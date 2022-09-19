require("nvim-treesitter.configs").setup({
	-- A list of parser names, or "all"
	-- I'm fine with all since it doesn't impact my nvim performance, just eats
	-- some space, but who cares really, If I want to I can olways trim it.
	ensure_installed = "all",
	sync_install = false,
	highlight = {
		enable = true,
		-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
		-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
		-- Using this option may slow down your editor, and you may see some duplicate highlights.
		-- Instead of true it can also be a list of languages
		additional_vim_regex_highlighting = false,
	},

	indent = { enable = true, disable = { "" } },
})

-- Runtime for FZF
vim.opt.runtimepath:append("/usr/local/bin/fzf")
