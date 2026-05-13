local wezterm = require 'wezterm'
local act = wezterm.action

wezterm.add_to_config_reload_watch_list(wezterm.home_dir .. '/.dotfiles/config/wezterm/wezterm.lua')

local config = wezterm.config_builder()

config.automatically_reload_config = true

local nord = {
  nord0 = '#2E3440',
  nord1 = '#3B4252',
  nord2 = '#434C5E',
  nord3 = '#4C566A',
  nord4 = '#D8DEE9',
  nord5 = '#E5E9F0',
  nord6 = '#ECEFF4',
  nord7 = '#8FBCBB',
  nord8 = '#88C0D0',
  nord9 = '#81A1C1',
  nord10 = '#5E81AC',
  nord11 = '#BF616A',
  nord12 = '#D08770',
  nord13 = '#EBCB8B',
  nord14 = '#A3BE8C',
  nord15 = '#B48EAD',
}

config.font = wezterm.font {
  family = 'mononoki Nerd Font',
  weight = 'Regular',
}
config.font_size = 12
config.line_height = 1.2

config.colors = {
  foreground = nord.nord4,
  background = nord.nord0,
  cursor_bg = nord.nord4,
  cursor_fg = nord.nord0,
  cursor_border = nord.nord4,
  ansi = {
    nord.nord1,
    nord.nord11,
    nord.nord14,
    nord.nord13,
    nord.nord9,
    nord.nord15,
    nord.nord8,
    nord.nord5,
  },
  brights = {
    nord.nord3,
    nord.nord11,
    nord.nord14,
    nord.nord13,
    nord.nord9,
    nord.nord15,
    nord.nord7,
    nord.nord6,
  },
  tab_bar = {
    background = nord.nord0,
    active_tab = {
      bg_color = nord.nord3,
      fg_color = nord.nord6,
    },
    inactive_tab = {
      bg_color = nord.nord1,
      fg_color = nord.nord4,
    },
    inactive_tab_hover = {
      bg_color = nord.nord2,
      fg_color = nord.nord6,
    },
    new_tab = {
      bg_color = nord.nord0,
      fg_color = nord.nord4,
    },
    new_tab_hover = {
      bg_color = nord.nord2,
      fg_color = nord.nord6,
    },
    inactive_tab_edge = nord.nord0,
  },
}

config.scrollback_lines = 20000
config.alternate_buffer_wheel_scroll_speed = 6

