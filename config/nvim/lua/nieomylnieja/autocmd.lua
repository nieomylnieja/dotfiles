local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local nieomylniejaGroup = augroup('nieomylnieja', {})

-- Prevent vim from clearing clipboard on exit.
autocmd("VimLeave", {
  group = nieomylniejaGroup,
  pattern = "*",
  command = "call system('xsel -ib', getreg('+'))"
})
