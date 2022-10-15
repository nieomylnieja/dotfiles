local function req(name)
	return require("nieomylnieja.lsp." .. name)
end

req("mason").setup()
req("complete")
req("lsp")
req("snippets")
req("diagnostics")
req("signature")
