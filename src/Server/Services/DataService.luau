local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Lyra = require(ServerScriptService.ServerPackages.Lyra)
local ProfileTemplate = require(ServerScriptService.Server.Modules.ProfileTemplate)
local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)

local function getName()
	if RunService:IsStudio() then
		return "studio1"
	end

	return "production"
end

local playerStore = Lyra.createPlayerStore({
	name = `playerdata/{getName()}`,
	template = ProfileTemplate.template,
	schema = ProfileTemplate.schema,
	useMock = RunService:IsStudio(),
})

local DataService = {}

function DataService.onStart()
	Players.PlayerAdded:Connect(function(player)
		playerStore:loadAsync(player)
		player:SetAttribute("Loaded", true)
		ServerEvents.fire("PlayerJoined", { player = player })
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStore:unloadAsync(player)
		ServerEvents.fire("PlayerLeft", { player = player })
	end)

	game:BindToClose(function()
		playerStore:closeAsync()
	end)
end

function DataService.get(player: Player)
	return playerStore:getAsync(player)
end

function DataService.update(player: Player, fn: (data: any) -> boolean)
	return playerStore:updateAsync(player, fn)
end

return DataService
