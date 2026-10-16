--!nonstrict
-- builders/checks/HubCheck.lua  ->  ServerStorage.DevTools.Checks.HubCheck   (docs/19 §3 MapCheck, docs/07 §8)
--
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.HubCheck:Clone()).Run())
--
-- Spec check for the hub and the hangar (map_00 §5, map_01, map_02):
--   * every gameplay id of the registries exists exactly once under Workspace.Map, with the right tag;
--   * every door opening (an opening at least 6 tall in a BK.wallWithOpenings wall) is >= 5 wide and >= 8 tall;
--   * each area's bounding box equals the spec footprint within 1 stud (footprints are wall centerlines, so
--     the expected boxes below include half the wall thickness);
--   * part and light counts are within the budgets of docs/07 §5.
-- Ids that later phases add are listed in DEFERRED and must NOT exist yet.

local CollectionService = game:GetService("CollectionService")

local Check = {}

local IDS = {
	SpawnPoint = {
		attribute = "SpawnId",
		ids = {
			"SPAWN_Q3_DESK", "SPAWN_QH", "SPAWN_BRF_DOOR", "SEAT_BRF_ELIAS", "SEAT_BRF_MARA", "SPAWN_OPS",
			"SPAWN_HANGAR_FLOOR", "SPAWN_MED_DOOR", "SPAWN_DECK", "FRAME_BAY1", "FRAME_BAY2", "FRAME_BAY3",
			"WP_HANGAR_ENTRANCE", "WP_BRIEFING_DOOR", "WP_MEDICAL_ARCH", "WP_QUARTERS", "WP_DECK",
			"MARK_MARA_DECK", "MARK_VOSS_MED", "MARK_TAMSIN", "WP_BAY2_BRIDGE", "WP_DEPLOY_DOOR",
			"WP_LAUNCH_CENTER", "MARK_HOLLIS_START", "MARK_HOLLIS_TALK", "MARK_MARA_VIEW", "MARK_VALE_RETURN",
			"MARK_RHEIN_RETURN", "SPAWN_TRAINING", "AUTO_CAUSEWAY_END",
		},
	},
	Interactable = {
		attribute = "InteractId",
		ids = {
			"INT_Q3_PHOTO", "INT_Q3_LOCKER", "INT_Q3_WINDOW", "INT_Q3_TERMINAL", "INT_STATUS_WALL", "INT_HOLO",
			"INT_POSTER", "INT_RESEARCH_DOOR", "INT_EQUIP_TERMINAL",
		},
	},
	Trigger = {
		attribute = "TriggerId",
		ids = { "TRG_BRIEFING_ENTER", "TRG_MED_ARCH", "TRG_HANGAR_REVEAL", "TRG_DEPLOY_DOOR" },
	},
	CinematicCam = {
		attribute = "CamId",
		ids = {
			"CAM_BRF_WIDE", "CAM_BRF_VALE", "CAM_BRF_PILOTS", "CAM_HANGAR_REVEAL_1", "CAM_HANGAR_REVEAL_2",
			"CAM_DOOR_EXT", "CAM_DOOR_REVEAL", "CAM_LAUNCH_A", "CAM_LAUNCH_B",
		},
	},
	Door = {
		attribute = "DoorId",
		ids = { "DOOR_RESEARCH", "DOOR_HANGAR_EAST", "DOOR_HANGAR_WEST", "DOOR_BULWARK_GATE" },
	},
}

-- Phase 2: the boarding prompts (with FrameService). Phase 5: NPCs.
local HUB_ZONES = { "CentralCommand", "Hangar", "Backdrops" }

-- TALK_TAMSIN and TALK_OKAFOR aren't map parts: NPCService puts them on the NPCs at runtime (D-081).
local DEFERRED = {
	InteractId = { "INT_BOARD_BAY1", "INT_BOARD_BAY2" },
}

-- { zone, area, min, max } with half the wall thickness included. Y: slab bottom to roof or parapet top.
local V = Vector3.new
local BOUNDS = {
	{ "CentralCommand", "OpsHall", V(-61, -1, -42), V(61, 38, 42) }, -- exterior pilasters stand 1 proud (structure pass)
	{ "CentralCommand", "WestCorridor", V(-80.5, -1, -41), V(-60, 17, 41) },
	{ "CentralCommand", "Quarters", V(-132, -1, 0), V(-80, 13, 42) }, -- exterior pilasters stand 1 proud (structure pass)
	{ "CentralCommand", "Briefing", V(-131, -1, -41), V(-80, 17, 0.5) },
	{ "CentralCommand", "EastCorridor", V(59, -1, -61), V(81, 31, 63) }, -- stairwell 2 deeper than the doc (Q-009)
	{ "CentralCommand", "Equipment", V(80, -1, -41), V(131, 22, 0.5) },
	{ "CentralCommand", "Medical", V(80, -1, 0), V(131, 22, 41) },
	{ "CentralCommand", "Research", V(80, -1, -81), V(251, 17, -19) },
	{ "CentralCommand", "Arrival", V(-80, -1, 40), V(80, 19, 130) },
	{ "CentralCommand", "Exterior", V(-421, -4.1, -321), V(421, 60, 421) },
	{ "CentralCommand", "TrainingYard", V(-421, -1, -301), V(-122, 56, -39) }, -- the simulacrum is 56 tall
	{ "Hangar", "Shell", V(-121.5, -1, -231.5), V(134.5, 92, -68.5) }, -- the east door's housing reaches X 134.5 (map_02 §4)
	{ "Hangar", "GateCorridor", V(-16, -1, -70), V(16, 17, -40) },
	{ "Hangar", "LaunchPlatform", V(123, -0.1, -190), V(200, 0.5, -110) },
	{ "Hangar", "Causeway", V(200, -1.1, -177), V(420, 60, -123) }, -- deck and its FrameBarriers (map_02 §8)
}

