local storage = storage or {}
local discordia = discordia or nil
local client = client or nil
-- Don't like these. I hate multi file but I want to stay decently organized now.
local util = {}

function util.init(discordia_in, client_in, storage_in)
  discordia = discordia_in
  client = client_in
  storage = storage_in
end

function util.parseNumber(s)
	if not s then return nil end
	s = s:lower():gsub(',','')
	local mult = 1
	if s:match('k$') then mult = 1000; s = s:sub(1, -2) end
	local num = tonumber(s)
	if not num then return nil end
	return num * mult
end
function util.parseRecipeTime(t)
	if not t then return nil end
	if t:find(':') then
		local m,sec = t:match('^(%d+):(%d+)$')
		if m and sec then return tonumber(m) + tonumber(sec)/60 end
		return nil
	else
		return tonumber(t)
	end
end
function util.formatShort(n)
	if not n then return "N/A" end
	if type(n) ~= "number" then return tostring(n) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end
	return tostring(math.floor(n*10)/10)
end
function util.formatTime(n)
	if n == nil then return "N/A" end
	if type(n) ~= "number" then return tostring(n) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end

	local minutes = math.floor(n)
	local seconds = math.floor((n - minutes) * 60 + 0.5)
	if seconds >= 60 then
		minutes = minutes + 1
		seconds = seconds - 60
	end
	return string.format("%d:%02d", minutes, seconds)
end
function util.computeDerived(e)
	local sp = tonumber(e.stockpile) or 0
	local cons = tonumber(e.consumption)
	local rcalls = tonumber(e.recipeCalls)
	local rmins = tonumber(e.recipeMins)
	if sp > 0 and rcalls and rmins and rcalls > 0 and rmins > 0 then
		e.time_h = ((sp / rcalls) * rmins) / 60
		e.msupp12 = (12 * 60 * rcalls) / rmins
		e.msupp24 = (24 * 60 * rcalls) / rmins
		e.msupp48 = (48 * 60 * rcalls) / rmins
	elseif sp > 0 and cons and cons > 0 then
		e.time_h = sp / cons
		e.msupp12 = cons * 12
		e.msupp24 = cons * 24
		e.msupp48 = cons * 48
	else
		e.time_h = e.time_h or 0
		e.msupp12 = e.msupp12 or 0
		e.msupp24 = e.msupp24 or 0
		e.msupp48 = e.msupp48 or 0
	end
	if not e.lastUpdate then e.lastUpdate = os.time() end
	e.unixTime = math.floor((e.lastUpdate + (e.time_h * 3600))) or os.time()
	--if e.time_h then e.time_h = math.floor(e.time_h*10)/10 end
	for _,k in ipairs({'msupp12','msupp24','msupp48'}) do if e[k] then e[k]=math.floor(e[k]*10)/10 end end
	if not e.isGenerator then
		logger:log(3,"Computing MSupp site: "..e.name.." with "..util.formatShort(sp).." in stockpile, with a "..cons.." hourly rate.")
	else
		logger:log(3,"Computing Gen   Site: "..e.name.." with "..util.formatShort(sp).." in stockpile, with a call of "..rcalls.." every "..util.formatTime(rmins or -1)..".")
	end
end
function util.renderEmbed(e)
	local color_ok = discordia.Color.fromRGB(114,137,218).value
	local color_warn = discordia.Color.fromRGB(255,80,80).value
	local color = (tonumber(e.time_h or 0) < 12) and color_warn or color_ok
	local fields = {
		{ name = "Site/Gen", value = e.name or "N/A", inline = true },
		{ name = "Stockpile", value = tostring(e.stockpile or "N/A"), inline = true },
		{ name = "Consumption / Calls", value = tostring(e.consumption or e.recipeCalls or "N/A"), inline = true },
		{ name = "Time (h)", value = tostring(e.time_h or "N/A"), inline = true },
		{ name = "Recipe (calls/mins)", value = (e.recipeCalls and e.recipeMins) and (tostring(e.recipeCalls).." / "..tostring(e.recipeMins)) or "N/A", inline = true },
		{ name = "MSupp (12/24/48)", value = table.concat({tostring(e.msupp12 or "N/A"), tostring(e.msupp24 or "N/A"), tostring(e.msupp48 or "N/A")}, " / "), inline = false },
	}
	return { embed = { title = (e.isGenerator and "Generator — " or "MSupp — ")..(e.name or "Unknown"), fields = fields, color = color, timestamp = discordia.Date():toISO('T','Z') } }
