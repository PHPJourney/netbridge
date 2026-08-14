@echo off
REM Interim / advanced: run install.ps1 from the same folder (elevated).
REM Prefer NetBridge-nbvpn-Setup.exe when available from GitHub Releases.
cd /d "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator...
  powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if errorlevel 1 pause
