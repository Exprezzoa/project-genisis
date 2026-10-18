--!nonstrict
-- builders/maps/backdrops/City.lua  ->  DevTools.Builders.Backdrops.City
-- docs/maps/map_00_world_layout.md §1 and §3.1 (New Halden), docs/06 §3 (palette), docs/07 §5 (backdrop budget):
-- the city round the hub in two districts, West X -1400..-440, Z -900..900 and South X -900..900, Z 440..1400.
-- Concrete building masses on a loose grid (80-stud lots, 40-stud streets, seed 1187), amber window strips the
-- client shows by preset, rooftop garden nets, antenna masts with red blinkers, 6 smokestacks, and the elevated rail
-- viaduct that carries the Arrival's line (Z 132..148, at grade to X -600) west to X -1400 at Y 20.
-- A backdrop (map_00 §3): nothing collides, nothing answers queries, nothing casts a shadow, no lights.
--
-- Choices where the spec is silent (to log in decisions.md):
--   * The grid's streets fall on the Arrival's line (Z 120..160, kept clear west of the hub) and on the hub's gate road
--     (X -20..20); a lot belongs to the district its center is in (West first where the two overlap).
--   * The South district keeps its full X range; lots that straddle the Bulwark (X 400..450 with its buttresses,
--     Z -800..800) keep their larger side. East of the wall (X 450..900, Z 440..1000) the blocks stand on the
--     Wilderness builder's ground (top Y 0), which leaves that box clear for them; this ground stops at X 450 there.
--     WILDERNESS_CLIP = true would keep blocks out of the wilderness box (X >= 450, Z -1000..1000) instead.
--   * Heights 30..160 rise with distance: West with -X, South with +Z at 0.75 of the West's rise (the tallest stay in
--     the far west). Window strips only on the face turned to the hub (West: +X, South: -Z), a third of the blocks
--     with 2, a third with 4 (the tallest), the rest 3, spaced evenly up the facade.
--   * Ground: Pavement #7C8086 like the hub's grounds, top at Y -0.1, widened 20 to meet the hub's ground (X -420,
--     Z 420; not over the Exterior's gate apron X -56..56).
--   * Viaduct: an earth embankment ramp (a wedge) from the at-grade end at X -600 (Y -0.1) to the deck at X -760
--     (Y 20), then the deck on pillars every 60 to X -1400; ballast, a sleeper band and two rails as on the Arrival.
--   * Rooftops: exactly 30% nets and 15% antennas on different roofs; the 6 stacks stand on roofs no taller than 60
--     (tops <= 119, under the Bulwark) spread along the grid; nets 6 above the roof (Fabric), antennas 8..16.
--
-- Passes (docs/07 §2): blockout = everything in the spec (ground, blocks, window strips, garden nets, antennas and
-- blinkers, smokestacks with their smoke, the viaduct with its ramp, pillars and track); structure = the viaduct's
-- parapets and pillar crossheads; dressed = a soot band at the top of each smokestack.
--
-- Expected parts (from the loop bounds below; budget: City <= 1,400, all backdrops 2,500):
--   ground plates                 24   (8 + 3 + 2 + 1 + 1 + 4 + 1 + 4 tiles of at most 512)
--   building masses              200   (220 lots: West 120, South 100; 20 left empty, seeded)
--   window strips                600   (66 x 2 + 68 x 3 + 66 x 4)
--   garden nets                  300   (60 = 30% of 200, plate + 4 posts)
--   antennas                      60   (30 = 15% of 200, mast + blinker)
--   smokestacks                   12   (6 stacks + 6 invisible vents carrying the emitters)
--   viaduct                       25   (ramp wedge + 4 track parts, 2 spans x (deck + 4 track parts), 10 pillars)
--   blockout                    1,221
--   structure                     +14  (4 parapets, 10 crossheads)  = 1,235
--   dressed                        +6  (6 stack bands)              = 1,241;   lights 0, emitters 6
--
-- Client contract: window strips are tagged "CityWindow" with the attribute Rank in [0, 1) (shown while Rank is under
-- the preset's fraction: MORNING 0.10, EVENING 0.60, NIGHT 0.85; built shown, transparency 0.35). Blinkers are tagged
-- "Blinker" (attribute BlinkHz 0.8).
-- opts: Common, BK, pass.

local Builder = {}

local V = Vector3.new

local SEED = 1187
local PART_BUDGET = 1400
local BLOCK_COUNT = 200 -- map_00 §3.1: 180..240

-- Districts (map_00 §1). face: the facade turned toward the hub, which carries the window strips.
local WEST = { name = "West", x1 = -1400, x2 = -440, z1 = -900, z2 = 900, face = "+X" }
local SOUTH = { name = "South", x1 = -900, x2 = 900, z1 = 440, z2 = 1400, face = "-Z" }
local SOUTH_RISE = 0.75 -- the South district's height gradient relative to the West's

-- The grid: 80-stud lots with 40-stud streets. Streets run X -20..20 (+120k) and Z 120..160 (+120k).
local PITCH, LOT = 120, 80
local LOT_X0, LOT_Z0 = 20, 40
local MIN_LOT = 30
local FOOT_MIN, FOOT_MAX = 20, 80
local H_LOW, H_HIGH = { 30, 70 }, { 100, 160 } -- height range at the near edge and at the far edge
local H_CAP = 160

-- What the lots keep clear of.
local BULWARK = { x1 = 400, x2 = 450, z1 = -800, z2 = 800 } -- the wall X 420..450 plus its 20-deep buttresses
local WILDERNESS_CLIP = true -- D-107: New Halden ends at its east wall (docs/02); nothing of the city stands outside it
local WILD = { x1 = 450, z1 = -1000, z2 = 1000 } -- map_00 §1: the Wilderness backdrop X 450..2000, Z -1000..1000
local RAIL_CLEAR = { x2 = -420, z1 = 120, z2 = 160 }

-- Rooftops (map_00 §3.1).
local NET_SHARE, ANTENNA_SHARE = 0.30, 0.15
local NET_COLOR = "#5D6650" -- the spec's hex (no palette key)
local NET_HEIGHT = 6
local ANTENNA_MIN, ANTENNA_MAX = 8, 16
local BLINK_HZ = 0.8
local STACKS, STACK_D, STACK_H = 6, 8, 60
local STACK_ROOF = 24 -- a roof at least this wide on both sides can carry a stack
local STACK_HOST_MAX = 60 -- and no taller than this, so no stack tops the Bulwark (120)
local SMOKE_RATE = 2

-- Windows.
local STRIP_H, STRIP_INSET, STRIP_TRANSPARENCY = 0.4, 2, 0.35

-- Ground.
local GROUND_TOP, GROUND_T, TILE = -0.1, 2, 512
local BASE_Y = -1 -- blocks and pillars start inside the ground plate

-- The rail line (map_01 §11, D-102: at grade X -600..412 on Z 132..148, rails at Z 136 and 144).
local RAIL_Z, RAILS = 140, { 136, 144 }
local GRADE_END = -600 -- the Arrival's line ends here; the ramp starts
local RAMP_TOP_X = -760
local VIADUCT_WEST = -1400
local DECK_TOP, DECK_T = 20, 3
local DECK_Z1, DECK_Z2 = 132, 148
local DECK_SPANS = { { -1400, -1060 }, { -1060, -760 } } -- joint over a pillar; under 512 long
local PILLAR_STEP = 60
local RAMP_WIDTH = 24 -- Z 128..152, as the Arrival's embankment

-- Ground pieces { name, x1, x2, z1, z2 }; each is cut into tiles of at most 512. The rail corridor X -760..-420,
-- Z 128..152 is left to the Arrival's embankment (X -600..-420) and the ramp; the wilderness box (X >= 450,
-- Z < 1000) to the Wilderness builder's ground.
local GROUND_PIECES = {
	{ "W", -1400, -760, -900, 900 },
	{ "WN", -760, -420, -900, 128 },
	{ "WS", -760, -420, 152, 900 },
	{ "GateW", -420, -56, 420, 440 },
	{ "GateE", 56, 450, 420, 440 },
	{ "S", -420, 450, 440, 1000 },
	{ "SW", -900, -420, 900, 1000 },
	{ "SFar", -900, 900, 1000, 1400 },
}

