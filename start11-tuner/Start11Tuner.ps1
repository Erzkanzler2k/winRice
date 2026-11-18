#Requires -Version 5.1
<#
  Start11 Tuner — конфигуратор Start11 в раскладке его родного окна.

  Значения читаются и пишутся строками в
  HKCU\Software\Stardock\Start8\Start8.ini\Start8 — так их хранит сам Start11.
  Перед записью делается бэкап в %LOCALAPPDATA%\Start11Tuner.

  Не делает: активацию/обход лицензии, редактор закреплённых (подключи
  Right/RightMode в неразобранном формате), редактор цветов.
#>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$key      = 'HKCU:\Software\Stardock\Start8\Start8.ini\Start8'
$bkDir    = Join-Path $env:LOCALAPPDATA 'Start11Tuner'
$configExe = 'C:\Program Files (x86)\Stardock\Start11\Start11Config.exe'

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
    @{ mode = 1; name = 'Стиль Windows 7';   desc = 'Классическое меню Windows 7.' },
    @{ mode = 2; name = 'Стиль Modern';      desc = 'Обновлённый стиль Windows 7.' },
    @{ mode = 3; name = 'Стиль Windows 10';  desc = 'Стиль Windows 10 с улучшениями.' },
    @{ mode = 4; name = 'Стиль Windows 11';  desc = 'Стиль Windows 11 с улучшениями.' },
    @{ mode = 5; name = 'Стиль Windows App'; desc = 'Обновлённый стиль Windows 11.' }
)

