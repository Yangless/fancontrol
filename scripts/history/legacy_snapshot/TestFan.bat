@echo off
chcp 65001 >nul
echo === FanControl 配置文件两分钟切换测试 ===
echo.

:: 设置 FanControl 所在目录（当前目录）
set FANCONTROL_DIR=%~dp0

:: 切换到 FanControl 所在目录
cd /d "%FANCONTROL_DIR%"

echo [时间: %TIME%] 正在切换为 游戏模式 (Game.json) ...
start "" "FanControl.exe" -c "Game.json"

echo 等待 60 秒...
timeout /t 60 /nobreak

echo.
echo [时间: %TIME%] 正在切换为 静音模式 (Quiet_mode.json) ...
start "" "FanControl.exe" -c "Quiet_mode.json"

echo 再次等待 60 秒...
timeout /t 60 /nobreak

echo.
echo === 测试结束 ===
pause
