local ReplicatedStorage = game:GetService("ReplicatedStorage")
local t = require(ReplicatedStorage.Packages.t)

local template = {
	tutorialComplete = false,

	videoProgress = 0,
	viewers = 0,
	subscribers = 1,
	gems = 0,

	equipment = {
		laptop = { level = 0, skin = "default" },
		desk = { level = 0, skin = "default" },
	},

	channel = {
		channelName = "",
		comments = 0,
	},
}

local schema = t.strictInterface({
	tutorialComplete = t.boolean,
	videoProgress = t.number,
	viewers = t.number,
	subscribers = t.number,
	gems = t.number,

	equipment = t.strictInterface({
		laptop = t.strictInterface({
			level = t.number,
			skin = t.string,
		}),
		desk = t.strictInterface({
			level = t.number,
			skin = t.string,
		}),
	}),

	channel = t.strictInterface({
		channelName = t.string,
		comments = t.number,
	}),
})

return {
	template = template,
	schema = schema,
}
