--!nonstrict
-- builders/lib/Props/Outdoor.lua  ->  ServerStorage.DevTools.Props.Outdoor (a child ModuleScript of DevTools.Props)
-- docs/07_building_with_parts.md §6 (recipes), §5 (collision); docs/06_art_direction.md §3-4 (palette, materials);
-- where they go: docs/maps/map_03_outpost_07.md §2 (tufts), §3 (checkpoint sandbags, roadside trees and rocks), §4 (the
-- east breach's debris piles), §5 (courtyard sandbags), §7 (the PipeRack), §9 (mess table sets, Watcher footprints),
-- §11-12 (trail and basin rock clusters, trees, the bleached ones, Strider footprints), §4 / CommMast (the fallen dish).
--
-- The outdoor props of the catalog. init.lua adds them to Props like the other child modules (require(child)(Props, BK)),
-- and builders call them as Props.<Name>(parent, cframe, opts) -> Model (PrimaryPart set):
--   Sandbags, DebrisPile, RockCluster, DeadTree, GrassTuft, FootprintWatcher, FootprintStrider, AntennaDish, PipeRack,
--   MessTableSet.
-- cframe = the prop's bottom-center on the ground, its front toward -Z. A footprint's toes point -Z: turn it along the
-- walking direction with BK.lookAlong(at, heading).
--
-- Collision (docs/07 §5; many of these stand on Frame and Strider routes): the props that are solid by default
-- (Sandbags, DebrisPile, RockCluster, DeadTree's trunk, AntennaDish, PipeRack, MessTableSet's table and benches) take
-- opts.collide = false, which makes every part CanCollide = false and CanQuery = false: decor on a route. A solid group
-- a Frame could walk onto still needs a FrameBarrier box over it (docs/07 §5). GrassTuft and the footprints never
-- collide, answer queries or cast shadows; detail parts (rebar, branches, the dish's hub and feed, trays, food, cups)
-- never collide or answer queries.
-- Randomness only through BK.rng(opts.seed); each seeded prop's default seed is fixed and given at its function.

local V = Vector3.new

return function(Props, BK)
	local P = Props.P
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }
	local quiet = { CanCollide = false, CanQuery = false } -- no collision or queries, but keeps its shadow

	local function with(base, extra)
		local t = table.clone(base)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- k.finish plus opts.collide = false: every part of the model stops colliding and answering queries.
	local function finish(k, primary, opts)
		local model = k.finish(primary)
		if opts.collide == false then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CanQuery = false
				end
			end
		end
		return model
	end

	-- A box of `size` turned by the rotation `rot`: its half-extents along the prop's axes (Vector3), and the radius of
	-- its footprint (the farthest corner from its center, seen from above).
	local function extents(rot, size)
		local x, y, z = rot.XVector, rot.YVector, rot.ZVector
		local h = size / 2
		local e = V(
			math.abs(x.X) * h.X + math.abs(y.X) * h.Y + math.abs(z.X) * h.Z,
			math.abs(x.Y) * h.X + math.abs(y.Y) * h.Y + math.abs(z.Y) * h.Z,
			math.abs(x.Z) * h.X + math.abs(y.Z) * h.Y + math.abs(z.Z) * h.Z
		)
		local radius = 0
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local c = x * (sx * h.X) + y * (sy * h.Y) + z * (sz * h.Z)
					radius = math.max(radius, math.sqrt(c.X * c.X + c.Z * c.Z))
				end
			end
		end
		return e, radius
	end

	-- A seeded shuffle of a copy of `list`.
	local function shuffled(list, rng)
		local t = table.clone(list)
		for i = #t, 2, -1 do
			local j = rng.int(1, i)
			t[i], t[j] = t[j], t[i]
		end
		return t
	end

	---------------------------------------------------------------------------
	-- Sandbags 6 x 2.5 x 2 (17 parts): three rows of "bags", cylinders Ø0.95 lying along X, #8A7B5E Fabric, squashed
	-- 0.18 into the row below. The two lower rows are two bags deep, the top row one bag in their groove; the middle row
	-- is offset half a bag (a half bag at each end), so no joints line up. Solid; opts.collide = false.
	---------------------------------------------------------------------------
	local BAG = 0.95
	local BAG_ROWS = { -- y of the row's axis, the z of its lines, its bags as { x, length }
		{ y = 0.475, lines = { -0.525, 0.525 }, bags = { { -2, 1.94 }, { 0, 1.94 }, { 2, 1.94 } } },
		{ y = 1.25, lines = { -0.525, 0.525 }, bags = { { -2.5, 0.94 }, { -1, 1.94 }, { 1, 1.94 }, { 2.5, 0.94 } } },
		{ y = 2.025, lines = { 0 }, bags = { { -2, 1.94 }, { 0, 1.94 }, { 2, 1.94 } } },
	}

	function Props.Sandbags(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Sandbags", cframe)
		local sack = { Color = "#8A7B5E", Material = "Fabric" }
		local first
		for _, row in ipairs(BAG_ROWS) do
			for _, z in ipairs(row.lines) do
				for _, bag in ipairs(row.bags) do
					local part = k.cyl("Bag", "X", V(bag[2], BAG, BAG), V(bag[1], row.y, z), sack)
					first = first or part
				end
			end
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- Debris pile 8 x 3 x 8 (8-12 parts): 6-10 broken concrete chunks (blocks and wedges in CONCRETE_MID / _DARK / _LIGHT
	-- Concrete, turned at random, tilted up to 25° and sunk into the ground; the two biggest in the middle, the rest in a
	-- ring) and 2 rebar sticks (Ø0.2 RUST CorrodedMetal) poking out at 35-60° from vertical. Everything stays inside
	-- 8 x 3 x 8. opts.seed (default 31). The chunks are solid (opts.collide = false); the rebar never collides.
	---------------------------------------------------------------------------
	local CONCRETES = { P.CONCRETE_MID, P.CONCRETE_MID, P.CONCRETE_DARK, P.CONCRETE_LIGHT }

	function Props.DebrisPile(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 31)
		local k = Props.kit(parent, opts.name or "DebrisPile", cframe)
		local count = rng.int(6, 10)
		local first
		for i = 1, count do
			local big = i <= 2
			local size = if big
				then V(rng.next(2.6, 3.6), rng.next(1.2, 2.0), rng.next(2.2, 3.2))
				else V(rng.next(1.0, 2.4), rng.next(0.5, 1.4), rng.next(0.8, 2.0))
			local rot = CFrame.Angles(0, rng.next(0, 2 * math.pi), 0) * CFrame.Angles(math.rad(rng.next(-25, 25)), 0, math.rad(rng.next(-25, 25)))
			local e = extents(rot, size)
			local angle = i / count * 2 * math.pi + rng.next(-0.4, 0.4)
			local r = if big then rng.next(0, 1) else rng.next(1.4, 3)
			local mx, mz = math.max(0, 4 - e.X), math.max(0, 4 - e.Z)
			local x = math.clamp(r * math.cos(angle), -mx, mx)
			local z = math.clamp(r * math.sin(angle), -mz, mz)
			-- 20-45% of its height below the ground, and never above 3.
			local y = math.min(e.Y * rng.next(0.1, 0.6), 3 - e.Y)
			local style = { Color = rng.pick(CONCRETES), Material = "Concrete" }
			local cf = CFrame.new(x, y, z) * rot
			local chunk = if rng.next() < 0.4 then k.wedge("Chunk", size, cf, style) else k.part("Chunk", size, cf, style)
			first = first or chunk
		end
		local rebar = with({ Color = P.RUST, Material = "CorrodedMetal" }, soft)
		for _ = 1, 2 do
			local yaw = rng.next(0, 2 * math.pi)
			local tilt = math.rad(rng.next(35, 60))
			local base = V(rng.next(-0.9, 0.9), rng.next(0.2, 0.5), rng.next(-0.9, 0.9))
			local dir = V(math.sin(tilt) * math.cos(yaw), math.cos(tilt), math.sin(tilt) * math.sin(yaw))
			local length = math.min(rng.next(2.6, 3.4), (2.9 - base.Y) / dir.Y)
			k.cyl("Rebar", "Z", V(0.2, 0.2, length), BK.lookAlong(base + dir * (length / 2), dir), rebar)
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- Rock cluster, opts.width wide (the recipe's 10-30; default 14) (3-6 parts): Rock-material blocks and wedges in ROCK /
	-- ROCK_DARK, turned at random, tilted up to 18° and sunk 20-45% of their height into the ground; the biggest in the
	-- middle, the others around it. Everything stays inside a circle opts.width across and under 0.45 x width tall (the
	-- biggest rock shows about 0.25-0.4 x width). opts.seed (default 51). Solid; opts.collide = false.
	---------------------------------------------------------------------------
	local ROCKS = { P.ROCK, P.ROCK, P.ROCK_DARK }

	function Props.RockCluster(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 51)
		local w = opts.width or 14
		local k = Props.kit(parent, opts.name or "RockCluster", cframe)
		local count = rng.int(3, 6)
		local first
		for i = 1, count do
			local main = i == 1
			local s = if main then 0.42 * w else rng.next(0.16, 0.3) * w
			local size = if main
				then V(s * rng.next(0.9, 1.15), s * rng.next(0.9, 1.15), s * rng.next(0.8, 1.0))
				else V(s * rng.next(0.9, 1.4), s * rng.next(0.5, 0.9), s * rng.next(0.7, 1.1))
			local rot = CFrame.Angles(0, rng.next(0, 2 * math.pi), 0) * CFrame.Angles(math.rad(rng.next(-18, 18)), 0, math.rad(rng.next(-18, 18)))
			local e, radius = extents(rot, size)
			local room = math.max(0, w / 2 - radius)
			local r = math.min(if main then rng.next(0, 0.06) * w else rng.next(0.25, 0.4) * w, room)
			local angle = (i - 2) / math.max(1, count - 1) * 2 * math.pi + rng.next(-0.5, 0.5)
			local y = math.min(e.Y * rng.next(0.1, 0.6), 0.45 * w - e.Y)
			local style = { Color = rng.pick(ROCKS), Material = "Rock" }
			local cf = CFrame.new(r * math.cos(angle), y, r * math.sin(angle)) * rot
			local rock = if not main and rng.next() < 0.5 then k.wedge("Rock", size, cf, style) else k.part("Rock", size, cf, style)
			first = first or rock
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- Dead tree 4 x 18 x 4 (5-8 parts): a trunk of 2-3 stacked tapering cylinders (Ø1.4 at the foot, 0.2 into the ground,
	-- each leaning up to 3° more) and 3-5 branch cylinders (Ø0.3-0.45, 25-60° from vertical, the upper ones steeper), all
	-- Wood in TREE_DEAD. The branch tips stay inside the 4 x 4 footprint and under the height. opts.height (default 18;
	-- everything scales with it, the footprint is height x 4/18 square), opts.color (the basin's bleached trees:
	-- "#8A8378"), opts.seed (default 61). The trunk is solid (opts.collide = false); the branches never collide or answer
	-- queries but keep their shadows.
	---------------------------------------------------------------------------
	local TRUNKS = {
		[2] = { lengths = { 0.58, 0.42 }, widths = { 1.4, 0.7 } },
		[3] = { lengths = { 0.42, 0.33, 0.25 }, widths = { 1.4, 0.95, 0.55 } },
	}

	-- How far a branch from coordinate p may run along d (one horizontal component) before leaving [-half, half].
	local function roomAlong(p, d, half)
		if d > 1e-6 then
			return (half - p) / d
		elseif d < -1e-6 then
			return (-half - p) / d
		end
		return math.huge
	end

	function Props.DeadTree(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 61)
		local h = opts.height or 18
		local s = h / 18
		local half = 2 * s
		local wood = { Color = opts.color or P.TREE_DEAD, Material = "Wood" }
		local k = Props.kit(parent, opts.name or "DeadTree", cframe)
		local trunkHeight = 0.86 * h
		local overlap = 0.3 * s
		local shape = TRUNKS[rng.int(2, 3)]
		local segments = {}
		local cursor = CFrame.new(0, -0.2 * s, 0)
		local first
		for i, fraction in ipairs(shape.lengths) do
			local last = i == #shape.lengths
			local length = fraction * trunkHeight + (if last then 0.2 * s else overlap)
			cursor = cursor * CFrame.Angles(math.rad(rng.next(-3, 3)), 0, math.rad(rng.next(-3, 3)))
			local d = shape.widths[i] * s
			local part = k.cyl("Trunk" .. i, "Y", V(d, length, d), cursor * CFrame.new(0, length / 2, 0), wood)
			first = first or part
			table.insert(segments, { cf = cursor, length = length, reach = if last then length else length - overlap })
			cursor = cursor * CFrame.new(0, length - overlap, 0)
		end
		local branch = with(wood, quiet)
		local count = rng.int(3, 5)
		for i = 1, count do
			local f = 0.35 + 0.55 * (i - 1) / (count - 1) + rng.next(-0.05, 0.05)
			-- The point on the trunk's axis a fraction f up it.
			local rest, at = f * trunkHeight, nil
			for j, segment in ipairs(segments) do
				if rest <= segment.reach or j == #segments then
					at = segment.cf * CFrame.new(0, math.min(rest, segment.length), 0)
					break
				end
				rest -= segment.reach
			end
			local p = at.Position
			local tilt = math.rad(if f < 0.6 then rng.next(40, 60) else rng.next(25, 40))
			local yaw = i * 2.4 + rng.next(-0.4, 0.4)
			local wanted = rng.next(3, 6) * s
			local d = rng.next(0.3, 0.45) * s
			local margin = 0.75 * d -- the branch's own thickness, so its whole box stays inside
			-- Shortened to stay in the footprint and under the height; turned round if that leaves it too short.
			local dir, length = nil, -math.huge
			for _, turn in ipairs({ 0, math.pi }) do
				local try = V(math.sin(tilt) * math.cos(yaw + turn), math.cos(tilt), math.sin(tilt) * math.sin(yaw + turn))
				local fits = math.min(wanted, roomAlong(p.X, try.X, half - margin), roomAlong(p.Z, try.Z, half - margin), (h - margin - p.Y) / try.Y)
				if fits > length then
					dir, length = try, fits
				end
				if fits >= 2.5 * s then
					break
				end
			end
			length = math.max(length, 0.6 * s)
			k.cyl("Branch" .. i, "Z", V(d, d, length), BK.lookAlong(p + dir * (length / 2), dir), branch)
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- Grass tuft 1.5 x 1 x 1.5 (3 parts): three thin LeafyGrass wedges in GRASS_DEAD fanning out from the middle (each
	-- tall at its outer end), 1.0 / 0.85 / 0.7 tall, 120° apart. Never collides, answers queries or casts shadows.
	---------------------------------------------------------------------------
	local BLADES = { { 0, 1.0 }, { 2.09, 0.85 }, { 4.19, 0.7 } } -- yaw (radians), height

	function Props.GrassTuft(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "GrassTuft", cframe)
		local grass = with({ Color = P.GRASS_DEAD, Material = "LeafyGrass" }, soft)
		local first
		for i, blade in ipairs(BLADES) do
			-- A wedge is tall at its +Z side; turned round, that side faces outward.
			local cf = CFrame.Angles(0, blade[1], 0) * CFrame.new(0, blade[2] / 2, -0.37) * CFrame.Angles(0, math.pi, 0)
			local part = k.wedge("Blade" .. i, V(0.12, blade[2], 0.74), cf, grass)
			first = first or part
		end
		return k.finish(first)
	end

	---------------------------------------------------------------------------
	-- Footprints, Watcher 7 x 0.3 x 14 and Strider 6 x 0.3 x 12 (10 parts each): a recessed darker plate #4D453A whose top
	-- is 0.05 above the ground (the ball of the foot, then the round heel, with the arch's waist between them), 4 toe
	-- pads of the same plate, and pushed-up edge ridges: 0.4-tall MUD_DRY wedges from 0.1 below the ground to 0.3 above
	-- it, their steep side toward the print (both sides, in front of the toes, behind the heel). Mud material. The toes
	-- point -Z; a right foot (big toe at -X) unless opts.left. Never collide, answer queries or cast shadows.
	---------------------------------------------------------------------------
	local TOES = { -- x and z as fractions of the width and the length, diameter as a fraction of the width
		{ -0.30, -0.39, 0.22 },
		{ -0.08, -0.40, 0.19 },
		{ 0.12, -0.385, 0.17 },
		{ 0.30, -0.37, 0.15 },
	}

	local function footprint(parent, cframe, opts, name, w, l)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or name, cframe)
		local mirror = if opts.left then -1 else 1
		local plate = with({ Color = "#4D453A", Material = "Mud" }, soft)
		local ridge = with({ Color = P.MUD_DRY, Material = "Mud" }, soft)
		local t = 0.05
		-- Ball and arch from -0.33 to 0.17 of the length; the heel touches its back edge.
		local sole = k.box("Sole", V(0.76 * w, t, 0.5 * l), V(0, t / 2, -0.08 * l), plate)
		local heel = 0.28 * w
		k.cyl("Heel", "Y", V(2 * heel, t, 2 * heel), V(0, t / 2, 0.17 * l + heel), plate)
		for i, toe in ipairs(TOES) do
			local d = toe[3] * w
			k.cyl("Toe" .. i, "Y", V(d, t, d), V(mirror * toe[1] * w, t / 2, toe[2] * l), plate)
		end
		-- A wedge's steep side is its +Z face: turned to face the print.
		local run = 0.1 * w
		local side = V(0.62 * l, 0.4, run)
		k.wedge("RidgeL", side, CFrame.new(-(0.4 * w + run / 2), 0.1, -0.02 * l) * CFrame.Angles(0, math.pi / 2, 0), ridge)
		k.wedge("RidgeR", side, CFrame.new(0.4 * w + run / 2, 0.1, -0.02 * l) * CFrame.Angles(0, -math.pi / 2, 0), ridge)
		k.wedge("RidgeToe", V(0.8 * w, 0.4, run), CFrame.new(0, 0.1, -l / 2 + run / 2), ridge)
		k.wedge("RidgeHeel", V(0.5 * w, 0.4, run), CFrame.new(0, 0.1, l / 2 - run / 2) * CFrame.Angles(0, math.pi, 0), ridge)
		return k.finish(sole)
	end

	function Props.FootprintWatcher(parent, cframe, opts)
		return footprint(parent, cframe, opts, "FootprintWatcher", 7, 14)
	end

	function Props.FootprintStrider(parent, cframe, opts)
		return footprint(parent, cframe, opts, "FootprintStrider", 6, 12)
	end

	---------------------------------------------------------------------------
	-- AntennaDish Ø10 (14 parts standing, 10 fallen): the dish is 8 wedges in a ring (an octagon 10 across its corners,
	-- 1.2 deep at the rim), a center hub and a feed arm 4 out to the feed, all #B7BCC2 Metal. Standing (the default): the
	-- dish faces -Z raised 30°, its center 6 up on a #B7BCC2 post and pivot over a CONCRETE_DARK footing; about
	-- 9.3 x 10.6 x 6.8 overall. opts.tilt (degrees) builds the fallen dish instead: no mount, lying on its rim with its
	-- face turned `tilt` from straight up toward -Z (0 = flat on its back), sunk 0.2 into the ground, one wedge cracked
	-- out of line, the feed arm snapped short. The dish, post and footing are solid (opts.collide = false); hub, arm and
	-- feed never collide.
	---------------------------------------------------------------------------
	local DISH_R, DISH_DEPTH, DISH_HUB = 5, 1.2, 0.8

	function Props.AntennaDish(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "AntennaDish", cframe)
		local metal = { Color = "#B7BCC2", Material = "Metal" }
		local detail = with(metal, soft)
		local fallen = opts.tilt ~= nil
		local apothem = DISH_R * math.cos(math.pi / 8)
		local chord = 2 * DISH_R * math.sin(math.pi / 8)
		-- The dish's own frame: its face along -Z (LookVector), the ring in its XY plane, the lowest wedge along -Y.
		local dish
		if fallen then
			local t = math.rad(opts.tilt)
			dish = BK.lookAlong(V(0, apothem * math.sin(t) - 0.2, 0), V(0, math.cos(t), -math.sin(t)))
		else
			local e = math.rad(30)
			dish = BK.lookAlong(V(0, 6, 0), V(0, math.sin(e), -math.cos(e)))
		end
		local forward = V(0, 0, -1)
		local first
		for i = 0, 7 do
			local a = i * math.pi / 4
			local out = V(math.cos(a), math.sin(a), 0)
			local tangent = V(-math.sin(a), math.cos(a), 0)
			-- Local Y = the dish's face direction, local Z = outward: the wedge rises from the hub to the rim (concave).
			local cf = CFrame.fromMatrix(out * ((DISH_HUB + apothem) / 2) + forward * (DISH_DEPTH / 2), -tangent, forward)
			if fallen and i == 3 then
				cf = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(math.rad(6), 0, 0) -- the crack: one wedge out of line
			end
			local petal = k.wedge("Petal" .. (i + 1), V(chord, DISH_DEPTH, apothem - DISH_HUB), dish * cf, metal)
			first = first or petal
		end
		k.cyl("Hub", "Z", V(2, 2, 1), dish * CFrame.new(0, 0, -0.3), detail)
		if fallen then
			k.cyl("FeedArm", "Z", V(0.3, 0.3, 1.4), dish * CFrame.new(0, 0, -1.5), detail)
		else
			k.cyl("FeedArm", "Z", V(0.3, 0.3, 3.4), dish * CFrame.new(0, 0, -2.5), detail)
			k.cyl("Feed", "Z", V(0.9, 0.9, 0.9), dish * CFrame.new(0, 0, -4.4), detail)
			local pivot = (dish * CFrame.new(0, 0, 0.9)).Position
			k.box("Footing", V(3, 0.6, 3), V(0, 0.3, pivot.Z), { Color = P.CONCRETE_DARK, Material = "Concrete" })
			local postTop = pivot.Y - 0.3
			k.cyl("Post", "Y", V(1.2, postTop - 0.6, 1.2), V(0, (postTop + 0.6) / 2, pivot.Z), metal)
			k.part("Pivot", V(1.6, 1.0, 1.2), dish * CFrame.new(0, 0, 0.9), detail)
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- PipeRack 20 x 10 x 4 (12 parts): 3 parallel pipes Ø1.2 along X, side by side, on 3 H-frame supports at X -8, 0, 8
	-- (STEEL_DARK Metal: two 10-tall posts and a crossbar at 8.6 between them that the pipes lie on; the pipes' tops at
	-- 10). Pipes STEEL_MID Metal, or RUST CorrodedMetal with opts.rust. Solid; opts.collide = false.
	---------------------------------------------------------------------------
	function Props.PipeRack(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "PipeRack", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local pipe = if opts.rust then { Color = P.RUST, Material = "CorrodedMetal" } else { Color = P.STEEL_MID, Material = "Metal" }
		local first
		for _, x in ipairs({ -8, 0, 8 }) do
			for _, z in ipairs({ -1.85, 1.85 }) do
				local post = k.box("Post", V(0.5, 10, 0.3), V(x, 5, z), steel)
				first = first or post
			end
			k.box("Crossbar", V(0.5, 0.4, 3.4), V(x, 8.6, 0), steel)
		end
		for i, z in ipairs({ -1.2, 0, 1.2 }) do
			k.cyl("Pipe" .. i, "X", V(20, 1.2, 1.2), V(0, 9.4, z), pipe)
		end
		return finish(k, first, opts)
	end

	---------------------------------------------------------------------------
	-- Mess table set 10 x 2.8 x 3 (16-23 parts): a table (a STEEL_MID Metal top 10 x 1.4, its surface at opts.top, default
	-- 2.8, on two STEEL_DARK end legs) between two benches along its long sides (10 x 0.7 STEEL_MID seats, tops at 1.6,
	-- each on two legs); 2-4 STEEL_LIGHT trays (thin parts) left mid-meal with two small blocks of "food" each; 1-2 SLATE
	-- cups. The middle of the top (|x| < 0.85) stays clear for a datapad or a clipboard. opts.seed (default 71),
	-- opts.trays (0-4; default 2-4 from the seed). Table and benches are solid (opts.collide = false); trays, food and cups
	-- never collide.
	---------------------------------------------------------------------------
	local FOOD = { P.RUST_DARK, P.RUST, P.WOOD_OLD, P.ASH, P.GRASS_SPARSE, P.AMBER_LAMP }
	local TRAY_SLOTS = { { -3.6, -0.33 }, { 1.5, -0.33 }, { -1.5, 0.33 }, { 3.6, 0.33 } }
	local CUP_SLOTS = { { -2.6, 0.35 }, { 2.6, -0.35 }, { 4.6, -0.35 }, { -4.6, 0.35 } }

	function Props.MessTableSet(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 71)
		local top = opts.top or 2.8
		local k = Props.kit(parent, opts.name or "MessTableSet", cframe)
		local metal = { Color = P.STEEL_MID, Material = "Metal" }
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local board = k.box("Top", V(10, 0.2, 1.4), V(0, top - 0.1, 0), metal)
		for _, x in ipairs({ -4.3, 4.3 }) do
			k.box("Leg", V(0.3, top - 0.2, 1.0), V(x, (top - 0.2) / 2, 0), steel)
			for _, z in ipairs({ -1.15, 1.15 }) do
				k.box("BenchLeg", V(0.3, 1.4, 0.4), V(x, 0.7, z), steel)
			end
		end
		for i, z in ipairs({ -1.15, 1.15 }) do
			k.box("Bench" .. i, V(10, 0.2, 0.7), V(0, 1.5, z), metal)
		end
		local trayStyle = with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft)
		local slots = shuffled(TRAY_SLOTS, rng)
		local trays = math.clamp(opts.trays or rng.int(2, 4), 0, 4)
		for i = 1, trays do
			local x, z = slots[i][1], slots[i][2]
			k.box("Tray" .. i, V(1.3, 0.08, 0.7), V(x, top + 0.04, z), trayStyle)
			local main = V(rng.next(0.35, 0.5), rng.next(0.12, 0.2), rng.next(0.3, 0.4))
			k.box("Food" .. i .. "_Main", main, V(x - 0.25, top + 0.08 + main.Y / 2, z + rng.next(-0.08, 0.08)), with({ Color = rng.pick(FOOD) }, soft))
			local side = V(rng.next(0.22, 0.32), rng.next(0.08, 0.16), rng.next(0.2, 0.28))
			k.box("Food" .. i .. "_Side", side, V(x + 0.3, top + 0.08 + side.Y / 2, z + rng.next(-0.1, 0.1)), with({ Color = rng.pick(FOOD) }, soft))
		end
		local cups = shuffled(CUP_SLOTS, rng)
		for i = 1, rng.int(1, 2) do
			k.cyl("Cup" .. i, "Y", V(0.34, 0.44, 0.34), V(cups[i][1], top + 0.22, cups[i][2]), with({ Color = P.SLATE }, soft))
		end
		return finish(k, board, opts)
	end
end
