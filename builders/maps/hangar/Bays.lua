--!nonstrict
-- builders/maps/hangar/Bays.lua  ->  DevTools.Builders.Hangar.Bays
-- docs/maps/map_02_frame_hangar.md §2: three bay rectangles (50 x 50), a 1-wide yellow outline 0.05 high,
-- and the bay number painted on the floor at (bayX, 0.05, -186). From the structure pass: the hazard placards on the
-- bays' front supports (the side catwalks' columns at Z -189..-187), "DANGER — FRAME BAY — STAY BEHIND THE LINE".
-- (Bay 3's dressing is Unit 03's builder.)

local Builder = {}

local V = Vector3.new

local BAYS = {
	{ "01", -95, -45 },
	{ "02", -25, 25 },
	{ "03", 45, 95 },
}
local Z1, Z2 = -230, -180
-- The side catwalks' columns (Hangar.Catwalks: 2 x 44 x 2 at X x1..x1+2 and x2-2..x2, Z -189..-187).
local COLUMNS = { -117, -111, -38, -32, 32, 38, 111, 117 }

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Bays", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local paint = { Color = P.HAZARD_YELLOW, CanCollide = false, CanQuery = false, CastShadow = false }

	for _, bay in ipairs(BAYS) do
		local number, x1, x2 = bay[1], bay[2], bay[3]
		local name = "Bay" .. number
		-- The north side stops at the wall's inner face (Z -228.5).
		BK.box(S, name .. "_Line_S", V(x1, 0, Z2 - 1), V(x2, 0.05, Z2), paint)
		BK.box(S, name .. "_Line_N", V(x1, 0, Z1 + 1.5), V(x2, 0.05, Z1 + 2.5), paint)
		BK.box(S, name .. "_Line_W", V(x1, 0, Z1 + 2.5), V(x1 + 1, 0.05, Z2 - 1), paint)
		BK.box(S, name .. "_Line_E", V(x2 - 1, 0, Z1 + 2.5), V(x2, 0.05, Z2 - 1), paint)
		BK.floorText(S, name .. "_Number", V((x1 + x2) / 2, 0, -186), Vector2.new(16, 10), number, { font = Enum.Font.Michroma })
	end

	if ctx.level >= 2 then
		for i, x in ipairs(COLUMNS) do
			BK.sign(ctx.Detail, "Placard" .. i, BK.lookAlong(V(x, 6.5, -186.94), V(0, 0, 1)), Vector2.new(1.9, 2.6), "DANGER — FRAME BAY — STAY BEHIND THE LINE", {
				textColor = P.HAZARD_BLACK, bgColor = P.HAZARD_YELLOW,
			})
		end
	end

	return C.finish(ctx)
end

return Builder
