local m = {}
m.module = {
	name	= "Foxhole API",
	desc	= "Contacts the official Foxhole api for current wartime data! If.. If only it gave better info.",
	version	= "1.0",
	hidehelp = true
}
m.commands = {}
m.commands["warapi"] = {
	cmd = "warapi",
	helper = "warapi -- makes a request to the official War API provided to give.. '_detailed_' info on the war.",
	func = function(message, args)
		message:delete()
		util.updateAPIEmbed(message.channel)
	end
}
local map_endpoints = {
	list = "https://war-service-live.foxholeservices.com/api/worldconquest/maps",
	report = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/report",
	static = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/static",
	dynamic = "https://war-service-live.foxholeservices.com/api/worldconquest/war/map/%s/dynamic"
}
m.util = {}
m.util.APICall = {
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
function m.util.buildAPIEmbed()
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
function m.util.updateAPIEmbed(channelObj)
	local payload = util.buildAPIEmbed()
	local saved = BOT_STORAGE[channelObj.guild.id].savedAPI or {}
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
		BOT_STORAGE[channelObj.guild.id].savedAPI = { channelId = target.id, messageId = sent.id }
		saveData()
	end
end
function m.util.grabWarAPI(opts)
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
function m.util.grabWarMapAPI(mapIdOrName, mapType, opts)
	opts = opts or {}
	if mapType == "list" then
		return cached_fetch("maplist", map_endpoints.list, util.APICall.cooldowns.map, util.APICall.cache.maps and { ts = util.APICall.cache.maps.ts, data = util.APICall.cache.maps.data } or { ts = {}, data = {} }, opts.force, opts.fallback or util.APICall.cache.maps.fallback)
	end
	local id = tostring(mapIdOrName or "unknown")
	local url = map_endpoints[mapType]:format(id)
	return cached_fetch(id..":"..mapType, url, util.APICall.cooldowns.map, util.APICall.cache.maps and { ts = util.APICall.cache.maps.ts, data = util.APICall.cache.maps.data } or { ts = {}, data = {} }, opts.force, opts.fallback or util.APICall.cache.maps.fallback)
end
return m