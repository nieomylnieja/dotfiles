-- General
lvim.log.level = "warn"
lvim.format_on_save.enabled = false
lvim.colorscheme = "nord"
-- Options
require("user.opt")

-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false
lvim.builtin.treesitter.ensure_installed = "all"
lvim.builtin.treesitter.highlight.enable = true

-- Plugins
require("user.plugins")
-- LSP settings
require("user.lsp")
-- Null-ls
require("user.null-ls").setup()
-- Autocommands (https://neovim.io/doc/user/autocmd.html)
require("user.autocmd")
-- Color scheme
require("user.colors").setup()
-- Keys
require("user.keymap")
