@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ==========================================
:: fetch_commit
:: %1 = git url
:: %2 = commit hash
:: %3 = target directory
:: %4 = branch (optional, default=main)
:: ==========================================

set GIT_URL=%~1
set COMMIT=%~2
set TARGET_DIR=%~3
set BRANCH=%~4
set ERROR_CODE=0

if "%BRANCH%"=="" set BRANCH=main

echo [INFO] Git URL   : %GIT_URL%
echo [INFO] Commit    : %COMMIT%
echo [INFO] TargetDir : %TARGET_DIR%
echo [INFO] Branch    : %BRANCH%

:: ---------- 参数校验 ----------
if "%GIT_URL%"==""  set ERROR_CODE=1 & goto cleanup
if "%COMMIT%"==""   set ERROR_CODE=2 & goto cleanup
if "%TARGET_DIR%"=="" set ERROR_CODE=3 & goto cleanup

:: ---------- 创建并进入目录 ----------
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if errorlevel 1 set ERROR_CODE=4 & goto cleanup

pushd "%TARGET_DIR%"
if errorlevel 1 set ERROR_CODE=5 & goto cleanup

:: ---------- 初始化 repo ----------
if not exist ".git" (
    git init || set ERROR_CODE=6
    if errorlevel 1 goto cleanup

    git remote add origin "%GIT_URL%" || set ERROR_CODE=7
    if errorlevel 1 goto cleanup
)

:: ---------- fetch 分支 ----------
git fetch origin %BRANCH%
if errorlevel 1 set ERROR_CODE=8 & goto cleanup

:: ---------- checkout commit ----------
git checkout %COMMIT%
if errorlevel 1 set ERROR_CODE=9 & goto cleanup

echo [SUCCESS] Checked out %COMMIT%
popd
endlocal
exit /b 0


:: ==========================================
:: cleanup（唯一失败出口）
:: ==========================================
:cleanup
popd >nul 2>&1

if "%TARGET_DIR%" NEQ "" (
    echo [CLEANUP] Removing %TARGET_DIR%
    rmdir /s /q "%TARGET_DIR%" 2>nul
)

endlocal
exit /b %ERROR_CODE%