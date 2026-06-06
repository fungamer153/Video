local ReplicatedStorage = game:GetService("ReplicatedStorage")
local t = require(ReplicatedStorage.Packages.t)

local template = {
	tutorialComplete = false,

	videoProgress = 0,
	viewers = 0,
	subscribers = 1,

	equipment = {
		laptop = "",
		desk = "",
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

	equipment = t.strictInterface({
		laptop = t.string,
		desk = t.string,
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
