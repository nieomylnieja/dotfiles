" vim:fdm=marker:fdl=0
let mapleader = ','

" Plugins {{{1

function! ImportConfig(file)
  exec printf('source %s', fnamemodify(expand('$MYVIMRC'), ':h') . expand('/config/') . a:file)
endfunction

call ImportConfig('coc.vim')
call ImportConfig('nerdtree.vim')
call ImportConfig('lightline.vim')
call ImportConfig('markdown-preview.vim')
call ImportConfig('treesitter.lua')

" Runtime for FZF
set runtimepath+=/usr/local/bin/fzf

" Colors
colorscheme nord

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

" Mappings {{{1

" Move between splits with CTRL+[hjkl]
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

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

" Functions {{{1

command! ReloadVimConfigs so $MYVIMRC
  \| echo 'configs reloaded!'
