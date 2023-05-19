lvim.plugins = {
  -- Better diagnoscitcs.
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  -- Smooth scroll effect, idk If I'm even using it.
  {
    "karb94/neoscroll.nvim",
    config = function() require("neoscroll").setup() end
  },
  -- Usefull for colorscheme related work, mostly due to TSHighlightCapturesUnderCursor.
  { "nvim-treesitter/playground" },
  -- These both bridge the gap between Mason and null-ls/dap...
  -- They are not perfect though and I might end up doing sth on my own eventually.
  { "jay-babu/mason-null-ls.nvim" },
  { "jay-babu/mason-nvim-dap.nvim" },
  -- Makes all the windows and stuff like lsp rename look so much better.
  {
    "stevearc/dressing.nvim",
    config = function() require("dressing").setup() end
  },
  -- Get colors for color codes.
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup({ "css", "scss", "html", "javascript", "lua" })
    end
  },
}
