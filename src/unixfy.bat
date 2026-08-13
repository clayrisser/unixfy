@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."

call "%ROOT%\tools\detect_arch.bat"
if errorlevel 1 exit /b 1

set "MSYS=%UNIXFY_MSYS_DIR%"
REM MSYS2 stopped publishing the dated tarballs this script used to hardcode, and
REM both of those URLs now 404. The -latest alias is the supported stable entry
REM point; override UNIXFY_MSYS2_URL to pin a dated build or an internal mirror.
if not defined UNIXFY_MSYS2_URL set "UNIXFY_MSYS2_URL=https://repo.msys2.org/distrib/msys2-%UNIXFY_MSYS2_ARCH%-latest.tar.xz"
set "MSYS_MARKER=C:\%MSYS%\etc\pacman.d\gnupg\pubring.gpg"

echo unixfy: %UNIXFY_ARCH% detected, installing the %UNIXFY_MSYS2_ARCH% MSYS2 base into C:\%MSYS%
if "%UNIXFY_EMULATED%" == "1" echo unixfy: MSYS2 has no native ARM64 build, so this runs under Windows x64 emulation

cd /d C:\
if errorlevel 1 (
    >&2 echo unixfy: could not switch to C:\
    exit /b 1
)

if exist "%MSYS_MARKER%" (
    echo unixfy: %MSYS% is already installed
    echo unixfy: if that is wrong, delete C:\%MSYS% and run unixfy again
    goto :addpath
)

if exist "C:\%MSYS%\msys2.exe" (
    echo unixfy: C:\%MSYS% is already unpacked, skipping the download
    goto :addpath
)

call "%ROOT%\tools\download.bat" "%UNIXFY_MSYS2_URL%" "%MSYS%.tar.xz"
if errorlevel 1 (
    >&2 echo unixfy: could not download %UNIXFY_MSYS2_URL%
    exit /b 1
)

REM tar.exe reads .tar.xz in one pass, and the 7-Zip fallback unwraps the inner
REM tarball itself, so this is a single call either way.
call "%ROOT%\tools\untar.bat" "%MSYS%.tar.xz"
if errorlevel 1 (
    >&2 echo unixfy: could not extract %MSYS%.tar.xz
    exit /b 1
)
del "C:\%MSYS%.tar.xz" 2>nul

if not exist "C:\%MSYS%\msys2.exe" (
    >&2 echo unixfy: C:\%MSYS% is missing after extraction
    exit /b 1
)

:addpath
call "%ROOT%\tools\add_to_path.bat" "C:\%MSYS%\usr\bin"
if errorlevel 1 (
    >&2 echo unixfy: could not add C:\%MSYS%\usr\bin to Path
    exit /b 1
)
call "%ROOT%\tools\add_to_path.bat" "C:\%MSYS%"
if errorlevel 1 (
    >&2 echo unixfy: could not add C:\%MSYS% to Path
    exit /b 1
)

if exist "%MSYS_MARKER%" goto :postinstall

echo unixfy: initializing MSYS2 . . .
"C:\%MSYS%\msys2.exe"
set "WAITED=0"

REM The old loop called a sleep binary that does not exist on Windows, so it
REM failed instantly every iteration and pegged a core until MSYS2 was ready.
:waitloop
if exist "%MSYS_MARKER%" goto :settled
set /a "WAITED+=1"
if %WAITED% GEQ 300 (
    >&2 echo unixfy: gave up waiting for MSYS2 to create %MSYS_MARKER%
    exit /b 1
)
call "%ROOT%\tools\sleep.bat" 1
goto :waitloop

:settled
echo unixfy: waiting 30 seconds while MSYS2 finishes its first-run setup . . .
call "%ROOT%\tools\sleep.bat" 30

:postinstall
call "%ROOT%\src\postinstall.bat" "%MSYS%"
exit /b %ERRORLEVEL%
