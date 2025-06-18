@echo off
:: Script to perform SFC and DISM scans and repairs

:: Elevate the script to run as administrator
:: If not running as admin, relaunch as admin
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo This script requires administrator privileges.
    echo.
    echo Attempting to relaunch as administrator...
    PowerShell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

echo ===================================================
echo Starting DISM and SFC Scans and Repairs
echo ===================================================

:: Step 1: Check system image health using DISM
echo Checking system health...
DISM /Online /Cleanup-Image /CheckHealth
if %ERRORLEVEL% NEQ 0 (
    echo Error occurred during /CheckHealth. Exiting.
    pause
    exit /b
)

:: Step 2: Scan system image health using DISM
echo Scanning system health...
DISM /Online /Cleanup-Image /ScanHealth
if %ERRORLEVEL% NEQ 0 (
    echo Error occurred during /ScanHealth. Exiting.
    pause
    exit /b
)

:: Step 3: Repair system image using DISM
echo Repairing system image (if necessary)...
DISM /Online /Cleanup-Image /RestoreHealth
if %ERRORLEVEL% NEQ 0 (
    echo Error occurred during /RestoreHealth. Exiting.
    pause
    exit /b
)

:: Step 4: Run SFC to check and repair system files
echo Running System File Checker (SFC)...
sfc /scannow
if %ERRORLEVEL% NEQ 0 (
    echo SFC found errors but couldn't fix them. Consider reviewing the log file at %windir%\Logs\CBS\CBS.log.
) else (
    echo SFC scan completed successfully, and all issues were resolved.
)

echo ===================================================
echo All operations completed.
echo Press any key to exit.
pause
exit