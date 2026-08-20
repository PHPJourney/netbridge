@echo off
rem NetBridge nbvpn — open an interactive cmd in the install directory.
cd /d "%~dp0"
title NetBridge nbvpn
echo.
echo  安装目录: %CD%
echo  常用命令: nbvpn version ^| status ^| show --uri ^| peer list
echo  说明: Server 2012 无官方 WireGuard 真隧道时多为 dry-run / 导出配置。
echo.
cmd /k
