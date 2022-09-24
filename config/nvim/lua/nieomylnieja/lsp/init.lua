local function req(name)
	require("nieomylnieja.lsp." .. name)
end

req("complete")
req("config")
req("lint")
req("snippets")
req("diagnostics")
