local M = {}

local Log = require "nieomylnieja.lib.log"

M.setup = function()
  local is_loaded, comments = pcall(require, "todo-comments")
  if not is_loaded then
    Log:error "`todo-comments` plugin not loaded, but was required"
    return M
  end
  comments.setup {
    search = {
      command = "rg",
      args = {
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
      },
      -- regex that will be used to match keywords.
      -- don't replace the (KEYWORDS) placeholder
      -- FIXME: this will catch strings containing the pattern, which is meh...
      pattern = [[\b(KEYWORDS):]], -- ripgrep regex
    },
  }
end

return M
