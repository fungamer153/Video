local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ClientNetwork = require(game:GetService("ReplicatedStorage").Client.Modules.ClientNetwork)

local SHOW_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local SHOWN_POSITION = UDim2.new(0.5, 0, 0.884, 0)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 1.1, 0)

local ANIMATION_DURATION = 0.5

local BASE_DURATION = 30
local TIME_INCREASE_MULTIPLIER = 1.05

local frame = nil
local clickConnection = nil
local passiveTimeConnection = nil

local totalDuration = 30
local elapsedProgressSeconds = 0
local speedModifier = 1
local isFinishingVideo = false
local lastClickTime = 0

local currentVisualProgress = 0
local targetVisualProgress = 0
local gradientRenderConnection = nil

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

local function updateTimeLeftText(secondsLeft: number)
	local clampedSeconds = math.max(0, math.ceil(secondsLeft))
	getTimeLeft().Text = string.format("%d:%02d", math.floor(clampedSeconds / 60), clampedSeconds % 60)
end

local function cleanupConnections()
	if clickConnection then
		clickConnection:Disconnect()
		clickConnection = nil
	end
	if passiveTimeConnection then
		passiveTimeConnection:Disconnect()
		passiveTimeConnection = nil
	end
	if gradientRenderConnection then
		gradientRenderConnection:Disconnect()
		gradientRenderConnection = nil
	end
end

local function attemptFinishVideo()
	if isFinishingVideo then
		return
	end
	isFinishingVideo = true
	cleanupConnections()
	RecordingFrame.hide()
end

function RecordingFrame.onStart(recordingFrame)
	frame = recordingFrame.ProgressFrame
	frame.Position = HIDDEN_POSITION

	recordingFrame.Visible = true
	frame.Visible = false

	ClientNetwork.StartTutorial.on(function()
		attemptFinishVideo()
	end)
end

function RecordingFrame.setupVideoTimeData(videosMade: number, totalSpeedMod: number)
	speedModifier = totalSpeedMod or 1
	totalDuration = BASE_DURATION * math.pow(TIME_INCREASE_MULTIPLIER, videosMade)
	elapsedProgressSeconds = 0
	currentVisualProgress = 0
	targetVisualProgress = 0
	isFinishingVideo = false

	updateTimeLeftText(totalDuration)
end

function RecordingFrame.registerClicks()
	local targetUi = frame:WaitForChild("Bar")
	local uiGradient = targetUi:WaitForChild("Frame"):WaitForChild("Fill"):WaitForChild("UIGradient")

	cleanupConnections()

	gradientRenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if math.abs(currentVisualProgress - targetVisualProgress) > 0.0001 then
			currentVisualProgress = currentVisualProgress
				+ (targetVisualProgress - currentVisualProgress) * (1 - math.exp(-15 * deltaTime))

			local p = math.clamp(currentVisualProgress, 0, 0.998)
			uiGradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(p, 0),
				NumberSequenceKeypoint.new(p + 0.001, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		else
			currentVisualProgress = targetVisualProgress
		end
	end)

	passiveTimeConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if elapsedProgressSeconds < totalDuration then
			elapsedProgressSeconds = math.clamp(elapsedProgressSeconds + (deltaTime * speedModifier), 0, totalDuration)
			updateTimeLeftText(totalDuration - elapsedProgressSeconds)

			local currentPct = elapsedProgressSeconds / totalDuration
			if currentPct > targetVisualProgress then
				targetVisualProgress = currentPct
			end
		else
			targetVisualProgress = 1
		end
	end)

	clickConnection = UIS.InputBegan:Connect(function(input: InputObject, isProcessed: boolean)
		if isProcessed or isFinishingVideo then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local now = os.clock()
			if now - lastClickTime < 0.05 then
				return
			end
			lastClickTime = now

			local parentX = frame.AbsolutePosition.X
			local parentY = frame.AbsolutePosition.Y

			local clickX = input.Position.X - parentX
			local clickY = input.Position.Y - parentY

			elapsedProgressSeconds = math.clamp(elapsedProgressSeconds + 1, 0, totalDuration)
			updateTimeLeftText(totalDuration - elapsedProgressSeconds)

			ClientNetwork.IncrementProgress.fire()

			local progressPercentage = math.clamp(elapsedProgressSeconds / totalDuration, 0.01, 0.999)
			targetVisualProgress = progressPercentage

			local orbTargetX = (targetUi.AbsolutePosition.X - parentX) + (targetUi.AbsoluteSize.X * progressPercentage)
			local orbTargetY = targetUi.AbsolutePosition.Y - parentY + (targetUi.AbsoluteSize.Y / 2)

			local midX = (clickX + orbTargetX) / 2
			local midY = (clickY + orbTargetY) / 2
			local curveHeight = 150

			local p1X = midX
			local p1Y = midY - curveHeight

			local progressOrb = frame.Parent:WaitForChild("ProgressOrb"):Clone()
			progressOrb.Position =
				UDim2.fromOffset(clickX - (progressOrb.AbsoluteSize.X / 2), clickY - (progressOrb.AbsoluteSize.Y / 2))
			progressOrb.Visible = true
			progressOrb.Parent = frame

			local startTime = os.clock()
			local orbConnection = nil

			orbConnection = RunService.RenderStepped:Connect(function()
				local elapsedTime = os.clock() - startTime
				local alpha = math.clamp(elapsedTime / ANIMATION_DURATION, 0, 1)

				local t = 1 - math.pow(1 - alpha, 3)

				local currentX = (1 - t) ^ 2 * clickX + 2 * (1 - t) * t * p1X + t ^ 2 * orbTargetX
				local currentY = (1 - t) ^ 2 * clickY + 2 * (1 - t) * t * p1Y + t ^ 2 * orbTargetY

				progressOrb.Position = UDim2.fromOffset(
					currentX - (progressOrb.AbsoluteSize.X / 2),
					currentY - (progressOrb.AbsoluteSize.Y / 2)
				)

				if alpha >= 1 then
					orbConnection:Disconnect()
					progressOrb:Destroy()
				end
			end)
		end
	end)
end

function RecordingFrame.show()
	isFinishingVideo = false
	frame.Visible = true
	frame.Position = HIDDEN_POSITION

	TweenService:Create(frame, SHOW_TWEEN, {
		Position = SHOWN_POSITION,
	}):Play()

	RecordingFrame.registerClicks()
end

function RecordingFrame.hide()
	cleanupConnections()

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
