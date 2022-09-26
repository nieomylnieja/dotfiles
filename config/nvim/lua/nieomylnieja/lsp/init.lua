local function req(name)
	require("nieomylnieja.lsp." .. name)
end

req("mason")
req("complete")
req("lsp")
req("snippets")
req("diagnostics")
req("null-ls")
req("signature")
