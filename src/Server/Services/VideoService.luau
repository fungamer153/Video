local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ChannelService = require(ServerScriptService.Server.Services.ChannelService)
local ServerNetwork = require(ServerScriptService.Server.Modules.ServerNetwork)

local VideoService = {
	activeRecords = {},
	playerSpeedModifiers = {},
	globalSpeedModifier = 1,
}

local BASE_DURATION = 30
local TIME_INCREASE_MULTIPLIER = 1.05

function VideoService.getPlayerSpeedModifier(player: Player): number
	return VideoService.playerSpeedModifiers[player] or 1
end

function VideoService.setPlayerSpeedModifier(player: Player, modifier: number)
	VideoService.playerSpeedModifiers[player] = modifier
end

function VideoService.getGlobalSpeedModifier(): number
	return VideoService.globalSpeedModifier
end

function VideoService.setGlobalSpeedModifier(modifier: number)
	VideoService.globalSpeedModifier = modifier
end

function VideoService.getTotalSpeedModifier(player: Player): number
	return VideoService.getPlayerSpeedModifier(player) * VideoService.getGlobalSpeedModifier()
end

local function getTargetDuration(player: Player): number
	local videosMade = ChannelService.getVideoCount() or 0
	return BASE_DURATION * math.pow(TIME_INCREASE_MULTIPLIER, videosMade)
end

function VideoService.getProgress(player: Player): number
	local record = VideoService.activeRecords[player]
	if not record then
		return 0
	end
	local timePassed = os.clock() - record.startTime
	local totalProgress = (timePassed * VideoService.getTotalSpeedModifier(player)) + record.skippedSeconds
	return math.clamp(totalProgress, 0, record.totalDuration)
end

local function fireVideoComplete(player: Player)
	local record = VideoService.activeRecords[player]

	if not record or record.isFinished then
		return
	end

	record.isFinished = true
	VideoService.activeRecords[player] = nil
	VideoService.completeVideo(player)
end

function VideoService.onStart()
	ServerNetwork.StartVideo.setCallback(function(player: Player, videoType: string)
		local duration = getTargetDuration(player)
		local currentSpeedModifier = VideoService.getTotalSpeedModifier(player)
		local videosMade = ChannelService.getVideoCount() or 0

		VideoService.activeRecords[player] = {
			startTime = os.clock(),
			skippedSeconds = 0,
			totalDuration = duration,
			isFinished = false,
		}

		return "Success"
	end)

	ServerNetwork.IncrementProgress.on(function(player: Player)
		local record = VideoService.activeRecords[player]
		if not record or record.isFinished then
			return
		end
		record.skippedSeconds = record.skippedSeconds + 1
	end)

	RunService.Heartbeat:Connect(function()
		for player, record in VideoService.activeRecords do
			if record.isFinished then
				continue
			end
			if VideoService.getProgress(player) >= record.totalDuration then
				fireVideoComplete(player)
			end
		end
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		VideoService.activeRecords[player] = nil
		VideoService.playerSpeedModifiers[player] = nil
	end)
end

function VideoService.completeVideo(player: Player)
	print(player.Name .. " completed their video!")
end

return VideoService
