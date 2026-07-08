local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(game:GetService("ReplicatedFirst").Services.Internal.Shortcuts)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)
local ChannelNameFrame = require(ReplicatedStorage.Client.UI.ChannelNameFrame)
local ChannelPreviewFrame = require(ReplicatedStorage.Client.UI.ChannelPreviewFrame)
local HUDFrame = require(ReplicatedStorage.Client.UI.HUDFrame)
local PublishHolder = require(ReplicatedStorage.Client.UI.PublishHolder)
local EquipmentFrame = require(ReplicatedStorage.Client.UI.EquipmentFrame)
local LiveFrame = require(ReplicatedStorage.Client.UI.LiveFrame)
local BuildUI = require(ReplicatedStorage.Client.UI.BuildUI)
local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)

local TutorialController = {}

local atomCleanups = {}

local function stopAtomListeners()
	for _, cleanup in atomCleanups do
		cleanup()
	end
	table.clear(atomCleanups)
end

local function showChannelPreview(channelName)
	stopAtomListeners()

	ChannelPreviewFrame.setChannelName(channelName)
	ChannelPreviewFrame.setViewers(0)
	ChannelPreviewFrame.setSubscribers(1)

	InterfaceController.showScreen("ChannelPreview")

	ChannelPreviewFrame.onConfirm(function()
		InterfaceController.hideScreen()
		InterfaceController.showHUD("HUD")
		HUDFrame.showOnlyMiddle()
		stopAtomListeners()

		S.RemoteEvent("TutorialComplete"):Fire()
	end)
end

local function startTutorial()
	InterfaceController.showScreen("ChannelName")

	ChannelNameFrame.onConfirm(function(channelName)
		local result = S.RemoteFunction("ChangeChannelName"):Invoke(channelName)

		if result ~= "Success" then
			return
		end

		InterfaceController.hideScreen()
		ChannelNameFrame.reset()
		showChannelPreview(channelName)
	end)
end

function TutorialController.onStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local channelNameFrame = playerGui:WaitForChild("Channel"):WaitForChild("ChannelName")
	ChannelNameFrame.onStart(channelNameFrame)

	local channelPreviewFrame = playerGui:WaitForChild("Channel"):WaitForChild("ChannelPreview")
	ChannelPreviewFrame.onStart(channelPreviewFrame)

	while not InterfaceController.isScreenRegistered("ChannelName") do
		task.wait()
	end

	S.RemoteEvent("StartTutorial"):CallBack(function()
		startTutorial()
	end)

	local hudUI = playerGui:WaitForChild("HUD")
	HUDFrame.onStart(hudUI)

	if Players.LocalPlayer:GetAttribute("TutorialAlreadyComplete") then
		InterfaceController.showHUD("HUD")
		HUDFrame.showMainHUD()
	end

	local publishHolderUI = playerGui:WaitForChild("PublishStats"):WaitForChild("PublishHolder")
	PublishHolder.onStart(publishHolderUI)

	PublishHolder.onConfirm(function()
		PublishHolder.hide(function()
			InterfaceController.hideScreen()
			HUDFrame.showMainHUD()
		end)
	end)

	S.RemoteEvent("VideoComplete"):CallBack(function(stats)
		InterfaceController.showScreen("PublishStats")
		PublishHolder.show(stats)
	end)

	local equipmentGui = playerGui:WaitForChild("Equipment")
	EquipmentFrame.onStart(equipmentGui)

	local equipmentButton = hudUI.UpperButtons.Equipment.TextButton
	usePrimaryButton(equipmentButton, function()
		InterfaceController.showScreen("Equipment")
		EquipmentFrame.show()
	end)

	local equipmentExitButton = equipmentGui.Frame.Header.Exit.TextButton
	usePrimaryButton(equipmentExitButton, function()
		EquipmentFrame.hide()
		InterfaceController.hideScreen()
		HUDFrame.showMainHUD()
	end)

	local liveGui = playerGui:WaitForChild("Live")
	LiveFrame.onStart(liveGui)

	local liveButton = hudUI.UpperButtons.Live.TextButton
	usePrimaryButton(liveButton, function()
		InterfaceController.showScreen("Live")
		LiveFrame.show()
	end)

	local liveExitButton = liveGui.Frame.Header.Exit.TextButton
	usePrimaryButton(liveExitButton, function()
		LiveFrame.hide()
		InterfaceController.hideScreen()
		HUDFrame.showMainHUD()
	end)

	local buildUiGui = playerGui:WaitForChild("BuildUI")
	BuildUI.onStart(buildUiGui)

	local buildExitOk, buildExitButton = pcall(function()
		return buildUiGui.hotbar.Close.Exit.TextButton
	end)
	if buildExitOk and buildExitButton then
		usePrimaryButton(buildExitButton, function()
			BuildUI.hide()
			InterfaceController.hideScreen()
			HUDFrame.showMainHUD()
		end)
	else
		warn(
			"[TutorialController] Could not find BuildUI exit button at hotbar.Close.Exit.TextButton: "
				.. tostring(buildExitButton)
		)
	end

	local editModeButton = hudUI.LeftButtons.EditMode.TextButton
	usePrimaryButton(editModeButton, function()
		if InterfaceController.getCurrentScreen() == "BuildUI" then
			BuildUI.hide()
			InterfaceController.hideScreen()
			HUDFrame.showMainHUD()
		else
			InterfaceController.showScreen("BuildUI")
			BuildUI.show()
		end
	end)
end

return TutorialController
