-- Tokyo Night. Config for WezTerm.
local wezterm = require 'wezterm'

return {
  colors = {
    background = '#1a1b26',
    foreground = '#c0caf5',
    cursor_bg = '#c0caf5',
    cursor_fg = '#1a1b26',
    selection_bg = '#33467c',
    selection_fg = '#c0caf5',
    ansi = {
      '#15161e', '#f7768e', '#9ece6a', '#e0af68',
      '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6',
    },
    brights = {
      '#414868', '#f7768e', '#9ece6a', '#e0af68',
      '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5',
    },
  },

  font = wezterm.font_with_fallback {
    'JetBrainsMono Nerd Font',
    'Segoe UI',
  },
  font_size = 11.0,

  -- Omarchy-ish gaps and transparency.
  window_padding = { left = 10, right = 10, top = 10, bottom = 10 },
  window_background_opacity = 0.82,
  win32_system_backdrop = 'Acrylic',
  window_decorations = 'NONE',

  hide_tab_bar_if_only_one_tab = true,
  use_fancy_tab_bar = false,
  tab_max_width = 24,
  window_close_confirmation = 'NeverPrompt',

  inactive_pane_hsb = { saturation = 0.7, brightness = 0.85 },
  adjust_window_size_when_changing_font_size = false,
  initial_cols = 110,
  initial_rows = 30,
  default_prog = { 'powershell.exe', '-NoLogo' },

  keys = {
    { key = 'd', mods = 'CTRL|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'e', mods = 'CTRL|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
  },
}
