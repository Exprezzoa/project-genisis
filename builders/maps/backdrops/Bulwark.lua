--!nonstrict
-- builders/maps/backdrops/Bulwark.lua  ->  DevTools.Builders.Backdrops.Bulwark
-- docs/maps/map_02_frame_hangar.md §8, map_00 §1 and §3: the Bulwark wall X 420..450, Z -800..800, Y 0..120, with
-- the Frame Gate (DOOR_BULWARK_GATE) at Z -180..-120, Y 0..75: two leaves 30 x 75 x 6 that slide apart along Z into
-- the wall over 6.0 s (S10). Buttresses on the inner face every 80, the painted name, and the road on east.
-- A backdrop (map_00 §3): nothing collides, nothing answers queries, nothing casts a shadow.
-- Blockout plus the buttresses and the name; structure: the gate border, its stripes, pour lines; dressed: parapets,
-- lamp posts, gun emplacements and the guard tower. opts: Common, BK, pass.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Backdrops", "Bulwark", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local backdrop = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function style(color, material)
		local props = table.clone(backdrop)
		props.Color, props.Material = color, material
		return props
	end
	local concrete = style(P.CONCRETE_MID, "Concrete")

	-- The wall in three pieces round the gate's opening.
	BK.box(S, "Wall_N", V(420, 0, -800), V(450, 120, -180), concrete)
	BK.box(S, "Wall_S", V(420, 0, -120), V(450, 120, 800), concrete)
	BK.box(S, "Wall_Lintel", V(420, 75, -180), V(450, 120, -120), concrete)
	-- Yellow on the opening's inner edge (from the structure pass the 8-thick border carries proper stripes).
	if ctx.level < 2 then
		for _, z in ipairs({ -180, -120 }) do
			BK.box(S, "GateEdge", V(419.8, 0, z - 0.5), V(420, 75, z + 0.5), style(P.HAZARD_YELLOW, "SmoothPlastic"))
		end
		BK.box(S, "GateEdge_Top", V(419.8, 74.5, -180), V(420, 75.5, -120), style(P.HAZARD_YELLOW, "SmoothPlastic"))
	end

	-- The gate: each leaf carries its closed and open CFrames for the server's door mover (Server/Sequence/Doors).
	local gate = BK.model(S, "DOOR_BULWARK_GATE")
	BK.tag(gate, "Door")
	BK.attr(gate, { DoorId = "DOOR_BULWARK_GATE" })
	for _, leaf in ipairs({ { "Leaf_N", -165, -30 }, { "Leaf_S", -135, 30 } }) do
		local closed = CFrame.new(435, 37.5, leaf[2])
		local open = closed + V(0, 0, leaf[3])
		local part = BK.part(gate, { Name = leaf[1], Size = V(6, 75, 30), CFrame = closed, Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CanQuery = false })
		BK.attr(part, { ClosedCFrame = closed, OpenCFrame = open, Delay = 0, Time = 6.0 })
		for index, offset in ipairs({ -9, 0, 9 }) do
			local ribClosed = closed * CFrame.new(-3.2, 0, offset)
			local rib = BK.part(gate, { Name = leaf[1] .. "_Rib" .. index, Size = V(0.6, 73, 1.2), CFrame = ribClosed, Color = P.STEEL_MID, Material = "Metal", CanCollide = false, CanQuery = false })
			BK.attr(rib, { ClosedCFrame = ribClosed, OpenCFrame = open * CFrame.new(-3.2, 0, offset), Delay = 0, Time = 6.0 })
		end
	end

	-- Buttresses on the inner (west) face every 80 along Z, clear of the gate: 20 deep at the base, 100 tall.
	for z = -760, 760, 80 do
		if math.abs(z + 150) > 60 then
			BK.wedge(S, {
				Name = "Buttress", Size = V(8, 100, 20), CFrame = CFrame.lookAt(V(410, 50, z), V(400, 50, z)),
				Color = P.CONCRETE_DARK, Material = "Concrete", CanCollide = false, CanQuery = false, CastShadow = false,
			})
		end
	end
	BK.sign(S, "BulwarkName", CFrame.lookAt(V(419.8, 96, -300), V(400, 96, -300)), Vector2.new(120, 12), "THIRD FRONTIER — HALDEN BULWARK", {
		bgTransparency = 1, textColor = P.SIGN_WHITE,
	})

	-- The road on into the wilderness, on ground that reaches past it.
	BK.box(S, "Ground_East", V(450, -1, -500), V(900, -0.1, 200), style(P.GROUND, "Ground"))
	BK.box(S, "Road_East", V(450, -0.1, -170), V(700, 0.1, -130), style(P.ASPHALT, "Asphalt"))

	if ctx.level >= 2 then
		Builder.structure(ctx, style, concrete)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, style)
	end
	return C.finish(ctx)
