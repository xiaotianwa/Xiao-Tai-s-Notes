@echo off
echo ========================================
echo 重启小泰服务器（后端 + 管理端）
echo ========================================
echo.

echo [1/4] 停止现有服务...
echo 请在运行后端和管理端的终端中按 Ctrl+C 停止服务
echo.
pause

echo.
echo [2/4] 清理并重新编译后端...
cd backend
if exist dist (
    echo 删除旧的编译文件...
    rmdir /s /q dist
)
echo 重新编译...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo 编译失败！请检查错误信息。
    pause
    exit /b 1
)
echo 编译成功！
cd ..

echo.
echo [3/4] 启动后端服务...
echo 请在新终端中运行以下命令：
echo cd xiaotai_server\backend
echo npm run start:dev
echo.
pause

echo.
echo [4/4] 启动管理端...
echo 请在新终端中运行以下命令：
echo cd xiaotai_server\admin
echo npm run dev
echo.

echo ========================================
echo 服务重启完成！
echo ========================================
echo.
echo 后端地址: http://localhost:3100
echo 管理端地址: http://localhost:5174
echo API 文档: http://localhost:3100/api/docs
echo.
pause
