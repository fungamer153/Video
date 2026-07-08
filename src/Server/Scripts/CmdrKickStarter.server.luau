local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local startTime = os.clock()
local Cmdr = require(ReplicatedStorage.Packages.Cmdr)

Cmdr:RegisterDefaultCommands()
Cmdr:RegisterHooksIn(ServerScriptService.Cmdr.Hooks)
Cmdr:RegisterTypesIn(ServerScriptService.Cmdr.Types)
Cmdr:RegisterCommandsIn(ServerScriptService.Cmdr.Commands)
