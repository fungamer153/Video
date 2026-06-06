local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Charm = require(Packages.Charm)

local atom = Charm.atom

return {
	availablePlots = atom({}),
	studioPlots = atom({}),
}
