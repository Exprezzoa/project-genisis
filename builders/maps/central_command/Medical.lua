--!nonstrict
-- builders/maps/central_command/Medical.lua  ->  DevTools.Builders.CentralCommand.Medical
-- docs/maps/map_01_central_command.md §8: X 80..130, Z 0..40, ceiling 18. Its roof is the Observation Deck (Y 20).
-- The west wall with the door is the East Corridor's east wall; the north wall is Equipment's divider.
--
-- Passes: blockout = shell and TRG_MED_ARCH; structure = finishes (white wainscot room), LIGHT_COOL panels (06 §5:
-- 4 x 0.2 x 4, 1.4 / 18), exterior pilasters; dressed = the scanner arch at (115, 0, 20) walked through west to east,
-- Voss's console at (118, 0, 14) facing north-west, three beds along the south wall (heads at Z 38) with curtain rails
-- and partly drawn curtains, medical cabinets along the east wall, a sink, the heart-rate wall screen, seams.
-- opts: Common, BK, Props (structure and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Medical")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

	local floor = BK.floor(S, "Floor", 80, 130, 0, 40, 0, 1, ctx.FLOOR)
	local roof = BK.ceiling(S, "Roof", 80, 130, 0, 40, 18, 2, ctx.ROOF)
	BK.wallZ(S, "Wall_E", 0, 39, 130, 0, 22, C.EXT, ctx.EXT)
	-- South wall: 20 tall where the roof bridge meets the deck (X 80..92), parapet (22) elsewhere.
	BK.wallX(S, "Wall_S_Bridge", 80.5, 92, 40, 0, 20, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_S", 92, 131, 40, 0, 22, C.EXT, ctx.EXT)

	BK.trigger(G, "TRG_MED_ARCH", V(113, 0, 17), V(117, 8, 23), "TRG_MED_ARCH")

	local Lib = opts.Props
	if ctx.level >= 2 then
		Builder.structure(ctx, C, roof)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, C, Lib)
		C.tileSeams(ctx, floor, nil)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.structure(ctx, C, roof)
	local BK, P = ctx.BK, ctx.P
	-- A white ceiling under the roof slab (the slab is the deck above).
	BK.box(ctx.Structure, "CeilingLining", V(80.5, 17.9, 0.5), V(129, 18, 39), { Color = P.MEDICAL_WHITE, CastShadow = false })
	local door = { { from = 16 - TRIM, to = 24 + TRIM, y1 = 0, y2 = C.DOUBLE_H + TRIM } }
	C.face(ctx, "FaceW", V(80.5, 0, 0.5), V(80.5, 0, 39), V(1, 0, 0), { kind = "interior", top = 17.9, gaps = door })
	C.face(ctx, "FaceN", V(80.5, 0, 0.5), V(129, 0, 0.5), V(0, 0, 1), { kind = "interior", top = 17.9 })
	C.face(ctx, "FaceE", V(129, 0, 0.5), V(129, 0, 39), V(-1, 0, 0), { kind = "interior", top = 17.9, lining = true })
	C.face(ctx, "FaceS", V(80.5, 0, 39), V(129, 0, 39), V(0, 0, -1), { kind = "interior", top = 17.9, lining = true })
	C.face(ctx, "Ext_E", V(131, 0, 0), V(131, 0, 41), V(1, 0, 0), { kind = "exterior", top = 22 })
	C.face(ctx, "Ext_S", V(92, 0, 41), V(131, 0, 41), V(0, 0, 1), { kind = "exterior", top = 22 })
	-- LIGHT_COOL panels 4 x 0.2 x 4 (06 §5), six of them.
	for i, p in ipairs({ { 92, 10 }, { 108, 10 }, { 122, 10 }, { 92, 30 }, { 108, 30 }, { 122, 30 } }) do
		C.fixture(ctx, "Panel" .. i, V(p[1], 17.8, p[2]), V(4, 0.2, 4), { Color = P.LIGHT_COOL, Brightness = 1.4, Range = 18 })
	end
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- The scanner arch: one walks through it from west to east (its passage along X).
	Lib.ScannerArch(F, CFrame.new(115, 0, 20) * Lib.FACE["+X"], { name = "ScannerArch" })
	-- Voss's console "at (118, 0, 14), facing north-west": Voss stands at MARK_VOSS_MED (118, 0, 14), so the console
	-- stands just north-west of the mark with its front toward him (south-east).
	Lib.Console(F, CFrame.new(116.4, 0, 12.4) * CFrame.Angles(0, math.rad(-135), 0), {
		name = "VossConsole", seed = 41, lines = { "MEDICAL · DR. VOSS", "SCAN QUEUE: 1", "NEURAL BASELINE" }, holo = "SCAN",
	})
	-- Three beds along the south wall, heads at Z 38, with curtain rails and curtains partly drawn.
	for i, x in ipairs({ 92, 104, 116 }) do
		Lib.MedBed(F, CFrame.new(x, 0, 34.4), { name = "Bed" .. i })
		BK.box(F, "CurtainRail" .. i, V(x - 5, 15.4, 29), V(x + 5, 15.6, 29.2), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
		for _, sx in ipairs({ -5, 5 }) do
			BK.box(F, "CurtainRailSide" .. i, V(x + sx - 0.1, 15.4, 29), V(x + sx + 0.1, 15.6, 39), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
		end
		local drawn = if i == 2 then 6 else 2.5
		BK.box(F, "Curtain" .. i, V(x - 5, 3, 29.05), V(x - 5 + drawn, 15.3, 29.15), with({ Color = "#C9D2DA", Material = "Fabric", Transparency = 0.1 }))
		BK.box(F, "CurtainSide" .. i, V(x + 4.95, 3, 30), V(x + 5.05, 15.3, 33.5), with({ Color = "#C9D2DA", Material = "Fabric", Transparency = 0.1 }))
	end
	-- Medical cabinets along the east wall, a sink between them.
	for i, z in ipairs({ 5, 9, 26, 30 }) do
		Lib.MedCabinet(F, CFrame.new(128.2, 0, z) * Lib.FACE["-X"], { name = "Cabinet" .. i, seed = i * 3 })
	end
	local sz = 17.5
	BK.box(F, "SinkCounter", V(126.6, 0, sz - 2.5), V(129, 3, sz + 2.5), { Color = P.MEDICAL_WHITE })
	BK.box(F, "SinkBasin", V(127, 2.7, sz - 1.4), V(128.6, 3.02, sz + 1.4), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	BK.box(F, "SinkTap", V(128.5, 3, sz - 0.1), V(128.7, 3.8, sz + 0.1), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	BK.box(F, "SinkSpout", V(127.9, 3.65, sz - 0.08), V(128.6, 3.8, sz + 0.08), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	-- The heart-rate wall screen on the north wall, and a duty board by the door.
	local screen = BK.part(F, with({ Name = "HeartScreen", Size = V(6, 3.4, 0.1), CFrame = BK.lookAlong(V(100, 9, 0.62), V(0, 0, 1)), Color = Lib.SCREEN_BASE, Material = "Neon", Transparency = 0.3 }))
	local g = Lib.gui(screen, Enum.NormalId.Front, 0, 40)
	Lib.rect(g, 0, 0, 1, 1, Lib.SCREEN_BASE, 0.1, "Back")
	Lib.label(g, "WARD 2 · TELEMETRY", 0.04, 0.04, 0.6, 0.14, { color = P.LIGHT_COOL })
	local trace = { 0.6, 0.6, 0.6, 0.25, 0.9, 0.55, 0.6, 0.6, 0.6, 0.6, 0.3, 0.86, 0.56, 0.6, 0.6, 0.6 }
	for i = 1, #trace - 1 do
		local x1 = 0.04 + (i - 1) * 0.92 / (#trace - 1)
		Lib.rect(g, x1, math.min(trace[i], trace[i + 1]), 0.92 / (#trace - 1) + 0.004, math.max(0.02, math.abs(trace[i + 1] - trace[i])), P.SUCCESS_GREEN, 0.15, "Trace" .. i)
	end
	BK.box(F, "HeartScreenFrame", V(96.8, 7.1, 0.5), V(103.2, 10.9, 0.56), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.sign(ctx.Detail, "Sign_Ward", BK.lookAlong(V(110, 13.4, 0.58), V(0, 0, 1)), Vector2.new(10, 1.2), "MEDICAL BAY · SCIENCE DIVISION LIAISON", {
		textColor = P.SIGN_WHITE, bgColor = P.SLATE,
	})
	-- A trolley of supplies and a stool by Voss's console.
	Lib.ToolCart(F, CFrame.new(122.5, 0, 16) * Lib.FACE["-X"], { name = "SupplyTrolley", seed = 9 })
	BK.cyl(F, { Name = "Stool", Axis = "Y", Size = V(1.4, 2.2, 1.4), Position = V(121, 1.1, 10.6), Color = P.MEDICAL_WHITE })
end

return Builder
