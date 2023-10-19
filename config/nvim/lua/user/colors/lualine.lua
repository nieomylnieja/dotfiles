local theme = {}

local colors = require "user.colors.nord"

theme.normal = {
  a = { fg = colors.dark_gray, bg = colors.glacier },
  b = { fg = colors.darker_white, bg = colors.gray },
  c = { fg = colors.darkest_white, bg = colors.dark_gray },
}

theme.insert = {
  a = { fg = colors.dark_gray, bg = colors.darkest_white },
  b = { fg = colors.white, bg = colors.gray },
  y = { fg = colors.darker_white, bg = colors.gray },
}

theme.visual = {
  a = { fg = colors.black, bg = colors.teal },
  b = { fg = colors.darkest_white, bg = colors.gray },
  y = { fg = colors.darker_white, bg = colors.gray },
}

theme.replace = {
  a = { fg = colors.black, bg = colors.red },
  b = { fg = colors.darkest_white, bg = colors.gray },
  y = { fg = colors.darker_white, bg = colors.gray },
}

theme.command = {
  a = { fg = colors.black, bg = colors.purple, gui = "bold" },
  b = { fg = colors.darkest_white, bg = colors.gray },
  y = { fg = colors.darker_white, bg = colors.gray },
}

theme.inactive = {
  a = { fg = colors.darkest_white, bg = colors.black, gui = "bold" },
  b = { fg = colors.darkest_white, bg = colors.black },
  c = { fg = colors.darkest_white, bg = colors.dark_gray },
}

return theme
