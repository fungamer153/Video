local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientNetwork = require(ReplicatedStorage.Client.Modules.ClientNetwork)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)
local ChannelNameFrame = require(ReplicatedStorage.Client.UI.ChannelNameFrame)

local TutorialController = {}

local function startTutorial()
	InterfaceController.showScreen("ChannelName")

	ChannelNameFrame.onConfirm(function(channelName)
		local success = ClientNetwork.ChangeChannelName.call(channelName)

		if not success then
			print("Channel name failed filter check")
			return
		end

		InterfaceController.hideScreen()
		ChannelNameFrame.reset()
	end)
end

function TutorialController.onStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local channelNameFrame = playerGui:WaitForChild("Channel"):WaitForChild("ChannelName")

	ChannelNameFrame.onStart(channelNameFrame)

	ClientNetwork.StartTutorial.on(function()
		startTutorial()
	end)
end

return TutorialController
