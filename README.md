<div align="center">

# winRice

**Tiling, keyboard-driven Windows 11 in the colours of Tokyo Night.**

![Windows 11](https://img.shields.io/badge/Windows-11-7aa2f7?style=flat-square&logo=windows11&logoColor=white)
![MIT](https://img.shields.io/badge/license-MIT-c0caf5?style=flat-square)

<img src="docs/bar.png" alt="winRice bar" width="100%">

**English** · [Русский](README.ru.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md)

</div>

## Install

```powershell
git clone https://github.com/Erzkanzler2k/winRice
cd winRice
powershell -ExecutionPolicy Bypass -File install.ps1
```

Requires Windows 11 22H2+ and `winget`. The script installs GlazeWM, YASB, WezTerm, Starship and Fastfetch, copies the configs, sets the wallpaper, hides desktop icons and registers autostart. It is idempotent — re-run it after any edit.

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
| `wallpaper/tokyonight.png` | `%USERPROFILE%\Pictures\winRice-wallpaper.png` |

Palette: `#1a1b26` background, `#c0caf5` text, `#7aa2f7` accent, `#565f89` muted.

## Notes

- The bar hides on fullscreen apps (`hide_on_fullscreen` in `yasb/config.yaml`).
- Some `Win` combinations stay with Windows — use the `Alt` variant.
- The native Start menu and taskbar are untouched; `Alt+Space` is the launcher.
- Logs: `~\.config\yasb\yasb.log`, `~\.glzr\glazewm\errors.log`.

## Credits

[GlazeWM](https://github.com/glzr-io/GlazeWM) · [YASB](https://github.com/amnweb/yasb) · [WezTerm](https://wezterm.org) · [Starship](https://starship.rs) · [Fastfetch](https://github.com/fastfetch-cli/fastfetch) · [JetBrains Mono NF](https://github.com/ryanoasis/nerd-fonts) · palette [Tokyo Night](https://github.com/folke/tokyonight.nvim) · inspired by [Omarchy](https://github.com/basecamp/omarchy).

[MIT](LICENSE) © 2026 Erzkanzler2k
