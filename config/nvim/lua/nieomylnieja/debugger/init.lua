local dap = require("dap")
local dapui = require("dapui")
local daptext = require("nvim-dap-virtual-text")

local nnoremap = require("nieomylnieja.keymap").nnoremap

daptext.setup()
dapui.setup({
	layouts = {
		{
			elements = {
				"console",
			},
			size = 7,
			position = "bottom",
		},
		{
			elements = {
				-- Elements can be strings or table with id and size keys.
				{ id = "scopes", size = 0.25 },
				"watches",
			},
			size = 40,
			position = "left",
		},
	},
})

dap.listeners.after.event_initialized["dapui_config"] = function()
	dapui.open(1)
end
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close

require("nieomylnieja.debugger.go")

nnoremap("<Home>", function()
	dapui.toggle(1)
end)
nnoremap("<End>", function()
	dapui.toggle(2)
end)

nnoremap("<leader><leader>", dap.close)

nnoremap("<Up>", dap.continue)
nnoremap("<Down>", dap.step_over)
nnoremap("<Right>", dap.step_into)
nnoremap("<Left>", dap.step_out)
nnoremap("<Leader>b", dap.toggle_breakpoint)
nnoremap("<Leader>B", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end)
nnoremap("<leader>rc", dap.run_to_cursor)
