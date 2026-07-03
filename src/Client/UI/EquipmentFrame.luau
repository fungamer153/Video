local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentTypes = require(ReplicatedStorage.Shared.EquipmentTypes)

local upgradeRequest = ReplicatedStorage:WaitForChild("UpgradeEquipmentRequest")
local upgradeFailed = ReplicatedStorage:WaitForChild("UpgradeEquipmentFailed")

local SHOW_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local TAB_STYLE_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FILL_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FILL_HOLD_TIME = 0.3

local HIDDEN_POSITION = UDim2.new(0.5, 0, 1.3, 0)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local SLOT_ORDER = { "laptop", "desk" }

local EquipmentFrame = {}

local slideFrame = nil
local scrollingFrame = nil
local sampleTemplate = nil
local tabsFrame = nil
local spawnedCards = {}
local tabButtons = {}
local selectedCategory = "All"
local lastEquipmentData = nil
local pendingUpgradeSlot = nil

local activeStyle = nil
local inactiveStyle = nil

local function captureTabStyle(tabInstance)
	local stroke = tabInstance:FindFirstChildOfClass("UIStroke")
	local action = tabInstance:FindFirstChild("Action")

	return {
		backgroundColor = tabInstance.BackgroundColor3,
		strokeColor = stroke and stroke.Color,
		textColor = action and action.TextColor3,
	}
end

local function applyTabStyle(tabInstance, style)
	local stroke = tabInstance:FindFirstChildOfClass("UIStroke")
	local action = tabInstance:FindFirstChild("Action")

	TweenService:Create(tabInstance, TAB_STYLE_TWEEN, {
		BackgroundColor3 = style.backgroundColor,
	}):Play()

	if stroke and style.strokeColor then
		TweenService:Create(stroke, TAB_STYLE_TWEEN, {
			Color = style.strokeColor,
		}):Play()
	end

	if action and style.textColor then
		TweenService:Create(action, TAB_STYLE_TWEEN, {
			TextColor3 = style.textColor,
		}):Play()
	end
end

local function clearCards()
	for _, card in spawnedCards do
		card:Destroy()
	end
	table.clear(spawnedCards)
end

local function formatStatMultiplier(statMultiplier)
	local parts = {}

	for topic, mult in statMultiplier do
		table.insert(parts, topic .. " x" .. tostring(mult))
	end

	if #parts == 0 then
		return "No topic bonus"
	end

	return table.concat(parts, ", ")
end

local function requestUpgrade(slotName, currency)
	if pendingUpgradeSlot then
		return
	end

	pendingUpgradeSlot = slotName
	upgradeRequest:FireServer(slotName, currency)
end

local function wireUpgradeButtons(card, slotName, slotData)
	local viewersCost = EquipmentTypes.getUpgradeCost(slotName, slotData.level, "viewers")

	card.Gems.Visible = false

	local viewsButton = card.Views.TextButton
	local viewsAction = viewsButton:FindFirstChild("Action")
	local viewsActionShadow = viewsButton:FindFirstChild("ActionShadow")

	if viewersCost then
		if viewsAction then
			viewsAction.Text = tostring(viewersCost)
		end
		if viewsActionShadow then
			viewsActionShadow.Text = tostring(viewersCost)
		end

		viewsButton.MouseButton1Click:Connect(function()
			requestUpgrade(slotName, "viewers")
		end)
	elseif viewsAction then
		viewsAction.Text = "MAX"
	end
end

local function populateCard(card, slotName, slotData)
	local definition = EquipmentTypes.getDefinition(slotName)
	if not definition then
		return
	end

	local effective = EquipmentTypes.getEffectiveStats(slotName, slotData.level, slotData.skin)

	card.ItemImage.Image = definition.image

	local nameLabel = card:FindFirstChild("Action")
	local levelLabel = card:FindFirstChild("Level")

	if nameLabel then
		nameLabel.Text = definition.name
	end

	if levelLabel then
		levelLabel.Text = "Level " .. tostring(slotData.level)
	end

	local bonusPercent = math.floor((effective.multiplier - 1) * 100)

	local viewStatsRows = card.InfoFrame["View Stats"]:GetChildren()
	local rowIndex = 0
	for _, row in viewStatsRows do
		if row:IsA("Frame") and row.Name == "Frame" then
			rowIndex += 1
			local viewsLabel = row:FindFirstChild("Views")
			if viewsLabel then
				if rowIndex == 1 then
					viewsLabel.Text = "+" .. tostring(bonusPercent) .. "%"
				else
					viewsLabel.Text = formatStatMultiplier(effective.statMultiplier)
				end
			end
		end
	end

	local barProgress = EquipmentTypes.getBarProgress(slotName, slotData.level)
	card.ProgressFrame.Fill.Size = UDim2.new(barProgress, 0, 1, 0)

	wireUpgradeButtons(card, slotName, slotData)
end

local function slotMatchesCategory(slotName)
	if selectedCategory == "All" then
		return true
	end

	local definition = EquipmentTypes.getDefinition(slotName)
	return definition and definition.category == selectedCategory
