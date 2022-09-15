-- vim:fdm=marker:fdl=0
vim.g.mapleader = " "

local function rc(conf)
  return require('nieomylnieja.' .. conf)
end

-- Essentials {{{1

rc("autocmd")
local remap = rc("keymap")
local noremap = remap.noremap
local nnoremap = remap.nnoremap
local xnoremap = remap.xnoremap
local vnoremap = remap.vnoremap

-- Plugins configuration {{{1

rc('nord')
rc('neo-tree')
rc('lualine')
rc('treesitter')
rc('lsp-config')
rc('metals')
rc('telescope')
rc('go')
rc('web-devicons')
rc('nvim-dap-ui')
rc('markdown-preview')

-- Runtime for FZF
vim.opt.runtimepath:append("/usr/local/bin/fzf")

-- General preferences {{{1

-- Center the view
vim.opt.scrolloff = 9999

-- Tabbing
vim.opt.tabstop = 2           -- The number of spaces a tab is
vim.opt.shiftwidth = 2        -- Number of spaces to use in auto(indent)
vim.opt.softtabstop = 2       -- Just to be clear
vim.opt.expandtab = true      -- Insert tabs as spaces
vim.opt.smartindent = true    -- Use smart indentation, works for C like langs.

-- Searching
vim.opt.wrapscan = true       -- Wrap searches
vim.opt.ignorecase = true     -- Ignore search term case...
vim.opt.smartcase = true      -- ... unless term contains an uppercase character

-- Wrapping
vim.opt.textwidth = 80        -- Hard-wrap text at nth column
vim.opt.wrap = true           -- Wrap long lines (bad for vsplits)

-- Folding
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99

-- General
vim.opt.lazyredraw = true     -- Do not redraw screen in the middle of a macro. Makes them complete faster.
vim.opt.clipboard = "unnamed,unnamedplus"

-- Mappings {{{1

-- Move between splits with CTRL+[hjkl]
nnoremap("<C-h>", "<C-w>h")
nnoremap("<C-h><C-j>", "<C-w>j")
nnoremap("<C-h><C-k>", "<C-w>k")
nnoremap("<C-h><C-l>", "<C-w>l")

-- Resize splits with CTRL+SHIFT+[hjkl]
nnoremap("<S-h>", ":vertical resize +1<CR>", { noremap = true, silent = true })
nnoremap("<S-j>", ":resize -1<CR>", { noremap = true, silent = true })
nnoremap("<S-k>", ":resize +1<CR>", { noremap = true, silent = true })
nnoremap("<S-l>", ":vertical resize -1<CR>", { noremap = true, silent = true })

-- Disable those filthy arrows
noremap("<Up>", "<Nop>")
noremap("<Down>", "<Nop>")
noremap("<Right>", "<Nop>")
noremap("<Left>", "<Nop>")

-- System clipboard
vnoremap("y", '"+y')

-- Fold with space
nnoremap("<space>", "za")

-- Neat base64 decoding and encoding
noremap("<leader>d", "c<c-r>=system('base64 --decode', @\")<cr><esc>gv<left>")
vnoremap("<leader>e", "c<c-r>=system('base64', @\")<cr><BS><esc>gv<left>")

-- j/k will move virtual lines (lines that wrap)
noremap("j", "(v:count == 0 ? 'gj' : 'j')", { silent = true, expr = true })
noremap("k", "(v:count == 0 ? 'gk' : 'k')", { silent = true, expr = true })

-- Fugitive Conflict Resolution
nnoremap("<leader>gd", ":Gdiffsplit!<CR>")
nnoremap("gdh", ":diffget //2<CR>")
nnoremap("gdl", ":diffget //3<CR>")

-- Paste without loosing buffer
xnoremap("<leader>p", "\"_dP")

-- Telescope mappings, should move these to telescope.lua

-- Functions {{{1

vim.api.nvim_create_user_command(
  "ReloadVimConfigs",
  "so $MYVIMRC | echo 'configs reloaded!'",
  {}
)
