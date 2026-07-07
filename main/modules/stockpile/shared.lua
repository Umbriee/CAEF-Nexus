local m = {}
m.module = {
	name = "Stockpile Alerts",
	desc = "Add stockpiles to your server, get updates when they might expire!",
	version = "1.0"
}

m.commands = {}
m.commands["stockpile"] = {
	cmd = "stockpile",
	abbreviation = "sp", -- May make it easier to type out.
	helper = "stockpile [name] [location] [code] <time remaining or 2d1h (accepts #d#h#m or hh:mm)> **OR** "..BOT_PREFIX.."stockpile [name] <time 2d1h> -- Can either register a stockpile, or update a pre-existing one. Fallsback to 2 days & 1 hour if the time field is missing.",
	fields = {"string","string/time","string","time"},
	func = function(message, args)
		local guild = message.guild
		if not guild then return end
		if not args[2] then message:replydel("Usage: !stockpile [name] [location or newly refreshed time] [code] <time remaining or 2d1h>") message:delete() return end
		local name, key = args[2],args[2]:lower()
		local arg3 = args[3]
		local arg4 = args[4]
		local arg5 = args[5]
		if not name or not arg3 then
			message:replydel("Usage: !stockpile [name] [location or newly refreshed time] [code] <time remaining or 2d1h>")
			message:delete(); return
		end
		if not BOT_STORAGE[guild.id].stockpileChannel then
			message:replydel("No stockpile channel found in server registry, add with `!addstockpilechannel`!")
			message:delete(); return
		end
		BOT_STORAGE[guild.id].stockpiles = BOT_STORAGE[guild.id].stockpiles or {}
		local existing = BOT_STORAGE[guild.id].stockpiles[key]
		local function isTimeFormat(s)
			if not s then return false end
			-- crude check: contains d or h or m or ":" or is all digits (e.g., "2h", "90m", "01:30")
			return string.find(s, "%d+[dhm]") or string.find(s, ":")
		end
		-- Decide whether arg3 is a time (refresh) or a location
		local location, code, expireTime
		if isTimeFormat(arg3) then
			-- quick update: name + time [ + code? + location? ]
			expireTime	= os.time() + util:parseTime(arg3)*3600
			code		= arg4 or (existing and existing.code)
			location	= arg5 or (existing and existing.loc)
		else
			-- normal create/update: name + location + code? + time?
			location	= arg3 or (existing and existing.loc)
			code		= arg4 or (existing and existing.code)
			expireTime	= (arg5 and (os.time() + util:parseTime(arg5)*3600) or nil)
		end
		-- default expireTime if none provided
		if not expireTime then expireTime = os.time() + 180000 end
		if not code then 
			message:replydel("No code field found, Usage: !stockpile [name] [location or newly refreshed time] [code] <time remaining or 2d1h>")
			message:delete(); return
		end
		if existing then
			local build = {
				name = existing.name or name,
				loc = location or existing.loc,
				code = code or existing.code,
				expireTime = expireTime or existing.expireTime
			}
			if util.stockpileAlerts[key] then util.stockpileAlerts[key] = nil end
			if existing.messageId then build.messageId = existing.messageId end
			util.updateStockpileEmbed(guild.id, build)
			message:replydel("Stockpile: [" .. build.name .. " @ "..build.loc.."] updated; expires " .. util:unixTimestamp(build.expireTime))
		else
			if not location then
			message:replydel("No existing stockpile named '"..name.."' found. Provide a location to create: Usage: !stockpile [name] [location] [code] <time>")
			message:delete(); return
			end
			util.updateStockpileEmbed(guild.id, { name = name, loc = location, code = code, expireTime = expireTime })
			message:replydel("Stockpile: [" .. name .. " - " .. location .. "] added to registry, will expire " .. util:unixTimestamp(expireTime))
		end
		message:delete()
	end
}
m.commands["rmvstockpile"] = {
	cmd = "rmvstockpile",
	abbreviation = "rsp",
	helper = "rmvstockpile [name] -- removes a stockpile from data.",
	fields = {"string"},
	func = function(message, args)
		local name, key = args[2],args[2]:lower()
		if not name then
			message:replydel("Usage: !rmvstockpile [name]")
			message:delete(); return
		end
		if BOT_STORAGE[message.guild.id].stockpiles[key] then
			if util.stockpileAlerts[key] then
				util.stockpileAlerts[key] = nil
			end
			if BOT_STORAGE[message.guild.id].stockpiles[key].messageId then
				local msg = util:grabmsg(message.guild.id,BOT_STORAGE[message.guild.id].stockpileChannel.channelId,BOT_STORAGE[message.guild.id].stockpiles[key].messageId)
				if msg then
					msg:delete()
				end
			end
			BOT_STORAGE[message.guild.id].stockpiles[key] = nil
			message:replydel("Deleting "..name.." from stockpile entry..")
		else
			message:replydel("Entry, "..name..", not found?")
		end
		saveData()
		message:delete()
	end
}
m.commands["addstockpilechannel"] = {
	cmd = "addstockpilechannel",
	helper = "addstockpilechannel -- marks the current channel a stockpile channel to add stockpiles & alerts",
	perms = {"manageChannels"},
	func = function(message, args)
		local guildId, channelId = message.guild.id, message.channel.id
		BOT_STORAGE[guildId].stockpileChannel = {guildId = guildId, channelId = channelId}
		saveData()
		message:replyq("Channel successfully marked as a stockpile channel for "..message.guild.name..". Use `!stockpile` to begin")
		message:delete()
	end
}
m.util = {}
m.util.stockpileAlerts = {}
function m.util.buildStockpileEmbed(guildObj, data)
	return {
		embed = {
			title = ("<:Orders:1501481297544220673> "..data.name.." | "..data.loc),
			description = "Stockpile code: `"..data.code.."` expires in "..util:unixTimestamp(data.expireTime),
			fields = {},
			color = discordia.Color.fromRGB(94, 180, 121).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function m.util.updateStockpileEmbed(guildId, data)
	if not BOT_STORAGE[guildId].stockpileChannel then logger:log(2,"Tried to update a stockpile without a Stockpile Channel Cached") return end
	local guild = client:getGuild(guildId)
	local payload = util.buildStockpileEmbed(guild,data)
	if guild then
		local ch = guild:getChannel(BOT_STORAGE[guildId].stockpileChannel.channelId)
		if ch then
			if data.messageId then
				local chan = ch
				util:addToQueue(guildId, nil, function()
					local msg = chan:getMessage(data.messageId)
					if msg and msg.author == client.user then
						msg:setContent(payload.content or "")
						msg:setEmbed(payload.embed)
						data.messageId = msg.id
						BOT_STORAGE[guildId].stockpiles[data.name:lower()] = data
						saveData()
						return true
					else
						local sent = chan:send(payload)
						data.messageId = sent.id
						BOT_STORAGE[guildId].stockpiles[data.name:lower()] = data
						saveData()
						return true
					end
				end)
			else
				ch:sendq(payload,function(sent)
					data.messageId = sent.id
					BOT_STORAGE[guildId].stockpiles[data.name:lower()] = data
					saveData()
				end)
				return true
			end
		end
	end
end
m.event = {}
m.event["min"] = function(now)
	local guildObj
	local channelObj
	local txt
	local ok, status = safeCall(function() 
		for key, data in pairs(BOT_STORAGE) do
			guildObj = client:getGuild(key)
			if guildObj then
				if data.stockpileChannel then
					channelObj = guildObj:getChannel(data.stockpileChannel.channelId)
					if channelObj then
						if data.stockpiles then
							local int = 0
							for key2, data2 in pairs(data.stockpiles) do
								int = int + 1
								if data2.expireTime then
									if (data2.expireTime - 18000) <= os.time() then
										if data2.expireTime <= os.time() then
											local alert = util.stockpileAlerts[key2]
											if not alert then
												util.stockpileAlerts[key2] = true
												txt = "`[⚠Alert]` - Stockpile, "..data2.name.." in "..data2.loc..", digitially expired.\n-# Use `!stockpile "..data2.name.." 2d1h` or whatever the time may be to refresh this.\n-# Or `!rmvstockpile "..data2.name.."` to delete it."
												logger:log(4,("["..guildObj.name.."] - "..txt))
												channelObj:senddel(txt,3600)
											end
										else
											local alert = util.stockpileAlerts[key2]
											if not alert then
												util.stockpileAlerts[key2] = os.time()
												txt = "`[⚠Alert]` - Stockpile, "..data2.name.." in "..data2.loc..", is about to expire. "..util:unixTimestamp(data2.expireTime).."\n-# Use `!stockpile "..data2.name.." 2d1h` or whatever the time may be to refresh this."
												logger:log(4,("["..guildObj.name.."] - "..txt))
												channelObj:senddel(txt,3600)
											else
												if type(alert) == "number" then
													if (os.time() - alert) >= 3600 then
														util.stockpileAlerts[key2] = os.time()
														txt = "`[⚠Reminder]` - Stockpile, "..data2.name.." in "..data2.loc..", still expiring soon. "..util:unixTimestamp(data2.expireTime).."\n-# Use `!stockpile "..data2.name.." 2d1h` to refresh."
														logger:log(4,("["..guildObj.name.."] - "..txt))
														channelObj:senddel(txt,3600)
													end
												else
													error("util.stockpileAlerts["..key2.."] is type "..type(alert).."! Did it expire and get refreshed?")
												end
											end
										end
									end
								end
							end
						end
					end
				end
			else logger:log(3,"Unknown guild found '%s'",tostring(key)) end
		end
	end)
	errorHandle({CH = (channelObj and channelObj.id or nil), GD = (guildObj and guildObj.id or nil)}, (txt and {{name = "Latest Message", value = txt}} or nil),ok, status)
end
return m