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
//      Umbree's Lua Discord Bot Handler | Version: Something.       //
//                 For use in modularity | Copyright: I.. Dunno.     //
///////////////////////////////////////////////////////////////////////
--]]
global = _G
	--==[ Bot Config ]==--
global.BOT_SAVEDATA		= "privateStorage/data.json"
global.BOT_MODULES		= "modules"
global.BOT_PREFIX		= "!"
global.BOT_WEBCOOL		= 2.00
	--==[ Library Stuff ]==--
global.http				= require("coro-http")
global.json				= require("json")
global.fs				= require('fs')
global.timer			= require("timer")
global.discordia		= require("discordia")
						  discordia.extensions()
global.client			= discordia.Client()
global.class			= discordia.class
global.logger			= discordia.Logger(4, "%Y-%m-%d %H:%M:%S", nil)
global.clock			= discordia.Clock()
global.permissions		= discordia.Permissions() -- unused? Maybe?
function global.safeCall(func) local status, err = xpcall(func, debug.traceback); return status, err end
	--==[ Global Vars ]==--
global.BOT_STORAGE		= {}
function loadData()
	if not BOT_SAVEDATA then
		print("Error: BOT_SAVEDATA path not defined")
		return
	end
	local f = io.open(BOT_SAVEDATA, 'r')
	if not f then
		print("No saved data found or unable to open file")
		return
	end
	local content = f:read('*a')
	f:close()
	if not content or content == "" then
		print("File is empty")
		return
	end
	local ok, t = safeCall(function() return json.decode(content) end)
	if ok and t then
		print("Data loaded successfully!")
		global.BOT_STORAGE = t
	else
		print("Failed to decode JSON:", t)
	end
end
function global.saveData() local f=io.open(global.BOT_SAVEDATA,'w') if f then f:write(json.encode(global.BOT_STORAGE)); f:close() end end
loadData()

	--==[ Load Preliminary Library Utility Functions ]==--
global.util			= require("libs.util")
util.errorHandler	= require("libs.error")
global.errorHandle = util.errorHandler.errorHandle
util:Init()
	--==[ Load Modules ]==--
moduleRegistry	= {}
commandRegistry	= {}
eventRegistry	= {}

local handledEvents = {
	["sec"]					= true,
	["memberJoin"]			= true,
	["memberLeave"]			= true,
	["messageCreate"]		= true,
	["ready"]				= true
}
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
	local ok, module = safeCall(chunk)
	if not ok then
		logger:log(1,"Error executing "..sharedPath.." | "..module)
		return nil
	end
	return module
end
fs.readdir(BOT_MODULES, function(err, potentialModules)
	if err then logger:log(1,err) return end
	for _, name in ipairs(potentialModules) do
		local path = BOT_MODULES .. "/" .. name
		local module = loadModule(path)
		if module then
			moduleRegistry[name] = module
			if module.init and util:isfunction(module.init) then module.init() end
			if module.commands then
				for cmd, data in pairs(module.commands) do
					if not commandRegistry[key] then
						commandRegistry[cmd] = data
					else
						logger:log(1,"["..name.."] - Trying to register a command with the same command as another! ".. (tostring(cmd) or tostring(data) or "ERR"))
					end
				end
			end
			local event = module.event or module.events
			if event then
				for event, func in pairs(event) do
					if not eventRegistry[event] then eventRegistry[event] = {} end
					table.insert(eventRegistry[event],{module = name, func = func})
				end
			end
			if module.util then
				for key, data in pairs(module.util) do
					if not util[key] then
						util[key] = data
					else
						logger:log(1,"["..name.."] - Trying to register a utility var with the same key as another! ".. (tostring(key) or tostring(data) or "ERR"))
					end
				end
			end
		end
	end
end)
local function runModuleEvent(eventStr,...)
	if not eventRegistry[eventStr] then return end
	for _,event in pairs(eventRegistry[eventStr]) do
		local func,module = event.func, event.module
		if func and util:isfunction(func) then func(...) end
	end
end
	--==[ Discord Events RegisterYeh. ]==--
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
		--== Early returns for non-command messages ==--
	if message.author.bot then return end
	if message.content:sub(1, 1) ~= BOT_PREFIX then return end
	if not message.guild then
		message:replyq("No guild found, assuming this is a DM environment?\nUntil I get more commands available in that field, nothing that I can do here.\nSorry!")
		return
	end
		--== Command processing ==--
	local ok, err = safeCall(function()
		logger:log(4, ("Potential Command: [%s] %s: %s"):format(message.guild and message.guild.name or "DM",message.author.name,message.content))
			--== Initialize guild storage if needed ==--
		BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
		local args = parseArgsFromContent(message.content)
		local cmd = (args[1] or ""):lower()
		local entry = commandRegistry[cmd]
			--== Handle help command separately ==--
		if cmd == 'help' then
			handleHelpCommand(message, args)
			return
		end
			--== Process regular commands ==--
		if not entry or type(entry.func) ~= "function" then return end
			--== Permission check ==--
		local canExecute = true
		if entry.perms then
			local success, needed = 0, #entry.perms
			for _, perm in pairs(entry.perms) do
				if message.guild:getMember(message.author.id):hasPermission(perm) and
				message.guild.me:hasPermission(perm) then
					success = success + 1
				end
			end
			canExecute = success >= needed
		end
		if not canExecute then
			message:replydel("Err, either you or I don't have enough permissions for that.")
		else
			entry.func(message, args)
		end
	end)
	errorHandle(
	{CH = message.channel.id, GD = (message.guild and message.guild.id or nil)},
	{{name = "Latest Command", value = ("`%s`"):format(message.content)}},
	ok, err)
	runModuleEvent("messageCreate", message)
