_G.http			= require("coro-http")
_G.json			= require('json')

_G.discordia		= require('discordia')
discordia.extensions()
_G.client			= discordia.Client()
_G.logger			= discordia.Logger(4, '%Y-%m-%d %H:%M:%S', nil)
_G.clock			= discordia.Clock()
_G.permissions		= discordia.Permissions()
_G.localSaveData	= 'privateStorage/data.json'
-- I was told that _G is something not to use all that much.. Buut..

_G.commandPrefix = "!"
local cooldown = os.time()
local cooldownTime = 2.00
_G.storage = {}
function _G.loadData()
	local f=io.open(localSaveData,'r') if f then local c=f:read'*a';f:close(); local ok,t=pcall(json.decode,c) if ok and t then _G.storage=t end end
end
function _G.saveData() local f=io.open(localSaveData,'w') if f then f:write(json.encode(_G.storage)); f:close() end end
loadData()

_G.util = require("libs.util")
util.errorHandler = require("libs.error")
errorHandle = util.errorHandler.errorHandle
commandRegistry = require("commands.commandRegistry")
client:on('reactionAddAny', function(channel, messageId, hash, userId)
	if userId == client.user.id then return end
	local guildStore = storage[channel.guild.id] or {}
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
	local ok,err = pcall(function() 
		local role
		for _,rr in pairs(channel.guild.roles) do if rr.id == roleId then role = rr; break end end
		logger:log(3,"[ReactionAdd: "..channel.guild.name.."] - Adding "..role.name.." to "..member.name)
		member:addRole(roleId) 
	end)
	if not ok then logger:log(2,"Role add error:", tostring(err)) end
end)
client:on('reactionRemoveAny', function(channel, messageId, hash, userId)
	if userId == client.user.id then return end
	local guildStore = storage[channel.guild.id] or {}
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
	local ok,err = pcall(function() 
		local role
		for _,rr in pairs(channel.guild.roles) do if rr.id == roleId then role = rr; break end end
		logger:log(3,"[ReactionAdd: "..channel.guild.name.."] - Removing "..role.name.." to "..member.name)
		member:removeRole(roleId)
	end)
	if not ok then logger:log(2,"Role remove error:", tostring(err)) end
end)
local function parseArgsFromContent(content)
	local s = content:sub(2)
	local args = {}
	local i = 1
	while true do
		while i <= #s and s:sub(i,i):match("%s") do i = i + 1 end
		if i > #s then break end
		local c = s:sub(i,i)
		if c == '"' or c == "'" then
			local q = c; i = i + 1; local buf = {}
			while i <= #s do
				local ch = s:sub(i,i)
				if ch == "\\" and i < #s then
					i = i + 1
					table.insert(buf, s:sub(i,i))
					i = i + 1
				elseif ch == q then
					i = i + 1; break
				else
					table.insert(buf, ch); i = i + 1
				end
			end
			table.insert(args, table.concat(buf))
		else
			local start = i
			while i <= #s and not s:sub(i,i):match("%s") do i = i + 1 end
			table.insert(args, s:sub(start, i-1))
		end
	end
	return args
