local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlotConfig = require(ReplicatedStorage.Shared.PlotConfig)
local ChunkTypes = require(ReplicatedStorage.Shared.ChunkTypes)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local PlotService = require(ServerScriptService.Server.Services.PlotService)
local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)

local CHUNK_SIZE = PlotConfig.CHUNK_SIZE

local PlotChunkService = {}

-- Shared, non-per-player template built once at boot from Sample.Floor's "Chunk" marker
-- Parts. templateLocked[cellKey] = true for cells that start locked; templateFloor[cellKey]
-- is the starting floor type for cells that don't start locked. Anything not present in
-- either table simply doesn't exist as a placeable cell at all.
local templateLocked: { [string]: boolean } = {}
local templateFloor: { [string]: string } = {}
local templateCellKeys: { string } = {}
local templateCellExists: { [string]: boolean } = {}

-- Overall bounds of the chunk grid, computed once at boot from the Chunk parts'
-- combined extents. Used both for the boot-time decomposition (as the reference frame
-- Chunk positions are measured against) and exposed via getTemplateBounds() for
-- PlotService to size/position each player's own floor-reference Part against.
local templateWidth: number? = nil
local templateDepth: number? = nil
local templateHalfHeight: number? = nil

-- Per-player record of which chunk-floor model is currently spawned for which cell, so
-- newly-unlocked cells can be spawned individually without redoing the whole plot.
local spawnedChunkModels: { [Player]: { [string]: Instance } } = {}

local function cellKey(chunkX: number, chunkZ: number): string
	return chunkX .. "," .. chunkZ
end

local function parseCellKey(key: string): (number, number)
	local chunkXStr, chunkZStr = key:match("^(-?%d+),(-?%d+)$")
	return tonumber(chunkXStr) :: number, tonumber(chunkZStr) :: number
end

