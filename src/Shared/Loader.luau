local Loader = {}

function Loader.MatchesName(partial: string)
	return function(moduleScript: ModuleScript)
		return (string.find(moduleScript.Name, partial, 1, true) ~= nil)
	end
end

function Loader.LoadDescendants(folder: Folder, predicate: (ModuleScript) -> boolean)
	local modules = {}

	for _, module in pairs(folder:GetDescendants()) do
		if module:IsA("ModuleScript") and predicate(module) then
			local success, result = pcall(require, module)
			if success then
				modules[module.Name] = result
			else
				warn("Failed to require module:", module:GetFullName(), result)
			end
		end
	end

	return modules
end

function Loader.SpawnAll(modules: { [string]: any }, methodName: string)
	local threads = {}

	for name, obj in modules do
		if typeof(obj) == "function" then
			table.insert(
				threads,
				coroutine.create(function()
					obj()
				end)
			)
		elseif typeof(obj) == "table" and obj[methodName] and typeof(obj[methodName]) == "function" then
			table.insert(
				threads,
				coroutine.create(function()
					obj[methodName]()
				end)
			)
		end
	end

	for _, thread in pairs(threads) do
		coroutine.resume(thread)
	end

	return threads
end

return Loader