config.hyperlink_rules = {
  {
    regex = [[\((\w+://[^\s)]+)\)]],
    format = '$1',
    highlight = 1,
  },
  {
    regex = [=[\[(\w+://[^\s\]]+)\]]=],
    format = '$1',
    highlight = 1,
  },
  {
    regex = [[\{(\w+://[^\s}]+)\}]],
    format = '$1',
    highlight = 1,
  },
  {
    regex = [[<(\w+://[^\s>]+)>]],
    format = '$1',
    highlight = 1,
  },
  {
    regex = [=[\b\w+://[^\s<>()\[\]{}"'`]*[^\s<>()\[\]{}"'`,.;:!?]]=],
    format = '$0',
  },
  {
    regex = [[\b\w+@[\w-]+(\.[\w-]+)+\b]],
    format = 'mailto:$0',
  },
  {
    regex = [[[/~A-Za-z0-9_.@%+=,-]+/[/~A-Za-z0-9_.@%+=,-]+(?::\d+)?]],
    format = 'https://wezterm-file-link/$0',
  },
}

config.window_decorations = 'TITLE | RESIZE'
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_frame = {
  active_titlebar_bg = nord.nord0,
  inactive_titlebar_bg = nord.nord0,
  active_titlebar_fg = nord.nord6,
  inactive_titlebar_fg = nord.nord4,
  active_titlebar_border_bottom = nord.nord0,
  inactive_titlebar_border_bottom = nord.nord0,
  button_bg = nord.nord0,
  button_fg = nord.nord4,
  button_hover_bg = nord.nord2,
  button_hover_fg = nord.nord6,
}
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.use_resize_increments = false

config.keys = {
  { key = 'L', mods = 'CTRL', action = act.SendString '\x0c' },
  { key = 'O', mods = 'CTRL|SHIFT', action = act.EmitEvent 'open-selected-file-reference' },
  { key = 'PageUp', mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },
  { key = 'Home', mods = 'SHIFT', action = act.ScrollToTop },
  { key = 'End', mods = 'SHIFT', action = act.ScrollToBottom },
  { key = 'Space', mods = 'CTRL', action = act.ActivateCopyMode },
}

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.SelectTextAtMouseCursor 'Cell',
  },
  {
    event = { Drag = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.ExtendSelectionToMouseCursor 'Cell',
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor 'ClipboardAndPrimarySelection',
  },
  {
    event = { Down = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.SelectTextAtMouseCursor 'Word',
  },
  {
    event = { Drag = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.ExtendSelectionToMouseCursor 'Word',
  },
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Down = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.SelectTextAtMouseCursor 'Line',
  },
  {
    event = { Drag = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.ExtendSelectionToMouseCursor 'Line',
  },
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Down = { streak = 1, button = 'Middle' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.PasteFrom 'PrimarySelection',
  },
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    mouse_reporting = true,
    action = act.PasteFrom 'Clipboard',
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local selection = window:get_selection_text_for_pane(pane)
      if selection ~= nil and selection ~= '' then
        window:perform_action(act.EmitEvent 'open-selected-file-reference', pane)
        return
      end

      window:perform_action(act.OpenLinkAtMouseCursor, pane)
    end),
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

local function file_exists(path)
  local file = io.open(path, 'r')
  if file == nil then
    return false
  end

  file:close()
  return true
end

local function trim_trailing_path_punctuation(path)
  return path:gsub('[,.;:!?%)%]%}]+$', '')
end

local function extract_file_reference(text)
  if text == nil or text == '' then
    return nil
  end

  local path_pattern = '([/~%w_.@%%+=,-]+/[~%w_.@%%+=,-][/~%w_.@%%+=,-]*)'
  local path, line = text:match(path_pattern .. ':(%d+)')
  if path ~= nil then
    return path, line
  end

  local squashed = text:gsub('%s+', '')
  path, line = squashed:match(path_pattern .. ':(%d+)')
  if path ~= nil then
    return path, line
  end

  path = squashed:match(path_pattern)
  if path ~= nil then
    return path, '1'
  end

  path = text:match(path_pattern)
  if path ~= nil then
    return path, '1'
  end

  return nil
end

local function open_file_reference(window, pane, path, line, target)
  if path == nil then
    return false
  end

  local resolved_path = resolve_path(pane, path)
  if not file_exists(resolved_path) then
    local trimmed_path = trim_trailing_path_punctuation(path)
    if trimmed_path ~= path then
      local trimmed_resolved_path = resolve_path(pane, trimmed_path)
      if file_exists(trimmed_resolved_path) then
        path = trimmed_path
        resolved_path = trimmed_resolved_path
      end
    end
  end

  if not file_exists(resolved_path) then
    wezterm.log_warn('File link does not exist: ' .. resolved_path)
    return false
  end

  local spawn_action = act.SpawnCommandInNewTab
  if target == 'window' then
    spawn_action = act.SpawnCommandInNewWindow
  elseif target == nil then
    local mods = window:keyboard_modifiers()
    if mods:find 'CTRL' then
      spawn_action = act.SpawnCommandInNewWindow
    end
  end

  window:perform_action(
    spawn_action {
      args = { 'nvim', '+' .. line, resolved_path },
    },
    pane
  )

  return false
end

wezterm.on('open-selected-file-reference', function(window, pane)
  local selection = window:get_selection_text_for_pane(pane)
  local path, line = extract_file_reference(selection)
  if path == nil then
    return
  end

  window:perform_action(act.ClearSelection, pane)
  return open_file_reference(window, pane, path, line, 'tab')
end)

wezterm.on('open-uri', function(window, pane, uri)
  local path, line = uri:match '^https://wezterm%-file%-link/(.-):(%d+)$'
  if path == nil then
    path = uri:match '^https://wezterm%-file%-link/(.+)$'
    line = '1'
  end

  if path == nil then
    return
  end

  return open_file_reference(window, pane, path, line)
end)

return config