-- Combined bounding box of a set of Parts: min/max X/Z and the shared top surface Y
-- (warns if the Parts don't actually share one, since the math below assumes they do).
local function getCombinedBounds(parts: { BasePart }): (number, number, number, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local topY: number? = nil

	for _, part in ipairs(parts) do
		local halfX = part.Size.X / 2
		local halfZ = part.Size.Z / 2
		minX = math.min(minX, part.Position.X - halfX)
		maxX = math.max(maxX, part.Position.X + halfX)
		minZ = math.min(minZ, part.Position.Z - halfZ)
		maxZ = math.max(maxZ, part.Position.Z + halfZ)

		local thisTopY = part.Position.Y + part.Size.Y / 2
		if not topY then
			topY = thisTopY
		elseif math.abs(topY - thisTopY) > 0.01 then
			warn(
				string.format(
					"[PlotChunkService] Chunk part %s has inconsistent top Y (%.2f vs %.2f)",
					part.Name,
					thisTopY,
					topY :: number
				)
			)
		end
	end

	return minX, maxX, minZ, maxZ, topY :: number
end

-- Decomposes one authored "Chunk" marker Part (which may span many cells -- e.g. a
-- 25x1x25 Part covers a 5x5 block of cells) into the individual chunk-cell coordinates it
-- covers, measured relative to the template's overall bounding box (centered, identity
-- rotation -- the same convention Roblox itself uses as a Model's default pivot when no
-- PrimaryPart is set, which is what PlotService.createPlot relies on when cloning Sample).
local function decomposeChunkPart(chunkPart: BasePart, boundsCenterX: number, boundsCenterZ: number): { { number } }
	local minLocalX = (chunkPart.Position.X - boundsCenterX) - chunkPart.Size.X / 2
	local minLocalZ = (chunkPart.Position.Z - boundsCenterZ) - chunkPart.Size.Z / 2

	local cellsX = math.round(chunkPart.Size.X / CHUNK_SIZE)
	local cellsZ = math.round(chunkPart.Size.Z / CHUNK_SIZE)

	local halfWidth = templateWidth :: number / 2
	local halfDepth = templateDepth :: number / 2

	local cells = {}
	for ix = 0, cellsX - 1 do
		for iz = 0, cellsZ - 1 do
			-- Sample the center of each sub-cell (not its edge) so floor() boundaries never land
			-- exactly on a cell seam.
			local sampleX = minLocalX + (ix + 0.5) * CHUNK_SIZE
			local sampleZ = minLocalZ + (iz + 0.5) * CHUNK_SIZE
			local chunkX = math.floor((sampleX + halfWidth) / CHUNK_SIZE)
			local chunkZ = math.floor((sampleZ + halfDepth) / CHUNK_SIZE)
			table.insert(cells, { chunkX, chunkZ })
		end
	end
	return cells
end

-- Scans workspace.Sample.Floor's "Chunk" marker Parts once at boot, builds the shared
-- template of which cells start locked/unlocked and what floor they start with, then
-- destroys the marker Parts -- they're pure authoring data, never meant to be the actual
-- visible floor. No Part is created or persisted in Sample itself; the reference geometry
-- each player actually needs is generated lazily, per-player, by PlotService.getFloorPart.
local function scanTemplate()
	local sample = Workspace:FindFirstChild("Sample")
	local floor = sample and sample:FindFirstChild("Floor")

	if not floor then
		warn("[PlotChunkService] Sample.Floor not found; cannot build chunk template")
		return
	end

	local chunkParts: { BasePart } = {}
	for _, child in ipairs(floor:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("^Chunk%d+$") then
			table.insert(chunkParts, child)
		end
	end

	if #chunkParts == 0 then
		warn("[PlotChunkService] No Chunk marker Parts found under Sample.Floor")
		return
	end

	local minX, maxX, minZ, maxZ, topY = getCombinedBounds(chunkParts)
	templateWidth = maxX - minX
	templateDepth = maxZ - minZ
	templateHalfHeight = chunkParts[1].Size.Y / 2

	local boundsCenterX = (minX + maxX) / 2
	local boundsCenterZ = (minZ + maxZ) / 2

	-- Sanity-check the chunk parts' shared top surface against the bounds' vertical center
	-- (which is what a Model's default pivot -- and therefore PlotService.createPlot's
	-- PivotTo -- will actually use), so a future asymmetric Sample.Floor doesn't silently
	-- throw the math off without at least a warning.
	local boundsCenterY = (topY - (templateHalfHeight :: number)) + (templateHalfHeight :: number)
	if math.abs(boundsCenterY - topY) > (templateHalfHeight :: number) + 0.01 then
		warn(
			"[PlotChunkService] Chunk parts' bounds don't look centered the way createPlot's default pivot expects; placement may be offset"
		)
	end

	local lockedCount = 0

	for _, chunkPart in ipairs(chunkParts) do
		local locked = chunkPart:GetAttribute("Locked") == true
		local floorAttr = chunkPart:GetAttribute("Floor")

		for _, cell in ipairs(decomposeChunkPart(chunkPart, boundsCenterX, boundsCenterZ)) do
			local key = cellKey(cell[1], cell[2])
			table.insert(templateCellKeys, key)

			templateCellExists[key] = true

			if locked then
				templateLocked[key] = true
				lockedCount += 1
			elseif typeof(floorAttr) == "string" and ChunkTypes.getDefinition(floorAttr) then
				templateFloor[key] = floorAttr
			end
		end
	end

	for _, chunkPart in ipairs(chunkParts) do
		chunkPart:Destroy()
	end

	print(
		string.format(
			"[PlotChunkService] Template scan complete: %d cells total, %d locked",
			#templateCellKeys,
			lockedCount
		)
	)
end

-- Public: the shared template's overall footprint (width, depth in studs) and the
-- vertical half-thickness cells are placed at. Used by PlotService to size/position each
-- player's own floor-reference Part. Returns nil if scanTemplate hasn't run/found anything.
function PlotChunkService.getTemplateBounds(): (number?, number?, number?)
	return templateWidth, templateDepth, templateHalfHeight
end

local function isCellUnlocked(player: Player, key: string): boolean
	if not templateLocked[key] then
		return true
	end

	local plot = ProfileService.get(player, "plot")
	return plot.unlockedOverrides[key] == true
end

-- Public: can equipment (or anything else) be placed on this cell right now for this
-- player? True only if the cell exists in the template at all AND is currently unlocked.
function PlotChunkService.isCellPlaceable(player: Player, chunkX: number, chunkZ: number): boolean
	local key = cellKey(chunkX, chunkZ)
	if not templateCellExists[key] then
		return false
	end
	return isCellUnlocked(player, key)
end

local function getCellFloor(player: Player, key: string): string?
	local plot = ProfileService.get(player, "plot")
	return plot.floorOverrides[key] or templateFloor[key]
end

local function getChunkCFrame(floorPart: BasePart, chunkX: number, chunkZ: number): CFrame
	local topY = floorPart.Size.Y / 2
	local localX = (chunkX + 0.5) * CHUNK_SIZE - floorPart.Size.X / 2
	local localZ = (chunkZ + 0.5) * CHUNK_SIZE - floorPart.Size.Z / 2
	return floorPart.CFrame * CFrame.new(localX, topY, localZ)
end

local function getFloorTemplate(chunkTypeId: string): Instance?
	local definition = ChunkTypes.getDefinition(chunkTypeId)
	if not definition then
		return nil
	end

	local assets = ServerStorage:FindFirstChild("Assets")
	local floorFolder = assets and assets:FindFirstChild("Floor")
	return floorFolder and floorFolder:FindFirstChild(definition.name)
end

local function spawnChunkFloor(
	player: Player,
	plotModel: Model,
	floorPart: BasePart,
	key: string,
	chunkX: number,
	chunkZ: number
)
	local chunkTypeId = getCellFloor(player, key)
	if not chunkTypeId then
		warn(
			"[PlotChunkService] Cell " .. key .. " is unlocked but has no floor type (no template/override) -- skipping"
		)
		return
	end

	local template = getFloorTemplate(chunkTypeId)
	if not template then
		warn("[PlotChunkService] No floor template for chunk type: " .. tostring(chunkTypeId))
		return
	end

	local clone = template:Clone()

	local spawnOk, spawnErr = pcall(function()
		-- Defensive: floor pieces must be anchored, regardless of how the source asset was
		-- authored, or they'll fall/drift under gravity the instant they're parented in.
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end

		if clone:IsA("Model") then
			if not clone.PrimaryPart then
				clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
			end
			clone:PivotTo(getChunkCFrame(floorPart, chunkX, chunkZ))
		elseif clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CFrame = getChunkCFrame(floorPart, chunkX, chunkZ)
		end

		clone:SetAttribute("ChunkX", chunkX)
		clone:SetAttribute("ChunkZ", chunkZ)
		clone.Parent = plotModel
	end)

	if not spawnOk then
		warn("[PlotChunkService] Failed to spawn floor for cell " .. key .. ": " .. tostring(spawnErr))
		clone:Destroy()
		return
	end

	spawnedChunkModels[player] = spawnedChunkModels[player] or {}
	spawnedChunkModels[player][key] = clone
end

local function spawnPlayerChunks(player: Player, plotModel: Model)
	local floorPart = PlotService.getFloorPart(player)
	if not floorPart then
		warn("[PlotChunkService] No floor part for " .. player.Name)
		return
	end

	spawnedChunkModels[player] = {}

	local totalCells = #templateCellKeys
	local unlockedCells = 0
	local spawnedCells = 0

	for _, key in ipairs(templateCellKeys) do
		if isCellUnlocked(player, key) then
			unlockedCells += 1
			local chunkX, chunkZ = parseCellKey(key)
			spawnChunkFloor(player, plotModel, floorPart, key, chunkX, chunkZ)
			if spawnedChunkModels[player][key] then
				spawnedCells += 1
			end
		end
	end

	print(
		string.format(
			"[PlotChunkService] %s: %d total cells, %d unlocked, %d floors spawned",
			player.Name,
			totalCells,
			unlockedCells,
			spawnedCells
		)
	)
end

-- Unlocks one chunk cell for a player (saving it via ProfileService) and spawns its floor
-- immediately if their plot is currently loaded. Not yet wired to any purchase flow --
-- this is the plumbing a future "buy chunk" remote/UI would call into.
function PlotChunkService.unlockChunk(player: Player, chunkX: number, chunkZ: number)
	local key = cellKey(chunkX, chunkZ)
	if not templateLocked[key] then
		return
	end

	ProfileService.setChunkUnlocked(player, key)

	local plotModel = PlotService.getPlotModel(player)
	local floorPart = PlotService.getFloorPart(player)
	local alreadySpawned = spawnedChunkModels[player] and spawnedChunkModels[player][key]

	if plotModel and floorPart and not alreadySpawned then
		spawnChunkFloor(player, plotModel, floorPart, key, chunkX, chunkZ)
	end
end

-- Changes one chunk cell's floor type for a player (saving it via ProfileService) and
-- respawns its floor model immediately if their plot is currently loaded. Also not yet
-- wired to any UI/remote.
function PlotChunkService.setChunkFloor(player: Player, chunkX: number, chunkZ: number, chunkTypeId: string)
	if not ChunkTypes.getDefinition(chunkTypeId) then
		warn("[PlotChunkService] Unknown chunk type: " .. tostring(chunkTypeId))
		return
	end

	local key = cellKey(chunkX, chunkZ)
	ProfileService.setChunkFloor(player, key, chunkTypeId)

	local plotModel = PlotService.getPlotModel(player)
	local floorPart = PlotService.getFloorPart(player)
	if not plotModel or not floorPart then
		return
	end

	local existing = spawnedChunkModels[player] and spawnedChunkModels[player][key]
	if existing then
		existing:Destroy()
	end

	spawnChunkFloor(player, plotModel, floorPart, key, chunkX, chunkZ)
end

function PlotChunkService.onStart()
	local scanOk, scanErr = pcall(scanTemplate)
	if not scanOk then
		warn("[PlotChunkService] scanTemplate() threw an error: " .. tostring(scanErr))
	end

	ServerEvents.connect("PlotReady", function(extraData: { player: Player, plotModel: Model })
		local player = extraData.player
		local plotModel = extraData.plotModel

		-- ProfileService's own "PlayerJoined" handler runs on a separate thread and may not
		-- have finished creating profile atoms yet, so wait for it defensively (same pattern
		-- PlotItemsService already uses for the identical race).
		local profileReady = false
		for _ = 1, 100 do
			local ok = pcall(function()
				return ProfileService.get(player, "plot")
			end)

			if ok then
				profileReady = true
				break
			end

			task.wait(0.1)
		end

		if not profileReady then
			warn("[PlotChunkService] Timed out waiting for profile to load for " .. player.Name)
			return
		end

		spawnPlayerChunks(player, plotModel)
	end)

	ServerEvents.connect("PlayerLeft", function(extraData: { player: Player })
		spawnedChunkModels[extraData.player] = nil
	end)
end

return PlotChunkService
