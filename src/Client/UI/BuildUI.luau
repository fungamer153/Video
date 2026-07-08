local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local S = require(ReplicatedFirst.Services.Internal.Shortcuts)
local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)
local PlotConfig = require(ReplicatedStorage.Shared.PlotConfig)

local GhostModelsFolder = ReplicatedStorage.Assets.Equipment
local GridTextureTemplate = ReplicatedStorage.Assets.Misc.GridTexture

local CHUNK_SIZE = PlotConfig.CHUNK_SIZE

-- Same 4 equipment ids as the rest of the project (EquipmentTypes.definitions / ProfileTemplate).
local SLOT_ORDER = { "laptopDesk", "desktop", "chair", "gamingChair" }

local SELECTED_SCALE = 1.1
local DESELECTED_SCALE = 1
local SELECT_SCALE_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local GHOST_VALID_COLOR = Color3.fromRGB(80, 220, 100)
local GHOST_INVALID_COLOR = Color3.fromRGB(220, 70, 70)
local GHOST_TRANSPARENCY = 0.55
local GHOST_TWEEN_SPEED = 24 -- higher = snappier follow, lower = more floaty/laggy
local DELETE_HIGHLIGHT_COLOR = Color3.fromRGB(220, 70, 70)

-- NUMBER_KEYCODES[n] selects hotbar slot n. LOW CONFIDENCE: rebuilt reasonably, not restored.
local NUMBER_KEYCODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local BuildUI = {}

local gui: ScreenGui
local hotbar: Frame
local sampleTemplate: Frame
local deleteSlot: Frame

local active = false
local selectedSlot: string? = nil -- an equipment id, "delete", or nil
local ghostRotation = 0 -- 0-3, matches server's rotation % 4 (90 degree steps)
local ghostModel: Model? = nil
local ghostIndicator: BasePart? = nil
local gridTextureClone: Texture? = nil
local deleteHighlightTarget: Instance? = nil
local deleteHighlightInstance: Highlight? = nil

local spawnedSlots: { [string]: Frame } = {}
local keyBindings: { [string]: string } = {}

-- Forward declarations (functions reference each other out of definition order).
local refreshHotbar
local applySelectionVisual
local clearGhost
local clearDeleteHighlight
local showGridTexture
local hideGridTexture

local function getEquipmentData(): { [string]: any }
	local player = Players.LocalPlayer
	local raw = player:GetAttribute("equipment_json")
	if not raw then
		return {}
	end

	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(decoded) ~= "table" then
		return {}
	end

	return decoded
end

local function findOwnPlot(): Model?
	local player = Players.LocalPlayer
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end

	return nil
end

local function getFloorPart(): BasePart?
	local plot = findOwnPlot()
	if not plot then
		return nil
	end

	local floorFolder = plot:FindFirstChild("Floor")
	local part = floorFolder and floorFolder:FindFirstChild("Part")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function tweenSlotScale(slotFrame: GuiObject?, targetScale: number)
	if not slotFrame then
		return
	end

	local uiScale = slotFrame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		return
	end

	TweenService:Create(uiScale, SELECT_SCALE_TWEEN, { Scale = targetScale }):Play()
end

local function getSlotFrame(slotName: string?): GuiObject?
	if not slotName then
		return nil
	end
	if slotName == "delete" then
		return deleteSlot
	end
	return spawnedSlots[slotName]
end

applySelectionVisual = function()
	for _, slotFrame in spawnedSlots do
		tweenSlotScale(slotFrame, DESELECTED_SCALE)
	end
	tweenSlotScale(deleteSlot, DESELECTED_SCALE)
	tweenSlotScale(getSlotFrame(selectedSlot), SELECTED_SCALE)
end

local function clearHotbarSlots()
	for _, slotFrame in spawnedSlots do
		slotFrame:Destroy()
	end
	table.clear(spawnedSlots)
	table.clear(keyBindings)
end

