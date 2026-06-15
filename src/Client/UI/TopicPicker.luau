local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local Topics = require(ReplicatedStorage.Shared.Configs.Topics)

local SHOW_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local SHOWN_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 1.6, 0)

local frame = nil
local onTopicSelectedCallback = nil
local topicsLoaded = false

local TopicPicker = {}

local function getHolder()
	return frame.Holder.TopicList.Holder
end

local function getTemplate()
	return getHolder().Template
end

local function getCloseButton()
	return frame.Holder.CloseButton.TextButton
end

local function loadTopics()
	if topicsLoaded then
		return
	end
	topicsLoaded = true

	local template = getTemplate()

	for topicName in Topics do
		local item = template:Clone()
		item.Name = topicName
		item.TopicName.Text = topicName
		item.Visible = true

		usePrimaryButton(item.TextButton, function()
			if onTopicSelectedCallback then
				onTopicSelectedCallback(topicName)
			end
		end)

		item.Parent = getHolder()
	end
end

function TopicPicker.onStart(topicPickerFrame)
	frame = topicPickerFrame
	frame.Position = HIDDEN_POSITION
	frame.Visible = false

	usePrimaryButton(getCloseButton(), function()
		TopicPicker.hide()
	end)
end

function TopicPicker.show()
	loadTopics()
	frame.Visible = true
	frame.Position = HIDDEN_POSITION

	TweenService:Create(frame, SHOW_TWEEN, {
		Position = SHOWN_POSITION,
	}):Play()
end

function TopicPicker.hide()
	TweenService:Create(frame, HIDE_TWEEN, {
		Position = HIDDEN_POSITION,
	}):Play()

	task.delay(HIDE_TWEEN.Time, function()
		frame.Visible = false
	end)
end

function TopicPicker.onTopicSelected(callback)
	onTopicSelectedCallback = callback
end

return TopicPicker