# группы настроек: кеи и типы взяты из живого ключа Start11
$groups = @(
    @{ id = 'menu'; name = 'Меню «Пуск»'; items = @(
        @{ kind = 'bool'; key = 'AcrylicBlurEnabled';     label = 'Акрил / размытие меню' }
        @{ kind = 'bool'; key = 'S11_ForceDarkMode';      label = 'Тёмное меню независимо от системы' }
        @{ kind = 'bool'; key = 'S11_UseWallpaperEffect'; label = 'Подложка из обоев' }
        @{ kind = 'int';  key = 'MenuAlphaValue';         label = 'Прозрачность меню'; min = 0; max = 100 }
    ) }
    @{ id = 'taskbar'; name = 'Панель задач'; items = @(
        @{ kind = 'bool'; key = 'EnableS11Taskbar';      label = 'Панель задач Start11' }
        @{ kind = 'bool'; key = 'TaskbarOnTop';          label = 'Панель сверху' }
        @{ kind = 'bool'; key = 'SecondaryTaskbarOnTop'; label = 'Сверху и на втором мониторе' }
        @{ kind = 'bool'; key = 'TaskbarDisallowBlur';   label = 'Запретить размытие' }
        @{ kind = 'int';  key = 'TaskbarAlphaValue';     label = 'Прозрачность панели'; min = 0; max = 100 }
    ) }
    @{ id = 'pins'; name = 'Закреплённые на панели'; items = @(
        @{ kind = 'bool'; key = 'ShowRight';        label = 'Правая колонка закреплённых' }
        @{ kind = 'bool'; key = 'ShowIconsOnRight'; label = 'Иконки в правой колонке' }
        @{ kind = 'bool'; key = 'TileMode';         label = 'Плитки вместо списка' }
        @{ kind = 'bool'; key = 'RightIconMode';    label = 'Крупные иконки справа' }
    ) }
    @{ id = 'search'; name = 'Поиск'; items = @(
        @{ kind = 'bool'; key = 'UseCortanaSearch'; label = 'Веб-поиск Cortana' }
    ) }
    @{ id = 'manage'; name = 'Управление'; items = @() }
    @{ id = 'about';  name = 'О программе'; items = @() }
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

function Get-Val([string]$name) {
    $v = (Get-ItemProperty $key -Name $name -ErrorAction SilentlyContinue).$name
    if ($null -eq $v) { return $null }
    [string]$v
}

function Save-Backup {
    New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
    $obj = [ordered]@{}
    foreach ($p in (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) { $obj[$p.Name] = $p.Value }
    $file = Join-Path $bkDir ("backup-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $obj | ConvertTo-Json -Depth 3 | Set-Content $file -Encoding UTF8
    $file
}

$script:selected = 0
$m = Get-Val 'MenuMode'
if ($m -and [int]$m -ge 1 -and [int]$m -le 5) { $script:selected = [int]$m }
$script:bound = New-Object System.Collections.ArrayList
$script:pages = @{}
$script:navLabels = New-Object System.Collections.ArrayList

# ---------- окно ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Start11 Tuner'
$form.Size = New-Object System.Drawing.Size(1020, 726)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = $C_BG
$form.ForeColor = $C_TEXT
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$side = New-Object System.Windows.Forms.Panel
$side.Location = New-Object System.Drawing.Point(0, 0)
$side.Size = New-Object System.Drawing.Size(230, 688)
$side.BackColor = $C_SIDE
$form.Controls.Add($side)

# ---------- заголовок ----------
$title = New-Object System.Windows.Forms.Label
$title.Text = 'Меню «Пуск»'
$title.Location = New-Object System.Drawing.Point(270, 26)
$title.AutoSize = $true
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 19)
$title.ForeColor = $C_TEXT
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'Стиль меню «Пуск»'
$sub.Location = New-Object System.Drawing.Point(272, 74)
$sub.AutoSize = $true
$sub.ForeColor = $C_MUTED
$form.Controls.Add($sub)

# ---------- карточки стилей ----------
$script:cards = New-Object System.Collections.ArrayList
$x = 270
foreach ($s in $styles) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($x, 100)
    $card.Size = New-Object System.Drawing.Size(140, 214)
    $card.BackColor = $C_BG
    $card.Tag = $s
    $card.Cursor = 'Hand'

    $card.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $st = $sender.Tag
        $isSel = ([int]$st.mode -eq $script:selected)
        $rect = New-Object System.Drawing.RectangleF 0, 0, ($sender.Width - 1), ($sender.Height - 1)
        $path = New-RoundedPath $rect 8
        $bg = New-Object System.Drawing.SolidBrush ($(if ($isSel) { $C_CARD_HI } else { $C_CARD }))
        $g.FillPath($bg, $path); $bg.Dispose()
        if ($isSel) { $pen = New-Object System.Drawing.Pen $C_ACCENT, 2; $g.DrawPath($pen, $path); $pen.Dispose() }

        $pv = New-Object System.Drawing.RectangleF 14, 14, ($sender.Width - 28), 100
        $pvp = New-RoundedPath $pv 4
        $pbg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#3a3a46'))
        $g.FillPath($pbg, $pvp); $pbg.Dispose(); $pvp.Dispose()

        $fg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#5a5a6b'))
        switch ([int]$st.mode) {
            1 { $g.FillRectangle($fg, 20, 28, 44, 20); $g.FillRectangle($fg, 70, 28, 44, 70); $g.FillRectangle($fg, 20, 54, 44, 44) }
            2 { $g.FillRectangle($fg, 20, 24, 94, 9); $g.FillRectangle($fg, 20, 39, 58, 63); $g.FillRectangle($fg, 84, 39, 30, 63) }
            3 { for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 4; $c++) { $g.FillRectangle($fg, (20 + $c * 25), (28 + $r * 26), 21, 21) } } }
            4 { for ($r = 0; $r -lt 3; $r++) { for ($c = 0; $c -lt 5; $c++) { $g.FillRectangle($fg, (22 + $c * 19), (28 + $r * 22), 15, 17) } } }
            5 { for ($r = 0; $r -lt 4; $r++) { $g.FillRectangle($fg, 22, (26 + $r * 16), 92, 8) } }
        }
        $fg.Dispose()

        $fN = New-Object System.Drawing.Font('Segoe UI', 9.5)
        $tb = New-Object System.Drawing.SolidBrush ($(if ($isSel) { $C_ACCENT } else { $C_TEXT }))
        $g.DrawString($st.name, $fN, $tb, (New-Object System.Drawing.RectangleF 12, 124, ($sender.Width - 24), 42))
        $tb.Dispose(); $fN.Dispose()

        $fD = New-Object System.Drawing.Font('Segoe UI', 8)
        $mb = New-Object System.Drawing.SolidBrush $C_MUTED
        $g.DrawString($st.desc, $fD, $mb, (New-Object System.Drawing.RectangleF 12, 168, ($sender.Width - 24), 40))
        $mb.Dispose(); $fD.Dispose()
    })

    $card.Add_Click({
        param($sender, $e)
        $script:selected = [int]$sender.Tag.mode
        foreach ($c in $script:cards) { $c.Invalidate() }
    })

    $form.Controls.Add($card)
    [void]$script:cards.Add($card)
    $x += 152
}

