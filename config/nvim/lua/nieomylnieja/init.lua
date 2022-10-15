-- vim:fdm=marker
vim.g.mapleader = " "

-- General preferences {{{1

local opt = vim.opt

-- General
opt.shortmess:append "c"
opt.lazyredraw = true -- Do not redraw screen in the middle of a macro. Makes them complete faster.
opt.clipboard = { "unnamed", "unnamedplus" } -- Allows neovim to access the system clipboard
opt.scrolloff = 9999 -- Center the view
opt.number = true -- Set numbered lines
opt.relativenumber = true -- Set relative numbered lines
opt.mouse = "a" -- Enable mouse
opt.termguicolors = true -- Required by bufferline!
opt.hidden = true -- Otherwise terminals managed by toggleterm are discarded.
opt.splitbelow = true -- Force all horizontal splits to go below current window
opt.splitright = true -- Force all vertical splits to go to the right of current window
opt.swapfile = false
opt.pumheight = 10
opt.completeopt = { "menuone", "noselect" }
opt.timeoutlen = 500
opt.undofile = true -- Peristent undo
opt.updatetime = 300 -- Faster completion (4s default!)
opt.writebackup = false
opt.signcolumn = "yes" -- Always show the sign column, otherwise it would shift the text each time

-- Tabbing
opt.tabstop = 2 -- The number of spaces a tab is
opt.shiftwidth = 2 -- Number of spaces to use in auto(indent)
opt.softtabstop = 2 -- Just to be clear
opt.expandtab = true -- Insert tabs as spaces

-- Searching
opt.wrapscan = true -- Wrap searches
opt.ignorecase = true -- Ignore search term case...
opt.smartcase = true -- ... unless term contains an uppercase character

-- Wrapping
opt.textwidth = 80 -- Hard-wrap text at nth column
opt.wrap = false -- Don't wrap long lines (good for vsplits, bad otherwise?)

-- Folding
opt.foldmethod = "manual"
opt.foldexpr = "nvim_treesitter#foldexpr()"

-- Setup {{{1

local function req(name)
  return require("nieomylnieja." .. name)
end

req("lib.notify").setup()
req("lib.commands").load()

-- Mappings {{{1

local remap = require "nieomylnieja.keymap"

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

-- Resize with arrows
nnoremap("<S-k>", ":resize -2<CR>", silent)
nnoremap("<S-j>", ":resize +2<CR>", silent)
nnoremap("<S-h>", ":vertical resize -2<CR>", silent)
nnoremap("<S-l>", ":vertical resize +2<CR>", silent)

-- System clipboard
vnoremap("y", '"+y')
-- j/k will move virtual lines (lines that wrap)
noremap("j", "(v:count == 0 ? 'gj' : 'j')", silent_expr)
noremap("k", "(v:count == 0 ? 'gk' : 'k')", silent_expr)

-- Paste without loosing buffer
xnoremap("<leader>p", '"_dP')
nnoremap("<leader>d", '"_d')
vnoremap("<leader>d", '"_d')

-- Others
tnoremap("<Esc>", "<C-\\><C-n>")
nnoremap("<leader>so", ":SymbolsOutline<CR>", silent)
noremap("<leader>d", [[c<c-r>=system('base64 --decode', @")<cr><esc>gv<left>]])
vnoremap("<leader>e", [[c<c-r>=system('base64', @")<cr><BS><esc>gv<left>]])
nnoremap("<C-g>", ":Neogit<CR>", silent)
nnoremap("<leader>n", ":Neotree<cr>", silent)
nnoremap("<C-x>", ":BufferKill<CR>", silent)

-- Plugins {{{1

-- Optimize
require "impatient"

-- My own
req "autocmd"

-- Manager
req "packer"
-- Looks
req("colors").setup()
req "web-devicons"
req "dressing"
req "lualine"
req "bufferline"
req "neotree"
req "dashboard"
require("colorizer").setup()
-- Code
req "lsp"
req "debugger"
req "treesitter"
req "treesitter-context"
req "gitsigns"
req "which-key"
req("autopairs").setup()
req("comments").setup()
req "indent"
req "illuminate"
req("code.annotations").setup()
req("code.rust").setup()
-- Other
req "markdown-preview"
req "telescope"
req "term"
-- req "neogit"
req("projects").setup()
req("spectre").setup()
req("todo-comments").setup()
req("surround").setup()
req("knap").setup()
-- Mappings
req "keys"

--- Neovide {{{1
if vim.g.neovide then
  vim.g.neovide_transparency = 0.9
  opt.guifont = "mononoki Nerd Font Mono:h14"
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_scale_factor = 1.0
  vim.api.nvim_create_user_command("ChangeScaleFactor", function(opts)
    local value = 1.25
    if opts.args == "down" then
      value = 1 / value
    end
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor + value
  end, { nargs = 1 })
  noremap("<C-=>", ":ChangeScaleFactor up<cr>", silent)
  noremap("<C-->", ":ChangeScaleFactor down<cr>", silent)
end
