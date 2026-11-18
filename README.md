<div align="center">

# winRice

**Tiling, keyboard-driven Windows 11 in the colours of Tokyo Night.**

![Windows 11](https://img.shields.io/badge/Windows-11-7aa2f7?style=flat-square&logo=windows11&logoColor=white)
![MIT](https://img.shields.io/badge/license-MIT-c0caf5?style=flat-square)

<img src="docs/bar.png" alt="winRice bar" width="100%">

**English** · [Русский](README.ru.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md)

</div>

## Launcher

`Win` opens the winRice launcher. The native Start menu is out of the way: AutoHotkey takes the key over, so pressing it can no longer summon the Windows shell — `Win+E`, `Win+D`, `Win+L` and `Win+S` are re-implemented in `autohotkey/win-launcher.ahk`.

<div align="center">
  <img src="docs/launcher.png" alt="winRice launcher" width="480">
</div>

## Install

```powershell
git clone https://github.com/Erzkanzler2k/winRice
cd winRice
powershell -ExecutionPolicy Bypass -File install.ps1
```

Requires Windows 11 22H2+ and `winget`. The script installs GlazeWM, YASB, WezTerm, Starship, Fastfetch and AutoHotkey, copies the configs, sets the wallpaper, hides desktop icons and registers autostart. It is idempotent — re-run it after any edit.

## Keys

`Alt` or `Win` + …

| Keys | Action |
|:--|:--|
| `H J K L` | focus window |
| `Shift + H J K L` | move window |
| `1..9` | workspace |
| `Shift + 1..9` | window to workspace |
| `R` | resize mode (`Esc` exits) |
| `V` | tiling direction |
| `F` | fullscreen |
| `Shift + Space` | float |
| `Q` | close |
| `Space` | launcher |
| `Alt + Tab` | cycle windows in the workspace |
| `Enter` | WezTerm |
| `Shift + R` | reload config |

`Alt + S` / `Alt + A` — next / previous workspace. `Alt + Shift + E` — quit GlazeWM.

## Files

| Repo | Installed to |
|:--|:--|
| `glazewm/config.yaml` | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| `yasb/` | `%USERPROFILE%\.config\yasb\` |
| `wezterm/.wezterm.lua` | `%USERPROFILE%\.wezterm.lua` |
| `starship/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `fastfetch/` | `%USERPROFILE%\.config\fastfetch\` |
| `autohotkey/win-launcher.ahk` | `%USERPROFILE%\.config\winrice\win-launcher.ahk` |
| `wallpaper/tokyonight.png` | `%USERPROFILE%\Pictures\winRice-wallpaper.png` |

Palette: `#1a1b26` background, `#c0caf5` text, `#7aa2f7` accent, `#565f89` muted.

## Notes

- The bar hides on fullscreen apps (`hide_on_fullscreen` in `yasb/config.yaml`).
- GlazeWM hides other workspaces by cloaking their windows. Kill it and the cloak can outlive the restart — `tools/rescue-windows.ps1` uncloaks those windows and unminimizes what it re-adopted as minimized.
- `Win` is owned by winRice, so other `Win` combinations no longer reach Windows — use the `Alt` variant.
- To hand the key back and keep the native Start menu, delete the `winRice` entry from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` and kill `AutoHotkey64.exe`.
- Logs: `~\.config\yasb\yasb.log`, `~\.glzr\glazewm\errors.log`.

## Credits

[GlazeWM](https://github.com/glzr-io/GlazeWM) · [YASB](https://github.com/amnweb/yasb) · [WezTerm](https://wezterm.org) · [AutoHotkey](https://www.autohotkey.com) · [Starship](https://starship.rs) · [Fastfetch](https://github.com/fastfetch-cli/fastfetch) · [JetBrains Mono NF](https://github.com/ryanoasis/nerd-fonts) · palette [Tokyo Night](https://github.com/folke/tokyonight.nvim) · inspired by [Omarchy](https://github.com/basecamp/omarchy).

[MIT](LICENSE) © 2026 Erzkanzler2k
