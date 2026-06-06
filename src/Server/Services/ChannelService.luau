local TextService = game:GetService("TextService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerNetwork = require(ServerScriptService.Server.Modules.ServerNetwork)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

local ChannelService = {}

local function filterText(text, fromUserId)
	local success, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId)
	end)

	if not success then
		return nil
	end

	local filteredSuccess, filteredText = pcall(function()
		return result:GetNonChatStringForBroadcastAsync()
	end)

	if not filteredSuccess then
		return nil
	end

	return filteredText
end

function ChannelService.onStart()
	ServerNetwork.ChangeChannelName.setCallback(function(player, text)
		local filteredText = filterText(text, player.UserId)

		if not filteredText then
			return "Fail"
		end

		if filteredText ~= text then
			return "Filtered"
		end

		local currentChannel = ProfileService.get(player, "channel")
		ProfileService.setChannel(player, {
			channelName = text,
			comments = currentChannel.comments,
		})

		return "Success"
	end)
end

return ChannelService
