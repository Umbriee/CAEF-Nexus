local moduleutil = {}
function moduleutil.computeDerived(e, guildId)
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
		local txt = "Computing MSupp site: '"..e.name.."' with "..util.formatShort(sp).." in stockpile, and "..cons.."MSupps at an hourly rate."
		util.logInChannel(guildId, txt)
		logger:log(3,txt)
	else
		local txt = "Computing Gen   Site: '"..e.name.."' with "..util.formatShort(sp).." in stockpile, with a call of "..rcalls.." every "..util.formatTime(rmins or -1).."."
		util.logInChannel(guildId, txt)
		logger:log(3,txt)
	end
end
function moduleutil.renderEmbed(e)
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
function moduleutil.buildSummaryEmbed(guildId)
	local msupps = {}
	local gens = {}
	local lowestM = nil -- storing like { time = num, entry = site } yadda yadda
	local lowestG = nil
	local totals = {m = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}, g = {stockpile = 0, msupp12 = 0, msupp24 = 0, msupp48 = 0}}
	for _,e in pairs(BOT_STORAGE[guildId].upkeepEntries) do
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
	--==[ MSupps Spreadsheet ]==-- 
	if #msupps > 0 then
		table.insert(fields, { name = "Totals (Stockpile | MSupp [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
			util.formatShort(totals.m.stockpile), util.formatShort(totals.m.msupp12), util.formatShort(totals.m.msupp24), util.formatShort(totals.m.msupp48)), inline = false })

		local lowestUnixTimeM = lowestM.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(msupps) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "!") or "+"
			table.insert(lines, string.format("%s %s, %s | >%sh |%sm/hr| %s, %s, %s", 
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(util.roundNumber(e.time_h) or "N/A"), e.consumption, 
					util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(msupps) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "<:MaintenanceSuppliesIcon:1501480687251750952> MSupp Sites",		value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Update Times",		value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestM.entry.name.." has >"..tostring(lowestM.time).."h, will run out ~<t:"..lowestUnixTimeM..":R>"), inline = false })
	end
	
	--==[ Generators Spreadsheet ]==--
	if #gens > 0 then
		table.insert(fields, { name = "Totals (Stockpile | Fuel [12, 24, 48])", value = string.format("`%s`  | `%s`, `%s`, `%s`",
			util.formatShort(totals.g.stockpile), util.formatShort(totals.g.msupp12), util.formatShort(totals.g.msupp24), util.formatShort(totals.g.msupp48)), inline = false })
		local lowestUnixTimeG = lowestG.entry.unixTime or os.time()
		local lines = {}
		for _,e in ipairs(gens) do
			local time = tonumber(e.time_h) or 0
			local tcol = (time < 24) and ((time < 12) and "- ⚠" or "! ") or "+ "
			table.insert(lines, string.format("%s %s, %s | >%sh |%sx%sm| %s, %s, %s",
				tcol, e.name, util.formatShort(tonumber(e.stockpile) or 0), tostring(util.roundNumber(e.time_h) or "N/A"),
					tostring(e.recipeCalls or "N/A"), util.formatTime(e.recipeMins or -1),
						util.formatShort(tonumber(e.msupp12) or 0), util.formatShort(tonumber(e.msupp24) or 0), util.formatShort(tonumber(e.msupp48) or 0)))
		end
		local lines2 = {}
		for _,e in ipairs(gens) do
			table.insert(lines2,string.format("%s last updated %s | ETA to runout %s", e.name, ("<t:"..(e.lastUpdate or os.time())..":R>"), ("<t:"..(e.unixTime or os.time())..":R>")))
		end
		table.insert(fields, { name = "<:Orders:1501481297544220673> Generators",			value = "```diff\n" .. table.concat(lines, "\n") .. "\n```", inline = false })
		table.insert(fields, { name = "Lowest Gen Site",	value = ("-# - "..table.concat(lines2, "\n-# - ").."\nLowest Site:\n- "..lowestG.entry.name.." has >"..tostring(lowestG.time).."h, will run out ~<t:"..lowestUnixTimeG..":R>"), inline = false })
	end
	if #fields <= 0 then
		table.insert(fields, { name = "No data", value = "No data found. Is this a mistake?", inline = false })
	end

	return {
		embed = {
			title = "<:Orders:1501481297544220673> Logistics Summary",
			description = "Summary of MSupps and Generators\n-# Use either; `!create` `!creategen` or `!update` to get more info on how to write to the logi-summary",
			fields = fields,
			color = discordia.Color.fromRGB(114,137,218).value,
			timestamp = discordia.Date():toISO('T','Z')
		}
	}
end
function moduleutil.updateSummaryMessage(channel)
	local payload = util.buildSummaryEmbed(channel.guild.id)
	local saved = BOT_STORAGE[channel.guild.id].savedSummary or {}
	if saved.messageId and saved.channelId then
		local ok, err = safeCall(function()
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
		if ok then saveData(); return end
	end
	local target = channel
	if not target then
		if saved.channelId then target = client:getChannel(saved.channelId) end
	end
	if not target then return end
	local sent = target:send(payload)
	if sent then
		BOT_STORAGE[channel.guild.id].savedSummary = { channelId = target.id, messageId = sent.id }
		saveData()
	end
end
return moduleutil