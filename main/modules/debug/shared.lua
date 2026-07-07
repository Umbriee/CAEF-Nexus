local m = {}
m.module = {
	name = "Debugging/General",
	desc = "Commands, utility functions, or otherwise to test the general features of the bot.",
	version = "1.0",
	-- hidehelp = true
}
m.commands = {}
m.commands["error"] = {
	cmd = "error",
	helper = "error <field> -- manually triggers an error for my own debugging purposes",
	perms = {"manageChannels"},
	func = function(message, args)
		message:delete()
		error("MANUALLY TRIGGERED ERROR '"..(args[2] or "NaN").."'")
	end
}
m.commands["addlogchannel"] = {
	cmd = "addlogchannel",
	helper = "addlogchannel -- registers the messaged channel to be a sort of 'botlog' that will be sent messages when things are updated or otherwise.",
	perms = {"manageChannels"},
	func = function(message, args)
		local guildId = message.guild.id
		BOT_STORAGE[guildId].logChannel = message.channel.id
		saveData()
		message:replydel("Channel successfully marked as a log channel for "..message.guild.name..".",10)
		message:delete()
	end
}
m.util = {}
function m.util:logInChannel(guildId, payload)
	if not guildId or not payload then return end
	local logChannel = BOT_STORAGE[guildId].logChannel
	if logChannel then
		local ch = client:getChannel(logChannel)
		if ch then
			ch:sendq(payload,nil,nil,true)
		end
	end
end
m.event = {}
return m