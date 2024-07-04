local plugin = require("neovim-header.header")
local config = require("neovim-header.config")

local M = {}

---@param opts neovim-header.Config?
function M.setup(opts)
	if not (opts == nil) then
		config.setup(opts)
	end

	vim.api.nvim_create_user_command("UQAddHeader", function()
		local buf = vim.api.nvim_get_current_buf()

		M.add(buf, config.get())
	end, {})
	vim.api.nvim_create_user_command("UQUpdateHeader", function()
		local buf = vim.api.nvim_get_current_buf()
		M.add(buf, config.get())
	end, {})

	if config.get().auto_insert then
		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function()
				local buf = vim.api.nvim_get_current_buf()
				M.add(buf, config.get())
			end,
		})
	end
end

--- Add copyright header to file. Do not replace existed one.
function M.add(buf, opts)
	plugin.add(buf, opts)
end

--- Add new or update existing header in file
function M.update(buf, opts)
	plugin.update(buf, opts)
end

return M