end)
function handleHelpCommand(message, args)
	if not args[2] then
			--== Main help menu ==--
		local payload = {
			embed = {
				title = "<:logoColonial64:1501481247128555631> "..client.user.name.." - Available Modules! <:logoWarden64:1501481249745928272>",
				description = table.concat({
					"Type `"..BOT_PREFIX.."help [module]` for more info!",
					"-# You are free to suggest ideas to @umbreeee, they always need more.~",
					"-# I have a Github where my code is publicly shown [here](https://github.com/Umbriee/CAEF-Nexus) if you are curious about anything.",
					"-# Will delete message to keep channel clean "..util:timeTill(120)
				}, "\n"),
				fields = {},
				color = discordia.Color.fromRGB(114, 137, 218).value,
				timestamp = discordia.Date():toISO('T', 'Z')
			}
		}
		for key, module in pairs(moduleRegistry) do
			local commandCount = 0
			for _ in pairs(module.commands) do commandCount = commandCount + 1 end

			if commandCount > 0 and not module.module.hidehelp then
				table.insert(payload.embed.fields, {
					name = ("`%shelp` `%s`"):format(BOT_PREFIX, key),
					value = ("%s, %s%s"):format(
						module.module.name,
						module.module.desc,
						module.module.version and ("\n-# - Version "..module.module.version) or ""
					),
					inline = false
				})
			end
		end
		message.channel:senddel(payload,120)
	else
			--== Module-specific help ==--
		local module = args[2]:lower()
		if not moduleRegistry[module] then
			message:replydel(("Module `%s` not found. Type `%shelp` for more info! Apologies!"):format(module, BOT_PREFIX))
			util:addToDelete(message)
			return
		end
		local moduleData = moduleRegistry[module]
		if moduleData.module.hidehelp then return end
		local payload = {
			embed = {
				title = "<:logoColonial64:1501481247128555631> "..moduleData.module.name.." - Available Commands! <:logoWarden64:1501481249745928272>",
				description = table.concat({
					'`[field]` is required, `<field>` is optional. These are _linear_, so to build up you need the _previous values_ in your input.',
					'You can also include spaces in your command by sorrounding it in quotation marks "like so"',
					"-# Will delete message to clean channel "..util:timeTill(120)
				}, "\n"),
				fields = {},
				color = discordia.Color.fromRGB(114, 137, 218).value,
				timestamp = discordia.Date():toISO('T', 'Z')
			}
		}
		for key, data in pairs(moduleData.commands) do
			if data.helper then
				table.insert(payload.embed.fields, {
					name = "`"..BOT_PREFIX..(data.name or tostring(key)).."`",
					value = table.concat({
						"- Usage: `"..BOT_PREFIX..data.helper.."`",
						data.fields and ("-# - Expected Fields: "..table.concat(data.fields, ", ")) or "",
						data.perms and ("-# - Needed Permissions: "..table.concat(data.perms, ", ")) or ""
					}, "\n"),
					inline = false
				})
			end
		end
		message.channel:senddel(payload,120)
	end
	util:addToDelete(message)
end
clock:on('sec', function(now)
	if util.todelete and next(util.todelete) then
		for key, data in pairs(util.todelete) do
			local msg_obj, time = data[1], data[2]
			if time < os.time() then 
				logger:log(4, 'Deleting garbage message..')
				local savedmsg = msg_obj
				local guild = savedmsg.guild
				util:addToQueue(savedmsg.guild.id, nil, function() 
					local channel = guild and guild:getChannel(savedmsg.channel.id)
					if channel then
						local msg = channel and channel:getcachedmessage(savedmsg.id)
						if msg then
							logger:log(4, 'Deleted garbage message')
							msg:delete()
						end
					end
				end)
				util.todelete[key] = nil
			end
		end
	end
	if util.queue and next(util.queue) then
		for guildId, guildQueue in pairs(util.queue) do
			if not util.queuecool[guildId] then
				util.queuecool[guildId] = os.time()-1
			end
			local queuedata = guildQueue[1]
			if queuedata then
				local time = queuedata[2]
				local func = queuedata[1]
				--[[for ind = #guildQueue, 1, -1 do
					logger:log(4,"   ["..ind.."] -"..time..", "..tostring(time - os.time())..", "..tostring(util.queuecool[guildId] - os.time()))
				end--]]
				if time <= os.time() and (not util.queuecool[guildId] or util.queuecool[guildId] <= os.time()) then
					local ok, err = pcall(func)
					table.remove(guildQueue, 1)
					util.queuecool[guildId] = os.time() + BOT_WEBCOOL
					errorHandle(nil,{{name = "Guild Queue Error", value = "Error in guild: '"..guildId.."'"}},ok, err)
				end
			end
		end
	end
	runModuleEvent("sec",now)
end)
client:on('memberJoin', function(...)	runModuleEvent("memberJoin",	...) end)
client:on('memberLeave', function(...)	runModuleEvent("memberLeave",	...) end)
client:on('ready', function(...)
	logger:log(3, 'Bot started as "%s" in %s servers', (client.user.username..'" / "'..client.user.name), #client.guilds)
	runModuleEvent("ready",...)
	for event, eventDatum in pairs(eventRegistry) do
		if not handledEvents[event] then
			for key, datum in pairs(eventDatum) do
				if key == "module" then
					-- continue
				elseif type(datum) == "table" then
					logger:log(2,"Unhandled event from module '"..datum.module.."' on '"..event..".' Adding to eventRegistry in full")
					local func = function(...) runModuleEvent(event, ...) end
					client:on(event, func)
					handledEvents[event] = true
				end
			end
		end
	end
end)
clock:start(false)
local BOT_TOKEN = require("privateStorage.bottoken")
client:run("Bot "..BOT_TOKEN)