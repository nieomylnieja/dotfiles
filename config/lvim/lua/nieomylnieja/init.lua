--[[
lvim is the global options object

Linters should be
filled in as strings with either
a global executable or a path to
an executable
]]
-- THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT

-- general
lvim.log.level = "warn"
lvim.format_on_save.enabled = false
lvim.colorscheme = "nord"
-- options
require("nieomylnieja.opt")

-- TODO: User Config for predefined plugins
-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false

-- If you don't want all the parsers change this to a table of the ones you want
lvim.builtin.treesitter.ensure_installed = "all"
lvim.builtin.treesitter.highlight.enable = true

-- LSP settings
require("nieomylnieja.lsp")

-- Null-ls
require("nieomylnieja.null-ls").setup()

-- Additional Plugins
lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "karb94/neoscroll.nvim",
    config = function()
      require('neoscroll').setup()
    end
  },
  { "nvim-treesitter/playground" },
  { "jay-babu/mason-null-ls.nvim" },
  { "jay-babu/mason-nvim-dap.nvim" },
}

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
require("nieomylnieja.autocmd")

-- Color scheme
require("nieomylnieja.colors").setup()

-- Keys
require("nieomylnieja.keymap")
