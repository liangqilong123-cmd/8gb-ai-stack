@echo off
title Local AI Engine Starter
rem ASCII-only launcher (see docs/troubleshooting: non-ASCII in .bat breaks cmd parsing).
rem Edit ENGINE and SCRIPT below to match your install.

set "ENGINE=ninfer-serve.exe"
set "SCRIPT=%~dp0ninfer-start.ps1"

tasklist /FI "IMAGENAME eq %ENGINE%" 2>nul | find /I "%ENGINE%" >nul
if %ERRORLEVEL%==0 (
    echo [!] Engine is ALREADY running.
    echo     API: http://127.0.0.1:8091/v1
    echo     Close the other engine window to restart.
    pause
    exit /b 0
)

echo Starting engine ...
echo API: http://127.0.0.1:8091/v1
echo Keep this window OPEN. Closing it STOPS the engine.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
pause