local function selectSlot(slotName: string)
	if selectedSlot == slotName then
		selectedSlot = nil
	else
		selectedSlot = slotName
	end

	ghostRotation = 0
	clearGhost()
	clearDeleteHighlight()
	applySelectionVisual()
end

local function onDeleteButtonClicked()
	selectSlot("delete")
end

local function createHotbarSlot(equipmentId: string, keyNumber: number)
	local definition = EquipmentTypes.getDefinition(equipmentId)
	if not definition then
		return
	end

	local slotFrame = sampleTemplate:Clone()
	slotFrame.Name = equipmentId
	slotFrame.Visible = true
	slotFrame.LayoutOrder = keyNumber

	local icon = slotFrame.TextButton.Frame.icon.ImageLabel
	icon.Image = definition.image

	local tooltipLabel = slotFrame.TextButton.Frame.ToolTip.Item.Key
	tooltipLabel.Text = definition.name

	local badgeLabel = slotFrame.TextButton.Frame.ToolTip.Key.Frame.Key
	badgeLabel.Text = tostring(keyNumber)

	usePrimaryButton(slotFrame.TextButton, function()
		selectSlot(equipmentId)
	end)

	slotFrame.Parent = hotbar
	spawnedSlots[equipmentId] = slotFrame
	keyBindings[tostring(keyNumber)] = equipmentId
end

refreshHotbar = function()
	clearHotbarSlots()

	local equipmentData = getEquipmentData()
	local keyNumber = 1

	for _, slotName in ipairs(SLOT_ORDER) do
		local slotData = equipmentData[slotName]
		if slotData and slotData.level and slotData.level >= 1 and not slotData.placed then
			createHotbarSlot(slotName, keyNumber)
			keyNumber += 1
		end
	end

	if selectedSlot and selectedSlot ~= "delete" and not spawnedSlots[selectedSlot] then
		selectedSlot = nil
		clearGhost()
	end

	applySelectionVisual()
end

hideGridTexture = function()
	if gridTextureClone then
		gridTextureClone:Destroy()
		gridTextureClone = nil
	end
end

showGridTexture = function()
	hideGridTexture()

	local floorPart = getFloorPart()
	if not floorPart then
		task.spawn(function()
			for _ = 1, 30 do
				if not active then
					return
				end
				task.wait(0.1)
				if getFloorPart() then
					break
				end
			end
			if active then
				showGridTexture()
			end
		end)
		return
	end

	local clone = GridTextureTemplate:Clone()
	clone.Parent = floorPart
	gridTextureClone = clone
end

local ghostIsNew = false
local INDICATOR_HEIGHT = 0.05

-- Last hovered cell that was fully valid, used to let the ghost slide along whichever
-- single axis is still accessible near a locked cell, instead of freezing on both axes.
local lastValidChunkX: number? = nil
local lastValidChunkZ: number? = nil

clearGhost = function()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	ghostIndicator = nil
	ghostIsNew = false
	lastValidChunkX = nil
	lastValidChunkZ = nil
end

local function ensureGhost(slotName: string): Model?
	if ghostModel then
		return ghostModel
	end

	local definition = EquipmentTypes.getDefinition(slotName)
	if not definition then
		return nil
	end

	local template = GhostModelsFolder:FindFirstChild(definition.name)
	if not template or not template:IsA("Model") then
		return nil
	end

	local clone = template:Clone()
	clone.Name = "BuildGhost"

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			if descendant.Name ~= "Root" then
				descendant.Transparency = math.clamp(descendant.Transparency + GHOST_TRANSPARENCY, 0, 0.9)
			end
		end
	end

	-- A dedicated flat square below Root carries the valid/invalid color instead of
	-- highlighting the whole (often irregularly-shaped) model. Sized to the item's base,
	-- unrotated chunk footprint -- rotating the whole ghost via PivotTo naturally rotates
	-- this along with it, so it doesn't need separate rotation handling.
	local root = clone:FindFirstChild("Root")
	local indicator: BasePart? = nil

	if root and root:IsA("BasePart") then
		local chunkWidth, chunkDepth = EquipmentTypes.getChunkFootprint(slotName, GhostModelsFolder)

		indicator = Instance.new("Part")
		indicator.Name = "PlacementIndicator"
		indicator.Size = Vector3.new(chunkWidth * CHUNK_SIZE, INDICATOR_HEIGHT, chunkDepth * CHUNK_SIZE)
		indicator.CFrame = root.CFrame * CFrame.new(0, -(root.Size.Y / 2 + INDICATOR_HEIGHT / 2), 0)
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.CanQuery = false
		indicator.CanTouch = false
		indicator.Material = Enum.Material.Neon
		indicator.Color = GHOST_VALID_COLOR
		indicator.Transparency = 0.9
		indicator.Parent = clone
	end

	clone.Parent = Workspace
	ghostModel = clone
	ghostIndicator = indicator
	ghostIsNew = true

	return clone
