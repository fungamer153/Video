local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ChannelService = require(ServerScriptService.Server.Services.ChannelService)
local ServerNetwork = require(ServerScriptService.Server.Modules.ServerNetwork)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

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
	VideoService.completeVideo(player, record.topic)
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
			topic = videoType,
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

local STAT_KEYS = { "bad", "better", "meh", "mediocre", "great", "awesome" }

function VideoService.generatePublishStats(player: Player)
	local weights = {}
	local totalWeight = 0

	for _, key in STAT_KEYS do
		local weight = math.random()
		weights[key] = weight
		totalWeight += weight
	end

	local budget = 1
	local stats = {}

	for _, key in STAT_KEYS do
		stats[key] = (weights[key] / totalWeight) * budget
	end

	return stats
end

local STAT_QUALITY_WEIGHTS = {
	bad = 0,
	better = 0.2,
	meh = 0.4,
	mediocre = 0.6,
	great = 0.8,
	awesome = 1,
}

local MIN_VIEWERS_GAINED = 20
local MAX_VIEWERS_GAINED = 500
local MIN_SUBSCRIBERS_GAINED = 0
local MAX_SUBSCRIBERS_GAINED = 40

function VideoService.calculateVideoRewards(stats)
	local qualityScore = 0

	for key, weight in STAT_QUALITY_WEIGHTS do
		qualityScore += (stats[key] or 0) * weight
	end

	qualityScore = math.clamp(qualityScore, 0, 1)

	local viewersGained = math.floor(MIN_VIEWERS_GAINED + qualityScore * (MAX_VIEWERS_GAINED - MIN_VIEWERS_GAINED))
	local subscribersGained =
		math.floor(MIN_SUBSCRIBERS_GAINED + qualityScore * (MAX_SUBSCRIBERS_GAINED - MIN_SUBSCRIBERS_GAINED))

	return viewersGained, subscribersGained
end

local function getTopQuality(stats)
	local topKey = STAT_KEYS[1]
	local topValue = stats[topKey] or 0

	for _, key in STAT_KEYS do
		local value = stats[key] or 0
		if value > topValue then
			topValue = value
			topKey = key
		end
	end

	return topKey
end

function VideoService.completeVideo(player: Player, topic: string?)
	local stats = VideoService.generatePublishStats(player)
	local viewersGained, subscribersGained = VideoService.calculateVideoRewards(stats)

	ProfileService.addViewers(player, viewersGained)
	ProfileService.addSubscribers(player, subscribersGained)

	if topic then
		ProfileService.setLastVideo(player, {
			topic = topic,
			quality = getTopQuality(stats),
			viewersGained = viewersGained,
			subscribersGained = subscribersGained,
		})
	end

	ProfileService.setVideoProgress(player, ProfileService.get(player, "videoProgress") + 1)

	print(
		player.Name
			.. " video stats -> bad: "
			.. string.format("%.3f", stats.bad)
			.. " better: "
			.. string.format("%.3f", stats.better)
			.. " meh: "
			.. string.format("%.3f", stats.meh)
			.. " mediocre: "
			.. string.format("%.3f", stats.mediocre)
			.. " great: "
			.. string.format("%.3f", stats.great)
			.. " awesome: "
			.. string.format("%.3f", stats.awesome)
			.. " -> +"
			.. viewersGained
			.. " viewers, +"
			.. subscribersGained
			.. " subscribers"
	)

	stats.viewersGained = viewersGained
	stats.subscribersGained = subscribersGained

	ServerNetwork.VideoComplete.fire(player, stats)
end

return VideoService
