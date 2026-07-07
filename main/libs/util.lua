local util = {}

util.unix = {}
util.unix.shortTime		= "t"
util.unix.longTIme		= "T"
util.unix.shortDate		= "d"
util.unix.longDate		= "D"
util.unix.shortDateTime	= "f"
util.unix.longDateTime	= "F"
util.unix.relative		= "R"
function util:unixTimestamp(time,type) -- time takes in like os.time()
	local txt = ("<t:"..(time or os.time())..":"..(type or util.unix.relative)..">")
	return txt
end
function util:timeTill(tSeconds) return util:unixTimestamp((tSeconds or 0) + os.time(),util.unix.relative) or "" end
function util:parseNumber(s)
	if not s then return nil end
	s = s:lower():gsub(',','')
	local mult = 1
	if s:match('k$') then mult = 1000; s = s:sub(1, -2) end
	local num = tonumber(s)
	if not num then return nil end
	return num * mult
end
function util:parseTime(s)
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
function util:formatShort(n)
	if not n then return "N/A" end
	if type(n) ~= "number" then return tostring(n) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end
	return tostring(math.floor(n*10)/10)
end
function util:formatTime(n)
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
function util:grabmsg(guildId,channelId,msgId)
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
function util:roundNumber(num, decimal)
	local dec = math.max(math.ceil(decimal or 2) - 1,0)
	num = math.floor(tonumber(num)*(10^dec))/(10^dec)
	return num
end
function util:isfunction(var) return type(var) == 'function' end
function util:ismessage(var) return getmetatable(var) == 'class Message' end
--==| Taken from: [gist](https://gist.github.com/marcotrosi/163b9e890e012c6a460a) Owned by Marco Trosi, Last Updated May 25th, 2015.|==--
function util:printTable(t, f)
	local function printTableHelper(obj, cnt)
		local cnt = cnt or 0
		if type(obj) == "table" then
			io.write("\n", string.rep("\t", cnt), "{\n")
			cnt = cnt + 1
			for k,v in pairs(obj) do
				if type(k) == "string" then
					io.write(string.rep("\t",cnt), '["'..k..'"]', ' = ')
				end
				if type(k) == "number" then
					io.write(string.rep("\t",cnt), "["..k.."]", " = ")
				end
				printTableHelper(v, cnt)
				io.write(",\n")
			end
			cnt = cnt-1
			io.write(string.rep("\t", cnt), "}")
		elseif type(obj) == "string" then
			io.write(string.format("%q", obj))
		else
			io.write(tostring(obj))
		end 
	end

	if f == nil then
		printTableHelper(t)
	else
		io.output(f)
		io.write("return")
		printTableHelper(t)
		io.output(io.stdout)
	end
end
util.todelete = {}
function util:addToDelete(message, timeToDelete)
	local tim = (timeToDelete or 7.0) + os.time()
	local data = {[1] = message, [2] = tim}
	table.insert(util.todelete,data)
	-- logger:log(4, 'Added message to delete table in '..(timeToDelete or 7.0)..'s')
end
util.queue = {}
util.queuecool = {}
function util:addToQueue(guild, timeToQueue, callback, bForceToStart)
	if not guild then guild = "NOGUILD" end
	if type(guild) ~= "string" then guild = tostring(guild.id) end
	if not util.queue[guild] then util.queue[guild] = {} end
	local data = {[1] = callback, [2] = (timeToQueue or 0) + os.time()}
	if bForceToStart then
		table.insert(util.queue[guild],1,data)
	else
		table.insert(util.queue[guild],data)
	end
	-- logger:log(4, 'Added message to '..(bForceToStart and "quick " or "")..'queue table'..(((timeToQueue or 0) > 0) and (', set to go in '..(timeToQueue or 0)..'s') or ''))
end
function util:editMTData()
	if class and class.classes then
		local var = class.classes.Message
		if var then
			var.replyq = function(mt, content, time, callback)
				if self:isfunction(time) then callback = time time = nil end
				self:addToQueue(mt.guild, time, function() mt:reply(content) end)
			end
			var.replydel = function(mt, content, time)
				self:addToDelete(mt:reply(content),time)
			end
		else
			logger:log(1,"[UTIL INIT] - Message class not found")
		end
		local var = class.classes.GuildTextChannel
		if var then
			var.sendq = function(mt, payload, time, callback)
				if self:isfunction(time) then callback = time time = nil end
				self:addToQueue(mt.guild, time, function() local msg = mt:send(payload) if callback then callback(msg) end end)
			end
			var.senddel = function(mt, payload, time)
				self:addToDelete(mt:send(payload),time)
			end
			var.getcachedmessage = function(mt, id)
				local weakCache = mt.messages
				if weakCache then
					local msg = weakCache:find(function(obj) return obj.id == id end)
					if msg then return msg else return false end
				else
					return false
				end
			end
		else
			logger:log(1,"[UTIL INIT] - GuildTextChannel class not found")
		end
	else
		logger:log(1,"[UTIL INIT] - Classes not found?")
	end
end
function util:Init() self:editMTData() end
return util