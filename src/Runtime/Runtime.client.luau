local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Startup = require(script.Startup)

local controllersFolder = ReplicatedStorage.Client.Controllers


Startup(controllersFolder, "Controller", {
	modulePredicate = function(moduleScript)
		return true
	end,
})