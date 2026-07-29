@echo off
cd /d "%~dp0"
echo.
echo ============================================================
echo   DITI365 - FILL THE MISSING DEMO DATA
echo ============================================================
echo.
echo 720 is resumable: every section checks its own table, so this
echo only creates what is still missing. Nothing is duplicated.
echo.
sqlcmd -S localhost -E -I -b -d Diti365_Dev -i scripts\720_seed_demo_transactions.sql
if errorlevel 1 (
    echo.
    echo   FAILED - the error is printed above.
) else (
    echo.
    echo   DONE
)
echo ============================================================
echo.
pause
