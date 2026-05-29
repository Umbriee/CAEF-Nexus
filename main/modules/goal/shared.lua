local m = {}
m.module = {
	name = "Server Goal",
	desc = "Puts server goals for people to update and check up on!",
	version = "1.0"
}
m.commands = {}
m.commands["goalcreate"] = {
	cmd = "goalcreate",
	helper = "goalcreate [name] [goalammount] <currently at?>",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2]
		if not name then 
			util.addToDelete(message:reply("Usage: !goalcreate [Name] [goalammount] <Current?>"));  
		else
			BOT_STORAGE[message.guild.id].goals = BOT_STORAGE[message.guild.id].goals or {}
			if not BOT_STORAGE[message.guild.id].goals[name] then
				BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
				BOT_STORAGE[message.guild.id].goals = BOT_STORAGE[message.guild.id].goals or {}
				BOT_STORAGE[message.guild.id].goals[name] = {
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
m.commands["goalremove"] = {
	cmd = "goalremove",
	helper = "goalremove [All or Name]",
	fields = {"string"},
	func = function(message, args)
		local name = args[2]
		if not name then
			util.addToDelete(message:reply("Usage: !goalremove [All or name]"),10)
		else 
			if name == 'all' then
				if not BOT_STORAGE[message.guild.id].goals then
					util.addToDelete(message:reply("`[Err]` - no goals exists on server?"));
				else
					BOT_STORAGE[message.guild.id].goalsSummary = BOT_STORAGE[message.guild.id].goalsSummary or {}
					if not BOT_STORAGE[message.guild.id].goalsSummary then
						util.addToDelete(message:reply("`[Err]` - no goals exists on server?"));
					else
						local ch = client:getChannel(BOT_STORAGE[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(BOT_STORAGE[message.guild.id].goalsSummary.messageId)
							if msg then
								msg:delete()
								BOT_STORAGE[message.guild.id].goalsSummary = {}
								saveData()
							else
								BOT_STORAGE[message.guild.id].goalsSummary = {}
								saveData()
							end
						else
							BOT_STORAGE[message.guild.id].goalsSummary = {}
							saveData()
						end
					end
				end
			else
				local entry; for key,g in pairs(BOT_STORAGE[message.guild.id].goals) do; if (g.name:lower() or "") == name:lower() then; entry = key; break; end end
				if not entry then
					util.addToDelete(message:reply("`[Err]` - goal, '"..name.."', doesn't exist?"))
				else
					if BOT_STORAGE[message.guild.id].goals[entry] then
						BOT_STORAGE[message.guild.id].goals[entry] = nil
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
m.commands["goal"] = {
	cmd = "goal",
	helper = "goal [name] [Current, appending # will set otherwise will add or subtract] <goalammount>",
	fields = {"string","number","number"},
	func = function(message, args)
		local name = args[2]
		if not name then 
			util.addToDelete(message:reply("Usage: !goal [name] [current, (Appending '#' will set, otherwise will add/subtract)] <goalammount?>"));
		else 
			if name == 'show' then
				if not BOT_STORAGE[message.guild.id].goals then
					util.addToDelete(message:reply("`[Err]` - no goals exists on server? Do `!goalcreate` for more info"));
				else
					BOT_STORAGE[message.guild.id].goalsSummary = BOT_STORAGE[message.guild.id].goalsSummary or {}
					if not BOT_STORAGE[message.guild.id].goalsSummary then
						local payload = util.buildGoalEmbed(message.guild)
						local msg = message.channel:send(payload)
						BOT_STORAGE[message.guild.id].goalsSummary = {
							channelId = message.channel.id,
							messageId = msg.id,
							nonce = msg.nonce
						}
						saveData()
					else
						local ch = client:getChannel(BOT_STORAGE[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(BOT_STORAGE[message.guild.id].goalsSummary.messageId)
							if msg then
								msg:delete()
								local payload = util.buildGoalEmbed(message.guild)
								local msg = message.channel:send(payload)
								BOT_STORAGE[message.guild.id].goalsSummary = {
									channelId = msg.channel.id,
									messageId = msg.id,
									nonce = msg.nonce
								}
							else
								local payload = util.buildGoalEmbed(message.guild)
								local msg = message.channel:send(payload)
								BOT_STORAGE[message.guild.id].goalsSummary = {
									channelId = message.channel.id,
									messageId = msg.id,
									nonce = msg.nonce
								}
								saveData()
							end
						else
							local payload = util.buildGoalEmbed(message.guild)
							local msg = message.channel:send(payload)
							BOT_STORAGE[message.guild.id].goalsSummary = {
								channelId = message.channel.id,
								messageId = msg.id,
								nonce = msg.nonce
							}
							saveData()
						end
					end
				end
			else
				local entry; for key,g in pairs(BOT_STORAGE[message.guild.id].goals) do; if g.name:lower() == name:lower() then; entry = key; break; end end
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
								BOT_STORAGE[message.guild.id].goals[entry].value = num
								util.logInChannel(message.guild.id, "Updating goal '"..entry.."' to "..num)
							end
						else
							local delta = util.parseNumber(raw)
							if delta then
								BOT_STORAGE[message.guild.id].goals[entry].value = (BOT_STORAGE[message.guild.id].goals[entry].value or 0) + delta
								util.logInChannel(message.guild.id, "Updating goal '"..entry.."' "..((delta >= 0) and ("+"..delta) or delta))
							end
						end
					end
					if args[4] then
						BOT_STORAGE[message.guild.id].goals[entry].goal = util.parseNumber(args[4])
					end
					if BOT_STORAGE[message.guild.id].goalsSummary and (BOT_STORAGE[message.guild.id].goalsSummary.channelId and BOT_STORAGE[message.guild.id].goalsSummary.messageId) then
						local ch = client:getChannel(BOT_STORAGE[message.guild.id].goalsSummary.channelId)
						if ch then
							local msg = ch:getMessage(BOT_STORAGE[message.guild.id].goalsSummary.messageId)
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
local util = {}
function util.buildGoalEmbed(guildObj)
	local goals = BOT_STORAGE[guildObj.id].goals
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
m.util = util
return m