require("indent_blankline").setup({
	char = "▏",
	buftype_exclude = { "terminal", "nofile" },
	filetype_exclude = {
		"help",
		"dashboard",
		"packer",
		"neogitstatus",
		"neo-tree",
		"Trouble",
	},
	show_end_of_line = true,
	show_current_context = true,
	use_treesitter = true,
	show_trailing_blankline_indent = false,
	show_first_indent_level = true,
})
