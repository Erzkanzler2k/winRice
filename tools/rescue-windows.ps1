# Brings back windows GlazeWM left behind when it was killed instead of exited:
# windows it had cloaked on a workspace it later forgot, and windows it adopted
# as "minimized". Run it after restarting GlazeWM.
# Usage: powershell -ExecutionPolicy Bypass -File tools\rescue-windows.ps1
Add-Type -Namespace winRice -Name Win -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
[DllImport("user32.dll")] public static extern int GetWindowLongW(IntPtr h, int i);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
'@
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

# 1. uncloak windows parked outside the screen
$targets = New-Object System.Collections.ArrayList
$cb = [winRice.Win+EnumProc] {
    param($h, $p)
    if (-not [winRice.Win]::IsWindowVisible($h)) { return $true }
    if ([winRice.Win]::GetWindowLongW($h, -20) -band 0x80) { return $true }   # WS_EX_TOOLWINDOW
    $sb = New-Object System.Text.StringBuilder 512
    [void][winRice.Win]::GetWindowTextW($h, $sb, 512)
    if ($sb.Length -eq 0) { return $true }
    $cloaked = 0
    [void][winRice.Win]::DwmGetWindowAttribute($h, 13, [ref]$cloaked, 4)
    $r = New-Object winRice.Win+RECT
    [void][winRice.Win]::GetWindowRect($h, [ref]$r)
    $offScreen = $r.R -le $screen.Left -or $r.L -ge ($screen.Left + $screen.Width) -or $r.B -le $screen.Top -or $r.T -ge ($screen.Top + $screen.Height)
    if ($cloaked -ne 0 -or $offScreen) { [void]$targets.Add([pscustomobject]@{ H = $h; Title = $sb.ToString() }) }
    return $true
}
[void][winRice.Win]::EnumWindows($cb, [IntPtr]::Zero)

foreach ($w in $targets) {
    $zero = 0
    [void][winRice.Win]::DwmSetWindowAttribute($w.H, 13, [ref]$zero, 4)
    [void][winRice.Win]::ShowWindow($w.H, 9)   # SW_RESTORE
    $r = New-Object winRice.Win+RECT
    [void][winRice.Win]::GetWindowRect($w.H, [ref]$r)
    $width = [Math]::Max($r.R - $r.L, 480)
    $height = [Math]::Max($r.B - $r.T, 360)
    $x = $screen.Left + [int](($screen.Width - $width) / 2)
    $y = $screen.Top + [int](($screen.Height - $height) / 2)
    [void][winRice.Win]::SetWindowPos($w.H, [IntPtr]::Zero, $x, $y, $width, $height, 0x0040)   # SWP_SHOWWINDOW
    "unhid: $($w.Title)"
}

# 2. unminimize what GlazeWM adopted as minimized
$glaze = @("$env:ProgramFiles\glzr.io\GlazeWM\cli\glazewm.exe", 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $glaze) { $glaze = (Get-Command glazewm -ErrorAction SilentlyContinue).Source }
if ($glaze) {
    $json = & $glaze query windows 2>$null | Out-String
    if ($json) {
        foreach ($w in ($json | ConvertFrom-Json).data.windows) {
            if ($w.state.type -eq 'minimized') {
                & $glaze command --id $w.id toggle-minimized | Out-Null
                "restored: $($w.title)"
            }
        }
    }
}
