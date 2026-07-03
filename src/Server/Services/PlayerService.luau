local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local ServerNetwork = require(ServerScriptService.Server.Modules.ServerNetwork)
local DataService = require(ServerScriptService.Server.Services.DataService)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

local tutorialCompleteRemote = ReplicatedStorage:WaitForChild("TutorialComplete")

local PlayerService = {}

local function onPlayerJoined(player: Player)
	local profileData = DataService.get(player)
	if not profileData then
		warn("Failed to get profile data for", player.Name)
		return
	end

	if not profileData.tutorialComplete then
		ServerNetwork.StartTutorial.fire(player)
		return
	end

	player:SetAttribute("TutorialAlreadyComplete", true)
end

function PlayerService.onStart()
	ServerEvents.connect("PlayerJoined", function(extraData: { player: Player })
		onPlayerJoined(extraData.player)
	end)

	tutorialCompleteRemote.OnServerEvent:Connect(function(player: Player)
		ProfileService.setTutorialComplete(player, true)
	end)
end

return PlayerService
