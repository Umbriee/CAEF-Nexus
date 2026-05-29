--[[
///////////////////////////////////////////////////////////////////////
//  █████  █████                 █████        ███████     █████████  //
// ▒▒███  ▒▒███                 ▒▒███       ███▒▒▒▒▒███  ███▒▒▒▒▒███ //
//  ▒███   ▒███  █████████████   ▒███████  ███     ▒▒███▒███    ▒▒▒  //
//  ▒███   ▒███ ▒▒███▒▒███▒▒███  ▒███▒▒███▒███      ▒███▒▒█████████  //
//  ▒███   ▒███  ▒███ ▒███ ▒███  ▒███ ▒███▒███      ▒███ ▒▒▒▒▒▒▒▒███ //
//  ▒███   ▒███  ▒███ ▒███ ▒███  ▒███ ▒███▒▒███     ███  ███    ▒███ //
//  ▒▒████████   █████▒███ █████ ████████  ▒▒▒███████▒  ▒▒█████████  //
//   ▒▒▒▒▒▒▒▒   ▒▒▒▒▒ ▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒▒▒   //
//      Umbree's Cool Discord Bot                                    //
//          For use in modularity                                    //
///////////////////////////////////////////////////////////////////////
--]]
	--==[ Preliminary Library Stuff ]==--
_G.http				= require("coro-http")
_G.json				= require("json")
_G.fs				= require('fs')
local timer			= require("timer")
_G.discordia		= require("discordia")
					discordia.extensions()
_G.client			= discordia.Client()
_G.logger			= discordia.Logger(4, "%Y-%m-%d %H:%M:%S", nil)
_G.clock			= discordia.Clock()
_G.permissions		= discordia.Permissions()
_G.localSaveData	= "privateStorage/data.json"
_G.BOT_MODULES		= "modules"
_G.BOT_PREFIX		= "!"
_G.BOT_STORAGE		= {}
_G.BOT_COOL			= 2.00
	--==[ Load Saved Funcs Data & load to memory ]==--
function _G.loadData()
	local f=io.open(localSaveData,'r') if f then local c=f:read'*a';f:close(); local ok,t=pcall(json.decode,c) if ok and t then _G.BOT_STORAGE=t end end
end
function _G.saveData() local f=io.open(localSaveData,'w') if f then f:write(json.encode(_G.BOT_STORAGE)); f:close() end end
loadData()
	--==[ Load Locally made Libary ]==--
_G.util = require("libs.util")
util.errorHandler = require("libs.error")
errorHandle = util.errorHandler.errorHandle

	--==[ Load Modules ]==--
moduleRegistry	= {}
commandRegistry	= {}
eventRegistry	= {}
local function loadModule(modulePath)
	local sharedPath = modulePath .. "/shared.lua"
	local file, err = io.open(sharedPath, "r")
	if not file then
		logger:log(2,"Couldn't open "..sharedPath.." | "..err)
		return nil
	end
	local content = file:read("*a")
	file:close()
	local chunk, err = load(content, sharedPath)
	if not chunk then
		logger:log(1,"Error loading "..sharedPath.." | "..err)
		return nil
	end
	local ok, module = pcall(chunk)
	if not ok then
		logger:log(1,"Error executing "..sharedPath.." | "..module)
		return nil
	end
	return module
end
fs.readdir(BOT_MODULES, function(err, potentialModules)
	if err then error(err) return end
	for _, name in ipairs(potentialModules) do
		local path = BOT_MODULES .. "/" .. name
		local module = loadModule(path)
		if module then
			moduleRegistry[name] = module
			if module.init then
				module.init()
			end
			if module.commands then
				for cmd, data in pairs(module.commands) do
					if not commandRegistry[key] then
						commandRegistry[cmd] = data
					else
						error("Trying to register a command with the same command as another! ", cmd)
					end
				end
			end
			if module.event then
				for event, data in pairs(module.event) do
					if not eventRegistry[event] then eventRegistry[event] = {} end
					table.insert(eventRegistry[event],{name = data})
				end
			end
			if module.util then
				for key, data in pairs(module.util) do
					if not util[key] then
						util[key] = data
					else
						error("Trying to register a utility var with the same key as another! ", key)
					end
				end
			end
		end
	end
end)
local function runModuleEvent(eventStr,...)
	if not eventRegistry[eventStr] then return end
	for _,events in pairs(eventRegistry[eventStr]) do
		for _,event in pairs(events) do
			event(...)
		end
	end
end
	--==[ Discord Events RegisterYeh. ]==--
