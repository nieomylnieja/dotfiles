vim.cmd([[
  augroup _general_settings
    autocmd!
    autocmd FileType qf,help,man,lspinfo,spectre_panel,toggleterm nnoremap <silent> <buffer> q :close<CR>
    autocmd TextYankPost * silent!lua require('vim.highlight').on_yank({higroup = 'Visual', timeout = 200})
    autocmd BufWinEnter * :set formatoptions-=cro
    autocmd FileType qf set nobuflisted
  augroup end
  augroup _git
    autocmd!
    autocmd FileType gitcommit setlocal wrap
    autocmd FileType gitcommit setlocal spell
  augroup end
  augroup _markdown
    autocmd!
    autocmd FileType markdown setlocal wrap
    autocmd FileType markdown setlocal spell
  augroup end
  augroup _auto_resize
    autocmd!
    autocmd VimResized * tabdo wincmd =
  augroup end
  augroup _alpha
    autocmd!
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
  augroup end
  augroup _json
    autocmd!
    autocmd FileType json,jsonc setlocal wrap
  augroup end
  augroup _zsh
    autocmd!
    autocmd FileType zsh silent!lua require("nvim-treesitter.highlight").attach(0, "bash")
  augroup end
]])

local gs = vim.api.nvim_create_augroup("GeneralSettings", { clear = true })

vim.api.nvim_create_autocmd("VimLeave", {
  group = gs,
  pattern = "*",
  callback = function()
    vim.fn("system('xsel -ib', getreg('+'))")
  end
})
