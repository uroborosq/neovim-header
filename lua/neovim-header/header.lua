local template = require("neovim-header.template")

local M = {}

---@param current_text string
---@param header string
---@param license neovim-header.License
---@return boolean
local function is_already_added(current_text, header, license)
	local check_exist = license.check_exist

	if license.check_exist == nil then
		check_exist = function(license_header)
			return #{ current_text:gmatch("$Copyright") } > 0
		end
	elseif type(license.check_exist) == "string" then
		check_exist = function(license_header)
			return #{ current_text:gmatch(tostring(license.check_exist)) } > 0
		end
	end

	return check_exist(header)
end
---comment
---@param buf integer
---@param config neovim-header.Config
function M.add(buf, config)
	vim.validate({
		buf = { buf, "number" },
	})

	local selected_license_name = config.select_license
	if type(config.select_license) == "function" then
		selected_license_name = config.select_license()
	end

	local license = config.licenses[selected_license_name]

	local text = template.replace_vars(license.template, license.vars)

	local count = #{ text:gmatch("\n") }
	local current_header = vim.api.nvim_buf_get_lines(buf, 0, count, false)

	assert(is_already_added(current_header, text, license), "header is already added")

	vim.fn.appendbufline(buf, count, text)
end

function M.update(buf, config) end

return M
