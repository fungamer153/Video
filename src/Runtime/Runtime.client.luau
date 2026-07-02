local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Startup = require(script.Startup)

local controllersFolder = ReplicatedStorage.Client.Controllers
local player = Players.LocalPlayer

local InterfaceController = require(controllersFolder.InterfaceController)
InterfaceController.onStart()

while not player:GetAttribute("Loaded") do
	player:GetAttributeChangedSignal("Loaded"):Wait()
end

Startup(controllersFolder, "Controller", {
	modulePredicate = function(moduleScript)
		return moduleScript.Name ~= "InterfaceController"
	end,
})
