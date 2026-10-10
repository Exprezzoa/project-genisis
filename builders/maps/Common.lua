--!nonstrict
-- builders/maps/Common.lua  ->  ServerStorage.DevTools.Builders.Common
--
-- Shared by every map builder: target folders, pass handling, blockout styles, and the hub's marker and
-- navigation registries (straight from docs/maps/map_00 §5, map_01 §13 and map_02 §11).
--
--   local ctx = Common.begin(opts, "CentralCommand", "OpsHall")   -- clears and recreates the area folder
--   ... build into ctx.Structure / ctx.Gameplay ...
--   return Common.finish(ctx)                                     -- BK.report stats

local Common = {}

Common.EXT = 2 -- exterior wall thickness (map docs give centerlines)
Common.INT = 1 -- interior walls
Common.HANGAR = 3 -- hangar walls
Common.DOOR_H = 8 -- human door 5 x 8
Common.DOUBLE_H = 9 -- double door 8 x 9
Common.GROUND_Y = -0.1 -- exterior ground top; building slabs (top Y 0) sit on it without coplanar faces (D-024)

local PASSES = { blockout = 1, structure = 2, dressed = 3 }
local SUBFOLDERS = { "Structure", "Detail", "Props", "Lighting", "Gameplay" }
local FACING = {
	["-Z"] = Vector3.new(0, 0, -1),
	["+Z"] = Vector3.new(0, 0, 1),
	["+X"] = Vector3.new(1, 0, 0),
	["-X"] = Vector3.new(-1, 0, 0),
}

