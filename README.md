# LegionDeck

> Real-time Windows PC hardware telemetry streamed to iPhone 16 Pro & Apple Watch Series 8 over local Wi-Fi.

## Features

| Feature | Status |
|---------|--------|
| 1 Hz CPU / GPU / RAM / VRAM telemetry | ✅ |
| AMD Ryzen AI 7 350 CPU temperatures | ✅ |
| NVIDIA RTX 5070 GPU temperatures | ✅ |
| AMD Radeon 860M iGPU temp (bonus) | ✅ |
| Dynamic Island Live Activity (iOS 27) | ✅ |
| Lock Screen Live Activity banner | ✅ |
| Silent audio background keep-alive | ✅ |
| Bidirectional clipboard sync | ✅ |
| Remote PC lock | ✅ |
| Apple Watch Series 8 complications (4 families) | ✅ |
| Watch Smart Stack widget | ✅ |
| In-app floating debug console | ✅ |
| GitHub Actions unsigned IPA build | ✅ |
| LiveContainer compatible (reduced features) | ⚠️ |

---

## Quick Start

### Windows PC (Daemon)

```
cd pc_daemon
start.bat          ← double-click (will prompt for Admin/UAC)
```

The terminal will print your local IP, e.g. `ws://192.168.1.42:8765`.

### iPhone (App)
1. Download IPA from GitHub Actions → Artifacts
2. Sign & install via **AltStore** or **Sideloadly**
3. Open **LegionDeck** → **Settings** → enter your PC's IP
4. Tap **Connect**

---

## Architecture

```
Windows Daemon (Python)
  ├── pynvml          → RTX 5070: usage, VRAM, temp
  ├── HardwareMonitor → Ryzen AI 7 CPU temp, Radeon 860M iGPU temp
  ├── psutil          → CPU usage %, RAM usage %
  └── WebSocket :8765 → 1Hz JSON broadcast

iOS App (SwiftUI)
  ├── SocketManager        → WebSocket client, auto-reconnect
  ├── BackgroundEngine     → Silent audio loop (keeps socket alive)
  ├── LiveActivityManager  → Dynamic Island / Lock Screen
  ├── WatchSessionManager  → Sends data to Watch every 5s
  ├── ClipboardSync        → Bidirectional clipboard bridge
  └── DebugOverlayView     → Floating terminal console

Apple Watch Series 8 (watchOS)
  ├── WatchDashboardView   → Companion app UI
  └── LegionWatchWidget    → 4 WidgetKit accessory families
```

---

## Project Structure

```
LegionDeck/
├── pc_daemon/                    ← Windows Python daemon
│   ├── main.py
│   ├── requirements.txt
│   └── start.bat
│
├── LegionDeck/                   ← iOS app source (add to Xcode project)
│   ├── App/
│   ├── Networking/
│   ├── Background/
│   ├── LiveActivity/
│   ├── Watch/
│   ├── Clipboard/
│   ├── Debug/
│   ├── Views/
│   └── Resources/Info.plist
│
├── LegionActivityWidget/         ← Widget Extension (Dynamic Island)
│
├── LegionDeckWatch/              ← watchOS companion app
│   └── LegionWatchWidget/
│
├── .github/workflows/build.yml   ← GitHub Actions IPA build
├── XCODE_SETUP.md                ← Step-by-step Xcode project setup
└── README.md
```

---

## LiveContainer Note

If using **LiveContainer**:
- ✅ Dashboard, clipboard, lock PC all work
- ❌ Dynamic Island / Live Activities — **not available** (requires Widget Extension registration)
- ❌ Apple Watch companion — **not available** (separate binary)
- ⚠️ Background keep-alive — unreliable (depends on LiveContainer's process)

For full features, sideload directly via AltStore.

---

## Requirements

### Windows
- Python 3.11+
- NVIDIA GPU with drivers installed (for pynvml)
- Run as Administrator (for CPU/iGPU temps via LibreHardwareMonitor)

### iOS
- iPhone with Dynamic Island (iPhone 14 Pro or newer)
- iOS 17.0+
- AltStore or Sideloadly for installation

### Watch
- Apple Watch Series 4 or newer (watchOS 10+)
- Paired with the iPhone running LegionDeck

---

## Re-Signing (Free Apple Account)

Free Apple ID sideloads expire every **7 days**. Keep AltServer running on your Windows PC and AltStore will auto-refresh over Wi-Fi.

The app's **Settings** tab shows days remaining and reminds you to re-sign.
