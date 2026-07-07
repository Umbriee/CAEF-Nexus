local commands = {}
commands["create"] = {
	cmd = "create",
	helper = "create Name [stockpile] [consumption]",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2] or ("site_"..tostring(os.time()))
		local sp = util:parseNumber(args[3])
		local cons = util:parseNumber(args[4])
		if not sp or not cons then message:delete() message:replydel("Invalid, or too few, fields: !create Name [stockpile(num)] [consumption(num)]") return end
		local e = { name = name, stockpile = sp or 0, consumption = cons or nil, isGenerator = false, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		BOT_STORAGE[message.guild.id].upkeepEntries = BOT_STORAGE[message.guild.id].upkeepEntries or {}
		BOT_STORAGE[message.guild.id].upkeepEntries[e.nonce] = e
		saveData()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commands["creategen"] = {
	cmd = "creategen",
	helper = "creategen [Name] [stockpile] <calls> <M:SS or minutes>",
	fields = {"string","number","number","time"},
	func = function(message, args)
		local name = args[2]
		if not name or not args[3] then message:replydel("Invalid, or too few, fields: !creategen [Name] [stockpile] <calls> <M:SS or minutes>",10); message:delete(); return end
		local idx = 3
		local spCandidate = util:parseNumber(args[idx])
		local sp, calls, rtime
		if spCandidate then sp = spCandidate; idx = idx + 1 end
		calls = tonumber(args[idx])
		rtime = util:parseTime(args[idx+1])
		if not (calls and rtime) then message:replydel("Invalid arguments? Example: !creategen GenN 2.0k 30 1:30",10); message:delete(); return end
		local e = { name = name, stockpile = sp or 0, recipeCalls = calls, recipeMins = rtime, consumption = nil, isGenerator = true, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
		BOT_STORAGE[message.guild.id].upkeepEntries = BOT_STORAGE[message.guild.id].upkeepEntries or {}
		BOT_STORAGE[message.guild.id].upkeepEntries[e.nonce] = e
		saveData()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commands["update"] = {
	cmd = "update",
	helper = "update [name] [stockpile] <consumption> <Time M:SS (generator only)>",
	fields = {"string","number","number","time"},
	func = function(message, args)
		if not BOT_STORAGE[message.guild.id].upkeepEntries then
			message:replydel("No sites found in server data. Type `!create` or `!creategen`for more info.")
			return
		end
		local name = args[2]
		if not name then message:replydel("Usage: !update [Name] [stockpile] [consumption] [Time(gen only)]")  else
			local entry;  
			for _,v in pairs(BOT_STORAGE[message.guild.id].upkeepEntries) do if v.name:lower() == name:lower() then entry = v; break end end
			if not entry then 
				message:replydel("Entry, "..name..", not found?")
			else
				local isGen = entry.isGenerator and true or false
				local a3 = args[3]; local a4 = args[4]; local a5 = args[5]
				if a3 then
					local n3 = util:parseNumber(a3)
					if n3 then entry.stockpile = n3 end
				end
				if a4 and not isGen then
					local n4 = util:parseNumber(a4)
					if n4 then entry.consumption = n4 end
				elseif a4 and isGen then
					local n4 = util:parseNumber(a4)
					if n4 then entry.recipeCalls = n4 end
				end
				if a5 then 
					local n5 = util:parseTime(a5)
					if n5 then entry.recipeMins = n5 end
				end
				entry.lastUpdate = os.time()
				util.computeDerived(entry, message.guild.id)
				saveData()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commands["remove"] = {
	cmd = "remove",
	helper = "remove [site]",
	fields = {"string"},
	func = function(message, args)
		if not BOT_STORAGE[message.guild.id].upkeepEntries then
			message:replydel("No sites found in server data. Type `!create` or `!creategen`for more info.")
			return
		end
		local name = args[2]
		if not name then
			message:replydel("Usage: !remove [Site]",10)
		else
			local foundKey, entry
			for k, v in pairs(BOT_STORAGE[message.guild.id].upkeepEntries) do
				if v.name and v.name:lower() == name:lower() then
				foundKey, entry = k, v
				break
				end
			end
			if not foundKey then
				message:replydel("Entry, "..name..", not found?",10)
			else
				local site = BOT_STORAGE[message.guild.id].upkeepEntries[foundKey]
				util:logInChannel(message.guild.id,"Removing site '"..site.name.."'")
				BOT_STORAGE[message.guild.id].upkeepEntries[foundKey] = nil
				saveData()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commands["upkeepsummary"] = {
	cmd = "upkeepsummary",
	helper = "upkeepSummary -- changes or moves the upkeepSummary",
	perms = {"manageChannels"},
	func = function(message, args)
		if not BOT_STORAGE[message.guild.id].upkeepEntries then
			message:replydel("No sites found in server data. Type `!create` or `!creategen`for more info.")
			return
		end
		local saved = BOT_STORAGE[message.guild.id].savedSummary or {}
		if saved.messageId and saved.channelId then
			local ch = client:getChannel(saved.channelId)
			if ch then
				local msg = ch:getMessage(saved.messageId)
				if msg then
					msg:delete()
				end
			end
		end
		local payload = util.buildSummaryEmbed(message.guild.id)
		local data = message
		message.channel:sendq(payload, function(sent)
			BOT_STORAGE[data.guild.id].savedSummary = { channelId = data.channel.id, messageId = sent.id }
			saveData()
		end)
		message:delete()
	end
}
return commands