lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "karb94/neoscroll.nvim",
    config = function()
      require('neoscroll').setup()
    end
  },
  { "nvim-treesitter/playground" },
  { "jay-babu/mason-null-ls.nvim" },
  { "jay-babu/mason-nvim-dap.nvim" },
}
