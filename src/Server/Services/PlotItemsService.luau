local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)
local PlotConfig = require(ReplicatedStorage.Shared.PlotConfig)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local PlotService = require(ServerScriptService.Server.Services.PlotService)
local PlotChunkService = require(ServerScriptService.Server.Services.PlotChunkService)
local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local S = require(game:GetService("ReplicatedFirst").Services.Internal.Shortcuts)

local CHUNK_SIZE = PlotConfig.CHUNK_SIZE

local PlotItemsService = {}

-- gridX/gridZ (in the profile) are chunk-grid indices now, not stud offsets -- the anchor
-- cell of the item's footprint (its lowest-index corner along both axes, post-rotation).
local placedItems: { [Player]: { [string]: Instance } } = {}

-- Which slotName currently occupies each chunk cell, per player. A 1x2 item occupies two
-- entries here (its anchor cell plus one more along its long axis), both pointing at the
-- same slotName.
local occupiedChunks: { [Player]: { [string]: string } } = {}

local function cellKey(chunkX: number, chunkZ: number): string
	return chunkX .. "," .. chunkZ
end

-- Equipment models used to live server-only in ServerStorage.Assets.Equipment, with a
-- separate (and prone to drifting out of sync) client-visible copy under
-- ReplicatedStorage.Assets.Equipment for ghost previews. Now there's a single copy in
-- ReplicatedStorage.Assets.Equipment that both server and client read from directly.
local function getEquipmentAssetsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Equipment")
end

local function getEquipmentTemplate(slotName: string): Instance?
	local definition = EquipmentTypes.getDefinition(slotName)
	local equipmentFolder = getEquipmentAssetsFolder()
	return definition and equipmentFolder and equipmentFolder:FindFirstChild(definition.name)
end

-- Every cell (chunkX, chunkZ) an item's footprint covers, given its anchor cell and its
-- effective (post-rotation) width/depth in chunks.
local function getOccupiedCells(chunkX: number, chunkZ: number, width: number, depth: number): { { number } }
	local cells = {}
	for dx = 0, width - 1 do
		for dz = 0, depth - 1 do
			table.insert(cells, { chunkX + dx, chunkZ + dz })
		end
	end
	return cells
end

-- Same convention as PlotChunkService.getChunkCFrame, extended to a multi-cell footprint:
-- the CFrame is centered on the whole occupied area, not just the anchor cell.
local function getFootprintCFrame(
	floorPart: BasePart,
	chunkX: number,
	chunkZ: number,
	width: number,
	depth: number,
	rotation: number
): CFrame
	local topY = floorPart.Size.Y / 2
	local centerLocalX = (chunkX + width / 2) * CHUNK_SIZE - floorPart.Size.X / 2
	local centerLocalZ = (chunkZ + depth / 2) * CHUNK_SIZE - floorPart.Size.Z / 2
	return floorPart.CFrame
		* CFrame.new(centerLocalX, topY, centerLocalZ)
		* CFrame.Angles(0, math.rad(rotation * 90), 0)
end

local function spawnItemModel(
	player: Player,
	plotModel: Model,
	slotName: string,
	chunkX: number,
	chunkZ: number,
	rotation: number
)
	local floorPart = PlotService.getFloorPart(player)
	if not floorPart then
		return
	end

	local template = getEquipmentTemplate(slotName)
	if not template then
		warn("[PlotItemsService] No template found for slot: " .. slotName)
		return
	end

	local width, depth = EquipmentTypes.getEffectiveChunkSize(slotName, rotation, getEquipmentAssetsFolder())
	local baseCFrame = getFootprintCFrame(floorPart, chunkX, chunkZ, width, depth, rotation)

	local clone = template:Clone()

	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end

		local _, size = clone:GetBoundingBox()
		clone:PivotTo(baseCFrame * CFrame.new(0, size.Y / 2, 0))
	elseif clone:IsA("BasePart") then
		clone.CFrame = baseCFrame * CFrame.new(0, clone.Size.Y / 2, 0)
	else
		warn("[PlotItemsService] Asset is neither a Model nor a BasePart: " .. slotName)
		clone:Destroy()
		return
	end

	-- Tagged the same way floor chunks are (ChunkX/ChunkZ), plus the effective
	-- (post-rotation) footprint size, so clients can derive occupancy themselves without
	-- needing to reverse-engineer it from world position/rotation.
	clone:SetAttribute("EquipmentSlot", slotName)
	clone:SetAttribute("ChunkX", chunkX)
	clone:SetAttribute("ChunkZ", chunkZ)
	clone:SetAttribute("ChunkWidth", width)
	clone:SetAttribute("ChunkDepth", depth)
	clone.Parent = plotModel

	placedItems[player] = placedItems[player] or {}
	placedItems[player][slotName] = clone

	occupiedChunks[player] = occupiedChunks[player] or {}
	for _, cell in ipairs(getOccupiedCells(chunkX, chunkZ, width, depth)) do
		occupiedChunks[player][cellKey(cell[1], cell[2])] = slotName
	end
