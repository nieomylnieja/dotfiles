-- vim:fdm=marker:fdl=0

-- Essentials {{{1

local function rc(conf)
	return require("nieomylnieja." .. conf)
end

rc("autocmd")
local remap = rc("keymap")
local noremap = remap.noremap
local nnoremap = remap.nnoremap
local xnoremap = remap.xnoremap
local vnoremap = remap.vnoremap

-- Make sure space is not mapped to anything!
nnoremap("<space>", "<Nop>")
vim.g.mapleader = " "

-- Plugins configuration {{{1

rc("nord")
rc("neo-tree")
rc("lualine")
rc("treesitter")
rc("lsp-config")
rc("metals")
rc("telescope")
rc("go")
rc("web-devicons")
rc("nvim-dap-ui")
rc("markdown-preview")
rc("formatter")

-- Runtime for FZF
vim.opt.runtimepath:append("/usr/local/bin/fzf")

-- General preferences {{{1

-- Center the view
vim.opt.scrolloff = 9999

-- Tabbing
vim.opt.tabstop = 2 -- The number of spaces a tab is
vim.opt.shiftwidth = 2 -- Number of spaces to use in auto(indent)
vim.opt.softtabstop = 2 -- Just to be clear
vim.opt.expandtab = true -- Insert tabs as spaces
vim.opt.smartindent = true -- Use smart indentation, works for C like langs.

-- Searching
vim.opt.wrapscan = true -- Wrap searches
vim.opt.ignorecase = true -- Ignore search term case...
vim.opt.smartcase = true -- ... unless term contains an uppercase character

-- Wrapping
vim.opt.textwidth = 80 -- Hard-wrap text at nth column
vim.opt.wrap = true -- Wrap long lines (bad for vsplits)

-- Folding
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99

-- General
vim.opt.lazyredraw = true -- Do not redraw screen in the middle of a macro. Makes them complete faster.
vim.opt.clipboard = "unnamed,unnamedplus"

-- Mappings {{{1

local snmap = { noremap = true, silent = true }
local sexpr = { silent = true, expr = true }

-- Move between splits with CTRL+[hjkl]
nnoremap("<C-h>", "<C-w>h")
nnoremap("<C-h><C-j>", "<C-w>j")
nnoremap("<C-h><C-k>", "<C-w>k")
nnoremap("<C-h><C-l>", "<C-w>l")

-- Resize splits with CTRL+SHIFT+[hjkl]
nnoremap("<S-h>", ":vertical resize +1<CR>", snmap)
nnoremap("<S-j>", ":resize -1<CR>", snmap)
nnoremap("<S-k>", ":resize +1<CR>", snmap)
nnoremap("<S-l>", ":vertical resize -1<CR>", snmap)

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

-- Formatting
nnoremap("<leader>fm", ":FormatWrite<CR>", snmap)

-- Telescope mappings, should move these to telescope.lua

-- Functions {{{1

vim.api.nvim_create_user_command("ReloadMyConfigs", "so $MYVIMRC | echo 'Configs reloaded!'", {})