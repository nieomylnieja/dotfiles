local M = {}

M.setup = function()
  vim.g.knap_settings = {
    htmloutputext = "html",
    htmltohtml = "none",
    htmltohtmlviewerlaunch = "brave %outputfile%",
    htmltohtmlviewerrefresh = "none",
    mdoutputext = "html",
    mdtohtml = "pandoc --standalone %docroot% -o %outputfile%",
    mdtohtmlviewerlaunch = "falkon %outputfile%",
    mdtohtmlviewerrefresh = "none",
    mdtopdf = "pandoc %docroot% -o %outputfile%",
    mdtopdfviewerlaunch = "sioyek %outputfile%",
    mdtopdfviewerrefresh = "none",
    markdownoutputext = "html",
    markdowntohtml = "pandoc --standalone %docroot% -o %outputfile%",
    markdowntohtmlviewerlaunch = "falkon %outputfile%",
    markdowntohtmlviewerrefresh = "none",
    markdowntopdf = "pandoc %docroot% -o %outputfile%",
    markdowntopdfviewerlaunch = "sioyek %outputfile%",
    markdowntopdfviewerrefresh = "none",
    texoutputext = "pdf",
    textopdf = "pdflatex --shell-escape -interaction=batchmode -halt-on-error -synctex=1 %docroot%",
    textopdfviewerlaunch = [[zathura --synctex-editor-command 'nvim --headless -es --cmd "lua require('"'"'knaphelper'"'"').relayjump('"'"'%servername%'"'"','"'"'%{input}'"'"',%{line},0)"' %outputfile%]],
    textopdfviewerrefresh = "none",
    textopdfforwardjump = "zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%",
    textopdfshorterror = 'A=%outputfile% ; LOGFILE="${A%.pdf}.log" ; rubber-info "$LOGFILE" 2>&1 | head -n 1',
    delay = 250,
  }
end

return M
