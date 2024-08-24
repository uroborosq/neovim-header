local M = {}

function M.replace_vars(str, vars, previous_vars)
	local count = 1
	return (
		str:gsub("({([^}]+)})", function(whole, i)
			count = count + 1
			if type(vars[i]) == "string" then
				return tostring(vars[i])
			elseif type(vars[i]) == "function" then
				return vars[i](previous_vars[count])
			end
			return whole
		end)
	)
end

return M
