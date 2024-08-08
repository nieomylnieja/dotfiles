local opt = vim.opt

opt.laststatus = 3 -- global statusline
opt.showmode = false
opt.showcmd = false

opt.clipboard = "unnamedplus"
opt.cursorline = true
opt.swapfile = false

-- Indenting
opt.expandtab = true
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

opt.fillchars = { eob = " " }
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"

-- Numbers
opt.number = true
opt.relativenumber = true
opt.numberwidth = 2
opt.ruler = false

-- disable nvim intro
opt.shortmess:append("fFIlqx")

opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.timeoutlen = 400
opt.undofile = true
opt.scrolloff = 999 -- Center the view

-- Relevant for popup menus, like cmp
opt.pumheight = 10 -- limit to 10 entries

-- interval for writing swap file to disk, also used by gitsigns
opt.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
opt.whichwrap:append("<>[]hl")

vim.g.mapleader = " "

-- disable some default providers
for _, provider in ipairs({ "node", "perl", "python3", "ruby" }) do
  vim.g["loaded_" .. provider .. "_provider"] = 0
end

-- add binaries installed by mason.nvim to path
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin" .. ":" .. vim.env.PATH

-- https://editorconfig.org builtin support
vim.g.editorconfig = {
  indent_style = "space",
  trim_trailing_whitespace = true,
  insert_final_newline = false,
}

-- grep configuration
opt.grepprg="rg --vimgrep --no-heading --smart-case"
opt.grepformat="%f:%l:%c:%m"
