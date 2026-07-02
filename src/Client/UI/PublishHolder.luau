local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local STAT_KEYS = { "bad", "better", "meh", "mediocre", "great", "awesome" }
local BAR_NAMES = {
	bad = "Bad",
	better = "Better",
	meh = "Meh",
	mediocre = "Mediocre",
	great = "Great",
	awesome = "AWESOME",
}

local STAT_QUOTES = {
	bad = {
		"Try buying more equipment!",
		"Maybe pick a different topic next time.",
		"Your videos need some serious work.",
		"Ouch, that one flopped hard.",
	},
	better = {
		"You're improving, keep it up!",
		"Not bad, but there's room to grow.",
		"A decent step in the right direction.",
	},
	meh = {
		"That one was pretty average.",
		"Nothing special, but not terrible either.",
		"Middle of the pack this time.",
	},
	mediocre = {
		"It's okay, but viewers expect more.",
		"You can definitely do better than this.",
		"A forgettable upload, unfortunately.",
	},
	great = {
		"Nice work, that was a great video!",
		"Your audience is going to love this one.",
		"Solid upload, keep the momentum going!",
	},
	awesome = {
		"Incredible! That video is going viral!",
		"You've outdone yourself this time!",
		"Absolutely awesome, your channel is blowing up!",
	},
}

