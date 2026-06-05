local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type StepType =
	"Heartbeat"
	| "Stepped"
	| "RenderStepped"
	| "PreSimulation"
	| "PostSimulation"
	| "PreAnimation"
	| "PreRender"
type Module = {
	stepType: StepType?,
	priority: number?,
	onUpdate: ((deltaTime: number) -> ())?,
	onLoaded: (() -> ())?,
	onStart: (() -> ())?,
}

type LoaderOptions = {
	modulePredicate: ((module: ModuleScript) -> boolean?)?,
}

local Concur = require(ReplicatedStorage.Packages.Concur)
local Loader = require(ReplicatedStorage.Common.Loader)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

return function(folder: Folder, matchName: string, options: LoaderOptions?)
	local modules = Loader.LoadDescendants(folder, function(moduleScript)
		if options and options.modulePredicate then
			return options.modulePredicate(moduleScript) == true and (Loader.MatchesName(matchName)(moduleScript))
		end

		return Loader.MatchesName(matchName)(moduleScript)
	end)

	print("Starting modules:", TableUtil.Keys(modules))

	local threads = Loader.SpawnAll(modules, "onStart")
	local err = Concur.all(threads :: any):Await(5)
	if err == Concur.Errors.Timeout then
		error("Modules failed to start within 5 seconds. Please check your onStart functions.")
	end

	for name, obj in modules do
		if typeof(obj) == "function" or not obj.onUpdate then
			continue
		end

		local defaultStep = "Heartbeat"
		if obj.stepType then
			defaultStep = obj.stepType
		end

		if obj.stepType == "Stepped" then
			RunService.Stepped:Connect(function(_, deltaTime)
				debug.profilebegin(name .. "_SteppedUpdate")
				obj.onUpdate(deltaTime)
				debug.profileend()
			end)
		elseif obj.stepType == "RenderStepped" and obj.priority and RunService:IsClient() then
			RunService:BindToRenderStep(name .. "Update", obj.priority, function(deltaTime)
				debug.profilebegin(name .. "_RenderSteppedUpdate")
				obj.onUpdate(deltaTime)
				debug.profileend()
			end)
		else
			local rs = RunService :: any
			rs[defaultStep]:Connect(function(deltaTime)
				debug.profilebegin(name .. "_HeartbeatUpdate")
				obj.onUpdate(deltaTime)
				debug.profileend()
			end)
		end
	end

	Loader.SpawnAll(modules, "onLoaded")
end
