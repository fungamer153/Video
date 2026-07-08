local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)
local S = require(game:GetService("ReplicatedFirst").Services.Internal.Shortcuts)

local VALID_CURRENCIES = { viewers = true }

local EquipmentService = {}

local function onUpgradeRequest(player: Player, slotName: unknown, currency: unknown)
	if typeof(slotName) ~= "string" or typeof(currency) ~= "string" then
		return
	end

	if not VALID_CURRENCIES[currency] then
		return
	end

	local definition = EquipmentTypes.getDefinition(slotName)
	if not definition then
		return
	end

	local equipment = ProfileService.get(player, "equipment")
	local slotData = equipment[slotName]
	if not slotData then
		return
	end

	local cost = EquipmentTypes.getUpgradeCost(slotName, slotData.level, currency)
	if not cost then
		S.RemoteEvent("UpgradeEquipmentFailed"):Fire(player, slotName, "Max level reached")
		return
	end

	local currentAmount: number = ProfileService.get(player, currency)
	if currentAmount < cost then
		S.RemoteEvent("UpgradeEquipmentFailed"):Fire(player, slotName, "Not enough " .. currency)
		return
	end

	ProfileService.addViewers(player, -cost)

	ProfileService.setEquipmentSlot(player, slotName, {
		level = slotData.level + 1,
		skin = slotData.skin,
		placed = slotData.placed,
		gridX = slotData.gridX,
		gridZ = slotData.gridZ,
		rotation = slotData.rotation,
	})
end

function EquipmentService.onStart()
	S.RemoteEvent("UpgradeEquipmentRequest"):CallBack(onUpgradeRequest)
end

return EquipmentService
