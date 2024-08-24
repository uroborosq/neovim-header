local M = {}

---@param previous string?
---@return string
function M.years_field(previous)
	local current_year = tostring(os.date("%Y"))
	if previous == nil then
		return current_year
	end

	local idx, _, start_year = previous:find("(%d+)-(%d+)")

	if idx == nil then
		if previous == current_year then
			return current_year
		end
		start_year = previous
	end

	return start_year .. "-" .. current_year
end

return M
