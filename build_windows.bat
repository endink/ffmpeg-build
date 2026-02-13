@ECHO OFF
setlocal enabledelayedexpansion
REM SET FFMPEG_VERSION=4.4.6

REM ==== Specify MSVC and Windows SDK versions ====
set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"

if not defined VC_VERSION set "VC_VERSION=14.38.33130"
if not defined WIN_SDK_VERSION set "WIN_SDK_VERSION=10.0.22621.0"
if not defined FFMPEG_VERSION set "FFMPEG_VERSION=7.1.3"

if not "%~1"=="" set "MS_BUILD_TYPE=%~1"

if not defined MS_BUILD_TYPE set "MS_BUILD_TYPE=static"

if /I "%MS_BUILD_TYPE%"=="shared" (
    set "MSBUILD_CONFIG_TYPE=DynamicLibrary"
) else (
    set "MSBUILD_CONFIG_TYPE=StaticLibrary"
)

echo BUILD TYPE: %MSBUILD_CONFIG_TYPE%


pushd %~dp0

SET SCRIPT_DIR=%CD%

SET "BUILDER_DIR=%SCRIPT_DIR%\windows-builder"
SET "SOURCE_DIR=%BUILDER_DIR%\src"
SET "INSTALL_DIR=%SCRIPT_DIR%\build\%FFMPEG_VERSION%\win64"


if /I "%CI%"=="true" (
    if defined OUTPUT_DIR set "INSTALL_DIR=%OUTPUT_DIR%"
    
    
    echo Running inside CI environment
    echo Output Dir: %OUTPUT_DIR%
    echo.
)


if defined FFMPEG_DIR (
    if not "%FFMPEG_DIR%"=="" (
        if exist "%FFMPEG_DIR%\" (
            mklink /D "%SOURCE_DIR%\ffmpeg-%FFMPEG_VERSION%" "%FFMPEG_DIR%"
        )
    )
)

SET FFMPEG_DIR=%SOURCE_DIR%\ffmpeg-%FFMPEG_VERSION%

if not exist "%FFMPEG_DIR%" (
    echo Cloning FFmpeg %FFMPEG_VERSION% ...
    git clone --depth 1 -v --progress -b n%FFMPEG_VERSION% https://github.com/FFmpeg/FFmpeg.git "%FFMPEG_DIR%"
    if errorlevel 1 (
        echo Clone failed, exiting.
        exit /b 1
    )
)


if /I NOT "%CI%"=="true" (

    echo Initializing MSVC environment...
    call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat"  x86_amd64 %WIN_SDK_VERSION% -vcvars_ver=%VC_VERSION%
    if errorlevel 1 (
        echo MSVC environment initialization failed.
        exit /b 1
    )

    where cl

)


SET UPSTREAMURL=https://github.com/ShiftMediaProject
SET DEPENDENCIES=( ^
bzip2, ^
fontconfig, ^
freetype2, ^
fribidi, ^
game-music-emu, ^
gnutls, ^
harfbuzz, ^
lame, ^
libass, ^
libbluray, ^
libgcrypt, ^
libiconv, ^
libilbc, ^
liblzma, ^
libssh, ^
libxml2, ^
libvpx, ^
mfx_dispatch, ^
modplug, ^
opus, ^
sdl, ^
soxr, ^
speex, ^
theora, ^
vorbis, ^
zlib ^
)

SET PGOPTIONS=^
--enable-version3 ^
--enable-zlib ^
--enable-bzlib ^
--enable-lzma ^
--enable-static ^
--disable-shared ^
 ^
--disable-ffplay ^
--disable-sdl2 ^
--disable-opengl ^
--disable-vulkan ^
--disable-ffnvcodec ^
--disable-cuda ^
--disable-amf ^
--disable-libbluray ^
--disable-libxml2 ^
--disable-libmodplug ^
--disable-libtheora ^
--disable-libvorbis ^
--disable-libopus ^
--disable-libilbc ^
 ^
--disable-vaapi ^
--enable-w32threads ^
--disable-avfilter ^
--disable-postproc ^
--enable-avutil ^
--enable-avcodec ^
--enable-avformat ^
--enable-swresample ^
--enable-swscale ^
 ^
--disable-avdevice ^
--disable-programs ^
--disable-doc ^
--disable-debug ^
--disable-network ^
--disable-devices ^
--disable-encoders ^
 ^
--disable-decoders ^
--enable-decoder=rawvideo ^
--enable-decoder=aac ^
--enable-decoder=mp3 ^
--enable-decoder=flac ^
--enable-decoder=alac ^
--enable-decoder=ac3 ^
--enable-decoder=eac3 ^
--enable-decoder=dca ^
--enable-decoder=vorbis ^
--enable-decoder=pcm_s16le ^
--enable-decoder=pcm_s16be ^
--enable-decoder=pcm_s24le ^
--enable-decoder=pcm_s32le ^
--enable-decoder=pcm_f32le ^
--enable-decoder=h264 ^
--enable-decoder=hevc ^
--enable-decoder=vp8 ^
--enable-decoder=vp9 ^
--enable-decoder=av1 ^
--enable-decoder=mjpeg ^
 ^
--disable-parsers ^
--enable-parser=aac ^
--enable-parser=aac_latm ^
--enable-parser=mpegaudio ^
--enable-parser=flac ^
--enable-parser=ac3 ^
--enable-parser=dca ^
--enable-parser=h264 ^
--enable-parser=hevc ^
--enable-parser=vp8 ^
--enable-parser=vp9 ^
--enable-parser=mjpeg ^
--enable-parser=av1 ^
 ^
