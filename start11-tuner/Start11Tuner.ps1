#Requires -Version 5.1
<#
  Start11 Tuner — конфигуратор Start11 в раскладке его собственного окна:
  слева разделы, справа карточки стилей меню.
  Пишет только те значения, которые Start11 сам читает:
  HKCU\Software\Stardock\Start8\Start8.ini\Start8 (MenuMode, AcrylicBlurEnabled).
  Перед записью делает бэкап в %LOCALAPPDATA%\Start11Tuner.
#>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$key    = 'HKCU:\Software\Stardock\Start8\Start8.ini\Start8'
$backup = Join-Path $env:LOCALAPPDATA 'Start11Tuner'

$C_BG      = [System.Drawing.ColorTranslator]::FromHtml('#1b1b1f')
$C_SIDE    = [System.Drawing.ColorTranslator]::FromHtml('#15151a')
$C_CARD    = [System.Drawing.ColorTranslator]::FromHtml('#2a2a33')
$C_CARD_HI = [System.Drawing.ColorTranslator]::FromHtml('#33333d')
$C_TEXT    = [System.Drawing.ColorTranslator]::FromHtml('#e6e6ef')
$C_MUTED   = [System.Drawing.ColorTranslator]::FromHtml('#8a8a99')
$C_ACCENT  = [System.Drawing.ColorTranslator]::FromHtml('#e0af68')

if (-not (Test-Path $key)) {
    [System.Windows.Forms.MessageBox]::Show('Start11 не найден: нет ключа' + "`n" + $key, 'Start11 Tuner') | Out-Null
    return
}

$styles = @(
    @{ mode = 1; name = 'Стиль Windows 7';    desc = 'Классическое меню Windows 7.' },
    @{ mode = 2; name = 'Стиль Modern';       desc = 'Обновлённый стиль Windows 7.' },
    @{ mode = 3; name = 'Стиль Windows 10';   desc = 'Стиль Windows 10 с улучшениями.' },
    @{ mode = 4; name = 'Стиль Windows 11';   desc = 'Стиль Windows 11 с улучшениями.' },
    @{ mode = 5; name = 'Стиль Windows App';  desc = 'Обновлённый стиль Windows 11.' }
)

function New-RoundedPath([System.Drawing.RectangleF]$r, [single]$rad) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $rad * 2
    $p.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $p.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $p.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $p
}

function Save-Backup {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    $obj = [ordered]@{}
    foreach ($p in (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) { $obj[$p.Name] = $p.Value }
    $file = Join-Path $backup ("backup-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $obj | ConvertTo-Json -Depth 3 | Set-Content $file -Encoding UTF8
    $file
}

$cur = Get-ItemProperty $key
$currentMode = if ($cur.MenuMode) { [int]$cur.MenuMode } else { 0 }
$currentAcrylic = ([string]$cur.AcrylicBlurEnabled -eq '1')
$script:selected = $currentMode

# ---------- окно ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Start11 Tuner'
$form.Size = New-Object System.Drawing.Size(1020, 640)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = $C_BG
$form.ForeColor = $C_TEXT
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

# ---------- боковая колонка ----------
$side = New-Object System.Windows.Forms.Panel
$side.Location = New-Object System.Drawing.Point(0, 0)
$side.Size = New-Object System.Drawing.Size(230, 600)
$side.BackColor = $C_SIDE
$form.Controls.Add($side)

$navItems = @(
    @{ text = 'Меню «Пуск»';           active = $true },
    @{ text = 'Панель задач';          active = $false },
    @{ text = 'Закреплённые на панели'; active = $false },
    @{ text = 'Поиск';                 active = $false },
    @{ text = 'Управление';            active = $false },
    @{ text = 'О программе';           active = $false }
)
$y = 24
foreach ($item in $navItems) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = '   ' + $item.text
    $lbl.Location = New-Object System.Drawing.Point(0, $y)
    $lbl.Size = New-Object System.Drawing.Size(230, 40)
    $lbl.TextAlign = 'MiddleLeft'
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    if ($item.active) {
        $lbl.ForeColor = $C_TEXT
        $lbl.BackColor = $C_BG
        $bar = New-Object System.Windows.Forms.Panel
        $bar.BackColor = $C_ACCENT
        $bar.Location = New-Object System.Drawing.Point(0, $y)
        $bar.Size = New-Object System.Drawing.Size(3, 40)
        $side.Controls.Add($bar)
    } else {
        $lbl.ForeColor = $C_MUTED
    }
    $side.Controls.Add($lbl)
    $y += 44
}

# ---------- заголовок ----------
$title = New-Object System.Windows.Forms.Label
$title.Text = 'Меню «Пуск»'
$title.Location = New-Object System.Drawing.Point(270, 30)
$title.AutoSize = $true
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 19)
$title.ForeColor = $C_TEXT
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'Стиль меню «Пуск»'
$sub.Location = New-Object System.Drawing.Point(272, 78)
$sub.AutoSize = $true
$sub.ForeColor = $C_MUTED
$form.Controls.Add($sub)

