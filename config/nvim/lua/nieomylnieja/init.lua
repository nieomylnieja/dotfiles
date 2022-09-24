-- vim:fdm=marker:fdl=0
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
opt.hidden = true -- Otherwise terminals managed by toggleterm are discarded.
opt.splitbelow = true
opt.splitright = true

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

local remap = require("nieomylnieja.keymap")

local noremap = remap.noremap
local nnoremap = remap.nnoremap
local xnoremap = remap.xnoremap
local vnoremap = remap.vnoremap
local tnoremap = remap.tnoremap

local silent = { silent = true }
local silent_expr = { silent = true, expr = true }

-- Make sure space is not mapped to anything!
nnoremap("<space>", "<Nop>")

-- Move between splits with CTRL+[hjkl]
nnoremap("<C-h>", "<C-w>h")
nnoremap("<C-j>", "<C-w>j")
nnoremap("<C-k>", "<C-w>k")
nnoremap("<C-l>", "<C-w>l")

-- Resize splits with CTRL+SHIFT+[hjkl]
nnoremap("<S-h>", ":vertical resize -1<CR>", silent)
nnoremap("<S-j>", ":resize -1<CR>", silent)
nnoremap("<S-k>", ":resize +1<CR>", silent)
nnoremap("<S-l>", ":vertical resize +1<CR>", silent)

-- System clipboard
vnoremap("y", '"+y')
-- Fold
nnoremap("<tab>", "za")
-- j/k will move virtual lines (lines that wrap)
noremap("j", "(v:count == 0 ? 'gj' : 'j')", silent_expr)
noremap("k", "(v:count == 0 ? 'gk' : 'k')", silent_expr)

-- Fugitive Conflict Resolution
nnoremap("<leader>gd", ":Gdiffsplit!<CR>")
nnoremap("gdh", ":diffget //2<CR>")
nnoremap("gdl", ":diffget //3<CR>")

-- Paste without loosing buffer
xnoremap("<leader>p", '"_dP')

-- Others
tnoremap("<Esc>", "<C-\\><C-n>")
nnoremap("<leader>fm", ":FormatWrite<CR>", silent)
nnoremap("<leader>so", ":SymbolsOutline<CR>", silent)
noremap("<leader>d", [[c<c-r>=system('base64 --decode', @")<cr><esc>gv<left>]])
vnoremap("<leader>e", [[c<c-r>=system('base64', @")<cr><BS><esc>gv<left>]])
nnoremap("<C-g>", ":Neogit<CR>", silent)
nnoremap("<leader>n", ":Neotree<cr>", silent)

require("keys")

-- Telescope mappings, should move these to telescope.lua

-- Functions {{{1

vim.api.nvim_create_user_command("ReloadMyConfigs", function()
	vim.cmd([[so $MYVIMRC]])
	vim.cmd([[:PackerCompile<CR>]])
	print("Confgis reloaded!")
end, {})

-- Plugins {{{1

local function req(name)
	require("nieomylnieja." .. name)
end

-- My own
req("autocmd")

-- Managers
req("packer")
req("mason")
-- Looks
req("nord")
req("web-devicons")
req("lualine")
req("bufferline")
req("neotree")
-- Code
req("debugger")
req("lsp")
req("format")
req("treesitter")
req("treesitter-context")
req("gitsigns")
req("which-key")
-- Other
req("markdown-preview")
req("telescope")
req("term")
req("neogit")
require("octo").setup() -- The defaults are fine, but it needs to load after telescope.
