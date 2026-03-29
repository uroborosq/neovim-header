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

---@param config neovim-header.Config
---@return neovim-header.License|nil
local function resolve_license(config)
	local selected_license_name = config.select_license
	if type(config.select_license) == "function" then
		selected_license_name = config.select_license()
	end

	local license = config.licenses[selected_license_name]
	if license == nil then
		return nil
	end

	if not contains(license.filetypes, vim.bo.filetype) then
		return nil
	end

	return license
end

---@param license neovim-header.License
---@param current_header string
---@return integer[]
local function extract_previous_vars(license, current_header)
	local safe_template = escape_pattern(license.template)
	local empty_vars = {}
	for k, _ in pairs(license.vars) do
		empty_vars[k] = "(.*)"
	end
	local any_vars_template = template.replace_vars(safe_template, empty_vars)
	return { current_header:find(any_vars_template) }
end

---@param lines string[]
---@return string[]
local function comment_lines(lines)
	local lcs, rcs = cmt_utils.unwrap_cstr(get_comment_pattern())
	local commented_lines = {}
	for _, line in ipairs(lines) do
		local commented_line = cmt_utils.commenter(lcs, rcs, true, 0)(line)
		table.insert(commented_lines, commented_line)
	end

	table.insert(commented_lines, "")

	return commented_lines
end

---@param buf integer
---@param config neovim-header.Config
---@return boolean
local function should_skip_buffer(buf, config)
	return config.project_files_only and not starts_with(vim.api.nvim_buf_get_name(buf), vim.fn.getcwd())
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
---@param license neovim-header.License
---@return table
local function build_header_context(buf, license)
	local trimmed_lines = get_commented_header(buf)
	local current_header = table.concat(trimmed_lines, "\n")
	local previous_vars = extract_previous_vars(license, current_header)

	return {
		trimmed_lines = trimmed_lines,
		current_header = current_header,
		previous_vars = previous_vars,
	}
end

---@param license neovim-header.License
---@param previous_vars integer[]
---@param var_start integer
---@return string
local function render_header_text(license, previous_vars, var_start)
	return template.replace_vars(license.template, license.vars, slice(previous_vars, var_start))
end

---@param text string
---@return string[]
local function build_buffer_lines(text)
	return comment_lines(split(text, "\n"))
end

---@param buf integer
---@param start_row integer
---@param end_row integer
---@param lines string[]
local function apply_header(buf, start_row, end_row, lines)
	vim.api.nvim_buf_set_text(buf, start_row, 0, end_row, 0, lines)
	vim.lsp.codelens.refresh()
end

---@param buf integer
---@param config neovim-header.Config
function M.add(buf, config)
	-- do not change non-project files if configured.
	if should_skip_buffer(buf, config) then
		return
	end

	local license = resolve_license(config)
	if license == nil then
		return
	end

	local context = build_header_context(buf, license)
	local previous_vars = context.previous_vars
	local header_found = not (previous_vars[1] == nil)
	if
		(header_found and license.check_exist == nil)
		or (not license.check_exist == nil and is_added(context.current_header, license))
	then
		return
	end

	local text = render_header_text(license, previous_vars, 3)
	local copyright_lines = build_buffer_lines(text)

	apply_header(buf, 0, 0, copyright_lines)
end

---@param buf integer
---@param config neovim-header.Config
function M.update(buf, config)
	-- do not change non-project files if configured.
	if should_skip_buffer(buf, config) then
		return
	end

	local license = resolve_license(config)
	if license == nil then
		return
	end

	local context = build_header_context(buf, license)
	local previous_vars = context.previous_vars

	local text = render_header_text(license, previous_vars, 2)

	if text == context.current_header then
		return
	end

	local copyright_lines = build_buffer_lines(text)

	apply_header(buf, 0, #context.trimmed_lines, copyright_lines)
end

return M
