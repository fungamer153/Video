local EquipmentTypes = {}

EquipmentTypes.definitions = {
	laptop = {
		name = "Laptop",
		category = "Technology",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.1,
		upgradeCost = {
			gems = 50,
			viewers = 500,
		},
		upgradeCostScale = 1.15,
		maxLevel = 20,
		skins = {
			default = {
				statMultiplier = {
					Gaming = 2,
					Tech = 1.5,
				},
			},
		},
	},
	desk = {
		name = "Desk",
		category = "Background",
		image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		baseMultiplier = 1,
		levelMultiplierStep = 0.05,
		upgradeCost = {
			gems = 30,
			viewers = 300,
		},
		upgradeCostScale = 1.15,
		maxLevel = 20,
		skins = {
			default = {
				statMultiplier = {
					Fun = 1.5,
				},
			},
		},
	},
}

EquipmentTypes.categories = { "All", "Technology", "Accessories", "Background" }

function EquipmentTypes.getDefinition(equipmentId)
	return EquipmentTypes.definitions[equipmentId]
end

function EquipmentTypes.getUpgradeCost(equipmentId, level, currency)
	local definition = EquipmentTypes.definitions[equipmentId]
	if not definition or not definition.upgradeCost then
		return nil
	end

	if definition.maxLevel and (level or 0) >= definition.maxLevel then
		return nil
	end

	local baseCost = definition.upgradeCost[currency]
	if not baseCost then
		return nil
	end

	local scale = definition.upgradeCostScale or 1.15
	return math.floor(baseCost * (scale ^ (level or 0)))
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

return EquipmentTypes
