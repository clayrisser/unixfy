@echo off
REM unixfy test suite.
REM
REM Deliberately covers only the pieces that cannot damage the machine it runs
REM on. The installer itself is not exercised here: it unpacks MSYS2 into C:\,
REM rewrites the persisted Path and runs pacman, none of which belongs in a test
REM run. add_to_path is tested against a throwaway key under
REM HKCU\Software\unixfy-test rather than the real environment.
setlocal EnableExtensions

set "TESTS=%~dp0"
set "ROOT=%TESTS%.."
set "TOOLS=%ROOT%\tools"
set "TESTKEY=HKCU\Software\unixfy-test"

if not defined UNIXFY_TEST_URL set "UNIXFY_TEST_URL=https://repo.msys2.org/distrib/README.txt"
if not defined UNIXFY_TEST_DEAD_URL set "UNIXFY_TEST_DEAD_URL=https://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20161025.tar.xz"
if not defined UNIXFY_TEST_WORK set "UNIXFY_TEST_WORK=%TEMP%\unixfy-tests"
set "WORK=%UNIXFY_TEST_WORK%"

set "PASSED=0"
set "FAILED=0"
set "SKIPPED=0"

rd /s /q "%WORK%" 2>nul
mkdir "%WORK%" 2>nul

echo unixfy test suite
echo   root      %ROOT%
echo   work      %WORK%
echo   machine   %PROCESSOR_ARCHITECTURE%
echo.

echo -- architecture detection --
call :arch_case AMD64 0 x86_64 msys64 0
call :arch_case ARM64 0 x86_64 msys64 1
call :arch_case x86 1
call :arch_case IA64 1
call :arch_case SPARC 1
call :test_arch_native
echo.

echo -- download --
call :test_download_ok
call :test_download_dead
call :test_download_usage
echo.

echo -- untar --
call :test_untar_targz
call :test_untar_missing
echo.

echo -- add_to_path --
call :test_path_setup
call :test_path_indirection
call :test_path_idempotent
call :test_path_dryrun
call :test_path_teardown
echo.

echo -- sleep --
call :test_no_sleep_binary
call :test_sleep_waits
echo.

echo ---------------------------------------
echo   passed  %PASSED%
echo   failed  %FAILED%
echo   skipped %SKIPPED%
echo ---------------------------------------

REM Keep the logs around when something went wrong, or when asked to.
if defined UNIXFY_TEST_KEEP goto :done
if not "%FAILED%" == "0" (
    echo   logs kept in %WORK%
    goto :done
)
rd /s /q "%WORK%" 2>nul

:done
if not "%FAILED%" == "0" exit /b 1
exit /b 0

REM ===========================================================================
REM helpers
REM ===========================================================================

:pass
set /a "PASSED+=1"
echo   PASS  %~1
goto :eof

:fail
set /a "FAILED+=1"
echo   FAIL  %~1
goto :eof

:skip
set /a "SKIPPED+=1"
echo   SKIP  %~1
goto :eof

REM :now [varname] - current clock as centiseconds since midnight
:now
set "T=%TIME%"
set "T=%T::=,%"
set "T=%T:.=,%"
set "T=%T: =0%"
for /f "tokens=1-4 delims=," %%a in ("%T%") do set /a "NOWCS=(((1%%a-100)*60+(1%%b-100))*60+(1%%c-100))*100+(1%%d-100)"
set "%~1=%NOWCS%"
goto :eof

REM ===========================================================================
REM architecture detection
REM ===========================================================================

REM :arch_case [forced arch] [expected exit] [msys2 arch] [msys dir] [emulated]
:arch_case
set "UNIXFY_FORCE_ARCH=%~1"
set "UNIXFY_ARCH="
set "UNIXFY_MSYS2_ARCH="
set "UNIXFY_MSYS_DIR="
set "UNIXFY_EMULATED="
call "%TOOLS%\detect_arch.bat" >"%WORK%\arch-%~1.log" 2>&1
set "RC=%ERRORLEVEL%"
set "UNIXFY_FORCE_ARCH="
if not "%RC%" == "%~2" (
    call :fail "%~1 - expected exit %~2 but got %RC%"
    goto :eof
)
if "%~2" == "1" (
    call :fail_unless_refused "%~1"
    goto :eof
)
if not "%UNIXFY_MSYS2_ARCH%" == "%~3" (
    call :fail "%~1 - expected msys2 arch %~3 but got %UNIXFY_MSYS2_ARCH%"
    goto :eof
)
if not "%UNIXFY_MSYS_DIR%" == "%~4" (
    call :fail "%~1 - expected dir %~4 but got %UNIXFY_MSYS_DIR%"
    goto :eof
)
if not "%UNIXFY_EMULATED%" == "%~5" (
    call :fail "%~1 - expected emulated=%~5 but got %UNIXFY_EMULATED%"
    goto :eof
)
call :pass "%~1 selects %UNIXFY_MSYS2_ARCH% into C:\%UNIXFY_MSYS_DIR%, emulated=%UNIXFY_EMULATED%"
goto :eof

