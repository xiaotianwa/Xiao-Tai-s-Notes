# 停止小泰服务器
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "停止小泰服务器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 停止后端 (端口 3100)
Write-Host "检查后端服务 (端口 3100)..." -ForegroundColor Yellow
$backend = Get-NetTCPConnection -LocalPort 3100 -ErrorAction SilentlyContinue
if ($backend) {
    $backendPid = $backend.OwningProcess | Select-Object -First 1
    Write-Host "  找到后端进程 (PID: $backendPid)" -ForegroundColor Gray
    Write-Host "  正在停止..." -ForegroundColor Gray
    Stop-Process -Id $backendPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "  ✓ 后端已停止" -ForegroundColor Green
} else {
    Write-Host "  后端未运行" -ForegroundColor Gray
}
Write-Host ""

# 停止管理端 (端口 5174)
Write-Host "检查管理端服务 (端口 5174)..." -ForegroundColor Yellow
$admin = Get-NetTCPConnection -LocalPort 5174 -ErrorAction SilentlyContinue
if ($admin) {
    $adminPid = $admin.OwningProcess | Select-Object -First 1
    Write-Host "  找到管理端进程 (PID: $adminPid)" -ForegroundColor Gray
    Write-Host "  正在停止..." -ForegroundColor Gray
    Stop-Process -Id $adminPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "  ✓ 管理端已停止" -ForegroundColor Green
} else {
    Write-Host "  管理端未运行" -ForegroundColor Gray
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "所有服务已停止" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Read-Host "按回车键关闭此窗口"
