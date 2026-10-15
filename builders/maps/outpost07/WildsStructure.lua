--!nonstrict
-- builders/maps/outpost07/WildsStructure.lua  ->  DevTools.Builders.Outpost07.WildsStructure
-- docs/maps/map_03_outpost_07.md §11-12; docs/07_building_with_parts.md §2 (structure pass)
--
-- The STRUCTURE pass of the trail and Kessler Basin, on top of Wilds' blockout (Wilds.Build calls
-- Structure[area](ctx, T) when the pass is "structure" or higher; inject it as opts.Structure):
--   Trail: the broken signpost "KESSLER RESERVOIR — NO ENTRY", the old pipeline 45 west on its supports, rock
--   outcrops along both sides.
--   Basin: the dam's waterline stain, depth markers, railing remnants and control hut; the intake tower's grates,
--   ring walkway, control house and broken bridge stub; the rock formations RF1-RF4 as several rotated blocks
--   inside the blockout's footprints (so the fight routes stay as swept); the boat wreck.
-- Trees, small rock clusters, the fallen pylon, cracks, footprints and mist are the dressed pass.

local Structure = {}

local V = Vector3.new
local FLOOR_Y = -12

function Structure.Trail(ctx, T, Builder)
	local BK, P = ctx.BK, ctx.P
	local rng = Random.new(707)
	-- The signpost at (25, 0, -230), leaning, its sign to the south (the way the Frames come).
	local lean = CFrame.new(T.W(25, 0, -230)) * CFrame.Angles(math.rad(-10), 0, math.rad(6))
	BK.part(ctx.Structure, { Name = "SignPost", Size = V(0.8, 12, 0.8), CFrame = lean * CFrame.new(0, 6, 0), Color = P.WOOD_OLD, Material = "Wood" })
	BK.sign(ctx.Detail, "ReservoirSign", lean * CFrame.new(0, 10, 0.5) * CFrame.Angles(0, math.pi, 0), Vector2.new(14, 2.4), "KESSLER RESERVOIR — NO ENTRY", {
		bgColor = P.RUST, textColor = P.SIGN_WHITE,
	})
	-- The old pipeline: 45 studs west of the centerline, on supports every 24.
	local nodes = Builder.TRAIL
	for index = 1, 4 do
		local a, b = nodes[index], nodes[index + 1]
		local from, to = T.W(a[1] - 45, 4, a[3]), T.W(b[1] - 45, 4, b[3])
		BK.cyl(ctx.Structure, { Name = "Pipeline" .. index, Axis = "Z", Size = V(4, 4, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = P.RUST, Material = "CorrodedMetal" })
		local length = (to - from).Magnitude
		for d = 0, length, 24 do
			local at = from:Lerp(to, d / length)
			BK.part(ctx.Structure, { Name = "PipeSupport", Size = V(5, 2, 1.2), CFrame = CFrame.new(at - V(0, 3, 0)) * CFrame.lookAt(Vector3.zero, (to - from) * V(1, 0, 1)).Rotation, Color = P.STEEL_DARK, Material = "Metal" })
		end
	end
	-- Rock outcrops, 20-40 tall, 40-58 studs either side of the centerline (the barriers stand at 55).
	for index = 1, 4 do
		local a, b = nodes[index], nodes[index + 1]
		local along = V(b[1] - a[1], 0, b[3] - a[3])
		local side = V(-along.Z, 0, along.X).Unit
		for t = 0.2, 0.8, 0.6 do
			for _, s in ipairs({ -1, 1 }) do
				local base = V(a[1], 0, a[3]):Lerp(V(b[1], 0, b[3]), t) + side * s * rng:NextNumber(44, 56)
				local height = rng:NextNumber(20, 40)
				local size = V(rng:NextNumber(10, 18), height, rng:NextNumber(10, 18))
				local cf = CFrame.new(T.W(base.X, height / 2 - 2, base.Z)) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-6, 6)))
				BK.part(ctx.Structure, { Name = "Outcrop", Size = size, CFrame = cf, Color = if rng:NextNumber() < 0.5 then P.ROCK else P.ROCK_DARK, Material = "Rock" })
			end
		end
	end
end

