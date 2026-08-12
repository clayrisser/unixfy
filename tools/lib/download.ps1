param(
    [Parameter(Mandatory = $true)][string]$url,
    [Parameter(Mandatory = $true)][string]$name,
    [string]$cwd,
    [string]$tools
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if (-not $cwd) { $cwd = (Get-Location).Path }

$script:failed = $false

function Write-Fail {
    param([string]$message)
    $script:failed = $true
    [Console]::Error.WriteLine("download: $message")
}

function Get-ProxyUri {
    param([string]$targetUrl)
    try {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        if (-not $proxy) { return $null }
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $proxyUri = $proxy.GetProxy($targetUrl)
        # GetProxy hands back the original URI when no proxy applies to it.
        if (-not $proxyUri -or "$proxyUri" -eq "$targetUrl") { return $null }
        return $proxyUri
    } catch {
        return $null
    }
}

function Get-HttpStatus {
    param($errorRecord)
    try {
        $response = $errorRecord.Exception.Response
        if (-not $response) { return '' }
        return [string][int]$response.StatusCode
    } catch {
        return ''
    }
}

function Invoke-Download {
    param([string]$sourceUrl, [string]$fileName)

    if (-not (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)) {
        Write-Fail 'Invoke-WebRequest is unavailable; PowerShell 3.0 or newer is required.'
        return
    }

    $downloadPath = Join-Path $cwd $fileName
    # Download to a sibling .part file so an aborted transfer can never be
    # mistaken for a finished one by whatever runs next.
    $partialPath = "$downloadPath.part"
    $startTime = Get-Date

    Write-Output "Downloading $sourceUrl"

    # Windows PowerShell 5.1 still negotiates TLS 1.0 by default, which most
    # mirrors now refuse.
    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        # Older .NET without Tls12 in the enum; nothing to do about it.
    }

    if (Test-Path -LiteralPath $partialPath) {
        Remove-Item -LiteralPath $partialPath -Force
    }

    $request = @{
        Uri             = $sourceUrl
        OutFile         = $partialPath
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }

    $proxyUri = Get-ProxyUri $sourceUrl
    if ($proxyUri) {
        Write-Output "Using proxy: $proxyUri"
        $request['Proxy'] = $proxyUri
        $request['ProxyUseDefaultCredentials'] = $true
    }

    try {
        Invoke-WebRequest @request
    } catch {
        $status = Get-HttpStatus $_
        if ($status) {
            Write-Fail "HTTP $status for $sourceUrl"
        } else {
            Write-Fail "could not reach $sourceUrl"
        }
        Write-Fail $_.Exception.Message
        if (Test-Path -LiteralPath $partialPath) {
            Remove-Item -LiteralPath $partialPath -Force
        }
        return
    }

    if (-not (Test-Path -LiteralPath $partialPath)) {
        Write-Fail "no file was written for $sourceUrl"
        return
    }

    $size = (Get-Item -LiteralPath $partialPath).Length
    if ($size -le 0) {
        Write-Fail "downloaded 0 bytes from $sourceUrl"
        Remove-Item -LiteralPath $partialPath -Force
        return
    }

    if (Test-Path -LiteralPath $downloadPath) {
        Remove-Item -LiteralPath $downloadPath -Force
    }
    Move-Item -LiteralPath $partialPath -Destination $downloadPath -Force

    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    Write-Output "Wrote $downloadPath ($size bytes)"
    Write-Output "Time taken: $elapsed second(s)"
}

try {
    Invoke-Download $url $name
} catch {
    Write-Fail $_.Exception.Message
}

if ($script:failed) { exit 1 }
exit 0
