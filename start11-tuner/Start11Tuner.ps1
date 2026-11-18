#Requires -Version 5.1
<#
  Start11 Tuner — минимальный конфигуратор Start11 поверх его же реестровых ключей.

  Откуда взято:
    HKCU\Software\Stardock\Start8\Start8.ini\Start8 — живая ветка настроек Start11 3.x.
    MenuMode: 1 Windows 7, 2 Modern, 3 Windows 10, 4 Windows 11, 5 Windows App
    (порядок стилей снят из ресурсов Start11Config.exe; соответствие числа стилю — гипотеза,
     проверяется одним применением + перезагрузкой).

  Ничего не взламывает: пишет только те значения, которые Start11 сам читает.
  Перед первой записью делает бэкап в %LOCALAPPDATA%\Start11Tuner.
#>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$key    = 'HKCU:\Software\Stardock\Start8\Start8.ini\Start8'
$backup = Join-Path $env:LOCALAPPDATA 'Start11Tuner'
$styles = [ordered]@{ 1 = 'Windows 7'; 2 = 'Modern'; 3 = 'Windows 10'; 4 = 'Windows 11'; 5 = 'Windows App' }

if (-not (Test-Path $key)) {
    [System.Windows.Forms.MessageBox]::Show('Start11 не найден: нет ключа' + "`n" + $key, 'Start11 Tuner') | Out-Null
    return
}

function Save-Backup {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    $props = (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
    $obj = [ordered]@{}
    foreach ($p in $props) { $obj[$p.Name] = $p.Value }
    $file = Join-Path $backup ("backup-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $obj | ConvertTo-Json -Depth 3 | Set-Content $file -Encoding UTF8
    $file
}

function Get-Current {
    $p = Get-ItemProperty $key
    [pscustomobject]@{
        MenuMode = [int]$p.MenuMode
        Acrylic  = [int]$p.AcrylicBlurEnabled
    }
}

# --- окно ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Start11 Tuner'
$form.Size = New-Object System.Drawing.Size(420, 300)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1a1b26')
$form.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#c0caf5')
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$lblStyle = New-Object System.Windows.Forms.Label
$lblStyle.Text = 'Стиль меню'
$lblStyle.Location = New-Object System.Drawing.Point(20, 20)
$lblStyle.AutoSize = $true
$form.Controls.Add($lblStyle)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = New-Object System.Drawing.Point(20, 44)
$combo.Size = New-Object System.Drawing.Size(360, 24)
$combo.DropDownStyle = 'DropDownList'
foreach ($k in $styles.Keys) { [void]$combo.Items.Add("$k — $($styles[$k])") }
$form.Controls.Add($combo)

$chkAcrylic = New-Object System.Windows.Forms.CheckBox
$chkAcrylic.Text = 'Акрил / размытие меню'
$chkAcrylic.Location = New-Object System.Drawing.Point(20, 84)
$chkAcrylic.AutoSize = $true
$form.Controls.Add($chkAcrylic)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(20, 116)
$status.Size = New-Object System.Drawing.Size(360, 60)
$status.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#565f89')
$form.Controls.Add($status)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Применить'
$btnApply.Location = New-Object System.Drawing.Point(20, 190)
$btnApply.Size = New-Object System.Drawing.Size(170, 32)
$form.Controls.Add($btnApply)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = 'Откатить'
$btnRevert.Location = New-Object System.Drawing.Point(210, 190)
$btnRevert.Size = New-Object System.Drawing.Size(170, 32)
$form.Controls.Add($btnRevert)

# --- логика ---
$cur = Get-Current
$combo.SelectedIndex = [Math]::Max(0, [Math]::Min(4, $cur.MenuMode - 1))
$chkAcrylic.Checked = ($cur.Acrylic -eq 1)
$running = (Get-Process Start11_64 -ErrorAction SilentlyContinue) -ne $null
$status.Text = "Сейчас: MenuMode=$($cur.MenuMode), акрил=$($cur.Acrylic)" + "`n" +
               'Смена стиля между 10 и 11 требует перезагрузки.'
if ($running) {
    # проверено на практике: работающий Start11 перезаписывает MenuMode при выходе
    $status.Text += "`n" + 'Start11 запущен — он перезапишет значение при выходе. Выключи его меню в его же окне перед применением.'
    $status.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#e0af68')
}

$btnApply.Add_Click({
    $mode = [int]($combo.SelectedItem -split ' ')[0]
    $file = Save-Backup
    Set-ItemProperty $key -Name 'MenuMode' -Value $mode -Type String
    Set-ItemProperty $key -Name 'AcrylicBlurEnabled' -Value $(if ($chkAcrylic.Checked) { 1 } else { 0 }) -Type String
    $status.Text = "Записано: MenuMode=$mode, акрил=$($chkAcrylic.Checked)." + "`n" +
                   "Бэкап: $file" + "`n" + 'Перезагрузись, чтобы Start11 перечитал настройки.'
})

$btnRevert.Add_Click({
    $last = Get-ChildItem $backup -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $last) { $status.Text = 'Бэкапов нет.'; return }
    $data = Get-Content $last.FullName -Raw | ConvertFrom-Json
    foreach ($p in $data.PSObject.Properties) {
        Set-ItemProperty $key -Name $p.Name -Value ([string]$p.Value) -Type String -ErrorAction SilentlyContinue
    }
    $c = Get-Current
    $combo.SelectedIndex = [Math]::Max(0, [Math]::Min(4, $c.MenuMode - 1))
    $chkAcrylic.Checked = ($c.Acrylic -eq 1)
    $status.Text = "Откат из $($last.Name)." + "`n" + 'Перезагрузись, чтобы применилось.'
})

[void]$form.ShowDialog()
