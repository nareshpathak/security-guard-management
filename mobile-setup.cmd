@echo off
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   DITI365 MOBILE - SETUP AND CHECK
echo ============================================================
echo.

if not exist "apps\mobile\.env" (
    echo Creating apps\mobile\.env from the example...
    copy /y "apps\mobile\.env.example" "apps\mobile\.env" >nul
    echo.
    echo   IMPORTANT: a phone cannot reach "localhost".
    echo   Edit apps\mobile\.env and set your machine's LAN address, e.g.
    echo       EXPO_PUBLIC_API_BASE_URL=https://192.168.1.5:7175
    echo.
)

echo [1/2] Installing packages...
call pnpm install
if errorlevel 1 goto :fail

echo [2/2] Typechecking the mobile app...
call pnpm typecheck:mobile
if errorlevel 1 (
    echo.
    echo   TYPE ERRORS ABOVE - they need fixing before the app will run.
    goto :done
)

echo.
echo   ALL GREEN
echo.
echo   To run it on a phone:
echo       pnpm --filter mobile exec expo start
echo   then scan the QR code with Expo Go, or press "a" for an emulator.
echo.

:done
echo ============================================================
echo.
pause
goto :eof

:fail
echo.
echo   SETUP FAILED - the error is above.
echo ============================================================
pause
