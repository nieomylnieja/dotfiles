local keymap = require("nieomylnieja.keymap")

vim.api.nvim_create_autocmd("TermEnter", {
	pattern = "term://*toggleterm#*",
	command = 'tnoremap <silent><c-t> <Cmd>exe v:count1 . "ToggleTerm"<CR>',
})

local opts = { silent = true, noremap = true }
keymap.nnoremap("<c-t>", '<Cmd>exe v:count1 . "ToggleTerm"<CR>', opts)
keymap.inoremap("<c-t>", '<Esc><Cmd>exe v:count1 . "ToggleTerm"<CR>', opts)

require("toggleterm").setup({
	-- size can be a number or function which is passed the current terminal
	size = function(term)
		if term.direction == "horizontal" then
			return 15
		elseif term.direction == "vertical" then
			return vim.o.columns * 0.4
		end
	end,
	open_mapping = [[<c-\>]],
	hide_numbers = true, -- hide the number column in toggleterm buffers
	autochdir = false, -- when neovim changes it current directory the terminal will change it's own when next it's opened
	-- highlights = {
	-- 	-- highlights which map to a highlight group name and a table of it's values
	-- 	-- NOTE: this is only a subset of values, any group placed here will be set for the terminal window split
	-- 	Normal = {
	-- 		guibg = "<VALUE-HERE>",
	-- 	},
	-- 	NormalFloat = {
	-- 		link = "Normal",
	-- 	},
	-- 	FloatBorder = {
	-- 		guifg = "<VALUE-HERE>",
	-- 		guibg = "<VALUE-HERE>",
	-- 	},
	-- },
	shade_terminals = true, -- NOTE: this option takes priority over highlights specified so if you specify Normal highlights you should set this to false
	shading_factor = 1, -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
	start_in_insert = true,
	insert_mappings = true, -- whether or not the open mapping applies in insert mode
	terminal_mappings = true, -- whether or not the open mapping applies in the opened terminals
	persist_size = true,
	persist_mode = true, -- if set to true (default) the previous terminal mode will be remembered
	direction = "horizontal",
	close_on_exit = true, -- close the terminal window when the process exits
	shell = vim.o.shell, -- change the default shell
	auto_scroll = true, -- automatically scroll to the bottom on terminal output
})
