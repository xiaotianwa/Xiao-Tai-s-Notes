# 小泰服务器重启脚本
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "重启小泰服务器（后端 + 管理端）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 停止占用端口的进程
Write-Host "[1/5] 停止现有服务..." -ForegroundColor Yellow

# 停止后端 (端口 3100)
$backend = Get-NetTCPConnection -LocalPort 3100 -ErrorAction SilentlyContinue
if ($backend) {
    $backendPid = $backend.OwningProcess | Select-Object -First 1
    Write-Host "  停止后端进程 (PID: $backendPid)..." -ForegroundColor Gray
    Stop-Process -Id $backendPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "  后端已停止" -ForegroundColor Green
} else {
    Write-Host "  后端未运行" -ForegroundColor Gray
}

# 停止管理端 (端口 5174)
$admin = Get-NetTCPConnection -LocalPort 5174 -ErrorAction SilentlyContinue
if ($admin) {
    $adminPid = $admin.OwningProcess | Select-Object -First 1
    Write-Host "  停止管理端进程 (PID: $adminPid)..." -ForegroundColor Gray
    Stop-Process -Id $adminPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "  管理端已停止" -ForegroundColor Green
} else {
    Write-Host "  管理端未运行" -ForegroundColor Gray
}

Write-Host ""

# 清理后端编译文件
Write-Host "[2/5] 清理后端编译文件..." -ForegroundColor Yellow
Set-Location backend
if (Test-Path "dist") {
    Write-Host "  删除 dist 文件夹..." -ForegroundColor Gray
    Remove-Item -Recurse -Force dist
    Write-Host "  清理完成" -ForegroundColor Green
} else {
    Write-Host "  dist 文件夹不存在，跳过" -ForegroundColor Gray
}
Write-Host ""

# 重新编译后端
Write-Host "[3/5] 重新编译后端..." -ForegroundColor Yellow
Write-Host "  运行 npm run build..." -ForegroundColor Gray
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "  编译失败！请检查错误信息。" -ForegroundColor Red
    Set-Location ..
    Read-Host "按回车键退出"
    exit 1
}
Write-Host "  编译成功！" -ForegroundColor Green
Set-Location ..
Write-Host ""

# 启动后端
Write-Host "[4/5] 启动后端服务..." -ForegroundColor Yellow
Write-Host "  在新窗口中启动后端..." -ForegroundColor Gray
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\backend'; Write-Host '后端服务启动中...' -ForegroundColor Cyan; npm run start:dev"
Start-Sleep -Seconds 3
Write-Host "  后端已启动" -ForegroundColor Green
Write-Host ""

# 启动管理端
Write-Host "[5/5] 启动管理端..." -ForegroundColor Yellow
Write-Host "  在新窗口中启动管理端..." -ForegroundColor Gray
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\admin'; Write-Host '管理端启动中...' -ForegroundColor Cyan; npm run dev"
Start-Sleep -Seconds 2
Write-Host "  管理端已启动" -ForegroundColor Green
Write-Host ""

# 完成
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "服务重启完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "后端地址:   http://localhost:3100" -ForegroundColor White
Write-Host "管理端地址: http://localhost:5174" -ForegroundColor White
Write-Host "API 文档:   http://localhost:3100/api/docs" -ForegroundColor White
Write-Host ""
Write-Host "等待服务完全启动（约 10-20 秒）..." -ForegroundColor Yellow
Write-Host ""

Read-Host "按回车键关闭此窗口"
