@echo off
setlocal
title Prepare Project for MonkeyCode
color 0A

echo.
echo ================================================
echo       PREPARE PROJECT FOR MONKEYCODE
echo ================================================
echo.

cd /d "%~dp0"

echo Project:
echo %CD%
echo.

REM -----------------------------------------------
REM 1. Check Git
REM -----------------------------------------------

where git >nul 2>&1

if errorlevel 1 (
    echo ERROR: Git is not installed or not in PATH.
    echo Install Git first, then run this file again.
    pause
    exit /b 1
)

echo [OK] Git detected.

REM -----------------------------------------------
REM 2. Protect files AI should not need
REM -----------------------------------------------

if not exist ".gitignore" (
    echo Creating .gitignore...

    (
        echo # Dependencies
        echo node_modules/
        echo.
        echo # .NET
        echo bin/
        echo obj/
        echo.
        echo # Next.js
        echo .next/
        echo out/
        echo.
        echo # Build
        echo dist/
        echo build/
        echo.
        echo # Secrets
        echo .env
        echo .env.*
        echo !.env.example
        echo.
        echo # IDE
        echo .vs/
        echo .vscode/
        echo.
        echo # Logs
        echo *.log
        echo.
        echo # OS
        echo Thumbs.db
        echo .DS_Store
    ) > ".gitignore"

    echo [OK] .gitignore created.
) else (
    echo [OK] Existing .gitignore preserved.
)

REM -----------------------------------------------
REM 3. Git repository
REM -----------------------------------------------

if not exist ".git" (
    echo.
    echo Initializing Git...
    git init

    if errorlevel 1 goto :ERROR

    git branch -M main

    echo [OK] Git initialized.
) else (
    echo [OK] Git repository already exists.
)

REM -----------------------------------------------
REM 4. Show files before commit
REM -----------------------------------------------

echo.
echo Checking repository status...
git status --short

echo.
echo IMPORTANT:
echo Make sure passwords, API keys, connection-string
echo secrets and .env files are NOT being committed.
echo.
pause

REM -----------------------------------------------
REM 5. Initial checkpoint
REM -----------------------------------------------

git add .

git diff --cached --quiet

if errorlevel 1 (
    git commit -m "Checkpoint before MonkeyCode AI work"

    if errorlevel 1 (
        echo.
        echo Commit could not be created.
        echo Git username/email may need configuration.
        goto :ERROR
    )

    echo [OK] Safety checkpoint created.
) else (
    echo [OK] Nothing new to commit.
)

REM -----------------------------------------------
REM 6. Create AI working branch
REM -----------------------------------------------

git show-ref --verify --quiet refs/heads/ai/monkeycode-completion

if errorlevel 1 (
    git checkout -b ai/monkeycode-completion
) else (
    git checkout ai/monkeycode-completion
)

if errorlevel 1 goto :ERROR

echo [OK] AI branch ready.

REM -----------------------------------------------
REM 7. Remote repository
REM -----------------------------------------------

git remote get-url origin >nul 2>&1

if errorlevel 1 (

    echo.
    echo Paste your PRIVATE GitHub repository URL.
    echo Example:
    echo https://github.com/USERNAME/security-guard-management.git
    echo.

    set /p REPO_URL=GitHub Repo URL: 

    if "%REPO_URL%"=="" (
        echo ERROR: Repository URL cannot be empty.
        goto :ERROR
    )

    git remote add origin "%REPO_URL%"

    if errorlevel 1 goto :ERROR

) else (
    echo [OK] GitHub origin already configured.
)

REM -----------------------------------------------
REM 8. Push main + AI branch
REM -----------------------------------------------

echo.
echo Uploading repository...

git push -u origin main

if errorlevel 1 (
    echo.
    echo Main push failed.
    echo GitHub authentication or remote repository
    echo configuration may be required.
    goto :ERROR
)

git push -u origin ai/monkeycode-completion

if errorlevel 1 goto :ERROR

echo.
echo ================================================
echo              PROJECT READY
echo ================================================
echo.
echo Branch:
echo ai/monkeycode-completion
echo.
echo NEXT:
echo Open MonkeyCode and connect this PRIVATE repo.
echo.
echo Do NOT ask MonkeyCode to complete everything
echo in one task.
echo.

pause
exit /b 0


:ERROR

echo.
echo ================================================
echo                 ERROR
echo ================================================
echo.
echo Read the message above.
echo Nothing will be deleted automatically.
echo.

pause
exit /b 1