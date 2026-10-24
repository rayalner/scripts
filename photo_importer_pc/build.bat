@echo off
REM Build script for Photo Importer Windows executable

echo ================================
echo  Photo Importer Build Script
echo ================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed. Downloading Python installer...
    echo.

    REM Create temp directory
    if not exist "%TEMP%\photo_importer_build" mkdir "%TEMP%\photo_importer_build"

    REM Download Python installer using PowerShell
    echo Downloading Python 3.11.8 (64-bit)...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe' -OutFile '%TEMP%\photo_importer_build\python_installer.exe'}"

    if errorlevel 1 (
        echo ERROR: Failed to download Python installer
        echo Please manually install Python 3.8 or higher from https://www.python.org/
        pause
        exit /b 1
    )

    echo.
    echo Installing Python...
    echo IMPORTANT: The installer will open. Please check "Add Python to PATH" during installation!
    echo.
    pause

    REM Run installer with options to add to PATH
    "%TEMP%\photo_importer_build\python_installer.exe" /passive PrependPath=1 Include_pip=1

    echo.
    echo Waiting for installation to complete...
    timeout /t 10 /nobreak >nul

    REM Clean up
    del "%TEMP%\photo_importer_build\python_installer.exe"
    rmdir "%TEMP%\photo_importer_build"

    echo.
    echo Python installation complete. Please close this window and run build.bat again.
    echo If Python still isn't found, you may need to restart your computer.
    pause
    exit /b 0
)

echo [1/4] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [2/4] Cleaning previous builds...
if exist "build" rmdir /s /q build
if exist "dist" rmdir /s /q dist
if exist "*.spec" del /q *.spec

echo.
echo [3/4] Building executable with PyInstaller...
pyinstaller --onefile --windowed --name="Photo Importer" photo_importer.py
if errorlevel 1 (
    echo ERROR: Failed to build executable
    pause
    exit /b 1
)

echo.
echo [4/4] Build complete!
echo.
echo The executable is located at:
echo   dist\Photo Importer.exe
echo.
echo You can now distribute this .exe file without requiring Python installation.
echo.
pause
