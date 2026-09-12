Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

$form = New-Object System.Windows.Forms.Form
$form.Text = 'MagicKeyFix v1 - Apple Magic Keyboard A1644'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(650, 500)
$form.MinimumSize = New-Object System.Drawing.Size(666, 539)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'MagicKeyFix v1'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'A1644 / PID 0267 lower-filter remapper'
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(22, 52)
$form.Controls.Add($subtitle)

$mapBox = New-Object System.Windows.Forms.GroupBox
$mapBox.Text = 'Fixed mapping'
$mapBox.Location = New-Object System.Drawing.Point(20, 85)
$mapBox.Size = New-Object System.Drawing.Size(295, 180)
$form.Controls.Add($mapBox)

$map = New-Object System.Windows.Forms.Label
$map.Text = "Fn              -> Ctrl`r`nControl         -> Ctrl`r`nOption          -> Windows`r`nCommand         -> Alt`r`nEject           -> Delete (forward)"
$map.Location = New-Object System.Drawing.Point(18, 28)
$map.Size = New-Object System.Drawing.Size(255, 135)
$map.Font = New-Object System.Drawing.Font('Consolas', 10)
$mapBox.Controls.Add($map)

$statusBox = New-Object System.Windows.Forms.GroupBox
$statusBox.Text = 'Status'
$statusBox.Location = New-Object System.Drawing.Point(335, 85)
$statusBox.Size = New-Object System.Drawing.Size(295, 180)
$form.Controls.Add($statusBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(18, 27)
$statusLabel.Size = New-Object System.Drawing.Size(260, 137)
$statusBox.Controls.Add($statusLabel)

function Get-TestSigningState {
    try {
        $bcd = (& bcdedit.exe /enum '{current}' 2>$null | Out-String)
        if ($bcd -match '(?im)^testsigning\s+Yes\s*$') { return 'ON' }
        if ($bcd -match '(?im)^testsigning\s+No\s*$') { return 'OFF' }
        return 'not explicitly set'
    } catch { return 'unknown' }
}

function Get-SecureBootState {
    try {
        $v = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($v) { return 'ON' } else { return 'OFF' }
    } catch {
        return 'unknown / unsupported'
    }
}

function Refresh-Status {
    $keyboard = $null
    try {
        $keyboard = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
            $_.PNPDeviceID -match 'VID_05AC.*PID_0267' -or $_.PNPDeviceID -match 'VID&0001004c_PID&0267'
        } | Select-Object -First 1
    } catch {}

    $svc = Get-Service -Name MagicKeyFix -ErrorAction SilentlyContinue
    $sys = Test-Path (Join-Path $root 'driver\build\Release\MagicKeyFix.sys')
    $pkg = Test-Path (Join-Path $root 'package\MagicKeyFix.cat')

    $statusLabel.Text = @"
A1644 detected:  $(if ($keyboard) {'YES'} else {'NO'})
Built .sys:      $(if ($sys) {'YES'} else {'NO'})
Signed package:  $(if ($pkg) {'YES'} else {'NO'})
Driver service:  $(if ($svc) {$svc.Status} else {'not installed'})
TESTSIGNING:     $(Get-TestSigningState)
Secure Boot:     $(Get-SecureBootState)
"@
}

function Add-Button([string]$text, [int]$x, [int]$y, [scriptblock]$action) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size(190, 38)
    $b.Add_Click($action)
    $form.Controls.Add($b)
    return $b
}

Add-Button '1. Build Release' 20 290 {
    Start-Process -FilePath (Join-Path $root '1 BUILD RELEASE.cmd') -Wait
    Refresh-Status
} | Out-Null

Add-Button '2. Make Test Package' 230 290 {
    Start-Process -FilePath (Join-Path $root '2 MAKE TEST PACKAGE.cmd')
} | Out-Null

Add-Button '3. Enable TESTSIGNING' 440 290 {
    Start-Process -FilePath (Join-Path $root '3 ENABLE TESTSIGNING.cmd')
} | Out-Null

Add-Button '4. Install Driver' 20 345 {
    Start-Process -FilePath (Join-Path $root '4 INSTALL DRIVER.cmd')
} | Out-Null

Add-Button '5. Uninstall Driver' 230 345 {
    Start-Process -FilePath (Join-Path $root '5 UNINSTALL DRIVER.cmd')
} | Out-Null

Add-Button '6. Disable TESTSIGNING' 440 345 {
    Start-Process -FilePath (Join-Path $root '6 DISABLE TESTSIGNING.cmd')
} | Out-Null

Add-Button 'Refresh Status' 20 410 {
    Refresh-Status
} | Out-Null

Add-Button 'Open README' 230 410 {
    Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $root 'README.txt') + '"')
} | Out-Null

$close = Add-Button 'Close' 440 410 { $form.Close() }
$close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $close

Refresh-Status
[void]$form.ShowDialog()
