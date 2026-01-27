@echo off
SET REPO_URL=https://github.com/Triveni-Ahmedabad/Triveni-Enterprise-Toolkit.git
SET PROJECT_DIR=Triveni-Control-Center
SET BUILD_DIR=Triveni-Build-Source

echo.
echo [ TRIVENI CMD BUILD SYSTEM - v1.13.0 ]
echo.

:: 1. Dependency Check
echo Checking Dependencies...
go version >nul 2>&1 || (echo ERROR: Go is not installed! & pause & exit /b)
node -v >nul 2>&1 || (echo ERROR: Node.js is not installed! & pause & exit /b)
wails version >nul 2>&1 || (echo ERROR: Wails is not installed! & pause & exit /b)
git --version >nul 2>&1 || (echo ERROR: Git is not installed! & pause & exit /b)
echo OK: All dependencies found.

:: 2. Clone/Update Source
if exist %BUILD_DIR% (
    echo Updating source code...
    cd %BUILD_DIR%
    git pull origin main
) else (
    echo Cloning repository...
    git clone %REPO_URL% %BUILD_DIR%
    cd %BUILD_DIR%
)

:: 3. Build Process
cd %PROJECT_DIR%
echo Starting Wails Build (v1.13.0)...
wails build -o Triveni-Enterprise-v1.13.0.exe

:: 4. Packaging
echo Packaging Final Binaries...
if exist "build\bin" (
    copy /y config.json "build\bin\"
    copy /y Triveni.png "build\bin\"
    echo.
    echo SUCCESS! Build ready in: %CD%\build\bin
    echo Executable: Triveni-Enterprise-v1.13.0.exe
) else (
    echo ERROR: Build failed!
)

pause
