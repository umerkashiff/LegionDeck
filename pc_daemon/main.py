"""
LegionDeck — Windows Telemetry Daemon
Broadcasts real-time hardware telemetry over WebSocket to connected iOS clients.

Requirements: pip install -r requirements.txt
Run via: start.bat (auto-elevates to Administrator for temperature sensors)
"""

import asyncio
import json
import logging
import socket
import subprocess
import time
import os
import base64
import io
import threading
import tkinter as tk

import psutil
import pyperclip
try:
    import keyboard
except ImportError:
    pass

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

try:
    import mss
    from PIL import Image
    MSS_AVAILABLE = True
except ImportError:
    MSS_AVAILABLE = False

CONFIG_FILE = "config.json"
DEFAULT_CONFIG = {
    "encryption_key": "LegionDeck_SecretKey_32_Bytes!!!",
    "locked_apps": ["Discord.exe", "Spotify.exe"]
}

def load_config():
    if not os.path.exists(CONFIG_FILE):
        save_config(DEFAULT_CONFIG)
        return DEFAULT_CONFIG
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return DEFAULT_CONFIG

def save_config(cfg):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(cfg, f, indent=4)
    except Exception:
        pass

CONFIG = load_config()
SECRET_KEY = CONFIG.get("encryption_key", DEFAULT_CONFIG["encryption_key"]).encode('utf-8')
if len(SECRET_KEY) != 32:
    SECRET_KEY = DEFAULT_CONFIG["encryption_key"].encode('utf-8')

LOCKED_APPS = CONFIG.get("locked_apps", DEFAULT_CONFIG["locked_apps"])

def encrypt_payload(data: str) -> str:
    try:
        aesgcm = AESGCM(SECRET_KEY)
        nonce = os.urandom(12)
        ct = aesgcm.encrypt(nonce, data.encode('utf-8'), None)
        return base64.b64encode(nonce + ct).decode('utf-8')
    except Exception as e:
        log.error(f"Encryption failed: {e}")
        return ""

def decrypt_payload(b64_str: str) -> str:
    try:
        raw = base64.b64decode(b64_str)
        if len(raw) < 28: return "" 
        nonce = raw[:12]
        ct = raw[12:]
        aesgcm = AESGCM(SECRET_KEY)
        pt = aesgcm.decrypt(nonce, ct, None)
        return pt.decode('utf-8')
    except Exception:
        return ""

try:
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.PAUSE = 0
    PYAUTOGUI_AVAILABLE = True
except ImportError:
    PYAUTOGUI_AVAILABLE = False

try:
    from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
    from ctypes import cast, POINTER
    from comtypes import CLSCTX_ALL
    PYCAW_AVAILABLE = True
except ImportError:
    PYCAW_AVAILABLE = False

try:
    from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager
    WINSDK_AVAILABLE = True
except ImportError:
    WINSDK_AVAILABLE = False

import websockets
from websockets.server import WebSocketServerProtocol

try:
    import win32gui
    import win32process
    import win32con
    WIN32_AVAILABLE = True
except ImportError:
    WIN32_AVAILABLE = False

def _set_window_visibility(pid: int, show: bool = False):
    """Hides or shows all top-level windows belonging to a specific Process ID."""
    if not WIN32_AVAILABLE:
        return
    
    def callback(hwnd, hwnds):
        if win32gui.IsWindowVisible(hwnd) or show:
            _, found_pid = win32process.GetWindowThreadProcessId(hwnd)
            if found_pid == pid:
                hwnds.append(hwnd)
        return True

    hwnds = []
    try:
        win32gui.EnumWindows(callback, hwnds)
        cmd = win32con.SW_SHOW if show else win32con.SW_HIDE
        for hwnd in hwnds:
            win32gui.ShowWindow(hwnd, cmd)
    except Exception as e:
        log.warning(f"Error setting window visibility for PID {pid}: {e}")

# ─── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("LegionDeck")

