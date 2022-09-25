local M = {}

local commands = {
	{
		name = "BufferKill",
		fn = function()
			require("nieomylnieja.lib.functions").buf_kill("bd")
		end,
	},
	{
		name = "ReloadMyConfigs",
		fn = function()
			vim.cmd([[so $MYVIMRC]])
			vim.cmd([[:PackerCompile<CR>]])
			print("Confgis reloaded!")
		end,
	},
}

function M.load()
	local common_opts = { force = true }
	for _, cmd in pairs(commands) do
		local opts = vim.tbl_deep_extend("force", common_opts, cmd.opts or {})
		vim.api.nvim_create_user_command(cmd.name, cmd.fn, opts)
	end
end

return M
