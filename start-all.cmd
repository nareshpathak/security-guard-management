@echo off
setlocal
cd /d "%~dp0"

REM ---------------------------------------------------------------
REM  Opens the API and the web app in their own windows.
REM
REM  Both need to keep running at the same time, which is why they
REM  cannot share one window: whichever started first would hold it.
REM ---------------------------------------------------------------

echo.
echo ============================================================
echo   DITI365 - START EVERYTHING
echo ============================================================
echo.

echo Stopping anything already running...
taskkill /IM Diti365.Api.exe /F >nul 2>&1
echo.

echo Opening window 1: the API   ^(https://localhost:7175^)
start "Diti365 API" cmd /k "cd /d "%~dp0api" && dotnet run --project src\Diti365.Api"

echo Waiting for the API to come up...
timeout /t 12 /nobreak >nul

echo Opening window 2: the web app  ^(http://localhost:3000^)
start "Diti365 Web" cmd /k "cd /d "%~dp0" && pnpm dev"

echo Waiting for the web app to compile...
timeout /t 12 /nobreak >nul

echo Opening the browser...
start "" http://localhost:3000

echo.
echo ============================================================
echo   Two new windows are now open. Leave them running.
echo.
echo   Sign in with:
echo       diti.admin  /  Admin@123
echo.
echo   To stop everything, close both windows.
echo ============================================================
echo.
pause
