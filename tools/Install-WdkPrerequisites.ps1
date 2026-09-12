$ErrorActionPreference = 'Stop'

Write-Host 'MagicKeyFix v3 - WDK prerequisite installer' -ForegroundColor Cyan
Write-Host ''
Write-Host 'This installs the current Windows 11 26H1 SDK/WDK build tools required to compile MagicKeyFix.'
Write-Host 'It does NOT require winget/App Installer.'
Write-Host 'It also adds the Windows Driver Kit integration component to your existing Visual Studio installation.'
Write-Host ''

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsSetup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'

if (-not (Test-Path $vswhere)) {
    throw 'vswhere.exe was not found. Install Visual Studio 2026 Build Tools or Visual Studio 2026 first.'
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
if (-not $vsPath) {
    throw 'Visual Studio/MSBuild was not found.'
}

if (-not (Test-Path $vsSetup)) {
    throw "Visual Studio Installer setup.exe was not found at $vsSetup"
}

Write-Host "Visual Studio: $vsPath" -ForegroundColor Gray
Write-Host ''

# Official Microsoft bootstrapper links for the currently supported 28000-series SDK/WDK.
# The SDK and WDK only need the same base build number (28000); their QFE values may differ.
$sdkUrl = 'https://go.microsoft.com/fwlink/?linkid=2376217'
$wdkUrl = 'https://go.microsoft.com/fwlink/?LinkId=2371554'
$tempRoot = Join-Path $env:TEMP 'MagicKeyFix-WDK'
$sdkInstaller = Join-Path $tempRoot 'winsdksetup.exe'
$wdkInstaller = Join-Path $tempRoot 'wdksetup.exe'

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function Download-MicrosoftInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Write-Host "Downloading $Label..." -ForegroundColor Gray
    if (Test-Path $OutFile) {
        Remove-Item -Force $OutFile
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing

    if (-not (Test-Path $OutFile)) {
        throw "$Label download did not create $OutFile"
    }

    $sig = Get-AuthenticodeSignature -FilePath $OutFile
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "$Label failed Microsoft Authenticode verification. Status: $($sig.Status); signer: $($sig.SignerCertificate.Subject)"
    }
}

function Run-ElevatedInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Verb RunAs -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        throw "$Label failed with exit code $($proc.ExitCode)"
    }

    if ($proc.ExitCode -eq 3010) {
        Write-Host "$Label completed; Windows reports that a reboot will be required." -ForegroundColor Yellow
    }
}

try {
    Write-Host '[1/3] Installing/updating Windows 11 26H1 SDK...' -ForegroundColor Cyan
    Download-MicrosoftInstaller -Uri $sdkUrl -OutFile $sdkInstaller -Label 'Windows SDK installer'
    Run-ElevatedInstaller -FilePath $sdkInstaller -Arguments @('/features', '+', '/quiet', '/norestart') -Label 'Windows SDK installation'

    Write-Host ''
    Write-Host '[2/3] Installing/updating Windows 11 26H1 WDK...' -ForegroundColor Cyan
    Download-MicrosoftInstaller -Uri $wdkUrl -OutFile $wdkInstaller -Label 'Windows WDK installer'
    Run-ElevatedInstaller -FilePath $wdkInstaller -Arguments @('/quiet', '/norestart') -Label 'Windows WDK installation'

    Write-Host ''
    Write-Host '[3/3] Adding Windows Driver Kit integration to Visual Studio...' -ForegroundColor Cyan
    $proc = Start-Process -FilePath $vsSetup -ArgumentList @(
        'modify',
        '--installPath', "`"$vsPath`"",
        '--add', 'Component.Microsoft.Windows.DriverKit',
        '--passive',
        '--norestart'
    ) -Verb RunAs -Wait -PassThru

    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        throw "Visual Studio DriverKit component installation failed with exit code $($proc.ExitCode)"
    }

    Write-Host ''
    Write-Host 'Prerequisite installation finished.' -ForegroundColor Green
    Write-Host 'Now run: 1 BUILD RELEASE.cmd' -ForegroundColor Green
    Write-Host ''
    Write-Host 'If any installer returns an error, keep this window open and send me the complete output.' -ForegroundColor Yellow
}
finally {
    Remove-Item -Force $sdkInstaller, $wdkInstaller -ErrorAction SilentlyContinue
    Remove-Item -Force $tempRoot -ErrorAction SilentlyContinue
}