# ---------- карточки стилей ----------
$script:cardPanels = @()
$x = 270
foreach ($s in $styles) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($x, 108)
    $card.Size = New-Object System.Drawing.Size(140, 230)
    $card.BackColor = $C_BG
    $card.Tag = $s
    $card.Cursor = 'Hand'

    $card.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $name = $sender.Tag.name
        $desc = $sender.Tag.desc
        $mode = [int]$sender.Tag.mode
        $isSel = ($mode -eq $script:selected)
        $rect = New-Object System.Drawing.RectangleF 0, 0, ($sender.Width - 1), ($sender.Height - 1)
        $path = New-RoundedPath $rect 8
        $bg = New-Object System.Drawing.SolidBrush ($(if ($isSel) { $C_CARD_HI } else { $C_CARD }))
        $g.FillPath($bg, $path)
        if ($isSel) {
            $pen = New-Object System.Drawing.Pen $C_ACCENT, 2
            $g.DrawPath($pen, $path)
            $pen.Dispose()
        }
        $bg.Dispose()

        # мини-превью меню: у каждого стиля своя раскладка
        $pv = New-Object System.Drawing.RectangleF 14, 14, ($sender.Width - 28), 110
        $pvp = New-RoundedPath $pv 4
        $pbg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#3a3a46'))
        $g.FillPath($pbg, $pvp)
        $pbg.Dispose(); $pvp.Dispose()

        $fg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#5a5a6b'))
        switch ($mode) {
            1 { $g.FillRectangle($fg, 20, 30, 46, 22); $g.FillRectangle($fg, 72, 30, 46, 78); $g.FillRectangle($fg, 20, 58, 46, 50) }
            2 { $g.FillRectangle($fg, 20, 26, 98, 10); $g.FillRectangle($fg, 20, 42, 62, 70); $g.FillRectangle($fg, 88, 42, 30, 70) }
            3 { for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 4; $c++) { $g.FillRectangle($fg, (20 + $c * 26), (30 + $r * 30), 22, 24) } } }
            4 { for ($r = 0; $r -lt 3; $r++) { for ($c = 0; $c -lt 5; $c++) { $g.FillRectangle($fg, (22 + $c * 20), (34 + $r * 26), 16, 20) } } }
            5 { $g.FillRectangle($fg, 22, 30, 96, 8); $g.FillRectangle($fg, 22, 44, 96, 8); $g.FillRectangle($fg, 22, 58, 96, 8); $g.FillRectangle($fg, 22, 72, 96, 8) }
        }
        $fg.Dispose()

        $fName = New-Object System.Drawing.Font('Segoe UI', 9.5)
        $tb = New-Object System.Drawing.SolidBrush ($(if ($isSel) { $C_ACCENT } else { $C_TEXT }))
        $rName = New-Object System.Drawing.RectangleF 12, 136, ($sender.Width - 24), 44
        $g.DrawString($name, $fName, $tb, $rName)
        $tb.Dispose(); $fName.Dispose()

        $fDesc = New-Object System.Drawing.Font('Segoe UI', 8)
        $mb = New-Object System.Drawing.SolidBrush $C_MUTED
        $rDesc = New-Object System.Drawing.RectangleF 12, 184, ($sender.Width - 24), 40
        $g.DrawString($desc, $fDesc, $mb, $rDesc)
        $mb.Dispose(); $fDesc.Dispose()
    })

    $card.Add_Click({
        param($sender, $e)
        $script:selected = [int]$sender.Tag.mode
        foreach ($c in $script:cardPanels) { $c.Invalidate() }
    })

    $form.Controls.Add($card)
    $script:cardPanels += $card
    $x += 152
}

