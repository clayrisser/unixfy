@echo off
set ROOT=%~dp0

call %ROOT%\tools\elevate.bat "%ROOT%\src\unixfy.bat"
echo Please restart your computer after the install finishes
