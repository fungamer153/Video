local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

local liveBarFilled = ReplicatedStorage:WaitForChild("LiveBarFilled")

local MIN_VIEWERS_REWARD = 30
local MAX_VIEWERS_REWARD = 80
local COOLDOWN_SECONDS = 2

local lastRewardTime: { [Player]: number } = {}

local LiveService = {}

local function onBarFilled(player: Player)
	local lastTime = lastRewardTime[player]
	if lastTime and os.clock() - lastTime < COOLDOWN_SECONDS then
		return
	end

	lastRewardTime[player] = os.clock()

	local viewersGained = math.random(MIN_VIEWERS_REWARD, MAX_VIEWERS_REWARD)
	ProfileService.addViewers(player, viewersGained)
end

function LiveService.onStart()
	liveBarFilled.OnServerEvent:Connect(onBarFilled)

	game.Players.PlayerRemoving:Connect(function(player)
		lastRewardTime[player] = nil
	end)
end

return LiveService
