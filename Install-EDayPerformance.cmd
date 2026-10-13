@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-EDayPerformance.ps1"
if errorlevel 1 echo Installation failed.
if errorlevel 0 echo.
pause
