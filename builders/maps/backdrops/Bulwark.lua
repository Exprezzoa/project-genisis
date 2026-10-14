--!nonstrict
-- builders/maps/backdrops/Bulwark.lua  ->  DevTools.Builders.Backdrops.Bulwark
-- docs/maps/map_02_frame_hangar.md §8, map_00 §1 and §3: the Bulwark wall X 420..450, Z -800..800, Y 0..120, with
-- the Frame Gate (DOOR_BULWARK_GATE) at Z -180..-120, Y 0..75: two leaves 30 x 75 x 6 that slide apart along Z into
-- the wall over 6.0 s (S10). Buttresses on the inner face every 80, the painted name, and the road on east.
-- A backdrop (map_00 §3): nothing collides, nothing answers queries, nothing casts a shadow.
-- Blockout plus the buttresses and the name; the walkway, lamps, guns and guard tower are dressed pass.

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
	-- Hazard stripes on the opening's inner edge (the 8-thick border of §8 comes with the dressed pass).
	for _, z in ipairs({ -180, -120 }) do
		BK.box(S, "GateEdge", V(419.8, 0, z - 0.5), V(420, 75, z + 0.5), style(P.HAZARD_YELLOW, "SmoothPlastic"))
	end
	BK.box(S, "GateEdge_Top", V(419.8, 74.5, -180), V(420, 75.5, -120), style(P.HAZARD_YELLOW, "SmoothPlastic"))

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

	return C.finish(ctx)
end

return Builder