-- flat = true: the area folder has no Structure/Detail/... subfolders (the Hangar's sections, docs/07 §4).
function Common.begin(opts, zone, area, flat)
	local BK = opts.BK
	local P = BK.Palette
	local pass = opts.pass or "blockout"
	if not PASSES[pass] then
		error("unknown pass " .. tostring(pass), 2)
	end
	local zoneFolder = BK.folder(BK.folder(workspace, "Map"), zone)
	local root = BK.folder(zoneFolder, area, true)
	local ctx = {
		BK = BK,
		P = P,
		pass = pass,
		level = PASSES[pass],
		zone = zone,
		area = area,
		root = root,
		clock = os.clock(),
		-- Flat blockout styles (docs/06 §3-4).
		EXT = { Color = P.CONCRETE_MID, Material = "Concrete" },
		INT = { Color = P.WALL_INTERIOR },
		FLOOR = { Color = P.FLOOR_INTERIOR, Reflectance = 0.03 },
		CEIL = { Color = "#8A9096" },
		ROOF = { Color = P.CONCRETE_DARK, Material = "Concrete" },
		DECK = { Color = P.STEEL_MID, Material = "DiamondPlate" },
		GLASS = { Color = P.GLASS, Material = "Glass", Transparency = 0.55 },
		STANDIN = { Color = P.STEEL_MID },
	}
	for _, name in ipairs(SUBFOLDERS) do
		ctx[name] = if flat then root else BK.folder(root, name)
	end
	root:SetAttribute("Pass", pass)
	return ctx
end

function Common.finish(ctx)
	return ctx.BK.report(ctx.root, ctx.clock)
end

-- A blockout stand-in for a prop that carries a prompt or blocks movement. Later passes replace it.
function Common.standIn(ctx, name, min, max, props)
	local p = if props then table.clone(props) else table.clone(ctx.STANDIN)
	p.Attributes = { StandIn = true }
	return ctx.BK.box(ctx.Gameplay, name, min, max, p)
end

---------------------------------------------------------------------------------------------------
-- Markers: spawns, seats, NPC marks, waypoints, Frame bays. All are SpawnPoint markers (BK.spawnPoint).
-- { id, area, x, y, z, facing }
---------------------------------------------------------------------------------------------------
Common.MARKERS = {
	-- map_00 §5
	{ "SPAWN_Q3_DESK", "Quarters", -118, 0, 5, "-Z" },
	{ "SPAWN_QH", "Quarters", -100, 0, 20, "+X" },
	{ "SPAWN_BRF_DOOR", "Briefing", -84, 0, -20, "+X" },
	{ "SEAT_BRF_ELIAS", "Briefing", -103, 1, -25, "-X" },
	{ "SEAT_BRF_MARA", "Briefing", -103, 1, -27.5, "-X" },
	{ "SPAWN_OPS", "OpsHall", 0, 0, 20, "-Z" },
	{ "SPAWN_HANGAR_FLOOR", "Hangar", 0, 0, -172, "-Z" },
	{ "SPAWN_MED_DOOR", "Medical", 86, 0, 20, "+X" },
	{ "SPAWN_DECK", "ObservationDeck", 105, 20, 0, "+X" },
	{ "FRAME_BAY1", "Hangar", -70, 0, -205, "+Z" },
	{ "FRAME_BAY2", "Hangar", 0, 0, -205, "+Z" },
	{ "FRAME_BAY3", "Hangar", 70, 0, -205, "+Z" },
	-- map_01 §13.3-13.4
	{ "WP_HANGAR_ENTRANCE", "Hangar", 0, 0, -72, "-Z" },
	{ "WP_BRIEFING_DOOR", "Briefing", -80, 0, -20, "-X" },
	{ "WP_MEDICAL_ARCH", "Medical", 115, 0, 20, "+X" },
	{ "WP_QUARTERS", "Quarters", -119.5, 0, 16, "-Z" },
	{ "WP_DECK", "ObservationDeck", 126, 20, -10, "+X" },
	{ "MARK_MARA_DECK", "ObservationDeck", 126, 20, -10, "+X" },
	{ "MARK_VOSS_MED", "Medical", 118, 0, 14, "-Z" },
	{ "MARK_TAMSIN", "Quarters", -104, 0, 23, "-Z" },
	-- map_02 §8, §9, §11
	{ "WP_BAY2_BRIDGE", "Hangar", -4, 28, -198, "+X" },
	{ "WP_DEPLOY_DOOR", "Hangar", 100, 0, -150, "+X" },
	{ "WP_LAUNCH_CENTER", "LaunchPlatform", 160, 0, -150, "+X" },
	{ "MARK_HOLLIS_START", "Hangar", 70, 0, -175, "-Z" },
	{ "MARK_HOLLIS_TALK", "Hangar", 14, 0, -170, "-X" },
	{ "MARK_MARA_VIEW", "Hangar", 6, 0, -168, "-Z" },
	{ "MARK_VALE_RETURN", "Hangar", -3, 0, -160, "-Z" },
	{ "MARK_RHEIN_RETURN", "Hangar", 3, 0, -160, "-Z" },
}

---------------------------------------------------------------------------------------------------
-- Navigation nodes (map_01 §13.2). { id, area, x, y, z, links }
-- Deviations from the doc are marked (D-025, Q-009, Q-010): the doc's straight links crossed the
-- holo-table and the stairwell's railings, and NAV_STAIR_B sat inside the second step.
---------------------------------------------------------------------------------------------------
Common.NAV = {
	{ "NAV_Q3_IN", "Quarters", -120, 0, 8, { "NAV_Q3_DOOR" } },
	{ "NAV_Q3_DOOR", "Quarters", -119.5, 0, 16, { "NAV_Q3_IN", "NAV_QH_W" } },
	{ "NAV_QH_W", "Quarters", -119.5, 0, 20, { "NAV_Q3_DOOR", "NAV_QH_E" } },
	{ "NAV_QH_E", "Quarters", -84, 0, 20, { "NAV_QH_W", "NAV_WC_Q" } },
	{ "NAV_WC_Q", "WestCorridor", -70, 0, 20, { "NAV_QH_E", "NAV_WC_MID" } },
	{ "NAV_WC_MID", "WestCorridor", -70, 0, 0, { "NAV_WC_Q", "NAV_WC_B", "NAV_OPS_W" } },
	{ "NAV_WC_B", "WestCorridor", -70, 0, -20, { "NAV_WC_MID", "NAV_BRF_DOOR" } },
	{ "NAV_BRF_DOOR", "Briefing", -84, 0, -20, { "NAV_WC_B", "NAV_BRF_IN" } },
	{ "NAV_BRF_IN", "Briefing", -90, 0, -20, { "NAV_BRF_DOOR", "NAV_BRF_AISLE" } },
	{ "NAV_BRF_AISLE", "Briefing", -103, 1, -20, { "NAV_BRF_IN" } },
	{ "NAV_OPS_W", "OpsHall", -52, 0, 0, { "NAV_WC_MID", "NAV_OPS_C" } },
	-- doc: NAV_OPS_C links NAV_OPS_E and NAV_OPS_N directly; both lines cross the holo-table (radius 10).
	{ "NAV_OPS_C", "OpsHall", -14, 0, 8, { "NAV_OPS_W", "NAV_OPS_SE", "NAV_OPS_NW", "NAV_OPS_S" } },
	{ "NAV_OPS_NW", "OpsHall", -16, 0, -16, { "NAV_OPS_C", "NAV_OPS_N" } }, -- added
	{ "NAV_OPS_SE", "OpsHall", 0, 0, 16, { "NAV_OPS_C", "NAV_OPS_E" } }, -- added
	{ "NAV_OPS_N", "OpsHall", 0, 0, -32, { "NAV_OPS_NW", "NAV_GATE_S" } },
	{ "NAV_GATE_S", "GateCorridor", 0, 0, -42, { "NAV_OPS_N", "NAV_GATE_N" } },
	{ "NAV_GATE_N", "GateCorridor", 0, 0, -68, { "NAV_GATE_S", "NAV_HG_S" } },
	{ "NAV_HG_S", "Hangar", 0, 0, -80, { "NAV_GATE_N", "NAV_HG_VIEW", "NAV_HG_SW" } },
	{ "NAV_HG_VIEW", "Hangar", 0, 0, -160, { "NAV_HG_S" } },
	{ "NAV_HG_SW", "Hangar", -100, 0, -100, { "NAV_HG_S", "NAV_HG_STAIR_B" } },
	{ "NAV_HG_STAIR_B", "Hangar", -114, 0, -140, { "NAV_HG_SW", "NAV_HG_STAIR_T" } },
	{ "NAV_HG_STAIR_T", "Hangar", -114, 28, -190, { "NAV_HG_STAIR_B", "NAV_CW_W", "NAV_CW_B1S" } },
	{ "NAV_CW_W", "Hangar", -114, 28, -227, { "NAV_HG_STAIR_T", "NAV_CW_B2" } },
	{ "NAV_CW_B1S", "Hangar", -114, 28, -198, { "NAV_HG_STAIR_T", "NAV_BAY1_HATCH" } },
	{ "NAV_BAY1_HATCH", "Hangar", -74, 28, -198, { "NAV_CW_B1S" } },
	{ "NAV_CW_B2", "Hangar", -35, 28, -227, { "NAV_CW_W", "NAV_CW_B2S" } },
	{ "NAV_CW_B2S", "Hangar", -35, 28, -198, { "NAV_CW_B2", "NAV_BAY2_HATCH" } },
	{ "NAV_BAY2_HATCH", "Hangar", -4, 28, -198, { "NAV_CW_B2S" } },
	{ "NAV_OPS_E", "OpsHall", 52, 0, 0, { "NAV_OPS_SE", "NAV_EC_MID" } },
	{ "NAV_EC_MID", "EastCorridor", 70, 0, 0, { "NAV_OPS_E", "NAV_EC_EQ", "NAV_EC_MED", "NAV_EC_N" } },
	{ "NAV_EC_EQ", "EastCorridor", 70, 0, -20, { "NAV_EC_MID", "NAV_EQ_DOOR" } },
	{ "NAV_EQ_DOOR", "Equipment", 84, 0, -20, { "NAV_EC_EQ", "NAV_EQ_IN" } },
	{ "NAV_EQ_IN", "Equipment", 100, 0, -20, { "NAV_EQ_DOOR" } },
	{ "NAV_EC_MED", "EastCorridor", 70, 0, 20, { "NAV_EC_MID", "NAV_MED_DOOR", "NAV_EC_S" } },
	{ "NAV_MED_DOOR", "Medical", 84, 0, 20, { "NAV_EC_MED", "NAV_MED_IN" } },
	{ "NAV_MED_IN", "Medical", 100, 0, 20, { "NAV_MED_DOOR", "NAV_MED_ARCH" } },
	{ "NAV_MED_ARCH", "Medical", 113, 0, 20, { "NAV_MED_IN" } },
	{ "NAV_EC_S", "EastCorridor", 70, 0, 36, { "NAV_EC_MED", "NAV_STAIR_B" } },
	-- Stairwell, provisional layout (Q-009; see EastCorridor.lua).
	-- doc: NAV_STAIR_B (65, 0, 44) - NAV_STAIR_L (70, 10, 58) - NAV_STAIR_T (75, 20, 41) - NAV_DECK_BR.
	{ "NAV_STAIR_B", "EastCorridor", 70, 0, 40, { "NAV_EC_S", "NAV_STAIR_L" } }, -- moved: in the doorway
	{ "NAV_STAIR_L", "EastCorridor", 70, 10, 59.25, { "NAV_STAIR_B", "NAV_STAIR_L2" } }, -- moved 1.25 south
	{ "NAV_STAIR_L2", "EastCorridor", 64, 10, 59.25, { "NAV_STAIR_L", "NAV_STAIR_T" } }, -- added
	{ "NAV_STAIR_T", "EastCorridor", 64, 20, 42, { "NAV_STAIR_L2", "NAV_STAIR_G" } }, -- moved: top landing
	{ "NAV_STAIR_G", "EastCorridor", 76.5, 20, 44, { "NAV_STAIR_T", "NAV_DECK_BR" } }, -- added: gallery
	{ "NAV_DECK_BR", "ObservationDeck", 86, 20, 45, { "NAV_STAIR_G", "NAV_DECK" } },
	{ "NAV_DECK", "ObservationDeck", 105, 20, 0, { "NAV_DECK_BR" } },
	{ "NAV_EC_N", "EastCorridor", 70, 0, -54, { "NAV_EC_MID", "NAV_RC_DOOR" } },
	{ "NAV_RC_DOOR", "Research", 97, 0, -54, { "NAV_EC_N" } },
	{ "NAV_OPS_S", "OpsHall", 0, 0, 36, { "NAV_OPS_C", "NAV_CONC" } },
	-- doc: NAV_CONC links NAV_ARR directly; that line runs through the canopy column at (0, 0, 88).
	{ "NAV_CONC", "Arrival", 0, 0, 60, { "NAV_OPS_S", "NAV_ARR_IN" } },
	{ "NAV_ARR_IN", "Arrival", 6, 0, 84, { "NAV_CONC", "NAV_ARR" } }, -- added
	{ "NAV_ARR", "Arrival", 0, 0, 100, { "NAV_ARR_IN" } },
}

-- Places the markers and nav nodes that belong to this area (or to the listed areas) into ctx.Gameplay.
function Common.placeRegistry(ctx, areas)
	local BK = ctx.BK
	local wanted = {}
	for _, area in ipairs(areas or { ctx.area }) do
		wanted[area] = true
	end
	for _, m in ipairs(Common.MARKERS) do
		if wanted[m[2]] then
			BK.spawnPoint(ctx.Gameplay, m[1], BK.lookAlong(Vector3.new(m[3], m[4], m[5]), FACING[m[6]]))
		end
	end
	for _, n in ipairs(Common.NAV) do
		if wanted[n[2]] then
			BK.navNode(ctx.Gameplay, n[1], Vector3.new(n[3], n[4], n[5]), n[6])
		end
	end
end

return Common