end
client:enableIntents(discordia.enums.gatewayIntent.messageContent)
client:on('messageCreate', function(message)
	if message.author.bot then return end
	if message.content:sub(1,1) ~= commandPrefix then return end
	if not message.guild then message:reply("No guild found, assuming DM. Until I get more commands available in that field, nothing that I can do here.") return end
	if cooldown < os.time() then
		local ok, err = pcall(function()
			logger:log(4,"Potential Command: ["..(message.guild and message.guild.name or "DM").."] "..message.author.username..":  "..message.content)
			if not storage[message.guild.id] then
				storage[message.guild.id] = storage[message.guild.id] or {}
			end
			local args = parseArgsFromContent(message.content)
			local cmd = (args[1] or ""):lower()
			local entry = commandRegistry[cmd]
			if entry and type(entry.func) == "function" then
				local can = false
				if entry.perms then
					local success,needed = 0,#entry.perms
					for key, data in pairs(entry.perms) do
						if message.guild:getMember(message.author.id):hasPermission(data) and message.guild.me:hasPermission(data) then success=success+1; end
					end
					if success >= needed then can = true end
				else can = true end
				if not can then
					message:reply("Either I don't have current permissions for that command, or you don't!")
				else
					cooldown = os.time() + cooldownTime
					entry.func(message, args)
				end
			else
				if cmd == 'help' then
					local payload = {
						embed = {
							title = "<:logoColonial64:1501481247128555631> "..client.user.username.." - Available Commands! <:logoWarden64:1501481249745928272>",
							description = "`[field]` is required, `<field>` is optional. These are _linear_, so to build up you need the _previous values_ in your input.\n-# You are free to suggest ideas to @umbreeee, they need more.~\n-# I have a Github where my code is publicly shown [here](https://github.com/Umbriee/CAEF-Nexus) if you are curious about anything.",
							fields = {},
							color = discordia.Color.fromRGB(114, 137, 218).value,
							timestamp = discordia.Date():toISO('T', 'Z')
						}
					}
					for key, data in pairs(commandRegistry) do
						if data.helper then
							local fields, perms
							if data.fields then
								fields = table.concat(data.fields,", ")
							end
							if data.perms then
								perms = table.concat(data.perms,", ")
							end
							table.insert(payload.embed.fields, {name = (data.name or tostring(key)), value = ("- Usage: `"..commandPrefix..data.helper.."`"..(fields and ("\n-# - Expected Fields: "..fields) or "")..(perms and ("\n-# - Needed Permissions: "..perms) or "")), inline = false})
						end
					end
					cooldown = os.time() + cooldownTime
					util.addToDelete(message.channel:send(payload),120)
					message:delete()
				end
			end
		end)
		errorHandle({CH = message.channel.id, GD = (message.guild and message.guild.id or nil)}, {{name = "Latest Command", value = ("`"..message.content.."`")}}, ok, err)
	else
		util.addToDelete(message:reply("I'm sending too many requests too quickly!\n-# <Cooldown of "..cooldownTime.." seconds per cmd.>"))
		util.addToDelete(message,3)
	end
end)
local pcall_old = pcall
function pcall(func)
	lasttrace = lasttrace or nil
	local status, err = xpcall(func,debug.traceback)
	return status, err
end
client:on('ready', function()
	logger:log(3, 'Bot started as %s in %s servers', client.user.username, #client.guilds)
	local perms = permissions.all()
	--[[for key, data in pairs(perms:toTable()) do
		print(tostring(key),tostring(data))
	end--]]
	logger:log(3, "Starting Garbage Data Collection...")
	for key, data in pairs(storage) do
		local guild = client:getGuild(key)
		if guild then
			logger:log(3,"Found Guild data for server: %s (%s)",guild.name,tostring(key))
		else
			logger:log(2,"Garbage Wandering Data found, %s %s",tostring(key),tostring(data))
			storage[key] = nil
		end
	end
	logger:log(3, "Run any command that saves data to confirm.")
end)
clock:on('sec', function(now)
	if util.todelete and #util.todelete > 0 then
		for key, data in pairs(util.todelete) do
			local msg_obj, time = data[1], data[2]
			if time > os.time() then 
				-- continue
			else
				local guild = client:getGuild(msg_obj.guild.id)
				local channel = guild and guild:getChannel(msg_obj.channel.id)
				local msg = channel and channel:getMessage(msg_obj.id)
				if msg then 
					logger:log(3, 'Deleting garbage message..')
					msg:delete()
					util.todelete[key] = nil
				end
			end
		end
	end
end)
clock:on('min', function(now)
	for key, data in pairs(storage) do
		local guild = client:getGuild(key)
		if guild then
			if data.stockpileChannel then
				local ch = guild:getChannel(data.stockpileChannel.channelId)
				if ch then
					if data.stockpiles then
						for key2, data2 in pairs(data.stockpiles) do
							if data2.expireTime then
								if (data2.expireTime - 3600) <= os.time() then
									if not util.stockpileAlerts[key2] then
										util.stockpileAlerts[key2] = true
										util.addToDelete(ch:send("`[⚠Alert]` - Stockpile, "..data2.name.." in "..data2.loc..", is about to expire. "..util.unixTimestamp(data2.expireTime).."\n-# Use `!stockpile "..data2.name.." 2d1h` or whatever the time may be to refresh this."),1500)
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
clock:start(false)
local BOT_TOKEN = require("privateStorage.bottoken")
client:run("Bot "..BOT_TOKEN)