local nord = {
  black = "#2E3440",
  dark_gray = "#3B4252",
  gray = "#434C5E",
  light_gray = "#4C566A",
  light_gray_bright = "#616E88",
  darkest_white = "#D8DEE9",
  darker_white = "#E5E9F0",
  white = "#ECEFF4",
  teal = "#8FBCBB",
  off_blue = "#88C0D0",
  glacier = "#81A1C1",
  blue = "#5E81AC",
  red = "#BF616A",
  orange = "#D08770",
  yellow = "#EBCB8B",
  green = "#A3BE8C",
  purple = "#B48EAD",
  none = "NONE",
}

-- Enable contrast sidebars, floating windows and popup menus
if vim.g.nord_contrast then
  nord.sidebar = nord.dark_gray
  nord.float = nord.dark_gray
else
  nord.sidebar = nord.black
  nord.float = nord.black
end

if vim.g.nord_cursorline_transparent then
  nord.cursorlinefg = nord.black
else
  nord.cursorlinefg = nord.dark_gray
end

return nord
