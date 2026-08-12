param(
    [Parameter(Mandatory = $true)][string]$entry,
    [ValidateSet('Auto', 'User', 'Machine')][string]$scope = 'Auto',
    # Overrides the registry key that gets edited. Only meant for the test suite,
    # which points this at a throwaway key instead of the real environment.
    [string]$key = '',
    [ValidateSet('Prepend', 'Append')][string]$position = 'Prepend',
    [switch]$dryRun
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$MACHINE_KEY = 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
$USER_KEY = 'HKCU\Environment'

$script:failed = $false

function Write-Fail {
    param([string]$message)
    $script:failed = $true
    [Console]::Error.WriteLine("add_to_path: $message")
}

function Test-Admin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal $identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch {
        return $false
    }
}

function Resolve-Key {
    param([string]$path)
    $normalized = $path -replace '^Registry::', ''
    $normalized = $normalized -replace '^(HKLM|HKEY_LOCAL_MACHINE):?\\', 'HKLM\'
    $normalized = $normalized -replace '^(HKCU|HKEY_CURRENT_USER):?\\', 'HKCU\'
    if ($normalized -like 'HKLM\*') {
        return @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; SubKey = $normalized.Substring(5); Display = $normalized }
    }
    if ($normalized -like 'HKCU\*') {
        return @{ Hive = [Microsoft.Win32.Registry]::CurrentUser; SubKey = $normalized.Substring(5); Display = $normalized }
    }
    throw "unsupported registry root in '$path' (expected HKLM\... or HKCU\...)"
}

function Get-RawPath {
    param($registryKey)
    # The whole point of this script: GetValue with DoNotExpandEnvironmentNames
    # returns the stored string, so %SystemRoot% stays %SystemRoot% instead of
    # being baked down to C:\Windows on the way back into the registry.
    return [string]$registryKey.GetValue(
        'Path',
        '',
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}

function Get-PathValueName {
    param($registryKey)
    # Registry value names are case-insensitive but they are stored verbatim, so
    # reuse whatever casing is already there rather than renaming PATH to Path.
    foreach ($name in $registryKey.GetValueNames()) {
        if ($name -ieq 'Path') { return $name }
    }
    return 'Path'
}

function Update-Path {
    $target = $key
    if (-not $target) {
        $effectiveScope = $scope
        if ($effectiveScope -eq 'Auto') {
            if (Test-Admin) { $effectiveScope = 'Machine' } else { $effectiveScope = 'User' }
        }
        if ($effectiveScope -eq 'Machine') { $target = $MACHINE_KEY } else { $target = $USER_KEY }
    }

    $resolved = Resolve-Key $target
    $writable = -not $dryRun.IsPresent

    $registryKey = $resolved.Hive.OpenSubKey($resolved.SubKey, $writable)
    if (-not $registryKey -and $writable) {
        # Only create keys the caller explicitly asked for; the real environment
        # keys always exist already.
        $registryKey = $resolved.Hive.CreateSubKey($resolved.SubKey)
    }
    if (-not $registryKey) {
        Write-Fail "cannot open $($resolved.Display) (missing key, or no permission to write it)"
        return
    }

    try {
        $valueName = Get-PathValueName $registryKey
        $raw = Get-RawPath $registryKey

        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        try {
            $existingKind = $registryKey.GetValueKind($valueName)
            if ($existingKind -eq [Microsoft.Win32.RegistryValueKind]::String -or
                $existingKind -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) {
                $kind = $existingKind
            }
        } catch {
            # Value does not exist yet; ExpandString is the Windows default here.
        }

        $parts = @()
        foreach ($part in ($raw -split ';')) {
            if ($part -ne '') { $parts += $part }
        }

        $needle = $entry.TrimEnd('\')
        foreach ($part in $parts) {
            if ($part.TrimEnd('\') -ieq $needle) {
                Write-Output "$($resolved.Display) Path already contains $entry"
                return
            }
        }

        if ($position -eq 'Append') {
            $updated = (($parts + $entry) -join ';')
        } else {
            $updated = ((@($entry) + $parts) -join ';')
        }

        Write-Output "key : $($resolved.Display)"
        Write-Output "old : $raw"
        Write-Output "new : $updated"

        if ($dryRun.IsPresent) {
            Write-Output 'dry run, registry not modified'
            return
        }

        $registryKey.SetValue($valueName, $updated, $kind)
        Write-Output "added $entry to $($resolved.Display) Path ($kind)"
    } finally {
        $registryKey.Close()
    }
}

try {
    Update-Path
} catch {
    Write-Fail $_.Exception.Message
}

if ($script:failed) { exit 1 }
exit 0
