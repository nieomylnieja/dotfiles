-- General
lvim.log.level = "warn"
lvim.format_on_save.enabled = false
lvim.colorscheme = "nord"
-- Options
require("nieomylnieja.opt")

-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false
lvim.builtin.treesitter.ensure_installed = "all"
lvim.builtin.treesitter.highlight.enable = true

-- Plugins
require("nieomylnieja.plugins")
-- LSP settings
require("nieomylnieja.lsp")
-- Null-ls
require("nieomylnieja.null-ls").setup()
-- Autocommands (https://neovim.io/doc/user/autocmd.html)
require("nieomylnieja.autocmd")
-- Color scheme
require("nieomylnieja.colors").setup()
-- Keys
require("nieomylnieja.keymap")