# ─── NVIDIA GPU via pynvml ───────────────────────────────────────────────────
NVML_AVAILABLE = False
_nvml_handle = None
_nvml_name = "N/A"

try:
    import pynvml
    pynvml.nvmlInit()
    _nvml_handle = pynvml.nvmlDeviceGetHandleByIndex(0)
    raw_name = pynvml.nvmlDeviceGetName(_nvml_handle)
    _nvml_name = raw_name.decode() if isinstance(raw_name, bytes) else raw_name
    NVML_AVAILABLE = True
    log.info(f"NVIDIA GPU: {_nvml_name}")
except Exception as e:
    log.warning(f"pynvml unavailable ({e}) — GPU metrics will be 0.")

# ─── CPU + iGPU temps via LibreHardwareMonitor ───────────────────────────────
LHM_AVAILABLE = False
_lhm_computer = None
_lhm_visitor = None

try:
    from HardwareMonitor.Hardware import Computer, SensorType

    class _UpdateVisitor:
        """Visitor that triggers hardware.Update() on all nodes."""
        def VisitComputer(self, computer):
            computer.Traverse(self)

        def VisitHardware(self, hardware):
            hardware.Update()
            for sub in hardware.SubHardware:
                sub.Update()

        def VisitSensor(self, sensor):
            pass

        def VisitParameter(self, parameter):
            pass

    _lhm_computer = Computer()
    _lhm_computer.IsCpuEnabled = True
    _lhm_computer.IsGpuEnabled = True
    _lhm_computer.Open()
    _lhm_visitor = _UpdateVisitor()
    LHM_AVAILABLE = True
    log.info("LibreHardwareMonitor ready — CPU/iGPU temps enabled.")
except Exception as e:
    log.warning(f"LibreHardwareMonitor unavailable ({e}) — temps will be 0.")
    log.warning("Re-run start.bat as Administrator to enable temperature reading.")

# ─── Connected clients ───────────────────────────────────────────────────────
_clients: set[WebSocketServerProtocol] = set()

# ═══════════════════════════════════════════════════════════════════════════════
# Hardware Readers
# ═══════════════════════════════════════════════════════════════════════════════

def _read_gpu() -> dict:
    """RTX 5070 metrics via pynvml."""
    if not NVML_AVAILABLE:
        return {"gpu_usage": 0, "vram_usage": 0, "temp_gpu": 0, "gpu_label": "N/A"}
    try:
        util = pynvml.nvmlDeviceGetUtilizationRates(_nvml_handle)
        mem  = pynvml.nvmlDeviceGetMemoryInfo(_nvml_handle)
        temp = pynvml.nvmlDeviceGetTemperature(_nvml_handle, pynvml.NVML_TEMPERATURE_GPU)
        vram_pct = int((mem.used / mem.total) * 100) if mem.total > 0 else 0
        return {
            "gpu_usage":  int(util.gpu),
            "vram_usage": vram_pct,
            "temp_gpu":   int(temp),
            "gpu_label":  _nvml_name,
        }
    except Exception as e:
        log.debug(f"GPU read error: {e}")
        return {"gpu_usage": 0, "vram_usage": 0, "temp_gpu": 0, "gpu_label": _nvml_name}


def _read_lhm_temps() -> dict:
    """CPU package temp (AMD Ryzen AI 7) and iGPU temp (Radeon 860M) via LHM."""
    out = {"temp_cpu": 0, "temp_igpu": 0}
    if not LHM_AVAILABLE or _lhm_computer is None:
        return out
    try:
        _lhm_computer.Accept(_lhm_visitor)
        for hw in _lhm_computer.Hardware:
            hw_type_str = str(hw.HardwareType).lower()
            # Iterate sub-hardware too (some sensors live there)
            targets = list(hw.SubHardware) + [hw]
            for target in targets:
                target.Update()
                for sensor in target.Sensors:
                    if str(sensor.SensorType).lower() != "temperature":
                        continue
                    val = sensor.Value
                    if val is None:
                        continue
                    name = str(sensor.Name).lower()
                    # AMD Ryzen CPU package / Tdie / Tctl
                    if "cpu" in hw_type_str and (
                        "package" in name or "tdie" in name or "tctl" in name
                    ):
                        out["temp_cpu"] = int(val)
                    # AMD Radeon 860M iGPU
                    if "gpu" in hw_type_str and "amd" in hw_type_str:
                        if any(k in name for k in ("core", "junction", "hot spot", "edge")):
                            out["temp_igpu"] = int(val)
    except Exception as e:
        log.debug(f"LHM read error: {e}")
    return out


