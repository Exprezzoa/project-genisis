--!nonstrict
-- builders/maps/hangar/Lighting.lua  ->  DevTools.Builders.Hangar.Lighting
-- docs/maps/map_02_frame_hangar.md §10 (and §2, §4): the hangar's fixtures, built from the structure pass.
--   * 15 pendant high-bays (rows Z -200, -150, -100 x X -96, -48, 0, 48, 96) on cables to Y 78 (D-044), a cone shade
--     and a Neon disc; SpotLight down 2.5 / 60 / 90; shadows on the middle row only. Under the open-floor rows an
--     invisible throw emitter at Y 52 (1.6 / 60 / 110) carries their light to the floor (D-101)
--   * bay floodlights, 2 per bay on the side catwalks at Y 47, aimed at the Frames' chests (LIGHT_COOL 3 / 50 / 45,
--     shadows); Bay 2's "2 extra floodlights" (§2) on floor stands at its front corners, no shadows
--   * wall washers: SurfaceLights on 8 pilasters (0.6 / 30 / 90); catwalk strips under the decks every 24 (0.8 / 18)
--   * door warning lights: 3 amber boxes over each big door, one PointLight WARNING_ORANGE 1 / 20
--   * beacons: 2 at the east door (Y 72) that spin while the door is open (tag Beacon; AmbientController)
--   * 4 portable light towers on the floor (D-101): the pendants hang at Y 78 to clear the 64-stud Frames, and a
--     light's range is at most 60, so they can't reach the floor; the towers stand clear of the Frame lane, the
--     forklift loop and the walking routes
-- Lights are tagged HubLight (dimmed 30% at NIGHT). opts: Common, BK, Props, pass ("structure" or "dressed").

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Lighting", true)
	local BK, P = ctx.BK, ctx.P
	if ctx.level < 2 then
		return C.finish(ctx) -- the blockout has no fixtures
	end
	local L = ctx.Lighting
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local steel = with({ Color = P.STEEL_DARK, Material = "Metal" })
	local glow = with({ Color = BK.GLOW.amber.Color, Material = "Neon", Transparency = BK.GLOW.amber.Transparency })
	local function emitter(name, cf, size)
		return BK.part(L, with({ Name = name, Size = size or V(0.4, 0.4, 0.4), CFrame = cf, Transparency = 1 }))
	end

	-- Pendant high-bays.
	for row, z in ipairs({ -200, -150, -100 }) do
		for _, x in ipairs({ -96, -48, 0, 48, 96 }) do
			local name = ("HighBay_%d_%d"):format(row, x)
			local roof = 91 + 6 * (1 - math.abs(x) / 121.5) -- the sloped deck's underside (Shell)
			BK.box(L, name .. "_Cable", V(x - 0.08, 80.4, z - 0.08), V(x + 0.08, roof, z + 0.08), with({ Color = P.HAZARD_BLACK }))
			BK.cyl(L, with({ Name = name .. "_Cap", Axis = "Y", Size = V(1.6, 1.2, 1.6), Position = V(x, 80.4, z), Color = P.STEEL_DARK, Material = "Metal" }))
			BK.cyl(L, with({ Name = name .. "_Shade", Axis = "Y", Size = V(4.6, 1.6, 4.6), Position = V(x, 79, z), Color = P.STEEL_MID, Material = "Metal" }))
			BK.cyl(L, with({ Name = name .. "_Disc", Axis = "Y", Size = V(4, 0.1, 4), Position = V(x, 78.15, z), Color = P.LIGHT_NEUTRAL, Material = "Neon" }))
			local e = emitter(name, CFrame.new(x, 77.9, z))
			BK.light(e, "Spot", { Color = P.LIGHT_NEUTRAL, Brightness = 2.5, Range = 60, Angle = 90, Face = Enum.NormalId.Bottom, Shadows = row == 2, Tags = { "HubLight" } })
			-- Over the open floor (rows -150 and -100) the pendant's light can't reach the floor from Y 78 (range 60):
			-- an invisible "throw" emitter on the same axis at Y 52 carries it down (D-101).
			if row > 1 then
				local throw = emitter(name .. "_Throw", CFrame.new(x, 52, z))
				BK.light(throw, "Spot", { Color = P.LIGHT_NEUTRAL, Brightness = 1.6, Range = 60, Angle = 110, Face = Enum.NormalId.Bottom, Tags = { "HubLight" } })
			end
		end
	end

	-- A floodlight head aimed at `target`: a housing, a LIGHT_COOL face, a SpotLight out of its front.
	local function flood(name, pos, target, shadows, brightness)
		local cf = CFrame.lookAt(pos, target)
		BK.part(L, with({ Name = name .. "_Housing", Size = V(2.2, 1.8, 1.6), CFrame = cf * CFrame.new(0, 0, 0.8), Color = P.STEEL_DARK, Material = "Metal" }))
		BK.part(L, with({ Name = name .. "_Face", Size = V(1.9, 1.5, 0.1), CFrame = cf * CFrame.new(0, 0, -0.05), Color = P.LIGHT_COOL, Material = "Neon" }))
		local e = emitter(name, cf * CFrame.new(0, 0, -0.3), V(0.4, 0.4, 0.2))
		BK.light(e, "Spot", { Color = P.LIGHT_COOL, Brightness = brightness or 3, Range = 50, Angle = 45, Face = Enum.NormalId.Front, Shadows = shadows, Tags = { "HubLight" } })
		BK.box(L, name .. "_Yoke", pos + V(-0.15, -2.2, -0.15), pos + V(0.15, -0.5, 0.15), steel)
	end
	-- Two per bay on the side catwalks (deck top 45), aimed at each Frame's chest (Y 50); the gap catwalks carry one
	-- for each neighbouring bay, side by side.
	local bays = { { -70, -114, -37 }, { 0, -33, 33 }, { 70, 37, 114 } }
	for i, b in ipairs(bays) do
		for j, x in ipairs({ b[2], b[3] }) do
			flood(("BayFlood%d_%d"):format(i, j), V(x, 47.2, -188), V(b[1], 50, -205), true)
		end
	end
	-- Bay 2's two extra floods on floor stands outside its front corners (clear of Unit 02's path out), looking up.
	for j, x in ipairs({ -30, 30 }) do
		local base = V(x, 0, -176)
		BK.cyl(L, { Name = "HeroStand_Base" .. j, Axis = "Y", Size = V(2.6, 0.4, 2.6), Position = base + V(0, 0.2, 0), Color = P.HAZARD_YELLOW, Material = "Metal" })
		BK.box(L, "HeroStand_Pole" .. j, base + V(-0.25, 0.4, -0.25), base + V(0.25, 13, 0.25), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		flood("HeroFlood" .. j, base + V(0, 15.2, 0), V(0, 48, -205), false, 2.4)
	end

	-- Wall washers on 8 pilasters (the north ones under the walkway, the south ones by the banners and the corners).
	local washers = {
		{ V(-72, 30, -226.5), V(0, 0, 1) }, { V(-24, 30, -226.5), V(0, 0, 1) }, { V(24, 30, -226.5), V(0, 0, 1) }, { V(72, 30, -226.5), V(0, 0, 1) },
		{ V(-110, 32, -73.5), V(0, 0, -1) }, { V(-50, 32, -73.5), V(0, 0, -1) }, { V(50, 32, -73.5), V(0, 0, -1) }, { V(110, 32, -73.5), V(0, 0, -1) },
	}
	for i, w in ipairs(washers) do
		local cf = BK.lookAlong(w[1] + w[2] * 0.3, w[2])
		BK.part(L, with({ Name = "Washer" .. i .. "_Housing", Size = V(2.6, 1.2, 0.6), CFrame = cf, Color = P.STEEL_DARK, Material = "Metal" }))
		local face = BK.part(L, with({ Name = "Washer" .. i, Size = V(2.2, 0.8, 0.1), CFrame = cf * CFrame.new(0, 0, -0.32), Color = P.LIGHT_NEUTRAL, Material = "Neon" }))
		BK.light(face, "Surface", { Color = P.LIGHT_NEUTRAL, Brightness = 0.6, Range = 30, Angle = 90, Face = Enum.NormalId.Front, Tags = { "HubLight" } })
	end

	-- Catwalk strips under the decks (deck underside Y 44), every 24.
	local strips = {}
	for x = -108, 108, 24 do
		table.insert(strips, { V(x, 43.85, -226), V(6, 0.15, 0.4) })
	end
	for _, x in ipairs({ -114, -35, 35, 114 }) do
		for _, z in ipairs({ -214, -194 }) do
			table.insert(strips, { V(x, 43.85, z), V(0.4, 0.15, 6) })
		end
	end
	for i, s in ipairs(strips) do
		local face = BK.part(L, with({ Name = "CatwalkStrip" .. i, Size = s[2], CFrame = CFrame.new(s[1]), Color = P.LIGHT_NEUTRAL, Material = "Neon" }))
		BK.light(face, "Surface", { Color = P.LIGHT_NEUTRAL, Brightness = 0.8, Range = 18, Face = Enum.NormalId.Bottom, Tags = { "HubLight" } })
	end

	-- Door warning lights: three amber boxes over each big door on the inner face, one light each door.
	for _, d in ipairs({ { 118.3, -150, -1 }, { -118.3, -110, 1 } }) do
		for k = -1, 1 do
			local box = BK.part(L, with({ Name = "DoorWarning", Size = V(0.8, 1.2, 3), CFrame = CFrame.new(d[1] + d[3] * 0.2, 73.2, d[2] + k * 10), Color = glow.Color, Material = "Neon", Transparency = glow.Transparency }))
			if k == 0 then
				BK.light(box, "Point", { Color = P.WARNING_ORANGE, Brightness = 1, Range = 20, Tags = { "HubLight" } })
			end
		end
	end

	-- Beacons at the east door (06 §6): a bracket, a base, an amber dome and a rotor carrying the SpotLight. The rotor
	-- spins 1.2 s per turn and the light is on while DOOR_HANGAR_EAST is open (AmbientController).
	for i, z in ipairs({ -184, -116 }) do
		local pos = V(117.6, 72, z)
		BK.box(L, "Beacon" .. i .. "_Bracket", V(117.5, 71.2, z - 0.3), V(118.5, 71.6, z + 0.3), steel)
		BK.cyl(L, with({ Name = "Beacon" .. i .. "_Base", Axis = "Y", Size = V(1.2, 0.5, 1.2), Position = pos - V(0, 0.15, 0), Color = P.STEEL_DARK, Material = "Metal" }))
		BK.ball(L, with({ Name = "Beacon" .. i .. "_Dome", Size = V(1.1, 1.1, 1.1), Position = pos + V(0, 0.35, 0), Color = P.WARNING_ORANGE, Material = "Glass", Transparency = 0.35 }))
		local rotor = BK.part(L, with({
			Name = "Beacon" .. i, Size = V(0.3, 0.3, 0.6), CFrame = CFrame.new(pos + V(0, 0.35, 0)), Color = P.WARNING_ORANGE, Material = "Neon",
			Tags = { "Beacon" }, Attributes = { DoorId = "DOOR_HANGAR_EAST", Period = 1.2 },
		}))
		BK.light(rotor, "Spot", { Color = P.WARNING_ORANGE, Brightness = 4, Range = 40, Angle = 40, Face = Enum.NormalId.Front, Enabled = false })
	end

	-- Portable light towers on the floor: a wheeled base, a mast to 22, two heads angled down at the floor.
	local towers = { { V(-95, 0, -125), V(-40, 0, -135) }, { V(95, 0, -100), V(40, 0, -125) }, { V(-12, 0, -100), V(-30, 0, -140) }, { V(24, 0, -108), V(30, 0, -150) } }
	for i, t in ipairs(towers) do
		local base, aim = t[1], t[2]
		local name = "LightTower" .. i
		BK.box(L, name .. "_Base", base + V(-2, 0.8, -2.6), base + V(2, 2.6, 2.6), { Color = P.HAZARD_YELLOW, Material = "Metal" })
		for _, w in ipairs({ { -2.1, -1.8 }, { 2.1, -1.8 }, { -2.1, 1.8 }, { 2.1, 1.8 } }) do
			BK.cyl(L, with({ Name = name .. "_Wheel", Axis = "X", Size = V(0.5, 1.6, 1.6), Position = base + V(w[1], 0.8, w[2]), Color = P.HAZARD_BLACK }))
		end
		BK.box(L, name .. "_Mast", base + V(-0.3, 2.6, -0.3), base + V(0.3, 21.4, 0.3), { Color = P.STEEL_MID, Material = "Metal", CanCollide = false })
		BK.box(L, name .. "_Bar", base + V(-2.6, 21.4, -0.2), base + V(2.6, 21.8, 0.2), steel)
		for h, dx in ipairs({ -2, 2 }) do
			local head = base + V(dx, 22.6, 0)
			local cf = CFrame.lookAt(head, aim + V(dx * 6, 0, 0))
			BK.part(L, with({ Name = name .. "_Head" .. h, Size = V(1.8, 1.4, 1.2), CFrame = cf * CFrame.new(0, 0, 0.6), Color = P.STEEL_DARK, Material = "Metal" }))
			BK.part(L, with({ Name = name .. "_Lens" .. h, Size = V(1.5, 1.1, 0.1), CFrame = cf * CFrame.new(0, 0, -0.05), Color = P.LIGHT_NEUTRAL, Material = "Neon" }))
			if h == 1 then
				local e = emitter(name, cf * CFrame.new(2, 0, -0.3), V(0.4, 0.4, 0.2))
				BK.light(e, "Spot", { Color = P.LIGHT_NEUTRAL, Brightness = 3.5, Range = 60, Angle = 80, Face = Enum.NormalId.Front, Tags = { "HubLight" } })
			end
		end
	end

	return C.finish(ctx)
end

return Builder
