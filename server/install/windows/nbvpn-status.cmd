@echo off
rem NetBridge nbvpn — show status in a visible window that stays open.
cd /d "%~dp0"
title NetBridge nbvpn status
echo.
echo  == nbvpn version ==
"%~dp0nbvpn.exe" version
echo.
echo  == nbvpn status ==
"%~dp0nbvpn.exe" status
echo.
echo  按任意键关闭…
pause >nul
