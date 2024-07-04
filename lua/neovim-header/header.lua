local template = require("neovim-header.template")

local M = {}

---@param current_text string
---@param header string
---@param license neovim-header.License
---@return boolean
local function is_added(current_text, header, license)
	local check_exist = license.check_exist

	if license.check_exist == nil then
		check_exist = function(license_header)
			local empty_vars = {}
			for k, v in pairs(license.vars) do
				empty_vars[k] = ".*"
			end
			local any_vars_template = template.replace_vars(license.template, empty_vars)
			return current_text:match(any_vars_template) == current_text
		end
	elseif type(license.check_exist) == "string" then
		check_exist = function(license_header)
			return #{ current_text:gmatch(tostring(license.check_exist)) } > 0
		end
	end

	return check_exist(header)
end

local function contains(table, element)
	for _, value in ipairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

---comment
---@param buf integer
---@param config neovim-header.Config
function M.add(buf, config)
	local selected_license_name = config.select_license
	if type(config.select_license) == "function" then
		selected_license_name = config.select_license()
	end

	local license = config.licenses[selected_license_name]
	if not contains(license.filetypes, vim.bo.filetype) then
		return
	end

	local text = template.replace_vars(license.template, license.vars)
	local count = 0

	for _ in string.gmatch(text, "\n") do
		count = count + 1
	end

	local comment = vim.bo.commentstring
	local lines = vim.api.nvim_buf_get_lines(buf, 0, count + 1, false)
	local trimmed_lines = {}
	for _, line in ipairs(lines) do
		local trimmed = line:gsub("^" .. comment .. "*(.*)$", "%1")
		table.insert(trimmed_lines, trimmed)
	end
	local current_header = table.concat(trimmed_lines, "\n")

	if is_added(current_header, text, license) then
		return
	end
	local copyright_lines = {}

	for line in string.gmatch(text, "([^\n]+)") do
		local commented_line = comment:gsub("%%s", line)
		table.insert(copyright_lines, commented_line)
	end
	table.insert(copyright_lines, "")
	table.insert(copyright_lines, "")
	vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, copyright_lines)
end

function M.update(buf, config) end

return M
