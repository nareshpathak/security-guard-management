@echo off
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   DITI365 WEB - SETUP AND CHECK
echo ============================================================
echo.

where pnpm >nul 2>&1
if errorlevel 1 (
    echo [1/4] pnpm not found - installing it globally...
    call npm install -g pnpm@9.15.9
    if errorlevel 1 goto :fail
) else (
    echo [1/4] pnpm found
)

if not exist "apps\web\.env.local" (
    echo       creating apps\web\.env.local from the example
    copy /y "apps\web\.env.local.example" "apps\web\.env.local" >nul
)

echo [2/4] Installing packages ^(first run takes a few minutes^)...
call pnpm install
if errorlevel 1 goto :fail

echo [3/4] Trusting the ASP.NET development certificate...
call dotnet dev-certs https --trust >nul 2>&1
if errorlevel 1 (
    echo       could not trust it automatically - set DITI_ALLOW_SELF_SIGNED_API_CERT=true
    echo       in apps\web\.env.local if the login page cannot reach the API
) else (
    echo       trusted
)

echo [4/4] Typechecking and verifying every API call resolves...
call pnpm check
if errorlevel 1 (
    echo.
    echo   ERRORS ABOVE - nothing is broken yet, they just need fixing.
    goto :done
)

echo.
echo   ALL GREEN
echo.
echo   Start the API first, in another terminal:
echo       cd api ^&^& dotnet run --project src\Diti365.Api
echo   Then start the web app:
echo       pnpm dev
echo   And open http://localhost:3000
echo.
goto :done

:fail
echo.
echo   SETUP FAILED - the error is above.

:done
echo ============================================================
echo.
pause
