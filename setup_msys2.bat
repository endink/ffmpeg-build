@echo off
setlocal

REM -----------------------------
REM 脚本目录
REM -----------------------------
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"  REM 去掉最后的反斜杠

REM -----------------------------
REM 设置安装目录
REM -----------------------------
if "%~1"=="" (
    set "INSTALL_DIR=%SCRIPT_DIR%"
) else (
    set "INSTALL_DIR=%~1"
)

echo MSYS2 will be installed to: %INSTALL_DIR%

REM -----------------------------
REM 如果目录已存在，直接退出
REM -----------------------------
if exist "%INSTALL_DIR%\msys64\." (
    echo Msys2 Directory already exists.
    exit /b 0
)

REM -----------------------------
REM MSYS2 下载地址和文件名
REM -----------------------------
set "MSYS2_URL=https://github.com/msys2/msys2-installer/releases/download/2025-12-13/msys2-base-x86_64-20251213.tar.xz"
set "MSYS2_FILE=%SCRIPT_DIR%\msys2-base-x86_64-20251213.tar.xz"

REM -----------------------------
REM 检查 curl 是否存在
REM -----------------------------
where curl >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl not found in PATH!
    exit /b 1
)

REM -----------------------------
REM 下载文件（如果不存在）
REM -----------------------------
if exist "%MSYS2_FILE%" (
    echo File already exists: %MSYS2_FILE%
) else (
    echo Downloading MSYS2 from %MSYS2_URL% ...
    curl -L -o "%MSYS2_FILE%" "%MSYS2_URL%"
    if errorlevel 1 (
        if exist "%MSYS2_FILE%" del "%MSYS2_FILE%"
        echo ERROR: Failed to download MSYS2!
        exit /b 1
    )
)

REM -----------------------------
REM 创建安装目录
REM -----------------------------
if not exist "%INSTALL_DIR%\." mkdir "%INSTALL_DIR%"

REM -----------------------------
REM 解压 tar.xz
REM -----------------------------
echo Extracting MSYS2 to %INSTALL_DIR% ...
tar -xf "%MSYS2_FILE%" -C "%INSTALL_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to extract MSYS2!
    if exist "%INSTALL_DIR%\msys64\." rmdir /s /q "%INSTALL_DIR%\msys64"
    exit /b 1
)

echo Done. MSYS2 is set up at %INSTALL_DIR%
endlocal