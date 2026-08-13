@echo off
setlocal EnableExtensions

set "CWD=%cd%"
set "TOOLS=%~dp0"

if "%~1" == "" goto :usage

call "%TOOLS%lib\validate_powershell.bat"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%lib\elevate.ps1" -cmd "%~1" -cwd "%CWD%" -tools "%TOOLS%"
exit /b %ERRORLEVEL%

:usage
>&2 echo Usage: elevate.bat [script]
exit /b 2
