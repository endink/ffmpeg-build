@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
set "VC_VERSION=14.38.33130"
set "WIN_SDK_VERSION=10.0.22621.0"

REM ======================================================
REM FFmpeg Windows static build (MSVC, Dynamic CRT)
REM ======================================================

REM Current script directory
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM FFmpeg version
set FFVS_COMMIT=a25ea00107e46d01df7279fbcd64876f7661305a
set FFVS_DIR=%SCRIPT_DIR%\FFVS-Project-Generator

REM Output directory
set PREFIX=%SCRIPT_DIR%\build\win64

REM Clone FFmpeg if not exists
if not exist "%FFVS_DIR%\project_generate.sln" (
    call "%SCRIPT_DIR%\git_fetch_commit.bat" ^
    "https://github.com/ShiftMediaProject/FFVS-Project-Generator.git" ^
    %FFVS_COMMIT% ^
    %FFVS_DIR% ^
    master
)



REM ==== Specify MSVC and Windows SDK versions ====

echo Initializing MSVC environment...
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat"  x86_amd64 %WIN_SDK_VERSION% -vcvars_ver=%VC_VERSION%
if errorlevel 1 (
    echo MSVC environment initialization failed.
    exit /b 1
)


msbuild %FFVS_DIR%\project_generate.sln /p:Configuration=Release /p:Platform=x64

copy /Y "%FFVS_DIR%\bin\project_generate.exe"  "%SCRIPT_DIR%\windows-builder\"
copy /Y "%FFVS_DIR%\smp_project_get_dependencies"  "%SCRIPT_DIR%\windows-builder\"


pause