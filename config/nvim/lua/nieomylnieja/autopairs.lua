local M = {}

M.config = {
  check_ts = true,
  ts_config = {
    lua = { "string" },
    javascript = { "template_string" },
    java = false,
  },
  disable_filetype = { "TelescopePrompt" },
  fast_wrap = {
    map = "<M-e>",
    chars = { "{", "[", "(", '"', "'" },
    pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
    offset = 0, -- Offset from pattern match
    end_key = "$",
    keys = "qwertyuiopzxcvbnmasdfghjkl",
    check_comma = true,
    highlight = "PmenuSel",
    highlight_grey = "LineNr",
  },
}

M.setup = function()
  local is_loaded, autopairs = pcall(require, "nvim-autopairs")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "'nvim-autopairs' was required but not loaded"
    return
  end

  autopairs.setup { M.config }

  local rule = require "nvim-autopairs.rule"
  local cond = require "nvim-autopairs.conds"

  autopairs.add_rules {
    rule("$$", "$$", "tex"),
    rule("$", "$", { "tex", "latex" }) -- don't add a pair if the next character is %
      :with_pair(cond.not_after_regex_check "%%") -- don't add a pair if  the previous character is xxx
      :with_pair(cond.not_before_regex_check("xxx", 3)) -- don't move right when repeat character
      :with_move(cond.none()) -- don't delete if the next character is xx
      :with_del(cond.not_after_regex_check "xx") -- disable  add newline when press <cr>
      :with_cr(cond.none()),
    rule("$$", "$$", "tex"):with_pair(function(opts)
      print(vim.inspect(opts))
      if opts.line == "aa $$" then
        -- don't add pair on that line
        return false
      end
    end),
  }

  -- cmp
  local cmp = require "cmp"
  local cmp_autopairs = require "nvim-autopairs.completion.cmp"
  cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done { map_char = { all = "(", tex = "{" } })

  -- tressitter
  require("nvim-treesitter.configs").setup { autopairs = { enable = true } }
  local ts_conds = require "nvim-autopairs.ts-conds"
  -- press % => %% is only inside comment or string
  autopairs.add_rules {
    rule("%", "%", "lua"):with_pair(ts_conds.is_ts_node { "string", "comment" }),
    rule("$", "$", "lua"):with_pair(ts_conds.is_not_ts_node { "function" }),
  }
end

return M