:fail_unless_refused
REM An unsupported arch must refuse loudly and must not leave a target behind.
if defined UNIXFY_MSYS_DIR (
    call :fail "%~1 - refused but still exported UNIXFY_MSYS_DIR=%UNIXFY_MSYS_DIR%"
    goto :eof
)
findstr /c:"unixfy:" "%WORK%\arch-%~1.log" >nul 2>&1
if errorlevel 1 (
    call :fail "%~1 - refused without printing a reason"
    goto :eof
)
call :pass "%~1 is refused with a reason and exit 1"
goto :eof

:test_arch_native
set "UNIXFY_ARCH="
set "UNIXFY_MSYS2_ARCH="
set "UNIXFY_MSYS_DIR="
call "%TOOLS%\detect_arch.bat" >"%WORK%\arch-native.log" 2>&1
if errorlevel 1 (
    call :fail "this machine - detect_arch refused %PROCESSOR_ARCHITECTURE%"
    goto :eof
)
if not "%UNIXFY_MSYS2_ARCH%" == "x86_64" (
    call :fail "this machine - expected x86_64 but got %UNIXFY_MSYS2_ARCH%"
    goto :eof
)
call :pass "this machine, %PROCESSOR_ARCHITECTURE%, selects %UNIXFY_MSYS2_ARCH%"
goto :eof

REM ===========================================================================
REM download
REM ===========================================================================

:test_download_ok
pushd "%WORK%"
call "%TOOLS%\download.bat" "%UNIXFY_TEST_URL%" "ok.bin" >"%WORK%\download-ok.log" 2>&1
set "RC=%ERRORLEVEL%"
popd
if not "%RC%" == "0" (
    call :fail "live url - expected exit 0 but got %RC%"
    goto :eof
)
if not exist "%WORK%\ok.bin" (
    call :fail "live url - no file was written"
    goto :eof
)
set "SIZE=0"
for %%A in ("%WORK%\ok.bin") do set "SIZE=%%~zA"
if "%SIZE%" == "0" (
    call :fail "live url - wrote an empty file"
    goto :eof
)
if exist "%WORK%\ok.bin.part" (
    call :fail "live url - left a .part file behind"
    goto :eof
)
call :pass "live url downloads %SIZE% bytes and exits 0"
goto :eof

:test_download_dead
pushd "%WORK%"
call "%TOOLS%\download.bat" "%UNIXFY_TEST_DEAD_URL%" "dead.tar.xz" >"%WORK%\download-dead.log" 2>&1
set "RC=%ERRORLEVEL%"
popd
if "%RC%" == "0" (
    call :fail "dead url - reported success on a 404"
    goto :eof
)
if exist "%WORK%\dead.tar.xz" (
    call :fail "dead url - left a bogus output file behind"
    goto :eof
)
if exist "%WORK%\dead.tar.xz.part" (
    call :fail "dead url - left a .part file behind"
    goto :eof
)
findstr /c:"HTTP 404" "%WORK%\download-dead.log" >nul 2>&1
if errorlevel 1 (
    call :fail "dead url - did not report the HTTP status"
    goto :eof
)
findstr /c:"Time taken" "%WORK%\download-dead.log" >nul 2>&1
if not errorlevel 1 (
    call :fail "dead url - still printed a success timing line"
    goto :eof
)
call :pass "dead url fails with exit %RC%, reports HTTP 404, writes nothing"
goto :eof

:test_download_usage
call "%TOOLS%\download.bat" >"%WORK%\download-usage.log" 2>&1
set "RC=%ERRORLEVEL%"
if "%RC%" == "0" (
    call :fail "no arguments - expected a nonzero exit"
    goto :eof
)
call :pass "no arguments exits %RC% with usage"
goto :eof

REM ===========================================================================
REM untar
REM ===========================================================================

:test_untar_targz
set "FIX=%WORK%\untar"
mkdir "%FIX%" 2>nul
mkdir "%FIX%\payload" 2>nul
echo unixfy untar fixture>"%FIX%\payload\hello.txt"
pushd "%FIX%"
tar.exe -c -J -f sample.tar.xz payload >"%WORK%\untar-fixture.log" 2>&1
set "RC=%ERRORLEVEL%"
popd
if not "%RC%" == "0" (
    call :skip "tar.xz - no tar.exe on this machine to build a fixture"
    goto :eof
)
rd /s /q "%FIX%\payload"
pushd "%FIX%"
call "%TOOLS%\untar.bat" sample.tar.xz >"%WORK%\untar.log" 2>&1
set "RC=%ERRORLEVEL%"
popd
if not "%RC%" == "0" (
    call :fail "tar.xz - untar exited %RC%"
    goto :eof
)
if not exist "%FIX%\payload\hello.txt" (
    call :fail "tar.xz - archive contents were not restored"
    goto :eof
)
findstr /c:"unixfy untar fixture" "%FIX%\payload\hello.txt" >nul 2>&1
if errorlevel 1 (
    call :fail "tar.xz - restored file has the wrong contents"
    goto :eof
)
call :pass "tar.xz is extracted in a single pass"
goto :eof

