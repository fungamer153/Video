local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)

local BUY_ATTACHMENT_TEMPLATE = ReplicatedStorage.Assets.Misc.BuyAttachment

local ShopPromptController = {}

local activeAttachments = {}

local function getShopItemsFolder()
	local shop = Workspace:FindFirstChild("Shop")
	return shop and shop:FindFirstChild("Items")
end

local function populateBillboard(attachment, equipmentId)
	local definition = EquipmentTypes.getDefinition(equipmentId)
	if not definition then
		return
	end

	local billboard = attachment:FindFirstChildOfClass("BillboardGui")
	if not billboard then
		return
	end

	local frame = billboard.Frame
	frame.Item.Text = definition.name or equipmentId
	frame.Description.Text = definition.description or ""

	local price = EquipmentTypes.getPrice(equipmentId)
	frame.Cost.Cost.Text = price and tostring(price) or "?"
end

local function onPromptShown(prompt)
	local player = Players.LocalPlayer

	local part = prompt.Parent
	if not part then
		return
	end

	-- prompt.ObjectText is the display name ("Gaming Chair"), not the camelCase id
	-- ("gamingChair") -- naive string.lower() breaks on any name with a space ("gaming
	-- chair" != "gamingChair"), silently failing the lookup and leaving whatever
	-- placeholder text is baked into the template. Same fix as ShopService.tryPurchase.
	local equipmentId = EquipmentTypes.getIdFromDisplayName(prompt.ObjectText)
	if not equipmentId then
		warn("[ShopPromptController] No equipment definition for: " .. tostring(prompt.ObjectText))
		return
	end

	local clone = BUY_ATTACHMENT_TEMPLATE:Clone()
	clone.Parent = part
	populateBillboard(clone, equipmentId)

	activeAttachments[prompt] = clone
end

local function onPromptHidden(prompt)
	local clone = activeAttachments[prompt]
	if clone then
		clone:Destroy()
		activeAttachments[prompt] = nil
	end
end

local function watchPrompt(prompt)
	if prompt.Name ~= "BuyPrompt" then
		return
	end

	prompt.PromptShown:Connect(function()
		onPromptShown(prompt)
	end)

	prompt.PromptHidden:Connect(function()
		onPromptHidden(prompt)
	end)

	prompt.Triggered:Connect(function()
		onPromptHidden(prompt)
	end)
end

local function watchItem(item)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			watchPrompt(descendant)
		end
	end

	item.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watchPrompt(descendant)
		end
	end)
end

function ShopPromptController.onStart()
	local itemsFolder = getShopItemsFolder()
	if not itemsFolder then
		warn("[ShopPromptController] Workspace.Shop.Items folder not found")
		return
	end

	for _, item in ipairs(itemsFolder:GetChildren()) do
		watchItem(item)
	end

	itemsFolder.ChildAdded:Connect(watchItem)
end

return ShopPromptController
