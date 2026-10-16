--!nonstrict
-- builders/maps/hangar/Crane.lua  ->  DevTools.Builders.Hangar.Crane
-- docs/maps/map_02_frame_hangar.md §5 (with D-044's heights): the overhead gantry crane, an ambient decor piece.
--   * runway rails (box beams 2 x 3 along X) with their tops at Y 80, on wall brackets every 24, at Z -225 and -80
--   * the bridge girder: a box girder 145 long (Z -225..-80) x 3 wide x 4 tall, HAZARD_YELLOW with black end stripes,
--     on four end trucks with wheels
--   * the trolley (8 x 3.6 x 6) on the girder at Z -160 (between the pendant rows, D-101), two hoist cables to a hook
--     block at Y 76, and a pauldron plate (7.5 x 4.5 x 9, VG_PRIMER) hanging at Y 70..74 on two chains
-- Motion (clients, AmbientController): the crane model (tag Shuttle) travels X -100 <-> 100 over 60 s each way
-- (SineInOut); the load (tag Sway) swings +-2°. Built from the structure pass. opts: Common, BK, pass.

local Builder = {}

local V = Vector3.new

local Z1, Z2 = -225, -80
local TROLLEY_Z = -160

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Crane", true)
	local BK, P = ctx.BK, ctx.P
	if ctx.level < 2 then
		return C.finish(ctx)
	end
	local S = ctx.Structure
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local steel = with({ Color = P.STEEL_DARK, Material = "Metal" })
	local yellow = { Color = P.HAZARD_YELLOW, Material = "Metal", CanCollide = false }

	-- Runway rails and their wall brackets (north wall face Z -228.5, south wall face Z -71.5).
	for _, r in ipairs({ { Z1, -228.5 }, { Z2, -71.5 } }) do
		local z, wall = r[1], r[2]
		BK.box(S, "RunwayRail", V(-118.5, 77, z - 1), V(118.5, 80, z + 1), with({ Color = P.STEEL_DARK, Material = "Metal", CastShadow = true }))
		for x = -108, 108, 24 do
			local a, b = math.min(wall, z), math.max(wall, z)
			BK.box(S, "RailBracket", V(x - 0.4, 76, a), V(x + 0.4, 77, b), steel)
			BK.beam(S, "RailBrace", V(x, 72, wall + (if wall < z then 0.3 else -0.3)), V(x, 76.5, z), 0.4, 0.4, steel)
		end
	end

	-- The crane itself, built at X 0; the client shuttles the whole model along X.
	local crane = BK.model(S, "GantryCrane")
	BK.tag(crane, "Shuttle")
	BK.attr(crane, { Axis = Vector3.xAxis, From = -100, To = 100, Time = 60 })
	local girder = BK.part(crane, with({ Name = "Girder", Size = V(3, 4, math.abs(Z2 - Z1)), CFrame = CFrame.new(0, 82, (Z1 + Z2) / 2), Color = P.HAZARD_YELLOW, Material = "Metal", CastShadow = true }))
	for _, z in ipairs({ Z1 + 3, Z2 - 3 }) do
		for k = -1, 1 do
			BK.part(crane, with({ Name = "EndStripe", Size = V(3.06, 0.6, 0.8), CFrame = CFrame.new(0, 82 + k * 1.2, z) * CFrame.Angles(math.rad(45), 0, 0), Color = P.HAZARD_BLACK }))
		end
	end
	for _, z in ipairs({ Z1, Z2 }) do
		BK.part(crane, with({ Name = "EndTruck", Size = V(9, 2, 3), CFrame = CFrame.new(0, 81, z), Color = P.STEEL_DARK, Material = "Metal" }))
		for _, x in ipairs({ -3.2, 3.2 }) do
			BK.cyl(crane, with({ Name = "TruckWheel", Axis = "Z", Size = V(1.6, 1.6, 2.4), Position = V(x, 80.6, z), Color = P.HAZARD_BLACK }))
		end
	end
	-- The trolley on top of the girder, its drum, and the hoist.
	BK.part(crane, with({ Name = "Trolley", Size = V(8, 3.2, 6), CFrame = CFrame.new(0, 85.6, TROLLEY_Z), Color = P.HAZARD_YELLOW, Material = "Metal", CastShadow = true }))
	BK.cyl(crane, with({ Name = "Drum", Axis = "X", Size = V(6, 1.8, 1.8), Position = V(0, 86.2, TROLLEY_Z - 3.6), Color = P.STEEL_MID, Material = "Metal" }))
	for _, x in ipairs({ -3, 3 }) do
		BK.box(crane, "HoistCable", V(x - 0.15, 77, TROLLEY_Z - 0.15), V(x + 0.15, 84, TROLLEY_Z + 0.15), with({ Color = P.HAZARD_BLACK }))
	end
	BK.box(crane, "HookBlock", V(-3.4, 75.2, TROLLEY_Z - 1), V(3.4, 77, TROLLEY_Z + 1), with({ Color = P.HAZARD_YELLOW, Material = "Metal" }))
	BK.ball(crane, with({ Name = "Hook", Size = V(1.2, 1.2, 1.2), Position = V(0, 74.8, TROLLEY_Z), Color = P.STEEL_DARK, Material = "Metal" }))
	-- The load: a pauldron plate on two chains (it sways about the hook).
	local load = BK.model(crane, "Load")
	BK.tag(load, "Sway")
	BK.attr(load, { Pivot = V(0, 74.8, TROLLEY_Z), Amplitude = 2, Period = 5.5 })
	for _, x in ipairs({ -2.6, 2.6 }) do
		BK.beam(load, "Chain", V(0, 74.6, TROLLEY_Z), V(x, 74, TROLLEY_Z), 0.18, 0.18, with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	BK.part(load, with({ Name = "Pauldron", Size = V(7.5, 4.5, 9), CFrame = CFrame.new(0, 71.75, TROLLEY_Z), Color = P.VG_PRIMER, Material = "Metal", CastShadow = true }))
	BK.part(load, with({ Name = "PauldronRim", Size = V(7.7, 0.5, 9.2), CFrame = CFrame.new(0, 70.2, TROLLEY_Z), Color = P.VG_FRAME, Material = "Metal" }))
	load.PrimaryPart = load:FindFirstChild("Pauldron")
	crane.PrimaryPart = girder
	BK.sign(crane, "CraneSign", BK.lookAlong(V(0, 82, Z2 - 0.5), V(0, 0, 1)), Vector2.new(2.8, 1.2), "40 T", { textColor = P.HAZARD_BLACK, bgColor = P.HAZARD_YELLOW })

	return C.finish(ctx)
end

return Builder
