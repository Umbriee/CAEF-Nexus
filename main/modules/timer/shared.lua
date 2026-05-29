--[[commandRegistry.cmds["settimer"] = {
	cmd = "settimer",
	--helper = "settimer [name] [time] -- registers an alarmclock for time sensitive details. Name is for storing or organization.",
	fields = {"string","time"},
	func = function(message, args)

	end
}
util.timers = {}
function util.makeTimer(guildId,name,time)
	
end--]]