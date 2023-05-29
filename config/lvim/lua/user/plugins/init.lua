require("user.plugins.builtin")

lvim.plugins = {
  -- Better diagnoscitcs.
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
    config = function()
      require("trouble").setup({ auto_close = true })
    end
  },
  -- Smooth scroll effect, idk If I'm even using it.
  {
    "karb94/neoscroll.nvim",
    config = function() require("neoscroll").setup() end
  },
  -- Usefull for colorscheme related work, mostly due to TSHighlightCapturesUnderCursor.
  { "nvim-treesitter/playground" },
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
  -- Higlight and easily manage TODO comments.
  {
    "folke/todo-comments.nvim",
    config = function()
      require("todo-comments").setup()
    end
  },
  -- Leap helps you move faster :)
  {
    "ggandor/leap.nvim",
    config = function()
      require("leap").add_default_mappings()
    end,
  },
  -- DAP
  "leoluz/nvim-dap-go",
  "mfussenegger/nvim-dap-python",
  -- Awesome test runners :)
  {
    "nvim-neotest/neotest",
    config = require("user.plugins.neotest").setup
  },
  "nvim-neotest/neotest-go",
  "nvim-neotest/neotest-python",
  -- Git
  {
    "sindrets/diffview.nvim",
    event = "BufRead"
  },
  -- Notifications UI
  {
    "rcarriga/nvim-notify",
    config = function()
      vim.notify = require("notify")
    end
  },
}
