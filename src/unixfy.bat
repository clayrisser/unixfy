@set ROOT=%~dp0\..

if not exist "C:\mingw" mkdir "C:\mingw"
cd C:\mingw
call %ROOT%\tools\download.bat https://gigenet.dl.sourceforge.net/project/mingw/Installer/mingw-get/mingw-get-0.6.2-beta-20131004-1/mingw-get-0.6.2-mingw32-beta-20131004-1-bin.tar.xz mingw-get.tar.xz
call %ROOT%\tools\untar.bat mingw-get.tar.xz
call %ROOT%\tools\untar.bat mingw-get.tar
call C:\mingw\bin\mingw-get install gcc binutils mingw-runtime w32api mpc mpfr gmp pthreads zlib gettext gcc-core mpc mpfr gmp gcc-c++ gcc-objc gcc-fortran gcc-ada libexpat mingw32-make mingw-utils gdb msys
call %ROOT%\tools\add_to_path.bat C:\mingw\bin
call %ROOT%\tools\add_to_path.bat C:\mingw\msys\1.0\bin
call %ROOT%\tools\add_to_path.bat C:\mingw\mingw32\bin

