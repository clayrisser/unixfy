param(
    [Parameter(Mandatory = $true)][string]$filename,
    [string]$cwd,
    [string]$tools,
    # Forces the 7-Zip fallback even when tar.exe is present, so the suite can
    # cover both extraction backends.
    [switch]$forceSevenZip
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if (-not $cwd) { $cwd = (Get-Location).Path }
if (-not $tools) { $tools = Split-Path -Parent $PSScriptRoot }

$script:failed = $false

function Write-Fail {
    param([string]$message)
    $script:failed = $true
    [Console]::Error.WriteLine("untar: $message")
}

function Get-SystemTar {
    # Windows 10 1803 and later ship bsdtar as %SystemRoot%\System32\tar.exe, and
    # it links liblzma, so it reads .tar.xz in a single pass.
    $root = $env:SystemRoot
    if (-not $root) { $root = 'C:\Windows' }
    $candidates = @(
        (Join-Path $root 'System32\tar.exe'),
        # A 32-bit PowerShell sees SysWOW64 through System32; Sysnative is the
        # only way back to the real 64-bit directory.
        (Join-Path $root 'Sysnative\tar.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Get-SevenZipModule {
    # Match any installed version. The original pinned 1.8.0, so the guard never
    # matched what Save-Module actually laid down and the module was re-downloaded
    # on every single run.
    $moduleRoot = Join-Path $tools 'lib\7Zip4Powershell'
    if (Test-Path -LiteralPath $moduleRoot) {
        $manifest = Get-ChildItem -Path $moduleRoot -Filter '7Zip4PowerShell.psd1' -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($manifest) { return $manifest.FullName }
    }
    return $null
}

function Expand-WithSevenZip {
    param([string]$archivePath, [string]$destination)

    if (-not (Get-Command Expand-7Zip -ErrorAction SilentlyContinue)) {
        $manifest = Get-SevenZipModule
        if (-not $manifest) {
            if (-not (Get-Command Save-Module -ErrorAction SilentlyContinue)) {
                Write-Fail 'no tar.exe and no PowerShellGet to install 7Zip4Powershell.'
                return
            }
            Write-Output 'Installing 7Zip4Powershell . . .'
            Save-Module -Name 7Zip4Powershell -Force -Path (Join-Path $tools 'lib')
            $manifest = Get-SevenZipModule
        }
        if (-not $manifest) {
            Write-Fail 'could not locate the 7Zip4Powershell module after installing it.'
            return
        }
        Import-Module $manifest
    }

    Expand-7Zip $archivePath $destination

    # 7-Zip peels one layer at a time: foo.tar.xz becomes foo.tar. Unwrap the
    # inner tarball here so callers see the same result as the tar.exe path.
    $leaf = Split-Path -Leaf $archivePath
    if ($leaf -match '\.tar\.(xz|gz|bz2|zst)$') {
        $innerName = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $innerPath = Join-Path $destination $innerName
        if (Test-Path -LiteralPath $innerPath) {
            Write-Output "Untaring $innerPath"
            Expand-7Zip $innerPath $destination
            Remove-Item -LiteralPath $innerPath -Force
        }
    }
}

function Invoke-Untar {
    param([string]$tarFileName)

    $archivePath = Join-Path $cwd $tarFileName
    if (-not (Test-Path -LiteralPath $archivePath)) {
        Write-Fail "$archivePath does not exist."
        return
    }

    $tar = $null
    if (-not $forceSevenZip.IsPresent) { $tar = Get-SystemTar }

    Write-Output "Untaring $archivePath"

    if ($tar) {
        Write-Output "Using $tar"
        & $tar -x -f $archivePath -C $cwd
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "$tar exited with $LASTEXITCODE"
            return
        }
        return
    }

    Write-Output 'tar.exe not found, falling back to 7Zip4Powershell'
    Expand-WithSevenZip $archivePath $cwd
}

try {
    Invoke-Untar $filename
} catch {
    Write-Fail $_.Exception.Message
}

if ($script:failed) { exit 1 }
exit 0
