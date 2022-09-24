-- Make sidebars and popup menus like nvim-tree and telescope have a different background
vim.g.nord_contrast = true
-- Enable the border between verticaly split windows visable
vim.g.nord_borders = true
-- Disable the setting of background color so that NeoVim can use your terminal background
vim.g.nord_disable_background = false
-- Set the cursorline transparent/visible
vim.g.nord_cursorline_transparent = false
-- Re-enables the background of the sidebar if you disabled the background of everything
vim.g.nord_enable_sidebar_background = false
-- Enables/disables italics
vim.g.nord_italic = true
-- Enables/disables colorful backgrounds when used in diff mode
vim.g.nord_uniform_diff_background = true

require("nord").set()

local util = require("nord.util")
local colors = require("nord.named_colors")

util.loadColorSet({
	NeoTreeTabInactive = { fg = colors.light_gray , bg = colors.dark_gray },
	NeoTreeTabActive = { fg = colors.teal , bg = colors.gray  },
})
