local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local CanUseCommands = require(ReplicatedStorage.Modules.Logics.CanUseCommands)

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		-- local userId = context.Executor.UserId

		-- local player = Players:GetPlayerByUserId(userId)

		-- if not CanUseCommands(player) then
		-- 	return "You don't have permission to use this command"
		-- end

		return
	end)
end
