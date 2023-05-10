require("nvim-treesitter.configs").setup {
  -- I'm fine with all since it doesn't impact my nvim performance, just eats
  -- some space, but who cares really, If I want to I can olways trim it.
  ensure_installed = "all",
  sync_install = false,
  highlight = {
    enable = true,
    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
  autopairs = { enable = true },
  indent = {
    enable = true,
    -- FIXME: Once treesitter works fine for these, remove that ;)
    -- Refer to https://github.com/NvChad/NvChad/issues/1591 for more details.
    disable = { "python", "yaml" },
  },
  context_commentstring = {
    enable = true,
    enable_autocmd = false,
    config = {
      -- Languages that have a single comment style
      typescript = "// %s",
      css = "/* %s */",
      scss = "/* %s */",
      html = "<!-- %s -->",
      svelte = "<!-- %s -->",
      vue = "<!-- %s -->",
      json = "",
    },
  },
  endwise = { enable = true },
}

-- Runtime for FZF
vim.opt.runtimepath:append "/usr/local/bin/fzf"

-- Highlight for Octo
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.markdown.filetype_to_parsername = "octo"
