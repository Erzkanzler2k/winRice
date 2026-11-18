#Requires -Version 5.1
<#
  Start11 Tuner — конфигуратор Start11 в раскладке его родного окна.

  Все значения читаются из HKCU\Software\Stardock\Start8\Start8.ini\Start8 и
  пишутся обратно строками — так их хранит сам Start11. Список контролов
  строится из того, что реально лежит в ключе, поэтому охватывает все настройки,
  которые Start11 успел записать.

  Кнопка «Применить»: бэкап -> попытка закрыть Start11 -> перезапуск explorer ->
  окно закрывается. Без перезагрузки; исключение — смена стиля между 10 и 11.

  Не делает: активацию/обход лицензии, редактор закреплённых (подключи
  Right/RightMode в неразобранном формате).
#>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$key       = 'HKCU:\Software\Stardock\Start8\Start8.ini\Start8'
$bkDir     = Join-Path $env:LOCALAPPDATA 'Start11Tuner'
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

# эти значения не показываем и не перезаписываем: служебные для лицензии/кэша
$skip = @('LS', 'TextLookupD', 'LastSeenOS2', 'QC', 'MenuMode')

$styles = @(
    @{ mode = 1; name = 'Стиль Windows 7';   desc = 'Классическое меню Windows 7.' },
    @{ mode = 2; name = 'Стиль Modern';      desc = 'Обновлённый стиль Windows 7.' },
    @{ mode = 3; name = 'Стиль Windows 10';  desc = 'Стиль Windows 10 с улучшениями.' },
    @{ mode = 4; name = 'Стиль Windows 11';  desc = 'Стиль Windows 11 с улучшениями.' },
    @{ mode = 5; name = 'Стиль Windows App'; desc = 'Обновлённый стиль Windows 11.' }
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
    New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
    $obj = [ordered]@{}
    foreach ($p in (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) { $obj[$p.Name] = $p.Value }
    $file = Join-Path $bkDir ("backup-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $obj | ConvertTo-Json -Depth 3 | Set-Content $file -Encoding UTF8
    $file
}

function Get-GroupName([string]$name) {
    if ($name -match 'Taskbar') { return 'taskbar' }
    if ($name -match 'Search') { return 'search' }
    if ($name -match 'Right|Tile|Pins|Icon|Metro|Folder') { return 'pins' }
    if ($name -match '^(S11_|Menu|Acrylic|Custom|Background|UseFormica|FullUI|Texture|Skinned|Darken)') { return 'look' }
    return 'other'
}

# ---------- снимок текущих значений ----------
$props = (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' -and $skip -notcontains $_.Name }
$values = [ordered]@{}
foreach ($p in $props) { $values[$p.Name] = [string]$p.Value }

$script:selected = 0
$mm = $values['MenuMode']
$rawMode = (Get-ItemProperty $key -Name MenuMode -ErrorAction SilentlyContinue).MenuMode
if ($rawMode -and [int]$rawMode -ge 1 -and [int]$rawMode -le 5) { $script:selected = [int]$rawMode }

$bucket = [ordered]@{ look = @(); taskbar = @(); pins = @(); search = @(); other = @() }
foreach ($n in $values.Keys) { $bucket[(Get-GroupName $n)] += $n }

$script:writers = New-Object System.Collections.ArrayList   # контролы, которые пишем в реестр
$script:navLabels = New-Object System.Collections.ArrayList
$script:pages = @{}

# ---------- окно ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Start11 Tuner'
$form.Size = New-Object System.Drawing.Size(1020, 706)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = $C_BG
$form.ForeColor = $C_TEXT
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$side = New-Object System.Windows.Forms.Panel
$side.Location = New-Object System.Drawing.Point(0, 0)
$side.Size = New-Object System.Drawing.Size(230, 668)
$side.BackColor = $C_SIDE
$form.Controls.Add($side)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Меню «Пуск»'
$title.Location = New-Object System.Drawing.Point(270, 22)
$title.AutoSize = $true
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$title.ForeColor = $C_TEXT
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'Стиль меню «Пуск»'
$sub.Location = New-Object System.Drawing.Point(272, 66)
$sub.AutoSize = $true
$sub.ForeColor = $C_MUTED
$form.Controls.Add($sub)

# ---------- карточки стилей ----------
$script:cards = New-Object System.Collections.ArrayList
$x = 270
foreach ($s in $styles) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($x, 92)
    $card.Size = New-Object System.Drawing.Size(136, 206)
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

        $pv = New-Object System.Drawing.RectangleF 14, 14, ($sender.Width - 28), 96
        $pvp = New-RoundedPath $pv 4
        $pbg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#3a3a46'))
        $g.FillPath($pbg, $pvp); $pbg.Dispose(); $pvp.Dispose()

        $fg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#5a5a6b'))
        switch ([int]$st.mode) {
            1 { $g.FillRectangle($fg, 20, 26, 44, 20); $g.FillRectangle($fg, 70, 26, 44, 68); $g.FillRectangle($fg, 20, 52, 44, 42) }
            2 { $g.FillRectangle($fg, 20, 22, 94, 9); $g.FillRectangle($fg, 20, 37, 58, 61); $g.FillRectangle($fg, 84, 37, 30, 61) }
            3 { for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 4; $c++) { $g.FillRectangle($fg, (20 + $c * 25), (26 + $r * 26), 21, 21) } } }
            4 { for ($r = 0; $r -lt 3; $r++) { for ($c = 0; $c -lt 5; $c++) { $g.FillRectangle($fg, (22 + $c * 19), (26 + $r * 22), 15, 17) } } }
            5 { for ($r = 0; $r -lt 4; $r++) { $g.FillRectangle($fg, 22, (24 + $r * 16), 92, 8) } }
        }
        $fg.Dispose()

        $fN = New-Object System.Drawing.Font('Segoe UI', 9.5)
        $tb = New-Object System.Drawing.SolidBrush ($(if ($isSel) { $C_ACCENT } else { $C_TEXT }))
        $g.DrawString($st.name, $fN, $tb, (New-Object System.Drawing.RectangleF 12, 120, ($sender.Width - 24), 42))
        $tb.Dispose(); $fN.Dispose()

        $fD = New-Object System.Drawing.Font('Segoe UI', 8)
        $mb = New-Object System.Drawing.SolidBrush $C_MUTED
        $g.DrawString($st.desc, $fD, $mb, (New-Object System.Drawing.RectangleF 12, 162, ($sender.Width - 24), 40))
        $mb.Dispose(); $fD.Dispose()
    })

    $card.Add_Click({
        param($sender, $e)
        $script:selected = [int]$sender.Tag.mode
        foreach ($c in $script:cards) { $c.Invalidate() }
    })

    $form.Controls.Add($card)
    [void]$script:cards.Add($card)
    $x += 146
}

