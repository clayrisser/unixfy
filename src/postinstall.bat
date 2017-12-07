set MSYS=%1
set MSYS=%MSYS: =%
set PACKAGES="bash"

C:\%MSYS%\usr\bin\bash -c "export http_proxy=%http_proxy% && export https_proxy=%https_proxy% && (echo yes) | pacman -S %PACKAGES%"
