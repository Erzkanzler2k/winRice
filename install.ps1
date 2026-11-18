# Deploy winRice: install packages, sync configs, enable autostart.
# Re-run after editing anything in this repo:  powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

$packages = 'glzr-io.glazewm', 'AmN.yasb', 'wez.wezterm', 'Starship.Starship', 'DEVCOM.JetBrainsMonoNerdFont'
foreach ($id in $packages) {
    winget install --id $id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
}

$configs = @(
    @{ src = 'glazewm\config.yaml'; dst = "$env:USERPROFILE\.glzr\glazewm\config.yaml" },
    @{ src = 'yasb\config.yaml'; dst = "$env:USERPROFILE\.config\yasb\config.yaml" },
    @{ src = 'yasb\styles.css'; dst = "$env:USERPROFILE\.config\yasb\styles.css" },
    @{ src = 'wezterm\.wezterm.lua'; dst = "$env:USERPROFILE\.wezterm.lua" },
    @{ src = 'starship\starship.toml'; dst = "$env:USERPROFILE\.config\starship.toml" }
)
foreach ($c in $configs) {
    New-Item -ItemType Directory -Force -Path (Split-Path $c.dst) | Out-Null
    Copy-Item (Join-Path $repo $c.src) $c.dst -Force
    Write-Host "synced $($c.dst)"
}

# starship prompt in Windows PowerShell profile
$starship = (Get-Command starship -ErrorAction SilentlyContinue).Source
if (-not $starship) { $starship = 'C:\Program Files\starship\bin\starship.exe' }
$profilePath = $PROFILE.CurrentUserAllHosts
New-Item -ItemType Directory -Force -Path (Split-Path $profilePath) | Out-Null
if (-not (Test-Path $profilePath) -or -not (Select-String -Path $profilePath -Pattern 'starship\.exe' -Quiet)) {
    Add-Content $profilePath "`nInvoke-Expression (& `"$starship`" init powershell)"
    Write-Host "starship -> $profilePath"
}

# autostart
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GlazeWM' -Value '"C:\Program Files\glzr.io\GlazeWM\glazewm.exe"'
& 'C:\Program Files\YASB\yasbc.exe' enable-autostart | Out-Null

# wallpaper + hide desktop icons
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency -Value 1 -Type DWord
$wp = "$env:USERPROFILE\Pictures\winRice-wallpaper.png"
Copy-Item (Join-Path $repo 'wallpaper\tokyonight.png') $wp -Force
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
$spi = Add-Type -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);' -Name Spi -Namespace winRice -PassThru
$spi::SystemParametersInfo(20, 0, $wp, 3) | Out-Null

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$iconsShown = (Get-ItemProperty $adv -Name HideIcons -ErrorAction SilentlyContinue).HideIcons -ne 1
Set-ItemProperty $adv -Name HideIcons -Value 1 -Type DWord
if ($iconsShown) {
    $shell = Add-Type -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string w); [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);' -Name Shell -Namespace winRice -PassThru
    $shell::SendMessage($shell::FindWindow('Progman', $null), 0x0111, [IntPtr]0x7402, [IntPtr]::Zero) | Out-Null
}

# apply now
$glaze = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
if (Get-Process glazewm -ErrorAction SilentlyContinue) {
    & $glaze command wm-reload-config | Out-Null
} else {
    Start-Process 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
}
& 'C:\Program Files\YASB\yasbc.exe' stop | Out-Null
Start-Sleep -Seconds 1
taskkill /IM yasb.exe /F | Out-Null
Start-Process 'C:\Program Files\YASB\yasb.exe'

Write-Host 'done. log in again (or start GlazeWM + YASB) to pick up autostart.'
