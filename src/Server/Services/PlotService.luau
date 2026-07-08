local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotLocations = workspace.PlotLocations
local Plots = workspace.Plots
local SamplePlot = workspace.Sample

local ServerEvents = require(ServerScriptService.Server.Modules.ServerEvents)
local SharedAtoms = require(ReplicatedStorage.Shared.SharedAtoms)

local PlotService = {}

local plotModels: { [Player]: Model } = {}

function PlotService.createPlot(cframe: CFrame): Model
	local newSample: Folder = SamplePlot:Clone()
	local tempModel: Model = Instance.new("Model")

	for _, child in next, newSample:GetChildren() do
		child.Parent = tempModel
	end

	tempModel.Parent = Plots
	tempModel:PivotTo(cframe)

	newSample:Destroy()

	return tempModel
end

function PlotService.getPlotModel(player: Player): Model?
	return plotModels[player]
end

-- The floor reference Part is intentionally NOT authored in Sample -- it used to be,
-- but a hand-placed/leftover Instance there is fragile (easy to accidentally delete, and
-- not something Rojo tracks). Instead it's generated fresh here, lazily, directly inside
-- each player's own already-instantiated plot, sized/positioned from the shared chunk
-- template bounds (computed once at boot by PlotChunkService from the real, authored
-- Chunk marker Parts). It's pure runtime geometry: invisible, non-solid, but CanQuery is
-- left true so client-side raycasting (BuildUI's ghost/hover math) can actually hit it.
function PlotService.getFloorPart(player: Player): BasePart?
	local plotModel = plotModels[player]
	if not plotModel then
		return nil
	end

	local floorFolder = plotModel:FindFirstChild("Floor")
	if not floorFolder then
		return nil
	end

	local existing = floorFolder:FindFirstChild("Part")
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local PlotChunkService = require(script.Parent.PlotChunkService)
	local width, depth, halfHeight = PlotChunkService.getTemplateBounds()
	if not width then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = "Part"
	part.Size = Vector3.new(width, halfHeight * 2, depth)
	part.CFrame = plotModel:GetPivot() * CFrame.new(0, halfHeight, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = floorFolder

	return part
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
	local plotModel = PlotService.createPlot(plotCFrame)
	plotModel:SetAttribute("OwnerUserId", player.UserId)
	plotModel.Name = player.Name .. "'s Plot"
	plotModels[player] = plotModel

	character:PivotTo(plotCFrame * CFrame.new(0, 5, 0))

	ServerEvents.fire("PlotReady", { player = player, plotModel = plotModel })
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
		plotModels[player] = nil
	end)
end

return PlotService