local function inside(r, x, z)
	return x >= r.x1 and x < r.x2 and z >= r.z1 and z < r.z2
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function shuffle(list, rng)
	for k = #list, 2, -1 do
		local r = rng.int(1, k)
		list[k], list[r] = list[r], list[k]
	end
end

-- The lots, in grid order (X outer, Z inner), each clipped to its district and clear of the Bulwark, the
-- wilderness and the rail corridor.
local function lotGrid()
	local lots = {}
	local iMin = math.floor((WEST.x1 - LOT_X0) / PITCH) - 1
	local iMax = math.ceil((SOUTH.x2 - LOT_X0) / PITCH) + 1
	local jMin = math.floor((WEST.z1 - LOT_Z0) / PITCH) - 1
	local jMax = math.ceil((SOUTH.z2 - LOT_Z0) / PITCH) + 1
	for i = iMin, iMax do
		for j = jMin, jMax do
			local x1, z1 = LOT_X0 + PITCH * i, LOT_Z0 + PITCH * j
			local x2, z2 = x1 + LOT, z1 + LOT
			local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
			local district = if inside(WEST, cx, cz) then WEST elseif inside(SOUTH, cx, cz) then SOUTH else nil
			if district then
				x1, x2 = math.max(x1, district.x1), math.min(x2, district.x2)
				z1, z2 = math.max(z1, district.z1), math.min(z2, district.z2)
				if z1 < BULWARK.z2 and z2 > BULWARK.z1 and x1 < BULWARK.x2 and x2 > BULWARK.x1 then
					if BULWARK.x1 - x1 >= x2 - BULWARK.x2 then
						x2 = BULWARK.x1
					else
						x1 = BULWARK.x2
					end
				end
				if WILDERNESS_CLIP and z1 < WILD.z2 and z2 > WILD.z1 and x2 > WILD.x1 then
					x2 = WILD.x1
				end
				local onRail = x1 < RAIL_CLEAR.x2 and z1 < RAIL_CLEAR.z2 and z2 > RAIL_CLEAR.z1
				if x2 - x1 >= MIN_LOT and z2 - z1 >= MIN_LOT and not onRail then
					table.insert(lots, { district = district, x1 = x1, x2 = x2, z1 = z1, z2 = z2 })
				end
			end
		end
	end
	return lots
