--!nonstrict
-- builders/maps/hangar/GateCorridor.lua  ->  DevTools.Builders.Hangar.GateCorridor
-- docs/maps/map_02_frame_hangar.md §12: Hangar Gate Corridor X -15..15, Z -70..-40, ceiling 16.
-- Its ends are the openings in the Ops Hall's north wall and the hangar's south wall.
--
-- Passes: blockout = floor, ceiling, walls; structure = hazard stripes across both thresholds, a kickplate, ceiling
-- panels, the decontamination arch (two pillars and a beam with LIGHT_COOL strips) at Z -55, the sign at the south end;
-- dressed = the pilot gear lockers (8 per side, around the arch), the notice board (map_02 §12's two notices), a pipe
-- run under the ceiling, small decon screens on the arch. opts: Common, BK, Props (structure and up), pass.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "GateCorridor", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local walls = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }

	BK.floor(S, "Floor", -15, 15, -70, -40, 0, 1, { Color = P.FLOOR_HANGAR, Material = "Concrete" })
	BK.ceiling(S, "Ceiling", -16, 16, -68.5, -41, 16, 1, ctx.CEIL)
	BK.wallZ(S, "Wall_W", -68.5, -41, -15, 0, 16, C.EXT, walls)
	BK.wallZ(S, "Wall_E", -68.5, -41, 15, 0, 16, C.EXT, walls)

	local Lib = opts.Props
	if ctx.level >= 2 then
		Builder.structure(ctx, C, Lib)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, C, Lib)
	end
	return C.finish(ctx)
end

function Builder.structure(ctx, C, Lib)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	-- Hazard stripes across both thresholds, and a kickplate along both walls.
	for _, z in ipairs({ -69, -41.75 }) do
		BK.hazardStripe(ctx.Detail, "Threshold", CFrame.fromMatrix(V(0, 0.03, z), Vector3.xAxis, Vector3.yAxis), 28, 1.5, { angle = 45 })
	end
	for _, x in ipairs({ -14, 14 }) do
		BK.box(ctx.Detail, "Kick", V(x - (if x < 0 then 0 else 0.1), 0, -68.5), V(x + (if x < 0 then 0.1 else 0), 1, -41), with({ Color = P.CONCRETE_DARK, Material = "Concrete" }))
	end
	-- Ceiling panels (LIGHT_NEUTRAL), two pairs.
	for i, p in ipairs({ { -7, -63 }, { 7, -63 }, { -7, -47 }, { 7, -47 } }) do
		C.fixture(ctx, "CeilingPanel" .. i, V(p[1], 15.9, p[2]), V(4, 0.15, 2), { Brightness = 0.9, Range = 18 })
	end
	-- The decontamination arch at Z -55: two pillars, a beam, LIGHT_COOL strips on their inner faces and a soft light.
	local arch = { Color = P.STEEL_MID, Material = "Metal" }
	for _, sx in ipairs({ -1, 1 }) do
		BK.box(S, "DeconPillar", V(sx * 13.9 - 1, 0, -56), V(sx * 13.9 + 1, 15, -54), arch)
		local strip = BK.box(ctx.Detail, "DeconStrip", V(sx * 12.85 - 0.1, 1, -55.4), V(sx * 12.85 + 0.1, 13.4, -54.6), with({ Color = P.LIGHT_COOL, Material = "Neon" }))
		if sx < 0 then
			BK.light(strip, "Surface", { Color = P.LIGHT_COOL, Brightness = 0.8, Range = 14, Face = Enum.NormalId.Right, Tags = { "HubLight" } })
		end
	end
	BK.box(S, "DeconBeam", V(-14.9, 13.6, -56), V(14.9, 15, -54), arch)
	BK.box(ctx.Detail, "DeconBeamStrip", V(-12.8, 13.45, -55.4), V(12.8, 13.6, -54.6), with({ Color = P.LIGHT_COOL, Material = "Neon" }))
	BK.hazardStripe(ctx.Detail, "DeconBeamStripe", CFrame.fromMatrix(V(0, 14.3, -56.03), Vector3.xAxis, V(0, 0, -1)), 25, 1.2, { angle = 45 })
	-- The sign at the south end, hung from the ceiling, readable as one comes in from the Ops Hall.
	for _, x in ipairs({ -8, 8 }) do
		BK.box(ctx.Detail, "SignRod", V(x - 0.08, 14.1, -43.1), V(x + 0.08, 16, -42.9), with({ Color = P.STEEL_DARK }))
	end
	BK.sign(ctx.Detail, "Sign_Hangar", BK.lookAlong(V(0, 13.3, -43), V(0, 0, 1)), Vector2.new(20, 1.6), "FRAME HANGAR — AUTHORIZED PERSONNEL", { light = true })
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	-- Pilot gear lockers: 8 per side, in two rows of 4 either side of the arch.
	for _, side in ipairs({ { -13, "+X" }, { 13, "-X" } }) do
		for i, z in ipairs({ -63, -47 }) do
			Lib.Locker(F, CFrame.new(side[1], 0, z) * Lib.FACE[side[2]], { name = ("GearLockers_%s%d"):format(side[2] == "+X" and "W" or "E", i), count = 4 })
		end
	end
	-- The notice board above the east lockers (map_02 §12's two notices).
	BK.box(F, "NoticeBoard", V(13.88, 8.6, -51.5), V(14, 12.4, -42.5), { Color = P.SLATE_DEEP, CanCollide = false })
	local function notice(name, z, text, color)
		local part = BK.part(F, { Name = name, Size = V(3.6, 2.8, 0.04), CFrame = BK.lookAlong(V(13.84, 10.4, z), V(-1, 0, 0)), Color = color, CanCollide = false, CastShadow = false })
		local g = Lib.gui(part, Enum.NormalId.Front, 0.6, 80)
		Lib.rect(g, 0, 0, 1, 1, color, 0, "Paper")
		Lib.label(g, text, 0.08, 0.1, 0.84, 0.8, { font = Lib.FONT.body, color = P.KICKPLATE, xAlign = "Center", wrap = true })
	end
	notice("Notice_Deployment", -49.2, "EMBER SQUAD — DEPLOYMENT 06:30", P.MEDICAL_WHITE)
	notice("Notice_Hollis", -44.8, "REMINDER: TAP-TESTING HATCHES IS NOT A SAFETY PROCEDURE. — H.B.", P.AMBER_LAMP)
	-- A pipe run under the ceiling, and two small screens on the arch's pillars.
	BK.pipeRun(ctx.Detail, "CeilingPipe", { V(11.5, 15.1, -42), V(11.5, 15.1, -68) }, 0.35, { color = P.STEEL_MID })
	for _, sx in ipairs({ -1, 1 }) do
		BK.screen(ctx.Detail, "DeconScreen", BK.lookAlong(V(sx * 13.9, 6, -56.06), V(0, 0, -1)), Vector2.new(1.6, 1.0), { text = "DECON\nCLEAR", color = "#1B2A33" })
	end
end

return Builder
