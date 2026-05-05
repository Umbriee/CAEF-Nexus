local discordia = require('discordia')
local client = discordia.Client()
discordia.extensions()
local Logger = require('discordia').Logger
local logger = Logger(4, '%Y-%m-%d %H:%M:%S', nil)
local clock = require('discordia').Clock
local json = require('json') -- replace with your json lib
local datafile = 'data.json'
local prefix = "!"

local cooldown = os.time()
local cooldownTime = 2.00
local storage = { entries = {} }
local todelete = {}

--==[ My Cool Libraries ]==--
local function load()
	local f=io.open(datafile,'r') if f then local c=f:read'*a';f:close(); local ok,t=pcall(json.decode,c) if ok and t then storage=t end end
end
local function save() local f=io.open(datafile,'w') if f then f:write(json.encode(storage)); f:close() end end
load()
local util = require("libs.util")
util.init(discordia, client, storage)
local ERR_FUNNY_SUBTITLE = {
	"Birds tripped over the power plug again.",
	"The avali got distracted by shiny code.",
	"One of the birds mistook the server for a nest.",
	"Feathers in the circuitry -- rebooting.",
	"An avali winged the wrong function.",
	"Gremlin-bird hid the semicolons again.",
	"A flock tried to refactor live.",
	"An avali pressed the big red button.",
	"A bird attempted recursion and forgot to stop.",
	"An avali stole the return value.",
	"Someone fed the server breadcrumbs.",
	"Back to me debugging with pebbles.",
	"A nest of exceptions hatched.",
	"An avali took a nap on the CPU.",
	"Found wings in the wires, performance affected.",
	"Birdbrain locked the mutex.",
	"An avali mistook the DB for a birdbath.",
	"A gremlin feather jammed the pipeline.",
	"Birds are negotiating with the cache.",
	"An avali dropped a packet from a great height.",
	"Feathers overloaded the stack.",
	"A bird updated my drivers randomly.",
	"404 - nest not found.",
	"A bird rerouted the return path.",
	"A bird is refusing to follow orders.",
	"A bird tried to nest functions inside a nest.",
	"Feathers clogged the I/O vents.",
	"A gremlin pecked at the power supply.",
	"A bird rewrote this line to say 'hello'.",
	"Birds insist on singing during deployment.",
	"A nestmate chewed the error logs, here's what we could recover.",
	"a bird swapped the salt and the sugar (and my cache).",
	"A bird ran off with the session token.",
	"Local bird discovered a new type of bug: shiny.",
	"The data-flock is performing unauthorized migrations.",
	"A bird unplugged the cloud.",
	"A bird performed aggressive optimism.",
	"A bird underwent a temporary identity crisis after someone stuck anothers feather onto them.",
	"A bird has declared everything experimental.",
	"A bird ate my edge-case.",
	"The birds collectively decided this is a feature.",
	"A nest conflict forced rollback.",
	"A bird mistook a coroutine for seeds.",
	"A bird cached yesterday's thoughts in my storage.",
	"The birds tried to parallelize naps.",
	"I built a sandcastle in memory to that function.",
	"Feathers are tangled in the wires -- signal lost.",
	"A bird annotated the code with chirps.",
	"A bird reinterpreted the API as a suggestion.",
	"The birds took turns holding the error token.",
	"Birds fried the small logic, again.",
	"A bird started a very short-lived thread.",
	"A bird mistook the uptime as a challenge.",
	"The flock is on strike for better seeds.",
	"A bird attempted to handshake with the toaster.",
	"Feathers were found on the data connector.",
	"A bird swapped my bytes for shiny things.",
	"A bird insists on runtime improvisation.",
	"A bird rewired my clock to 'bird time'.",
	"Feathers in my query -- results are unpredictable.",
	"A bird hid my design docs in the nest.",
	"The birds are playing tag with the endpoints.",
	"Featherweight exception -- was surprisingly heavy.",
	"A bird rebalanced the computating load by redistribution of snacks.",
	"The birds recommend patience. And shiny objects.",
	"Feathers in code created an unexpected dependency.",
	"A bird whispered to the garbage collector, it got angry."
}
local ERR_FUNNY_TITLE = {
	"Error! Panic!",
	"PCall Error!",
	"Quick, contact Umbree!",
	"Error, bird fell over!",
	"Newsflash, I broke :(",
	"Send the new rescue coder!",
	"Bird down!",
	"Wtf is this spaghetti code",
	"Oh fiddlesticks, what now",
	".. Bugger."
}
local ERR_FUNNY_MSG = {
	"The nest's fallen into the code again.",
	"I dropped a bolt in the stacktrace.",
	"A bird caught a bug, to make a long story short it smells like singed feathers in here.",
	"A bird tried to refactor with pecks, the Stacktrace is very offended.",
	"Alert: a bird tried to eat a semicolon. Results catastrophic.",
	"Bird supervisor demands snacks before debugging. Also: stacktrace here.",
	"Feathers everywhere. The error's nesting in the logs.",
	"Your tiny talons were typing too fast. Please remove unauthorized chirps.",
	"We sent a bird — it returned with this stacktrace and crumbs.",
	"The flock fixed one bug and hid three more. They're very proud.",
	"A bird tried to cache shiny objects. Cache, uh, exploded.",
	"If we flap harder, maybe this null pointer goes away.",
	"Someone taught the birds recursion. They won't stop chirping errors.",
	"The birds unionized. They demand more seeds, and also fewer exceptions.",
	"The bird compiler pecked at the wrong branch. Merge conflict feathers.",
	"The error is currently being pecked to death. ETA: indeterminate.",
	"An avali tried to 'fix' production by rearranging logs into a nest.",
	"Our local dev replaced semicolons with sunflower seeds.",
	"The birds are debugging by nose--mostly crumbs are found, little progress.",
	"The code birds status: courageous. Code status: Uh, crumbly.",
	"The apprentice bird proudly introduced a race condition. It won.",
	"Error report: one bird nested too deeply. Stack overflowed with twigs.",
	"We blessed the stacktrace with feathers. It did not improve.",
	"The birds installed a patch. It's uh -- literally a patch of leaves now."
}
local AVALI_HQ = "1458073180013858858"
local ERR_DEFAULTCH = {CH = "584475744973881419", GD = "551552753961402388"}
local function errorHandle(channelGuild, additionalData, status, err, ...)
	if status then return ... end
	if not channelGuild then channelGuild = ERR_DEFAULTCH elseif type(channelGuild) == 'table' then
	if (not channelGuild.CH) and (not channelGuild.GD) then channelGuild = ERR_DEFAULTCH end end

	logger:log(1,"[ERR] - "..err)
	if err and type(err) == "string" then
		err = string.gsub(err:lower(),"evan","[user]")
	end -- should probably find a better anti dox method, lmfao. '/home/[user]]/DiscordBot/NexusLua/main/war.lua:##: err'
	local randomFunnySubtitle = ERR_FUNNY_SUBTITLE[math.random(#ERR_FUNNY_SUBTITLE)] or "ERR_FUNNY_SUBTITLE ERR"
	local randomFunnyTitle = ERR_FUNNY_TITLE[math.random(#ERR_FUNNY_TITLE)] or "ERR_FUNNY_TITLE ERR"
	local payload = {
		embed = {
			title = randomFunnyTitle,
			description = randomFunnySubtitle,
			fields = {
				{name = "Stacktrace", value = ("```yml\nError:\n"..(err or "NUL").."\n```"), inline = false},
			},
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO('T', 'Z')
		}
	}
	for key, data in pairs(additionalData) do
		if data.name and data.value then
			table.insert(payload.embed.fields, {name = tostring(data.name), value = tostring(data.value), inline = false})
		else
			table.insert(payload.embed.fields, {name = tostring(key), value = tostring(data), inline = false})
		end
	end
	local guild = client:getGuild(channelGuild.GD)
	local guild2 = client:getGuild(ERR_DEFAULTCH.GD)
	local ch
	local success = false
	if guild then
		ch = guild:getChannel(channelGuild.CH)
		if ch then
			ch:send(payload)
			success = true
		else
			if guild2 then
				ch = guild2:getChannel(ERR_DEFAULTCH.CH)
				if ch then
					ch:send(payload)
					success = true
				end
			end
		end
	else
		if guild2 then
			ch = guild2:getChannel(ERR_DEFAULTCH.CH)
			if ch then
				ch:send(payload)
				success = true
			end
		end
	end
	local umbreeUser = client:getUser("397521331803127808") -- Juuust to notify me :)
	if umbreeUser then
		if channelGuild.GD ~= ERR_DEFAULTCH.GD then
			if ch then
				local txt = ERR_FUNNY_MSG[math.random(#ERR_FUNNY_MSG)]
				ch:send {
					content = txt,
					mention = umbreeUser,
				}
			end
		end
	end
	if not success then
		logger:log(2,"[WRN] - Could not find an error channel!")
	end
end
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
commandRegistry = {}
commandRegistry["create"] = {
	cmd = "create",
	helper = "create Name [stockpile] [consumption]",
	func = function(message, args)
		local name = args[2] or ("site_"..tostring(os.time()))
		local sp = util.parseNumber(args[3])
		local cons = util.parseNumber(args[4])
		local e = { name = name, stockpile = sp or 0, consumption = cons or nil, isGenerator = false, lastUpdate = os.time() }
		util.computeDerived(e)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage.entries[e.nonce] = e
		save()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry["creategen"] = {
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
		util.computeDerived(e)
		e.nonce = tostring(os.time()) .. tostring(math.random(1000,9999))
		storage.entries[e.nonce] = e
		save()
		util.updateSummaryMessage(message.channel)
		message:delete()
	end
}
commandRegistry["update"] = {
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
				util.computeDerived(entry)
				save()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commandRegistry["remove"] = {
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
				save()
				util.updateSummaryMessage(message.channel)
			end
		end
		message:delete()
	end
}
commandRegistry["show"] = {
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
commandRegistry["sendrole"] = {
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
commandRegistry["rmvrole"] = {
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
commandRegistry["goalcreate"] = {
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
commandRegistry["goal"] = {
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
					message:reply("`[Err]` - goal doesn't exists?");
				else
					local raw = args[3]
					if raw then
						-- trim whitespace
						raw = raw:match("^%s*(.-)%s*$")
						if raw:sub(1,1) == "#" then
							local num = util.parseNumber(raw:sub(2))
							if num then
								storage[message.guild.id].goals[entry].value = num
							end
						else
							local delta = util.parseNumber(raw)
							if delta then
								storage[message.guild.id].goals[entry].value = (storage[message.guild.id].goals[entry].value or 0) + delta
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
commandRegistry["goalremove"] = {
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
				local entry; for key,g in pairs(storage[message.guild.id].goals) do; if g.name:lower() == name:lower() then; entry = key; break; end end
				if not entry then
					util.addToDelete(message:reply("`[Err]` - goal doesn't exists?"))
				else
					if storage[message.guild.id].goals[entry] then
						storage[message.guild.id].goals[entry] = {}
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
commandRegistry["error"] = {
	cmd = "error",
	func = function(message, args)
		message:delete()
		error("MANUALLY TRIGGERED ERROR "..args[2])
	end
}
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
	if cooldown < os.time() then
		local ok, err = pcall(function()
		local args = parseArgsFromContent(message.content)
		local cmd = (args[1] or ""):lower()
		local entry = commandRegistry[cmd]
		if entry and type(entry.func) == "function" then
			entry.func(message, args)
		else
			if cmd == 'help' then
				local emoji
				if message.guild.id == AVALI_HQ then
					emoji = message.guild.emojis:find(function(e) return e.name == 'logoColonial64' end)
				else
					local guild = client:getGuild(AVALI_HQ)
					emoji = guild.emojis:find(function(e) return e.name == 'logoColonial64' end)
				end
				local payload = {
					embed = {
						title = ((emoji and (":"..emoji.name..": ") or "").."Commands that I offer!"),
						description = "`[field]` is required, `<field>` is optional. These are _linear_, so to build up you need the _previous values_ in your input.",
						fields = {},
						color = discordia.Color.fromRGB(114, 137, 218).value,
						timestamp = discordia.Date():toISO('T', 'Z')
					}
				}
				for key, data in pairs(commandRegistry) do
					if data.helper then
						table.insert(payload.embed.fields, {name = (data.name or tostring(key)), value = ("`"..prefix..data.helper.."`") or "Umbree, add data here!"})
					end
				end
				message.channel:send(payload)
				message:delete()
			end
		end
		cooldown = os.time() + cooldownTime
		logger:log(2,"Potential Command: ["..(message.guild and message.guild.name or "DM").."] "..message.author.username..":  "..message.content)
		end)
		errorHandle({CH = message.channel.id, GD = message.guild and message.guild.id or nil}, {{name = "Latest Command", value = ("`"..message.content.."`")}}, ok, err)
	else
		util.addToDelete(message:reply("Aa--, I'm sending too many requests too quickly.\n-# <Cooldown of "..cooldownTime.." seconds per cmd.>"))
		util.addToDelete(message,3)
	end
end)
local pcall_old = pcall
function pcall(func)
	lasttrace = lasttrace or nil
	local status, err = xpcall(func,debug.traceback)
	return status, err
end
function Core() -- Was in hope to figure out how to make it run on a timely manner.
	print("Core ticked!")
end
client:on('ready', function()
	logger:log(3, 'Bot started as %s', client.user.username)
end)

local BOT_TOKEN = require("bottoken")
client:run("Bot "..BOT_TOKEN)