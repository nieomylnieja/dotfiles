-- Remove the deprecated commands from v1.x
vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

-- Toggle Neotree
require("nieomylnieja.keymap").nnoremap("<C-n>", ":Neotree<cr>")

-- Neo Tree requires these packages to work:
-- * "https://github.com/nvim-lua/plenary.nvim" - most of the plugins do...
-- * "https://github.com/kyazdani42/nvim-web-devicons" - not strictly required, but recommended
-- * "https://github.com/MunifTanjim/nui.nvim"

local tree = require("neo-tree")

-- The defaults are at: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/defaults.lua
local config = {
	log_level = "warn",
	source_selector = {
		statusline = true,
	},
	window = {
		position = "right",
		width = 30,
	},
}

tree.setup(config)
