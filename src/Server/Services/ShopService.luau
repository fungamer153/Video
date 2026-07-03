local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PROMPT_HOLD_DURATION = 3
local PROMPT_ACTION_TEXT = "Buy"

local ShopService = {}

local function addBuyPrompt(primaryPart: BasePart, equipmentName: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = equipmentName
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = primaryPart
	return prompt
end

local function placeAsset(attachment: Attachment)
	local folder = attachment.Parent
	local assets = ServerStorage:FindFirstChild("Assets")
	local equipmentFolder = assets and assets:FindFirstChild("Equipment")

	if not equipmentFolder then
		warn("[ShopService] ServerStorage.Assets.Equipment folder not found")
		return
	end

	local template = equipmentFolder:FindFirstChild(attachment.Name)
	if not template then
		warn("[ShopService] No ServerStorage asset found for attachment: " .. attachment.Name)
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
