@echo off
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   DITI365 - VERIFY EVERYTHING
echo ============================================================
echo.

REM  Nothing here hides output. A step that fails should say why on
REM  screen, and a step that waits for a keypress should be visible
REM  rather than looking like a hang.

echo [1/4] API ^(.NET^)...
call "api\build.cmd" ci
if errorlevel 1 goto :fail

echo.
echo [2/4] Web ^(TypeScript^)...
call pnpm typecheck
if errorlevel 1 goto :fail
echo       typechecks clean

echo.
echo [3/4] Mobile ^(TypeScript^)...
call pnpm typecheck:mobile
if errorlevel 1 goto :fail
echo       typechecks clean

echo.
echo [4/4] Every API call resolves, and every endpoint is reachable...
call pnpm check:routes
if errorlevel 1 goto :fail
call node tools/coverage.mjs
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo   ALL GREEN
echo.
echo   Start everything:   start-all.cmd
echo   Run the phone app:  pnpm mobile
echo ============================================================
echo.
pause
goto :eof

:fail
echo.
echo ============================================================
echo   SOMETHING FAILED - the error is above.
echo ============================================================
echo.
pause
