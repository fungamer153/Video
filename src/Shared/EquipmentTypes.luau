local EquipmentTypes = {}

EquipmentTypes.definitions = {
	laptopDesk = {
		name = "Laptop Desk",
		description = "A starter desk with a laptop already set up. Gets the job done.",
		price = 300,
		currency = "viewers",
		category = "Technology",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.05,
		upgradeCost = {
			viewers = 300,
		},
		upgradeCostScale = 1.15,
		barMaxLevel = 25,
		skins = {
			default = {
				statMultiplier = {
					Gaming = 1.3,
					Tech = 1.2,
				},
			},
		},
	},

	desktop = {
		name = "Desktop",
		description = "A proper desktop setup. Better performance than a laptop for serious content.",
		price = 700,
		currency = "viewers",
		category = "Technology",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.05,
		upgradeCost = {
			viewers = 700,
		},
		upgradeCostScale = 1.15,
		barMaxLevel = 25,
		skins = {
			default = {
				statMultiplier = {
					Gaming = 1.6,
					Tech = 1.4,
				},
			},
		},
	},

	chair = {
		name = "Chair",
		description = "A comfy chair to sit in while you record. Small comfort boost to any setup.",
		price = 150,
		currency = "viewers",
		category = "Accessories",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.05,
		upgradeCost = {
			viewers = 150,
		},
		upgradeCostScale = 1.15,
		barMaxLevel = 25,
		skins = {
			default = {
				statMultiplier = {
					Fun = 1.2,
				},
			},
		},
	},

	gamingChair = {
		name = "Gaming Chair",
		description = "A high-back gaming chair. Big boost to gaming videos specifically.",
		price = 400,
		currency = "viewers",
		category = "Accessories",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.05,
		upgradeCost = {
			viewers = 400,
		},
		upgradeCostScale = 1.15,
		barMaxLevel = 25,
		skins = {
			default = {
				statMultiplier = {
					Gaming = 1.8,
					Tech = 1.1,
				},
			},
		},
	},
}

EquipmentTypes.categories = { "All", "Technology", "Accessories", "Background" }
local idByLowerName = {}

local CHUNK_SIZE = 5
local chunkFootprintCache: { [string]: { chunkWidth: number, chunkDepth: number } } = {}

for id, definition in pairs(EquipmentTypes.definitions) do
	idByLowerName[definition.name:lower()] = id
end

function EquipmentTypes.getIdFromDisplayName(displayName)
	return idByLowerName[tostring(displayName):lower()]
end

function EquipmentTypes.getDefinition(equipmentId)
	return EquipmentTypes.definitions[equipmentId]
end

function EquipmentTypes.getPrice(equipmentId)
	local definition = EquipmentTypes.definitions[equipmentId]
	return definition and definition.price
end

function EquipmentTypes.getCurrency(equipmentId)
	local definition = EquipmentTypes.definitions[equipmentId]
	return (definition and definition.currency) or "viewers"
end

function EquipmentTypes.getUpgradeCost(equipmentId, level, currency)
	local definition = EquipmentTypes.definitions[equipmentId]
	if not definition or not definition.upgradeCost then
		return nil
	end

	local baseCost = definition.upgradeCost[currency]
	if not baseCost then
		return nil
	end

	local scale = definition.upgradeCostScale or 1.15
	return math.floor(baseCost * (scale ^ (level or 0)))
end

function EquipmentTypes.getBarProgress(equipmentId, level)
	local definition = EquipmentTypes.definitions[equipmentId]
	local barMaxLevel = (definition and definition.barMaxLevel) or 25
	return math.clamp((level or 0) / barMaxLevel, 0, 1)
end

function EquipmentTypes.getEffectiveStats(equipmentId, level, skin)
	local definition = EquipmentTypes.definitions[equipmentId]
	if not definition then
		return nil
	end

	local skinData = definition.skins[skin] or definition.skins.default
	local multiplier = definition.baseMultiplier + (definition.levelMultiplierStep * (level or 0))

	return {
		multiplier = multiplier,
		statMultiplier = skinData.statMultiplier,
	}
end

function EquipmentTypes.getChunkFootprint(equipmentId, assetsEquipmentFolder)
	local cached = chunkFootprintCache[equipmentId]
	if cached then
		return cached.chunkWidth, cached.chunkDepth
	end

	local definition = EquipmentTypes.definitions[equipmentId]
	local template = definition and assetsEquipmentFolder:FindFirstChild(definition.name)
	local root = template and template:FindFirstChild("Root")

	if not root or not root:IsA("BasePart") then
		warn("[EquipmentTypes] No Root part found for " .. tostring(equipmentId) .. "; defaulting to 1x1 chunk")
		return 1, 1
	end

	local chunkWidth = math.max(1, math.round(root.Size.X / CHUNK_SIZE))
	local chunkDepth = math.max(1, math.round(root.Size.Z / CHUNK_SIZE))

	chunkFootprintCache[equipmentId] = { chunkWidth = chunkWidth, chunkDepth = chunkDepth }
	return chunkWidth, chunkDepth
end

function EquipmentTypes.getEffectiveChunkSize(equipmentId, rotation, assetsEquipmentFolder)
	local chunkWidth, chunkDepth = EquipmentTypes.getChunkFootprint(equipmentId, assetsEquipmentFolder)
	local rotated = (rotation or 0) % 2 == 1

	if rotated then
		return chunkDepth, chunkWidth
	end
	return chunkWidth, chunkDepth
end

return EquipmentTypes
