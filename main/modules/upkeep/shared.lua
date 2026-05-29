-- made weirdly as per it being a working example. --
local m = {}
m.module = { -- Mostly flavortext in the help section.
	name	= "Upkeep",
	desc	= "Allows you to keep upkeep.",
	version	= "1.0"
}
-- Runs right after being loaded
function m.init()
end
local current_file = string.gsub(debug.getinfo(1, "S").source,"/shared.lua","")
m.commands	= require(current_file.."/commands")
m.event		= require(current_file.."/events")
m.util		= require(current_file.."/util")
return m