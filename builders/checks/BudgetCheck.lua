--!nonstrict
-- builders/checks/BudgetCheck.lua  ->  ServerStorage.DevTools.Checks.BudgetCheck   (docs/07 §5, docs/16 §11, map_00 §3)
--
--   local DT = game:GetService("ServerStorage").DevTools
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.BudgetCheck:Clone()).Run())
--
-- The static half of Phase 7's performance test (roadmap Phase 7 test 4): every row of docs/07 §5's budget table,
-- counted in the place as it stands. Runs in edit mode and creates nothing.
--   * zones under Workspace.Map: parts, lights (any), shadowed lights; for "per 150-stud radius" rows, the most
--     shadowed lights found within 150 studs of any one shadowed light;
--   * backdrops: no part collides, answers queries or casts a shadow (map_00 §3);
--   * rig templates (ServerStorage.Templates): Vanguard, Strider, Watcher parts and lights; NPC gear;
--   * all of Workspace: parts (<= 40,000, target 30,000);
--   * any part longer than 2048 studs on a side (the engine's cap).
-- FPS, heartbeat, memory, network and script activity need play mode and the user (docs/19 §6).

local Check = {}

local ZONES = {
	{ zone = "CentralCommand", parts = 9000, lights = 220, shadowRadius = 150, shadowMax = 24 },
	{ zone = "Hangar", parts = 6000, lights = 90, shadowTotal = 20 },
	{ zone = "Backdrops", parts = 2500, lights = 60, shadowTotal = 0, backdrop = true },
	{ zone = "Outpost07", parts = 12000, lights = 160, shadowRadius = 150, shadowMax = 24 },
}

local RIGS = {
	{ folder = "Frames", prefix = "Vanguard", parts = 450, lights = 6, shadows = 0 },
	{ folder = "Titans", prefix = "Strider", parts = 350, lights = 4, shadows = 0 },
	{ folder = "Titans", prefix = "Watcher", parts = 380, lights = 6, shadows = 0 },
}
local NPC_GEAR_PARTS = 40

local WORKSPACE_MAX, WORKSPACE_TARGET = 40000, 30000
local ENGINE_SIDE_CAP = 2048

local function lightPosition(light)
	local p = light.Parent
	if p and p:IsA("BasePart") then
		return p.Position
	elseif p and p:IsA("Attachment") then
		return p.WorldPosition
	end
	return nil
end

local function count(root)
	local out = { parts = 0, lights = 0, shadowLights = 0, shadowed = {}, oversize = {}, backdropViolations = 0, sampleViolations = {} }
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			out.parts += 1
			local s = d.Size
			if math.max(s.X, s.Y, s.Z) > ENGINE_SIDE_CAP then
				table.insert(out.oversize, d:GetFullName())
			end
		elseif d:IsA("Light") then
			out.lights += 1
			if d.Shadows then
				out.shadowLights += 1
				local p = lightPosition(d)
				if p then
					table.insert(out.shadowed, p)
				end
			end
		end
	end
	return out
end

-- The most shadowed lights within `radius` of one shadowed light (itself included).
local function densestCluster(points, radius)
	local best = 0
	for i = 1, #points do
		local n = 0
		for j = 1, #points do
			if (points[i] - points[j]).Magnitude <= radius then
				n += 1
			end
		end
		best = math.max(best, n)
	end
	return best
end

local function backdropRule(root, out)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CastShadow) then
			out.backdropViolations += 1
			if #out.sampleViolations < 10 then
				table.insert(out.sampleViolations, d:GetFullName())
			end
		end
	end
end