local BUDGETS = { CentralCommand = { parts = 9000, lights = 220 }, Hangar = { parts = 6000, lights = 90 } }

local function boundsOf(root)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") and not part:HasTag("NavNode") and not part:HasTag("CinematicCam") and not part:HasTag("SpawnPoint") then
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
	end
	return min, max
end

function Check.Run()
	local map = workspace:FindFirstChild("Map")
	-- The hub's zones only: Outpost 07 has its own registry (map_03 §16).
	local function inHub(instance)
		for _, zone in ipairs(HUB_ZONES) do
			local folder = map:FindFirstChild(zone)
			if folder and instance:IsDescendantOf(folder) then
				return true
			end
		end
		return false
	end
	local errors = {}
	local function fail(message)
		table.insert(errors, message)
	end

	-- 1. Registries.
	local found = {}
	for tag, spec in pairs(IDS) do
		local seen = {}
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if inHub(instance) then
				local id = instance:GetAttribute(spec.attribute)
				if id ~= nil then
					seen[id] = (seen[id] or 0) + 1
				end
			end
		end
		local expected = {}
		for _, id in ipairs(spec.ids) do
			expected[id] = true
			if seen[id] ~= 1 then
				fail(("%s %s exists %d times (expected 1)"):format(tag, id, seen[id] or 0))
			end
		end
		for id in pairs(seen) do
			if not expected[id] then
				fail(("%s %s isn't in the registry"):format(tag, tostring(id)))
			end
		end
		for _, id in ipairs(DEFERRED[spec.attribute] or {}) do
			if seen[id] then
				fail(("%s %s is deferred to a later phase but exists"):format(tag, id))
			end
		end
		found[tag] = #spec.ids
	end

	-- 2. Door openings.
	local doors, smallest = 0, nil
	for _, model in ipairs(map:GetDescendants()) do
		local openings = model:IsA("Model") and model:GetAttribute("Openings")
		for i = 1, openings or 0 do
			local span = model:GetAttribute(("Opening%d_Span"):format(i))
			local y = model:GetAttribute(("Opening%d_Y"):format(i))
			local width, height = span.Y - span.X, y.Y - y.X
			if height >= 6 then
				doors += 1
				if width < 5 - 1e-3 or height < 8 - 1e-3 then
					fail(("door %s #%d is %.2f x %.2f (minimum 5 x 8)"):format(model:GetFullName(), i, width, height))
				end
				if not smallest or width * height < smallest.width * smallest.height then
					smallest = { name = model.Name, width = width, height = height }
				end
			end
		end
	end

	-- 3. Bounds.
	for _, b in ipairs(BOUNDS) do
		local zone = map:FindFirstChild(b[1])
		local area = zone and zone:FindFirstChild(b[2])
		if not area then
			fail(("%s.%s is missing"):format(b[1], b[2]))
		else
			local min, max = boundsOf(area)
			local dMin, dMax = min - b[3], max - b[4]
			local worst = math.max(math.abs(dMin.X), math.abs(dMin.Y), math.abs(dMin.Z), math.abs(dMax.X), math.abs(dMax.Y), math.abs(dMax.Z))
			if worst > 1 then
				fail(("%s.%s bounds (%s) .. (%s) differ from the spec (%s) .. (%s) by %.2f"):format(b[1], b[2], tostring(min), tostring(max), tostring(b[3]), tostring(b[4]), worst))
			end
		end
	end

	-- 4. Budgets.
	local counts = {}
	for zoneName, budget in pairs(BUDGETS) do
		local zone = map:FindFirstChild(zoneName)
		local parts, lights = 0, 0
		for _, descendant in ipairs(if zone then zone:GetDescendants() else {}) do
			if descendant:IsA("BasePart") then
				parts += 1
			elseif descendant:IsA("Light") then
				lights += 1
			end
		end
		counts[zoneName] = { parts = parts, lights = lights }
		if parts > budget.parts or lights > budget.lights then
			fail(("%s is over budget: %d parts, %d lights"):format(zoneName, parts, lights))
		end
	end

	table.sort(errors)
	return { passed = #errors == 0, errors = errors, ids = found, doors = doors, smallestDoor = smallest, counts = counts }
end

return Check
