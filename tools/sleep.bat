@echo off
REM Usage: sleep.bat [seconds]
REM
REM Windows has no sleep binary, so a loop that shells out to "sleep 1" never
REM waits at all and spins the CPU instead. timeout is the right tool, but it
REM aborts with "input redirection is not supported" whenever stdin is not a
REM console, which is exactly what happens under CI and service accounts. ping
REM covers that case: -n N sends N packets one second apart.
setlocal EnableExtensions

if "%~1" == "" goto :usage

set /a "SECONDS=%~1" 2>nul
if not defined SECONDS goto :usage
if %SECONDS% LSS 1 set "SECONDS=1"

timeout /t %SECONDS% /nobreak >nul 2>&1
if not errorlevel 1 exit /b 0

set /a "PINGS=SECONDS+1"
ping -n %PINGS% 127.0.0.1 >nul 2>&1
exit /b 0

:usage
>&2 echo Usage: sleep.bat [seconds]
exit /b 2
