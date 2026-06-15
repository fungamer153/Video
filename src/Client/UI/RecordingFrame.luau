local TweenService = game:GetService("TweenService")

local SHOW_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local SHOWN_POSITION = UDim2.new(0.5, 0, 0.884, 0)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 1.1, 0)

local frame = nil

local RecordingFrame = {}

local function getBar()
	return frame.Bar.Frame.Fill
end

local function getTimeLeft()
	return frame.TimeLeft
end

local function getStage()
	return frame.Stage
end

function RecordingFrame.onStart(recordingFrame)
	frame = recordingFrame
	frame.Position = HIDDEN_POSITION
	frame.Visible = false
end

function RecordingFrame.show()
	frame.Visible = true
	frame.Position = HIDDEN_POSITION

	TweenService:Create(frame, SHOW_TWEEN, {
		Position = SHOWN_POSITION,
	}):Play()
end

function RecordingFrame.hide()
	TweenService:Create(frame, HIDE_TWEEN, {
		Position = HIDDEN_POSITION,
	}):Play()

	task.delay(HIDE_TWEEN.Time, function()
		frame.Visible = false
	end)
end

function RecordingFrame.setProgress(percent: number)
	getBar().Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
end

function RecordingFrame.setTimeLeft(seconds: number)
	getTimeLeft().Text = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function RecordingFrame.setStage(text: string)
	getStage().Text = text
end

return RecordingFrame