def _read_system() -> dict:
    """CPU usage % and RAM usage % via psutil (no admin required)."""
    return {
        "cpu_usage": int(psutil.cpu_percent(interval=None)),
        "ram_usage": int(psutil.virtual_memory().percent),
    }


def _read_clipboard() -> str:
    try:
        return pyperclip.paste() or ""
    except Exception:
        return ""

async def _read_media() -> dict:
    out = {"media_title": "", "media_artist": ""}
    if not WINSDK_AVAILABLE:
        return out
    try:
        manager = await GlobalSystemMediaTransportControlsSessionManager.request_async()
        session = manager.get_current_session()
        if session:
            info = await session.try_get_media_properties_async()
            out["media_title"] = info.title or ""
            out["media_artist"] = info.artist or ""
    except Exception as e:
        log.debug(f"Media read error: {e}")
    return out

def _read_volume() -> int:
    if not PYCAW_AVAILABLE: return 0
    try:
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = cast(interface, POINTER(IAudioEndpointVolume))
        scalar = volume.GetMasterVolumeLevelScalar()
        return int(round(scalar * 100))
    except Exception as e:
        log.debug(f"Volume read error: {e}")
        return 0

# ═══════════════════════════════════════════════════════════════════════════════
# Advanced Features (View Finder, App Lock, Secure Screen)
# ═══════════════════════════════════════════════════════════════════════════════

_authorized_apps = set()
_auth_pending_apps = set()
_viewfinder_active = False
_secure_screen_root = None
_secure_screen_thread_ref = None

def _broadcast_event(payload: dict):
    if _clients:
        msg = json.dumps(payload)
        enc = encrypt_payload(msg)
        if not enc: return
        for c in _clients:
            asyncio.create_task(c.send(enc))

async def _app_lock_engine():
    """Hides the window of unauthorized locked apps until FaceID auth is received."""
    while True:
        try:
            for proc in psutil.process_iter(['name', 'pid']):
                name = proc.info['name']
                if name and name in LOCKED_APPS:
                    if name not in _authorized_apps and name not in _auth_pending_apps:
                        _auth_pending_apps.add(name)
                        log.info(f"Locked {name} detected. Hiding windows and requesting FaceID.")
                        _broadcast_event({"action": "request_auth", "app": name, "type": "app_lock"})
                    
                    # Force hide while unauthorized
                    if name not in _authorized_apps:
                        _set_window_visibility(proc.info['pid'], False)
        except Exception:
            pass
        await asyncio.sleep(1.0)

async def _viewfinder_loop():
    """Streams the primary monitor as JPEG frames over WebSocket."""
    if not MSS_AVAILABLE: return
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        while True:
            if _viewfinder_active and _clients:
                try:
                    sct_img = sct.grab(monitor)
                    img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
                    img.thumbnail((1280, 720))
                    buf = io.BytesIO()
                    img.save(buf, format="JPEG", quality=40)
                    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
                    
                    _broadcast_event({"action": "viewfinder_frame", "data": b64})
                except Exception as e:
                    log.error(f"Viewfinder error: {e}")
                await asyncio.sleep(1/15)
            else:
                await asyncio.sleep(1.0)

