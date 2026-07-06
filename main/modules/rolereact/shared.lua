local m = {}
m.module = {
	name = "Role React",
	desc = "Gives the ability for the bot to hand out roles based on",
	version = "1.0"
}
m.commands = {}
m.commands["sendrole"] = {
	cmd = "sendrole",
	helper = "sendrole <Emoji> <Display> <Role> ... -- Repeat these three for how many you want. The role itself should probably be in quotation marks if it has spaces as it tries to find the role name **without an @**.",
	fields = {"emoji","string","string","..."},
	perms = {"manageRoles"},
	func = function(message, args)
		BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
		local guildStore = BOT_STORAGE[message.guild.id]
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
						local ok,err = safeCall(function() sent:addReaction(emojiStr) end)
						if not ok then logger:log(2,"addReaction failed:", emojiStr, err) end
					end
				end
			end
		end
		message:delete()
	end
}
m.commands["rmvrole"] = {
	cmd = "rmvrole",
	helper = "rmvrole -- removes **all** reaction roles(sendrole) in the channel sent.",
	perms = {"manageRoles"},
	func = function(message, args)
		BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
		local guildStore = BOT_STORAGE[message.guild.id]
		local chTable = (guildStore.savedRoleSelect or {})[message.channel.id] or {}
		for msgId,saved in pairs(chTable) do
		if saved and saved.messageId then
			local ok,err = safeCall(function()
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
m.events = {}
m.events['reactionAddAny'] = function(channel, messageId, hash, userId)
	if userId == client.user.id then return end
	local guildStore = BOT_STORAGE[channel.guild.id] or {}
	local chMap = guildStore.savedRoleSelect or {}
	local chTable = chMap[channel.id] or {}
	local saved = chTable[messageId]
	if not saved or not saved.messageId then return end
	if channel.id ~= saved.channelId or channel.guild.id ~= saved.guildId then return end

	local roleId = saved.emojiMap[hash] or saved.emojiMap[tostring(hash)]
	if not roleId then
		logger:log(2,"Unknown emoji hash on add:", hash); return
	end
	local member = channel.guild:getMember(userId)
	if not member then return end
	local ok,err = safeCall(function() 
		local role
		for _,rr in pairs(channel.guild.roles) do if rr.id == roleId then role = rr; break end end
		logger:log(3,"[ReactionAdd: "..channel.guild.name.."] - Adding "..role.name.." to "..member.name)
		member:addRole(roleId) 
	end)
	if not ok then logger:log(2,"Role add error:", tostring(err)) end
end
m.events['reactionRemoveAny'] = function(channel, messageId, hash, userId)
	if userId == client.user.id then return end
	local guildStore = BOT_STORAGE[channel.guild.id] or {}
	local chMap = guildStore.savedRoleSelect or {}
	local chTable = chMap[channel.id] or {}
	local saved = chTable[messageId]
	if not saved or not saved.messageId then return end
	if channel.id ~= saved.channelId or channel.guild.id ~= saved.guildId then return end

	local roleId = saved.emojiMap[hash] or saved.emojiMap[tostring(hash)]
	if not roleId then
		logger:log(2,"Unknown emoji hash on remove:", hash); return
	end
	local member = channel.guild:getMember(userId)
	if not member then return end
	local ok,err = safeCall(function() 
		local role
		for _,rr in pairs(channel.guild.roles) do if rr.id == roleId then role = rr; break end end
		logger:log(3,"[ReactionAdd: "..channel.guild.name.."] - Removing "..role.name.." to "..member.name)
		member:removeRole(roleId)
	end)
	if not ok then logger:log(2,"Role remove error:", tostring(err)) end
end
return m