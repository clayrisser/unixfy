@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"

call "%ROOT%tools\elevate.bat" "%ROOT%src\unixfy.bat"
set "RC=%ERRORLEVEL%"
if not "%RC%" == "0" (
    >&2 echo unixfy: install failed with exit code %RC%
    exit /b %RC%
)

echo unixfy: restart your computer once the install finishes
exit /b 0