def _secure_screen_gui():
    global _secure_screen_root
    _secure_screen_root = tk.Tk()
    _secure_screen_root.attributes("-fullscreen", True, "-topmost", True, "-alpha", 1.0)
    _secure_screen_root.configure(bg="black")
    _secure_screen_root.config(cursor="none")
    
    lbl = tk.Label(_secure_screen_root, text="🔒 LEGION SECURE SCREEN", fg="cyan", bg="black", font=("Arial", 32, "bold"))
    lbl.pack(expand=True)
    lbl2 = tk.Label(_secure_screen_root, text="Authenticate on iPhone to unlock.\nBypass: Ctrl+Shift+Alt+U", fg="gray", bg="black", font=("Arial", 16))
    lbl2.pack(pady=20)
    
    def check_close():
        if getattr(_secure_screen_root, "should_close", False):
            _secure_screen_root.destroy()
        else:
            _secure_screen_root.after(100, check_close)
            
    _secure_screen_root.after(100, check_close)
    _secure_screen_root.mainloop()

def _spawn_secure_screen(app=None):
    global _secure_screen_thread_ref
    if _secure_screen_thread_ref and _secure_screen_thread_ref.is_alive():
        return
    log.info("Starting Legion Secure Screen...")
    if app:
        _broadcast_event({"action": "request_auth", "app": app, "type": "app_lock"})
    else:
        _broadcast_event({"action": "request_auth", "type": "secure_screen"})
    _secure_screen_thread_ref = threading.Thread(target=_secure_screen_gui, daemon=True)
    _secure_screen_thread_ref.start()

def _kill_secure_screen():
    if _secure_screen_root:
        _secure_screen_root.should_close = True

def _bypass_hook():
    log.info("Bypass hook triggered!")
    _kill_secure_screen()
    for app in list(_auth_pending_apps):
        _auth_pending_apps.discard(app)
        _authorized_apps.add(app)
        for proc in psutil.process_iter(['name', 'pid']):
            if proc.info['name'] == app:
                _set_window_visibility(proc.info['pid'], True)

try:
    keyboard.add_hotkey('ctrl+shift+alt+u', _bypass_hook)
except Exception:
    pass

# ═══════════════════════════════════════════════════════════════════════════════
# WebSocket Handlers
# ═══════════════════════════════════════════════════════════════════════════════

async def _client_handler(ws: WebSocketServerProtocol):
    """Registers a client and listens for commands until disconnect."""
    _clients.add(ws)
    addr = ws.remote_address
    log.info(f"iOS connected  {addr[0]}:{addr[1]}  (total: {len(_clients)})")
    try:
        async for raw in ws:
            await _handle_command(raw)
    except websockets.ConnectionClosed:
        pass
    except Exception as e:
        log.warning(f"Client error: {e}")
    finally:
        _clients.discard(ws)
        log.info(f"iOS disconnected {addr[0]}:{addr[1]}  (total: {len(_clients)})")


