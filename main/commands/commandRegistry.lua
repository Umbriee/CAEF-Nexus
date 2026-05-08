local commandRegistry = {}
commandRegistry.cmds = {}
commandRegistry.cmds["create"] = {
	cmd = "create",
	helper = "create Name [stockpile] [consumption]",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2] or ("site_"..tostring(os.time()))
		local sp = util.parseNumber(args[3])
		local cons = util.parseNumber(args[4])
		if not sp or not cons then message:delete() message:rely("Invalid, or too few, fields: !create Name [stockpile(num)] [consumption(num)]") return end
		local e = { name = name, stockpile = sp or 0, consumption = cons or nil, isGenerator = false, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage[message.guild.id].upkeepEntries = storage[message.guild.id].upkeepEntries or {}
		storage[message.guild.id].upkeepEntries[e.nonce] = e
		saveData()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry.cmds["creategen"] = {
	cmd = "creategen",
	helper = "creategen [Name] [stockpile] <calls> <M:SS or minutes>",
	fields = {"string","number","number","time"},
	func = function(message, args)
		local name = args[2]
		if not name or not args[3] then util.addToDelete(message:reply("Invalid, or too few, fields: !creategen [Name] [stockpile] <calls> <M:SS or minutes>"),10); message:delete(); return end
		local idx = 3
		local spCandidate = util.parseNumber(args[idx])
		local sp, calls, rtime
		if spCandidate then sp = spCandidate; idx = idx + 1 end
		calls = tonumber(args[idx])
		rtime = util.parseTime(args[idx+1])
		if not (calls and rtime) then util.addToDelete(message:reply("Invalid arguments? Example: !creategen GenN 2.0k 30 1:30"),10); message:delete(); return end
		local e = { name = name, stockpile = sp or 0, recipeCalls = calls, recipeMins = rtime, consumption = nil, isGenerator = true, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage[message.guild.id] = storage[message.guild.id] or {}
		storage[message.guild.id].upkeepEntries = storage[message.guild.id].upkeepEntries or {}
		storage[message.guild.id].upkeepEntries[e.nonce] = e
		saveData()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry.cmds["update"] = {
	cmd = "update",
	helper = "update [name] [stockpile] <consumption> <Time M:SS (generator only)>",
	fields = {"string","number","number","time"},
	func = function(message, args)
		if not storage[message.guild.id].upkeepEntries then
			util.addToDelete(message:reply("No sites found in server data. Type `!create` or `!creategen`for more info."))
			return
		end
		local name = args[2]
		if not name then util.addToDelete(message:reply("Usage: !update [Name] [stockpile] [consumption] [Time(gen only)]"));  else
			local entry;  
			for _,v in pairs(storage[message.guild.id].upkeepEntries) do if v.name:lower() == name:lower() then entry = v; break end end
			if not entry then 
				util.addToDelete(message:reply("Entry, "..name..", not found?"));  
			else
				local isGen = entry.isGenerator and true or false
				local a3 = args[3]; local a4 = args[4]; local a5 = args[5]
				if a3 then
					local n3 = util.parseNumber(a3)
					if n3 then entry.stockpile = n3 end
				end
				if a4 and not isGen then
					local n4 = util.parseNumber(a4)
					if n4 then entry.consumption = n4 end
				elseif a4 and isGen then
					local n4 = util.parseNumber(a4)
					if n4 then entry.recipeCalls = n4 end
				end
				if a5 then 
					local n5 = util.parseTime(a5)
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
commandRegistry.cmds["remove"] = {
	cmd = "remove",
	helper = "remove [site]",
	fields = {"string"},
	func = function(message, args)
		if not storage[message.guild.id].upkeepEntries then
			util.addToDelete(message:reply("No sites found in server data. Type `!create` or `!creategen`for more info."))
			return
		end
		local name = args[2]
		if not name then
			util.addToDelete(message:reply("Usage: !remove [Site]"),10)
		else
			local foundKey, entry
			for k, v in pairs(storage[message.guild.id].upkeepEntries) do
				if v.name and v.name:lower() == name:lower() then
				foundKey, entry = k, v
				break
				end
			end
			if not foundKey then
				util.addToDelete(message:reply("Entry, "..name..", not found?"),10)
			else
				local site = storage[message.guild.id].upkeepEntries[foundKey]
				util.logInChannel(message.guild.id,"Removing site '"..site.name.."'")
				storage[message.guild.id].upkeepEntries[foundKey] = nil
				saveData()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["upkeepsummary"] = {
	cmd = "upkeepsummary",
	helper = "upkeepSummary -- changes or moves the upkeepSummary",
	perms = {"manageChannels"},
	func = function(message, args)
		if not storage[message.guild.id].upkeepEntries then
			util.addToDelete(message:reply("No sites found in server data. Type `!create` or `!creategen`for more info."))
			return
		end
		local saved = storage[message.guild.id].savedSummary or {}
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
		local sent = message.channel:send(payload)
		if sent then
			storage[message.guild.id].savedSummary = { channelId = message.channel.id, messageId = sent.id }
			saveData()
		end
		message:delete()
	end
}
commandRegistry.cmds["show"] = {
	cmd = "show",
	helper = "show [all or site] -- Old deprecated function to dedicately display a singular site out instead of a big summary.",
	fields = {"string"},
	func = function(message, args)
		if not storage[message.guild.id].upkeepEntries then
			util.addToDelete(message:reply("No sites found in server data. Type `!create` or `!creategen`for more info."))
			return
		end
		local target = args[2]
		if not target or target:lower() == 'all' then
			for _,e in pairs(storage[message.guild.id].upkeepEntries) do util.addToDelete(message.channel:send(util.renderEmbed(e)),30) end
		else
			local found
			for _,e in pairs(storage[message.guild.id].upkeepEntries) do if e.name:lower() == target:lower() then found = e; break end end
			if not found then util.addToDelete(message:reply("`[ERR]` - Site, '"..target.."', not found?")) else util.addToDelete(message.channel:send(util.renderEmbed(found)),30) end
		end
		message:delete()
	end
}
commandRegistry.cmds["sendrole"] = {
	cmd = "sendrole",
	helper = "sendrole <Emoji> <Display> <Role> ... -- Repeat these three for how many you want. The role itself should probably be in quotation marks if it has spaces as it tries to find the role name **without an @**.",
	fields = {"emoji","string","string","..."},
	perms = {"manageRoles"},
	func = function(message, args)
		storage[message.guild.id] = storage[message.guild.id] or {}
		local guildStore = storage[message.guild.id]
		guildStore.savedRoleSelect = guildStore.savedRoleSelect or {}
		local groups = {}
			do
			local i = 2
			while i <= #args - 2 do
				local e,d,r = args[i], args[i+1], args[i+2]
				if not (e and d and r) then break end
				table.insert(groups, {emoji=e, display=d, roleName=r})
				i = i + 3
			end
		end
		if #groups == 0 then util.addToDelete(message:reply("Usage: !sendrole <emoji> <display> <role> ..."),10); else
			local fields, emojiMap = {}, {}
			local err = false
			for _,g in ipairs(groups) do
				table.insert(fields, { name = g.emoji, value = g.display, inline = false })
				local role
				for _,rr in pairs(message.guild.roles) do if rr.name:lower() == g.roleName:lower() then role = rr; break end end
				if not role then 
					util.addToDelete(message:reply("Role not found: "..g.roleName),10); err = true
				else
					emojiMap[g.emoji] = role.id
				end
			end
			if not err then
				local sent = message.channel:send {
					embed = {
						title = "Role React",
						fields = fields,
						color = discordia.Color.fromRGB(114,137,218).value,
						timestamp = discordia.Date():toISO('T','Z')
					}
				}
				if not sent then else
					guildStore.savedRoleSelect[sent.channel.id] = guildStore.savedRoleSelect[sent.channel.id] or {}
					guildStore.savedRoleSelect[sent.channel.id][sent.id] = {
						guildId = sent.guild.id,
						channelId = sent.channel.id,
						messageId = sent.id,
						emojiMap = emojiMap
					}
					saveData()
					for emojiStr,_ in pairs(emojiMap) do
						local ok,err = pcall(function() sent:addReaction(emojiStr) end)
						if not ok then logger:log(2,"addReaction failed:", emojiStr, err) end
					end
				end
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["rmvrole"] = {
	cmd = "rmvrole",
	helper = "rmvrole -- removes **all** reaction roles(sendrole) in the channel sent.",
	perms = {"manageRoles"},
	func = function(message, args)
		storage[message.guild.id] = storage[message.guild.id] or {}
		local guildStore = storage[message.guild.id]
		local chTable = (guildStore.savedRoleSelect or {})[message.channel.id] or {}
		for msgId,saved in pairs(chTable) do
		if saved and saved.messageId then
			local ok,err = pcall(function()
			local ch = client:getChannel(saved.channelId)
			if ch then
				local msg = ch:getMessage(saved.messageId)
				if msg and msg.author == client.user then msg:delete() end
			end
			end)
			if not ok then logger:log(2,"rmvrole error:", tostring(err)) end
			chTable[msgId] = nil
		end
		end
		saveData()
		message:delete()
	end
}
commandRegistry.cmds["goalcreate"] = {
	cmd = "goalcreate",
	helper = "goalcreate [name] [goalammount] <currently at?>",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2]
		if not name then 
			util.addToDelete(message:reply("Usage: !goalcreate [Name] [goalammount] <Current?>"));  
		else
			storage[message.guild.id].goals = storage[message.guild.id].goals or {}
			if not storage[message.guild.id].goals[name] then
				storage[message.guild.id] = storage[message.guild.id] or {}
				storage[message.guild.id].goals = storage[message.guild.id].goals or {}
				storage[message.guild.id].goals[name] = {
					name = name,
					value = util.parseNumber(args[4]) or 0,
					goal = util.parseNumber(args[3]) or 0,
					subgoals = {}
				}
				saveData()
				message:reply("New goal created! Do `!goal show` to build / update the summary!");
			else
				message:reply("`[Err]` - goal already exists?");
			end
		end
	end
}
commandRegistry.cmds["goalremove"] = {
	cmd = "goalremove",
	helper = "goalremove [All or Name]",
	fields = {"string"},
	func = function(message, args)
		local name = args[2]
		if not name then
			util.addToDelete(message:reply("Usage: !goalremove [All or name]"),10)
		else 
			if name == 'all' then
				if not storage[message.guild.id].goals then
					util.addToDelete(message:reply("`[Err]` - no goals exists on server?"));
				else
					storage[message.guild.id].goalsSummary = storage[message.guild.id].goalsSummary or {}
					if not storage[message.guild.id].goalsSummary then
						util.addToDelete(message:reply("`[Err]` - no goals exists on server?"));
					else
						local ch = client:getChannel(storage[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(storage[message.guild.id].goalsSummary.messageId)
							if msg then
								msg:delete()
								storage[message.guild.id].goalsSummary = {}
								saveData()
							else
								storage[message.guild.id].goalsSummary = {}
								saveData()
							end
						else
							storage[message.guild.id].goalsSummary = {}
							saveData()
						end
					end
				end
			else
				local entry; for key,g in pairs(storage[message.guild.id].goals) do; if (g.name:lower() or "") == name:lower() then; entry = key; break; end end
				if not entry then
					util.addToDelete(message:reply("`[Err]` - goal, '"..name.."', doesn't exist?"))
				else
					if storage[message.guild.id].goals[entry] then
						storage[message.guild.id].goals[entry] = nil
						saveData()
					else
						util.addToDelete(message:reply("`[Err]` - goal, '"..name.."', doesn't exist?"))
					end
					saveData()
				end
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["goal"] = {
	cmd = "goal",
	helper = "goal [name] [Current, appending # will set otherwise will add or subtract] <goalammount>",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2]
		if not name then 
			util.addToDelete(message:reply("Usage: !goal [name] [current, (Appending '#' will set, otherwise will add/subtract)] <goalammount?>"));
		else 
			if name == 'show' then
				if not storage[message.guild.id].goals then
					util.addToDelete(message:reply("`[Err]` - no goals exists on server? Do `!goalcreate` for more info"));
				else
					storage[message.guild.id].goalsSummary = storage[message.guild.id].goalsSummary or {}
					if not storage[message.guild.id].goalsSummary then
						local payload = util.buildGoalEmbed(message.guild)
						local msg = message.channel:send(payload)
						storage[message.guild.id].goalsSummary = {
							channelId = message.channel.id,
							messageId = msg.id,
							nonce = msg.nonce
						}
						saveData()
					else
						local ch = client:getChannel(storage[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(storage[message.guild.id].goalsSummary.messageId)
							if msg then
								msg:delete()
								local payload = util.buildGoalEmbed(message.guild)
								local msg = message.channel:send(payload)
								storage[message.guild.id].goalsSummary = {
									channelId = msg.channel.id,
									messageId = msg.id,
									nonce = msg.nonce
								}
							else
								local payload = util.buildGoalEmbed(message.guild)
								local msg = message.channel:send(payload)
								storage[message.guild.id].goalsSummary = {
									channelId = message.channel.id,
									messageId = msg.id,
									nonce = msg.nonce
								}
								saveData()
							end
						else
							local payload = util.buildGoalEmbed(message.guild)
							local msg = message.channel:send(payload)
							storage[message.guild.id].goalsSummary = {
								channelId = message.channel.id,
								messageId = msg.id,
								nonce = msg.nonce
							}
							saveData()
						end
					end
				end
			else
				local entry; for key,g in pairs(storage[message.guild.id].goals) do; if g.name:lower() == name:lower() then; entry = key; break; end end
				if not entry then
					util.addToDelete(message:reply("`[Err]` - goal doesn't exist?"));
				else
					local raw = args[3]
					if raw then
						-- trim whitespace
						raw = raw:match("^%s*(.-)%s*$")
						if raw:sub(1,1) == "#" then
							local num = util.parseNumber(raw:sub(2))
							if num then
								storage[message.guild.id].goals[entry].value = num
								util.logInChannel(message.guild.id, "Updating goal '"..entry.."' to "..num)
							end
						else
							local delta = util.parseNumber(raw)
							if delta then
								storage[message.guild.id].goals[entry].value = (storage[message.guild.id].goals[entry].value or 0) + delta
								util.logInChannel(message.guild.id, "Updating goal '"..entry.."' "..((delta >= 0) and ("+"..delta) or delta))
							end
						end
					end
					if args[4] then
						storage[message.guild.id].goals[entry].goal = util.parseNumber(args[4])
					end
					if storage[message.guild.id].goalsSummary and (storage[message.guild.id].goalsSummary.channelId and storage[message.guild.id].goalsSummary.messageId) then
						local ch = client:getChannel(storage[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(storage[message.guild.id].goalsSummary.messageId)
							if msg and msg.author == client.user then
								local payload = util.buildGoalEmbed(message.guild)
								msg:setContent(payload.content or "")
								msg:setEmbed(payload.embed)
							end
						end
					end
					saveData()
				end
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["error"] = {
	cmd = "error",
	helper = "error <field> -- manually triggers an error for my own debugging purposes",
	perms = {"manageChannels"},
	func = function(message, args)
		message:delete()
		error("MANUALLY TRIGGERED ERROR '"..(args[2] or "NaN").."'")
	end
}
commandRegistry.cmds["warapi"] = {
	cmd = "warapi",
	helper = "warapi -- makes a request to the official War API provided to give.. '_detailed_' info on the war.",
	func = function(message, args)
		message:delete()
		util.updateAPIEmbed(message.channel)
	end
}
commandRegistry.cmds["addlogchannel"] = {
	cmd = "addlogchannel",
	helper = "addlogchannel -- registers the messaged channel to be a sort of 'botlog' that will be sent messages when things are updated or otherwise.",
	perms = {"manageChannels"},
	func = function(message, args)
		local guildId = message.guild.id
		storage[guildId].logChannel = message.channel.id
		saveData()
		util.addToDelete(message:reply("Channel successfully marked as a log channel for "..message.guild.name.."."),10)
		message:delete()
	end
}
commandRegistry.cmds["settimer"] = {
	cmd = "settimer",
	--helper = "settimer [name] [time] -- registers an alarmclock for time sensitive details. Name is for storing or organization.",
	fields = {"string","time"},
	func = function(message, args)

	end
}
commandRegistry.cmds["stockpile"] = {
	cmd = "stockpile",
	abbreviation = "sp", -- May make it easier to type out.
	helper = "stockpile [name] [location] [code] <time remaining or 2d1h (accepts #d#h#m or hh:mm)> **OR** "..commandPrefix.."stockpile [name] <time 2d1h> -- Can either register a stockpile, or update a pre-existing one. Fallsback to 2 days & 1 hour if the time field is missing.",
	fields = {"string","string/time","string","time"},
	func = function(message, args)
		local guild = message.guild
		if not guild then return end
		local name, key = args[2],args[2]:lower()
		local arg3 = args[3]
		local arg4 = args[4]
		local arg5 = args[5]
		if not name or not arg3 then
			util.addToDelete(message:reply("Usage: !stockpile [name] [location or newly refreshed time] [code] <time remaining or 2d1h>"))
			message:delete(); return
		end
		if not storage[guild.id].stockpileChannel then
			util.addToDelete(message:reply("No stockpile channel found in server registry, add with `!addstockpilechannel`!"))
			message:delete(); return
		end
		storage[guild.id].stockpiles = storage[guild.id].stockpiles or {}
		local existing = storage[guild.id].stockpiles[key]
		local function isTimeFormat(s)
			if not s then return false end
			-- crude check: contains d or h or m or ":" or is all digits (e.g., "2h", "90m", "01:30")
			return string.find(s, "%d+[dhm]") or string.find(s, ":")
		end
		-- Decide whether arg3 is a time (refresh) or a location
		local location, code, expireTime
		if isTimeFormat(arg3) then
			-- quick update: name + time [ + code? + location? ]
			expireTime = os.time() + util.parseTime(arg3)*3600
			code = arg4 or (existing and existing.code)
			location = arg5 or (existing and existing.loc)
		else
			-- normal create/update: name + location + code? + time?
			location = arg3 or (existing and existing.loc)
			code = arg4 or (existing and existing.code)
			expireTime = (arg5 and (os.time() + util.parseTime(arg5)*3600) or nil)
		end
		-- default expireTime if none provided
		if not expireTime then expireTime = os.time() + 180000 end
		if not code then 
			util.addToDelete(message:reply("No code field found, Usage: !stockpile [name] [location or newly refreshed time] [code] <time remaining or 2d1h>"))
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
			util.addToDelete(message:reply("Stockpile: [" .. build.name .. " @ "..build.loc.."] updated; expires " .. util.unixTimestamp(build.expireTime)))
		else
			if not location then
			util.addToDelete(message:reply("No existing stockpile named '"..name.."' found. Provide a location to create: Usage: !stockpile [name] [location] [code] <time>"))
			message:delete(); return
			end
			util.updateStockpileEmbed(guild.id, { name = name, loc = location, code = code, expireTime = expireTime })
			util.addToDelete(message:reply("Stockpile: [" .. name .. " - " .. location .. "] added to registry, will expire " .. util.unixTimestamp(expireTime)))
		end
		message:delete()
	end
}
commandRegistry.cmds["rmvstockpile"] = {
	cmd = "rmvstockpile",
	abbreviation = "rsp",
	helper = "stockpile [name] -- removes a stockpile from data.",
	fields = {"string"},
	func = function(message, args)
		local name, key = args[2],args[2]:lower()
		if not name then
			util.addToDelete(message:reply("Usage: !rmvstockpile [name]"))
			message:delete(); return
		end
		if storage[message.guild.id].stockpiles[key] then
			if util.stockpileAlerts[key] then
				util.stockpileAlerts[key] = nil
			end
			if storage[message.guild.id].stockpiles[key].messageId then
				local msg = util.grabmsg(message.guild.id,storage[message.guild.id].stockpileChannel.channelId,storage[message.guild.id].stockpiles[key].messageId)
				if msg then
					msg:delete()
				end
			end
			storage[message.guild.id].stockpiles[key] = nil
			util.addToDelete(message:reply("Deleting "..name.." from stockpile entry.."))
		else
			util.addToDelete(message:reply("Entry, "..name..", not found?"))
		end
		saveData()
		message:delete()
	end
}
commandRegistry.cmds["addstockpilechannel"] = {
	cmd = "addstockpilechannel",
	helper = "addstockpilechannel -- marks the current channel a stockpile channel to add stockpiles & alerts",
	perms = {"manageChannels"},
	func = function(message, args)
		local guildId, channelId = message.guild.id, message.channel.id
		storage[guildId].stockpileChannel = {guildId = guildId, channelId = channelId}
		saveData()
		message:reply("Channel successfully marked as a stockpile channel for "..message.guild.name..". Use `!stockpile` to begin")
		message:delete()
	end
}
return commandRegistry.cmds