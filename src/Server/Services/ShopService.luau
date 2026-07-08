local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local S = require(game:GetService("ReplicatedFirst").Services.Internal.Shortcuts)

local PROMPT_HOLD_DURATION = 3
local PROMPT_ACTION_TEXT = "Buy"
-- Explicit and well under the tightest gap between shop items (Gaming Chair <-> Chair is
-- only ~9.5 studs). Left unset, ProximityPrompt's 10-stud default overlaps that gap,
-- so standing near one item can surface a neighboring item's prompt instead.
local PROMPT_MAX_ACTIVATION_DISTANCE = 4

local ShopService = {}

local function tryPurchase(player: Player, equipmentName: string)
	local equipmentId = EquipmentTypes.getIdFromDisplayName(equipmentName)
	if not equipmentId then
		warn("[ShopService] No equipment definition for: " .. tostring(equipmentName))
		return
	end

	local definition = EquipmentTypes.getDefinition(equipmentId)
	if not definition then
		warn("[ShopService] No equipment definition for: " .. equipmentId)
		return
	end

	local price = EquipmentTypes.getPrice(equipmentId)
	if not price then
		warn("[ShopService] No price configured for: " .. equipmentId)
		return
	end

	local currency = EquipmentTypes.getCurrency(equipmentId)

	local equipment = ProfileService.get(player, "equipment")
	local slotData = equipment[equipmentId]

	if slotData and slotData.level >= 1 then
		S.RemoteEvent("BuyEquipmentFailed"):Fire(player, equipmentId, "Already owned")
		return
	end

	local currentAmount: number = ProfileService.get(player, currency)
	if currentAmount < price then
		S.RemoteEvent("BuyEquipmentFailed"):Fire(player, equipmentId, "Not enough " .. currency)
		return
	end

	if currency == "viewers" then
		ProfileService.addViewers(player, -price)
	elseif currency == "subscribers" then
		ProfileService.addSubscribers(player, -price)
	else
		warn("[ShopService] Unsupported currency: " .. tostring(currency))
		return
	end

	ProfileService.setEquipmentSlot(player, equipmentId, {
		level = 1,
		skin = (slotData and slotData.skin) or "default",
		placed = (slotData and slotData.placed) or false,
		gridX = (slotData and slotData.gridX) or 0,
		gridZ = (slotData and slotData.gridZ) or 0,
		rotation = (slotData and slotData.rotation) or 0,
	})

	S.RemoteEvent("BuyEquipmentSuccess"):Fire(player, equipmentId)
end

local function addBuyPrompt(primaryPart: BasePart, equipmentName: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = equipmentName
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = PROMPT_MAX_ACTIVATION_DISTANCE
	prompt.Parent = primaryPart

	prompt.Triggered:Connect(function(player: Player)
		tryPurchase(player, equipmentName)
	end)

	return prompt
end

local function placeAsset(attachment: Attachment)
	local folder = attachment.Parent
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local equipmentFolder = assets and assets:FindFirstChild("Equipment")

	if not equipmentFolder then
		warn("[ShopService] ReplicatedStorage.Assets.Equipment folder not found")
		return
	end

	local template = equipmentFolder:FindFirstChild(attachment.Name)
	if not template then
		warn("[ShopService] No equipment asset found for attachment: " .. attachment.Name)
		return
	end

	local clone = template:Clone()
	local placementCFrame = attachment.WorldCFrame

	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end

		if clone.PrimaryPart then
			clone:PivotTo(placementCFrame)
			addBuyPrompt(clone.PrimaryPart, attachment.Name)
		else
			warn("[ShopService] Model asset has no BasePart to pivot: " .. attachment.Name)
		end
	elseif clone:IsA("BasePart") then
		clone.CFrame = placementCFrame
		addBuyPrompt(clone, attachment.Name)
	else
		warn("[ShopService] Asset is neither a Model nor a BasePart: " .. attachment.Name)
	end

	clone.Parent = folder
	attachment:Destroy()
end

function ShopService.onStart()
	local shop = Workspace:FindFirstChild("Shop")
	local itemsFolder = shop and shop:FindFirstChild("Items")

	if not itemsFolder then
		warn("[ShopService] Workspace.Shop.Items folder not found")
		return
	end

	for _, child in ipairs(itemsFolder:GetChildren()) do
		if child:IsA("Attachment") then
			placeAsset(child)
		end
	end
end

return ShopService
