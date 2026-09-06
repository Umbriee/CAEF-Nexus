local m = {}
m.module = {
	name	= "Admin",
	desc	= "A bunch of utilities, admin commands, and otherwise automatic handling for some specific operations.",
	version	= "1.0",
	hidehelp = true
}
local current_file = string.gsub(debug.getinfo(1, "S").source,"/shared.lua","")
m.commands	= require(current_file.."/commands")
m.event		= require(current_file.."/events")
m.util		= require(current_file.."/util")
return m