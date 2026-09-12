$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
    exit
}

Write-Host 'Enabling Windows TESTSIGNING mode...' -ForegroundColor Cyan
& bcdedit.exe /set testsigning on
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Warning 'BCDEdit failed. If it says the value is protected by Secure Boot policy, disable Secure Boot in UEFI first.'
    Read-Host 'Press Enter to close'
    exit $LASTEXITCODE
}
Write-Host ''
Write-Host 'TESTSIGNING is enabled. Reboot Windows before installing/loading MagicKeyFix.' -ForegroundColor Green
Read-Host 'Press Enter to close'
