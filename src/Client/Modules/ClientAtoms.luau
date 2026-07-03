local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local atom = Charm.atom

return {
	viewers = atom(0),
	subscribers = atom(0),
	fov = atom(70),
}
