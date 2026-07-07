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
	helper = "markTicketCategory -- Marks category as a ticket category to auto generate text channels when tickets come in.",
	perms = {"manageChannels"},
	func = function(message, args)
		BOT_STORAGE[message.guild.id] = BOT_STORAGE[message.guild.id] or {}
		BOT_STORAGE[message.guild.id].ticketCategory = BOT_STORAGE[message.guild.id].ticketCategory or {}
		BOT_STORAGE[message.guild.id].ticketCategory = { channelId = message.channel.id, messageId = sent.id }
		message:replydel("Marked category as a ticket category!")
		saveData()
		message:delete()
	end
}
return commands