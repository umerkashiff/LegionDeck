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

import psutil
import pyperclip
import websockets
from websockets.server import WebSocketServerProtocol

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
    try:
        msg = json.loads(raw)
    except json.JSONDecodeError:
        log.warning(f"Bad JSON from client: {raw[:80]}")
        return

    action = msg.get("action", "")

    if action == "lock_pc":
        log.info("Lock PC requested by iOS.")
        subprocess.Popen(["rundll32.exe", "user32.dll,LockWorkStation"])

    elif action == "set_clipboard":
        text = msg.get("text", "")
        pyperclip.copy(text)
        preview = text[:50] + ("..." if len(text) > 50 else "")
        log.info(f"Clipboard set from iOS: '{preview}'")

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

            if clipboard != last_clip:
                if clipboard == "":
                    log.debug("PC Clipboard is empty or unsupported format.")
                else:
                    preview = clipboard[:40] + ("..." if len(clipboard) > 40 else "")
                    log.info(f"PC Clipboard changed: '{preview}'")
                last_clip = clipboard

            payload = {
                "cpu_usage":  sys_data["cpu_usage"],
                "gpu_usage":  gpu_data["gpu_usage"],
                "ram_usage":  sys_data["ram_usage"],
                "vram_usage": gpu_data["vram_usage"],
                "temp_cpu":   lhm_data["temp_cpu"],
                "temp_gpu":   gpu_data["temp_gpu"],
                "temp_igpu":  lhm_data["temp_igpu"],
                "gpu_label":  gpu_data["gpu_label"],
                "clipboard":  clipboard,
                "timestamp":  int(time.time()),
            }

            if _clients:
                message = json.dumps(payload)
                await asyncio.gather(
                    *[c.send(message) for c in list(_clients)],
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
        ping_interval=None,
        ping_timeout=None,
    ):
        await _broadcast_loop()


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        log.info("Interrupted — shutting down.")
    finally:
        if NVML_AVAILABLE:
            try:
                pynvml.nvmlShutdown()
            except Exception:
                pass
        if LHM_AVAILABLE and _lhm_computer:
            try:
                _lhm_computer.Close()
            except Exception:
                pass
