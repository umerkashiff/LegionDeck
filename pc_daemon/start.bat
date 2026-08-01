@echo off
:: LegionDeck — Windows Daemon Launcher
:: Auto-elevates to Administrator (required for CPU temperature sensors)
:: On first run: creates a Python venv and installs dependencies automatically.

title LegionDeck Daemon

:: ── Check for Administrator privileges ──────────────────────────────────────
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [LegionDeck] Requesting Administrator privileges...
    echo [LegionDeck] You will see a UAC prompt — click Yes.
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ── Setup venv on first run ─────────────────────────────────────────────────
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo [LegionDeck] First run — creating Python virtual environment...
    python -m venv .venv
    if %errorLevel% neq 0 (
        echo [ERROR] Python not found. Please install Python 3.11+ from python.org
        pause
        exit /b 1
    )
)

echo [LegionDeck] Verifying dependencies ^(this may take a minute^)...
.venv\Scripts\pip install --upgrade pip -q
.venv\Scripts\pip install -r requirements.txt -q

:: ── Launch daemon ───────────────────────────────────────────────────────────
echo [LegionDeck] Starting telemetry daemon in background...
echo [LegionDeck] You can close this window now. The daemon lives in your System Tray!
start "" .venv\Scripts\pythonw.exe main.py

exit /b