# ---------- акрил ----------
$chk = New-Object System.Windows.Forms.CheckBox
$chk.Text = 'Акрил / размытие меню'
$chk.Location = New-Object System.Drawing.Point(272, 356)
$chk.AutoSize = $true
$chk.ForeColor = $C_TEXT
$chk.Checked = $currentAcrylic
$form.Controls.Add($chk)

# ---------- статус ----------
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(272, 392)
$status.Size = New-Object System.Drawing.Size(700, 74)
$status.ForeColor = $C_MUTED
$form.Controls.Add($status)

$running = (Get-Process Start11_64 -ErrorAction SilentlyContinue) -ne $null
$status.Text = "Сейчас: MenuMode=$currentMode, акрил=$currentAcrylic" + "`n" +
               'Смена стиля между Windows 10 и Windows 11 требует перезагрузки.'
if ($running) {
    $status.Text += "`n" + 'Start11 запущен — он перезапишет значение при выходе. Сначала выключи его меню.'
    $status.ForeColor = $C_ACCENT
}

# ---------- кнопки ----------
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Применить'
$btnApply.Location = New-Object System.Drawing.Point(272, 480)
$btnApply.Size = New-Object System.Drawing.Size(160, 36)
$btnApply.FlatStyle = 'Flat'
$btnApply.BackColor = $C_ACCENT
$btnApply.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#1b1b1f')
$btnApply.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnApply)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = 'Откатить'
$btnRevert.Location = New-Object System.Drawing.Point(444, 480)
$btnRevert.Size = New-Object System.Drawing.Size(160, 36)
$btnRevert.FlatStyle = 'Flat'
$btnRevert.BackColor = $C_CARD
$btnRevert.ForeColor = $C_TEXT
$btnRevert.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#3a3a46')
$form.Controls.Add($btnRevert)

$btnApply.Add_Click({
    $mode = $script:selected
    if ($mode -lt 1) { $status.Text = 'Сначала выбери стиль.'; return }
    $file = Save-Backup
    Set-ItemProperty $key -Name 'MenuMode' -Value $mode -Type String
    Set-ItemProperty $key -Name 'AcrylicBlurEnabled' -Value $(if ($chk.Checked) { 1 } else { 0 }) -Type String
    $status.ForeColor = $C_TEXT
    $status.Text = "Записано: MenuMode=$mode, акрил=$($chk.Checked)." + "`n" +
                   "Бэкап: $file" + "`n" + 'Перезагрузи компьютер, чтобы Start11 перечитал настройки.'
})

$btnRevert.Add_Click({
    $last = Get-ChildItem $backup -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $last) { $status.Text = 'Бэкапов пока нет.'; return }
    $data = Get-Content $last.FullName -Raw | ConvertFrom-Json
    foreach ($p in $data.PSObject.Properties) {
        Set-ItemProperty $key -Name $p.Name -Value ([string]$p.Value) -Type String -ErrorAction SilentlyContinue
    }
    $c = Get-ItemProperty $key
    $script:selected = if ($c.MenuMode) { [int]$c.MenuMode } else { 0 }
    $chk.Checked = ([string]$c.AcrylicBlurEnabled -eq '1')
    foreach ($card in $script:cardPanels) { $card.Invalidate() }
    $status.Text = "Откат из $($last.Name). Перезагрузись, чтобы применилось."
})

[void]$form.ShowDialog()
