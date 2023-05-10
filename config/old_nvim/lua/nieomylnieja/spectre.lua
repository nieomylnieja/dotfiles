local M = {}

local Log = require "nieomylnieja.lib.log"
local keymap = require("nieomylnieja.keymap")

M.setup = function()
  local is_loaded, spectre = pcall(require, "spectre")
  if not is_loaded then
    Log:error "`spectre` plugin not loaded, but was required"
    return M
  end
  spectre.setup()
  keymap.nnoremap("<leader>S" ,"<cmd>:lua require('spectre').open()<CR>")
  keymap.nnoremap("<leader>sw", "<cmd>:lua require('spectre').open_visual({select_word=true})<CR>")
  keymap.vnoremap("<leader>s", "<esc>:lua require('spectre').open_visual()<CR>")
  keymap.nnoremap("<leader>sp", "viw:lua require('spectre').open_file_search()<cr>")
end

return M
