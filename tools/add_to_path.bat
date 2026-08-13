@echo off
REM Usage: add_to_path.bat [directory] [Auto|User|Machine]
REM
REM Prepends a single directory to the persisted Path. The registry value is read
REM back unexpanded, so entries such as %SystemRoot%\system32 survive as
REM indirections instead of being frozen to whatever they resolve to today.
setlocal EnableExtensions

set "TOOLS=%~dp0"

if "%~1" == "" goto :usage

set "SCOPE=%~2"
if not defined SCOPE set "SCOPE=Auto"

call "%TOOLS%lib\validate_powershell.bat"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%lib\add_to_path.ps1" -entry "%~1" -scope "%SCOPE%"
if errorlevel 1 exit /b %ERRORLEVEL%

REM Make it usable in the current session too; every other shell picks it up on
REM its next start.
endlocal & set "PATH=%~1;%PATH%"
exit /b 0

:usage
>&2 echo Usage: add_to_path.bat [directory] [Auto^|User^|Machine]
exit /b 2
