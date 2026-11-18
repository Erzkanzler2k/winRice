<div align="center">

# winRice

**Omarchy / Hyprland vibes on Windows 11** — tiling, a waybar-style bar, Tokyo Night terminal.

![bar](docs/bar.png)

GlazeWM · YASB · WezTerm · Starship · Fastfetch · JetBrainsMono Nerd Font

</div>

---

## What you get

| | |
|---|---|
| **Tiling like i3 / Hyprland** | GlazeWM: `Alt` or `Win` + `hjkl`, 9 workspaces, 6px gaps, rounded corners, no title bars, accent border on the focused window |
| **waybar-style bar** | YASB, 30px on top: launcher, workspaces, active window, clock, CPU, RAM, volume. Tokyo Night palette, blurred, at 55% opacity |
| **rofi / spotlight launcher** | `Alt+Space` or the 🔍 on the bar — searchable app list with icons |
| **Terminal** | WezTerm in Tokyo Night, JetBrainsMono NF, acrylic background, `Ctrl+Shift+d/e` splits, PowerShell + Starship `λ` |
| **Fetch** | `fastfetch` with a Windows 11 logo in the accent colour, memory/disk bars. Runs every time a WezTerm tab opens |
| **Desktop** | Dark Tokyo Night wallpaper, desktop icons hidden, Windows transparency enabled |

## Shell

![fetch](docs/fetch.png)

## Install

```powershell
git clone https://github.com/Erzkanzler2k/winRice
cd winRice
powershell -ExecutionPolicy Bypass -File install.ps1
```

The script installs everything via winget, copies the configs into place, sets the wallpaper, hides desktop icons, enables autostart for GlazeWM and YASB, and reloads both. Re-run it after editing anything here.

## Keys

Mod = `Alt` (GlazeWM's recommendation) or `Win` for the shortcuts Windows does not reserve.

| Keys | Action |
|:--|:--|
| `Alt/Win + Space` | **launcher** |
| `Alt/Win + Enter` | WezTerm |
| `Alt/Win + H J K L` | focus window |
| `Alt/Win + Shift + H J K L` | move window |
| `Alt/Win + R` | resize mode (`hjkl`, `Esc` to exit) |
| `Alt/Win + V` | toggle tiling direction |
| `Alt/Win + F` | fullscreen |
| `Alt/Win + Shift + Space` | float window |
| `Alt/Win + Q` | close window |
| `Alt/Win + 1..9` | workspace |
| `Alt/Win + Shift + 1..9` | move window to workspace |
| `Alt + S` / `Alt + A` | next / previous workspace |
| `Alt/Win + Shift + R` | reload config |
| `Alt + Shift + E` | quit GlazeWM |

## Repo layout

```
glazewm/config.yaml     -> %USERPROFILE%\.glzr\glazewm\config.yaml
yasb/config.yaml        -> %USERPROFILE%\.config\yasb\config.yaml
yasb/styles.css         -> %USERPROFILE%\.config\yasb\styles.css
wezterm/.wezterm.lua    -> %USERPROFILE%\.wezterm.lua
starship/starship.toml  -> %USERPROFILE%\.config\starship.toml
fastfetch/              -> %USERPROFILE%\.config\fastfetch\ (config.jsonc + logo.txt)
wallpaper/tokyonight.png-> %USERPROFILE%\Pictures\winRice-wallpaper.png
```

## Known limits

- The native taskbar is still there (bottom). Hide it in *Settings → Personalisation → Taskbar → Automatically hide* if you want the full Hyprland feel.
- The `Win` key still opens the native Start menu. A single-key remap needs PowerToys or SharpKeys; `Alt+Space` is the launcher here.
- Per-window transparency is off: without blur it makes text unreadable. Opacity lives on the bar and the terminal instead.
- Windows can reset the wallpaper after a game switches display modes; re-run `install.ps1` to set it back.

## Credits

[GlazeWM](https://github.com/glzr-io/GlazeWM) · [YASB](https://github.com/amnweb/yasb) · [WezTerm](https://wezterm.org) · [Starship](https://starship.rs) · palette after [Tokyo Night](https://github.com/folke/tokyonight.nvim), layout inspired by [Omarchy](https://github.com/basecamp/omarchy).