# ---------- поиск по настройкам ----------
$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Location = New-Object System.Drawing.Point(270, 306)
$searchBox.Size = New-Object System.Drawing.Size(300, 24)
$searchBox.BackColor = $C_CARD
$searchBox.ForeColor = $C_TEXT
$searchBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($searchBox)

$searchHint = New-Object System.Windows.Forms.Label
$searchHint.Text = 'фильтр по имени ключа'
$searchHint.Location = New-Object System.Drawing.Point(580, 310)
$searchHint.AutoSize = $true
$searchHint.ForeColor = $C_MUTED
$form.Controls.Add($searchHint)

# ---------- страницы ----------
$groups = @(
    @{ id = 'look';    name = 'Меню «Пуск»' },
    @{ id = 'taskbar'; name = 'Панель задач' },
    @{ id = 'pins';    name = 'Закреплённые на панели' },
    @{ id = 'search';  name = 'Поиск' },
    @{ id = 'other';   name = 'Прочие ключи' },
    @{ id = 'manage';  name = 'Управление' },
    @{ id = 'about';   name = 'О программе' }
)

foreach ($grp in $groups) {
    $page = New-Object System.Windows.Forms.Panel
    $page.Location = New-Object System.Drawing.Point(264, 338)
    $page.Size = New-Object System.Drawing.Size(724, 236)
    $page.BackColor = $C_BG
    $page.AutoScroll = $true
    $page.Visible = $false
    $form.Controls.Add($page)

    if ($grp.id -in @('look', 'taskbar', 'pins', 'search', 'other')) {
        $y = 0
        foreach ($n in $bucket[$grp.id]) {
            $cur = $values[$n]
            if ($cur -eq '0' -or $cur -eq '1') {
                $cb = New-Object System.Windows.Forms.CheckBox
                $cb.Text = $n
                $cb.Location = New-Object System.Drawing.Point(0, $y)
                $cb.AutoSize = $true
                $cb.ForeColor = $C_TEXT
                $cb.Checked = ($cur -eq '1')
                $cb.Tag = $n
                [void]$script:writers.Add($cb)
                $page.Controls.Add($cb)
                $y += 28
            } elseif ($cur -match '^\d{1,4}$') {
                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text = $n
                $lbl.Location = New-Object System.Drawing.Point(0, $y)
                $lbl.AutoSize = $true
                $lbl.ForeColor = $C_TEXT
                $page.Controls.Add($lbl)

                $num = New-Object System.Windows.Forms.NumericUpDown
                $num.Location = New-Object System.Drawing.Point(260, ($y - 3))
                $num.Size = New-Object System.Drawing.Size(80, 24)
                $num.Minimum = 0
                $num.Maximum = 9999
                $num.Value = [int]$cur
                $num.Tag = $n
                $num.BackColor = $C_CARD
                $num.ForeColor = $C_TEXT
                [void]$script:writers.Add($num)
                $page.Controls.Add($num)
                $y += 32
            } else {
                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text = $n
                $lbl.Location = New-Object System.Drawing.Point(0, $y)
                $lbl.AutoSize = $true
                $lbl.ForeColor = $C_TEXT
                $page.Controls.Add($lbl)

                $txt = New-Object System.Windows.Forms.TextBox
                $txt.Location = New-Object System.Drawing.Point(260, ($y - 3))
                $txt.Size = New-Object System.Drawing.Size(420, 24)
                $txt.Text = $cur
                $txt.Tag = $n
                $txt.BackColor = $C_CARD
                $txt.ForeColor = $C_TEXT
                $txt.BorderStyle = 'FixedSingle'
                [void]$script:writers.Add($txt)
                $page.Controls.Add($txt)
                $y += 32
            }
        }
        if ($bucket[$grp.id].Count -eq 0) {
            $empty = New-Object System.Windows.Forms.Label
            $empty.Text = 'Start11 ещё не записывал ключи для этого раздела.'
            $empty.Location = New-Object System.Drawing.Point(0, 0)
            $empty.AutoSize = $true
            $empty.ForeColor = $C_MUTED
            $page.Controls.Add($empty)
        }
    }

    if ($grp.id -eq 'manage') {
        $list = New-Object System.Windows.Forms.ListBox
        $list.Location = New-Object System.Drawing.Point(0, 0)
        $list.Size = New-Object System.Drawing.Size(330, 130)
        $list.BackColor = $C_CARD
        $list.ForeColor = $C_TEXT
        $list.BorderStyle = 'None'
        $page.Controls.Add($list)
        $script:backupList = $list

        $b1 = New-Object System.Windows.Forms.Button
        $b1.Text = 'Восстановить выбранный'
        $b1.Location = New-Object System.Drawing.Point(0, 142)
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
            $script:status.Text = "Восстановлено значений: $n из $($script:backupList.SelectedItem)."
        })
        $page.Controls.Add($b1)

        $b2 = New-Object System.Windows.Forms.Button
        $b2.Text = 'Открыть папку бэкапов'
        $b2.Location = New-Object System.Drawing.Point(232, 142)
        $b2.Size = New-Object System.Drawing.Size(184, 32)
        $b2.FlatStyle = 'Flat'
        $b2.BackColor = $C_CARD
        $b2.ForeColor = $C_TEXT
        $b2.Add_Click({ Start-Process explorer.exe $bkDir })
        $page.Controls.Add($b2)

        $b3 = New-Object System.Windows.Forms.Button
        $b3.Text = 'Настройки Start11'
        $b3.Location = New-Object System.Drawing.Point(0, 182)
        $b3.Size = New-Object System.Drawing.Size(220, 32)
        $b3.FlatStyle = 'Flat'
        $b3.BackColor = $C_CARD
        $b3.ForeColor = $C_TEXT
        $b3.Add_Click({ if (Test-Path $configExe) { Start-Process $configExe } })
        $page.Controls.Add($b3)

        $note = New-Object System.Windows.Forms.Label
        $note.Text = 'Перед применением лучше выйти из Start11 из его трея: работающий процесс перезаписывает настройки при выходе.'
        $note.Location = New-Object System.Drawing.Point(0, 226)
        $note.Size = New-Object System.Drawing.Size(560, 50)
        $note.ForeColor = $C_MUTED
        $page.Controls.Add($note)
    }

    if ($grp.id -eq 'about') {
        $about = New-Object System.Windows.Forms.Label
        $about.Location = New-Object System.Drawing.Point(0, 0)
        $about.Size = New-Object System.Drawing.Size(690, 240)
        $about.ForeColor = $C_MUTED
        $about.Text = "Start11 Tuner — редактор всех настроек, которые Start11 хранит в реестре.`n`n" +
                      "Ключ: HKCU\Software\Stardock\Start8\Start8.ini\Start8`n" +
                      "Контролы строятся по фактическому содержимому ключа: 0/1 — галочки,`n" +
                      "числа — счётчики, остальное — поля ввода.`n`n" +
                      "Служебные значения (LS, TextLookupD, LastSeenOS2, QC) скрыты и не пишутся.`n" +
                      "Смена стиля между Windows 10 и Windows 11 требует перезагрузки."
        $page.Controls.Add($about)
    }

    $script:pages[$grp.id] = $page
}