async def _handle_command(raw: str):
    """Process a JSON command string from an iOS client."""
    raw = decrypt_payload(raw)
    if not raw: return
    try:
        msg = json.loads(raw)
    except json.JSONDecodeError:
        log.warning(f"Bad JSON from client: {raw[:80]}")
        return

    action = msg.get("action", "")

    if action == "ping":
        return

    elif action == "lock_pc":
        log.info("Lock PC requested by iOS.")
        subprocess.Popen(["rundll32.exe", "user32.dll,LockWorkStation"])

    elif action == "set_clipboard":
        text = msg.get("text", "")
        pyperclip.copy(text)
        preview = text[:50] + ("..." if len(text) > 50 else "")
        log.info(f"Clipboard set from iOS: '{preview}'")

    elif action == "mouse_move":
        if not PYAUTOGUI_AVAILABLE:
            log.warning("mouse_move ignored: pyautogui not installed (pip install pyautogui)")
            return
        dx = msg.get("dx", 0)
        dy = msg.get("dy", 0)
        try:
            pyautogui.moveRel(int(dx), int(dy))
        except Exception as e:
            log.error(f"mouse_move failed: {e}")

    elif action == "mouse_click":
        if not PYAUTOGUI_AVAILABLE: return
        button = msg.get("button", "left")
        log.info(f"Mouse click: {button}")
        try:
            pyautogui.click(button=button)
        except Exception as e:
            log.error(f"mouse_click failed: {e}")

    elif action == "mouse_down":
        if not PYAUTOGUI_AVAILABLE: return
        try:
            pyautogui.mouseDown()
        except Exception as e:
            log.error(f"mouse_down failed: {e}")

    elif action == "mouse_up":
        if not PYAUTOGUI_AVAILABLE: return
        try:
            pyautogui.mouseUp()
        except Exception as e:
            log.error(f"mouse_up failed: {e}")

    elif action == "mouse_scroll":
        if not PYAUTOGUI_AVAILABLE: return
        dy = msg.get("dy", 0)
        try:
            pyautogui.scroll(dy)
        except Exception: pass

    elif action == "keyboard_type":
        if not PYAUTOGUI_AVAILABLE: return
        text = msg.get("text", "")
        try:
            pyautogui.write(text)
        except Exception: pass
        
    elif action == "keyboard_press":
        if not PYAUTOGUI_AVAILABLE: return
        key = msg.get("key", "")
        try:
            pyautogui.press(key)
        except Exception: pass

    elif action == "launch_app":
        app = msg.get("app", "")
        log.info(f"Launch requested: {app}")
        try:
            if app == "steam":
                import os
                os.startfile("steam://open/main")
            elif app == "discord":
                import os
                local_app_data = os.environ.get("LOCALAPPDATA", "")
                discord_path = os.path.join(local_app_data, "Discord", "Update.exe")
                subprocess.Popen([discord_path, "--processStart", "Discord.exe"])
            elif app == "chrome":
                subprocess.Popen(["start", "chrome"], shell=True)
            elif app == "explorer":
                subprocess.Popen("explorer.exe")
            else:
                log.warning(f"Unknown app launch requested: {app}")
        except Exception as e:
            log.error(f"Failed to launch {app}: {e}")

    elif action == "media_playpause":
        if PYAUTOGUI_AVAILABLE:
            try: pyautogui.press('playpause')
            except Exception: pass

    elif action == "media_next":
        if PYAUTOGUI_AVAILABLE:
            try: pyautogui.press('nexttrack')
            except Exception: pass

    elif action == "media_prev":
        if PYAUTOGUI_AVAILABLE:
            try: pyautogui.press('prevtrack')
            except Exception: pass

    elif action == "set_volume":
        if PYCAW_AVAILABLE:
            try:
                level = float(msg.get("level", 50))
                level = max(0.0, min(100.0, level))
                scalar = level / 100.0
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                volume.SetMasterVolumeLevelScalar(scalar, None)
                log.info(f"Volume set to {int(level)}%")
            except Exception as e:
                log.error(f"set_volume failed: {e}")

    elif action == "auth_success":
        app_name = msg.get("app")
        auth_type = msg.get("type")
        if auth_type == "app_lock" and app_name:
            _auth_pending_apps.discard(app_name)
            _authorized_apps.add(app_name)
            for proc in psutil.process_iter(['name', 'pid']):
                if proc.info['name'] == app_name:
                    _set_window_visibility(proc.info['pid'], True)
            log.info(f"{app_name} unlocked.")
        elif auth_type == "secure_screen":
            _kill_secure_screen()
            log.info("Secure screen unlocked via FaceID.")

    elif action == "start_viewfinder":
        global _viewfinder_active
        _viewfinder_active = True
        log.info("Viewfinder started.")
        
    elif action == "stop_viewfinder":
        _viewfinder_active = False
        log.info("Viewfinder stopped.")

    elif action == "secure_lock_pc":
        _spawn_secure_screen()

    else:
        log.warning(f"Unknown action received: '{action}'")


