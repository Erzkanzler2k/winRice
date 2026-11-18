<div align="center">

# winRice

**Тайловый Windows 11 под клавиатуру, в палитре Tokyo Night.**

![Windows 11](https://img.shields.io/badge/Windows-11-7aa2f7?style=flat-square&logo=windows11&logoColor=white)
![MIT](https://img.shields.io/badge/license-MIT-c0caf5?style=flat-square)

<img src="docs/bar.png" alt="бар winRice" width="100%">

[English](README.md) · **Русский** · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md)

</div>

## Установка

```powershell
git clone https://github.com/Erzkanzler2k/winRice
cd winRice
powershell -ExecutionPolicy Bypass -File install.ps1
```

Нужны Windows 11 22H2+ и `winget`. Скрипт ставит GlazeWM, YASB, WezTerm, Starship и Fastfetch, копирует конфиги, ставит обои, скрывает иконки рабочего стола и включает автозапуск. Идемпотентен — запускайте повторно после любой правки.

## Клавиши

`Alt` или `Win` + …

| Клавиши | Действие |
|:--|:--|
| `H J K L` | фокус окна |
| `Shift + H J K L` | переместить окно |
| `1..9` | рабочий стол |
| `Shift + 1..9` | окно на рабочий стол |
| `R` | режим ресайза (выход `Esc`) |
| `V` | направление укладки |
| `F` | полноэкранный режим |
| `Shift + Space` | плавающее окно |
| `Q` | закрыть |
| `Space` | лаунчер |
| `Enter` | WezTerm |
| `Shift + R` | перечитать конфиг |

`Alt + S` / `Alt + A` — следующий / предыдущий рабочий стол. `Alt + Shift + E` — выйти из GlazeWM.

## Файлы

| В репозитории | Куда ставится |
|:--|:--|
| `glazewm/config.yaml` | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| `yasb/` | `%USERPROFILE%\.config\yasb\` |
| `wezterm/.wezterm.lua` | `%USERPROFILE%\.wezterm.lua` |
| `starship/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `fastfetch/` | `%USERPROFILE%\.config\fastfetch\` |
| `wallpaper/tokyonight.png` | `%USERPROFILE%\Pictures\winRice-wallpaper.png` |

Палитра: фон `#1a1b26`, текст `#c0caf5`, акцент `#7aa2f7`, приглушённый `#565f89`.

## Заметки

- Бар скрывается в полноэкранных приложениях (`hide_on_fullscreen` в `yasb/config.yaml`).
- Часть сочетаний `Win` остаётся за Windows — используйте вариант с `Alt`.
- Штатные Пуск и панель задач не тронуты; лаунчер — `Alt+Space`.
- Логи: `~\.config\yasb\yasb.log`, `~\.glzr\glazewm\errors.log`.

## Благодарности

[GlazeWM](https://github.com/glzr-io/GlazeWM) · [YASB](https://github.com/amnweb/yasb) · [WezTerm](https://wezterm.org) · [Starship](https://starship.rs) · [Fastfetch](https://github.com/fastfetch-cli/fastfetch) · [JetBrains Mono NF](https://github.com/ryanoasis/nerd-fonts) · палитра [Tokyo Night](https://github.com/folke/tokyonight.nvim) · вдохновлено [Omarchy](https://github.com/basecamp/omarchy).

[MIT](LICENSE) © 2026 Erzkanzler2k
