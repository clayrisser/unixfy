param(
    [Parameter(Mandatory = $true)][string]$cmd,
    [string]$cwd,
    [string]$tools,
    [switch]$elevated
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if (-not $cwd) { $cwd = (Get-Location).Path }

function Write-Fail {
    param([string]$message)
    [Console]::Error.WriteLine("elevate: $message")
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Path -LiteralPath $cmd)) {
    Write-Fail "$cmd does not exist."
    exit 2
}

if (-not (Test-Admin)) {
    if ($elevated) {
        # This process is the elevated relaunch and it still is not elevated,
        # so relaunching again would only spin.
        Write-Fail 'failed to elevate.'
        exit 1
    }

    # -Wait plus -PassThru is what makes the exit code survive the trip through
    # a second process. The old call passed -noexit instead, which left the
    # elevated window open forever and gave the caller nothing to wait for or
    # read a status from, so a failed install looked exactly like a good one.
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$(Join-Path $PSScriptRoot 'elevate.ps1')`"",
        '-cmd', "`"$cmd`"",
        '-cwd', "`"$cwd`"",
        '-tools', "`"$tools`"",
        '-elevated'
    )

    try {
        $child = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -Wait `
            -ArgumentList $arguments
    } catch {
        # Raised when the UAC prompt is dismissed, and when the account cannot
        # elevate at all.
        Write-Fail $_.Exception.Message
        exit 1
    }

    exit $child.ExitCode
}

$code = 1
Push-Location -LiteralPath $cwd
try {
    & cmd.exe /c "`"$cmd`""
    $code = $LASTEXITCODE
} catch {
    Write-Fail $_.Exception.Message
} finally {
    Pop-Location
}

if ($elevated -and $code -ne 0) {
    # This window is about to close and take the only copy of the error with
    # it, so hold it open long enough for someone to read.
    Write-Fail "the command exited with code $code"
    try {
        [void](Read-Host 'Press Enter to close')
    } catch {
        # No console to read from; the caller still gets the exit code.
    }
}

exit $code
