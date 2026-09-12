$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
    exit
}

Write-Host 'Disabling Windows TESTSIGNING mode...' -ForegroundColor Cyan
& bcdedit.exe /set testsigning off
if ($LASTEXITCODE -ne 0) {
    Read-Host 'Press Enter to close'
    exit $LASTEXITCODE
}
Write-Host ''
Write-Host 'TESTSIGNING is disabled. Reboot Windows to apply it.' -ForegroundColor Green
Read-Host 'Press Enter to close'