# фильтр
$searchBox.Add_TextChanged({
    $q = $searchBox.Text.Trim().ToLower()
    foreach ($pid in @('look', 'taskbar', 'pins', 'search', 'other')) {
        foreach ($ctrl in $script:pages[$pid].Controls) {
            if ($ctrl.Tag) {
                $ctrl.Visible = ($q -eq '' -or ([string]$ctrl.Tag).ToLower().Contains($q))
            }
        }
    }
})

# ---------- навигация ----------
$y = 20
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
$script:bar.Location = New-Object System.Drawing.Point(0, 20)
$script:bar.Size = New-Object System.Drawing.Size(3, 40)
$side.Controls.Add($script:bar)
$script:navLabels[0].ForeColor = $C_TEXT
$script:navLabels[0].BackColor = $C_BG
$script:pages['look'].Visible = $true

# ---------- статус и кнопки ----------
$script:status = New-Object System.Windows.Forms.Label
$script:status.Location = New-Object System.Drawing.Point(270, 584)
$script:status.Size = New-Object System.Drawing.Size(720, 32)
$script:status.ForeColor = $C_MUTED
$form.Controls.Add($script:status)

$running = (Get-Process Start11_64 -ErrorAction SilentlyContinue) -ne $null
$script:status.Text = "Ключей в редакторе: $($values.Count). Смена стиля 10/11 требует перезагрузки."
if ($running) { $script:status.Text += ' Start11 запущен — он перепишет значения при выходе.' ; $script:status.ForeColor = $C_ACCENT }

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Применить'
$btnApply.Location = New-Object System.Drawing.Point(270, 624)
$btnApply.Size = New-Object System.Drawing.Size(160, 34)
$btnApply.FlatStyle = 'Flat'
$btnApply.BackColor = $C_ACCENT
$btnApply.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#1b1b1f')
$btnApply.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnApply)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = 'Откатить'
$btnRevert.Location = New-Object System.Drawing.Point(442, 624)
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
    foreach ($ctrl in $script:writers) {
        $v = if ($ctrl -is [System.Windows.Forms.CheckBox]) {
            if ($ctrl.Checked) { '1' } else { '0' }
        } elseif ($ctrl -is [System.Windows.Forms.NumericUpDown]) {
            [string][int]$ctrl.Value
        } else { [string]$ctrl.Text }
        Set-ItemProperty $key -Name $ctrl.Tag -Value $v -Type String
        $written++
    }

    $stopNote = ''
    $s11 = Get-Process Start11_64 -ErrorAction SilentlyContinue
    if ($s11) {
        try { $s11 | Stop-Process -Force -ErrorAction Stop } catch { $stopNote = 'Start11 закрыть не удалось (доступ запрещён) — он может вернуть старые значения.' }
    }
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Process explorer.exe
    Start-Sleep -Seconds 4

    New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
    Add-Content (Join-Path $bkDir 'last-apply.txt') ("{0} wrote={1} backup={2} {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $written, $file, $stopNote)
    $form.Close()
})

$btnRevert.Add_Click({
    $last = Get-ChildItem $bkDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $last) { $script:status.Text = 'Бэкапов пока нет.'; return }
    $data = Get-Content $last.FullName -Raw | ConvertFrom-Json
    foreach ($p in $data.PSObject.Properties) {
        Set-ItemProperty $key -Name $p.Name -Value ([string]$p.Value) -Type String -ErrorAction SilentlyContinue
    }
    $script:status.Text = "Откат из $($last.Name). Значения применятся после перезапуска explorer."
})

New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
Get-ChildItem $bkDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 20 |
    ForEach-Object { [void]$script:backupList.Items.Add($_.Name) }

[void]$form.ShowDialog()
