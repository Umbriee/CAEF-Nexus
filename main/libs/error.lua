local errorHandler = {}

local ERR_FUNNY_TITLE = {
	"Error! Panic!",
	"PCall Error!",
	"Quick, contact Umbree!",
	"Error, bubba fell over!",
	"Newsflash, I broke :(",
	"Send the new rescue coder!",
	"Man down!",
	"Wtf is this spaghetti code",
	"Oh fiddlesticks, what now",
	".. Bugger."
}
local ERR_FUNNY_SUBTITLE = {
	"Runtime errors, in your code? Its more likely than you think!",
	"I've seen worse.",
	"Major ~~lacerations~~runtime errors detected.",
	"And everything was going so perfectly!",
	"Dr Breerb.",
	"Who did it this time?",
	"I should improve this stack trace function.",
	"Runtime Error cascade stopped!",
	"This was not in the plan..",
	"Antlions are in the code.",
	"This is the purest error we've seen yet.",
	"Now it *could* do that. But I won't let it.",
	"Now. Could this be a bug or a feature?",
	"Uranium-235 has a Half-Life of 704 million years.\nWhat? Here's a random fact for you as I error out!",
	"Eeh, at least things are running still. Try again?",
	"I never thought I'd see a resonance cascade, let alone create one..",
	"Hey, I'm still running.. I think. Try again, will it go the same way?",
	"The right line in the wrong place can make all of the errors in the world."
}
local ERR_FUNNY_MSG = {
	"Black Mesa called. They want the bug back.",
	"My HEV suit says this trace is bad news.",
	".. I broke :(",
	"Umbree's bot, found errored in Detroit.",
	"I'm not sure how this happened, to be honest.",
	"Heeey, more debugging for you! :)",
	"I can't look, was it Gman(Ger)?",
	"What d'ya mean, 'overcharge?'"
}
local ERR_DEFAULTCH, username = require("privateStorage.privateserver") -- {CH = "ChannelID", GD = "GuildID"}, sort of a backup for me incase it errors out in a funny way to let me know. Other than a console check. Also username because stacktrace sometimes reveals my username in the full path, I have smart working directories :)
local function scrub(err)
	if not err or type(err) ~= "string" then return err end
	local s = err
	s = s:gsub("\\", "/")
	s = s:gsub("(/[%w%-%._%+]+/[%w%-%._%+%/]*/[%w%-%._%+]+:%d+)", function(pathline)
		local file_line = pathline:match("([^/]+:%d+)$")
		return "../" .. (file_line or pathline)
	end)
	s = s:gsub("(/[%w%-%._%+]+/[%w%/%-%._%+]+:%d+)", function(pathline)
		local file_line = pathline:match("([^/]+:%d+)$")
		return "../" .. (file_line or pathline)
	end)
	s = s:gsub("/%.%.%./+", "/../")
	s = s:gsub("/%.%.+/", "/../")
	s = s:gsub("([%w%-%._%+]+%.lua:%d+)", function(fl) return "../" .. fl end)
	if username and username ~= "" then
		local uname = username:gsub("([^%w_%-])", "%%%1")
		s = s:gsub("([%w_%-]*)" .. uname .. "([%w_%-]*)", function(pre, post)
			if pre == "" and post == "" then return "../Nexuslua" end
			return pre .. "../Nexuslua" .. post
		end)
		s = s:gsub(username:lower(), "../Nexuslua")
		s = s:gsub(username:upper(), "../Nexuslua")
	end
	return s
end
function errorHandler.errorHandle(channelGuild, additionalData, status, err, ...)
	local sent
	if status then return ... end
	if not channelGuild then channelGuild = ERR_DEFAULTCH elseif type(channelGuild) == 'table' then
	if (not channelGuild.CH) and (not channelGuild.GD) then channelGuild = ERR_DEFAULTCH end end

	logger:log(1,err)
	local scrubbedErr = scrub(err)
	local randomFunnySubtitle = ERR_FUNNY_SUBTITLE[math.random(#ERR_FUNNY_SUBTITLE)] or "ERR_FUNNY_SUBTITLE ERR"
	local randomFunnyTitle = ERR_FUNNY_TITLE[math.random(#ERR_FUNNY_TITLE)] or "ERR_FUNNY_TITLE ERR"
	local payload = {
		embed = {
			title = ("[ERR] "..randomFunnyTitle),
			description = randomFunnySubtitle.."\n-# - Auto-Delete in "..util:timeTill(60),
			fields = {
				{name = "Stacktrace", value = ("```yml\nError:\n"..(scrubbedErr or "NUL").."\n```"), inline = false},
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
			ch:senddel(payload,60)
			success = true
		else
			if guild2 then
				ch = guild2:getChannel(ERR_DEFAULTCH.CH)
				if ch then
					sent = ch:senddel(payload,60)
					success = true
				end
			end
		end
	else
		if guild2 then
			ch = guild2:getChannel(ERR_DEFAULTCH.CH)
			if ch then
				sent = ch:senddel(payload,10)
				success = true
			end
		end
	end
	local umbreeUser = client:getUser("397521331803127808") -- Juuust to notify me :)

	if umbreeUser then
		if channelGuild.GD ~= ERR_DEFAULTCH.GD then
			if ch then
				local umbeeFound = false
				for key, data in pairs(ch.guild.members) do
					local userId = data.id
					if userId == umbreeUser.id then
						umbeeFound = true
						break
					end
				end
				if umbeeFound then
					local txt = ERR_FUNNY_MSG[math.random(#ERR_FUNNY_MSG)]
					ch:send {
						content = txt,
						mention = umbreeUser,
					}
				end
			end
		end
	end
	if not success then
		logger:log(2,"Could not find an error channel!")
	end
	return sent or false
end

return errorHandler