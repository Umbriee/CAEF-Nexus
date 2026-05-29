local util = {}

util.unix = {}
util.unix.shortTime		= "t"
util.unix.longTIme		= "T"
util.unix.shortDate		= "d"
util.unix.longDate		= "D"
util.unix.shortDateTime	= "f"
util.unix.longDateTime	= "F"
util.unix.relative		= "R"
function util.unixTimestamp(time,type) -- time takes in like os.time()
	local txt = ("<t:"..(time or os.time())..":"..(type or util.unix.relative)..">")
	return txt
end
function util.timeTill(tSeconds) return util.unixTimestamp((tSeconds or 0) + os.time(),util.unix.relative) or "" end
function util.parseNumber(s)
	if not s then return nil end
	s = s:lower():gsub(',','')
	local mult = 1
	if s:match('k$') then mult = 1000; s = s:sub(1, -2) end
	local num = tonumber(s)
	if not num then return nil end
	return num * mult
end
function util.parseTime(s)
	if not s then return nil end
	local str = tostring(s):gsub('%s+',''):lower()
	if str == '' then return nil end
	-- 1) HH:MM or H:MM (colon) -> hours as number
	local h, m = str:match('^(%d+):(%d+)$')
	if h and m then
		return tonumber(h) + tonumber(m) / 60
	end
	-- 2) Plain number (integer or decimal) -> treat as hours
	if tonumber(str) then
		return tonumber(str)
	end
	-- 3) Combined units like "2d1h30m", "90m", "2h", "2d1h"
	-- Supported units: d (day = 24h), h (hour), m (minute)
	local unit_values = { d = 24, h = 1, m = 1/60 }
	local total = 0
	local found = false
	for num, unit in str:gmatch('(%d+%.?%d*)([dhm])') do
		local n = tonumber(num)
		if n and unit_values[unit] then
			total = total + n * unit_values[unit]
			found = true
		else
			return false
		end
	end
	if found then return total end
	return false
end
function util.formatShort(n)
	if not n then return "N/A" end
	if type(n) ~= "number" then return tostring(n) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end
	return tostring(math.floor(n*10)/10)
end
function util.formatTime(n)
	if n == nil then return "N/A" end
	if type(n) ~= "number" then return tostring(n) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end

	local minutes = math.floor(n)
	local seconds = math.floor((n - minutes) * 60 + 0.5)
	if seconds >= 60 then
		minutes = minutes + 1
		seconds = seconds - 60
	end
	return string.format("%d:%02d", minutes, seconds)
end
function util.grabmsg(guildId,channelId,msgId)
	local guild = client:getGuild(guildId)
	local channel
	local msg
	if guild then
		channel = guild:getChannel(channelId)
		if channel then
			if msgId then
				msg = channel:getMessage(msgId)
			else
				msg = false
			end
		else
			channel = false
		end
	else
		guild = false
	end
	return msg, channel, guild
end
function util.roundNumber(num, decimal)
	local dec = math.max(math.ceil(decimal or 2) - 1,0)
	num = math.floor(tonumber(num)*(10^dec))/(10^dec)
	return num
end
util.todelete = {}
function util.addToDelete(message, timeToDelete)
	local tim = (timeToDelete or 7.0) + os.time()
	local data = {[1] = message, [2] = tim}
	table.insert(util.todelete,data)
	logger:log(3, 'Added message to delete table in '..(timeToDelete or 7.0)..'s')
end

return util