set nocompatible
set encoding=utf-8

"" {{{
"" LEGEND
"
" - VIMPLUG
" - GENERAL
" - PLUGINS
"   - lightline
"   - coc
"
"" END LEGEND
"" }}}


"" {{{
"" PLUGINS

" automate vim-plugin installation
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

Plug 'arcticicestudio/nord-vim'
Plug 'itchyny/lightline.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'shumphrey/fugitive-gitlab.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Initialize plugin system
call plug#end()

"" END PLUGINS
"" }}}


"" {{{
"" GENERAL

" Do not redraw screen in the middle of a macro. Makes them complete faster.
set lazyredraw
" syntax
syntax on
filetype plugin on
" Disable those filthy arrows
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Right> <Nop>
noremap <Left> <Nop>
" System clipboard
set clipboard=unnamed,unnamedplus
vnoremap y "+y
" make backspace work like most other programs
set backspace=2 
" prevent vim from clearing clipboard on exit
autocmd VimLeave * call system("xsel -ib", getreg('+'))
" colors
colorscheme nord

"" END GENERAL
"" }}}

noremap <leader>d c<c-r>=system('base64 --decode', @")<cr><esc>gv<left>
" vnoremap <leader>e c<c-r>=system('base64 -w 0', @")<cr><esc>gv
vnoremap <leader>e c<c-r>=system('base64', @")<cr><BS><esc>gv<left>


" lightline
set laststatus=2
if !has('gui_running')
  set t_Co=256
endif

let g:lightline = {
      \ 'colorscheme': 'nord',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'FugitiveHead'
      \ },
      \ }

" start nerd tree if no files were specified or when opening a dir
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | exe 'cd '.argv()[0] | endif
map <C-n> :NERDTreeToggle<CR> " Ctrl+n
map <C-f> :NERDTreeFocus<CR> " Ctrl+f

" -----------------
" coc configuration
set nobackup
set nowritebackup
set hidden
set cmdheight=2
set updatetime=300
set shortmess+=c
set signcolumn=number
set number

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
" -----------------
"  awesome integrations for fugitive
let g:fugitive_gitlab_domains = ['https://my.gitlab.com']