end

-- Mirrors PlotItemsService's getFootprintCFrame exactly: centered on the whole occupied
-- footprint (width x depth chunks), not just the anchor cell.
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

local function updateGhostPosition(
	slotName: string,
	floorPart: BasePart,
	chunkX: number,
	chunkZ: number,
	width: number,
	depth: number,
	dt: number
)
	local ghost = ensureGhost(slotName)
	if not ghost then
		return
	end

	local baseCFrame = getFootprintCFrame(floorPart, chunkX, chunkZ, width, depth, ghostRotation)

	local _, size = ghost:GetBoundingBox()
	local targetCFrame = baseCFrame * CFrame.new(0, size.Y / 2, 0)

	if ghostIsNew then
		-- Snap instantly the first frame a ghost appears (nothing to tween from yet).
		ghost:PivotTo(targetCFrame)
		ghostIsNew = false
	else
		local alpha = math.clamp(dt * GHOST_TWEEN_SPEED, 0, 1)
		ghost:PivotTo(ghost:GetPivot():Lerp(targetCFrame, alpha))
	end
end

local function setGhostValid(isValid: boolean)
	if ghostIndicator then
		ghostIndicator.Color = isValid and GHOST_VALID_COLOR or GHOST_INVALID_COLOR
	end
end

clearDeleteHighlight = function()
	if deleteHighlightInstance then
		deleteHighlightInstance:Destroy()
		deleteHighlightInstance = nil
	end
	deleteHighlightTarget = nil
end

local function findPlacedEquipmentAncestor(instance: Instance?): Instance?
	local current = instance
	while current and current ~= Workspace do
		if current:GetAttribute("EquipmentSlot") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function highlightForDelete(target: Instance)
	if deleteHighlightTarget == target then
		return
	end

	clearDeleteHighlight()

	local highlight = Instance.new("Highlight")
	highlight.Name = "BuildDeleteHighlight"
	highlight.FillColor = DELETE_HIGHLIGHT_COLOR
	highlight.OutlineColor = DELETE_HIGHLIGHT_COLOR
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target

	deleteHighlightTarget = target
	deleteHighlightInstance = highlight
end

local function getMouseFloorHit(floorPart: BasePart): (number?, number?)
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()

	local unitRay = mouse.UnitRay

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { floorPart }

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	if not result then
		return nil, nil
	end

	local relative = floorPart.CFrame:PointToObjectSpace(result.Position)
	return relative.X, relative.Z
end

