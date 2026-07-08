local ReplicatedStorage = game:GetService("ReplicatedStorage")
local t = require(ReplicatedStorage.Packages.t)

local function defaultSlot()
	return { level = 0, skin = "default", placed = false, gridX = 0, gridZ = 0, rotation = 0 }
end

local template = {
	tutorialComplete = false,

	videoProgress = 0,
	viewers = 0,
	subscribers = 1,

	lastVideo = {
		topic = "",
		quality = "",
		viewersGained = 0,
		subscribersGained = 0,
	},

	equipment = {
		laptopDesk = defaultSlot(),
		desktop = defaultSlot(),
		chair = defaultSlot(),
		gamingChair = defaultSlot(),
	},

	channel = {
		channelName = "",
		comments = 0,
	},

	-- Sparse overrides against the shared, non-per-player chunk template built by
	-- PlotChunkService at boot (see Sample.Floor's Chunk marker Parts). A cell's effective
	-- state is always "template value, unless present here" -- this only stores deltas, so
	-- level-design changes (relocking a chunk, changing a default floor) apply cleanly to
	-- existing saves rather than being frozen in at the time the player first loaded.
	plot = {
		unlockedOverrides = {}, -- [cellKey: "chunkX,chunkZ"] = true (cells purchased beyond the starter set)
		floorOverrides = {}, -- [cellKey: "chunkX,chunkZ"] = chunkTypeId (cells where floor differs from template default)
	},
}

local equipmentSlotSchema = t.strictInterface({
	level = t.number,
	skin = t.string,
	placed = t.boolean,
	gridX = t.number,
	gridZ = t.number,
	rotation = t.number,
})

local schema = t.strictInterface({
	tutorialComplete = t.boolean,
	videoProgress = t.number,
	viewers = t.number,
	subscribers = t.number,

	lastVideo = t.strictInterface({
		topic = t.string,
		quality = t.string,
		viewersGained = t.number,
		subscribersGained = t.number,
	}),

	equipment = t.strictInterface({
		laptopDesk = equipmentSlotSchema,
		desktop = equipmentSlotSchema,
		chair = equipmentSlotSchema,
		gamingChair = equipmentSlotSchema,
	}),

	channel = t.strictInterface({
		channelName = t.string,
		comments = t.number,
	}),

	plot = t.strictInterface({
		unlockedOverrides = t.map(t.string, t.boolean),
		floorOverrides = t.map(t.string, t.string),
	}),
})

return {
	template = template,
	schema = schema,
}
