autocmd BufRead,BufNewFile */templates/*.yaml,*/templates/*.tpl,helmfile*.yaml set ft=helm

" Use {{/* */}} as comments
autocmd FileType helm setlocal commentstring={{/*\ %s\ */}}
