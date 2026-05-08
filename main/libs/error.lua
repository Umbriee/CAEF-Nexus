local errorHandler = {}

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
local function scrub(err)
	if not err or type(err) ~= "string" then return err end
	local username = 'evan' -- lmfao, hello y'all on my git.
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
local ERR_DEFAULTCH = {CH = "584475744973881419", GD = "551552753961402388"}
function errorHandler.errorHandle(channelGuild, additionalData, status, err, ...)
	local sent
	if status then return ... end
	if not channelGuild then channelGuild = ERR_DEFAULTCH elseif type(channelGuild) == 'table' then
	if (not channelGuild.CH) and (not channelGuild.GD) then channelGuild = ERR_DEFAULTCH end end

	logger:log(1,"[ERR] - "..err)
	local scrubbedErr = scrub(err)
	local randomFunnySubtitle = ERR_FUNNY_SUBTITLE[math.random(#ERR_FUNNY_SUBTITLE)] or "ERR_FUNNY_SUBTITLE ERR"
	local randomFunnyTitle = ERR_FUNNY_TITLE[math.random(#ERR_FUNNY_TITLE)] or "ERR_FUNNY_TITLE ERR"
	local payload = {
		embed = {
			title = ("[ERR] "..randomFunnyTitle),
			description = randomFunnySubtitle,
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
			util.addToDelete(ch:send(payload),10)
			success = true
		else
			if guild2 then
				ch = guild2:getChannel(ERR_DEFAULTCH.CH)
				if ch then
					sent = util.addToDelete(ch:send(payload),10)
					success = true
				end
			end
		end
	else
		if guild2 then
			ch = guild2:getChannel(ERR_DEFAULTCH.CH)
			if ch then
				sent = util.addToDelete(ch:send(payload),10)
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
		logger:log(2,"[WRN] - Could not find an error channel!")
	end
	return sent or false
end

return errorHandler