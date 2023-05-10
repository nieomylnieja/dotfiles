local lualine = require "lualine"

-- Config
local config = {
  options = {
    section_separators = "",
    component_separators = "",
    theme = require("nieomylnieja.colors.lualine"),
    disabled_filetypes = {
      statusline = { "neo-tree" },
    },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = {},
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
}

-- Now don't forget to initialize lualine
lualine.setup(config)
