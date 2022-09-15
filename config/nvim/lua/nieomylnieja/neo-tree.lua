-- Remove the deprecated commands from v1.x
vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

-- Neo Tree requires these packages to work:
-- * "https://github.com/nvim-lua/plenary.nvim" - most of the plugins do...
-- * "https://github.com/kyazdani42/nvim-web-devicons" - not strictly required, but recommended
-- * "https://github.com/MunifTanjim/nui.nvim"

tree = require('neo-tree')

-- The defaults are at: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/684894e7e6038c2e8d8595139ac24d14b267c75d/lua/neo-tree/defaults.lua
local config = {
  source_selector = {
    statusline = true
  }
}

tree.setup(config)

