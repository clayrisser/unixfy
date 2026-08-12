@echo off
setlocal EnableExtensions

set "CWD=%cd%"
set "TOOLS=%~dp0"

if "%~1" == "" goto :usage
if "%~2" == "" goto :usage

call "%TOOLS%lib\validate_powershell.bat"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%lib\download.ps1" -url "%~1" -name "%~2" -cwd "%CWD%" -tools "%TOOLS%"
exit /b %ERRORLEVEL%

:usage
>&2 echo Usage: download.bat [url] [filename]
exit /b 2
