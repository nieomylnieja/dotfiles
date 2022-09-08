" vim:fdm=marker:fdl=0
let mapleader = ','

" Plugins {{{1

function! ImportConfig(file)
  exec printf('source %s', fnamemodify(expand('$MYVIMRC'), ':h') . expand('/config/') . a:file)
endfunction

call ImportConfig('nord.lua')
call ImportConfig('neo-tree.lua')
call ImportConfig('lualine.lua')
call ImportConfig('markdown-preview.vim')
call ImportConfig('treesitter.lua')
call ImportConfig('lsp-config.lua')
call ImportConfig('metals.lua')
call ImportConfig('telescope.lua')
call ImportConfig('go.lua')
call ImportConfig('web-devicons.lua')
call ImportConfig('nvim-dap-ui.lua')

" Runtime for FZF
set runtimepath+=/usr/local/bin/fzf

" General preferences {{{1

" Center the view
set scrolloff=9999

" Tabbing
set tabstop=2           " The number of spaces a tab is
set shiftwidth=2        " Number of spaces to use in auto(indent)
set softtabstop=2       " Just to be clear
set expandtab           " Insert tabs as spaces

" Searching
set wrapscan            " Wrap searches
set ignorecase          " Ignore search term case...
set smartcase           " ... unless term contains an uppercase character

" Wrapping
set textwidth=80        " Hard-wrap text at nth column
set nowrap              " Don't wrap long lines (good for vsplits)

" Folding
set foldmethod=indent
set foldlevel=99

" General
set lazyredraw          " Do not redraw screen in the middle of a macro. Makes them complete faster.
set clipboard=unnamed,unnamedplus

" Prevent vim from clearing clipboard on exit
autocmd VimLeave * call system("xsel -ib", getreg('+'))

" Go config, should be probably moved to a different file..
autocmd BufWritePre *.go lua vim.lsp.buf.formatting()
autocmd BufWritePre *.go lua goimports(1000)

" Mappings {{{1

" Move between splits with CTRL+[hjkl]
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize splits with CTRL+SHIFT+[hjkl]
nnoremap <silent> <S-h> :vertical resize +1<CR>
nnoremap <silent> <S-j> :resize -1<CR>
nnoremap <silent> <S-k> :resize +1<CR>
nnoremap <silent> <S-l> :vertical resize -1<CR>

" Disable those filthy arrows
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Right> <Nop>
noremap <Left> <Nop>

" System clipboard
vnoremap y "+y

" Fold with space
nnoremap <space> za

" Neat base64 decoding and encoding
noremap <leader>d c<c-r>=system('base64 --decode', @")<cr><esc>gv<left>
vnoremap <leader>e c<c-r>=system('base64', @")<cr><BS><esc>gv<left>

" j/k will move virtual lines (lines that wrap)
noremap <silent> <expr> j (v:count == 0 ? 'gj' : 'j')
noremap <silent> <expr> k (v:count == 0 ? 'gk' : 'k')

" Fugitive Conflict Resolution
nnoremap <leader>gd :Gdiffsplit!<CR>
nnoremap gdh :diffget //2<CR>
nnoremap gdl :diffget //3<CR>

" Telescope mappings, should move these to telescope.lua
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
nnoremap <leader>fc <cmd>lua require('telescope.builtin').git_branches()<cr>
nnoremap <leader>ft <cmd>lua require('telescope.builtin').treesitter()<cr>

" Functions {{{1

command! ReloadVimConfigs so $MYVIMRC
  \| echo 'configs reloaded!'
