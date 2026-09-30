--[[
	Format (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.Format
	Number/time formatting for UI.
]]
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.Short(n: number): string
	local negative = n < 0
	n = math.abs(n)
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(n))
	else
		text = string.format(n >= 100 and "%.0f%s" or "%.1f%s", n, SUFFIXES[index])
	end
	return (negative and "-" or "") .. text
end

function Format.Commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Percent(x: number): string
	return string.format("%.1f%%", x * 100)
end

return Format
