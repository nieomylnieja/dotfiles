local function req(name)
	require("nieomylnieja.lsp." .. name)
end

req("config")
req("complete")
req("lint")
req("snippets")
req("diagnostics")
