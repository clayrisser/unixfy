# unixfy

Turn your Windows machine into a POSIX compatible unix-like system.

unixfy unpacks an [MSYS2](https://www.msys2.org/) base image into `C:\msys64`,
puts its `usr\bin` on the persisted `Path`, lets MSYS2 run its first-time setup,
and then installs a starter package set with `pacman`. After that `bash`, `ls`,
`grep`, `ssh`, `make` and the rest of the userland are available from a plain
`cmd.exe` prompt.

## Should you use this in 2026?

Probably not, and it is worth being honest about why. When this was written,
bolting MSYS2 onto Windows by hand was a reasonable way to get a unix userland.
Since then Windows has absorbed most of the problem:

- **WSL2** gives you a real Linux kernel and a real distro. `wsl --install` is
  one command, it is supported by Microsoft, and it is what you want for almost
  any development workflow.
- **winget** ships in Windows and installs MSYS2 directly:
  `winget install MSYS2.MSYS2`. That handles upgrades too.
- **`curl.exe` and `tar.exe` ship in `System32`** on Windows 10 1803 and later,
  so the download-and-unpack half of this project is now a one-liner with tools
  you already have. `tar.exe` is bsdtar linked against liblzma, so it reads
  `.tar.xz` natively.

unixfy is still useful in the narrow case where you want a scripted, no-installer,
no-WSL, no-package-manager way to drop MSYS2 onto a machine from a batch file,
for example on a locked-down build agent. That is the case it is maintained for.

## Requirements

- 64-bit Windows. MSYS2
  [dropped the 32-bit MSYS environment on 2020-05-17](https://www.msys2.org/news/#2020-05-17-32-bit-msys2-no-longer-actively-supported),
  so unixfy refuses to run on 32-bit Windows rather than installing something
  that cannot be updated.
- Windows on ARM works. MSYS2 publishes no native ARM64 base image, so unixfy
  installs the x86_64 build and Windows runs it under x64 emulation.
- PowerShell 3.0 or newer.
- Administrator rights, because the install writes to `C:\` and to the machine
  `Path`.

## Usage

Run the installer from an Administrator prompt:

```bat
unixfy.bat
```

Then restart, or at least open a new shell, so the updated `Path` is picked up.

To install a specific MSYS2 build instead of the current one, or to pull from an
internal mirror:

```bat
set UNIXFY_MSYS2_URL=https://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20260611.tar.xz
unixfy.bat
```

## Tools

The pieces are usable on their own. Each one exits nonzero when it fails.

```bat
tools\download.bat https://example.com/some.zip some.zip
tools\unzip.bat some.zip

tools\download.bat https://example.com/some.tar.xz some.tar.xz
tools\untar.bat some.tar.xz

tools\add_to_path.bat C:\msys64\usr\bin
tools\detect_arch.bat
tools\sleep.bat 5
```

| Tool | What it does |
| --- | --- |
| `tools\detect_arch.bat` | Exports `UNIXFY_ARCH`, `UNIXFY_MSYS2_ARCH`, `UNIXFY_MSYS_DIR` and `UNIXFY_EMULATED`. Exits 1 on an architecture MSYS2 cannot run on. |
| `tools\download.bat` | Downloads a URL to a file. Fails loudly on any HTTP error and leaves no partial file behind. |
| `tools\untar.bat` | Extracts a tarball. Uses `System32\tar.exe` when present, falls back to the `7Zip4Powershell` module on older Windows. |
| `tools\unzip.bat` | Extracts a zip with `System.IO.Compression`. |
| `tools\add_to_path.bat` | Prepends one directory to the persisted `Path`. |
| `tools\sleep.bat` | Waits N seconds without spinning the CPU. |
| `tools\elevate.bat` | Re-runs a command elevated. |

### add_to_path

`add_to_path.bat` reads the existing `Path` back out of the registry
**unexpanded**, so entries like `%SystemRoot%\system32` stay as indirections
instead of being frozen into `C:\Windows\system32`. It writes back with the value
type the key already had, and it only ever touches one scope, so the machine
`Path` never gets copied into the user `Path`.

```bat
tools\add_to_path.bat C:\msys64\usr\bin           REM Machine when elevated, otherwise User
tools\add_to_path.bat C:\msys64\usr\bin User
tools\add_to_path.bat C:\msys64\usr\bin Machine
```

The underlying script also takes `-dryRun`, which prints the before and after
values without writing anything, and `-key`, which points it at a different
registry key. Both exist so the change can be checked before it is made:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lib\add_to_path.ps1 ^
  -entry C:\msys64\usr\bin -dryRun
```

## Tests

```bat
tests\run_tests.bat
```

The suite covers architecture detection across every branch, downloads against a
live URL and a dead one, `.tar.xz` extraction, and `add_to_path` against a
throwaway key under `HKCU\Software\unixfy-test`. It never touches the real `Path`
and never runs the installer, since the installer's whole job is to modify the
machine it runs on.

## License

MIT. See [LICENSE](LICENSE).
