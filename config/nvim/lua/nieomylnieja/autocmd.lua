local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

nieomylniejaGroup = augroup('nieomylnieja', {})

-- Golang lsp.
autocmd("BufWritePre", {
  pattern = "*.go",
  group = nieomylniejaGroup,
  callback = vim.lsp.buf.formatting
})

autocmd("BufWritePre", {
  pattern = "*.go",
  group = nieomylniejaGroup,
  callback = function()
    goimports(1000)
  end
})

-- Prevent vim from clearing clipboard on exit.
autocmd("VimLeave", {
  pattern = "*",
  command = "call system('xsel -ib', getreg('+'))"
})
