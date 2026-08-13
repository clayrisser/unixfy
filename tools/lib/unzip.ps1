param(
    [Parameter(Mandatory = $true)][string]$filename,
    [string]$cwd,
    [string]$tools
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if (-not $cwd) { $cwd = (Get-Location).Path }

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Invoke-Unzip {
    param([string]$zipFileName)
    $zipFilePath = Join-Path $cwd $zipFileName
    if (-not (Test-Path -LiteralPath $zipFilePath)) {
        throw "$zipFilePath does not exist."
    }
    Write-Output "Unzipping $zipFilePath"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $cwd)
}

try {
    Invoke-Unzip $filename
} catch {
    [Console]::Error.WriteLine("unzip: $($_.Exception.Message)")
    exit 1
}

exit 0
