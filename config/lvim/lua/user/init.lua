-- General
lvim.log.level = "warn"
lvim.format_on_save.enabled = false
lvim.colorscheme = "nord"
-- Options
require("user.opt")
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
-- Ensure Mason sources are installed
require("user.mason").setup()
-- DAP
require("user.dap").setup()
