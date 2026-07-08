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
	local threadNames = {}

	for name, obj in modules do
		local callable = nil

		if typeof(obj) == "function" then
			callable = obj
		elseif typeof(obj) == "table" and obj[methodName] and typeof(obj[methodName]) == "function" then
			callable = function()
				obj[methodName]()
			end
		end

		if callable then
			local thread = coroutine.create(callable)
			table.insert(threads, thread)
			threadNames[thread] = name
		end
	end

	for _, thread in ipairs(threads) do
		local ok, err = coroutine.resume(thread)
		if not ok then
			warn(
				string.format(
					"[Loader] %s.%s threw an error: %s",
					tostring(threadNames[thread]),
					methodName,
					tostring(err)
				)
			)
		end
	end

	return threads
end

return Loader
