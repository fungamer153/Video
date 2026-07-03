local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveComments = require(ReplicatedStorage.Shared.LiveComments)
local usePrimaryButton = require(ReplicatedStorage.Client.UI.Utility.usePrimaryButton)

local liveBarFilled = ReplicatedStorage:WaitForChild("LiveBarFilled")

local SHOW_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local BAR_ANIMATION_DURATION = 0.35

local SHAKE_DURATION = 0.3
local SHAKE_MAGNITUDE = 6

local HIDDEN_POSITION = UDim2.new(0.5, 0, 1.3, 0)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local TOTAL_COMMENTS = 20
local BAR_STEP = 0.1
local POSITIVE_CHANCE = 0.65
local COMMENT_MIN_WAIT = 5
local COMMENT_MAX_WAIT = 10

local GOOD_COLOR = Color3.fromRGB(0, 197, 0)
local BAD_COLOR = Color3.fromRGB(220, 40, 40)

local LiveFrame = {}

local slideFrame = nil
local barFill = nil
local fillGradient = nil
local barContainer = nil
local barBasePosition = nil
local commentHolder = nil
local commentTemplate = nil
local currentCard = nil
local channelLabel, videoLabel, topicLabel = nil, nil, nil
local counterLabel = nil
local shakeConnection = nil

local availableQueue = {}
local currentComment = nil
local deliveredCount = 0
local respondedCount = 0
local barProgress = 0
local sessionId = 0

local MAX_FRIEND_USERNAMES = 30

local friendUsernames = nil
local friendsFetchStarted = false

local function fetchFriendUsernames()
	if friendsFetchStarted then
		return
	end
	friendsFetchStarted = true

	local player = Players.LocalPlayer
	local names = {}

	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)

	if ok and pages then
		pcall(function()
			while true do
				local currentPage = pages:GetCurrentPage()

				for _, friend in currentPage do
					table.insert(names, friend.Username)

					if #names >= MAX_FRIEND_USERNAMES then
						return
					end
				end

				if pages.IsFinished then
					break
				end

				pages:AdvanceToNextPageAsync()
			end
		end)
	end

	if #names > 0 then
		friendUsernames = names
	end
end

local function getUsernamePool()
	return friendUsernames or LiveComments.usernames
end

