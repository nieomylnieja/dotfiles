local ensure_packer = function()
	local fn = vim.fn
	local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
	if fn.empty(fn.glob(install_path)) > 0 then
		fn.system({ "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path })
		vim.cmd([[packadd packer.nvim]])
		return true
	end
	return false
end

local packer_bootstrap = ensure_packer()
local packer = require("packer")

return packer.startup(function(use)
	use("wbthomason/packer.nvim")

	-- Prerequisite
	use("nvim-lua/plenary.nvim")

	-- Color scheme and the looks
	use("shaunsingh/nord.nvim")
	use("kyazdani42/nvim-web-devicons")
	use("nvim-lualine/lualine.nvim")
	use({ "akinsho/bufferline.nvim", tag = "v2.*" })
	use({
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		requires = "MunifTanjim/nui.nvim",
	})
	use("folke/which-key.nvim")
	use("folke/trouble.nvim")

	-- Searching
	use({ "nvim-telescope/telescope.nvim", branch = "0.1.x" })
	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })

	-- Markdown, plantuml and more previewer
	use({ "iamcco/markdown-preview.nvim", run = "cd app && npm install" })

	-- Manage LSP and DAP server, linters and formatters.
	use("williamboman/mason.nvim")
	use("williamboman/mason-lspconfig.nvim")
	use("WhoIsSethDaniel/mason-tool-installer.nvim")

	-- Debugging
	use("mfussenegger/nvim-dap")
	use("rcarriga/nvim-dap-ui")
	use("theHamsta/nvim-dap-virtual-text")

	-- LSP
	use("neovim/nvim-lspconfig")
	use("hrsh7th/nvim-cmp")
	use("hrsh7th/cmp-nvim-lsp")
	use("hrsh7th/cmp-buffer")
	use("onsails/lspkind.nvim")
	use("simrat39/symbols-outline.nvim")
	use("mfussenegger/nvim-lint")
	use({ "L3MON4D3/LuaSnip", tag = "v1.*" })
	use("rafamadriz/friendly-snippets")
	use("saadparwaiz1/cmp_luasnip")
	use({
		"scalameta/nvim-metals",
		ft = "scala",
		config = function()
			require("nieomylnieja.metals")
		end,
	})
	use({ "Fymyte/rasi.vim", ft = "rasi" })

	-- Syntax highlighting
	use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" })
	use("nvim-treesitter/nvim-treesitter-context")

	-- Formatting
	use("mhartington/formatter.nvim")

	-- Terminal
	use({ "akinsho/toggleterm.nvim", tag = "*" })

	-- Git
	use("lewis6991/gitsigns.nvim")
	use("pwntester/octo.nvim")
	use("sindrets/diffview.nvim")
	use("TimUntersberger/neogit")
	use("petertriho/cmp-git")

	-- Popes awesomness
	use("tpope/vim-commentary")
	use("tpope/vim-repeat")
	-- TODO: I should write these settings to init.lua to get a better grasp on what's what.
	use("tpope/vim-sensible")
	use("tpope/vim-surround")

	if packer_bootstrap then
		packer.sync()
	end
end)
