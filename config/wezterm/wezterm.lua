local wezterm = require 'wezterm'
local act = wezterm.action

wezterm.add_to_config_reload_watch_list(wezterm.home_dir .. '/.dotfiles/config/wezterm/wezterm.lua')

local config = wezterm.config_builder()

config.automatically_reload_config = true

config.font = wezterm.font {
  family = 'mononoki Nerd Font',
  weight = 'Regular',
}
config.font_size = 12
config.line_height = 1.2

config.colors = {
  foreground = '#D8DEE9',
  background = '#2E3440',
  cursor_bg = '#D8DEE9',
  cursor_fg = '#2E3440',
  cursor_border = '#D8DEE9',
  ansi = {
    '#3B4252',
    '#BF616A',
    '#A3BE8C',
    '#EBCB8B',
    '#81A1C1',
    '#B48EAD',
    '#88C0D0',
    '#E5E9F0',
  },
  brights = {
    '#4C566A',
    '#BF616A',
    '#A3BE8C',
    '#EBCB8B',
    '#81A1C1',
    '#B48EAD',
    '#8FBCBB',
    '#ECEFF4',
  },
}

config.scrollback_lines = 20000
config.alternate_buffer_wheel_scroll_speed = 6

config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[[/~A-Za-z0-9_.@%+=,-]+/[/~A-Za-z0-9_.@%+=,-]+:\d+]],
  format = 'https://wezterm-file-link/$0',
})

config.window_decorations = 'TITLE | RESIZE'
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.use_resize_increments = false

config.keys = {
  { key = 'L', mods = 'CTRL', action = act.SendString '\x0c' },
  { key = 'PageUp', mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },
  { key = 'Home', mods = 'SHIFT', action = act.ScrollToTop },
  { key = 'End', mods = 'SHIFT', action = act.ScrollToBottom },
  { key = 'Space', mods = 'CTRL', action = act.ActivateCopyMode },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.Nop,
  },
}

local copy_mode = nil
if wezterm.gui then
  copy_mode = wezterm.gui.default_key_tables().copy_mode
  table.insert(copy_mode, {
    key = 'Space',
    mods = 'CTRL',
    action = act.CopyMode 'MoveToScrollbackBottom',
  })
end

config.key_tables = {
  copy_mode = copy_mode,
}

local function current_working_directory(pane)
  local cwd = pane:get_current_working_dir()
  if cwd == nil then
    return nil
  end

  if type(cwd) == 'userdata' or type(cwd) == 'table' then
    return cwd.file_path
  end

  local parsed = wezterm.url.parse(tostring(cwd))
  if parsed.scheme == 'file' then
    return parsed.file_path
  end

  return nil
end

local function resolve_path(pane, path)
  if path:sub(1, 2) == '~/' then
    return wezterm.home_dir .. path:sub(2)
  end

  if path:sub(1, 1) == '/' then
    return path
  end

  local cwd = current_working_directory(pane)
  if cwd ~= nil then
    return cwd .. '/' .. path
  end

  return path
end

wezterm.on('open-uri', function(window, pane, uri)
  local path, line = uri:match '^https://wezterm%-file%-link/(.-):(%d+)$'
  if path == nil then
    return
  end

  window:perform_action(
    act.SpawnCommandInNewWindow {
      args = { 'nvim', '+' .. line, resolve_path(pane, path) },
    },
    pane
  )

  return false
end)

return config
