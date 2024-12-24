// setup.bat - For Windows
@echo off
echo Setting up Keystore Manager...

:: Check if running with admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
) else (
    echo Please run this script as administrator
    pause
    exit /b 1
)

:: Get the current directory
set CURRENT_DIR=%~dp0

:: Add to system PATH
setx PATH "%PATH%;%CURRENT_DIR%" /M

:: Activate the package globally
call dart pub global activate --source path .

echo.
echo Setup completed successfully!
echo You can now use the 'keystore' command from anywhere.
echo Please restart your terminal for changes to take effect.
pause