local M = {}

local Log = require "nieomylnieja.lib.log"
local is_loaded, neogen = pcall(require, "neogen")
if not is_loaded then
  Log:error "`neogen` plugin not loaded, but was required"
  return M
end

M.setup = function()
  neogen.setup { snippet_engine = "luasnip" }
end

--- Checks of the cursor can jump backwards or forwards and performs the jump
---@param reverse boolean
---@return boolean
M.jump_if_applicable = function(reverse)
  reverse = reverse or false
  local jumpable = neogen.jumpable(reverse)
  if jumpable then
    if reverse then
      neogen.jump_prev()
    else
      neogen.jump_next()
    end
  end
  return jumpable
end

return M
