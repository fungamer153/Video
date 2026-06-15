local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)

local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0.58, 0)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local BOP_TWEEN_UP = TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local BOP_TWEEN_DOWN = TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HOLDER_DEFAULT_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local HOLDER_BOP_POSITION = UDim2.new(0.5, 0, 0.46, 0)

local frame = nil
local onConfirmCallback = nil
local bopTween = nil

local ChannelNameFrame = {}

local function getHolder()
	return frame.Holder
end

local function getTextBox()
	return frame.Holder.InputBox.TextBox
end

local function getConfirmButton()
	return frame.Confirm.TextButton
end

local function playIntroAnimation()
	frame.Position = HIDDEN_POSITION
	frame.BackgroundTransparency = 1

	TweenService:Create(frame, TWEEN_INFO, {
		Position = SHOWN_POSITION,
		BackgroundTransparency = 0,
	}):Play()
end

local function bopHolder()
	if bopTween then
		bopTween:Cancel()
	end

	local holder = getHolder()
	holder.Position = HOLDER_DEFAULT_POSITION

	bopTween = TweenService:Create(holder, BOP_TWEEN_UP, { Position = HOLDER_BOP_POSITION })
	bopTween:Play()

	bopTween.Completed:Connect(function()
		bopTween = TweenService:Create(holder, BOP_TWEEN_DOWN, { Position = HOLDER_DEFAULT_POSITION })
		bopTween:Play()
	end)
end

function ChannelNameFrame.onStart(channelNameFrame)
	frame = channelNameFrame

	getTextBox():GetPropertyChangedSignal("Text"):Connect(function()
		local text = getTextBox().Text
		local confirmButton = getConfirmButton()
		confirmButton.Active = #text > 0
		confirmButton.ImageLabel.ImageTransparency = if #text > 0 then 0 else 0.4
		bopHolder()
	end)

	usePrimaryButton(getConfirmButton(), function()
		local text = getTextBox().Text
		if #text == 0 then
			return
		end

		if onConfirmCallback then
			onConfirmCallback(text)
		end
	end)

	InterfaceController.onScreenChanged(function(screenName)
		if screenName == "ChannelName" then
			playIntroAnimation()
		end
	end)
end

function ChannelNameFrame.onConfirm(callback)
	onConfirmCallback = callback
end

function ChannelNameFrame.reset()
	getTextBox().Text = ""
end

return ChannelNameFrame
