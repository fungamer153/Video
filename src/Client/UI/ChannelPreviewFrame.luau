local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)

local INTRO_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0.58, 0)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local CONFIRM_SLIDE_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CONFIRM_HIDDEN_POSITION = UDim2.new(0.5, 0, 1.18, 0)
local CONFIRM_SHOWN_POSITION = UDim2.new(0.5, 0, 1.10, 0)

local CONFIRM_ORIGINAL = {
	["Frame"] = { BackgroundTransparency = 0.5 },
	["TextButton"] = { BackgroundTransparency = 0, TextTransparency = 0 },
	["ImageLabel"] = { ImageTransparency = 0 },
	["LevelLabel"] = { TextTransparency = 0 },
	["UIStroke"] = { Transparency = 0 },
}

local frame = nil
local onConfirmCallback = nil
local confirmSlideThread = nil

local ChannelPreviewFrame = {}

local function getConfirm()
	return frame.Confirm
end

local function getConfirmButton()
	return frame.Confirm.TextButton
end

local function getChannelNameLabel()
	return frame.Holder.ChannelName
end

local function getViewersLabel()
	return frame.Holder.Stats.Holder.Views.Stats.Title
end

local function getSubscribersLabel()
	return frame.Holder.Stats.Holder.Subscribers.Stats.Title
end

local function setConfirmTransparent()
	local confirm = getConfirm()
	for _, v in ipairs(confirm:GetDescendants()) do
		if v:IsA("GuiObject") then
			v.BackgroundTransparency = 1
		end

		if v:IsA("TextLabel") or v:IsA("TextButton") then
			v.TextTransparency = 1
		end

		if v:IsA("ImageLabel") or v:IsA("ImageButton") then
			v.ImageTransparency = 1
		end

		if v:IsA("UIStroke") then
			v.Transparency = 1
		end
	end
end

local function slideInConfirm()
	local confirm = getConfirm()
	confirm.Position = CONFIRM_HIDDEN_POSITION
	setConfirmTransparent()

	TweenService:Create(confirm, CONFIRM_SLIDE_TWEEN, {
		Position = CONFIRM_SHOWN_POSITION,
	}):Play()

	for _, v in ipairs(confirm:GetDescendants()) do
		local original = CONFIRM_ORIGINAL[v.Name]
		if original then
			TweenService:Create(v, CONFIRM_SLIDE_TWEEN, original):Play()
		end
	end
end

local function playIntroAnimation()
	local confirm = getConfirm()
	confirm.Position = CONFIRM_HIDDEN_POSITION
	setConfirmTransparent()

	frame.Position = HIDDEN_POSITION
	frame.BackgroundTransparency = 1

	TweenService:Create(frame, INTRO_TWEEN, {
		Position = SHOWN_POSITION,
		BackgroundTransparency = 0,
	}):Play()

	if confirmSlideThread then
		task.cancel(confirmSlideThread)
	end

	confirmSlideThread = task.delay(1, slideInConfirm)
end

function ChannelPreviewFrame.onStart(channelPreviewFrame)
	frame = channelPreviewFrame

	usePrimaryButton(getConfirmButton(), function()
		if onConfirmCallback then
			onConfirmCallback()
		end
	end)

	InterfaceController.onScreenChanged(function(screenName)
		if screenName == "ChannelPreview" then
			playIntroAnimation()
		end
	end)
end

function ChannelPreviewFrame.setChannelName(name)
	getChannelNameLabel().Text = name
end

function ChannelPreviewFrame.setViewers(count)
	getViewersLabel().Text = tostring(count)
end

function ChannelPreviewFrame.setSubscribers(count)
	getSubscribersLabel().Text = tostring(count)
end

function ChannelPreviewFrame.onConfirm(callback)
	onConfirmCallback = callback
end

return ChannelPreviewFrame