--enable-demuxers ^
--enable-hardcoded-tables ^
 ^
--disable-protocols ^
--enable-protocol=file ^
 ^
--disable-muxers ^
--enable-muxer=mp4

echo %PGOPTIONS%

REM Store current directory and ensure working directory is the location of current .bat
SET CURRDIR=%CD%
cd %~dp0

REM Initialise error check value
SET ERROR=0

REM Check if executable can be located
IF NOT EXIST "%BUILDER_DIR%\project_generate.exe" (
    ECHO "Error: FFVS Project Generator executable file not found."
    IF EXIST "../.git" (
        ECHO "Please build the executable using the supplied project before continuing."
    )
    GOTO exitOnError
)

REM Check if FFmpeg directory can be located
SET FFMPEGPATH=%FFMPEG_DIR%

REM Copy across the batch file used to auto get required dependencies
CALL :makeGetDeps || GOTO exit

REM Get/Update any used dependency libraries

IF /I "%GITHUB_ACTIONS%"=="true" (
    ECHO CI detected - auto updating dependencies
    ECHO.
    CALL :getDeps || GOTO exit
) ELSE (
    SET USERPROMPT=N
    SET /P USERPROMPT=Do you want to download/update the required dependency projects (Y/N)?
    IF /I "%USERPROMPT%"=="Y" (
        ECHO.
        CALL :getDeps || GOTO exit
        ECHO Ensure that any dependency projects have been built using the supplied project within the dependencies ./SMP folder before continuing.
        ECHO Warning: Some used dependencies require a manual download. Consult the readme for instructions to install the following needed components:
        ECHO    OpenGL
        PAUSE
    )
)


ECHO Build ffmepg dependencies...

set "MSBUILD_ARGS=^
/p:Configuration=Release ^
/p:ConfigurationType=%MSBUILD_CONFIG_TYPE% ^
/p:CLanguageStandard=Default ^
/p:DebugSymbols=false ^
/p:DebugType=None ^
/p:Platform=x64 ^
/p:VCToolsVersion=%VC_VERSION% ^
/p:WindowsTargetPlatformVersion=%WIN_SDK_VERSION%"


REM project_generate.exe --rootdir=%FFMPEG_DIR% --help
REM project_generate.exe --rootdir=%FFMPEG_DIR% --list-decoders 
SET FFMEPG_SLN=%FFMPEG_DIR%\SMP\ffmpeg.sln
SET libzlib_SLN=%SOURCE_DIR%\zlib\SMP\libzlib.sln
SET libbz2_SLN=%SOURCE_DIR%\bzip2\SMP\libbz2.sln
SET liblzma_SLN=%SOURCE_DIR%\liblzma\SMP\liblzma.sln

echo Start MSbuild ...

msbuild "%libzlib_SLN%" %MSBUILD_ARGS%
msbuild "%libbz2_SLN%" %MSBUILD_ARGS%
msbuild "%liblzma_SLN%" %MSBUILD_ARGS%

pushd "%BUILDER_DIR%"

project_generate.exe --rootdir=%FFMPEG_DIR% --help
REM Run the executable
ECHO Running project generator...
project_generate.exe --rootdir=%FFMPEG_DIR% %PGOPTIONS%

popd

@ECHO ON
REM msbuild "%FFMEPG_SLN%" -t:rebuild %MSBUILD_ARGS%
msbuild "%FFMEPG_SLN%" %MSBUILD_ARGS%
@ECHO OFF

if exist "%INSTALL_DIR%" (
    del /q "%INSTALL_DIR%\*" 2>nul
    for /d %%D in ("%INSTALL_DIR%\*") do rd /s /q "%%D"
) else (
    mkdir "%INSTALL_DIR%"
)

robocopy "%BUILDER_DIR%\msvc" "%INSTALL_DIR%" /S /MOVE
robocopy "%INSTALL_DIR%\lib\x64" "%INSTALL_DIR%\lib" /S /MOVE

rd "%INSTALL_DIR%\lib\x64" 2>nul

GOTO exit





:makeGetDeps
ECHO Creating project_get_dependencies.bat...
FOR %%I IN %DEPENDENCIES% DO SET LASTDEP=%%I
MKDIR "%FFMPEGPATH%/SMP" >NUL 2>&1
(
    ECHO @ECHO OFF
    ECHO SETLOCAL EnableDelayedExpansion
    ECHO.
    ECHO SET UPSTREAMURL=%UPSTREAMURL%
    ECHO SET DEPENDENCIES=( ^^
    FOR %%I IN %DEPENDENCIES% DO (
        IF "%%I"=="%LASTDEP%" (
            ECHO %%I ^^
        ) ELSE (
            ECHO %%I, ^^
        )
    )
    type "%BUILDER_DIR%\smp_project_get_dependencies"
) > "%FFMPEGPATH%/SMP/project_get_dependencies.bat"
ECHO.
EXIT /B %ERRORLEVEL%

:getDeps
REM Add current repo to list of already passed dependencies
ECHO Getting and updating any required dependency libs...
cd "%FFMPEGPATH%/SMP"
CALL project_get_dependencies.bat "ffmpeg" || EXIT /B 1
cd %~dp0
ECHO.
EXIT /B %ERRORLEVEL%

:exitOnError
SET ERROR=1

:exit
REM Check if this was launched from an existing terminal or directly from .bat
REM  If launched by executing the .bat then pause on completion
cd %CURRDIR%
ECHO %CMDCMDLINE% | FINDSTR /L %COMSPEC% >NUL 2>&1
IF %ERRORLEVEL% == 0 IF "%~1"=="" PAUSE
EXIT /B %ERROR%
