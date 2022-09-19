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

return packer.startup(function()
	use("wbthomason/packer.nvim")

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
		ft = { "markdown", "plantuml" },
		config = function()
			require("nieomylnieja.markdown-preview")
		end,
	})

	-- Color scheme
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

	-- Debugging
	use("mfussenegger/nvim-dap")
	use({ "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } })
	use({ "theHamsta/nvim-dap-virtual-text", requires = { "mfussenegger/nvim-dap" } })

	-- LSP
	use({
		"neovim/nvim-lspconfig",
		config = function()
			require("nieomylnieja.lsp")
		end,
	})
	use("hrsh7th/nvim-cmp")
	use("hrsh7th/cmp-nvim-lsp")
	use("hrsh7th/cmp-buffer")
	use({
		"scalameta/nvim-metals",
		ft = "scala",
		config = function()
			require("nieomylnieja.metals")
		end,
	})
	use({ "Fymyte/rasi.vim", ft = "rasi" })
	use({
		"ray-x/go.nvim",
		ft = "go",
		config = function()
			require("nieomylnieja.go")
		end,
	})

	-- Syntax highlighting
	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		config = function()
			require("nieomylnieja.treesitter")
		end,
	})
	use("nvim-treesitter/nvim-treesitter-context")

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
