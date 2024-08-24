---@class neovim-header.Config.mod: neovim-header.Config
local M = {}

---@class neovim-header.License
---@field template string|fun():string
---@field filetypes string[]
---@field check_exist (string|fun(string):boolean)?
---@field vars table<string,(string|fun(string?):string)>

---@class neovim-header.Config
---@field auto_insert boolean
---@field auto_update boolean
---@field project_files_only boolean
---@field select_license (string | fun():string)?
---@field global_vars table<string,(string|fun():string)>
---@field licenses table<string, neovim-header.License>

---@type neovim-header.Config
local defaults = {
	auto_insert = false,
	auto_update = false,
	project_files_only = true,
	select_license = nil,
	global_vars = {},
	licenses = {},
}

M.config = defaults

---@param opts neovim-header.Config
function M.setup(opts)
	if opts then
		for k, v in pairs(opts) do
			M.config[k] = v
		end
	end
end

---@return neovim-header.Config
function M.get()
	return vim.deepcopy(M.config, true)
end

return M
