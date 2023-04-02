local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system { "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path }
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()
local packer = require "packer"

return packer.startup(function(use)
  use "wbthomason/packer.nvim"

  -- Prerequisite
  use "nvim-lua/plenary.nvim"
  use "lewis6991/impatient.nvim"
  use "rcarriga/nvim-notify"
  use "Tastyep/structlog.nvim"

  -- Color scheme and the looks
  use "shaunsingh/nord.nvim"
  use "kyazdani42/nvim-web-devicons"
  use "stevearc/dressing.nvim"
  use "nvim-lualine/lualine.nvim"
  use { "akinsho/bufferline.nvim", tag = "v2.*" }
  use {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v2.x",
    requires = "MunifTanjim/nui.nvim",
  }
  use "folke/which-key.nvim"
  use "norcalli/nvim-colorizer.lua"

  -- Management
  use "goolord/alpha-nvim"
  use "ahmedkhalf/project.nvim"

  -- Searching
  use { "nvim-telescope/telescope.nvim", branch = "0.1.x" }
  use { "nvim-telescope/telescope-fzf-native.nvim", run = "make" }
  use "nvim-pack/nvim-spectre"

  -- Markdown, plantuml and more
  use { "iamcco/markdown-preview.nvim", run = "cd app && npm install", ft = { "markdown", "plantuml" } }
  use { "preservim/vim-markdown", ft = "markdown" }
  use { "frabjous/knap" }

  -- Manage LSP and DAP server, linters and formatters.
  use "williamboman/mason.nvim"
  use "williamboman/mason-lspconfig.nvim"
  use "WhoIsSethDaniel/mason-tool-installer.nvim"

  -- Debugging
  use "mfussenegger/nvim-dap"
  use "rcarriga/nvim-dap-ui"
  use "theHamsta/nvim-dap-virtual-text"
  use "leoluz/nvim-dap-go"
  use "nvim-telescope/telescope-dap.nvim"
  use "jbyuki/one-small-step-for-vimkind"
  use "mfussenegger/nvim-dap-python"

  -- Code (LSPs and stuff)
  use "neovim/nvim-lspconfig"
  use "ray-x/lsp_signature.nvim"
  use "RRethy/vim-illuminate"
  use "pearofducks/ansible-vim"
  -- Completion
  use "hrsh7th/nvim-cmp"
  use "hrsh7th/cmp-nvim-lsp"
  use "hrsh7th/cmp-buffer"
  use "hrsh7th/cmp-path"
  use "hrsh7th/cmp-cmdline"
  use "saadparwaiz1/cmp_luasnip"
  use "rcarriga/cmp-dap"
  use "hrsh7th/cmp-nvim-lsp-signature-help"
  use "onsails/lspkind.nvim"
  use "simrat39/symbols-outline.nvim"
  use { "L3MON4D3/LuaSnip", tag = "v1.*" }
  use "rafamadriz/friendly-snippets"
  use {
    "scalameta/nvim-metals",
    ft = "scala",
    config = function()
      require "nieomylnieja.metals"
    end,
  }
  use { "Fymyte/rasi.vim", ft = "rasi" }
  use "windwp/nvim-autopairs"
  -- Treesitter
  use { "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" }
  use "nvim-treesitter/nvim-treesitter-context"
  use "JoosepAlviste/nvim-ts-context-commentstring"
  use "jose-elias-alvarez/null-ls.nvim"
  use "folke/trouble.nvim"
  use "numToStr/Comment.nvim"
  use "lukas-reineke/indent-blankline.nvim"
  use "folke/todo-comments.nvim"
  use "danymat/neogen"
  use "kylechui/nvim-surround"
  use "RRethy/nvim-treesitter-endwise"
  use "simrat39/rust-tools.nvim"

  -- Terminal
  use { "akinsho/toggleterm.nvim", tag = "*" }

  -- Git
  use "lewis6991/gitsigns.nvim"
  use "sindrets/diffview.nvim"
  -- FIXME: After they fix it for non git cwd I'll have to remove the commit restraint.
  use { "TimUntersberger/neogit", commit = "8adf22f103250864171f7eb087046db8ad296f78" }
  use "petertriho/cmp-git"

  if packer_bootstrap then
    packer.sync()
  end
end)
