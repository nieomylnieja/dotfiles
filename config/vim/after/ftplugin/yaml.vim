" autocmd BufNewFile,BufReadPost *.{yaml,yml} set filetype=yaml foldmethod=indent foldnextmax=20
autocmd FileType yaml setlocal filetype=yaml foldmethod=indent foldnestmax=20
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