# ---------- страницы настроек ----------
foreach ($grp in $groups) {
    $page = New-Object System.Windows.Forms.Panel
    $page.Location = New-Object System.Drawing.Point(264, 324)
    $page.Size = New-Object System.Drawing.Size(720, 236)
    $page.BackColor = $C_BG
    $page.AutoScroll = $true
    $page.Visible = $false
    $form.Controls.Add($page)

    $y = 0
    foreach ($it in $grp.items) {
        $cur = Get-Val $it.key
        $exists = $null -ne $cur

        if ($it.kind -eq 'bool') {
            $ctrl = New-Object System.Windows.Forms.CheckBox
            $ctrl.Text = $it.label
            if (-not $exists) { $ctrl.Text += '   (Start11 ещё не записал это значение)' }
            $ctrl.Location = New-Object System.Drawing.Point(0, $y)
            $ctrl.AutoSize = $true
            $ctrl.ForeColor = $(if ($exists) { $C_TEXT } else { $C_MUTED })
            $ctrl.Enabled = $exists
            $ctrl.Checked = ($cur -eq '1')
            $ctrl.Tag = $it.key
            [void]$script:bound.Add($ctrl)
            $page.Controls.Add($ctrl)
            $y += 32
        } else {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text = $it.label
            $lbl.Location = New-Object System.Drawing.Point(0, $y)
            $lbl.AutoSize = $true
            $lbl.ForeColor = $C_TEXT
            $page.Controls.Add($lbl)

            $num = New-Object System.Windows.Forms.NumericUpDown
            $num.Location = New-Object System.Drawing.Point(220, ($y - 3))
            $num.Size = New-Object System.Drawing.Size(70, 24)
            $num.Minimum = $it.min
            $num.Maximum = $it.max
            $num.Value = if ($exists) { [int]$cur } else { 0 }
            $num.Enabled = $exists
            $num.Tag = $it.key
            $num.BackColor = $C_CARD
            $num.ForeColor = $C_TEXT
            $num.BorderStyle = 'FixedSingle'
            [void]$script:bound.Add($num)
            $page.Controls.Add($num)
            $y += 36
        }
    }

    if ($grp.id -eq 'manage') {
        $list = New-Object System.Windows.Forms.ListBox
        $list.Location = New-Object System.Drawing.Point(0, 0)
        $list.Size = New-Object System.Drawing.Size(320, 120)
        $list.BackColor = $C_CARD
        $list.ForeColor = $C_TEXT
        $list.BorderStyle = 'None'
        $page.Controls.Add($list)
        $script:backupList = $list

        $b1 = New-Object System.Windows.Forms.Button
        $b1.Text = 'Восстановить выбранный'
        $b1.Location = New-Object System.Drawing.Point(0, 132)
        $b1.Size = New-Object System.Drawing.Size(220, 32)
        $b1.FlatStyle = 'Flat'
        $b1.BackColor = $C_CARD
        $b1.ForeColor = $C_TEXT
        $b1.Add_Click({
            if (-not $script:backupList.SelectedItem) { return }
            $file = Join-Path $bkDir $script:backupList.SelectedItem
            $data = Get-Content $file -Raw | ConvertFrom-Json
            $n = 0
            foreach ($p in $data.PSObject.Properties) {
                Set-ItemProperty $key -Name $p.Name -Value ([string]$p.Value) -Type String -ErrorAction SilentlyContinue
                $n++
            }
            $status.Text = "Восстановлено значений: $n из $($script:backupList.SelectedItem). Нужна перезагрузка."
        })
        $page.Controls.Add($b1)

        $b2 = New-Object System.Windows.Forms.Button
        $b2.Text = 'Открыть папку бэкапов'
        $b2.Location = New-Object System.Drawing.Point(232, 132)
        $b2.Size = New-Object System.Drawing.Size(184, 32)
        $b2.FlatStyle = 'Flat'
        $b2.BackColor = $C_CARD
        $b2.ForeColor = $C_TEXT
        $b2.Add_Click({ Start-Process explorer.exe $bkDir })
        $page.Controls.Add($b2)

        $b3 = New-Object System.Windows.Forms.Button
        $b3.Text = 'Настройки Start11'
        $b3.Location = New-Object System.Drawing.Point(0, 172)
        $b3.Size = New-Object System.Drawing.Size(220, 32)
        $b3.FlatStyle = 'Flat'
        $b3.BackColor = $C_CARD
        $b3.ForeColor = $C_TEXT
        $b3.Add_Click({ if (Test-Path $configExe) { Start-Process $configExe } })
        $page.Controls.Add($b3)

        $note = New-Object System.Windows.Forms.Label
        $note.Text = 'Перед применением выключи меню Start11: работающий процесс перезаписывает настройки при выходе.'
        $note.Location = New-Object System.Drawing.Point(0, 214)
        $note.Size = New-Object System.Drawing.Size(560, 60)
        $note.ForeColor = $C_MUTED
        $page.Controls.Add($note)
    }

    if ($grp.id -eq 'about') {
        $about = New-Object System.Windows.Forms.Label
        $about.Location = New-Object System.Drawing.Point(0, 0)
        $about.Size = New-Object System.Drawing.Size(680, 220)
        $about.ForeColor = $C_MUTED
        $about.Text = "Start11 Tuner — конфигуратор поверх родных настроек Start11.`n`n" +
                      "Ключ: HKCU\Software\Stardock\Start8\Start8.ini\Start8`n" +
                      "Значения хранятся строками, булевы — 0/1.`n`n" +
                      "Собрано по разбору Start11 3.0.0.4.`n" +
                      "Не делает: активацию и обход лицензии, редактор закреплённых, редактор цветов."
        $page.Controls.Add($about)
    }

    $script:pages[$grp.id] = $page
}

