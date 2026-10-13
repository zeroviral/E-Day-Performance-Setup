@echo off
setlocal
cd /d "%~dp0"
echo Searching for E-Day settings files. This can take a minute...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Find-EDayConfig.ps1"
pause
