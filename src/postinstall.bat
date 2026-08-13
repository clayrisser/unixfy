@echo off
setlocal EnableExtensions

set "MSYS=%~1"
if not defined MSYS goto :usage
if not exist "C:\%MSYS%\usr\bin\bash.exe" (
    >&2 echo postinstall: C:\%MSYS%\usr\bin\bash.exe is missing
    exit /b 1
)

set "PACKAGES=bash"

REM --noconfirm rather than piping a single "yes": pacman can ask more than one
REM question, and the old pipe only ever answered the first.
"C:\%MSYS%\usr\bin\bash.exe" -c "export http_proxy='%http_proxy%'; export https_proxy='%https_proxy%'; pacman -S --needed --noconfirm %PACKAGES%"
if errorlevel 1 (
    >&2 echo postinstall: pacman failed
    exit /b 1
)
exit /b 0

:usage
>&2 echo Usage: postinstall.bat [msys directory name]
exit /b 2
