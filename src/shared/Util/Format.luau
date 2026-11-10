--[[ Format.luau — números compactos (1.2K, 3.4M) e tempo (mm:ss) ]]
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.compact(n: number): string
	n = tonumber(n) or 0
	local negative = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local text
	if i == 1 then
		text = tostring(math.floor(n))
	elseif n >= 100 then
		text = string.format("%d%s", math.floor(n), SUFFIXES[i])
	else
		text = string.format("%.1f%s", math.floor(n * 10) / 10, SUFFIXES[i]):gsub("%.0", "")
	end
	return (negative and "-" or "") .. text
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
