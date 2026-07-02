local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

export type EventName = "PlayerJoined" | "SetFov"
type ExtraData = { [string]: any }

local signals = {}
local ClientEvents = {}

function ClientEvents.connect(eventName: EventName, callback: (extraData: ExtraData) -> ())
	if not signals[eventName] then
		signals[eventName] = Signal.new()
	end

	return signals[eventName]:Connect(callback)
end

function ClientEvents.fire(eventName: EventName, extraData: ExtraData?): ()
	if not signals[eventName] then
		return
	end

	signals[eventName]:Fire(extraData or {})
end

return ClientEvents
