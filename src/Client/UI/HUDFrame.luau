local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientNetwork = require(ReplicatedStorage.Client.Modules.ClientNetwork)
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

local function startShineRotation()
	if shineConnection then
		shineConnection:Disconnect()
	end

	shineConnection = RunService.Heartbeat:Connect(function(dt)
		getShine().Rotation = (getShine().Rotation + dt * 30) % 360
	end)
end

local function stopShineRotation()
	if shineConnection then
		shineConnection:Disconnect()
		shineConnection = nil
	end
end

function HUDFrame.onStart(hudUI)
	mainUI = hudUI

	RecordingFrame.onStart(hudUI:WaitForChild("RecordingFrame"))
	TopicPicker.onStart(hudUI:WaitForChild("TopicPicker"))

	TopicPicker.onTopicSelected(function(topicName)
		local succ = ClientNetwork.StartVideo.call(topicName)

		if succ == "Success" then
			TopicPicker.hide()
			RecordingFrame.setupVideoTimeData(0, 1)

			task.delay(0.25, function()
				RecordingFrame.show()
			end)
		end
	end)

	usePrimaryButton(getRecordButton().TextButton, function()
		TopicPicker.show()
		toggleMiddleFrame(false)
	end)
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
