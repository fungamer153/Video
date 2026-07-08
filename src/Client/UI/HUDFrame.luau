local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local S = require(game:GetService("ReplicatedFirst").Services.Internal.Shortcuts)
local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local Charm = require(ReplicatedStorage.Packages.Charm)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)
local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local RecordingFrame = require(ReplicatedStorage.Client.UI.RecordingFrame)
local TopicPicker = require(ReplicatedStorage.Client.UI.TopicPicker)

local mainUI = nil
local shineConnection = nil

local HUDFrame = {}

local function getRecordButton()
	return mainUI.MainFrame.RecordButton
end

local function getShine()
	return mainUI.MainFrame.RecordButton.Shine
end

local function toggleMiddleFrame(state)
	mainUI.MainFrame.Visible = state
end

local function getBackgroundImages()
	local images = {}

	for _, child in ipairs(getRecordButton():GetChildren()) do
		if child:IsA("ImageLabel") and child.Name == "ImageLabel" then
			table.insert(images, child)
		end
	end

	return images
end

local function startShineRotation()
	if shineConnection then
		shineConnection:Disconnect()
	end

	local backgroundImages = getBackgroundImages()

	shineConnection = RunService.Heartbeat:Connect(function(dt)
		getShine().Rotation = (getShine().Rotation + dt * 30) % 360

		for _, image in backgroundImages do
			image.Rotation = (image.Rotation + dt * 30) % 360
		end
	end)
end

local function stopShineRotation()
	if shineConnection then
		shineConnection:Disconnect()
		shineConnection = nil
	end
end

local function getViewsLabel()
	return mainUI.Views.Views
end

local function getSubscribersLabel()
	return mainUI.SubscriberFrame.Frame.Subscribers
end

function HUDFrame.onStart(hudUI)
	mainUI = hudUI

	RecordingFrame.onStart(hudUI:WaitForChild("RecordingFrame"))
	TopicPicker.onStart(hudUI:WaitForChild("TopicPicker"))

	local player = Players.LocalPlayer
	local recordingButton = getRecordButton()

	local function seedAtoms()
		local viewers = player:GetAttribute("stat_viewers")
		local subscribers = player:GetAttribute("stat_subscribers")

		if viewers then
			ClientAtoms.viewers(viewers)
		end

		if subscribers then
			ClientAtoms.subscribers(subscribers)
		end
	end
	seedAtoms()

	player:GetAttributeChangedSignal("stat_viewers"):Connect(function()
		ClientAtoms.viewers(player:GetAttribute("stat_viewers") or 0)
	end)

	player:GetAttributeChangedSignal("stat_subscribers"):Connect(function()
		ClientAtoms.subscribers(player:GetAttribute("stat_subscribers") or 0)
	end)

	getViewsLabel().Text = tostring(ClientAtoms.viewers())
	getSubscribersLabel().Text = tostring(ClientAtoms.subscribers())

	Charm.subscribe(ClientAtoms.viewers, function(newValue)
		getViewsLabel().Text = tostring(newValue)
	end)

	Charm.subscribe(ClientAtoms.subscribers, function(newValue)
		getSubscribersLabel().Text = tostring(newValue)
	end)

	TopicPicker.onTopicSelected(function(topicName)
		local succ = S.RemoteFunction("StartVideo"):Invoke(topicName)

		if succ == "Success" then
			TopicPicker.hide()
			RecordingFrame.setupVideoTimeData(0, 1)

			task.delay(0.25, function()
				RecordingFrame.show()
			end)
		end
	end)

	TopicPicker.onClose(function()
		toggleMiddleFrame(true)
	end)

	print(recordingButton)

	usePrimaryButton(recordingButton.TextButton, function()
		TopicPicker.show()
		toggleMiddleFrame(false)
	end)

	startShineRotation()
end

function HUDFrame.showOnlyMiddle()
	toggleMiddleFrame(true)

	for _, child in ipairs(mainUI:GetChildren()) do
		if child.Name ~= "MainFrame" and child.Name ~= "RecordingFrame" then
			child.Visible = false
		end
	end

	getRecordButton().Visible = true
	startShineRotation()
end

function HUDFrame.showRecordingFrame()
	toggleMiddleFrame(false)
	mainUI.RecordingFrame.Visible = true
end

function HUDFrame.showMainHUD()
	InterfaceController.showHUD("HUD")

	mainUI.Views.Visible = true
	mainUI.UpperButtons.Visible = true
	mainUI.MainFrame.Visible = true
	mainUI.LeftButtons.Visible = true
	mainUI.SubscriberFrame.Visible = true
	mainUI.RecordingFrame.Visible = false
end

function HUDFrame.showAll()
	stopShineRotation()

	for _, child in ipairs(mainUI:GetChildren()) do
		child.Visible = true
	end
end

function HUDFrame.onRecordPressed(callback)
	HUDFrame._onRecordPressed = callback
end

return HUDFrame
