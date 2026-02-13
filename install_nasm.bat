@echo OFF
setlocal

SET "CALLDIR=%CD%"
pushd %~dp0
SET "SCRIPT_DIR=%CD%"
popd

SET "VSNASM_DIR=%SCRIPT_DIR%\VSNASM"

if not exist "%VSNASM_DIR%" (
    echo Cloning VSNASM %FFMPEG_VERSION% ...
    git clone --depth 1 -v --progress -b 1.0 https://github.com/ShiftMediaProject/VSNASM.git "%VSNASM_DIR%"
    if errorlevel 1 (
        echo Clone failed, exiting.
        exit /b 1
    )
)

MSVC_VER=17
REM 64/32
SYSARCH=64


REM Defined script variables
set NASMDL=http://www.nasm.us/pub/nasm/releasebuilds
set NASMVERSION=3.01
set VSWHEREDL=https://github.com/Microsoft/vswhere/releases/download
set VSWHEREVERSION=3.1.7

if not exist "%VCINSTALLDIR%" (
    echo Error: Failed to get VCINSTALLDIR !
    goto Exit
)

REM Get the location of the current msbuild
powershell.exe -Command ((Get-Command msbuild.exe)[0].Path ^| Split-Path -parent) > "%SCRIPT_DIR%\msbuild.txt"
findstr /C:"Get-Command" "%SCRIPT_DIR%\msbuild.txt" >nul 2>&1
if not ERRORLEVEL 1 (
    echo Error: Failed to get location of msbuild!
    del /F /Q "%SCRIPT_DIR%\msbuild.txt" >nul 2>&1
    goto Terminate
)
set /p MSBUILDDIR=<"%SCRIPT_DIR%\msbuild.txt"
del /F /Q "%SCRIPT_DIR%\msbuild.txt" >nul 2>&1
if "%MSVC_VER%"=="18" (
    set VCTargetsPath="..\..\..\Microsoft\VC\v180\BuildCustomizations"
) else if "%MSVC_VER%"=="17" (
    set VCTargetsPath="..\..\..\Microsoft\VC\v170\BuildCustomizations"
) else if "%MSVC_VER%"=="16" (
    set VCTargetsPath="..\..\Microsoft\VC\v160\BuildCustomizations"
) else if "%MSVC_VER%"=="15" (
    set VCTargetsPath="..\..\..\Common7\IDE\VC\VCTargets\BuildCustomizations"
) else (
    if "%MSBUILDDIR%"=="%MSBUILDDIR:amd64=%" (
        set VCTargetsPath="..\..\Microsoft.Cpp\v4.0\V%MSVC_VER%0\BuildCustomizations"
    ) else (
        set VCTargetsPath="..\..\..\Microsoft.Cpp\v4.0\V%MSVC_VER%0\BuildCustomizations"
    )
)

REM Convert the relative targets path to an absolute one
set CURRDIR=%CD%
pushd %MSBUILDDIR% 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to get correct msbuild path!
    goto Terminate
)
pushd %VCTargetsPath% 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: Unknown VCTargetsPath path!
    goto Terminate
)
set VCTargetsPath=%CD%
popd
popd
if not "%CURRDIR%"=="%CD%" (
    echo Error: Failed to resolve VCTargetsPath!
    goto Terminate
)

echo VCTargetsPath: %VCTargetsPath%

REM copy the BuildCustomizations to VCTargets folder
echo Installing build customisations...
del /F /Q "%VCTargetsPath%\nasm.*" >nul 2>&1
copy /B /Y /V "%VSNASM_DIR%\nasm.*" "%VCTargetsPath%\" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to copy build customisations!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    goto Terminate
)
REM Check if nasm is already found before trying to download it
echo Checking for existing NASM in NASMPATH...
if exist "%NASMPATH%\nasm.exe" (
    "%NASMPATH%\nasm.exe" -v >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo "Using existing NASM binary from %NASMPATH%\nasm.exe..."
        goto SkipInstallNASM
    ) else (
        echo "..existing NASM not found in NASMPATH=%NASMPATH%."
    )
)
REM Download the latest nasm binary for windows
if exist "%VSNASM_DIR%\nasm_%NASMVERSION%.zip" (
    echo Using existing NASM archive...
    goto InstallNASM
)
set NASMDOWNLOAD=%NASMDL%/%NASMVERSION%/win%SYSARCH%/nasm-%NASMVERSION%-win%SYSARCH%.zip
echo Downloading required NASM release binary...
powershell.exe -Command "(New-Object Net.WebClient).DownloadFile('%NASMDOWNLOAD%', '%SCRIPT_DIR%\nasm_%NASMVERSION%.zip')" >nul 2>&1
if not exist "%SCRIPT_DIR%\nasm_%NASMVERSION%.zip" (
    echo Error: Failed to download required NASM binary!
    echo    The following link could not be resolved "%NASMDOWNLOAD%"
    goto Terminate
)

:InstallNASM
powershell.exe -Command Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('"%SCRIPT_DIR%\nasm_%NASMVERSION%.zip"', '"%SCRIPT_DIR%\TempNASMUnpack"') >nul 2>&1
if not exist "%SCRIPT_DIR%\TempNASMUnpack" (
    echo Error: Failed to unpack NASM download!
    del /F /Q "%SCRIPT_DIR%\nasm_.zip" >nul 2>&1
    goto Terminate
)

REM copy nasm executable to VC installation folder
echo Installing required NASM release binary...
del /F /Q "%VCINSTALLDIR%\nasm.exe" >nul 2>&1
copy /B /Y /V "%SCRIPT_DIR%\TempNASMUnpack\nasm-%NASMVERSION%\nasm.exe" "%VCINSTALLDIR%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to install NASM binary!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    rd /S /Q "%SCRIPT_DIR%\TempNASMUnpack" >nul 2>&1
    goto Terminate
)
rd /S /Q "%SCRIPT_DIR%\TempNASMUnpack" >nul 2>&1

:SkipInstallNASM
echo NASM binary:
if exist "%VCINSTALLDIR%\nasm.exe" (
    dir "%VCINSTALLDIR%\nasm.exe"
) else (
    echo NOT FOUND: %VCINSTALLDIR%\nasm.exe
)

echo.
echo BuildCustomizations files in VCTargetsPath:
if exist "%VCTargetsPath%" (
    dir "%VCTargetsPath%\nasm.*"
) else (
    echo NOT FOUND: %VCTargetsPath%
)
echo Finished Successfully
goto Exit

:Terminate
set ERROR=1

:Exit
cd %CALLDIR%
if "%CI%"=="" (
    if not defined ISINSTANCE (
        pause
    )
)
endlocal & exit /b %ERROR%