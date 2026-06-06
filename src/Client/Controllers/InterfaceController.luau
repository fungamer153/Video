local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.janitor)
local Signal = require(ReplicatedStorage.Packages.Signal)

local hudRegistry = {}
local screenRegistry = {}
local hudOverrides = {}

local activeScreenName = nil
local screenJanitor = Janitor.new()
local screenChanged = Signal.new()

local function listToSet(list)
	local set = {}
	for _, name in list do
		set[name] = true
	end
	return set
end

local function resolveHUDVisibility(entry)
	local activeScreen = if activeScreenName then screenRegistry[activeScreenName] else nil

	if activeScreen then
		local config = activeScreen.config

		if config.hideAllHUDs then
			return false
		end

		if config.hideAllExceptWhitelist then
			return listToSet(config.hideAllExceptWhitelist)[entry.name] == true
		end

		if config.hideAllInBlacklist then
			if listToSet(config.hideAllInBlacklist)[entry.name] then
				return false
			end
		end
	end

	if hudOverrides[entry.name] ~= nil then
		return hudOverrides[entry.name]
	end

	return entry.visibleByDefault
end

local function refreshAllHUDs()
	for _, entry in hudRegistry do
		entry.instance.Visible = resolveHUDVisibility(entry)
	end
end

local InterfaceController = {}

function InterfaceController.registerHUD(name, instance, config)
	local resolvedConfig = config or {}

	hudRegistry[name] = {
		name = name,
		instance = instance,
		visibleByDefault = if resolvedConfig.visibleByDefault ~= nil then resolvedConfig.visibleByDefault else true,
	}

	instance.Visible = hudRegistry[name].visibleByDefault
end

function InterfaceController.registerScreen(name, instance, config)
	local resolvedConfig = config or {}

	screenRegistry[name] = {
		name = name,
		instance = instance,
		config = resolvedConfig,
	}

	if resolvedConfig.visibleByDefault then
		task.defer(function()
			InterfaceController.showScreen(name)
		end)
	else
		instance.Visible = false
	end
end

function InterfaceController.showScreen(name)
	local entry = screenRegistry[name]
	if not entry then
		warn("Screen not registered:", name)
		return
	end

	if activeScreenName == name then
		return
	end

	screenJanitor:Cleanup()

	if activeScreenName then
		local previousScreen = screenRegistry[activeScreenName]
		if previousScreen then
			previousScreen.instance.Visible = false
		end
	end

	activeScreenName = name
	table.clear(hudOverrides)

	entry.instance.Visible = true
	refreshAllHUDs()

	screenChanged:Fire(name)
end

function InterfaceController.hideScreen()
	if not activeScreenName then
		return
	end

	screenJanitor:Cleanup()

	local currentScreen = screenRegistry[activeScreenName]
	if currentScreen then
		currentScreen.instance.Visible = false
	end

	activeScreenName = nil
	table.clear(hudOverrides)
	refreshAllHUDs()

	screenChanged:Fire(nil)
end

function InterfaceController.getCurrentScreen()
	return activeScreenName
end

function InterfaceController.getScreenJanitor()
	return screenJanitor
end

function InterfaceController.onScreenChanged(callback)
	return screenChanged:Connect(callback)
end

function InterfaceController.showHUD(name)
	local entry = hudRegistry[name]
	if not entry then
		return
	end

	hudOverrides[name] = true
	entry.instance.Visible = resolveHUDVisibility(entry)
end

function InterfaceController.hideHUD(name)
	local entry = hudRegistry[name]
	if not entry then
		return
	end

	hudOverrides[name] = false
	entry.instance.Visible = resolveHUDVisibility(entry)
end

function InterfaceController.toggleHUD(name)
	local entry = hudRegistry[name]
	if not entry then
		return
	end

	hudOverrides[name] = not entry.instance.Visible
	entry.instance.Visible = resolveHUDVisibility(entry)
end

function InterfaceController.isHUDVisible(name)
	local entry = hudRegistry[name]
	if not entry then
		return false
	end
	return entry.instance.Visible
end

function InterfaceController.hideAllHUDs()
	for name, entry in hudRegistry do
		hudOverrides[name] = false
		entry.instance.Visible = false
	end
end

function InterfaceController.showAllDefaultHUDs()
	table.clear(hudOverrides)
	refreshAllHUDs()
end

function InterfaceController.onStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local hudGui = playerGui:WaitForChild("HUD")
	InterfaceController.registerHUD("HUD", hudGui.MainFrame)

	local channelGui = playerGui:WaitForChild("Channel")
	InterfaceController.registerScreen("Channel", channelGui, {
		hideAllHUDs = false,
		visibleByDefault = false,
	})

	local equipmentGui = playerGui:WaitForChild("Equipment")
	InterfaceController.registerScreen("Equipment", equipmentGui, {
		hideAllHUDs = false,
		visibleByDefault = false,
	})

	local liveGui = playerGui:WaitForChild("Live")
	InterfaceController.registerScreen("Live", liveGui, {
		hideAllHUDs = false,
		visibleByDefault = false,
	})

	local publishStatsGui = playerGui:WaitForChild("PublishStats")
	InterfaceController.registerScreen("PublishStats", publishStatsGui, {
		hideAllHUDs = true,
		visibleByDefault = false,
	})
end

return InterfaceController