end
function util.buildSummaryEmbed()
	local msupps = {}
	local gens = {}
	local lowestM = nil -- storing like { time = num, entry = site } yadda yadda
	local lowestG = nil
	local totals = {m = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}, g = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}}
	for _,e in pairs(storage.entries) do
		local stockpile = tonumber(e.stockpile) or 0
		local ms12 = tonumber(e.msupp12) or 0
		local ms24 = tonumber(e.msupp24) or 0
		local ms48 = tonumber(e.msupp48) or 0
		local time_h = math.floor(tonumber(e.time_h)*10)/10
		if e.isGenerator then 
			table.insert(gens, e)
			totals.g.stockpile = totals.g.stockpile + stockpile
			totals.g.msupp12 = totals.g.msupp12 + ms12
			totals.g.msupp24 = totals.g.msupp24 + ms24
			totals.g.msupp48 = totals.g.msupp48 + ms48
			if not lowestG or time_h < lowestG.time then
				lowestG = { time = time_h, entry = e }
			elseif not lowestG then
				lowestG = { time = time_h, entry = e }
			end
		else
			table.insert(msupps, e)
			totals.m.stockpile = totals.m.stockpile + stockpile
			totals.m.msupp12 = totals.m.msupp12 + ms12
			totals.m.msupp24 = totals.m.msupp24 + ms24
			totals.m.msupp48 = totals.m.msupp48 + ms48
			if not lowestM or time_h < lowestM.time then
				lowestM = { time = time_h, entry = e }
			elseif not lowestM then
				lowestM = { time = time_h, entry = e }
			end
		end
		if not e.lastUpdate then e.lastUpdate = os.time() end
	end
	local function name_cmp(a,b)
		local na = (a.name or ""):lower()
		local nb = (b.name or ""):lower()
		return na < nb
	end
	table.sort(gens, name_cmp)
	table.sort(msupps, name_cmp)
	local fields = {}
	--==[ Totals MSupp ]==--
	table.insert(fields, { name = "Totals (Stockpile | MSupp [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
		util.formatShort(totals.m.stockpile), util.formatShort(totals.m.msupp12), util.formatShort(totals.m.msupp24), util.formatShort(totals.m.msupp48)), inline = false })

	--==[ MSupps Spreadsheet ]==-- 
	if #msupps > 0 then
		local lowestUnixTimeM = lowestM.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(msupps) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "!") or "+"
			table.insert(lines, string.format("%s %s, %s| >%sh |%sm/hr| %s, %s, %s", 
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(e.time_h or "N/A"), e.consumption, 
					util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(msupps) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "MSupp Sites",		value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Update Times",		value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestM.entry.name.." has >"..tostring(lowestM.time).."h, will run out ~<t:"..lowestUnixTimeM..":R>"), inline = false })
	end
	--==[ Totals Generators ]==--
	table.insert(fields, { name = "Totals (Stockpile | Fuel [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
		util.formatShort(totals.g.stockpile), util.formatShort(totals.g.msupp12), util.formatShort(totals.g.msupp24), util.formatShort(totals.g.msupp48)), inline = false })
	
	--==[ Generators Spreadsheet ]==--
	if #gens > 0 then
		local lowestUnixTimeG = lowestG.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(gens) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "! ") or "+ "
			table.insert(lines, string.format("%s %s, %s| >%sh |%sx%sm| %s, %s, %s",
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(e.time_h or "N/A"),
					tostring(e.recipeCalls or "N/A"), util.formatTime(e.recipeMins or -1),
						util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(gens) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "Generators",			value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Lowest Gen Site",	value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestG.entry.name.." has >"..tostring(lowestG.time).."h, will run out ~<t:"..lowestUnixTimeG..":R>"), inline = false })
	end

	return {
		embed = {
			title = "Logistics Summary",
			description = "Summary of MSupps and Generators",
			fields = fields,
			color = discordia.Color.fromRGB(114,137,218).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.updateSummaryMessage(channel)
	local payload = util.buildSummaryEmbed()
	local saved = storage.savedSummary
	if saved.messageId and saved.channelId then
		local ok, err = pcall(function()
			local ch = client:getChannel(saved.channelId)
			if ch then
				local msg = ch:getMessage(saved.messageId)
				if msg and msg.author == client.user then
					msg:setContent(payload.content or "")
					msg:setEmbed(payload.embed)
					return true
				end
			end
			return false
		end)
		if ok then save(); return end
	end
	local target = channel
	if not target then
		if saved.channelId then target = client:getChannel(saved.channelId) end
	end
	if not target then return end
	local sent = target:send(payload)
	if sent then
		storage.savedSummary = { channelId = target.id, messageId = sent.id }
		save()
	end
end
function util.buildGoalEmbed(guildObj)
	local goals = storage[guildObj.id].goals
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
			title = "Current Server Goals",
			description = "Goal summary for "..(guildObj.name),
			fields = fields,
			color = discordia.Color.fromRGB(94, 180, 121).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function util.addToDelete(message, timeToDelete)
	local tim = (timeToDelete or 2.5) + os.time()
	local data = {[1] = message, [2] = tim}
	table.insert(todelete,data)
	logger:log(3, 'Added message to delete table in '..(timeToDelete or 2.5)..'s')
end

return util