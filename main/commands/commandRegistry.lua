local storage = {}
local discordia = nil
local client = nil
local logger = nil
local save = nil
local util = {}

local commandRegistry = {}
commandRegistry.cmds = {}
commandRegistry.cmds["create"] = {
	cmd = "create",
	helper = "create Name [stockpile] [consumption]",
	func = function(message, args)
		local name = args[2] or ("site_"..tostring(os.time()))
		local sp = util.parseNumber(args[3])
		local cons = util.parseNumber(args[4])
		local e = { name = name, stockpile = sp or 0, consumption = cons or nil, isGenerator = false, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage.entries[e.nonce] = e
		save()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry.cmds["creategen"] = {
	cmd = "creategen",
	helper = "creategen [Name] [stockpile] <calls> <M:SS or minutes>",
	func = function(message, args)
		local name = args[2]
		if not name then util.addToDelete(message:reply("Usage: !creategen [Name] [stockpile] <calls> <M:SS or minutes>"),10); message:delete(); return end
		local idx = 3
		local spCandidate = util.parseNumber(args[idx])
		local sp, calls, rtime
		if spCandidate then sp = spCandidate; idx = idx + 1 end
		calls = tonumber(args[idx])
		rtime = util.parseRecipeTime(args[idx+1])
		if not (calls and rtime) then util.addToDelete(message:reply("Invalid arguments? Example: !creategen GenN 2.0k 30 1:30"),10); message:delete(); return end
		local e = { name = name, stockpile = sp or 0, recipeCalls = calls, recipeMins = rtime, consumption = nil, isGenerator = true, lastUpdate = os.time() }
		util.computeDerived(e, message.guild.id)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage.entries[e.nonce] = e
		save()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry.cmds["update"] = {
	cmd = "update",
	helper = "update [name] [stockpile] <consumption> <Time M:SS (generator only)>",
	func = function(message, args)
		local name = args[2]
		if not name then util.addToDelete(message:reply("Usage: !update [Name] [stockpile] [consumption] [Time(gen only)]"));  else
			local entry;  
			for _,v in pairs(storage.entries) do if v.name:lower() == name:lower() then entry = v; break end end
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
					local n5 = util.parseRecipeTime(a5)
					if n5 then entry.recipeMins = n5 end
				end
				entry.lastUpdate = os.time()
				util.computeDerived(entry, message.guild.id)
				save()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["remove"] = {
	cmd = "remove",
	helper = "remove [site]",
	func = function(message, args)
		local name = args[2]
		if not name then
			util.addToDelete(message:reply("Usage: !remove [Site]"),10)
		else
			local foundKey, entry
			for k, v in pairs(storage.entries) do
				if v.name and v.name:lower() == name:lower() then
				foundKey, entry = k, v
				break
				end
			end
			if not foundKey then
				util.addToDelete(message:reply("Entry, "..name..", not found?"),10)
			else
				storage.entries[foundKey] = nil
				util.logInChannel(message.guild.id,"Removing site '"..foundKey.."'")
				save()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["show"] = {
	cmd = "show",
	helper = "show [all or site]",
	func = function(message, args)
		local target = args[2]
		if not target or target:lower() == 'all' then
			for _,e in pairs(storage.entries) do message.channel:send(util.renderEmbed(e)) end
		else
			local found
			for _,e in pairs(storage.entries) do if e.name:lower() == target:lower() then found = e; break end end
			if not found then message:reply("Not found") else message.channel:send(util.renderEmbed(found)) end
		end
		message:delete()
	end
}
commandRegistry.cmds["sendrole"] = {
	cmd = "sendrole",
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
					save()
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
		save()
		message:delete()
	end
}
commandRegistry.cmds["goalcreate"] = {
	cmd = "goalcreate",
	helper = "goalcreate [name] [goalammount] <currently at?>",
	func = function(message, args)
		local name = args[2]
		if not name then 
			message:reply("Usage: !goalcreate [Name] [goalammount] [Current?]");  
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
				save()
				message:reply("New goal created! Do `!goal show` to build / update the summary!");
			else
				message:reply("`[Err]` - goal already exists?");
			end
		end
	end
}
commandRegistry.cmds["goal"] = {
	cmd = "goal",
	helper = "goal [name] [Current, appending # will set otherwise will add or subtract] <goalammount>",
	func = function(message, args)
		local name = args[2]
		if not name then 
			message:reply("Usage: !goal [name] [current, (Appending '#' will set, otherwise will add/subtract)] <goalammount?>");
		else 
			if name == 'show' then
				if not storage[message.guild.id].goals then
					message:reply("`[Err]` - no goals exists on server?");
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
						save()
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
								save()
							end
						else
							local payload = util.buildGoalEmbed(message.guild)
							local msg = message.channel:send(payload)
							storage[message.guild.id].goalsSummary = {
								channelId = message.channel.id,
								messageId = msg.id,
								nonce = msg.nonce
							}
							save()
						end
					end
				end
			else
				local entry; for key,g in pairs(storage[message.guild.id].goals) do; if g.name:lower() == name:lower() then; entry = key; break; end end
				if not entry then
					message:reply("`[Err]` - goal doesn't exist?");
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
					save()
				end
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["goalremove"] = {
	cmd = "goalremove",
	helper = "goalremove [All or Name]",
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
								save()
							else
								storage[message.guild.id].goalsSummary = {}
								save()
							end
						else
							storage[message.guild.id].goalsSummary = {}
							save()
						end
					end
				end
			else
				local entry; for key,g in pairs(storage[message.guild.id].goals) do; if (g.name:lower() or "") == name:lower() then; entry = key; break; end end
				if not entry then
					util.addToDelete(message:reply("`[Err]` - goal doesn't exists?"))
				else
					if storage[message.guild.id].goals[entry] then
						storage[message.guild.id].goals[entry] = nil
						save()
					else
						util.addToDelete(message:reply("`[Err]` - goal doesn't exists?"))
					end
					save()
				end
			end
		end
		message:delete()
	end
}
commandRegistry.cmds["error"] = {
	cmd = "error",
	func = function(message, args)
		message:delete()
		error("MANUALLY TRIGGERED ERROR "..args[2])
	end
}
commandRegistry.cmds["addlogchannel"] = {
	cmd = "addlogchannel",
	func = function(message, args)
		local guildId = message.guild.id
		storage[guildId] = storage[guildId] or {}
		storage[guildId].logChannel = message.channel.id
		save()
		message:reply("Channel successfully marked as a log channel for "..message.guild.name..".")
		message:delete()
	end
}

function commandRegistry.init(discordia_in, client_in, storage_in, logger_in, save_in, util_in)
	discordia	= discordia_in
	client		= client_in
	storage		= storage_in
	logger		= logger_in
	save		= save_in
	util		= util_in
	print("2")
	return commandRegistry.cmds
end

return commandRegistry