@echo off
echo.
echo [ TRIVENI LOCAL BUILDER - v1.18.0 ]
echo ===================================
echo.

:: 1. Navigate to right folder
cd /d "%~dp0"

:: 2. Create build directory if missing
if not exist "build\bin" mkdir "build\bin"

:: 3. Build Process
echo Starting Wails Build (v1.18.0)...
wails build -o Triveni-Enterprise-v1.18.0.exe
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Wails build failed!
    pause
    exit /b
)

:: 4. Packaging
echo Packaging files...
copy /y config.json "build\bin\"
copy /y Triveni.png "build\bin\"
if exist "Triveni-Enterprise-v1.18.0.exe" (
    move /y "Triveni-Enterprise-v1.18.0.exe" "build\bin\"
)

echo.
echo SUCCESS! 
echo Build Folder: %CD%\build\bin
echo Executable: Triveni-Enterprise-v1.18.0.exe
explorer "%CD%\build\bin"

pause














