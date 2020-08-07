
set nocompatible
set encoding=utf-8

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