# ---------- навигация ----------
$y = 24
foreach ($grp in $groups) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = '   ' + $grp.name
    $lbl.Location = New-Object System.Drawing.Point(0, $y)
    $lbl.Size = New-Object System.Drawing.Size(230, 40)
    $lbl.TextAlign = 'MiddleLeft'
    $lbl.Tag = $grp.id
    $lbl.Cursor = 'Hand'
    $lbl.ForeColor = $C_MUTED
    $lbl.Add_Click({
        param($sender, $e)
        foreach ($nl in $script:navLabels) { $nl.ForeColor = $C_MUTED; $nl.BackColor = 'Transparent' }
        $sender.ForeColor = $C_TEXT
        $sender.BackColor = $C_BG
        $script:bar.Top = $sender.Top
        foreach ($k in $script:pages.Keys) { $script:pages[$k].Visible = $false }
        $script:pages[$sender.Tag].Visible = $true
        $title.Text = $sender.Text.Trim()
    })
    $side.Controls.Add($lbl)
    [void]$script:navLabels.Add($lbl)
    $y += 44
}

$script:bar = New-Object System.Windows.Forms.Panel
$script:bar.BackColor = $C_ACCENT
$script:bar.Location = New-Object System.Drawing.Point(0, 24)
$script:bar.Size = New-Object System.Drawing.Size(3, 40)
$side.Controls.Add($script:bar)

