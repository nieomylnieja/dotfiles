local lint = require("lint")

lint.linters_by_ft = {
	all = { "cspell" },
	sh = { "shellcheck" },
	go = { "golangcilint" },
	text = { "vale" },
	markdown = { "vale" },
	rst = { "vale" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	callback = function()
		lint.try_lint()
	end,
})
