local M = {}

M.setup = function()
  local is_loaded, comment = pcall(require, "Comment")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "'Comment' was required but not loaded"
    return
  end

  comment.setup {
    padding = true,
    ignore = "^$",
    pre_hook = function(ctx)
      require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()

      if vim.bo.filetype == "javascript" or vim.bo.filetype == "typescript" then
        local U = require "Comment.utils"

        -- Determine whether to use linewise or blockwise commentstring
        local type = ctx.ctype == U.ctype.linewise and "__default" or "__multiline"

        -- Determine the location where to calculate commentstring from
        local location = nil
        if ctx.ctype == U.ctype.blockwise then
          location = require("ts_context_commentstring.utils").get_cursor_location()
        elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
          location = require("ts_context_commentstring.utils").get_visual_start_location()
        end

        return require("ts_context_commentstring.internal").calculate_commentstring {
          key = type,
          location = location,
        }
      end
    end,
  }
end

return M