client:on('reactionAddAny', function(channel, messageId, hash, userId)
	runModuleEvent("reactionRemoveAny",channel, messageId, hash, userId)
end)
client:on('reactionRemoveAny', function(channel, messageId, hash, userId)
	runModuleEvent("reactionRemoveAny",channel, messageId, hash, userId)
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
	if message.content:sub(1,1) ~= BOT_PREFIX then return end
	if not message.guild then message:reply("No guild found, assuming DM. Until I get more commands available in that field, nothing that I can do here.") return end
	if (cooldown or 0) < os.time() then
		local ok, err = pcall(function()
			logger:log(4,"Potential Command: ["..(message.guild and message.guild.name or "DM").."] "..message.author.username..": "..message.content)
			if not BOT_STORAGE[message.guild.id] then
				BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
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
					cooldown = os.time() + BOT_COOL
					entry.func(message, args)
				end
			else
				if cmd == 'help' then
					if not args[2] then
						local payload = {
							embed = {
								title = "<:logoColonial64:1501481247128555631> "..client.user.username.." - Available Modules! <:logoWarden64:1501481249745928272>",
								description = "Type `"..BOT_PREFIX.."help [module]` for more info!\n-# You are free to suggest ideas to @umbreeee, they always need more.~\n-# I have a Github where my code is publicly shown [here](https://github.com/Umbriee/CAEF-Nexus) if you are curious about anything.\n-# Will delete message to keep channel clean "..util.timeTill(120),
								fields = {},
								color = discordia.Color.fromRGB(114, 137, 218).value,
								timestamp = discordia.Date():toISO('T', 'Z')
							}
						}
						for key, module in pairs(moduleRegistry) do
							local int = 0
							for _,_ in pairs(module.commands) do
								int = int + 1
							end
							if ((int > 0) and (not module.module.hidehelp)) then
								table.insert(payload.embed.fields, {name = ("`"..BOT_PREFIX.."help` `"..key.."`"), value = (module.module.name..", "..module.module.desc..(module.module.version and ("\n-# - Version "..module.module.version) or "")), inline = false})
							end
						end
						util.addToDelete(message.channel:send(payload),120)
					else
						local module = args[2]:lower()
						if not moduleRegistry[module] then
							util.addToDelete(message:reply("Module "..module.." not found. Type `"..BOT_PREFIX.."help` for more info! Apologies!"))
						else
							local module = moduleRegistry[module]
							if not module.module.hidehelp then	
								local payload = {
									embed = {
										title = "<:logoColonial64:1501481247128555631> "..module.module.name.." - Available Commands! <:logoWarden64:1501481249745928272>",
										description = '`[field]` is required, `<field>` is optional. These are _linear_, so to build up you need the _previous values_ in your input.\nYou can also include spaces in your command by sorrounding it in quotation marks "like so"\n-# Will delete message to clean channel '..util.timeTill(120),
										fields = {},
										color = discordia.Color.fromRGB(114, 137, 218).value,
										timestamp = discordia.Date():toISO('T', 'Z')
									}
								}
								for key, data in pairs(module.commands) do
									if data.helper then
										local fields, perms
										if data.fields then
											fields = table.concat(data.fields,", ")
										end
										if data.perms then
											perms = table.concat(data.perms,", ")
										end
										table.insert(payload.embed.fields, {name = (data.name or tostring(key)), value = ("- Usage: `"..BOT_PREFIX..data.helper.."`"..(fields and ("\n-# - Expected Fields: "..fields) or "")..(perms and ("\n-# - Needed Permissions: "..perms) or "")), inline = false})
									end
								end
								util.addToDelete(message.channel:send(payload),120)
							end
						end
					end
					message:delete()
					cooldown = os.time() + BOT_COOL
				end
			end
		end)
		errorHandle({CH = message.channel.id, GD = (message.guild and message.guild.id or nil)}, {{name = "Latest Command", value = ("`"..message.content.."`")}}, ok, err)
	else
		util.addToDelete(message:reply("I'm sending too many requests too quickly!\n-# <Cooldown of "..BOT_COOL.." seconds per cmd.>"))
		util.addToDelete(message,3)
	end
	runModuleEvent("messageCreate",message)
end)
local pcall_old = pcall
function pcall(func)
	lasttrace = lasttrace or nil
	local status, err = xpcall(func,debug.traceback)
	return status, err
end
client:on('ready', function(...)
	logger:log(3, 'Bot started as %s in %s servers', client.user.username, #client.guilds)
	local perms = permissions.all()
	runModuleEvent("ready",...)
end)
--[[logger:log(3, "Starting Garbage Data Collection...")
	for key, data in pairs(BOT_STORAGE) do
		local guild = client:getGuild(key)
		if guild then
			logger:log(3,"Found Guild data for server: %s (%s)",guild.name,tostring(key))
		else
			logger:log(2,"Garbage Wandering Data found, %s %s",tostring(key),tostring(data))
			BOT_STORAGE[key] = nil
		end
	end
	logger:log(3, "Run any command that saves data to confirm.")--]]
clock:on('sec', function(now)
	if util.todelete and #util.todelete > 0 then
		for key, data in pairs(util.todelete) do
			local msg_obj, time = data[1], data[2]
			if time > os.time() then 
				-- continue, but there is no continue func in this library
			else
				local guild = client:getGuild(msg_obj.guild.id)
				local channel = guild and guild:getChannel(msg_obj.channel.id)
				local msg = channel and channel:getMessage(msg_obj.id)
				if msg then 
					logger:log(3, 'Deleting garbage message..')
					pcall(msg:delete())
					util.todelete[key] = nil
				end
			end
		end
	end
	runModuleEvent("sec",now)
end)
clock:on('min', function(now)
	runModuleEvent("min",now)
end)
clock:start(false)
local BOT_TOKEN = require("privateStorage.bottoken")
client:run("Bot "..BOT_TOKEN)