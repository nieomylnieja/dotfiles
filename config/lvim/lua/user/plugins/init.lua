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
      require("notify").setup({ minimum_width = 15 })
      vim.notify = require("notify")
    end
  },
  -- AI boosters
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    dependencies = { "zbirenbaum/copilot.lua" },
    config = function()
      vim.defer_fn(function()
        require("copilot").setup()
        -- It is recommended to disable copilot.lua's suggestion and panel modules,
        -- as they can interfere with completions properly appearing in copilot-cmp.
        require("copilot_cmp").setup({
          suggestion = { enabled = false },
          panel = { enabled = false },
        })
      end, 100)
    end,
  },
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      require("chatgpt").setup({
        api_key_cmd = "pass show api/tokens/openai"
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    }
  },
}
