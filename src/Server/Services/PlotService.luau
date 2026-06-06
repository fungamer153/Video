local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotLocations = workspace.PlotLocations
local Plots = workspace.Plots
local SamplePlot = workspace.Sample

local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local SharedAtoms = require(ReplicatedStorage.Shared.SharedAtoms)

local PlotService = {}

function PlotService.createPlot(cframe: CFrame)
	local newSample: Folder = SamplePlot:Clone()
	local tempModel: Model = Instance.new("Model")

	for _, child in next, newSample:GetChildren() do
		child.Parent = tempModel
	end

	tempModel.Parent = Plots
	tempModel:PivotTo(cframe)
end

function PlotService.assignPlot(player: Player)
	local availablePlots = table.clone(SharedAtoms.availablePlots())

	if #availablePlots == 0 then
		warn("No available plots for player: " .. player.Name)
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()

	local plot = table.remove(availablePlots, 1)
	SharedAtoms.availablePlots(availablePlots)

	local studioPlots = table.clone(SharedAtoms.studioPlots())
	table.insert(studioPlots, plot)
	SharedAtoms.studioPlots(studioPlots)

	local plotCFrame = PlotLocations:FindFirstChild(plot).WorldCFrame
	PlotService.createPlot(plotCFrame)
	character:PivotTo(plotCFrame * CFrame.new(0, 5, 0))
end

function PlotService.onStart()
	for _, plot in next, PlotLocations:GetChildren() do
		if plot:IsA("Attachment") then
			local availablePlots = {}
			table.insert(availablePlots, plot.Name)
			SharedAtoms.availablePlots(availablePlots)
		end
	end

	ServerEvents.connect("PlayerJoined", function(extraData: { player: Player })
		local player = extraData.player
		PlotService.assignPlot(player)
	end)

	ServerEvents.connect("PlayerLeft", function(extraData: { player: Player })
		local player = extraData.player
		-- Handle player left event
	end)
end

function PlotService.exampleMethod() end

return PlotService