local function makeRandomComment()
	local isPositive = math.random() < POSITIVE_CHANCE
	local pool = isPositive and LiveComments.positive or LiveComments.negative
	local usernamePool = getUsernamePool()
	local username = usernamePool[math.random(1, #usernamePool)]
	local text = pool[math.random(1, #pool)]

	return {
		username = username,
		text = text,
		positive = isPositive,
	}
end

local function buildProgressSequence(progress)
	local edgeStart = math.clamp(progress, 0, 0.998)
	local edgeEnd = math.min(edgeStart + 0.001, 0.999)

	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(edgeStart, 0),
		NumberSequenceKeypoint.new(edgeEnd, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local barAnimConnection = nil

local function setBar(progress, duration)
	local targetProgress = math.clamp(progress, 0, 1)

	if barAnimConnection then
		barAnimConnection:Disconnect()
		barAnimConnection = nil
	end

	if not duration or duration <= 0 then
		barProgress = targetProgress
		fillGradient.Transparency = buildProgressSequence(barProgress)
		return
	end

	local startProgress = barProgress
	local elapsed = 0

	barAnimConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3

		barProgress = startProgress + (targetProgress - startProgress) * eased
		fillGradient.Transparency = buildProgressSequence(barProgress)

		if alpha >= 1 then
			barAnimConnection:Disconnect()
			barAnimConnection = nil
		end
	end)
end

local function shakeBar()
	if shakeConnection then
		shakeConnection:Disconnect()
		barContainer.Position = barBasePosition
	end

	local elapsed = 0

	shakeConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		if elapsed >= SHAKE_DURATION then
			shakeConnection:Disconnect()
			shakeConnection = nil
			barContainer.Position = barBasePosition
			return
		end

		local falloff = 1 - (elapsed / SHAKE_DURATION)
		local offset = math.sin(elapsed * 50) * SHAKE_MAGNITUDE * falloff
		barContainer.Position = barBasePosition + UDim2.new(0, offset, 0, 0)
	end)
end

local function updateCounter()
	counterLabel.Text = tostring(deliveredCount - respondedCount) .. "/" .. tostring(TOTAL_COMMENTS)
end

local function clearCard()
	if currentCard then
		currentCard:Destroy()
		currentCard = nil
	end
end

local respond

local function spawnCard()
	clearCard()

	local card = commentTemplate:Clone()
	card.Visible = true
	card.Parent = commentHolder

	usePrimaryButton(card.Accept.TextButton, function()
		respond(true)
	end)

	usePrimaryButton(card.Ignore.TextButton, function()
		respond(false)
	end)

	currentCard = card
	return card
end

local function showComment(comment)
	local card = spawnCard()
	local color = comment.positive and GOOD_COLOR or BAD_COLOR

	card.User.Text = '<font color="#1965D0">' .. comment.username .. '</font> <font color="#6F6F6F">says:</font>'
	card.Comment.Text = comment.text
	card.Comment.TextColor3 = color
	card.Accept.Visible = true
	card.Ignore.Visible = true
end

local function showStatusCard(message)
	local card = spawnCard()

	card.User.Text = ""
	card.Comment.Text = message
	card.Comment.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.Accept.Visible = false
	card.Ignore.Visible = false
end

local function advanceComment()
	if #availableQueue > 0 then
		currentComment = table.remove(availableQueue, 1)
		showComment(currentComment)
		return
	end

	currentComment = nil

	if deliveredCount >= TOTAL_COMMENTS then
		showStatusCard("No more comments right now!")
	else
		showStatusCard("Waiting for the next comment...")
	end
end

local function arrivalLoop(mySessionId)
	while sessionId == mySessionId and deliveredCount < TOTAL_COMMENTS do
		local waitTime = COMMENT_MIN_WAIT + math.random() * (COMMENT_MAX_WAIT - COMMENT_MIN_WAIT)
		task.wait(waitTime)

		if sessionId ~= mySessionId then
			return
		end

		deliveredCount += 1
		table.insert(availableQueue, makeRandomComment())
		updateCounter()

		if not currentComment then
			advanceComment()
		end
	end
end

local function onFillComplete()
	liveBarFilled:FireServer()
	setBar(0)
end

respond = function(isAccept)
	if not currentComment then
		return
	end

	local comment = currentComment
	respondedCount += 1
	updateCounter()

	local isCorrect = (comment.positive and isAccept) or (not comment.positive and not isAccept)

	if isCorrect then
		local targetProgress = barProgress + BAR_STEP
		setBar(targetProgress, BAR_ANIMATION_DURATION)

		if targetProgress >= 1 then
			task.delay(BAR_ANIMATION_DURATION, onFillComplete)
		end
	else
		setBar(barProgress - BAR_STEP, BAR_ANIMATION_DURATION)
		shakeBar()
	end

	advanceComment()
end

function LiveFrame.onStart(liveGui)
	slideFrame = liveGui.Frame

	local main = slideFrame.Holder.Main
	barContainer = main.Bar.Frame
	barFill = barContainer.Fill
	fillGradient = barFill:FindFirstChildOfClass("UIGradient")
	barBasePosition = barContainer.Position

	local upper = main.Upper
	local textLabels = {}
	for _, child in ipairs(upper:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(textLabels, child)
		end
	end
	channelLabel = textLabels[1]
	videoLabel = textLabels[2]
	topicLabel = textLabels[3]

	local comments = main.Comments
	commentHolder = comments.CommentHolder
	commentTemplate = commentHolder.Sample
	commentTemplate.Visible = false

	for _, child in ipairs(comments:GetChildren()) do
		if child.Name == "User" and child.Position.X.Scale > 0.5 then
			counterLabel = child
		end
	end

	slideFrame.Position = HIDDEN_POSITION

	task.spawn(fetchFriendUsernames)
end

function LiveFrame.show()
	slideFrame.Visible = true
	slideFrame.Position = HIDDEN_POSITION

	TweenService:Create(slideFrame, SHOW_TWEEN, {
		Position = SHOWN_POSITION,
	}):Play()

	local player = Players.LocalPlayer
	local channelName = player:GetAttribute("stat_channelName")
	local videoProgress = player:GetAttribute("stat_videoProgress")
	local lastVideoRaw = player:GetAttribute("lastVideo_json")

	local lastVideo = nil
	if lastVideoRaw then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(lastVideoRaw)
		end)
		if ok then
			lastVideo = decoded
		end
	end

	channelLabel.Text = (channelName and channelName ~= "") and channelName or "YOUR CHANNEL NAME"
	videoLabel.Text = "Video #" .. tostring(videoProgress or 0)

	if lastVideo and lastVideo.topic and lastVideo.topic ~= "" then
		topicLabel.Text = lastVideo.topic
	else
		topicLabel.Text = "No videos yet"
	end

	availableQueue = {}
	currentComment = nil
	deliveredCount = 0
	respondedCount = 0
	barProgress = 0
	setBar(0)
	clearCard()

	sessionId += 1
	local mySessionId = sessionId

	deliveredCount += 1
	table.insert(availableQueue, makeRandomComment())
	updateCounter()
	advanceComment()

	task.spawn(arrivalLoop, mySessionId)
end

function LiveFrame.hide()
	sessionId += 1

	TweenService:Create(slideFrame, HIDE_TWEEN, {
		Position = HIDDEN_POSITION,
	}):Play()

	task.delay(HIDE_TWEEN.Time, function()
		slideFrame.Visible = false
		clearCard()
	end)
end

return LiveFrame
