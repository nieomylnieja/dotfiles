return require("packer").startup(function()
	use("wbthomason/packer.nvim")

	-- Formatting
	use("mhartington/formatter.nvim")

	-- Status line
	use({ "nvim-lualine/lualine.nvim", requires = { "kyazdani42/nvim-web-devicons" } })

	-- Tree view tab
	use({
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		requires = {
			"nvim-lua/plenary.nvim",
			"kyazdani42/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
	})

	--Searching
	use({
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		requires = { "nvim-lua/plenary.nvim" },
	})
	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })

	-- Markdown, plantuml and more previewer
	use({ "iamcco/markdown-preview.nvim", run = vim.fn["mkdp#util#install"] })

	-- Color scheme
	use("shaunsingh/nord.nvim")

	-- Debugging
	use("mfussenegger/nvim-dap")
	use({ "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } })

	-- LSP
	use("neovim/nvim-lspconfig")
	use("hrsh7th/nvim-cmp")
	use("hrsh7th/cmp-nvim-lsp")
	use("hrsh7th/cmp-buffer")
	use({ "scalameta/nvim-metals", ft = "scala" })
	use({ "Fymyte/rasi.vim", ft = "rasi" })
	use({ "ray-x/go.nvim", ft = "go" })

	-- Syntax highlighting
	use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" })

	-- Popes awesomness
	use("tpope/vim-commentary")
	use("tpope/vim-fugitive")
	use("tpope/vim-repeat")
	-- TODO: I should write these settings to init.lua to get a better grasp on what's what.
	use("tpope/vim-sensible")
	use("tpope/vim-surround")
end)
