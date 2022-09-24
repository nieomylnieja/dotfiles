local k = require("nieomylnieja.keymap")
local silent = { silent = true }

k.nnoremap("<leader>xx", "<cmd>TroubleToggle<cr>", silent)
k.nnoremap("<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", silent)
k.nnoremap("<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", silent)
k.nnoremap("<leader>xl", "<cmd>TroubleToggle loclist<cr>", silent)
k.nnoremap("<leader>xq", "<cmd>TroubleToggle quickfix<cr>", silent)
k.nnoremap("gR", "<cmd>TroubleToggle lsp_references<cr>", silent)