end

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Backdrops", "City", true)
	local BK = ctx.BK
	local rng = BK.rng(SEED)
	local backdrop = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function style(color, material, extra)
		local props = table.clone(backdrop)
		props.Color, props.Material = color, material
		if extra then
			for key, value in pairs(extra) do
				props[key] = value
			end
		end
		return props
	end

	-- Every random draw happens in the blockout code, in a fixed order, so all passes get the same city.
	Builder.ground(ctx, style)
	local city = Builder.plan(ctx, rng)
	Builder.blocks(ctx, style, city, rng)
	Builder.viaduct(ctx, style)
	if ctx.level >= 2 then
		Builder.viaductStructure(ctx, style)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, style, city)
	end

	local parts = BK.stats(ctx.root).parts
	if parts > PART_BUDGET then
		BK.warn(("Backdrops.City: %d parts, over its budget of %d (docs/07 §5)"):format(parts, PART_BUDGET))
	end
	return C.finish(ctx)
end

function Builder.ground(ctx, style)
	local BK, S = ctx.BK, ctx.Structure
	local pavement = style("#7C8086", "Pavement")
	for _, piece in ipairs(GROUND_PIECES) do
		local name, x1, x2, z1, z2 = piece[1], piece[2], piece[3], piece[4], piece[5]
		local nx, nz = math.ceil((x2 - x1) / TILE), math.ceil((z2 - z1) / TILE)
		for ix = 1, nx do
			for iz = 1, nz do
				local a1, a2 = lerp(x1, x2, (ix - 1) / nx), lerp(x1, x2, ix / nx)
				local b1, b2 = lerp(z1, z2, (iz - 1) / nz), lerp(z1, z2, iz / nz)
				BK.box(S, ("Ground_%s_%d_%d"):format(name, ix, iz), V(a1, GROUND_TOP - GROUND_T, b1), V(a2, GROUND_TOP, b2), pavement)
			end
		end
	end
end

