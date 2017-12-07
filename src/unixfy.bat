@echo off
set ROOT=%~dp0..

cd C:\
set MSYS=msys32
set DOWNLOAD_URL=http://repo.msys2.org/distrib/i686/msys2-base-i686-20161025.tar.xz
IF "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
    set MSYS=msys64
    set DOWNLOAD_URL=http://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20161025.tar.xz
)
IF NOT EXIST "C:\%MSYS%\etc\pacman.d\gnupg\pubring.gpg" (
    call %ROOT%\tools\download.bat %DOWNLOAD_URL% %MSYS%.tar.xz
    call %ROOT%\tools\untar.bat %MSYS%.tar.xz
    del C:\%MSYS%.tar.xz
    call %ROOT%\tools\untar.bat %MSYS%.tar
    del C:\%MSYS%.tar
) ELSE (
    echo %MSYS% already installed
    echo If this is a mistake, please delete C:\%MSYS%
)
call %ROOT%\tools\add_to_path.bat C:\%MSYS%\usr\bin
call %ROOT%\tools\add_to_path.bat C:\%MSYS%
IF NOT EXIST "C:\%MSYS%\etc\pacman.d\gnupg\pubring.gpg" (
    @echo Initializing msys . . .
    C:\%MSYS%\msys2.exe
    GOTO waitloop
) ELSE (
    GOTO postinstall
)

:waitloop
IF NOT EXIST "C:\%MSYS%\etc\pacman.d\gnupg\pubring.gpg" (
    sleep 1
    GOTO waitloop
) ELSE (
    @echo Please wait 30 seconds while msys is setup . . .
    sleep 30
    GOTO postinstall
    echo Please restart your computer
)

:postinstall
call %ROOT%\src\postinstall.bat %MSYS%
