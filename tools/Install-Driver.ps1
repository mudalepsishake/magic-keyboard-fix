$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$inf = Join-Path $root 'package\MagicKeyFix.inf'
$cat = Join-Path $root 'package\MagicKeyFix.cat'
$sys = Join-Path $root 'package\MagicKeyFix.sys'

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
        exit
    }
}

Ensure-Admin
Write-Host 'MagicKeyFix v1 - install driver' -ForegroundColor Cyan

foreach ($f in @($inf, $cat, $sys)) {
    if (-not (Test-Path $f)) {
        throw "Missing package file: $f. Run '2 MAKE TEST PACKAGE.cmd' first."
    }
}

$keyboard = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
    $_.PNPDeviceID -match 'VID_05AC.*PID_0267' -or $_.PNPDeviceID -match 'VID&0001004c_PID&0267'
} | Select-Object -First 1

if ($keyboard) {
    Write-Host "A1644 detected: $($keyboard.Name)" -ForegroundColor Green
    Write-Host "PnP ID: $($keyboard.PNPDeviceID)"
} else {
    Write-Warning 'A1644 / PID 0267 is not currently visible. The package can still be staged, but it will only bind to that exact model.'
}

Write-Host ''
Write-Host 'Installing/staging package with PnPUtil...'
& pnputil.exe /add-driver $inf /install
if ($LASTEXITCODE -ne 0) {
    throw "PnPUtil failed with exit code $LASTEXITCODE"
}

Write-Host ''
Write-Host 'Installed. Connect the keyboard now if you havent already. Test the keyboard mappings below. If they work, the install was successful and the mappings should continue working. ' -ForegroundColor Green
Write-Host 'Expected: Fn=Ctrl, Control=Ctrl, Option=Win, Command=Alt, Eject=Delete.'
Write-Host 'If the keyboard mappings arent working, disconnect/reconnect the keyboard or reboot Windows.' -ForegroundColor Green
Read-Host 'Press Enter to close'