-- The city as data: footprints, heights, colors, window counts and roofs. Draws from rng in a fixed order.
function Builder.plan(ctx, rng)
	local BK, P = ctx.BK, ctx.P
	local lots = lotGrid()
	local count = math.min(BLOCK_COUNT, #lots)
	if #lots < BLOCK_COUNT then
		BK.warn(("Backdrops.City: only %d lots for %d blocks"):format(#lots, BLOCK_COUNT))
	end

	-- Leave the surplus lots empty (seeded).
	local order = {}
	for k = 1, #lots do
		order[k] = k
	end
	local empty = {}
	for k = 1, #lots - count do
		local r = rng.int(k, #order)
		order[k], order[r] = order[r], order[k]
		empty[order[k]] = true
	end

	-- Footprints loose in their lots; heights rise toward the far edge of each district.
	local colors = { P.CONCRETE_MID, P.CONCRETE_DARK, BK.hex("#5A5F66") }
	local city = {}
	for k, lot in ipairs(lots) do
		if not empty[k] then
			local lw, ld = lot.x2 - lot.x1, lot.z2 - lot.z1
			local w = rng.int(FOOT_MIN, math.min(FOOT_MAX, lw))
			local d = rng.int(FOOT_MIN, math.min(FOOT_MAX, ld))
			local x1 = lot.x1 + rng.int(0, lw - w)
			local z1 = lot.z1 + rng.int(0, ld - d)
			local b = { district = lot.district, x1 = x1, x2 = x1 + w, z1 = z1, z2 = z1 + d }
			local t
			if lot.district == WEST then
				t = math.clamp((WEST.x2 - (b.x1 + b.x2) / 2) / (WEST.x2 - WEST.x1), 0, 1)
			else
				t = SOUTH_RISE * math.clamp(((b.z1 + b.z2) / 2 - SOUTH.z1) / (SOUTH.z2 - SOUTH.z1), 0, 1)
			end
			local h = rng.next(lerp(H_LOW[1], H_HIGH[1], t), lerp(H_LOW[2], H_HIGH[2], t))
			b.h = math.clamp(math.round(h), H_LOW[1], H_CAP)
			b.color = BK.vary(rng.pick(colors), 0.03, rng)
			table.insert(city, b)
			b.index = #city
		end
	end

	-- Window strips by height: the lowest third 2, the tallest third 4, the rest 3.
	local byHeight = table.clone(city)
	table.sort(byHeight, function(a, b)
		if a.h ~= b.h then
			return a.h < b.h
		end
		return a.index < b.index
	end)
	local third = math.floor(#byHeight / 3)
	for rank, b in ipairs(byHeight) do
		b.strips = if rank <= third then 2 elseif rank > #byHeight - third then 4 else 3
	end

	-- Smokestacks on 6 of the roofs wide enough for one and no taller than STACK_HOST_MAX (at least the 6 lowest),
	-- spread along the grid.
	local low = {}
	for _, b in ipairs(byHeight) do
		if b.x2 - b.x1 >= STACK_ROOF and b.z2 - b.z1 >= STACK_ROOF and (b.h <= STACK_HOST_MAX or #low < STACKS) then
			table.insert(low, b)
		end
	end
	table.sort(low, function(a, b)
		return a.index < b.index
	end)
	if #low < STACKS then
		BK.warn(("Backdrops.City: only %d roofs can carry a smokestack"):format(#low))
	end
	for k = 1, math.min(STACKS, #low) do
		low[math.floor((k - 0.5) * #low / STACKS) + 1].roof = "stack"
	end

	-- Garden nets on 30% of the blocks, antennas on 15% (never on the same roof, nor on a stack's).
	local pool = {}
	for _, b in ipairs(city) do
		if not b.roof then
			table.insert(pool, b)
		end
	end
	shuffle(pool, rng)
	local nets = math.floor(#city * NET_SHARE + 0.5)
	local antennas = math.floor(#city * ANTENNA_SHARE + 0.5)
	for k, b in ipairs(pool) do
		if k <= nets then
			b.roof = "net"
		elseif k <= nets + antennas then
			b.roof = "antenna"
		end
	end
	return city
end

function Builder.blocks(ctx, style, city, rng)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local post = style(P.STEEL_DARK, "Metal")
	local net = style(NET_COLOR, "Fabric")
	local stackStyle = style(P.CONCRETE_DARK, "Concrete")
	local stacks = 0
	for _, b in ipairs(city) do
		local i = b.index
		BK.box(S, "Block" .. i, V(b.x1, BASE_Y, b.z1), V(b.x2, b.h, b.z2), style(b.color, "Concrete"))

		-- Window strips on the facade turned to the hub, evenly spaced up it.
		for k = 1, b.strips do
			local y = b.h * k / (b.strips + 1)
			local props = style(P.AMBER_LAMP, "Neon", {
				Transparency = STRIP_TRANSPARENCY,
				Tags = { "CityWindow" },
				Attributes = { Rank = rng.next() },
			})
			local name = ("Window%d_%d"):format(i, k)
			local half = STRIP_H / 2
			if b.district.face == "+X" then
				BK.box(S, name, V(b.x2 - 0.1, y - half, b.z1 + STRIP_INSET), V(b.x2 + 0.1, y + half, b.z2 - STRIP_INSET), props)
			else
				BK.box(S, name, V(b.x1 + STRIP_INSET, y - half, b.z1 - 0.1), V(b.x2 - STRIP_INSET, y + half, b.z1 + 0.1), props)
			end
		end

		if b.roof == "net" then
			-- A 0.2-thick net over the roof garden, inset 2 from the edges, on 4 corner posts.
			local x1, x2, z1, z2 = b.x1 + 2, b.x2 - 2, b.z1 + 2, b.z2 - 2
			local top = b.h + NET_HEIGHT
			BK.box(S, "GardenNet" .. i, V(x1, top, z1), V(x2, top + 0.2, z2), net)
			for k, c in ipairs({ { x1, z1 }, { x2 - 0.5, z1 }, { x1, z2 - 0.5 }, { x2 - 0.5, z2 - 0.5 } }) do
				BK.box(S, ("GardenPost%d_%d"):format(i, k), V(c[1], b.h - 0.2, c[2]), V(c[1] + 0.5, top, c[2] + 0.5), post)
			end
		elseif b.roof == "antenna" then
			local height = rng.int(ANTENNA_MIN, ANTENNA_MAX)
			local ax = rng.next(b.x1 + 2, b.x2 - 2)
			local az = rng.next(b.z1 + 2, b.z2 - 2)
			local top = b.h + height
			BK.box(S, "Antenna" .. i, V(ax - 0.25, b.h - 0.2, az - 0.25), V(ax + 0.25, top, az + 0.25), post)
			BK.box(S, "Blinker" .. i, V(ax - 0.5, top, az - 0.5), V(ax + 0.5, top + 1, az + 0.5), style(P.DANGER_RED, "Neon", {
				Tags = { "Blinker" },
				Attributes = { BlinkHz = BLINK_HZ },
			}))
		elseif b.roof == "stack" then
			-- A cylinder 8 x 60 standing on the roof (1 into it), its slow smoke from an invisible vent on top.
			stacks += 1
			local mx = (b.x2 - b.x1) / 2 - STACK_D / 2 - 1
			local mz = (b.z2 - b.z1) / 2 - STACK_D / 2 - 1
			local sx = (b.x1 + b.x2) / 2 + rng.next(-mx, mx)
			local sz = (b.z1 + b.z2) / 2 + rng.next(-mz, mz)
			local bottom = b.h - 1
			local top = bottom + STACK_H
			local p = table.clone(stackStyle)
			p.Name, p.Axis, p.Size, p.Position = "Smokestack" .. stacks, "Y", V(STACK_D, STACK_H, STACK_D), V(sx, bottom + STACK_H / 2, sz)
			BK.cyl(S, p)
			local vent = BK.box(S, "SmokeVent" .. stacks, V(sx - 3, top, sz - 3), V(sx + 3, top + 1, sz + 3), style(P.STEEL_DARK, "SmoothPlastic", {
				Transparency = 1,
			}))
			local smoke = BK.emitter(vent, "Smoke")
			smoke.Rate = SMOKE_RATE
			smoke.Size = NumberSequence.new(10, 30)
			smoke.Transparency = NumberSequence.new(0.75, 1)
			smoke.Lifetime = NumberRange.new(8, 12)
			smoke.Speed = NumberRange.new(2, 4)
			b.stack = { x = sx, z = sz, top = top }
		end
	end
end

-- The rail viaduct (map_00 §3.1): the ramp from the at-grade end up to the deck, the deck on pillars every 60, and
-- the track (ballast, a sleeper band and two rails, 0..0.5 / 0.5..0.8 / 0.8..1.4 above the surface, as the Arrival's).
function Builder.viaduct(ctx, style)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local ballast = style(P.ROCK, "Slate")
	local sleepers = style(P.WOOD_OLD, "Wood")
	local rail = style(P.STEEL_LIGHT, "Metal")
	-- A track from (xa, surface sa) to (xb, surface sb); sloped on the ramp, flat on the deck.
	local function track(name, xa, sa, xb, sb)
		local function run(partName, z, width, lo, hi, props)
			local y = (lo + hi) / 2
			BK.beam(S, partName, V(xa, sa + y, z), V(xb, sb + y, z), width, hi - lo, props)
		end
		run(name .. "_Ballast", RAIL_Z, 14, 0, 0.5, ballast)
		run(name .. "_Sleepers", RAIL_Z, 11, 0.5, 0.8, sleepers)
		for k, z in ipairs(RAILS) do
			run(name .. "_Rail" .. k, z, 0.4, 0.8, 1.4, rail)
		end
	end

	-- The ramp: an earth wedge whose tall end (X -760) meets the deck and whose foot meets the Arrival's line at X -600.
	BK.triangle(S, "Viaduct_Ramp", V(RAMP_TOP_X, GROUND_TOP, RAIL_Z), V(0, DECK_TOP - GROUND_TOP, 0), V(GRADE_END - RAMP_TOP_X, 0, 0), RAMP_WIDTH, style(P.GROUND, "Ground"))
	track("Viaduct_RampTrack", GRADE_END, GROUND_TOP, RAMP_TOP_X, DECK_TOP)

	local concrete = style(P.CONCRETE_MID, "Concrete")
	for k, span in ipairs(DECK_SPANS) do
		BK.box(S, "Viaduct_Deck" .. k, V(span[1], DECK_TOP - DECK_T, DECK_Z1), V(span[2], DECK_TOP, DECK_Z2), concrete)
		track("Viaduct_Track" .. k, span[2], DECK_TOP, span[1], DECK_TOP)
	end
	local dark = style(P.CONCRETE_DARK, "Concrete")
	local n = 0
	for x = RAMP_TOP_X - PILLAR_STEP, VIADUCT_WEST, -PILLAR_STEP do
		n += 1
		BK.box(S, "Viaduct_Pillar" .. n, V(x - 2, BASE_Y, RAIL_Z - 4), V(x + 2, DECK_TOP - DECK_T, RAIL_Z + 4), dark)
	end
end

-- Structure: low parapets on both deck edges and a crosshead under the deck on each pillar.
function Builder.viaductStructure(ctx, style)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local concrete = style(P.CONCRETE_MID, "Concrete")
	local dark = style(P.CONCRETE_DARK, "Concrete")
	for k, span in ipairs(DECK_SPANS) do
		BK.box(S, ("Viaduct_Parapet%d_N"):format(k), V(span[1], DECK_TOP, DECK_Z1), V(span[2], DECK_TOP + 1.5, DECK_Z1 + 0.6), concrete)
		BK.box(S, ("Viaduct_Parapet%d_S"):format(k), V(span[1], DECK_TOP, DECK_Z2 - 0.6), V(span[2], DECK_TOP + 1.5, DECK_Z2), concrete)
	end
	local n = 0
	for x = RAMP_TOP_X - PILLAR_STEP, VIADUCT_WEST, -PILLAR_STEP do
		n += 1
		local y = DECK_TOP - DECK_T
		BK.box(S, "Viaduct_Crosshead" .. n, V(x - 3, y - 2, DECK_Z1 - 1), V(x + 3, y, DECK_Z2 + 1), dark)
	end
end

-- Dressed: a soot band (STEEL_DARK, 3 tall) just under the top of each smokestack.
function Builder.dress(ctx, style, city)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local band = style(P.STEEL_DARK, "Metal")
	local n = 0
	for _, b in ipairs(city) do
		if b.stack then
			n += 1
			local p = table.clone(band)
			p.Name, p.Axis, p.Size, p.Position = "SmokestackBand" .. n, "Y", V(STACK_D + 0.6, 3, STACK_D + 0.6), V(b.stack.x, b.stack.top - 2.5, b.stack.z)
			BK.cyl(S, p)
		end
	end
end

return Builder
