local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node

local function is_bats_file()
	return vim.fn.expand("%:e") == "bats"
end

local function bats_snippet(context, nodes)
	context.condition = is_bats_file
	context.show_condition = is_bats_file
	return s(context, nodes)
end

return {
	bats_snippet({ trig = "batsfocus", dscr = "Bats focused test tag" }, t("# bats test_tags=bats:focus")),

	bats_snippet({ trig = "batsfocusfile", dscr = "Bats focused file tag" }, t("# bats file_tags=bats:focus")),
}
