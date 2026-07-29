@echo off
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   DITI365 - REBUILD DATABASE AND API
echo ============================================================
echo.

echo [1/2] Database ^(new list procedures + the location fixes^)...
powershell -ExecutionPolicy Bypass -File "db\run-all.ps1"
if errorlevel 1 (
    echo.
    echo   DATABASE FAILED - the error is above.
    goto :done
)

echo.
echo [2/2] API...
call "api\build.cmd" ci

:done
echo.
echo ============================================================
echo   Next: start the API in another terminal
echo       cd api ^&^& dotnet run --project src\Diti365.Api
echo   Then:
echo       powershell -ExecutionPolicy Bypass -File api\smoke-test.ps1
echo ============================================================
echo.
