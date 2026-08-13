@echo off
REM Works out which MSYS2 base image this machine can actually run.
REM
REM Exports to the caller:
REM   UNIXFY_ARCH       raw Windows architecture (AMD64 / ARM64 / x86 / ...)
REM   UNIXFY_MSYS2_ARCH MSYS2 flavour to install (x86_64)
REM   UNIXFY_MSYS_DIR   directory name the tarball unpacks into (msys64)
REM   UNIXFY_EMULATED   1 when MSYS2 will run under CPU emulation
REM
REM Exits 1 when MSYS2 cannot run here at all.

setlocal EnableExtensions

set "ARCH=%PROCESSOR_ARCHITECTURE%"
REM A 32-bit cmd.exe on a 64-bit OS reports x86; the real architecture of the
REM machine is only visible through PROCESSOR_ARCHITEW6432.
if defined PROCESSOR_ARCHITEW6432 set "ARCH=%PROCESSOR_ARCHITEW6432%"
REM Test hook: lets the suite exercise every branch on a single machine.
if defined UNIXFY_FORCE_ARCH set "ARCH=%UNIXFY_FORCE_ARCH%"

if /i "%ARCH%" == "AMD64" goto :amd64
if /i "%ARCH%" == "ARM64" goto :arm64
if /i "%ARCH%" == "x86" goto :x86
goto :unknown

:amd64
set "MSYS2_ARCH=x86_64"
set "MSYS_DIR=msys64"
set "EMULATED=0"
goto :done

:arm64
REM MSYS2 publishes no aarch64 base image; repo.msys2.org/distrib only carries
REM i686 and x86_64. Windows 11 on ARM runs x86_64 binaries under emulation, so
REM the x86_64 build is the correct (and only) choice here.
set "MSYS2_ARCH=x86_64"
set "MSYS_DIR=msys64"
set "EMULATED=1"
goto :done

:x86
>&2 echo unixfy: 32-bit Windows (x86) is not supported.
>&2 echo unixfy: MSYS2 dropped the 32-bit MSYS environment on 2020-05-17 and the
>&2 echo unixfy: i686 tree has been frozen since. Install 64-bit Windows instead.
>&2 echo unixfy: https://www.msys2.org/news/#2020-05-17-32-bit-msys2-no-longer-actively-supported
endlocal & exit /b 1

:unknown
>&2 echo unixfy: unsupported processor architecture "%ARCH%".
>&2 echo unixfy: MSYS2 only ships i686 and x86_64 base images, and only x86_64 is
>&2 echo unixfy: still supported. Nothing to install.
endlocal & exit /b 1

:done
endlocal & set "UNIXFY_ARCH=%ARCH%" & set "UNIXFY_MSYS2_ARCH=%MSYS2_ARCH%" & set "UNIXFY_MSYS_DIR=%MSYS_DIR%" & set "UNIXFY_EMULATED=%EMULATED%" & exit /b 0
