local nnoremap = require("nieomylnieja.keymap").nnoremap
local opts = { silent = true }
-- These commands will navigate through buffers in order.
nnoremap("<C-n>", ":BufferLineCycleNext<CR>", opts)
nnoremap("<C-p>", ":BufferLineCyclePrev<CR>", opts)
-- These commands will move the current buffer backwards or forwards.
nnoremap("<S-n>", ":BufferLineMoveNext<CR>", opts)
nnoremap("<S-p>", ":BufferLineMovePrev<CR>", opts)

-- Support nord theme.
local colors = require("nord.named_colors")
local fill = colors.black --'#181c24' if separator_style is "slant"
local indicator = colors.glacier
local bg = colors.black
local buffer_bg = colors.black
local buffer_bg_selected = colors.dark_gray
local buffer_bg_visible = colors.black

require("bufferline").setup({
	options = {
		show_close_icon = false,
		diagnostics = "nvim_lsp",
		diagnostics_indicator = function(_, level)
			local icon = level:match("error") and " " or ""
			return icon
		end,
		offsets = {
			{
				filetype = "neo-tree",
				text = "File Explorer",
				text_align = "center",
				separator = true,
			},
			{
				filetype = "DiffviewFiles",
				text = "Diff View",
				highlight = "PanelHeading",
				padding = 1,
			},
			{
				filetype = "packer",
				text = "Packer",
				highlight = "PanelHeading",
				padding = 1,
			},
		},
		color_icons = true,
	},
	highlights = {
		fill = {
			bg = fill,
		},
		background = {
			bg = bg,
		},
		buffer_selected = {
			bg = buffer_bg_selected,
		},
		buffer_visible = {
			bg = buffer_bg_visible,
			italic = true,
		},
		numbers = {
			bg = buffer_bg,
		},
		numbers_selected = {
			bg = buffer_bg_selected,
		},
		numbers_visible = {
			bg = buffer_bg_visible,
			italic = true,
		},
		diagnostic = {
			bg = buffer_bg,
		},
		diagnostic_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		diagnostic_visible = {
			bg = buffer_bg_visible,
		},
		hint = {
			bg = buffer_bg,
		},
		hint_visible = {
			bg = buffer_bg_visible,
		},
		hint_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		hint_diagnostic = {
			bg = buffer_bg,
		},
		hint_diagnostic_visible = {
			bg = buffer_bg_visible,
		},
		hint_diagnostic_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		info = {
			bg = buffer_bg,
		},
		info_visible = {
			bg = buffer_bg_visible,
		},
		info_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		info_diagnostic = {
			bg = buffer_bg,
		},
		info_diagnostic_visible = {
			bg = buffer_bg_visible,
		},
		info_diagnostic_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		warning = {
			bg = buffer_bg,
		},
		warning_visible = {
			bg = buffer_bg_visible,
		},
		warning_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		warning_diagnostic = {
			bg = buffer_bg,
		},
		warning_diagnostic_visible = {
			bg = buffer_bg_visible,
		},
		warning_diagnostic_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		error = {
			bg = buffer_bg,
		},
		error_visible = {
			bg = buffer_bg_visible,
		},
		error_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		error_diagnostic = {
			bg = buffer_bg,
		},
		error_diagnostic_visible = {
			bg = buffer_bg_visible,
		},
		error_diagnostic_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		close_button = {
			bg = buffer_bg,
		},
		close_button_visible = {
			bg = buffer_bg_visible,
		},
		close_button_selected = {
			bg = buffer_bg_selected,
		},
		duplicate = {
			bg = buffer_bg,
		},
		duplicate_selected = {
			bg = buffer_bg_selected,
		},
		duplicate_visible = {
			bg = buffer_bg_visible,
		},
		separator = {
			fg = fill,
			bg = buffer_bg,
		},
		separator_selected = {
			fg = fill,
			bg = buffer_bg_selected,
		},
		separator_visible = {
			fg = fill,
			bg = buffer_bg_visible,
		},
		modified = {
			bg = buffer_bg,
		},
		modified_selected = {
			bg = buffer_bg_selected,
		},
		modified_visible = {
			bg = buffer_bg_visible,
		},
		indicator_selected = {
			fg = indicator,
			bg = buffer_bg_selected,
		},
		pick = {
			bg = buffer_bg,
			bold = true,
			italic = true,
		},
		pick_selected = {
			bg = buffer_bg_selected,
			bold = true,
			italic = true,
		},
		pick_visible = {
			bg = buffer_bg_visible,
			bold = true,
			italic = true,
		},
		offset_separator = {
			fg = colors.gray,
			bg = buffer_bg,
		},
	},
})
