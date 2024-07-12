local template = require("neovim-header.template")

local M = {}
local function trim(s)
	if s == nil then
		return ""
	end
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function split(s, delimiter)
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find(s, delimiter, from)
	while delim_from do
		table.insert(result, string.sub(s, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(s, delimiter, from)
	end
	table.insert(result, string.sub(s, from))
	return result
end

local function escape_pattern(text)
	local matches = {
		["%"] = "%%",
		["."] = "%.",
		["+"] = "%+",
		["-"] = "%-",
		["*"] = "%*",
		["?"] = "%?",
		["^"] = "%^",
		["$"] = "%$",
		["["] = "%[",
		["]"] = "%]",
		["("] = "%(",
		[")"] = "%)",
		-- ["{"] = "%{",
		-- ["}"] = "%}",
	}
	return (text:gsub(".", matches))
end

---@param current_text string
---@param header string
---@param license neovim-header.License
---@return boolean
local function is_added(current_text, header, license)
	local check_exist = license.check_exist

	if license.check_exist == nil then
		check_exist = function(license_header)
			local safe_template = escape_pattern(license.template)
			local empty_vars = {}
			for k, v in pairs(license.vars) do
				empty_vars[k] = ".*"
			end
			local any_vars_template = template.replace_vars(safe_template, empty_vars)
			local matched_text = current_text:match(any_vars_template)

			return matched_text == current_text
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
	local count = 1

	for _ in string.gmatch(text, "\n") do
		count = count + 1
	end

	local trimmed_comment = vim.bo.cms:gsub("%s", "")
	local lines = vim.api.nvim_buf_get_lines(buf, 0, count, false)
	local trimmed_lines = {}
	for _, line in ipairs(lines) do
		local trimmed = trim(line:gsub("^" .. trimmed_comment .. "*(.*)$", "%1"))
		table.insert(trimmed_lines, trimmed)
	end
	local current_header = table.concat(trimmed_lines, "\n")

	if is_added(current_header, text, license) then
		return
	end
	local copyright_lines = {}
	local uncommented_lines = split(text, "\n")
	for k, line in ipairs(uncommented_lines) do
		local commented_line = vim.bo.cms:gsub("%%s", line)
		table.insert(copyright_lines, commented_line)
	end
	table.insert(copyright_lines, "")
	table.insert(copyright_lines, "")
	vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, copyright_lines)
	vim.lsp.codelens.refresh()
end

function M.update(buf, config) end

return M