function Structure.Basin(ctx, T, Builder)
	local BK, P = ctx.BK, ctx.P
	local rng = Random.new(1187)
	local paint = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function style(color, material, extra)
		local p = table.clone(extra or {})
		p.Color, p.Material = color, material
		return p
	end
	-- The dam's inner face: the waterline stain (Y -12..0), depth markers, railing remnants on top, the control hut
	-- at (-193, 18, -470).
	local stain = table.clone(paint)
	stain.Color = "#4A4F45"
	T.box(ctx.Detail, "WaterlineStain", -186, FLOOR_Y, -722, -185.9, 0, -426, stain)
	for index, mark in ipairs({ { "5", -6 }, { "10", 2 }, { "15", 10 } }) do
		local cf = BK.lookAlong(T.W(-185.85, mark[2], -500), V(1, 0, 0))
		BK.sign(ctx.Detail, "DepthMark" .. index, cf, Vector2.new(4, 3), mark[1], { bgTransparency = 1, textColor = P.SIGN_WHITE })
		T.box(ctx.Detail, "DepthTick" .. index, -185.95, mark[2] - 0.15, -503, -185.85, mark[2] + 0.15, -497, style(P.SIGN_WHITE, "SmoothPlastic", paint))
	end
	for z = -720, -430, 12 do
		if rng:NextNumber() < 0.7 and (z < -592 or z > -558) then
			T.box(ctx.Detail, "DamRailPost", -188.3, 18, z - 0.25, -187.8, 21.5, z + 0.25, style(P.STEEL_DARK, "Metal"))
			if rng:NextNumber() < 0.6 then
				T.box(ctx.Detail, "DamRail", -188.3, 21, z, -187.8, 21.4, z + 12, style(P.STEEL_DARK, "Metal"))
			end
		end
	end
	T.box(ctx.Structure, "ControlHut", -197, 18, -474, -189, 24, -466, style(P.CONCRETE_LIGHT, "Concrete"))
	T.box(ctx.Detail, "ControlHutDoor", -197.1, 18, -471.5, -196.95, 23, -468.5, style(P.STEEL_MID, "Metal"))
	T.box(ctx.Detail, "ControlHutWindow", -188.95, 20.5, -472, -188.8, 22.5, -468, style("#2A3138", "Glass", { Transparency = 0.25 }))
	-- The intake tower (-95, -12, -600): four dark intake grates at its base, a ring walkway with a railing at the
	-- top (Y 34), a small control house, and the broken access-bridge stub pointing west at Y 30.
	local cx, cz = -95, -600
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local out = V(math.sin(angle), 0, math.cos(angle))
		BK.part(ctx.Detail, {
			Name = "IntakeGrate", Size = V(6, 6, 0.4), CFrame = BK.lookAlong(T.W(cx, FLOOR_Y + 3, cz) + out * 9.05, out),
			Color = "#1B1D20", Material = "DiamondPlate",
		})
	end
	for index = 0, 11 do
		local angle = index * math.pi / 6
		local at = T.W(cx, 34, cz) + V(math.sin(angle), 0, math.cos(angle)) * 10.2
		BK.part(ctx.Structure, { Name = "Walkway", Size = V(5.6, 0.4, 2.6), CFrame = CFrame.lookAt(at, T.W(cx, 34, cz)) * CFrame.new(0, -0.2, 0), Color = P.STEEL_MID, Material = "DiamondPlate" })
		BK.part(ctx.Detail, { Name = "WalkwayRail", Size = V(5.6, 0.3, 0.3), CFrame = CFrame.lookAt(at, T.W(cx, 34, cz)) * CFrame.new(0, 3.2, -1.2), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		BK.part(ctx.Detail, { Name = "WalkwayPost", Size = V(0.3, 3.4, 0.3), CFrame = CFrame.lookAt(at, T.W(cx, 34, cz)) * CFrame.new(2.6, 1.5, -1.2), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	end
	T.box(ctx.Structure, "IntakeControlHouse", cx - 3, 34, cz - 3, cx + 3, 39, cz + 3, style(P.CONCRETE_LIGHT, "Concrete"))
	T.box(ctx.Structure, "BridgeStub", cx - 19, 29.4, cz - 1.5, cx - 9, 30, cz + 1.5, style(P.STEEL_MID, "DiamondPlate"))
	BK.part(ctx.Detail, { Name = "BridgeStubBent", Size = V(3, 0.6, 3), CFrame = CFrame.new(T.W(cx - 20.2, 29.2, cz)) * CFrame.Angles(0, 0, math.rad(25)), Color = P.STEEL_MID, Material = "DiamondPlate" })
	-- The rock formations as several rotated blocks inside the blockout's boxes (map_03 §12: 4-7 pieces each).
	for _, rock in ipairs(Builder.ROCKS) do
		local name, x, z, sx, h, sz = rock[1], rock[2], rock[3], rock[4], rock[5], rock[6]
		local pieces = rng:NextInteger(4, 7)
		for index = 1, pieces do
			local main = index == 1
			local w = if main then sx * 0.78 else sx * rng:NextNumber(0.3, 0.5)
			local d = if main then sz * 0.78 else sz * rng:NextNumber(0.3, 0.5)
			local ph = if main then h else h * rng:NextNumber(0.35, 0.75)
			local ox = if main then 0 else rng:NextNumber(-1, 1) * (sx - w) / 2
			local oz = if main then 0 else rng:NextNumber(-1, 1) * (sz - d) / 2
			local cf = CFrame.new(T.W(x + ox, FLOOR_Y + ph / 2 - 1, z + oz)) * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), math.rad(rng:NextNumber(-12, 12)), math.rad(rng:NextNumber(-5, 5)))
			local part = BK.part(ctx.Structure, { Name = name .. "_" .. index, Size = V(w, ph, d), CFrame = cf, Color = if rng:NextNumber() < 0.6 then P.ROCK else P.ROCK_DARK, Material = "Rock" })
			if not main and rng:NextNumber() < 0.4 then
				part:Destroy()
				BK.wedge(ctx.Structure, { Name = name .. "_" .. index, Size = V(w, ph, d), CFrame = cf * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0), Color = P.ROCK, Material = "Rock" })
			end
		end
	end
	-- The boat wreck at (-130, -12, -650): a small rusted hull on its side.
	local hull = CFrame.new(T.W(-130, FLOOR_Y + 2.5, -650)) * CFrame.Angles(0, math.rad(30), math.rad(70))
	BK.part(ctx.Structure, { Name = "BoatHull", Size = V(6, 3, 14), CFrame = hull, Color = P.RUST, Material = "CorrodedMetal" })
	BK.wedge(ctx.Structure, { Name = "BoatBow", Size = V(6, 3, 5), CFrame = hull * CFrame.new(0, 0, -9.5) * CFrame.Angles(0, math.pi, 0), Color = P.RUST, Material = "CorrodedMetal" })
	BK.part(ctx.Detail, { Name = "BoatCabin", Size = V(3.6, 2.4, 4), CFrame = hull * CFrame.new(0, 2.6, 2), Color = P.RUST_DARK, Material = "CorrodedMetal" })
end

return Structure
