local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local DataService = require(ServerScriptService.Server.Services.DataService)

local ProfileTemplate = require(ServerScriptService.Server.Modules.ProfileTemplate)

local playerAtoms: { [Player]: { [string]: any } } = {}

local function createProfileAtoms(profileData: { [string]: any }): { [string]: any }
	return {
		tutorialComplete = Charm.atom(profileData.tutorialComplete),
		videoProgress = Charm.atom(profileData.videoProgress),
		viewers = Charm.atom(profileData.viewers),
		subscribers = Charm.atom(profileData.subscribers),
		equipment = Charm.atom(profileData.equipment),
		channel = Charm.atom(profileData.channel),
	}
end

local function requireAtoms(player: Player): { [string]: any }
	local atoms = playerAtoms[player]
	assert(atoms, "No profile loaded for player: " .. player.Name)
	return atoms
end

local function commitField(player, field, value)
	DataService.update(player, function(profileData)
		for k, v in ProfileTemplate.template do
			if profileData[k] == nil then
				profileData[k] = v
			end
		end

		profileData[field] = value
		return true
	end)

	local atoms = playerAtoms[player]
	if atoms and atoms[field] then
		atoms[field](value)
	end
end

local ProfileService = {}

function ProfileService.onStart()
	ServerEvents.connect("PlayerJoined", function(extraData: { player: Player })
		local player = extraData.player
		local profileData = DataService.get(player)
		if not profileData then
			return
		end

		playerAtoms[player] = createProfileAtoms(profileData)
		print("Profile atoms initialised for", player.Name)
	end)

	ServerEvents.connect("PlayerLeft", function(extraData: { player: Player })
		local player = extraData.player
		playerAtoms[player] = nil
	end)
end

-- Returns the current value of a profile field atom
function ProfileService.get(player: Player, field: string): any
	local atoms = requireAtoms(player)
	assert(atoms[field], "Unknown field: " .. tostring(field))
	return atoms[field]()
end

-- Subscribe to live changes on a profile field; returns a cleanup function
function ProfileService.observe(player: Player, field: string, callback: (newValue: any, oldValue: any) -> ()): () -> ()
	local atoms = requireAtoms(player)
	assert(atoms[field], "Unknown field: " .. tostring(field))
	return Charm.observe(atoms[field], callback)
end

-- Subscribers
function ProfileService.addSubscribers(player: Player, amount: number)
	local currentSubscribers: number = ProfileService.get(player, "subscribers")
	commitField(player, "subscribers", currentSubscribers + amount)
end

function ProfileService.setSubscribers(player: Player, amount: number)
	commitField(player, "subscribers", amount)
end

-- Viewers
function ProfileService.addViewers(player: Player, amount: number)
	local currentViewers: number = ProfileService.get(player, "viewers")
	commitField(player, "viewers", currentViewers + amount)
end

function ProfileService.setViewers(player: Player, amount: number)
	commitField(player, "viewers", amount)
end

-- Video Progress
function ProfileService.setVideoProgress(player: Player, progress: number)
	commitField(player, "videoProgress", progress)
end

-- Equipment
function ProfileService.setEquipment(player: Player, equipmentData: { laptop: string, desk: string })
	commitField(player, "equipment", equipmentData)
end

-- Channel
function ProfileService.setChannel(player: Player, channelData: { channelName: string, comments: number })
	commitField(player, "channel", channelData)
end

function ProfileService.addComments(player: Player, amount: number)
	local currentChannel: { channelName: string, comments: number } = ProfileService.get(player, "channel")
	commitField(player, "channel", {
		channelName = currentChannel.channelName,
		comments = currentChannel.comments + amount,
	})
end

return ProfileService
