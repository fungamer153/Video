local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)

local upgradeRequest = ReplicatedStorage:WaitForChild("UpgradeEquipmentRequest")
local upgradeFailed = ReplicatedStorage:WaitForChild("UpgradeEquipmentFailed")

local VALID_CURRENCIES = { gems = true, viewers = true }

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
		upgradeFailed:FireClient(player, slotName, "Max level reached")
		return
	end

	local currentAmount: number = ProfileService.get(player, currency)
	if currentAmount < cost then
		upgradeFailed:FireClient(player, slotName, "Not enough " .. currency)
		return
	end

	if currency == "gems" then
		ProfileService.addGems(player, -cost)
	else
		ProfileService.addViewers(player, -cost)
	end

	ProfileService.setEquipmentSlot(player, slotName, {
		level = slotData.level + 1,
		skin = slotData.skin,
	})
end

function EquipmentService.onStart()
	upgradeRequest.OnServerEvent:Connect(onUpgradeRequest)
end

return EquipmentService
