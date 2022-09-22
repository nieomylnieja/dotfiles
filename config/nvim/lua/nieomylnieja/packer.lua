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

	-- Color scheme and the looks
	use({
		"shaunsingh/nord.nvim",
		config = function()
			require("nieomylnieja.nord")
		end,
	})
	use({
		"kyazdani42/nvim-web-devicons",
		config = function()
			require("nieomylnieja.web-devicons")
		end,
	})

	-- Formatting
	use({
		"mhartington/formatter.nvim",
		config = function()
			require("nieomylnieja.format")
		end,
	})

	-- Status line
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "kyazdani42/nvim-web-devicons" },
		config = function()
			require("nieomylnieja.lualine")
		end,
	})
	use({
		"akinsho/bufferline.nvim",
		tag = "v2.*",
		requires = "kyazdani42/nvim-web-devicons",
		config = function()
			require("nieomylnieja.bufferline")
		end,
	})

	-- Tree view tab
	use({
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		requires = {
			"nvim-lua/plenary.nvim",
			"kyazdani42/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("nieomylnieja.neo-tree")
		end,
	})

	-- Searching
	use({
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		requires = { "nvim-lua/plenary.nvim" },
		config = function()
			require("nieomylnieja.telescope")
		end,
	})
	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })

	-- Markdown, plantuml and more previewer
	use({
		"iamcco/markdown-preview.nvim",
		run = "cd app && npm install",
		config = function()
			require("nieomylnieja.markdown-preview")
		end,
	})

	-- Manage LSP and DAP server, linters and formatters.
	use({
		"williamboman/mason.nvim",
		config = function()
			require("nieomylnieja.mason")
		end,
		requires = {
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
	})

	-- Debugging
	use({
		"mfussenegger/nvim-dap",
		config = function()
			require("nieomylnieja.debugger")
		end,
		requires = {
			"rcarriga/nvim-dap-ui",
			"theHamsta/nvim-dap-virtual-text",
		},
	})

	-- LSP
	use({
		"neovim/nvim-lspconfig",
		config = function()
			require("nieomylnieja.lsp.config")
		end,
	})
	use({
		"hrsh7th/nvim-cmp",
		config = function()
			require("nieomylnieja.lsp.complete")
		end,
		requires = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			{
				"L3MON4D3/LuaSnip",
				tag = "v1.*",
				requires = {
					"rafamadriz/friendly-snippets",
					"saadparwaiz1/cmp_luasnip",
				},
				config = function()
					require("nieomylnieja.lsp.snippets")
				end,
			},
			"onsails/lspkind.nvim",
			"simrat39/symbols-outline.nvim",
			{
				"mfussenegger/nvim-lint",
				config = function()
					require("nieomylnieja.lsp.lint")
				end,
			},
		},
	})
	use({
		"scalameta/nvim-metals",
		ft = "scala",
		config = function()
			require("nieomylnieja.metals")
		end,
	})
	use({ "Fymyte/rasi.vim", ft = "rasi" })

	-- Syntax highlighting
	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		config = function()
			require("nieomylnieja.treesitter")
		end,
		requires = "nvim-treesitter/nvim-treesitter",
	})

	-- Terminal
	use({
		"akinsho/toggleterm.nvim",
		tag = "*",
		config = function()
			require("nieomylnieja.term")
		end,
	})

	-- Popes awesomness
	use("tpope/vim-commentary")
	use("tpope/vim-fugitive")
	use("tpope/vim-repeat")
	-- TODO: I should write these settings to init.lua to get a better grasp on what's what.
	use("tpope/vim-sensible")
	use("tpope/vim-surround")

	if packer_bootstrap then
		packer.sync()
	end
end)
