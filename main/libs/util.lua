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
function util.logInChannel(guildId, payload)
	if not guildId or not payload then return end
	local logChannel = storage[guildId].logChannel
	if logChannel then
		local ch = client:getChannel(logChannel)
		if ch then
			ch:send(payload)
		end
	end
end
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
function util.computeDerived(e, guildId)
	local sp = tonumber(e.stockpile) or 0
	local cons = tonumber(e.consumption)
	local rcalls = tonumber(e.recipeCalls)
	local rmins = tonumber(e.recipeMins)
	if sp > 0 and rcalls and rmins and rcalls > 0 and rmins > 0 then
		e.time_h = ((sp / rcalls) * rmins) / 60
		e.msupp12 = (12 * 60 * rcalls) / rmins
		e.msupp24 = (24 * 60 * rcalls) / rmins
		e.msupp48 = (48 * 60 * rcalls) / rmins
	elseif sp > 0 and cons and cons > 0 then
		e.time_h = sp / cons
		e.msupp12 = cons * 12
		e.msupp24 = cons * 24
		e.msupp48 = cons * 48
	else
		e.time_h = e.time_h or 0
		e.msupp12 = e.msupp12 or 0
		e.msupp24 = e.msupp24 or 0
		e.msupp48 = e.msupp48 or 0
	end
	if not e.lastUpdate then e.lastUpdate = os.time() end
	e.unixTime = math.floor((e.lastUpdate + (e.time_h * 3600))) or os.time()
	--if e.time_h then e.time_h = math.floor(e.time_h*10)/10 end
	for _,k in ipairs({'msupp12','msupp24','msupp48'}) do if e[k] then e[k]=math.floor(e[k]*10)/10 end end
	if not e.isGenerator then
		local txt = "Computing MSupp site: '"..e.name.."' with "..util.formatShort(sp).." in stockpile, and "..cons.."MSupps at an hourly rate."
		util.logInChannel(guildId, txt)
		logger:log(3,txt)
	else
		local txt = "Computing Gen   Site: '"..e.name.."' with "..util.formatShort(sp).." in stockpile, with a call of "..rcalls.." every "..util.formatTime(rmins or -1).."."
		util.logInChannel(guildId, txt)
		logger:log(3,txt)
	end
end
function util.renderEmbed(e)
	local color_ok = discordia.Color.fromRGB(114,137,218).value
	local color_warn = discordia.Color.fromRGB(255,80,80).value
	local color = (tonumber(e.time_h or 0) < 12) and color_warn or color_ok
	local fields = {
		{ name = "Site/Gen", value = e.name or "N/A", inline = true },
		{ name = "Stockpile", value = tostring(e.stockpile or "N/A"), inline = true },
		{ name = "Consumption / Calls", value = tostring(e.consumption or e.recipeCalls or "N/A"), inline = true },
		{ name = "Time (h)", value = tostring(e.time_h or "N/A"), inline = true },
		{ name = "Recipe (calls/mins)", value = (e.recipeCalls and e.recipeMins) and (tostring(e.recipeCalls).." / "..tostring(e.recipeMins)) or "N/A", inline = true },
		{ name = "MSupp (12/24/48)", value = table.concat({tostring(e.msupp12 or "N/A"), tostring(e.msupp24 or "N/A"), tostring(e.msupp48 or "N/A")}, " / "), inline = false },
	}
	return { embed = { title = (e.isGenerator and "Generator — " or "MSupp — ")..(e.name or "Unknown"), fields = fields, color = color, timestamp = discordia.Date():toISO('T','Z') } }
end
function util.roundNumber(num, decimal)
	local dec = math.max(math.ceil(decimal or 2) - 1,0)
	num = math.floor(tonumber(num)*(10^dec))/(10^dec)
	return num