-- Converts a raw stud hit-point (relative to the floor Part's center) into the chunk cell
-- under the cursor. The anchor convention matches the server: the lowest-index corner of
-- the footprint along both axes.
local function getHoveredChunk(floorPart: BasePart, rawX: number, rawZ: number): (number, number)
	local chunkX = math.floor((rawX + floorPart.Size.X / 2) / CHUNK_SIZE)
	local chunkZ = math.floor((rawZ + floorPart.Size.Z / 2) / CHUNK_SIZE)
	return chunkX, chunkZ
end

-- Which chunk cells are currently unlocked, derived from something the client can
-- actually see: a floor chunk model only ever gets spawned (by PlotChunkService, tagged
-- with ChunkX/ChunkZ attributes) for cells that are unlocked. No separate replication of
-- lock state is needed -- floor presence already is the ground truth. Rebuilt each time
-- build mode is entered.
local unlockedCells: { [string]: boolean } = {}

local function cellKey(chunkX: number, chunkZ: number): string
	return chunkX .. "," .. chunkZ
end

-- Which cells are currently occupied by another placed equipment item, derived the same
-- way unlocked cells are: from attributes already tagged on the real, replicated
-- Instance (ChunkX/ChunkZ/ChunkWidth/ChunkDepth set by PlotItemsService.spawnItemModel),
-- not from any separate replication.
local occupiedCells: { [string]: boolean } = {}

local function refreshUnlockedCells()
	table.clear(unlockedCells)
	table.clear(occupiedCells)

	local plot = findOwnPlot()
	if not plot then
		return
	end

	for _, child in ipairs(plot:GetChildren()) do
		local chunkX = child:GetAttribute("ChunkX")
		local chunkZ = child:GetAttribute("ChunkZ")
		if typeof(chunkX) ~= "number" or typeof(chunkZ) ~= "number" then
			continue
		end

		unlockedCells[cellKey(chunkX, chunkZ)] = true

		local equipmentSlot = child:GetAttribute("EquipmentSlot")
		local chunkWidth = child:GetAttribute("ChunkWidth")
		local chunkDepth = child:GetAttribute("ChunkDepth")
		if typeof(equipmentSlot) == "string" and typeof(chunkWidth) == "number" and typeof(chunkDepth) == "number" then
			for dx = 0, chunkWidth - 1 do
				for dz = 0, chunkDepth - 1 do
					occupiedCells[cellKey(chunkX + dx, chunkZ + dz)] = true
				end
			end
		end
	end
end

-- Is any cell this footprint would occupy already taken by another placed item?
local function isIntersectingOccupied(chunkX: number, chunkZ: number, width: number, depth: number): boolean
	for dx = 0, width - 1 do
		for dz = 0, depth - 1 do
			if occupiedCells[cellKey(chunkX + dx, chunkZ + dz)] then
				return true
			end
		end
	end
	return false
end

-- Is every cell this footprint would occupy actually unlocked? This is the real,
-- accurate check (not a bounding-box heuristic) since it's grounded in real spawned
-- floor models, not a guess about the floor's overall rectangular extent.
local function areAllCellsUnlocked(chunkX: number, chunkZ: number, width: number, depth: number): boolean
	for dx = 0, width - 1 do
		for dz = 0, depth - 1 do
			if not unlockedCells[cellKey(chunkX + dx, chunkZ + dz)] then
				return false
			end
		end
	end
	return true
end

local pendingPlacement: { slotName: string, chunkX: number, chunkZ: number }? = nil

local function tryConfirmPlacement()
	if pendingPlacement then
		S.RemoteEvent("PlaceEquipmentRequest")
			:Fire(pendingPlacement.slotName, pendingPlacement.chunkX, pendingPlacement.chunkZ, ghostRotation)
	end
end

local function tryConfirmDelete()
	if deleteHighlightTarget then
		local slotName = deleteHighlightTarget:GetAttribute("EquipmentSlot")
		if slotName then
			S.RemoteEvent("RemoveEquipmentRequest"):Fire(slotName)
		end
	end
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if not active or gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if selectedSlot == "delete" then
			tryConfirmDelete()
		elseif selectedSlot then
			tryConfirmPlacement()
		end
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		ghostRotation = (ghostRotation + 1) % 4
		return
	end

	if input.KeyCode == Enum.KeyCode.X then
		selectSlot("delete")
		return
	end

	for keyNumber, keyCode in ipairs(NUMBER_KEYCODES) do
		if input.KeyCode == keyCode then
			local slotName = keyBindings[tostring(keyNumber)]
			if slotName then
				selectSlot(slotName)
			end
			return
		end
	end
end

function BuildUI.onStart(buildGui: ScreenGui)
	gui = buildGui
	hotbar = buildGui:WaitForChild("hotbar") :: Frame
	sampleTemplate = hotbar:WaitForChild("Sample") :: Frame
	deleteSlot = hotbar:WaitForChild("Delete") :: Frame
	local closeSlot = hotbar:WaitForChild("Close") :: Frame

	sampleTemplate.Visible = false
	deleteSlot.LayoutOrder = 998
	closeSlot.LayoutOrder = 999

	usePrimaryButton(deleteSlot.Delete.TextButton, onDeleteButtonClicked)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("equipment_json"):Connect(function()
		if active then
			refreshHotbar()
			refreshUnlockedCells()
		end
	end)

	S.RemoteEvent("PlaceEquipmentFailed"):CallBack(function(slotName, reason)
		warn("[BuildUI] Place failed for " .. tostring(slotName) .. ": " .. tostring(reason))
	end)

	S.RemoteEvent("RemoveEquipmentFailed"):CallBack(function(slotName, reason)
		warn("[BuildUI] Remove failed for " .. tostring(slotName) .. ": " .. tostring(reason))
	end)

	UserInputService.InputBegan:Connect(onInputBegan)

	RunService.RenderStepped:Connect(function(dt: number)
		if not active then
			pendingPlacement = nil
			return
		end

		if selectedSlot == "delete" then
			clearGhost()
			pendingPlacement = nil

			local player = Players.LocalPlayer
			local mouse = player:GetMouse()
			local target = findPlacedEquipmentAncestor(mouse.Target)
			if target then
				highlightForDelete(target)
			else
				clearDeleteHighlight()
			end
			return
		end

		clearDeleteHighlight()

		if not selectedSlot then
			clearGhost()
			pendingPlacement = nil
			return
		end

		local floorPart = getFloorPart()
		if not floorPart then
			clearGhost()
			pendingPlacement = nil
			return
		end

		local rawX, rawZ = getMouseFloorHit(floorPart)
		if not rawX or not rawZ then
			return
		end

		local width, depth = EquipmentTypes.getEffectiveChunkSize(selectedSlot, ghostRotation, GhostModelsFolder)
		local chunkX, chunkZ = getHoveredChunk(floorPart, rawX, rawZ)

		local targetChunkX, targetChunkZ = chunkX, chunkZ

		if not areAllCellsUnlocked(chunkX, chunkZ, width, depth) then
			-- Near a locked cell: try sliding along just one axis (keeping the other pinned
			-- to the last valid hover) instead of freezing on both, so moving the mouse back
			-- and forth reads as "clamped to an accessible axis" rather than a stutter.
			if lastValidChunkZ and areAllCellsUnlocked(chunkX, lastValidChunkZ, width, depth) then
				targetChunkX, targetChunkZ = chunkX, lastValidChunkZ
			elseif lastValidChunkX and areAllCellsUnlocked(lastValidChunkX, chunkZ, width, depth) then
				targetChunkX, targetChunkZ = lastValidChunkX, chunkZ
			else
				-- Neither axis is accessible either -- stay fully frozen at the last position.
				return
			end
		end

		lastValidChunkX, lastValidChunkZ = targetChunkX, targetChunkZ

		updateGhostPosition(selectedSlot, floorPart, targetChunkX, targetChunkZ, width, depth, dt)
		setGhostValid(not isIntersectingOccupied(targetChunkX, targetChunkZ, width, depth))

		pendingPlacement = { slotName = selectedSlot, chunkX = targetChunkX, chunkZ = targetChunkZ }
	end)
end

function BuildUI.show()
	active = true
	selectedSlot = nil
	clearGhost()
	clearDeleteHighlight()
	refreshHotbar()
	refreshUnlockedCells()
end

function BuildUI.hide()
	active = false
	selectedSlot = nil
	clearGhost()
	clearDeleteHighlight()
	applySelectionVisual()
	hideGridTexture()
end

return BuildUI
