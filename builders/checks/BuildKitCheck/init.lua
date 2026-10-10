--!nonstrict
-- builders/checks/BuildKitCheck/init.lua  ->  ServerStorage.DevTools.Checks.BuildKitCheck
--
-- Smoke test (docs/18_roadmap.md Phase 0) and full self-test for BuildKit.
--
--   local DT = game:GetService("ServerStorage").DevTools
--   local BK = require(DT.BuildKit:Clone())
--   local Check = require(DT.Checks.BuildKitCheck:Clone())
--   return game:GetService("HttpService"):JSONEncode(Check.Smoke(BK))  -- 3-part model, stats, deleted
--   return game:GetService("HttpService"):JSONEncode(Check.Full(BK))   -- every BuildKit function
--
-- Both build inside Workspace.__BuildKitCheck (1000 studs up, away from every zone) and always remove it.

local Check = {}

local SANDBOX_NAME = "__BuildKitCheck"
local ORIGIN = Vector3.new(0, 1000, 0)
local CASE_MODULES = { "CasesCore", "CasesStructure", "CasesDetail", "CasesFxGameplay" }

local function makeSandbox()
	local old = workspace:FindFirstChild(SANDBOX_NAME)
	if old then
		old:Destroy()
	end
	local sandbox = Instance.new("Folder")
	sandbox.Name = SANDBOX_NAME
	sandbox.Parent = workspace
	return sandbox
end

-- Builds a 3-part test model, returns its stats in the builder format, then deletes it.
function Check.Smoke(BK)
	local P = BK.Palette
	local startClock = os.clock()
	local sandbox = makeSandbox()
	local model = BK.model(sandbox, "SmokeModel")
	BK.part(model, { Name = "Block", Size = Vector3.new(4, 2, 4), Position = ORIGIN + Vector3.new(0, 1, 0), Color = P.CONCRETE_MID, Material = "Concrete" })
	BK.wedge(model, { Name = "Wedge", Size = Vector3.new(4, 2, 4), Position = ORIGIN + Vector3.new(6, 1, 0), Color = P.STEEL_MID, Material = "Metal" })
	BK.cyl(model, { Name = "Cylinder", Axis = "Y", Size = Vector3.new(2, 4, 2), Position = ORIGIN + Vector3.new(-6, 2, 0), Color = P.AMBER, Material = "Neon" })

	local stats = BK.report(model, startClock)
	stats.builtInWorkspace = model:IsDescendantOf(workspace)
	sandbox:Destroy()
	stats.deleted = workspace:FindFirstChild(SANDBOX_NAME) == nil
	return stats
end

-- Runs every case module. Returns { passed, failed, total, failures = {{case, error}}, cases, ms }.
function Check.Full(BK)
	local startClock = os.clock()
	local sandbox = makeSandbox()
	local report = { passed = 0, failed = 0, failures = {}, cases = {} }
	local savedBudget = BK.yieldBudget
	BK.yieldBudget = 0 -- the cases are small; keep each one atomic

	local T = { BK = BK, P = BK.Palette, O = ORIGIN, sandbox = sandbox }

	function T.expect(condition, label)
		if not condition then
			error("expected: " .. tostring(label), 2)
		end
	end

	function T.expectNear(actual, expected, label, tolerance)
		if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 0.01) then
			error(("%s: expected %s, got %s"):format(tostring(label), tostring(expected), tostring(actual)), 2)
		end
	end

	function T.expectVec(actual, expected, label, tolerance)
		if (actual - expected).Magnitude > (tolerance or 0.01) then
			error(("%s: expected (%s), got (%s)"):format(tostring(label), tostring(expected), tostring(actual)), 2)
		end
	end

	function T.expectError(fn, label)
		if pcall(fn) then
			error(tostring(label) .. ": expected an error, but the call succeeded", 2)
		end
	end

	function T.hex(color)
		return color:ToHex()
	end

	-- Every BasePart under root (root included).
	function T.parts(root)
		local list = {}
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(list, descendant)
			end
		end
		return list
	end

	-- World-space axis-aligned bounds of every BasePart under root.
	function T.bounds(root)
		local min = Vector3.new(math.huge, math.huge, math.huge)
		local max = -min
		for _, part in ipairs(T.parts(root)) do
			local cf, half = part.CFrame, part.Size / 2
			local x, y, z = cf.XVector, cf.YVector, cf.ZVector
			local extent = Vector3.new(
				math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z,
				math.abs(x.Y) * half.X + math.abs(y.Y) * half.Y + math.abs(z.Y) * half.Z,
				math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
			)
			min = min:Min(cf.Position - extent)
			max = max:Max(cf.Position + extent)
		end
		return min, max
	end

	-- Raycast that only sees `root` (default: the whole sandbox).
	function T.ray(from, direction, root)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { root or sandbox }
		return workspace:Raycast(from, direction, params)
	end

	function T.case(name, fn)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = sandbox
		local ok, message = xpcall(fn, function(err)
			return tostring(err)
		end, folder)
		table.insert(report.cases, name)
		if ok then
			report.passed += 1
		else
			report.failed += 1
			table.insert(report.failures, { case = name, error = message })
		end
		folder:Destroy()
	end

	for _, moduleName in ipairs(CASE_MODULES) do
		local module = script:FindFirstChild(moduleName)
		if module then
			local ok, message = pcall(function()
				require(module)(T)
			end)
			if not ok then
				report.failed += 1
				table.insert(report.failures, { case = moduleName, error = "case module failed to run: " .. tostring(message) })
			end
		else
			report.failed += 1
			table.insert(report.failures, { case = moduleName, error = "case module is missing" })
		end
	end

	BK.yieldBudget = savedBudget
	sandbox:Destroy()
	report.total = report.passed + report.failed
	report.ms = math.floor((os.clock() - startClock) * 1000 + 0.5)
	report.sandboxRemoved = workspace:FindFirstChild(SANDBOX_NAME) == nil
	return report
end

return Check
