@echo off
setlocal EnableExtensions

set "CWD=%cd%"
set "TOOLS=%~dp0"

if "%~1" == "" goto :usage

call "%TOOLS%lib\validate_powershell.bat"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%lib\untar.ps1" -filename "%~1" -cwd "%CWD%" -tools "%TOOLS%" %2 %3
exit /b %ERRORLEVEL%

:usage
>&2 echo Usage: untar.bat [archive] [-forceSevenZip]
exit /b 2
