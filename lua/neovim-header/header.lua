local template = require("neovim-header.template")
local cmt_utils = require("Comment.utils")
local cmt_ft = require("Comment.ft")

local M = {}

local function starts_with(text, prefix)
	return text:find(prefix, 1, true) == 1
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

local function slice(tbl, first, last, step)
	local sliced = {}

	for i = first or 1, last or #tbl, step or 1 do
		sliced[#sliced + 1] = tbl[i]
	end

	return sliced
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

---@return string
local function get_comment_pattern()
	local comment = cmt_ft.get(vim.bo.filetype, cmt_utils.ctype.linewise)
	return tostring(comment)
end

---@param current_text string
---@param check_exist string|fun(string):boolean
---@return boolean
local function is_added(current_text, check_exist)
	if type(check_exist) == "string" then
		check_exist = function(_)
			return #{ current_text:gmatch(tostring(check_exist)) } > 0
		end
	end

	return check_exist(current_text)
end

local function contains(table, element)
	for _, value in ipairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

---@param buf integer
---@return string[]
local function get_commented_header(buf)
	local commented_lines = {}
	local line_counter = 0
	local max = vim.api.nvim_buf_line_count(buf)

	while line_counter < max do
		local new_line = vim.api.nvim_buf_get_lines(buf, line_counter, line_counter + 1, true)[1]
		local lcs, rcs = cmt_utils.unwrap_cstr(get_comment_pattern())
		if cmt_utils.is_commented(lcs, rcs, true)(new_line) then
			local trimmed = cmt_utils.uncommenter(lcs, rcs, true)(new_line)
			table.insert(commented_lines, trimmed)
		else
			break
		end

		line_counter = line_counter + 1
	end

	return commented_lines
end

---@param buf integer
---@param config neovim-header.Config
function M.add(buf, config)
	local selected_license_name = config.select_license
	if type(config.select_license) == "function" then
		selected_license_name = config.select_license()
	end

	-- do not change non-project files if configured.
	if config.project_files_only and not starts_with(vim.api.nvim_buf_get_name(buf), vim.fn.getcwd()) then
		return
	end

	local license = config.licenses[selected_license_name]
	if not contains(license.filetypes, vim.bo.filetype) then
		return
	end

	local trimmed_lines = get_commented_header(buf)
	local current_header = table.concat(trimmed_lines, "\n")

	local safe_template = escape_pattern(license.template)
	local empty_vars = {}
	for k, _ in pairs(license.vars) do
		empty_vars[k] = "(.*)"
	end
	local any_vars_template = template.replace_vars(safe_template, empty_vars)
	local previous_vars = { current_header:find(any_vars_template) }
	local header_found = not (previous_vars[1] == nil)
	if
		(header_found and license.check_exist == nil)
		or (not license.check_exist == nil and is_added(current_header, license))
	then
		return
	end

	local text = template.replace_vars(license.template, license.vars, slice(previous_vars, 3))
	local copyright_lines = {}
	local uncommented_lines = split(text, "\n")
	for _, line in ipairs(uncommented_lines) do
		local lcs, rcs = cmt_utils.unwrap_cstr(get_comment_pattern())
		local commented_line = cmt_utils.commenter(lcs, rcs, true, 0)(line)
		table.insert(copyright_lines, commented_line)
	end
	table.insert(copyright_lines, "")
	table.insert(copyright_lines, "")

	vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, copyright_lines)
	vim.lsp.codelens.refresh()
end

---@param buf integer
---@param config neovim-header.Config
function M.update(buf, config)
	local selected_license_name = config.select_license
	if type(config.select_license) == "function" then
		selected_license_name = config.select_license()
	end

	-- do not change non-project files if configured.
	if config.project_files_only and not starts_with(vim.api.nvim_buf_get_name(buf), vim.fn.getcwd()) then
		return
	end

	local license = config.licenses[selected_license_name]
	if not contains(license.filetypes, vim.bo.filetype) then
		return
	end

	local trimmed_lines = get_commented_header(buf)
	local current_header = table.concat(trimmed_lines, "\n")

	local safe_template = escape_pattern(license.template)
	local empty_vars = {}
	for k, _ in pairs(license.vars) do
		empty_vars[k] = "(.*)"
	end
	local any_vars_template = template.replace_vars(safe_template, empty_vars)
	local previous_vars = { current_header:find(any_vars_template) }

	local text = template.replace_vars(license.template, license.vars, slice(previous_vars, 2))

	if text == current_header then
		return
	end

	local license_lines = split(text, "\n")

	local lcs, rcs = cmt_utils.unwrap_cstr(get_comment_pattern())
	local copyright_lines = {}
	for _, line in ipairs(license_lines) do
		local commented_line = cmt_utils.commenter(lcs, rcs, true, 0)(line)
		table.insert(copyright_lines, commented_line)
	end

	table.insert(copyright_lines, "")

	vim.api.nvim_buf_set_text(buf, 0, 0, #trimmed_lines, 0, copyright_lines)
	vim.lsp.codelens.refresh()
end

return M
