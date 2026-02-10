@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ======================================================
REM FFmpeg Windows static build (MSVC, Dynamic CRT)
REM ======================================================

REM Current script directory
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM FFmpeg version
set FFMPEG_VERSION=6.1.r112164
set FFMPEG_DIR=%SCRIPT_DIR%\msvc\ffmpeg-%FFMPEG_VERSION%

REM Output directory
set PREFIX=%SCRIPT_DIR%\build\win64

REM Clone FFmpeg if not exists
if not exist "%FFMPEG_DIR%" (
    echo Cloning FFmpeg %FFMPEG_VERSION% ...
    git clone --depth 1 -v --progress -b %FFMPEG_VERSION% https://github.com/ShiftMediaProject/FFmpeg "%FFMPEG_DIR%"
    if errorlevel 1 (
        echo Clone failed, exiting.
        exit /b 1
    )
)

cd /d "%FFMPEG_DIR%\SMP"

REM project_get_dependencies.bat



REM ==== Specify MSVC and Windows SDK versions ====
set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
set "VC_VERSION=14.38.33130"
set "WIN_SDK_VERSION=10.0.22621.0"

echo Initializing MSVC environment...
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat"  x86_amd64 %WIN_SDK_VERSION% -vcvars_ver=%VC_VERSION%
if errorlevel 1 (
    echo MSVC environment initialization failed.
    exit /b 1
)



REM ==== Configure FFmpeg ====
REM configure ^
REM --disable-gnutls ^
REM --disable-libssh ^
REM --enable-static ^
REM --disable-shared ^
REM --disable-x86asm ^
REM --disable-asm ^
REM --disable-inline-asm ^
REM --disable-stripping ^
REM --disable-programs ^
REM --disable-doc ^
REM --disable-debug ^
REM --disable-devices ^
REM --disable-filters ^
REM --disable-swresample ^
REM --disable-postproc ^
REM --disable-symver ^
REM --disable-encoders ^
REM --disable-decoders ^
REM --disable-demuxers ^
REM --disable-muxers ^
REM --disable-pthreads ^
REM --disable-w32threads ^
REM --disable-os2threads ^
REM --disable-protocols ^
REM --enable-protocol=file ^
REM --disable-runtime-cpudetect ^
REM --disable-bsfs ^
REM --disable-sdl2 ^
REM --disable-zlib ^
REM --disable-xlib ^
REM --disable-avdevice ^
REM --disable-network ^
REM --disable-autodetect ^
REM --enable-demuxer=aac,mp4,mov,webm,hevc,h264,avi,ogg,matroska ^
REM --enable-decoder=aac,h264,hevc,mpeg4,vp8,vp9,av1 ^
REM --enable-muxer=mp4 ^
REM --enable-hardcoded-tables

REM ==== Build and install ====
