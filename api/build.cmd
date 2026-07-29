@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM ---------------------------------------------------------------
REM  Pass any argument (verify-all.cmd passes "ci") to skip the
REM  pause at the end. Without that, a caller that redirects output
REM  sits waiting for a keypress it cannot see, and looks hung.
REM ---------------------------------------------------------------
set NOPAUSE=%1

echo.
echo ============================================================
echo   DITI365 API - BUILD
echo ============================================================
echo.

REM ---------------------------------------------------------------
REM  A running API holds its own DLLs open, which makes the build
REM  fail with MSB3021 / MSB3027 "file is being used by another
REM  process". Those are not code errors. Stop it first.
REM ---------------------------------------------------------------
echo [1/3] Stopping any running API...
taskkill /IM Diti365.Api.exe /F >nul 2>&1 && echo       stopped Diti365.Api.exe || echo       nothing was running
taskkill /IM dotnet.exe /FI "WINDOWTITLE eq Diti365*" /F >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/3] Building...
dotnet build -clp:ErrorsOnly;NoSummary > build.log 2>&1
set BUILD_EXIT=%ERRORLEVEL%

echo [3/3] Result
echo ------------------------------------------------------------
if %BUILD_EXIT%==0 (
    echo.
    echo   BUILD SUCCEEDED
    echo.
    echo   Run the API with:
    echo       dotnet run --project src\Diti365.Api
    echo   Then open https://localhost:7175/swagger
    echo.
) else (
    echo.
    echo   BUILD FAILED - errors below, full log in build.log
    echo.
    findstr /C:"error " build.log
    echo.
    echo ------------------------------------------------------------
    for /f %%C in ('findstr /C:"error " build.log ^| find /c /v ""') do echo   %%C error line^(s^). Full output: api\build.log
    echo.
)
echo ============================================================
echo.

if not "%NOPAUSE%"=="" exit /b %BUILD_EXIT%
pause
exit /b %BUILD_EXIT%
