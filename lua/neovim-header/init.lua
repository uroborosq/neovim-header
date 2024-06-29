local plugin = require("neovim-header.header")
local config = require("neovim-header.config")

local M = {}

---@param opts?
function M.setup(opts)
	config.setup(opts)

	vim.api.nvim_create_user_command("UQAddHeader", function(opts)
		local buf = vim.api.nvim_get_current_buf()

		M.add(buf, config.get())
	end)
	vim.api.nvim_create_user_command("UQUpdateHeader", function(opts)
		local buf = vim.api.nvim_get_current_buf()
		M.add(buf, config.get())
	end)
end

--- Add copyright header to file
function M.add(buf, opts)
	plugin.add(buf, opts)
end

--- Add new or update existing header in file
function M.update(buf, opts)
	plugin.update(buf, opts)
end
