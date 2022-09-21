local nnoremap = require("nieomylnieja.keymap").nnoremap
local opts = { noremap = true, silent = true }
-- These commands will navigate through buffers in order.
nnoremap("<C-n>", ":BufferLineCycleNext<CR>", opts)
nnoremap("<C-p>", ":BufferLineCyclePrev<CR>", opts)
-- These commands will move the current buffer backwards or forwards.
nnoremap("<S-n>", ":BufferLineMoveNext<CR>", opts)
nnoremap("<S-p>", ":BufferLineMovePrev<CR>", opts)

require("bufferline").setup({
	options = {
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
			},
		},
		color_icons = true,
	},
})
