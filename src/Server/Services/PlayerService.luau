local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")

local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local ServerNetwork = require(ServerScriptService.Server.Modules.ServerNetwork)
local DataService = require(ServerScriptService.Server.Services.DataService)

local PlayerService = {}

local function onPlayerJoined(player: Player)
	local profileData = DataService.get(player)
	if not profileData then
		warn("Failed to get profile data for", player.Name)
		return
	end

	if not profileData.tutorialComplete then
		print(11111)
		ServerNetwork.StartTutorial.fire(player)
		return
	end

	-- player has completed the tutorial
end

function PlayerService.onStart()
	ServerEvents.connect("PlayerJoined", function(extraData: { player: Player })
		onPlayerJoined(extraData.player)
	end)
end

return PlayerService
