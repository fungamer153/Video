local ServerScriptService = game:GetService("ServerScriptService")
local Startup = require(script.Startup)

local servicesFolder = ServerScriptService.Server.Services

Startup(servicesFolder, "Service", {
	modulePredicate = function(moduleScript)
		return true
	end,
})
