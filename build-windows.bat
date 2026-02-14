@ECHO OFF
setlocal enabledelayedexpansion
chcp 65001

pushd %~dp0
SET SCRIPT_DIR=%CD%
popd

if not "%~1"=="" set "BUILD_TYPE=%~1"

REM SET FFMPEG_VERSION=4.4.6

REM ==== Specify MSVC and Windows SDK versions ====
set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"

if not defined VC_VERSION set "VC_VERSION=14.38.33130"
if not defined WIN_SDK_VERSION set "WIN_SDK_VERSION=10.0.22621.0"
if not defined FFMPEG_VERSION set "FFMPEG_VERSION=7.1.3"
if not defined MSYS2_ROOT set "MSYS2_ROOT=%SCRIPT_DIR%\msys64"

if not defined BUILD_TYPE set BUILD_TYPE=static

if not "%BUILD_TYPE%"=="shared" set BUILD_TYPE=static


SET "FFMPEG_DIR=%SCRIPT_DIR%\ffmpeg-src\%FFMPEG_VERSION%"
if not defined INSTALL_DIR SET "INSTALL_DIR=%SCRIPT_DIR%\build\%FFMPEG_VERSION%\win64"

echo.

echo FFmpeg Version: %FFMPEG_VERSION%
echo BUILD TYPE: %BUILD_TYPE%
echo Source DIR: %FFMPEG_DIR%
echo Install DIR: %INSTALL_DIR%
echo MSYS2 DIR: %MSYS2_ROOT%

echo.

if not exist "%MSYS2_ROOT%" (
    echo MSYS2 not found !!
    exit /b 1
)




REM 转成 msys 路径
set "CYGPATH=%MSYS2_ROOT%\usr\bin"
pushd %CYGPATH%
for /f "usebackq delims=" %%i in (`cygpath.exe "%FFMPEG_DIR%"`) do (
    set "MSYS_FFMPEG_SRC=%%i"
)
popd

echo MSYS SRC: %MSYS_FFMPEG_SRC%

if not exist "%FFMPEG_DIR%" (
    echo Cloning FFmpeg %FFMPEG_VERSION% ...
    git clone --depth 1 -v --progress -b n%FFMPEG_VERSION% https://github.com/FFmpeg/FFmpeg.git "%FFMPEG_DIR%"
    if errorlevel 1 (
        echo Clone failed, exiting.
        exit /b 1
    )
)


if /I "%CI%" neq "true" (

    pushd "%VS_PATH%"
    echo Initializing MSVC environment...
    call ".\VC\Auxiliary\Build\vcvarsall.bat"  x86_amd64 %WIN_SDK_VERSION% -vcvars_ver=%VC_VERSION%
    popd
    if errorlevel 1 (
        echo MSVC environment initialization failed.
        exit /b 1
    )
    echo.
    where cl
    where msbuild
    echo.
)





pushd %SCRIPT_DIR%


where link

echo.

if exist "%INSTALL_DIR%\" (
    echo Clean build dir ...
    
    REM rmdir /s /q "%INSTALL_DIR%"
)

set "VC_EXE_PATH=%VCToolsInstallDir%bin\HostX86\x64"

call "%MSYS2_ROOT%\msys2_shell.cmd" -mingw64 -use-full-path -defterm -no-start -here ^
    -shell bash -c "./msys2_build_ffmpeg.sh \"%MSYS_FFMPEG_SRC%\" \"%BUILD_TYPE%\" \"%FFMPEG_VERSION%\""
popd


for %%F in ("%INSTALL_DIR%\lib\*.a") do (

    dumpbin /symbols "%%F" 2>nul | findstr /C:"COFF SYMBOL TABLE" >nul
    set "NEWNAME=%%~nF.lib"
    if %ERRORLEVEL%==0 (
        ren "%%F" "!NEWNAME!"
    ) else (
        echo WARNING: %%F is not an MSVC static library!
    )
)

GOTO exit




:exit
REM Check if this was launched from an existing terminal or directly from .bat
REM  If launched by executing the .bat then pause on completion
ECHO %CMDCMDLINE% | FINDSTR /L %COMSPEC% >NUL 2>&1
IF %ERRORLEVEL% == 0 if /I NOT "%CI%"=="true" PAUSE
endlocal
EXIT /B %ERROR%
