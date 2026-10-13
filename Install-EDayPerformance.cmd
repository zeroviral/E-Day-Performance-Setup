@echo off
setlocal
cd /d "%~dp0"
echo Gears of War: E-Day performance profiles
echo.
echo 1 - Maximum Performance
echo 2 - Enhanced Performance
echo.
choice /c 12 /n /m "Choose 1 or 2: "
if errorlevel 2 set "PROFILE=ENHANCED"
if errorlevel 1 set "PROFILE=MAXIMUM"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-EDayPerformance.ps1" -Profile "%PROFILE%"
if errorlevel 1 echo Installation failed.
if errorlevel 0 echo.
pause