local POP_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local BAR_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local BAR_STAGGER = 0.06
local BAR_SEQUENCE_DURATION = (#STAT_KEYS - 1) * BAR_STAGGER + BAR_TWEEN.Time

local COUNT_DURATION = 0.8
local COUNT_START_DELAY = 1
local CONFIRM_FADE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local MIN_DISPLAY_SCALE = 0.05
local MAX_DISPLAY_SCALE = 0.9

local PublishHolder = {}

local frame = nil
local bars = {}
local baseSize = nil
local confirmCallback = nil
local descriptionLabel = nil
local viewsLabel = nil
local subscribersLabel = nil
local confirmOriginals = {}

local function captureBar(key)
	local barName = BAR_NAMES[key]
	local bar = frame.Holder.Stats[barName]
	local size = bar.Size
	local position = bar.Position
	local bottom = position.Y.Scale + size.Y.Scale

	bars[key] = {
		instance = bar,
		xScale = size.X.Scale,
		xOffset = size.X.Offset,
		posXScale = position.X.Scale,
		posXOffset = position.X.Offset,
		yOffset = size.Y.Offset,
		maxHeight = size.Y.Scale,
		bottom = bottom,
	}
end

local function snapshotConfirmOriginals()
	confirmOriginals = {}

	for _, v in ipairs(frame.Holder.Confirm:GetDescendants()) do
		local props = {}

		if v:IsA("GuiObject") then
			props.BackgroundTransparency = v.BackgroundTransparency
		end

		if v:IsA("TextLabel") or v:IsA("TextButton") then
			props.TextTransparency = v.TextTransparency
		end

		if v:IsA("ImageLabel") or v:IsA("ImageButton") then
			props.ImageTransparency = v.ImageTransparency
		end

		if v:IsA("UIStroke") then
			props.Transparency = v.Transparency
		end

		if next(props) then
			confirmOriginals[v] = props
		end
	end
end

local function setConfirmTransparent()
	for v, props in confirmOriginals do
		for propName in props do
			v[propName] = 1
		end
	end
end

local function fadeInConfirm()
	for v, props in confirmOriginals do
		TweenService:Create(v, CONFIRM_FADE_TWEEN, props):Play()
	end
end

function PublishHolder.onStart(publishHolder)
	frame = publishHolder
	baseSize = frame.Size
	descriptionLabel = frame.Holder.Header3.Frame.Action
	viewsLabel = frame.Holder.ViewStats.Views.Views
	subscribersLabel = frame.Holder.ViewStats.Subscribers.Views

	for _, key in STAT_KEYS do
		captureBar(key)
	end

	snapshotConfirmOriginals()

	frame.Holder.Confirm.TextButton.MouseButton1Click:Connect(function()
		if confirmCallback then
			confirmCallback()
		end
	end)
end

local function animateBar(key, value, maxValue, index)
	local bar = bars[key]
	local clampedValue = math.clamp(value, 0, 1)
	local proportion = 0
	if maxValue > 0 then
		proportion = clampedValue / maxValue
	end
	local displayScale = MIN_DISPLAY_SCALE + proportion * (MAX_DISPLAY_SCALE - MIN_DISPLAY_SCALE)
	local height = bar.maxHeight * displayScale
	local targetPosY = bar.bottom - height

	bar.instance.Size = UDim2.new(bar.xScale, bar.xOffset, 0, bar.yOffset)
	bar.instance.Position = UDim2.new(bar.posXScale, bar.posXOffset, bar.bottom, 0)

	task.delay(index * BAR_STAGGER, function()
		if not bar.instance or not bar.instance.Parent then
			return
		end

		TweenService:Create(bar.instance, BAR_TWEEN, {
			Size = UDim2.new(bar.xScale, bar.xOffset, height, bar.yOffset),
			Position = UDim2.new(bar.posXScale, bar.posXOffset, targetPosY, 0),
		}):Play()
	end)
end

local function setDescription(topKey)
	local quotes = STAT_QUOTES[topKey]
	if not quotes or not descriptionLabel then
		return
	end

	descriptionLabel.Text = quotes[math.random(1, #quotes)]
end

function PublishHolder.setStats(stats)
	local maxValue = 0
	local topKey = STAT_KEYS[1]

	for _, key in STAT_KEYS do
		local value = stats[key] or 0
		if value > maxValue then
			maxValue = value
			topKey = key
		end
	end

	for index, key in STAT_KEYS do
		animateBar(key, stats[key] or 0, maxValue, index - 1)
	end

	setDescription(topKey)
end

local function countUp(label, targetValue, onComplete)
	local startTime = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startTime) / COUNT_DURATION, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		local current = math.floor(eased * targetValue)

		label.Text = "+ " .. tostring(current)

		if alpha >= 1 then
			connection:Disconnect()
			label.Text = "+ " .. tostring(targetValue)

			if onComplete then
				onComplete()
			end
		end
	end)
end

function PublishHolder.show(stats)
	frame.Size = UDim2.new(baseSize.X.Scale * 0.8, baseSize.X.Offset, baseSize.Y.Scale * 0.8, baseSize.Y.Offset)

	TweenService:Create(frame, POP_TWEEN, {
		Size = baseSize,
	}):Play()

	setConfirmTransparent()
	PublishHolder.setStats(stats)

	viewsLabel.Text = "+ 0"
	subscribersLabel.Text = "+ 0"

	task.delay(BAR_SEQUENCE_DURATION + COUNT_START_DELAY, function()
		local viewersDone = false
		local subscribersDone = false

		local function tryFadeInConfirm()
			if viewersDone and subscribersDone then
				fadeInConfirm()
			end
		end

		countUp(viewsLabel, stats.viewersGained or 0, function()
			viewersDone = true
			tryFadeInConfirm()
		end)

		countUp(subscribersLabel, stats.subscribersGained or 0, function()
			subscribersDone = true
			tryFadeInConfirm()
		end)
	end)
end

function PublishHolder.hide(onComplete)
	local shrunk = UDim2.new(baseSize.X.Scale * 0.8, baseSize.X.Offset, baseSize.Y.Scale * 0.8, baseSize.Y.Offset)

	local tween = TweenService:Create(frame, HIDE_TWEEN, {
		Size = shrunk,
	})

	tween:Play()

	for v, props in confirmOriginals do
		local hidden = {}
		for propName in props do
			hidden[propName] = 1
		end

		TweenService:Create(v, HIDE_TWEEN, hidden):Play()
	end

	tween.Completed:Connect(function()
		frame.Size = shrunk

		if onComplete then
			onComplete()
		end
	end)
end

function PublishHolder.onConfirm(callback)
	confirmCallback = callback
end

return PublishHolder