$script:navLabels[0].ForeColor = $C_TEXT
$script:navLabels[0].BackColor = $C_BG
$script:pages['menu'].Visible = $true

# ---------- статус и кнопки ----------
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(270, 566)
$status.Size = New-Object System.Drawing.Size(700, 46)
$status.ForeColor = $C_MUTED
$form.Controls.Add($status)

$running = (Get-Process Start11_64 -ErrorAction SilentlyContinue) -ne $null
$status.Text = 'Смена стиля между Windows 10 и Windows 11 требует перезагрузки.'
if ($running) {
    $status.Text += "`n" + 'Start11 запущен — он перезапишет значения при выходе. Сначала выключи его меню.'
    $status.ForeColor = $C_ACCENT
}

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Применить'
$btnApply.Location = New-Object System.Drawing.Point(270, 620)
$btnApply.Size = New-Object System.Drawing.Size(160, 34)
$btnApply.FlatStyle = 'Flat'
$btnApply.BackColor = $C_ACCENT
$btnApply.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#1b1b1f')
$btnApply.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnApply)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = 'Откатить'
$btnRevert.Location = New-Object System.Drawing.Point(442, 620)
$btnRevert.Size = New-Object System.Drawing.Size(160, 34)
$btnRevert.FlatStyle = 'Flat'
$btnRevert.BackColor = $C_CARD
$btnRevert.ForeColor = $C_TEXT
$form.Controls.Add($btnRevert)

# ---------- действия ----------
$btnApply.Add_Click({
    $file = Save-Backup
    $written = 0
    if ($script:selected -ge 1) {
        Set-ItemProperty $key -Name 'MenuMode' -Value ([string]$script:selected) -Type String
        $written++
    }
    foreach ($ctrl in $script:bound) {
        if (-not $ctrl.Enabled) { continue }
        $v = if ($ctrl -is [System.Windows.Forms.CheckBox]) {
            if ($ctrl.Checked) { '1' } else { '0' }
        } else { [string][int]$ctrl.Value }
        Set-ItemProperty $key -Name $ctrl.Tag -Value $v -Type String
        $written++
    }
    $status.ForeColor = $C_TEXT
    $status.Text = "Записано значений: $written. Бэкап: $file" + "`n" + 'Закрываю Start11 и перезапускаю explorer.'
    $form.Refresh()

    # Start11 при выходе перезаписывает настройки — закрываем его до записи в оболочку.
    $stopNote = ''
    $s11 = Get-Process Start11_64 -ErrorAction SilentlyContinue
    if ($s11) {
        try { $s11 | Stop-Process -Force -ErrorAction Stop } catch { $stopNote = ' Start11 закрыть не удалось (доступ запрещён) — он может вернуть старые значения.' }
    }

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Process explorer.exe
    Start-Sleep -Seconds 4

    if ($stopNote) {
        Add-Content (Join-Path $bkDir 'last-apply.txt') ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $stopNote.Trim())
    }
    $form.Close()
})

$btnRevert.Add_Click({
    $last = Get-ChildItem $bkDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $last) { $status.Text = 'Бэкапов пока нет.'; return }
    $data = Get-Content $last.FullName -Raw | ConvertFrom-Json
    foreach ($p in $data.PSObject.Properties) {
        Set-ItemProperty $key -Name $p.Name -Value ([string]$p.Value) -Type String -ErrorAction SilentlyContinue
    }
    $status.Text = "Откат из $($last.Name). Перезагрузись, чтобы применилось."
})

# заполнить список бэкапов
New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
Get-ChildItem $bkDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 20 |
    ForEach-Object { [void]$script:backupList.Items.Add($_.Name) }

[void]$form.ShowDialog()
