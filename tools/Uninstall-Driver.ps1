$ErrorActionPreference = 'Stop'

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
Write-Host 'MagicKeyFix v1 - uninstall driver' -ForegroundColor Cyan

$text = (& pnputil.exe /enum-drivers | Out-String)
$blocks = $text -split '(?:\r?\n){2,}'
$published = @()

foreach ($block in $blocks) {
    if ($block -match '(?im)^\s*Original Name\s*:\s*MagicKeyFix\.inf\s*$') {
        $m = [regex]::Match($block, '(?im)^\s*Published Name\s*:\s*(oem\d+\.inf)\s*$')
        if ($m.Success) { $published += $m.Groups[1].Value }
    }
}

if ($published.Count -eq 0) {
    Write-Host 'No installed MagicKeyFix driver package was found.' -ForegroundColor Yellow
} else {
    foreach ($name in ($published | Select-Object -Unique)) {
        Write-Host "Removing $name ..."
        & pnputil.exe /delete-driver $name /uninstall /force
        if ($LASTEXITCODE -ne 0) {
            throw "PnPUtil failed removing $name with exit code $LASTEXITCODE"
        }
    }
}

$svc = Get-Service -Name MagicKeyFix -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host 'Removing leftover MagicKeyFix service registration...'
    & sc.exe delete MagicKeyFix | Out-Host
}

Write-Host ''
Write-Host 'Uninstall complete. Reboot Windows to guarantee the old HID stack is back.' -ForegroundColor Green
Read-Host 'Press Enter to close'
