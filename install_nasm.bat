@echo OFF

chcp 65001
setlocal

REM =============================
REM 初始化脚本目录
REM =============================
SET "CALLDIR=%CD%"
pushd %~dp0
SET "SCRIPT_DIR=%CD%"
popd

SET "VSNASM_DIR=%SCRIPT_DIR%\VSNASM"

REM =============================
REM 克隆 VSNASM 库（如果不存在）
REM =============================
if not exist "%VSNASM_DIR%" (
    echo Cloning VSNASM ...
    git clone --depth 1 -v --progress -b 1.0 https://github.com/ShiftMediaProject/VSNASM.git "%VSNASM_DIR%"
    if errorlevel 1 (
        echo Clone failed, exiting.
        exit /b 1
    )
)

REM =============================
REM VS Build Tools 安装路径
REM =============================
SET "VS_BUILD_PATH=C:\VS_BUILD"

REM 先调用 VsDevCmd.bat 初始化环境
if not exist "%VS_BUILD_PATH%\Common7\Tools\VsDevCmd.bat" (
    echo Error: VsDevCmd.bat not found at %VS_BUILD_PATH%
    goto Exit
)
call "%VS_BUILD_PATH%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64

REM =============================
REM 检查 VCINSTALLDIR
REM =============================
if not defined VCINSTALLDIR (
    echo Error: VCINSTALLDIR is not set! Ensure VsDevCmd.bat was called correctly.
    goto Exit
)
echo VCINSTALLDIR: %VCINSTALLDIR%

REM =============================
REM 自动获取 VCTargetsPath
REM =============================
REM VS2022/VS2026: VC\Tools\MSVC\<version>\BuildCustomizations
REM VS2019: VC\Tools\MSVC\<version>\BuildCustomizations
REM VS2017: VC\VCTargets\BuildCustomizations
for /f "delims=" %%v in ('dir /b /ad "%VCINSTALLDIR%\Tools\MSVC" 2^>nul') do set MSVC_VER_DIR=%%v
if defined MSVC_VER_DIR (
    set "VCTargetsPath=%VCINSTALLDIR%\Tools\MSVC\%MSVC_VER_DIR%\BuildCustomizations"
) else (
    REM fallback for VS2017
    set "VCTargetsPath=%VCINSTALLDIR%\VCTargets\BuildCustomizations"
)

REM 确认路径存在
if not exist "%VCTargetsPath%" (
    echo Error: VCTargetsPath not found at %VCTargetsPath%
    goto Exit
)
echo VCTargetsPath: %VCTargetsPath%

REM =============================
REM 安装 VSNASM BuildCustomizations
REM =============================
echo Installing VSNASM build customizations...
del /F /Q "%VCTargetsPath%\nasm.*" >nul 2>&1
copy /B /Y /V "%VSNASM_DIR%\nasm.*" "%VCTargetsPath%\" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to copy build customizations!
    goto Exit
)

REM =============================
REM 下载并安装 NASM（可选覆盖）
REM =============================
set NASMDL=http://www.nasm.us/pub/nasm/releasebuilds
set NASMVERSION=3.01
set SYSARCH=64

if exist "%VCINSTALLDIR%\nasm.exe" (
    "%VCINSTALLDIR%\nasm.exe" -v >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo Using existing NASM in VCINSTALLDIR
        goto SkipInstallNASM
    )
)

REM 下载 NASM
if not exist "%SCRIPT_DIR%\nasm_%NASMVERSION%.zip" (
    set NASMDOWNLOAD=%NASMDL%/%NASMVERSION%/win%SYSARCH%/nasm-%NASMVERSION%-win%SYSARCH%.zip
    echo Downloading NASM %NASMVERSION%...
    powershell.exe -Command "(New-Object Net.WebClient).DownloadFile('%NASMDOWNLOAD%', '%SCRIPT_DIR%\nasm_%NASMVERSION%.zip')" >nul 2>&1
    if not exist "%SCRIPT_DIR%\nasm_%NASMVERSION%.zip" (
        echo Error: Failed to download NASM!
        goto Exit
    )
)

REM 解压并复制
powershell.exe -Command Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%SCRIPT_DIR%\nasm_%NASMVERSION%.zip', '%SCRIPT_DIR%\TempNASMUnpack') >nul 2>&1
if not exist "%SCRIPT_DIR%\TempNASMUnpack" (
    echo Error: Failed to unpack NASM!
    goto Exit
)
copy /B /Y /V "%SCRIPT_DIR%\TempNASMUnpack\nasm-%NASMVERSION%\nasm.exe" "%VCINSTALLDIR%" >nul 2>&1
rd /S /Q "%SCRIPT_DIR%\TempNASMUnpack" >nul 2>&1
:SkipInstallNASM

echo Finished Successfully
goto Exit

:Exit
cd %CALLDIR%
endlocal & exit /b 0