end
function util.buildSummaryEmbed(guildId)
	local msupps = {}
	local gens = {}
	local lowestM = nil -- storing like { time = num, entry = site } yadda yadda
	local lowestG = nil
	local totals = {m = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}, g = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}}
	for _,e in pairs(storage[guildId].upkeepEntries) do
		local stockpile = tonumber(e.stockpile) or 0
		local ms12 = tonumber(e.msupp12) or 0
		local ms24 = tonumber(e.msupp24) or 0
		local ms48 = tonumber(e.msupp48) or 0
		local time_h = math.floor(tonumber(e.time_h)*10)/10
		if e.isGenerator then 
			table.insert(gens, e)
			totals.g.stockpile = totals.g.stockpile + stockpile
			totals.g.msupp12 = totals.g.msupp12 + ms12
			totals.g.msupp24 = totals.g.msupp24 + ms24
			totals.g.msupp48 = totals.g.msupp48 + ms48
			if not lowestG or time_h < lowestG.time then
				lowestG = { time = time_h, entry = e }
			elseif not lowestG then
				lowestG = { time = time_h, entry = e }
			end
		else
			table.insert(msupps, e)
			totals.m.stockpile = totals.m.stockpile + stockpile
			totals.m.msupp12 = totals.m.msupp12 + ms12
			totals.m.msupp24 = totals.m.msupp24 + ms24
			totals.m.msupp48 = totals.m.msupp48 + ms48
			if not lowestM or time_h < lowestM.time then
				lowestM = { time = time_h, entry = e }
			elseif not lowestM then
				lowestM = { time = time_h, entry = e }
			end
		end
		if not e.lastUpdate then e.lastUpdate = os.time() end
	end
	local function name_cmp(a,b)
		local na = (a.name or ""):lower()
		local nb = (b.name or ""):lower()
		return na < nb
	end
	table.sort(gens, name_cmp)
	table.sort(msupps, name_cmp)
	local fields = {}
	--==[ MSupps Spreadsheet ]==-- 
	if #msupps > 0 then
		table.insert(fields, { name = "Totals (Stockpile | MSupp [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
			util.formatShort(totals.m.stockpile), util.formatShort(totals.m.msupp12), util.formatShort(totals.m.msupp24), util.formatShort(totals.m.msupp48)), inline = false })

		local lowestUnixTimeM = lowestM.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(msupps) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "!") or "+"
			table.insert(lines, string.format("%s %s, %s | >%sh |%sm/hr| %s, %s, %s", 
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(util.roundNumber(e.time_h) or "N/A"), e.consumption, 
					util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(msupps) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "<:MaintenanceSuppliesIcon:1501480687251750952> MSupp Sites",		value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Update Times",		value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestM.entry.name.." has >"..tostring(lowestM.time).."h, will run out ~<t:"..lowestUnixTimeM..":R>"), inline = false })
	end
	
	--==[ Generators Spreadsheet ]==--
	if #gens > 0 then
		table.insert(fields, { name = "Totals (Stockpile | Fuel [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
			util.formatShort(totals.g.stockpile), util.formatShort(totals.g.msupp12), util.formatShort(totals.g.msupp24), util.formatShort(totals.g.msupp48)), inline = false })
		local lowestUnixTimeG = lowestG.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(gens) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "! ") or "+ "
			table.insert(lines, string.format("%s %s, %s | >%sh |%sx%sm| %s, %s, %s",
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(util.roundNumber(e.time_h) or "N/A"),
					tostring(e.recipeCalls or "N/A"), util.formatTime(e.recipeMins or -1),
						util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(gens) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "<:Orders:1501481297544220673> Generators",			value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Lowest Gen Site",	value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestG.entry.name.." has >"..tostring(lowestG.time).."h, will run out ~<t:"..lowestUnixTimeG..":R>"), inline = false })
	end
	if #fields <= 0 then
		table.insert(fields, { name = "No data", value = "No data found. Is this a mistake?", inline = false })
	end

	return {
		embed = {
			title = "<:Orders:1501481297544220673> Logistics Summary",
			description = "Summary of MSupps and Generators\n-# Use either; `!create` `!creategen` or `!update` to get more info on how to write to the logi-summary",
			fields = fields,
			color = discordia.Color.fromRGB(114,137,218).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.updateSummaryMessage(channel)
	local payload = util.buildSummaryEmbed(channel.guild.id)
	local saved = storage[channel.guild.id].savedSummary or {}
	if saved.messageId and saved.channelId then
		local ok, err = pcall(function()
			local ch = client:getChannel(saved.channelId)
			if ch then
				local msg = ch:getMessage(saved.messageId)
				if msg and msg.author == client.user then
					msg:setContent(payload.content or "")
					msg:setEmbed(payload.embed)
					return true
				end
			end
			return false
		end)
		if ok then saveData(); return end
	end
	local target = channel
	if not target then
		if saved.channelId then target = client:getChannel(saved.channelId) end
	end
	if not target then return end
	local sent = target:send(payload)
	if sent then
		storage[channel.guild.id].savedSummary = { channelId = target.id, messageId = sent.id }
		saveData()
	end
end
function util.buildGoalEmbed(guildObj)
	local goals = storage[guildObj.id].goals
	local fields = {}
	local lines = {}
	for key, g in pairs(goals) do
		local name,value,goal = g.name,g.value,g.goal
		local per = (math.floor(((g.value/g.goal) * 100) * 100 + 0.5) / 100)
		local txt = (string.format("%s - %s / %s (%s",name or "ERR",value or "-1",goal or "-1",per or "-1").."%)")
		table.insert(lines, txt)
		local barWidth = #txt       -- length you want the bar to be (same as previous txt)
		local bar = ""
		local progress = 0
		if g.goal and g.goal ~= 0 then
			progress = math.max(0, math.min(1, (g.value or 0) / g.goal))
		end

		local filled = math.floor(progress * barWidth)
		local partial = (progress * barWidth) - filled

		for i = 1, barWidth do
			if i <= filled then
				bar = bar .. "█"
			elseif i == filled + 1 and partial > 0 then
				-- optional single-character partial using a lighter block for smoother look
				bar = bar .. "▌"
			else
				bar = bar .. "▒"
			end
		end
		table.insert(lines, bar)
	end
	table.insert(fields, { name = "Goals",	value = ("```yml\n"..table.concat(lines, "\n").."\n```"), inline = false })
	return {
		embed = {
			title = "<:Orders:1501481297544220673> Current Server Goals",
			description = "Goal summary for "..(guildObj.name).."\n-# You can add to these! Do `!goal` for more info",
			fields = fields,
			color = discordia.Color.fromRGB(94, 180, 121).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.updateGoalEmbed(channelObj)
	-- todo
end
util.timers = {}
util.stockpileAlerts = {}
function util.makeTimer(guildId,name,time)
	
end
function util.buildStockpileEmbed(guildObj, data)
	return {
		embed = {
			title = ("<:Orders:1501481297544220673> "..data.name.." | "..data.loc),
			description = "Stockpile code: `"..data.code.."` expires in "..util.unixTimestamp(data.expireTime),
			fields = {},
			color = discordia.Color.fromRGB(94, 180, 121).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.updateStockpileEmbed(guildId, data)
	if not storage[guildId].stockpileChannel then logger:log(2,"Tried to update a stockpile without a Stockpile Channel Cached") return end
	local guild = client:getGuild(guildId)
	local payload = util.buildStockpileEmbed(guild,data)
	if guild then
		local ch = guild:getChannel(storage[guildId].stockpileChannel.channelId)
		if ch then
			if data.messageId then
				local msg = ch:getMessage(data.messageId)
				if msg and msg.author == client.user then
					msg:setContent(payload.content or "")
					msg:setEmbed(payload.embed)
					data.messageId = msg.id
					storage[guildId].stockpiles[data.name:lower()] = data
					saveData()
					return true
				else
					local sent = ch:send(payload)
					data.messageId = sent.id
					storage[guildId].stockpiles[data.name:lower()] = data
					saveData()
					return (sent and true or false)
				end
			else
				local sent = ch:send(payload)
				data.messageId = sent.id
				storage[guildId].stockpiles[data.name:lower()] = data
				saveData()
				return (sent and true or false)
			end
		end
	end
end
function util.buildAPIEmbed()
	local warapi = util.grabWarAPI()
	local fields = {}
	table.insert(fields, {name = "Time:", value = "Started: <t:"..(math.ceil(warapi.conquestStartTime / 1000))..":R>"..(warapi.conquestEndTime and (", Ended: <t:"..(math.ceil(warapi.conquestEndTime / 1000))..":R>") or ""), inline = false})
	if warapi.resistanceStartTime then
		table.insert(fields, {name = "Resistance:", value = "Started: <t:"..(math.ceil(warapi.resistanceStartTime / 1000))..":R>"..(warapi.scheduledConquestEndTime and (", Ended: <t:"..(math.ceil(warapi.scheduledConquestEndTime / 1000))..":R>") or ""), inline = false})
	end
	if warapi.winner ~= "NONE" then
		table.insert(fields, {name = "Winner:", value = "**"..warapi.winner.."**", inline = false})
	end
	return {
		embed = {
			title = ("<:Orders:1501481297544220673> War-"..(warapi.warNumber or 0).." data <:shared:1501481298672484412>"),
			description = "Wartime data\n-# Do `!warapi` to update this",
			fields = fields,
			color = discordia.Color.fromRGB(94, 180, 121).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.updateAPIEmbed(channelObj)
	local payload = util.buildAPIEmbed()
	local saved = storage[channelObj.guild.id].savedAPI or {}
	if saved.messageId and saved.channelId then
		local ok, err = pcall(function()
			local ch = client:getChannel(saved.channelId)
			if ch then
				local msg = ch:getMessage(saved.messageId)
				if msg and msg.author == client.user then
					msg:setContent(payload.content or "")
					msg:setEmbed(payload.embed)
					return true
				end
			end
			return false
		end)
		if ok then saveData(); return end
	end
	local target = channelObj
	if not target then
		if saved.channelId then target = client:getChannel(saved.channelId) end
	end
	if not target then return end
	local sent = target:send(payload)
	if sent then
		storage[channelObj.guild.id].savedAPI = { channelId = target.id, messageId = sent.id }
		saveData()
	end
end
util.APICall = {
	cooldowns = { war = 30, map = 60 },
	cache = {
		war		= { ts = 0, data = nil, fallback = nil },
		maps	= { ts = {}, data = {}, fallback = {} }
	}
}
local function http_get(url)
	logger:log(3,"Grabbing http data: '"..url.."'")
	local res, body = http.request("GET", url)
	if not res then return nil, "HTTP request failed" end
	if res.code ~= 200 then return nil, ("HTTP %d"):format(res.code) end
	local ok, parsed = pcall(json.decode, body)
	if not ok then return nil, "JSON decode error: "..tostring(parsed) end
	return parsed
end
local function cached_fetch(key, url, cooldown, cache_table, forced, fallback)
	logger:log(3,"Returning cached fetch: '"..tostring(key).."', '"..tostring(url).."'")
	forced = forced == true
	local entry_ts = cache_table.ts[key] or 0
	local age = os.time() - entry_ts
	if not forced and cache_table.data[key] and age < cooldown then
		return cache_table.data[key]
	end
	local ok, res = pcall(http_get, url)
	if ok and res then
		cache_table.ts[key] = os.time()
		cache_table.data[key] = res
		return res
	end
	return cache_table.data[key] or fallback or nil
end
function util.grabWarAPI(opts)
	opts = opts or {}
	return cached_fetch(
		"war",
		"https://war-service-live.foxholeservices.com/api/worldconquest/war",
		util.APICall.cooldowns.war,
		util.APICall.cache.war and { ts = { war = util.APICall.cache.war.ts }, data = { war = util.APICall.cache.war.data } } or { ts = {}, data = {} },
		opts.force,
		opts.fallback or util.APICall.cache.war.fallback
	)
end
local map_endpoints = {
	list = "https://war-service-live.foxholeservices.com/api/worldconquest/maps",
	report = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/report",
	static = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/static",
	dynamic = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/dynamic"
}
function util.grabWarMapAPI(mapIdOrName, mapType, opts)
	opts = opts or {}
	if mapType == "list" then
		return cached_fetch("maplist", map_endpoints.list, util.APICall.cooldowns.map, util.APICall.cache.maps and { ts = util.APICall.cache.maps.ts, data = util.APICall.cache.maps.data } or { ts = {}, data = {} }, opts.force, opts.fallback or util.APICall.cache.maps.fallback)
	end
	local id = tostring(mapIdOrName or "unknown")
	local url = map_endpoints[mapType]:format(id)
	return cached_fetch(id..":"..mapType, url, util.APICall.cooldowns.map, util.APICall.cache.maps and { ts = util.APICall.cache.maps.ts, data = util.APICall.cache.maps.data } or { ts = {}, data = {} }, opts.force, opts.fallback or util.APICall.cache.maps.fallback)
end
util.todelete = {}
function util.addToDelete(message, timeToDelete)
	local tim = (timeToDelete or 7.0) + os.time()
	local data = {[1] = message, [2] = tim}
	table.insert(util.todelete,data)
	logger:log(3, 'Added message to delete table in '..(timeToDelete or 7.0)..'s')
end

return util