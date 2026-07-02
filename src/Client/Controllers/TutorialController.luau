local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientNetwork = require(ReplicatedStorage.Client.Modules.ClientNetwork)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)
local ChannelNameFrame = require(ReplicatedStorage.Client.UI.ChannelNameFrame)
local ChannelPreviewFrame = require(ReplicatedStorage.Client.UI.ChannelPreviewFrame)
local HUDFrame = require(ReplicatedStorage.Client.UI.HUDFrame)
local PublishHolder = require(ReplicatedStorage.Client.UI.PublishHolder)
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
	end)
end

local function startTutorial()
	InterfaceController.showScreen("ChannelName")

	ChannelNameFrame.onConfirm(function(channelName)
		local result = ClientNetwork.ChangeChannelName.call(channelName)

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

	ClientNetwork.StartTutorial.on(function()
		startTutorial()
	end)

	local hudUI = playerGui:WaitForChild("HUD")
	HUDFrame.onStart(hudUI)

	local publishHolderUI = playerGui:WaitForChild("PublishStats"):WaitForChild("PublishHolder")
	PublishHolder.onStart(publishHolderUI)

	PublishHolder.onConfirm(function()
		PublishHolder.hide(function()
			InterfaceController.hideScreen()
			HUDFrame.showMainHUD()
		end)
	end)

	ClientNetwork.VideoComplete.on(function(stats)
		ClientAtoms.viewers(ClientAtoms.viewers() + (stats.viewersGained or 0))
		ClientAtoms.subscribers(ClientAtoms.subscribers() + (stats.subscribersGained or 0))

		InterfaceController.showScreen("PublishStats")
		PublishHolder.show(stats)
	end)
end

return TutorialController
