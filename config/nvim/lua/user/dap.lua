local dap = require("dap")
local dapui = require("dapui")

dapui.setup({
  controls = {
    element = "scopes",
  },
  expand_lines = false,
  layouts = { {
    elements = { {
      id = "repl",
      size = 0.25
    }, {
      id = "breakpoints",
      size = 0.25
    }, {
      id = "stacks",
      size = 0.25
    }, {
      id = "watches",
      size = 0.25
    } },
    position = "left",
    size = 40
  }, {
    elements = { {
      id = "scopes",
      size = 1
    } },
    position = "bottom",
    size = 20
  } },
})

vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "Debug", linehl = "", numhl = "" })

dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open({}) end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close({}) end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close({}) end

local dap_go = require("dap-go")
local dap_python = require("dap-python")

dap_go.setup({
  delve = {
    build_flags = "-tags=integration_test,e2e_test,unit_test",
  }
})
dap_python.setup()

---@param config {args?:string[]|fun():string[]?}
local function dap_get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.input("Run with args: ", table.concat(args, " "))
    return vim.split(vim.fn.expand(new_args), " ")
  end
  return config
end

require("which-key").add({
    { "<leader>d", group = "Debug" },
    { "<leader>db", function() dap.toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>dB", function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
    { "<leader>dc", function() dap.continue() end, desc = "Continue" },
    { "<leader>da", function() dap.continue({ before = dap_get_args }) end, desc = "Run with Args" },
    { "<leader>dm", function()
      local ft = vim.bo.filetype
      if ft == "go" then
        dap_go.debug_test()
      elseif ft == "python" then
        dap_python.test_method()
      else
        vim.notify("unsupported DAP for running test", vim.log.levels.ERROR)
      end
    end, desc = "Debug test" },
    { "<leader>dC", function() dap.run_to_cursor() end, desc = "Run to Cursor" },
    { "<leader>dg", function() dap.goto_() end, desc = "Go to line (no execute)" },
    { "<leader>di", function() dap.step_into() end, desc = "Step Into" },
    { "<leader>dj", function() dap.down() end, desc = "Down" },
    { "<leader>dk", function() dap.up() end, desc = "Up" },
    { "<leader>dl", function() dap.run_last() end, desc = "Run Last" },
    { "<leader>do", function() dap.step_out() end, desc = "Step Out" },
    { "<leader>dO", function() dap.step_over() end, desc = "Step Over" },
    { "<leader>dp", function() dap.pause() end, desc = "Pause" },
    { "<leader>dr", function() dap.repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>dt", function() dap.terminate() end, desc = "Terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    { "<leader>df", function() dap_python.test_class() end, desc = "Debug class" },
    { "<leader>ds", function() dap_python.debug_selection() end, desc = "Debug selection" },
})
