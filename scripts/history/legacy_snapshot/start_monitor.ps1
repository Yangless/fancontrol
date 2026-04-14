# FanControl 监控启动器

param(
    [string]$Mode = "normal"  # normal, background
)

if ($Mode -eq "background") {
    # 后台运行
    Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\FanControl_Auto\monitor.ps1`"" -WindowStyle Hidden
    Write-Host "Monitor started in background" -ForegroundColor Green
} else {
    # 前台运行
    & "C:\FanControl_Auto\monitor.ps1"
}