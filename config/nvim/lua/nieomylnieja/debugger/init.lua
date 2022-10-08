local dap = require "dap"
local dapui = require "dapui"
local daptext = require "nvim-dap-virtual-text"
local dap_go = require "nieomylnieja.debugger.go"

local nnoremap = require("nieomylnieja.keymap").nnoremap

dap_go.setup()
daptext.setup()
dapui.setup {
  -- layouts = {
  -- 	{
  -- 		elements = {
  -- 			"console",
  -- 		},
  -- 		size = 7,
  -- 		position = "bottom",
  -- 	},
  -- 	{
  -- 		elements = {
  -- 			-- Elements can be strings or table with id and size keys.
  -- 			{ id = "scopes", size = 0.25 },
  -- 			"watches",
  -- 		},
  -- 		size = 40,
  -- 		position = "left",
  -- 	},
  -- },
}

vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "⛔", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointRejected", { text = "🚫", texthl = "Debug", linehl = "", numhl = "" })

dap.listeners.after.event_initialized["dapui_config"] = dapui.open
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close

require "nieomylnieja.debugger.go"

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
  dap.set_breakpoint(vim.fn.input "Breakpoint condition: ")
end)
nnoremap("<leader>rc", dap.run_to_cursor)
nnoremap("<leader>td", function()
  local ft = vim.bo.filetype
  if ft == "go" then
    -- TODO: Maybe expose it through language specific config instead?
    require("dap-go").debug_test()
  else
    vim.notify "lool!"
  end
end)
