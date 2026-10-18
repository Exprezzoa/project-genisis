--!nonstrict
-- builders/maps/backdrops/Wilderness.lua  ->  DevTools.Builders.Backdrops.Wilderness
-- docs/maps/map_00_world_layout.md §3.2 (extents §1: X 450..2000, Z -1000..1000), colors docs/06 §3: the wilderness
-- east of the Bulwark, seen through the Frame Gate. Ground plates with ASH_DARK patches, rolling hills of wedge
-- pairs, 14 dead-forest clusters, the ruined city silhouette (X 1400..1900, Z -600..400), the distant Titan
-- silhouette standing still at (1600, 0, -300), and ash drifting west over the wall near the gate.
-- A backdrop (map_00 §3): nothing collides, nothing answers queries, nothing casts a shadow; no lights.
-- Passes: everything in §3.2 is built at blockout (a backdrop is only ever seen from afar, and §3.2 has no purely
-- decorative extras); structure and dressed add nothing. opts: Common, BK, pass.
--
-- Parts (maxima from the loop bounds; Wilderness budget 700 of the backdrops' 2,500, docs/07 §5):
--   ground tiles      4 x 4                                                  =  16
--   ash patches       up to 20                                               <= 20
--   hills             16 x 2 wedges                                          <= 32
--   dead forest       14 clusters, <= 120 trees x (trunk + 2 branches) + <= 40 third branches  <= 400
--   ruined towers     18 x (1 body + <= 3 top wedges + <= 4 window strips)   <= 144
--   distant Titan     exactly 12
--   ash emitter part  1
--   total             <= 625 parts, 0 lights, 1 particle emitter
--
-- Seeds (map_00 gives none for the wilderness): patches 4520, hills 4530, forest 4540, ruins 4550.
-- The ground's top is Y 0: 0.1 above the Bulwark builder's Ground_East (top -0.1, now hidden under it) and 0.1 below
-- its Road_East (top 0.1), so the road from the gate stays visible.

local Builder = {}

local V = Vector3.new
local RAD = math.rad
local TAU = 2 * math.pi

-- map_00 §1 and §3.2.
local X1, X2, Z1, Z2 = 450, 2000, -1000, 1000
local TILE = 512 -- docs/07 §5: large ground is tiled at 512 x 512
local GATE = V(435, 0, -150) -- the Frame Gate's center (map_02 §8: opening Z -180..-120 in the wall X 420..450)
local TITAN = V(1600, 0, -300)
local TITAN_COLOR = "#2F2C2A" -- map_00 §3.2 (no palette key)
local RUIN_COLOR = "#4E5257" -- map_00 §3.2 (no palette key)

local SEED = { patches = 4520, hills = 4530, forest = 4540, ruins = 4550 }

-- Keep-out boxes { x1, x2, z1, z2 } for the scattered features (bounding circles are tested against them).
local ROAD = { 450, 740, -200, -100 } -- the Bulwark's road X 450 -> 700 from the gate (Z -180..-120), padded
local CITY_SOUTH = { 450, 920, 420, 1000 } -- map_00 §3.1's southern city (X -900..900, Z 440..1400) overlaps here
local RUINS = { 1380, 1920, -620, 420 } -- the ruined city, padded 20 (no hills or trees in it)

local PATCH_COUNT, HILL_COUNT, CLUSTERS = 20, 16, 14
local MAX_TREES, MAX_THIRD_BRANCHES = 120, 40 -- keep the forest at or under 400 parts
local TOWERS_X, TOWERS_Z = 3, 6 -- 18 towers on a jittered 3 x 6 grid of cells

---------------------------------------------------------------------------------------------------
-- Placement helpers (XZ only)
---------------------------------------------------------------------------------------------------
local function outsideBox(x, z, r, box)
	local dx = math.max(box[1] - x, 0, x - box[2])
	local dz = math.max(box[3] - z, 0, z - box[4])
	return dx * dx + dz * dz >= r * r
end

-- The circle lies inside the wilderness (inset from its edges).
local function inside(x, z, r, inset)
	return x - r >= X1 + inset and x + r <= X2 - inset and z - r >= Z1 + inset and z + r <= Z2 - inset
end

-- Clear of the road, the southern city and the ruined city.
local function clear(x, z, r)
	return outsideBox(x, z, r, ROAD) and outsideBox(x, z, r, CITY_SOUTH) and outsideBox(x, z, r, RUINS)
end

-- Distance from (x, z) to the segment a-b.
local function segmentDistance(x, z, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local t = math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / (abx * abx + abz * abz), 0, 1)
	local px, pz = a.X + abx * t, a.Z + abz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
end

-- The view from the gate to the Titan: hills, trees and towers keep out of it.
local function sightDistance(x, z)
	return segmentDistance(x, z, GATE, TITAN)
end

local function with(props, name, size, cframe)
	local p = table.clone(props)
	p.Name, p.Size, p.CFrame = name, size, cframe
	return p
end

---------------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------------
function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Backdrops", "Wilderness", true)
	local function style(color, material)
		return { Color = color, Material = material, CanCollide = false, CanQuery = false, CastShadow = false }
	end

	Builder.ground(ctx, style)
	local hills = Builder.hills(ctx, style)
	Builder.forest(ctx, style, hills)
	Builder.ruins(ctx, style)
	Builder.titan(ctx, style)
	Builder.ash(ctx, style)
	return C.finish(ctx)
end

-- Ground plates 512 x 512 (the last row and column cut to fit: X 1986..2000, Z 536..1000), top at Y 0, 1 thick.
-- ASH_DARK patches: flat plates 0.1 thick with their top 0.05 above the ground, 40-200 a side, turned at random.
-- They never overlap one another (their tops would be coplanar), so a patch with no room after 60 tries is skipped.
function Builder.ground(ctx, style)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local dirt = style(P.GROUND, "Ground")
	local i = 0
	for x = X1, X2 - 1, TILE do
		for z = Z1, Z2 - 1, TILE do
			i += 1
			BK.box(S, "Ground" .. i, V(x, -1, z), V(math.min(x + TILE, X2), 0, math.min(z + TILE, Z2)), dirt)
		end
	end

	local rng = BK.rng(SEED.patches)
	local ash = style(P.ASH_DARK, "Ground")
	local placed = {}
	for _ = 1, PATCH_COUNT do
		for _ = 1, 60 do
			local sx, sz = rng.next(40, 200), rng.next(40, 200)
			local yaw = rng.next(0, math.pi)
			local r = math.sqrt(sx * sx + sz * sz) / 2
			local x, z = rng.next(X1, X2), rng.next(Z1, Z2)
			local ok = inside(x, z, r, 0) and outsideBox(x, z, r, ROAD) and outsideBox(x, z, r, CITY_SOUTH)
			for _, q in ipairs(placed) do
				if ok and (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < (r + q[3]) ^ 2 then
					ok = false
				end
			end
			if ok then
				table.insert(placed, { x, z, r })
				BK.part(S, with(ash, "AshPatch" .. #placed, V(sx, 0.1, sz), CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)))
				break
			end
		end
	end
end

-- Rolling hills: each a ridge of two wedges back to back. Each wedge is 60-200 wide (along the ridge) and runs
-- 60-200 down its slope at 5-12°; both sides share the ridge height, so the far side's run follows from its slope.
-- Hills keep out of the road, the southern city, the ruined city and the gate's view of the Titan.
-- Returns the hills for Builder.surface (trees stand on them).
function Builder.hills(ctx, style)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local rng = BK.rng(SEED.hills)
	local dirt = style(P.GROUND, "Ground")
	local hills = {}
	for _ = 1, HILL_COUNT do
		for _ = 1, 200 do
			local width = rng.next(60, 200)
			local run1 = rng.next(60, 200)
			local height = run1 * math.tan(RAD(rng.next(5, 12)))
			local lo = math.max(RAD(5), math.atan(height / 200))
			local hi = math.max(lo, math.min(RAD(12), math.atan(height / 60)))
			local run2 = height / math.tan(rng.next(lo, hi))
			local yaw = rng.next(0, math.pi)
			local r = math.sqrt((width / 2) ^ 2 + math.max(run1, run2) ^ 2)
			local x, z = rng.next(X1, X2), rng.next(Z1, Z2)
			local ok = inside(x, z, r, 5) and clear(x, z, r) and sightDistance(x, z) >= r + 30
			for _, h in ipairs(hills) do
				if ok and (x - h.x) ^ 2 + (z - h.z) ^ 2 < ((r + h.r) * 0.6) ^ 2 then
					ok = false
				end
			end
			if ok then
				local n = #hills + 1
				local frame = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
				-- A WedgePart rises toward its Back (+Z): the near side as is, the far side turned round.
				BK.wedge(S, with(dirt, ("Hill%d_A"):format(n), V(width, height, run1), frame * CFrame.new(0, height / 2, -run1 / 2)))
				BK.wedge(S, with(dirt, ("Hill%d_B"):format(n), V(width, height, run2), frame * CFrame.new(0, height / 2, run2 / 2) * CFrame.Angles(0, math.pi, 0)))
				table.insert(hills, { x = x, z = z, r = r, frame = frame, width = width, height = height, run1 = run1, run2 = run2 })
				break
			end
		end
	end
	if #hills < HILL_COUNT then
		BK.warn(("Wilderness: placed %d of %d hills"):format(#hills, HILL_COUNT))
	end
	return hills
end

-- The height of the hills' surface at (x, z) (0 on flat ground).
function Builder.surface(hills, x, z)
	local y = 0
	for _, h in ipairs(hills) do
		local l = h.frame:PointToObjectSpace(V(x, 0, z))
		if math.abs(l.X) <= h.width / 2 then
			if l.Z >= -h.run1 and l.Z <= 0 then
				y = math.max(y, h.height * (1 + l.Z / h.run1))
			elseif l.Z > 0 and l.Z <= h.run2 then
				y = math.max(y, h.height * (1 - l.Z / h.run2))
			end
		end
	end
	return y
end

-- 14 clusters (radius 30-55, centers at least 160 apart while there is room) of 6-12 dead trees at least 6 apart.
-- At most 120 trees: if the draw comes to more, the largest clusters lose a tree each (never below 6).
-- Clusters keep out of the road, the southern city, the ruined city and the gate's view of the Titan.
function Builder.forest(ctx, style, hills)
	local BK, P = ctx.BK, ctx.P
	local rng = BK.rng(SEED.forest)
	local wood = style(P.TREE_DEAD, "Wood")
	local counts, total = {}, 0
	for c = 1, CLUSTERS do
		counts[c] = rng.int(6, 12)
		total += counts[c]
	end
	while total > MAX_TREES do
		local big = 1
		for c = 2, CLUSTERS do
			if counts[c] > counts[big] then
				big = c
			end
		end
		counts[big] -= 1
		total -= 1
	end

	local centers, thirds = {}, 0
	for c = 1, CLUSTERS do
		local cx, cz, radius
		for attempt = 1, 200 do
			local r = rng.next(30, 55)
			local x, z = rng.next(X1, X2), rng.next(Z1, Z2)
			local ok = inside(x, z, r, 5) and clear(x, z, r) and sightDistance(x, z) >= r + 10
			if attempt <= 100 then
				for _, q in ipairs(centers) do
					if ok and (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < 160 ^ 2 then
						ok = false
					end
				end
			end
			if ok then
				cx, cz, radius = x, z, r
				break
			end
		end
		if not cx then
			BK.warn(("Wilderness: no room for forest cluster %d"):format(c))
			continue
		end
		table.insert(centers, { cx, cz })
		local trees = {}
		for t = 1, counts[c] do
			local x, z
			for _ = 1, 8 do
				local a, d = rng.next(0, TAU), radius * math.sqrt(rng.next())
				x, z = cx + d * math.cos(a), cz + d * math.sin(a)
				local spaced = true
				for _, q in ipairs(trees) do
					if (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < 36 then
						spaced = false
					end
				end
				if spaced then
					break
				end
			end
			table.insert(trees, { x, z })
			local third = rng.next() < 0.35 and thirds < MAX_THIRD_BRANCHES
			if third then
				thirds += 1
			end
			Builder.tree(ctx, wood, rng, ("Tree%d_%d"):format(c, t), V(x, Builder.surface(hills, x, z), z), third)
		end
	end
end

-- A simplified dead tree (3-4 parts): a trunk 12-30 tall leaning 0-12° (sunk 0.5 into the ground), and 2 or 3
-- branches leaving it 40-75% of the way up at 40-70° from vertical, reaching 20-35% of its height.
function Builder.tree(ctx, wood, rng, name, base, third)
	local BK, S = ctx.BK, ctx.Structure
	local height = rng.next(12, 30)
	local lean, leanAz = RAD(rng.next(0, 12)), rng.next(0, TAU)
	local leanDir = V(math.cos(leanAz), 0, math.sin(leanAz))
	local frame = CFrame.new(base - V(0, 0.5, 0)) * CFrame.fromAxisAngle(Vector3.yAxis:Cross(leanDir), lean)
	local diameter = 0.8 + height * 0.05
	local length = height + 0.5
	local trunk = with(wood, name .. "_Trunk", V(diameter, length, diameter), frame * CFrame.new(0, length / 2, 0))
	trunk.Axis = "Y"
	BK.cyl(S, trunk)

	local branches = if third then 3 else 2
	local az0 = rng.next(0, TAU)
	for b = 1, branches do
		local at = 0.5 + rng.next(0.4, 0.75) * height
		local az = az0 + (b - 1) * TAU / branches + rng.next(-0.4, 0.4)
		local tilt = RAD(rng.next(40, 70))
		local dir = V(math.sin(tilt) * math.cos(az), math.cos(tilt), math.sin(tilt) * math.sin(az))
		local reach = height * rng.next(0.2, 0.35)
		local start = frame * V(0, at, 0)
		local thickness = diameter * 0.45
		local branch = with(wood, ("%s_Branch%d"):format(name, b), V(thickness, thickness, reach), BK.lookAlong(start + dir * reach / 2, dir))
		branch.Axis = "Z"
		BK.cyl(S, branch)
	end
end

-- The ruined city: 18 broken tower blocks, one per cell of a 3 x 6 grid over X 1400..1900, Z -600..400.
-- Footprints 30-60, heights 40-140; the six towers in cells where (column + row) % 3 == 0 tilt 5-15° in a random
-- direction. Every tower (its lean included) stays inside its cell, clear of the Titan and the gate's view of it;
-- after 30 failed tries a tower is drawn small and upright.
function Builder.ruins(ctx, style)
	local BK, P = ctx.BK, ctx.P
	local rng = BK.rng(SEED.ruins)
	local concrete = style(RUIN_COLOR, "Concrete")
	local window = style(P.KICKPLATE, "Concrete")
	local cellX, cellZ = 500 / TOWERS_X, 1000 / TOWERS_Z
	local n = 0
	for i = 1, TOWERS_X do
		for j = 1, TOWERS_Z do
			n += 1
			local x1, z1 = 1400 + (i - 1) * cellX, -600 + (j - 1) * cellZ
			local tower, ok
			for attempt = 1, 60 do
				local small = attempt > 30
				local w = if small then 30 else rng.next(30, 60)
				local d = if small then 30 else rng.next(30, 60)
				local h = rng.next(40, 140)
				local tilt = if (i + j) % 3 == 0 and not small then RAD(rng.next(5, 15)) else 0
				local az = rng.next(0, TAU)
				local reach = math.sqrt(w * w + d * d) / 2 + h * math.sin(tilt) + 2
				local x = rng.next(x1 + reach, x1 + cellX - reach)
				local z = rng.next(z1 + reach, z1 + cellZ - reach)
				tower = { x = x, z = z, w = w, d = d, h = h, tilt = tilt, az = az }
				ok = (V(x, 0, z) - TITAN).Magnitude >= reach + 20 and sightDistance(x, z) >= reach + 8
				if ok then
					break
				end
			end
			if not ok then
				BK.warn(("Wilderness: Tower%d stands in the gate's view of the Titan"):format(n))
			end
			Builder.tower(ctx, concrete, window, rng, "Tower" .. n, tower)
		end
	end
end

-- One tower: the body (sunk so a tilted base never lifts off the ground), a jagged top of 2-3 wedges (each 30-60% of
-- the footprint, 4-14 tall, turned in quarter turns, sunk 1 into the roof and kept 0.5 inside its edges), and 1-4
-- window bands (one per 30 of height) as dark strips 4 tall on the west face, toward the hub.
function Builder.tower(ctx, concrete, window, rng, name, t)
	local BK, S = ctx.BK, ctx.Structure
	local frame = CFrame.new(t.x, 0, t.z)
	local sink = 1
	if t.tilt > 0 then
		local dir = V(math.cos(t.az), 0, math.sin(t.az))
		frame *= CFrame.fromAxisAngle(Vector3.yAxis:Cross(dir), t.tilt)
		sink += math.sqrt(t.w * t.w + t.d * t.d) / 2 * math.tan(t.tilt)
	end
	BK.part(S, with(concrete, name, V(t.w, t.h + sink, t.d), frame * CFrame.new(0, (t.h - sink) / 2, 0)))

	for k = 1, rng.int(2, 3) do
		local ex, ez = t.w * rng.next(0.3, 0.6), t.d * rng.next(0.3, 0.6) -- extents along the tower's X and Z
		local rise = rng.next(4, 14)
		local quarter = rng.int(0, 3)
		local ox = rng.next(-1, 1) * ((t.w - ex) / 2 - 0.5)
		local oz = rng.next(-1, 1) * ((t.d - ez) / 2 - 0.5)
		local size = if quarter % 2 == 1 then V(ez, rise + 1, ex) else V(ex, rise + 1, ez)
		local cf = frame * CFrame.new(ox, t.h - 1 + (rise + 1) / 2, oz) * CFrame.Angles(0, quarter * math.pi / 2, 0)
		BK.wedge(S, with(concrete, ("%s_Top%d"):format(name, k), size, cf))
	end

	local rows = math.clamp(math.floor(t.h / 30), 1, 4)
	for r = 1, rows do
		local y = t.h * (0.12 + 0.68 * (r - 0.5) / rows)
		BK.part(S, with(window, ("%s_Windows%d"):format(name, r), V(0.2, 4, t.d - 6), frame * CFrame.new(-t.w / 2 - 0.05, y, 0)))
	end
end

-- The distant Titan: a static 70-tall figure of exactly 12 dark parts at (1600, 0, -300) facing south (+Z). Lanky:
-- its hands hang to its knees, its neck leans forward. No tags, no scripts: it never moves.
function Builder.titan(ctx, style)
	local BK = ctx.BK
	local model = BK.model(ctx.Structure, "DistantTitan")
	local skin = style(TITAN_COLOR, "SmoothPlastic")
	local base = CFrame.lookAt(TITAN, TITAN + Vector3.zAxis) -- local +X (its right) is west
	local function limb(name, size, cf)
		BK.part(model, with(skin, name, size, cf))
	end
	for _, side in ipairs({ { "R", 1 }, { "L", -1 } }) do
		local s = side[2]
		limb("Shin_" .. side[1], V(4.5, 18.5, 4.5), base * CFrame.new(4.6 * s, 8.75, 0)) -- Y -0.5..18
		limb("Thigh_" .. side[1], V(6, 17.5, 6), base * CFrame.new(4.8 * s, 26.25, 0)) -- Y 17.5..35
		local shoulder = base * CFrame.new(10.9 * s, 53, 0) * CFrame.Angles(0, 0, RAD(5) * s)
		limb("UpperArm_" .. side[1], V(4.2, 18, 4.2), shoulder * CFrame.new(0, -8, 0))
		local elbow = shoulder * CFrame.new(0, -17, 0) * CFrame.Angles(RAD(if s > 0 then 4 else 10), 0, 0)
		limb("Forearm_" .. side[1], V(3.6, 19, 3.6), elbow * CFrame.new(0, -9, 0))
	end
	limb("Pelvis", V(14, 9, 7), base * CFrame.new(0, 37.5, 0)) -- Y 33..42
	limb("Chest", V(17, 14, 8.5), base * CFrame.new(0, 48, 0)) -- Y 41..55
	limb("Neck", V(4, 7, 4), base * CFrame.new(0, 57, -0.8) * CFrame.Angles(RAD(-15), 0, 0))
	limb("Head", V(8, 11, 9), base * CFrame.new(0, 64.5, -1.6)) -- Y 59..70
	model.WorldPivot = base
end

-- Ash drifting east -> west near the Bulwark: one invisible emitter part above the wall (X 430..450, Y 129..131,
-- Z -390..90 round the gate) with the AshFlakes preset at Rate 30 in ASH, emitting from its west (Left) face, the
-- preset's eastward drift turned west.
function Builder.ash(ctx, style)
	local BK, P = ctx.BK, ctx.P
	local props = style(P.ASH, "SmoothPlastic")
	props.Transparency = 1
	local part = BK.box(ctx.Structure, "AshEmitter", V(430, 129, -390), V(450, 131, 90), props)
	local emitter = BK.emitter(part, "AshFlakes")
	emitter.Rate = 30
	emitter.Color = ColorSequence.new(P.ASH)
	emitter.EmissionDirection = Enum.NormalId.Left -- the part is axis-aligned: Left is -X, west
	emitter.Acceleration = V(-2, -1.5, 0)
end

return Builder
