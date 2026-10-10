--!strict
-- Shared/Modules/Loader.lua  (docs/16_technical_architecture.md §3)
--
-- Used by Main.server and Main.client: requires the modules of a folder in a fixed order, calls Init() on all of
-- them, then Start() on all of them. Modules in the order list that don't exist yet (later phases) are skipped.
-- A module that isn't in the order list, or a failing require/Init/Start, is an error that names the module.

local Loader = {}

local function fail(tag: string, what: string, message: any)
	error(("[%s] %s failed: %s"):format(tag, what, tostring(message)), 0)
end

-- Returns the names of the loaded modules, in order.
function Loader.run(tag: string, folder: Instance, order: { string }): { string }
	local known = {}
	for _, name in ipairs(order) do
		known[name] = true
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") and not known[child.Name] then
			fail(tag, child.Name, "it isn't in the load order list")
		end
	end

	local names = {}
	local modules = {}
	for _, name in ipairs(order) do
		local moduleScript = folder:FindFirstChild(name)
		if moduleScript and moduleScript:IsA("ModuleScript") then
			local ok, result = xpcall(require, debug.traceback, moduleScript)
			if not ok then
				fail(tag, "require " .. name, result)
			end
			if type(result) ~= "table" then
				fail(tag, "require " .. name, "the module must return a table")
			end
			table.insert(names, name)
			table.insert(modules, result)
		end
	end

	for _, phase in ipairs({ "Init", "Start" }) do
		for index, module in ipairs(modules) do
			local fn = (module :: any)[phase]
			if type(fn) == "function" then
				local ok, message = xpcall(fn, debug.traceback)
				if not ok then
					fail(tag, names[index] .. "." .. phase, message)
				end
			end
		end
	end
	return names
end

return Loader