end

local function removeItemModel(player: Player, slotName: string)
	local playerItems = placedItems[player]
	local model = playerItems and playerItems[slotName]

	if model then
		model:Destroy()
		playerItems[slotName] = nil
	end

	local occupied = occupiedChunks[player]
	if occupied then
		for key, occupyingSlot in occupied do
			if occupyingSlot == slotName then
				occupied[key] = nil
			end
		end
	end
end

local function onPlaceRequest(
	player: Player,
	slotNameRaw: unknown,
	chunkXRaw: unknown,
	chunkZRaw: unknown,
	rotationRaw: unknown
)
	if
		typeof(slotNameRaw) ~= "string"
		or typeof(chunkXRaw) ~= "number"
		or typeof(chunkZRaw) ~= "number"
		or typeof(rotationRaw) ~= "number"
	then
		return
	end

	local slotName = slotNameRaw :: string
	local definition = EquipmentTypes.getDefinition(slotName)
	if not definition then
		S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "Invalid item")
		return
	end

	local equipment = ProfileService.get(player, "equipment")
	local slotData = equipment[slotName]
	if not slotData or slotData.level < 1 then
		S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "You don't own this item")
		return
	end

	if slotData.placed then
		S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "Already placed")
		return
	end

	local plotModel = PlotService.getPlotModel(player)
	local floorPart = PlotService.getFloorPart(player)
	if not plotModel or not floorPart then
		S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "Plot not ready")
		return
	end

	local rotation = math.floor(rotationRaw) % 4
	local chunkX = math.floor(chunkXRaw)
	local chunkZ = math.floor(chunkZRaw)

	local width, depth = EquipmentTypes.getEffectiveChunkSize(slotName, rotation, getEquipmentAssetsFolder())
	local cells = getOccupiedCells(chunkX, chunkZ, width, depth)

	for _, cell in ipairs(cells) do
		if not PlotChunkService.isCellPlaceable(player, cell[1], cell[2]) then
			S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "That spot isn't available")
			return
		end
	end

	local occupied = occupiedChunks[player]
	if occupied then
		for _, cell in ipairs(cells) do
			if occupied[cellKey(cell[1], cell[2])] then
				S.RemoteEvent("PlaceEquipmentFailed"):Fire(player, slotName, "That spot is taken")
				return
			end
		end
	end

	spawnItemModel(player, plotModel, slotName, chunkX, chunkZ, rotation)

	ProfileService.setEquipmentPlacement(player, slotName, {
		placed = true,
		gridX = chunkX,
		gridZ = chunkZ,
		rotation = rotation,
	})
end

local function onRemoveRequest(player: Player, slotNameRaw: unknown)
	if typeof(slotNameRaw) ~= "string" then
		return
	end

	local slotName = slotNameRaw :: string
	local equipment = ProfileService.get(player, "equipment")
	local slotData = equipment[slotName]

	if not slotData or not slotData.placed then
		S.RemoteEvent("RemoveEquipmentFailed"):Fire(player, slotName, "Not placed")
		return
	end

	removeItemModel(player, slotName)

	ProfileService.setEquipmentPlacement(player, slotName, {
		placed = false,
		gridX = 0,
		gridZ = 0,
		rotation = 0,
	})
end

function PlotItemsService.onStart()
	S.RemoteEvent("PlaceEquipmentRequest"):CallBack(onPlaceRequest)
	S.RemoteEvent("RemoveEquipmentRequest"):CallBack(onRemoveRequest)

	ServerEvents.connect("PlotReady", function(extraData: { player: Player, plotModel: Model })
		local player = extraData.player
		local plotModel = extraData.plotModel

		placedItems[player] = {}
		occupiedChunks[player] = {}

		-- ProfileService's own "PlayerJoined" handler runs on a separate thread and may not
		-- have finished creating profile atoms yet, so wait for it defensively.
		local equipment = nil
		for _ = 1, 100 do
			local ok, result = pcall(function()
				return ProfileService.get(player, "equipment")
			end)

			if ok then
				equipment = result
				break
			end

			task.wait(0.1)
		end

		if not equipment then
			warn("[PlotItemsService] Timed out waiting for profile to load for " .. player.Name)
			return
		end

		for slotName, slotData in equipment do
			if slotData.placed then
				spawnItemModel(player, plotModel, slotName, slotData.gridX, slotData.gridZ, slotData.rotation)
			end
		end
	end)

	ServerEvents.connect("PlayerLeft", function(extraData: { player: Player })
		local player = extraData.player
		placedItems[player] = nil
		occupiedChunks[player] = nil
	end)
end

return PlotItemsService
