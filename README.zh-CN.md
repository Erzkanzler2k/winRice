<div align="center">

# winRice

**为键盘而生的平铺式 Windows 11，配以 Tokyo Night 配色。**

![Windows 11](https://img.shields.io/badge/Windows-11-7aa2f7?style=flat-square&logo=windows11&logoColor=white)
![MIT](https://img.shields.io/badge/license-MIT-c0caf5?style=flat-square)

<img src="docs/bar.png" alt="winRice 状态栏" width="100%">

[English](README.md) · [Русский](README.ru.md) · **简体中文** · [Español](README.es.md) · [Português (BR)](README.pt-BR.md)

</div>

## 安装

```powershell
git clone https://github.com/Erzkanzler2k/winRice
cd winRice
powershell -ExecutionPolicy Bypass -File install.ps1
```

需要 Windows 11 22H2+ 和 `winget`。脚本会安装 GlazeWM、YASB、WezTerm、Starship 和 Fastfetch，复制配置文件，设置壁纸，隐藏桌面图标并注册开机自启。脚本是幂等的——修改后重新运行即可。

## 快捷键

`Alt` 或 `Win` + …

| 按键 | 操作 |
|:--|:--|
| `H J K L` | 切换窗口焦点 |
| `Shift + H J K L` | 移动窗口 |
| `1..9` | 切换工作区 |
| `Shift + 1..9` | 把窗口移到工作区 |
| `R` | 调整大小模式（`Esc` 退出） |
| `V` | 切换平铺方向 |
| `F` | 全屏 |
| `Shift + Space` | 浮动窗口 |
| `Q` | 关闭窗口 |
| `Space` | 启动器 |
| `Enter` | WezTerm |
| `Shift + R` | 重新加载配置 |

`Alt + S` / `Alt + A` —— 下一个 / 上一个工作区。`Alt + Shift + E` —— 退出 GlazeWM。

## 文件

| 仓库内路径 | 安装到 |
|:--|:--|
| `glazewm/config.yaml` | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| `yasb/` | `%USERPROFILE%\.config\yasb\` |
| `wezterm/.wezterm.lua` | `%USERPROFILE%\.wezterm.lua` |
| `starship/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `fastfetch/` | `%USERPROFILE%\.config\fastfetch\` |
| `wallpaper/tokyonight.png` | `%USERPROFILE%\Pictures\winRice-wallpaper.png` |

配色：背景 `#1a1b26`，文字 `#c0caf5`，强调色 `#7aa2f7`，次要色 `#565f89`。

## 说明

- 全屏应用下状态栏会自动隐藏（`yasb/config.yaml` 里的 `hide_on_fullscreen`）。
- 部分 `Win` 组合键仍由 Windows 占用，请使用 `Alt` 版本。
- 系统自带的开始菜单和任务栏保持不变；启动器是 `Alt+Space`。
- 日志：`~\.config\yasb\yasb.log`、`~\.glzr\glazewm\errors.log`。

## 致谢

[GlazeWM](https://github.com/glzr-io/GlazeWM) · [YASB](https://github.com/amnweb/yasb) · [WezTerm](https://wezterm.org) · [Starship](https://starship.rs) · [Fastfetch](https://github.com/fastfetch-cli/fastfetch) · [JetBrains Mono NF](https://github.com/ryanoasis/nerd-fonts) · 配色 [Tokyo Night](https://github.com/folke/tokyonight.nvim) · 灵感来自 [Omarchy](https://github.com/basecamp/omarchy)。

[MIT](LICENSE) © 2026 Erzkanzler2k
