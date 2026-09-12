$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$driverDir = Join-Path $root 'driver'
$packageDir = Join-Path $root 'package'
$certDir = Join-Path $root 'testcert'
$sysSource = Join-Path $driverDir 'build\Release\MagicKeyFix.sys'
$infSource = Join-Path $driverDir 'MagicKeyFix.inf'

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
        exit
    }
}

function Find-WdkTool([string]$name, [switch]$PreferX64) {
    $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path $kits)) {
        throw 'Windows Kits\10\bin was not found. Install the Windows Driver Kit (WDK).'
    }

    $matches = @(Get-ChildItem -Path $kits -Filter $name -File -Recurse -ErrorAction SilentlyContinue)
    if ($PreferX64) {
        $x64 = @($matches | Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending)
        if ($x64.Count -gt 0) { return $x64[0].FullName }
    }
    if ($matches.Count -eq 0) {
        throw "$name was not found under $kits. Install/repair the WDK."
    }
    return ($matches | Sort-Object FullName -Descending | Select-Object -First 1).FullName
}

Ensure-Admin
Write-Host 'MagicKeyFix v1 - create test-signed package' -ForegroundColor Cyan

if (-not (Test-Path $sysSource)) {
    throw "MagicKeyFix.sys does not exist yet. Run '1 BUILD RELEASE.cmd' first."
}
if (-not (Test-Path $infSource)) {
    throw "Missing INF: $infSource"
}

$signtool = Find-WdkTool 'signtool.exe' -PreferX64
$inf2cat = Find-WdkTool 'Inf2Cat.exe'
Write-Host "SignTool: $signtool"
Write-Host "Inf2Cat: $inf2cat"

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
New-Item -ItemType Directory -Force -Path $certDir | Out-Null
Get-ChildItem -Path $packageDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$sys = Join-Path $packageDir 'MagicKeyFix.sys'
$inf = Join-Path $packageDir 'MagicKeyFix.inf'
$cat = Join-Path $packageDir 'MagicKeyFix.cat'
Copy-Item $sysSource $sys -Force
Copy-Item $infSource $inf -Force

$subject = 'CN=MagicKeyFix Test'
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
    $_.Subject -eq $subject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date).AddDays(30)
} | Sort-Object NotAfter -Descending | Select-Object -First 1

if (-not $cert) {
    Write-Host 'Creating local MagicKeyFix test-signing certificate...'
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $subject `
        -CertStoreLocation 'Cert:\LocalMachine\My' `
        -HashAlgorithm SHA256 `
        -KeyAlgorithm RSA `
        -KeyLength 3072 `
        -KeyExportPolicy Exportable `
        -NotAfter (Get-Date).AddYears(5)
}

$cerPath = Join-Path $certDir 'MagicKeyFix-Test.cer'
Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
Import-Certificate -FilePath $cerPath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Import-Certificate -FilePath $cerPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' | Out-Null
Write-Host "Certificate: $($cert.Thumbprint)"

Write-Host 'Signing .sys...'
& $signtool sign /v /sm /s My /sha1 $cert.Thumbprint /fd SHA256 $sys
if ($LASTEXITCODE -ne 0) { throw "SignTool failed on MagicKeyFix.sys ($LASTEXITCODE)" }

Write-Host 'Generating catalog...'
& $inf2cat "/driver:$packageDir" '/os:10_X64'
if ($LASTEXITCODE -ne 0) { throw "Inf2Cat failed ($LASTEXITCODE)" }
if (-not (Test-Path $cat)) { throw 'Inf2Cat did not create MagicKeyFix.cat.' }

Write-Host 'Signing catalog...'
& $signtool sign /v /sm /s My /sha1 $cert.Thumbprint /fd SHA256 $cat
if ($LASTEXITCODE -ne 0) { throw "SignTool failed on MagicKeyFix.cat ($LASTEXITCODE)" }

Write-Host ''
Write-Host "Package ready: $packageDir" -ForegroundColor Green
Write-Host 'Next: enable TESTSIGNING, reboot, then run 4 INSTALL DRIVER.cmd.'
Read-Host 'Press Enter to close'