end

local function renderEquipment(equipmentData)
	clearCards()

	for _, slotName in SLOT_ORDER do
		local slotData = equipmentData[slotName]
		if slotData and slotMatchesCategory(slotName) then
			local card = sampleTemplate:Clone()
			card.Visible = true
			card.Name = slotName
			card.Parent = scrollingFrame

			populateCard(card, slotName, slotData)

			table.insert(spawnedCards, card)
		end
	end

	lastEquipmentData = equipmentData
end

local function findCard(slotName)
	for _, card in spawnedCards do
		if card.Name == slotName then
			return card
		end
	end
	return nil
end

local function getEquipmentData()
	local player = Players.LocalPlayer
	local raw = player:GetAttribute("equipment_json")
	if not raw then
		return nil
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)

	if ok then
		return decoded
	end

	return nil
end

local function refresh()
	local equipmentData = getEquipmentData()
	if equipmentData then
		renderEquipment(equipmentData)
	end
end

local function onEquipmentChanged()
	local newData = getEquipmentData()
	if not newData then
		return
	end

	local upgradedSlot = pendingUpgradeSlot
	if upgradedSlot and lastEquipmentData then
		local oldLevel = lastEquipmentData[upgradedSlot] and lastEquipmentData[upgradedSlot].level or 0
		local newLevel = newData[upgradedSlot] and newData[upgradedSlot].level or 0

		if newLevel > oldLevel then
			local card = findCard(upgradedSlot)
			pendingUpgradeSlot = nil

			if card then
				local newProgress = EquipmentTypes.getBarProgress(upgradedSlot, newLevel)

				TweenService:Create(card.ProgressFrame.Fill, FILL_TWEEN, {
					Size = UDim2.new(newProgress, 0, 1, 0),
				}):Play()

				task.delay(FILL_TWEEN.Time + FILL_HOLD_TIME, function()
					renderEquipment(newData)
				end)

				return
			end
		end
	end

	pendingUpgradeSlot = nil
	renderEquipment(newData)
end

local function selectCategory(category)
	if selectedCategory == category then
		return
	end

	selectedCategory = category

	for tabCategory, tabInstance in tabButtons do
		applyTabStyle(tabInstance, tabCategory == category and activeStyle or inactiveStyle)
	end

	refresh()
end

local function createTabs()
	local activeTemplate = tabsFrame.TabSample
	local inactiveTemplate = tabsFrame.TabSampleInactive

	activeStyle = captureTabStyle(activeTemplate)
	inactiveStyle = captureTabStyle(inactiveTemplate)

	activeTemplate.Visible = false
	inactiveTemplate.Visible = false

	local listLayout = tabsFrame:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	for index, category in EquipmentTypes.categories do
		local tabInstance = inactiveTemplate:Clone()
		tabInstance.Name = category
		tabInstance.LayoutOrder = index
		tabInstance.Visible = true

		local action = tabInstance:FindFirstChild("Action")
		if action then
			action.Text = category
		end

		local button = Instance.new("TextButton")
		button.Name = "ClickCatcher"
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Size = UDim2.fromScale(1, 1)
		button.ZIndex = 10
		button.Parent = tabInstance

		button.MouseButton1Click:Connect(function()
			selectCategory(category)
		end)

		tabInstance.Parent = tabsFrame
		tabButtons[category] = tabInstance
	end

	applyTabStyle(tabButtons["All"], activeStyle)
end

function EquipmentFrame.onStart(equipmentGui)
	slideFrame = equipmentGui.Frame
	scrollingFrame = slideFrame.Holder.ScrollingFrame
	sampleTemplate = scrollingFrame.Sample
	sampleTemplate.Visible = false
	tabsFrame = slideFrame.Tabs

	slideFrame.Position = HIDDEN_POSITION

	createTabs()

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("equipment_json"):Connect(function()
		if slideFrame.Visible then
			onEquipmentChanged()
		end
	end)

	upgradeFailed.OnClientEvent:Connect(function(slotName, reason)
		if pendingUpgradeSlot == slotName then
			pendingUpgradeSlot = nil
		end
		warn("[EquipmentFrame] Upgrade failed for " .. tostring(slotName) .. ": " .. tostring(reason))
	end)
end

function EquipmentFrame.show()
	slideFrame.Visible = true
	slideFrame.Position = HIDDEN_POSITION

	TweenService:Create(slideFrame, SHOW_TWEEN, {
		Position = SHOWN_POSITION,
	}):Play()

	selectedCategory = "All"
	for tabCategory, tabInstance in tabButtons do
		applyTabStyle(tabInstance, tabCategory == "All" and activeStyle or inactiveStyle)
	end

	refresh()
end

function EquipmentFrame.hide()
	TweenService:Create(slideFrame, HIDE_TWEEN, {
		Position = HIDDEN_POSITION,
	}):Play()

	task.delay(HIDE_TWEEN.Time, function()
		slideFrame.Visible = false
		clearCards()
	end)
end

return EquipmentFrame
