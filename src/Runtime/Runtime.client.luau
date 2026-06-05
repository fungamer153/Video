local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Startup = require(script.Startup)

local controllersFolder = ReplicatedStorage.Client.Controllers
local conch = require(ReplicatedStorage.Packages.Conch)
local ui = require(ReplicatedStorage.Packages.ConchUI)

Startup(controllersFolder, "Controller", {
	modulePredicate = function(moduleScript)
		return true
	end,
})

conch.initiate_default_lifecycle()
ui.bind_to(Enum.KeyCode.Backquote)