# ═══════════════════════════════════════════════════════════════════════════════
# Broadcast Loop
# ═══════════════════════════════════════════════════════════════════════════════

async def _broadcast_loop():
    """Collects telemetry every second and fans it out to all connected clients."""
    # Prime psutil CPU counter (first call always returns 0.0)
    psutil.cpu_percent(interval=None)
    await asyncio.sleep(0.5)

    log.info("Broadcast loop running at 1 Hz.")
    last_clip = ""

    while True:
        try:
            sys_data  = _read_system()
            gpu_data  = _read_gpu()
            lhm_data  = _read_lhm_temps()
            clipboard = _read_clipboard()
            media     = await _read_media()
            volume    = _read_volume()

            if clipboard != last_clip:
                if clipboard == "":
                    log.debug("PC Clipboard is empty or unsupported format.")
                else:
                    preview = clipboard[:40] + ("..." if len(clipboard) > 40 else "")
                    log.info(f"PC Clipboard changed: '{preview}'")
                last_clip = clipboard

            payload = {
                "cpu_usage":    sys_data["cpu_usage"],
                "gpu_usage":    gpu_data["gpu_usage"],
                "ram_usage":    sys_data["ram_usage"],
                "vram_usage":   gpu_data["vram_usage"],
                "temp_cpu":     lhm_data["temp_cpu"],
                "temp_gpu":     gpu_data["temp_gpu"],
                "temp_igpu":    lhm_data["temp_igpu"],
                "gpu_label":    gpu_data["gpu_label"],
                "clipboard":    clipboard,
                "media_title":  media["media_title"],
                "media_artist": media["media_artist"],
                "volume":       volume,
                "timestamp":    int(time.time()),
            }

            if _clients:
                message = json.dumps(payload)
                enc = encrypt_payload(message)
                if enc:
                    await asyncio.gather(
                        *[c.send(enc) for c in list(_clients)],
                        return_exceptions=True,
                    )

        except Exception as e:
            log.error(f"Broadcast error: {e}")

        await asyncio.sleep(1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

async def _main():
    # Resolve local IP
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        local_ip = "127.0.0.1"

    print()
    print("=" * 55)
    print("   LegionDeck — Windows Telemetry Daemon")
    print("=" * 55)
    print(f"   WebSocket:  ws://{local_ip}:8765")
    print(f"   Enter the IP above in the iOS app → Settings")
    print(f"   NVIDIA GPU: {_nvml_name}")
    print(f"   LHM temps:  {'enabled' if LHM_AVAILABLE else 'DISABLED (run as admin)'}")
    print("=" * 55)
    print()

    async with websockets.serve(
        _client_handler,
        "0.0.0.0",
        8765,
        ping_interval=3,
        ping_timeout=5,
    ):
        await asyncio.gather(
            _broadcast_loop(),
            _app_lock_engine(),
            _viewfinder_loop(),
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Desktop System Tray GUI
# ═══════════════════════════════════════════════════════════════════════════════

try:
    import pystray
    import customtkinter as ctk
    from PIL import ImageDraw
    GUI_AVAILABLE = True
except ImportError:
    GUI_AVAILABLE = False

_settings_app = None

class SettingsWindow(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("LegionDeck Daemon")
        self.geometry("450x350")
        self.protocol("WM_DELETE_WINDOW", self.hide_window)
        
        self.label = ctk.CTkLabel(self, text="LegionDeck Settings", font=ctk.CTkFont(size=20, weight="bold"))
        self.label.pack(pady=(20, 10))
        
        # ── Key
        self.key_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.key_frame.pack(fill="x", padx=40, pady=10)
        ctk.CTkLabel(self.key_frame, text="Encryption Key (32 bytes):").pack(anchor="w")
        
        self.key_var = tk.StringVar(value=CONFIG.get("encryption_key", ""))
        self.key_entry = ctk.CTkEntry(self.key_frame, textvariable=self.key_var, show="*")
        self.key_entry.pack(fill="x", pady=5)
        
        # ── Locked Apps
        self.apps_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.apps_frame.pack(fill="x", padx=40, pady=10)
        ctk.CTkLabel(self.apps_frame, text="Locked Apps (comma separated):").pack(anchor="w")
        
        self.apps_var = tk.StringVar(value=", ".join(LOCKED_APPS))
        self.apps_entry = ctk.CTkEntry(self.apps_frame, textvariable=self.apps_var)
        self.apps_entry.pack(fill="x", pady=5)
        
        # ── Smart EXE Picker
        self.picker_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.picker_frame.pack(fill="x", padx=40, pady=0)
        
        # Fetch running processes (unique names, sorted)
        try:
            running = sorted(list(set([p.info['name'] for p in psutil.process_iter(['name']) if p.info['name']])))
        except Exception:
            running = ["Error fetching processes"]
            
        self.process_dropdown = ctk.CTkOptionMenu(self.picker_frame, values=running, dynamic_resizing=False)
        self.process_dropdown.pack(side="left", fill="x", expand=True, padx=(0, 10))
        
        def add_process():
            selected = self.process_dropdown.get()
            if selected and selected != "Error fetching processes":
                current = self.apps_var.get().strip()
                if current:
                    self.apps_var.set(f"{current}, {selected}")
                else:
                    self.apps_var.set(selected)
                    
        self.add_btn = ctk.CTkButton(self.picker_frame, text="Add Running App", command=add_process, width=120)
        self.add_btn.pack(side="right")
        
        # ── Save
        self.save_btn = ctk.CTkButton(self, text="Save & Apply", command=self.save_settings)
        self.save_btn.pack(pady=20)
        
    def save_settings(self):
        global SECRET_KEY, LOCKED_APPS
        key = self.key_var.get().strip()
        apps = [a.strip() for a in self.apps_var.get().split(',') if a.strip()]
        
        CONFIG["encryption_key"] = key
        CONFIG["locked_apps"] = apps
        save_config(CONFIG)
        
        SECRET_KEY = key.encode('utf-8')
        if len(SECRET_KEY) != 32:
            SECRET_KEY = DEFAULT_CONFIG["encryption_key"].encode('utf-8')
            
        LOCKED_APPS = apps
        self.hide_window()

    def hide_window(self):
        self.withdraw()

def _create_tray_image():
    image = Image.new('RGB', (64, 64), color='black')
    draw = ImageDraw.Draw(image)
    draw.rectangle((16, 16, 48, 48), fill='cyan')
    return image

def _show_settings(icon, item):
    if _settings_app:
        _settings_app.after(0, _settings_app.deiconify)

def _quit_app(icon, item):
    icon.stop()
    if _settings_app:
        _settings_app.after(0, _settings_app.quit)
    os._exit(0)

def _setup_tray():
    image = _create_tray_image()
    menu = pystray.Menu(
        pystray.MenuItem("Settings", _show_settings, default=True),
        pystray.MenuItem("Quit", _quit_app)
    )
    icon = pystray.Icon("LegionDeck", image, "LegionDeck Daemon", menu)
    icon.run()

# ═══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    try:
        # 1. Start the asyncio loop in a background thread
        def _start_async_loop():
            asyncio.run(_main())
        threading.Thread(target=_start_async_loop, daemon=True).start()
        
        # 2. Setup GUI on the main thread
        if GUI_AVAILABLE:
            # pystray blocks, so we run it in a thread, allowing CTK to run mainloop
            threading.Thread(target=_setup_tray, daemon=True).start()
            
            ctk.set_appearance_mode("dark")
            _settings_app = SettingsWindow()
            _settings_app.withdraw() # Start hidden
            _settings_app.mainloop()
        else:
            log.warning("GUI dependencies missing. Running without System Tray.")
            while True: time.sleep(1.0)
            
    except KeyboardInterrupt:
        log.info("Interrupted — shutting down.")
        os._exit(0)
