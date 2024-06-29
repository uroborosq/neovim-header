local M = {}

function M.replace_vars(str, vars)
	return (str:gsub("({([^}]+)})", function(whole, i)
		return vars[i] or whole
	end))
end

return M
