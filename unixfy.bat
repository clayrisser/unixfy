@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"

call "%ROOT%tools\elevate.bat" "%ROOT%src\unixfy.bat"
echo unixfy: restart your computer once the install finishes
exit /b 0
