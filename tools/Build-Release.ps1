$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sln = Join-Path $root 'MagicKeyFix.sln'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'

Write-Host 'MagicKeyFix v2 - Release build' -ForegroundColor Cyan

if (-not (Test-Path $vswhere)) {
    throw 'vswhere.exe was not found. Install Visual Studio 2026 Build Tools or Visual Studio 2026 with Desktop development with C++.'
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
if (-not $vsPath) {
    throw 'Visual Studio/MSBuild was not found.'
}

$msbuild = Join-Path $vsPath 'MSBuild\Current\Bin\amd64\MSBuild.exe'
if (-not (Test-Path $msbuild)) {
    throw "64-bit MSBuild was not found at $msbuild. The current WDK requires 64-bit MSBuild for INF verification."
}

$toolsetRoot = Join-Path $vsPath 'MSBuild\Microsoft\VC\v180\Platforms\x64\PlatformToolsets\WindowsKernelModeDriver10.0'
if (-not (Test-Path $toolsetRoot)) {
    Write-Host ''
    Write-Host 'WindowsKernelModeDriver10.0 is not installed in this Visual Studio instance.' -ForegroundColor Yellow
    Write-Host 'Run: 0 INSTALL WDK PREREQUISITES.cmd' -ForegroundColor Yellow
    Write-Host ''
    throw 'WDK Visual Studio integration is missing.'
}

$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$includeRoot = Join-Path $kits 'Include'
$libRoot = Join-Path $kits 'Lib'
$wdkVersions = @()
if (Test-Path $includeRoot) {
    $wdkVersions = Get-ChildItem $includeRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            (Test-Path (Join-Path $_.FullName 'km\ntddk.h')) -and
            (Test-Path (Join-Path $libRoot ($_.Name + '\km\x64\ntoskrnl.lib')))
        } |
        Sort-Object Name -Descending
}

if (-not $wdkVersions -or $wdkVersions.Count -eq 0) {
    Write-Host ''
    Write-Host 'A complete x64 WDK/SDK pair was not found under Windows Kits\10.' -ForegroundColor Yellow
    Write-Host 'Run: 0 INSTALL WDK PREREQUISITES.cmd' -ForegroundColor Yellow
    Write-Host ''
    throw 'WDK headers/libraries are missing.'
}

Write-Host "Visual Studio: $vsPath"
Write-Host "MSBuild: $msbuild"
Write-Host "WDK/SDK: $($wdkVersions[0].Name)"

$wdkVersion = $wdkVersions[0].Name
& $msbuild $sln /m /t:Build /p:Configuration=Release /p:Platform=x64 /p:WindowsTargetPlatformVersion=$wdkVersion
if ($LASTEXITCODE -ne 0) {
    throw "MSBuild failed with exit code $LASTEXITCODE"
}

$sys = Join-Path $root 'driver\build\Release\MagicKeyFix.sys'
if (-not (Test-Path $sys)) {
    throw "Build reported success, but $sys was not found. Search the build output for MagicKeyFix.sys and send me the log/path."
}

Write-Host ''
Write-Host "Built: $sys" -ForegroundColor Green
