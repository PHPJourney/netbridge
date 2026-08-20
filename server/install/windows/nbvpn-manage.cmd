@echo off
rem NetBridge nbvpn — interactive manage menu for Server 2012 (no Fyne GUI).
rem Compatible with cmd.exe on Server 2012 / 2012 R2 (no PowerShell menu required).
setlocal EnableExtensions
cd /d "%~dp0"
title NetBridge nbvpn 管理

:menu
cls
echo.
echo  ========================================
echo   NetBridge nbvpn 管理 ^(Server 2012^)
echo  ========================================
echo.
echo   本机没有 Fyne GUI：日常管理用本菜单或 CLI。
echo   无官方 WireGuard 1.1 时，start 多为 dry-run；
echo   仍可加 peer、导出 URI/conf 给客户端。
echo   真隧道请自备兼容 2012 的旧 WG，或换
echo   Linux / Server 2016+。
echo.
echo  ----------------------------------------
echo   1. 状态 ^(status^)
echo   2. 启动 ^(start^)
echo   3. 停止 ^(stop^)
echo   4. 列出 peer
echo   5. 显示连接信息 / URI
echo   6. 打开数据目录
echo   7. 添加 peer
echo   0. 退出
echo  ----------------------------------------
echo.
set "CHOICE="
set /p CHOICE=请输入数字后回车: 

if "%CHOICE%"=="1" goto do_status
if "%CHOICE%"=="2" goto do_start
if "%CHOICE%"=="3" goto do_stop
if "%CHOICE%"=="4" goto do_peerlist
if "%CHOICE%"=="5" goto do_show
if "%CHOICE%"=="6" goto do_data
if "%CHOICE%"=="7" goto do_peeradd
if "%CHOICE%"=="0" goto do_exit
echo.
echo  无效选项，请重试。
pause
goto menu

:do_status
echo.
echo  == nbvpn version ==
"%~dp0nbvpn.exe" version
echo.
echo  == nbvpn status ==
"%~dp0nbvpn.exe" status
goto after

:do_start
echo.
echo  == nbvpn start ==
"%~dp0nbvpn.exe" start
goto after

:do_stop
echo.
echo  == nbvpn stop ==
"%~dp0nbvpn.exe" stop
goto after

:do_peerlist
echo.
echo  == nbvpn peer list ==
"%~dp0nbvpn.exe" peer list
goto after

:do_show
echo.
echo  == nbvpn show --uri ==
"%~dp0nbvpn.exe" show --uri
echo.
echo  == nbvpn show ^(摘要^) ==
"%~dp0nbvpn.exe" show
goto after

:do_data
echo.
echo  打开 %%ProgramData%%\nbvpn ...
start "" explorer.exe "%ProgramData%\nbvpn"
goto after

:do_peeradd
echo.
set "PNAME="
set /p PNAME=可选：输入 peer 名称后回车^(直接回车则自动命名^): 
echo.
echo  == nbvpn peer add ==
if defined PNAME (
  "%~dp0nbvpn.exe" peer add %PNAME%
) else (
  "%~dp0nbvpn.exe" peer add
)
goto after

:after
echo.
echo  ----------------------------------------
pause
goto menu

:do_exit
echo.
echo  已退出。
endlocal
exit /b 0
