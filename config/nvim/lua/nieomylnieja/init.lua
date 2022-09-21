-- vim:fdm=marker:fdl=0

-- Essentials {{{1

require("nieomylnieja.packer")

require("nieomylnieja.autocmd")
local remap = require("nieomylnieja.keymap")
local noremap = remap.noremap
local nnoremap = remap.nnoremap
local xnoremap = remap.xnoremap
local vnoremap = remap.vnoremap
local tnoremap = remap.tnoremap

-- Make sure space is not mapped to anything!
nnoremap("<space>", "<Nop>")
vim.g.mapleader = " "

-- General preferences {{{1

local opt = vim.opt

-- General
opt.lazyredraw = true -- Do not redraw screen in the middle of a macro. Makes them complete faster.
opt.clipboard = "unnamed,unnamedplus"
opt.scrolloff = 9999 -- Center the view
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.termguicolors = true -- Required by bufferline!

-- Tabbing
opt.tabstop = 2 -- The number of spaces a tab is
opt.shiftwidth = 2 -- Number of spaces to use in auto(indent)
opt.softtabstop = 2 -- Just to be clear
opt.expandtab = true -- Insert tabs as spaces
opt.smartindent = true -- Use smart indentation, works for C like langs.

-- Searching
opt.wrapscan = true -- Wrap searches
opt.ignorecase = true -- Ignore search term case...
opt.smartcase = true -- ... unless term contains an uppercase character

-- Wrapping
opt.textwidth = 80 -- Hard-wrap text at nth column
opt.wrap = false -- Don't wrap long lines (good for vsplits, bad otherwise?)

-- Folding
opt.foldmethod = "indent"
opt.foldlevel = 99

-- Mappings {{{1

local snmap = { noremap = true, silent = true }
local sexpr = { silent = true, expr = true }

-- Move between splits with CTRL+[hjkl]
nnoremap("<C-h>", "<C-w>h")
nnoremap("<C-j>", "<C-w>j")
nnoremap("<C-k>", "<C-w>k")
nnoremap("<C-l>", "<C-w>l")

-- Resize splits with CTRL+SHIFT+[hjkl]
nnoremap("<S-h>", ":vertical resize -1<CR>", snmap)
nnoremap("<S-j>", ":resize -1<CR>", snmap)
nnoremap("<S-k>", ":resize +1<CR>", snmap)
nnoremap("<S-l>", ":vertical resize +1<CR>", snmap)

-- System clipboard
vnoremap("y", '"+y')

-- Fold with tab
nnoremap("<tab>", "za")

-- Neat base64 decoding and encoding
noremap("<leader>d", [[c<c-r>=system('base64 --decode', @")<cr><esc>gv<left>]])
vnoremap("<leader>e", [[c<c-r>=system('base64', @")<cr><BS><esc>gv<left>]])

-- j/k will move virtual lines (lines that wrap)
noremap("j", "(v:count == 0 ? 'gj' : 'j')", sexpr)
noremap("k", "(v:count == 0 ? 'gk' : 'k')", sexpr)

-- Fugitive Conflict Resolution
nnoremap("<leader>gd", ":Gdiffsplit!<CR>")
nnoremap("gdh", ":diffget //2<CR>")
nnoremap("gdl", ":diffget //3<CR>")

-- Paste without loosing buffer
xnoremap("<leader>p", '"_dP')

-- Terminal mode
nnoremap("<leader>t", ":te<CR>")
tnoremap("<Esc>", "<C-\\><C-n>")

-- Formatting
nnoremap("<leader>fm", ":FormatWrite<CR>", snmap)

-- Symbols outline
nnoremap("<leader>so", ":SymbolsOutline<CR>", snmap)

-- Telescope mappings, should move these to telescope.lua

-- Functions {{{1

vim.api.nvim_create_user_command("ReloadMyConfigs", function()
	vim.cmd([[so $MYVIMRC]])
	vim.cmd([[:PackerCompile<CR>]])
  print("Confgis reloaded!")
end, {})