end

-- Structure (map_02 §8): the gate's 8-thick concrete border on the inner face with hazard stripes on its inner
-- edges, and horizontal pour lines every 12 on the inner face.
function Builder.structure(ctx, style, concrete)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local dark = style(P.CONCRETE_DARK, "Concrete")
	BK.box(S, "GateBorder_N", V(416, 0, -188), V(420, 83, -180), dark)
	BK.box(S, "GateBorder_S", V(416, 0, -120), V(420, 83, -112), dark)
	BK.box(S, "GateBorder_Top", V(416, 75, -180), V(420, 83, -120), dark)
	BK.hazardStripe(ctx.Detail, "GateStripe_N", CFrame.fromMatrix(V(418, 37.5, -179.97), Vector3.yAxis, Vector3.zAxis), 75, 4, { angle = 45 })
	BK.hazardStripe(ctx.Detail, "GateStripe_S", CFrame.fromMatrix(V(418, 37.5, -120.03), Vector3.yAxis, -Vector3.zAxis), 75, 4, { angle = 45 })
	BK.hazardStripe(ctx.Detail, "GateStripe_Top", CFrame.fromMatrix(V(418, 74.97, -150), Vector3.zAxis, -Vector3.yAxis), 60, 4, { angle = 45 })
	local line = style(P.CONCRETE_DARK, "Concrete")
	for y = 12, 108, 12 do
		BK.box(ctx.Detail, "PourLine", V(419.85, y - 0.1, -800), V(420, y + 0.1, -188), line)
		BK.box(ctx.Detail, "PourLine", V(419.85, y - 0.1, -112), V(420, y + 0.1, 800), line)
		if y > 83 then
			BK.box(ctx.Detail, "PourLine", V(419.85, y - 0.1, -188), V(420, y + 0.1, -112), line)
		end
	end
end

-- Dressed: the top walkway's parapets (map_02 §8's railings, as low walls: at this distance a railing 1,600 long
-- would be thousands of parts), amber lamp posts every 40 (PointLight AMBER_LAMP, range 30, no shadows), gun
-- emplacements every 160 (clear of the gate), and the guard tower over the gate.
function Builder.dress(ctx, style)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local dark = style(P.CONCRETE_DARK, "Concrete")
	local steel = style(P.STEEL_DARK, "Metal")
	for _, x in ipairs({ { 420, 421 }, { 449, 450 } }) do
		BK.box(F, "Parapet", V(x[1], 120, -800), V(x[2], 123.5, 800), dark)
	end
	for z = -780, 780, 40 do
		BK.box(F, "LampPost", V(422, 120, z - 0.2), V(422.4, 126, z + 0.2), steel)
		local head = BK.box(F, "LampHead", V(421.8, 126, z - 0.5), V(423, 126.8, z + 0.5), style(P.AMBER_LAMP, "Neon"))
		BK.light(head, "Point", { Color = P.AMBER_LAMP, Brightness = 1, Range = 30 })
	end
	for z = -720, 720, 160 do
		if math.abs(z + 150) > 60 then
			BK.box(F, "GunBase", V(431, 120, z - 5), V(439, 121, z + 5), steel)
			BK.box(F, "GunTurret", V(431, 121, z - 4), V(439, 127, z + 4), style(P.STEEL_MID, "Metal"))
			for _, dz in ipairs({ -1.5, 1.5 }) do
				BK.cyl(F, { Name = "GunBarrel", Axis = "X", Size = V(12, 1.5, 1.5), Position = V(445, 124.5, z + dz), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CanQuery = false, CastShadow = false })
			end
		end
	end
	-- The guard tower above the gate: 12 x 14 x 12 with a band of dark windows, a roof cap and an antenna.
	BK.box(F, "GuardTower", V(429, 120, -156), V(441, 134, -144), style(P.CONCRETE_MID, "Concrete"))
	BK.box(F, "GuardTowerWindows", V(428.9, 128, -156.1), V(441.1, 131, -143.9), style("#2A3138", "Glass"))
	BK.box(F, "GuardTowerRoof", V(428.4, 134, -156.6), V(441.6, 135, -143.4), dark)
	BK.box(F, "GuardTowerAntenna", V(434.8, 135, -150.2), V(435.2, 143, -149.8), steel)
	local beacon = BK.box(F, "GuardTowerBeacon", V(434.6, 143, -150.4), V(435.4, 143.8, -149.6), style(P.DANGER_RED, "Neon"))
	BK.tag(beacon, "HoloBlink")
	beacon:SetAttribute("BlinkHz", 0.5)
end

return Builder
