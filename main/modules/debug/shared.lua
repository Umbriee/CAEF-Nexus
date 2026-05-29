local m = {}
m.module = {
	name = "Debugging",
	desc = "Commands, utility functions, or otherwise to test the general features of the bot.",
	version = "1.0",
	hidehelp = true
}
m.commands = {}
m.commands["error"] = {
	cmd = "error",
	helper = "error <field> -- manually triggers an error for my own debugging purposes",
	perms = {"manageChannels"},
	func = function(message, args)
		message:delete()
		error("MANUALLY TRIGGERED ERROR '"..(args[2] or "NaN").."'")
	end
}
m.commands["addlogchannel"] = {
	cmd = "addlogchannel",
	helper = "addlogchannel -- registers the messaged channel to be a sort of 'botlog' that will be sent messages when things are updated or otherwise.",
	perms = {"manageChannels"},
	func = function(message, args)
		local guildId = message.guild.id
		BOT_STORAGE[guildId].logChannel = message.channel.id
		saveData()
		util.addToDelete(message:reply("Channel successfully marked as a log channel for "..message.guild.name.."."),10)
		message:delete()
	end
}
m.util = {}
function m.util.logInChannel(guildId, payload)
	if not guildId or not payload then return end
	local logChannel = BOT_STORAGE[guildId].logChannel
	if logChannel then
		local ch = client:getChannel(logChannel)
		if ch then
			ch:send(payload)
		end
	end
end
m.events = {}
m.events["min"] = function(now)
	local guildObj
	local channelObj
	local txt
	local ok, status = pcall(function() 
		for key, data in pairs(BOT_STORAGE) do
			guildObj = client:getGuild(key)
			if guildObj then
				if data.stockpileChannel then
					channelObj = guildObj:getChannel(data.stockpileChannel.channelId)
					if channelObj then
						if data.stockpiles then
							for key2, data2 in pairs(data.stockpiles) do
								if data2.expireTime then
									if (data2.expireTime - 18000) <= os.time() then
										if data2.expireTime <= os.time() then
											local alert = util.stockpileAlerts[key2]
											if not alert then
												util.stockpileAlerts[key2] = true
												txt = "`[⚠Alert]` - Stockpile, "..data2.name.." in "..data2.loc..", digitially expired.\n-# Use `!stockpile "..data2.name.." 2d1h` or whatever the time may be to refresh this.\n-# Or `!rmvstockpile "..data2.name.."` to delete it."
												logger:log(4,("["..guildObj.name.."] - "..txt))
												util.addToDelete(channelObj:send(txt),3600)
											end
										else
											local alert = util.stockpileAlerts[key2]
											if not alert then
												util.stockpileAlerts[key2] = os.time()
												txt = "`[⚠Alert]` - Stockpile, "..data2.name.." in "..data2.loc..", is about to expire. "..util.unixTimestamp(data2.expireTime).."\n-# Use `!stockpile "..data2.name.." 2d1h` or whatever the time may be to refresh this."
												logger:log(4,("["..guildObj.name.."] - "..txt))
												util.addToDelete(channelObj:send(txt),3600)
											else
												if type(alert) == "number" then
													if (os.time() - alert) >= 3600 then
														util.stockpileAlerts[key2] = os.time()
														txt = "`[⚠Reminder]` - Stockpile, "..data2.name.." in "..data2.loc..", still expiring soon. "..util.unixTimestamp(data2.expireTime).."\n-# Use `!stockpile "..data2.name.." 2d1h` to refresh."
														logger:log(4,("["..guildObj.name.."] - "..txt))
														util.addToDelete(channelObj:send(txt),3600)
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
			else
				logger:log(3,"Unknown guild found '%s'",tostring(key))
			end
		end
	end)
	errorHandle({CH = (channelObj and channelObj.id or nil), GD = (guildObj and guildObj.id or nil)}, (txt and {{name = "Latest Message", value = txt}} or nil),ok, status)
end
return m