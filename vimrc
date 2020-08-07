set nocompatible
set encoding=utf-8

"" }}}
"" PLUGINS {{{

" automate vim-plugin installation
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

" nord colors
Plug 'arcticicestudio/nord-vim'

" Initialize plugin system
call plug#end()

" Disable those filthy arrows
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" System clipboard
set clipboard=unnamed,unnamedplus
vnoremap y "+y

" Relative line numbers
set rnu

" make backspace work like most other programs
set backspace=2 

" prevent vim from clearing clipboard on exit
autocmd VimLeave * call system("xsel -ib", getreg('+'))

" colors
colorscheme nord
