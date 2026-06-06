local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

export type EventName = "PlayerJoined" | "PlayerLeft"
type ExtraData = { [string]: any }

local signals = {}
local ServerEvents = {}

function ServerEvents.connect(eventName: EventName, callback: (extraData: ExtraData) -> ())
	if not signals[eventName] then
		signals[eventName] = Signal.new()
	end

	return signals[eventName]:Connect(callback)
end

function ServerEvents.fire(eventName: EventName, extraData: ExtraData?): ()
	if not signals[eventName] then
		return
	end

	signals[eventName]:Fire(extraData or {})
end

return ServerEvents
