--!nonstrict
-- builders/maps/hangar/LaunchPlatform.lua  ->  DevTools.Builders.Hangar.LaunchPlatform
-- docs/maps/map_02_frame_hangar.md §8: deck X 123..200, Z -190..-110, top Y 0.5, DiamondPlate #4A4F55.
-- Passes: blockout = the deck; structure = chamfered edges (0.5 wedges down to the ground), the circle marking (radius
-- 25, 24 yellow segments) at (160, 0.55, -150), "LAUNCH 1" painted at (160, 0.55, -172), four FloodlightMasts (50) at
-- the corners aimed at the center (one light each, shadows: the hangar's light budget, map_02 §10); dressed = a few
-- tie-down rings, a hazard border and two bollards at the hangar door's sides. opts: Common, BK, Props, pass.

local Builder = {}

local V = Vector3.new
local CENTER = V(160, 0, -150)

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "LaunchPlatform", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure

	BK.box(S, "Deck", V(123, C.GROUND_Y, -190), V(200, 0.5, -110), ctx.DECK)
	if ctx.level < 2 then
		return C.finish(ctx)
	end
	local Lib = opts.Props
	local paint = { Color = P.HAZARD_YELLOW, CanCollide = false, CanQuery = false, CastShadow = false }
	local deck = { Color = P.STEEL_MID, Material = "DiamondPlate" }

	-- Chamfers on the three open edges (north, south, east): 0.5-tall wedges sloping down to the ground.
	-- (A wedge is high at its +Z: the north one keeps that, the south one turns round, the east one faces west.)
	BK.wedge(S, { Name = "Chamfer_N", Size = V(77, 0.6, 1), CFrame = CFrame.new(161.5, 0.2, -190.5), Color = deck.Color, Material = deck.Material })
	BK.wedge(S, { Name = "Chamfer_S", Size = V(77, 0.6, 1), CFrame = CFrame.new(161.5, 0.2, -109.5) * CFrame.Angles(0, math.pi, 0), Color = deck.Color, Material = deck.Material })
	BK.wedge(S, { Name = "Chamfer_E", Size = V(80, 0.6, 1), CFrame = CFrame.new(200.5, 0.2, -150) * CFrame.Angles(0, -math.pi / 2, 0), Color = deck.Color, Material = deck.Material })

	-- The circle (24 segments, radius 25) and "LAUNCH 1".
	for i = 0, 23 do
		local a = math.rad(i * 15 + 7.5)
		local pos = CENTER + V(math.sin(a) * 25, 0.55, math.cos(a) * 25)
		local p = table.clone(paint)
		p.Name = "Circle" .. i
		p.Size = V(1.2, 0.05, 6.2)
		p.CFrame = CFrame.lookAt(pos, pos + V(math.cos(a), 0, -math.sin(a)))
		BK.part(ctx.Detail, p)
	end
	BK.floorText(ctx.Detail, "LaunchText", V(160, 0.5, -172), Vector2.new(30, 8), "LAUNCH 1", { font = Enum.Font.Michroma, textUp = V(1, 0, 0) })
	BK.floorText(ctx.Detail, "CenterMark", CENTER + V(0, 0.5, 0), Vector2.new(6, 6), "+", { textUp = V(1, 0, 0) })

	-- Four floodlight masts at the corners, aimed at the center.
	for i, at in ipairs({ V(126, 0.5, -187), V(197, 0.5, -187), V(126, 0.5, -113), V(197, 0.5, -113) }) do
		local facing = (CENTER - at) * V(1, 0, 1)
		Lib.FloodlightMast(S, BK.lookAlong(at, facing.Unit), { name = "Mast" .. i, height = 50, aim = CENTER + V(0, 4, 0), shadows = true, single = true, lightTags = { "HubLight" } })
	end

	if ctx.level >= 3 then
		-- Tie-down rings round the circle and a hazard border along the hangar side.
		for i = 0, 7 do
			local a = math.rad(i * 45)
			local pos = CENTER + V(math.sin(a) * 31, 0.55, math.cos(a) * 31)
			BK.cyl(ctx.Detail, { Name = "TieDown" .. i, Axis = "Y", Size = V(1.4, 0.2, 1.4), Position = pos, Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CanQuery = false, CastShadow = false })
		end
		BK.hazardStripe(ctx.Detail, "DoorApron", CFrame.fromMatrix(V(125, 0.53, -150), Vector3.zAxis, Vector3.yAxis), 60, 2, { angle = 45 })
		for _, z in ipairs({ -184, -116 }) do
			Lib.Bollard(ctx.Props, CFrame.new(124.5, 0.5, z), { name = "DoorBollard" })
		end
	end
	return C.finish(ctx)
end

return Builder
