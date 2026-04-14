@echo off
:: 启动 FanControl 并根据时间自动切换配置
cd /d "D:\Program Files (x86)\FanControl"
start "" "FanControl.exe"

:: 等待 FanControl 启动
timeout /t 5 /nobreak >nul

:: 执行 PowerShell 脚本切换配置
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\auto_switch.ps1"