:test_untar_missing
pushd "%WORK%"
call "%TOOLS%\untar.bat" definitely-not-here.tar.xz >"%WORK%\untar-missing.log" 2>&1
set "RC=%ERRORLEVEL%"
popd
if "%RC%" == "0" (
    call :fail "missing archive - reported success"
    goto :eof
)
call :pass "missing archive fails with exit %RC%"
goto :eof

REM ===========================================================================
REM add_to_path, against a throwaway key
REM ===========================================================================

:test_path_setup
reg delete "%TESTKEY%" /f >nul 2>&1
reg add "%TESTKEY%" /f /v Path /t REG_EXPAND_SZ /d "%%SystemRoot%%\system32;%%SystemRoot%%;%%USERPROFILE%%\bin" >nul 2>&1
if errorlevel 1 (
    call :fail "setup - could not seed %TESTKEY%"
    goto :eof
)
call :pass "seeded %TESTKEY% with an unexpanded Path"
goto :eof

:test_path_indirection
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\lib\add_to_path.ps1" -entry "C:\msys64\usr\bin" -key "%TESTKEY%" >"%WORK%\path-add.log" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%" == "0" (
    call :fail "indirection - add_to_path exited %RC%"
    goto :eof
)
reg query "%TESTKEY%" /v Path >"%WORK%\path-after.log" 2>&1
findstr /c:"REG_EXPAND_SZ" "%WORK%\path-after.log" >nul 2>&1
if errorlevel 1 (
    call :fail "indirection - value type is no longer REG_EXPAND_SZ"
    goto :eof
)
findstr /c:"C:\msys64\usr\bin;%%SystemRoot%%\system32;%%SystemRoot%%;%%USERPROFILE%%\bin" "%WORK%\path-after.log" >nul 2>&1
if errorlevel 1 (
    call :fail "indirection - value is not the entry prepended to the original raw string"
    goto :eof
)
findstr /c:"Wbem" "%WORK%\path-after.log" >nul 2>&1
if not errorlevel 1 (
    call :fail "indirection - machine Path was merged into the target key"
    goto :eof
)
call :pass "entry is prepended, SystemRoot indirection survives, machine Path is not merged"
goto :eof

:test_path_idempotent
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\lib\add_to_path.ps1" -entry "C:\msys64\usr\bin" -key "%TESTKEY%" >"%WORK%\path-again.log" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%" == "0" (
    call :fail "idempotent - second run exited %RC%"
    goto :eof
)
reg query "%TESTKEY%" /v Path >"%WORK%\path-after2.log" 2>&1
fc /b "%WORK%\path-after.log" "%WORK%\path-after2.log" >nul 2>&1
if errorlevel 1 (
    call :fail "idempotent - a second run changed the value"
    goto :eof
)
call :pass "re-adding the same entry is a no-op"
goto :eof

:test_path_dryrun
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\lib\add_to_path.ps1" -entry "C:\msys64" -key "%TESTKEY%" -dryRun >"%WORK%\path-dry.log" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%" == "0" (
    call :fail "dry run - exited %RC%"
    goto :eof
)
reg query "%TESTKEY%" /v Path >"%WORK%\path-after3.log" 2>&1
fc /b "%WORK%\path-after.log" "%WORK%\path-after3.log" >nul 2>&1
if errorlevel 1 (
    call :fail "dry run - modified the registry anyway"
    goto :eof
)
call :pass "dry run reports the change without writing it"
goto :eof

:test_path_teardown
reg delete "%TESTKEY%" /f >nul 2>&1
reg query "%TESTKEY%" >nul 2>&1
if not errorlevel 1 (
    call :fail "teardown - %TESTKEY% still exists"
    goto :eof
)
call :pass "removed %TESTKEY%"
goto :eof

REM ===========================================================================
REM sleep
REM ===========================================================================

:test_no_sleep_binary
where sleep >nul 2>&1
if not errorlevel 1 (
    call :skip "a sleep binary is on PATH here, so the old loop would have worked"
    goto :eof
)
call :pass "there is no sleep binary on PATH, which is what the old loop called"
goto :eof

:test_sleep_waits
call :now T0
call "%TOOLS%\sleep.bat" 3
call :now T1
set /a "ELAPSED=T1-T0"
if %ELAPSED% LSS 0 set /a "ELAPSED+=8640000"
if %ELAPSED% LSS 250 (
    call :fail "sleep 3 returned after %ELAPSED% centiseconds, it did not wait"
    goto :eof
)
if %ELAPSED% GTR 1000 (
    call :fail "sleep 3 took %ELAPSED% centiseconds, far longer than asked"
    goto :eof
)
call :pass "sleep 3 waited %ELAPSED% centiseconds"
goto :eof
