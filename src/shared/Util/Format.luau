--!strict
-- Number and time formatting for UI ("1.25M", "3:07").

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.23K", 15600000 -> "15.6M"
function Format.Abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		local text = if value == math.floor(value) then tostring(value) else string.format("%.1f", value)
		return (if negative then "-" else "") .. text
	end
	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / (1000 ^ tier)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	else
		if scaled >= 10 then
			text = string.format("%.1f", math.floor(scaled * 10) / 10)
		else
			text = string.format("%.2f", math.floor(scaled * 100) / 100)
		end
		-- Trim trailing zeros: "1.50K" -> "1.5K", "2.00M" -> "2M".
		text = string.gsub(text, "%.?0+$", "") :: string
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

function Format.Cash(value: number): string
	return "$" .. Format.Abbreviate(math.floor(value))
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- 1.5 -> "x1.5", 2 -> "x2"
function Format.Multiplier(value: number): string
	local rounded = math.floor(value * 100 + 0.5) / 100
	if rounded >= 1000 then
		return "x" .. Format.Abbreviate(rounded)
	end
	local text = string.format("%.2f", rounded)
	text = string.gsub(text, "%.?0+$", "") :: string
	return "x" .. text
end

-- 0.0123 -> "1.23%", 0.5 -> "50%"
function Format.Percent(fraction: number): string
	local percent = fraction * 100
	if percent <= 0 then
		return "0%"
	elseif percent >= 10 then
		return string.format("%d%%", math.floor(percent + 0.5))
	elseif percent >= 1 then
		return (string.gsub(string.format("%.1f", percent), "%.0$", "")) .. "%"
	end
	return (string.gsub(string.format("%.2f", percent), "%.?0+$", "")) .. "%"
end

return Format
