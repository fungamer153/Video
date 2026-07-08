local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local CanUseCommands = require(ReplicatedStorage.Modules.Logics.CanUseCommands)

-- local startTime = os.clock()
-- if CanUseCommands(Players.LocalPlayer) then
-- 	local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient")) :: any
-- 	Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })

-- 	print("Cmdr loaded in " .. os.clock() - startTime .. "s")
-- end

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient")) :: any
Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
