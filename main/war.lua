local discordia = require('discordia')
local http = require("coro-http")
local client = discordia.Client()
discordia.extensions()
local Logger = discordia.Logger
local logger = Logger(4, '%Y-%m-%d %H:%M:%S', nil)
local Clock = discordia.Clock
local clock = Clock()
local Permissions = discordia.Permissions
local permissions = Permissions()
local json = require('json')
local datafile = 'privateStorage/data.json'
local prefix = "!"

local cooldown = os.time()
local cooldownTime = 2.00
local storage = { entries = {} }

local function load()
	local f=io.open(datafile,'r') if f then local c=f:read'*a';f:close(); local ok,t=pcall(json.decode,c) if ok and t then storage=t end end
end
local function save() local f=io.open(datafile,'w') if f then f:write(json.encode(storage)); f:close() end end
load()

local util = require("libs.util").init(discordia, client, storage, logger, save, json, http)
util.errorHandler = require("libs.error").init(discordia, client, storage, logger, save)
local errorHandle = util.errorHandler.errorHandle
local commandRegistry = require("commands.commandRegistry").init(discordia, client, storage, logger, save, util)
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
client:on('messageCreate', function(message)
	if message.author.bot then return end
	if message.content:sub(1,1) ~= prefix then return end
	if not message.guild then message:reply("No guild found, assuming DM. Until I get more commands available in that field, nothing that I can do here.") return end
	if cooldown < os.time() then
		local ok, err = pcall(function()
			logger:log(2,"Potential Command: ["..(message.guild and message.guild.name or "DM").."] "..message.author.username..":  "..message.content)
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
							local txt
							if data.fields then
								txt = table.concat(data.fields,", ")
							end
							table.insert(payload.embed.fields, {name = (data.name or tostring(key)), value = (("`"..prefix..data.helper.."`"..(txt and ("\n-# Expected Fields: "..txt) or "")) or "Umbree, add data here!"), inline = false})
						end
					end
					message.channel:send(payload)
					message:delete()
				end
			end
			cooldown = os.time() + cooldownTime
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
end)
clock:on('min', function(now)
	--[[if now.min % 3 == 0 then return end--]]
	--print("Timer ticked")
end)
clock:start(false)
--[[do
	for key, data in pairs(storage.entries) do
		storage["1458073180013858858"] = storage["1458073180013858858"] or {}
		storage["1458073180013858858"].upkeepEntries = storage["1458073180013858858"].upkeepEntries or {}
		storage["1458073180013858858"].upkeepEntries[key] = data
	end
	for key, data in pairs(storage.savedSummary) do
		storage["1458073180013858858"] = storage["1458073180013858858"] or {}
		storage["1458073180013858858"].savedSummary = storage["1458073180013858858"].savedSummary or {}
		storage["1458073180013858858"].savedSummary[key] = data
	end
	save()
end--]]
local BOT_TOKEN = require("privateStorage.bottoken")
client:run("Bot "..BOT_TOKEN)