function Check.Run()
	local report = { zones = {}, rigs = {}, errors = {}, warnings = {} }
	local function fail(msg)
		table.insert(report.errors, msg)
	end

	local map = workspace:FindFirstChild("Map")
	for _, z in ipairs(ZONES) do
		local root = map and map:FindFirstChild(z.zone)
		if not root then
			table.insert(report.warnings, z.zone .. ": not built")
			continue
		end
		local c = count(root)
		local row = { parts = c.parts, lights = c.lights, shadowLights = c.shadowLights, budget = { parts = z.parts, lights = z.lights } }
		if c.parts > z.parts then
			fail(("%s: %d parts > %d"):format(z.zone, c.parts, z.parts))
		end
		if c.lights > z.lights then
			fail(("%s: %d lights > %d"):format(z.zone, c.lights, z.lights))
		end
		if z.shadowTotal and c.shadowLights > z.shadowTotal then
			fail(("%s: %d shadowed lights > %d"):format(z.zone, c.shadowLights, z.shadowTotal))
		end
		if z.shadowRadius then
			row.densestShadowCluster = densestCluster(c.shadowed, z.shadowRadius)
			if row.densestShadowCluster > z.shadowMax then
				fail(("%s: %d shadowed lights within %d studs > %d"):format(z.zone, row.densestShadowCluster, z.shadowRadius, z.shadowMax))
			end
		end
		if #c.oversize > 0 then
			fail(z.zone .. ": parts longer than 2048: " .. table.concat(c.oversize, ", "))
		end
		if z.backdrop then
			backdropRule(root, c)
			row.backdropViolations = c.backdropViolations
			if c.backdropViolations > 0 then
				fail(("%s: %d parts collide, answer queries or cast shadows (e.g. %s)"):format(z.zone, c.backdropViolations, table.concat(c.sampleViolations, ", ")))
			end
		end
		report.zones[z.zone] = row
	end

	local templates = game:GetService("ServerStorage"):FindFirstChild("Templates")
	for _, rig in ipairs(RIGS) do
		local folder = templates and templates:FindFirstChild(rig.folder)
		local found = 0
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			if model:IsA("Model") and string.sub(model.Name, 1, #rig.prefix) == rig.prefix then
				found += 1
				local c = count(model)
				report.rigs[model.Name] = { parts = c.parts, lights = c.lights, shadowLights = c.shadowLights, budget = { parts = rig.parts, lights = rig.lights } }
				if c.parts > rig.parts then
					fail(("%s: %d parts > %d"):format(model.Name, c.parts, rig.parts))
				end
				if c.lights > rig.lights then
					fail(("%s: %d lights > %d"):format(model.Name, c.lights, rig.lights))
				end
				if c.shadowLights > rig.shadows then
					fail(("%s: %d shadowed lights > %d"):format(model.Name, c.shadowLights, rig.shadows))
				end
			end
		end
		if found == 0 then
			table.insert(report.warnings, rig.prefix .. ": no template found in Templates." .. rig.folder)
		end
	end

	-- NPC gear: parts other than the R15 body's 15 (and an HRP) per NPC template.
	local npcs = templates and templates:FindFirstChild("NPCs")
	local heaviest, heaviestName = 0, nil
	for _, model in ipairs(npcs and npcs:GetChildren() or {}) do
		if model:IsA("Model") then
			local gear = 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and not (d.Parent == model and model:FindFirstChildOfClass("Humanoid")) then
					gear += 1
				end
			end
			if gear > heaviest then
				heaviest, heaviestName = gear, model.Name
			end
			if gear > NPC_GEAR_PARTS then
				fail(("%s: %d gear parts > %d"):format(model.Name, gear, NPC_GEAR_PARTS))
			end
		end
	end
	report.npcGear = { heaviest = heaviest, name = heaviestName, budget = NPC_GEAR_PARTS }

	local all = count(workspace)
	report.workspace = { parts = all.parts, lights = all.lights, shadowLights = all.shadowLights, max = WORKSPACE_MAX, target = WORKSPACE_TARGET }
	if all.parts > WORKSPACE_MAX then
		fail(("Workspace: %d parts > %d"):format(all.parts, WORKSPACE_MAX))
	elseif all.parts > WORKSPACE_TARGET then
		table.insert(report.warnings, ("Workspace: %d parts > the %d target"):format(all.parts, WORKSPACE_TARGET))
	end

	report.passed = #report.errors == 0
	return report
end

return Check
