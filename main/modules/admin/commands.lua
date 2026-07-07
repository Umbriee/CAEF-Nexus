local commands = {}
commands["addticket"] = {
	cmd = "addticket",
	helper = "addticket -- add an admin ticket to be handled. Use this if you have a problem you wish to privately discuss!",
	func = function(message, args)
		message:replydel("This is a WIP module. To be more added! Uhh-- Dm someone I suppose.")
		message:delete()
	end
}
commands["markticketcategory"] = {
	cmd = "markticketcategory",
	helper = "markTicketCategory [name] -- Marks category as a ticket category to auto generate text channels when tickets come in.",
	perms = {"manageChannels"},
	func = function(message, args)
		local arg = args[2]
		if (not arg) or (arg == "") then 
			message:replydel("Usage: `"..BOT_PREFIX.."markticketcategory` `[category name]`\n-# Not case sensitive. If the category has spaces sorround it with quotation marks!")
			util:addToDelete(message)
			return
		end
		arg = arg:lower()
		local category = nil
		for id, obj in pairs(message.guild.categories) do if obj.name:lower() == arg then category = obj break end end
		if not category then
			message:replydel("Couldn't find the listed category, apologies.")
			util:addToDelete(message)
			return
		else
			print(category)
			-- BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
			-- BOT_STORAGE[message.guild.id].ticketCategory = nil
			-- saveData()
			message:replydel("This is where I would do something. If I had an idea.")
			util:addToDelete(message)
		end
	end
}
return commands