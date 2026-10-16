--!nonstrict
-- BuildKit/Structure: spec-friendly architecture builders. Coordinates come straight from the map docs
-- (wall centerlines, ground floor top at Y 0). API reference: docs/07_building_with_parts.md section 3.
--
-- Placement convention for BK.window and BK.door: `cframe` is the BOTTOM-CENTER of the element on the
-- wall centerline, and the element faces -Z (its LookVector), like every prop in docs/07 section 6.

return function(BK)
	local P = BK.Palette

	-- Dimensions the docs leave open (docs/tracking/decisions.md D-011). Tune here, then rebuild.
	local EPS = 0.001
	local TRIM_WIDTH = 0.4 -- door-frame trim width (docs/07 section 3)
	local TRIM_PROUD = 0.1 -- the trim stands this far out of each wall face
	local RAMP_THICKNESS = 1
	local RAIL_THICKNESS = 0.3
	local COLLIDER_THICKNESS = 0.4
	local STRINGER_WIDTH = 0.4
	local STRINGER_DEPTH = 0.8
	local COLUMN_FLARE = 0.5 -- base and capital overhang per side
	local COLUMN_CAP_HEIGHT = 1
	local WINDOW_FRAME = 0.4
	local WINDOW_DEPTH = 0.6
	local GLASS_THICKNESS = 0.2
	local GLASS_TRANSPARENCY = 0.55 -- docs/06 section 3 (GLASS)
	local DOOR_LEAF_THICKNESS = 0.4

	local function order(a, b)
		if a <= b then
			return a, b
		end
		return b, a
	end

	---------------------------------------------------------------------------
	-- Boxes, floors, ceilings, walls
	---------------------------------------------------------------------------
	function BK.box(parent, name, min, max, props)
		local x1, x2 = order(min.X, max.X)
		local y1, y2 = order(min.Y, max.Y)
		local z1, z2 = order(min.Z, max.Z)
		local size = Vector3.new(x2 - x1, y2 - y1, z2 - z1)
		if size.X < EPS or size.Y < EPS or size.Z < EPS then
			error(("[BuildKit] BK.box '%s' has a zero dimension: %s"):format(tostring(name), tostring(size)), 2)
		end
		local p = if props then table.clone(props) else {}
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
		p.Position = nil
		p.Orientation = nil
		return BK.part(parent, p)
	end

	function BK.floor(parent, name, x1, x2, z1, z2, yTop, thickness, props)
		return BK.box(parent, name, Vector3.new(x1, yTop - thickness, z1), Vector3.new(x2, yTop, z2), props)
	end

	function BK.ceiling(parent, name, x1, x2, z1, z2, yBottom, thickness, props)
		return BK.box(parent, name, Vector3.new(x1, yBottom, z1), Vector3.new(x2, yBottom + thickness, z2), props)
	end

	function BK.wallX(parent, name, x1, x2, zCenter, y1, y2, thickness, props)
		local half = thickness / 2
		return BK.box(parent, name, Vector3.new(x1, y1, zCenter - half), Vector3.new(x2, y2, zCenter + half), props)
	end

	function BK.wallZ(parent, name, z1, z2, xCenter, y1, y2, thickness, props)
		local half = thickness / 2
		return BK.box(parent, name, Vector3.new(xCenter - half, y1, z1), Vector3.new(xCenter + half, y2, z2), props)
	end

	-- A wall split around openings {from, to, y1, y2} (from/to along the wall's axis, world coordinates).
	-- Each opening gets a 0.4-stud STEEL_DARK frame. The frame REPLACES wall material around the opening, so
	-- the clear opening keeps exactly the size given. props.Trim = false (or opening.trim = false) skips it;
	-- props.TrimColor overrides the color. The model gets attributes Openings, Axis, Opening<i>_Span/_Y.
	function BK.wallWithOpenings(parent, name, axis, a1, a2, center, y1, y2, thickness, openings, props)
		if axis ~= "X" and axis ~= "Z" then
			error("[BuildKit] BK.wallWithOpenings: axis must be 'X' or 'Z'", 2)
		end
		a1, a2 = order(a1, a2)
		y1, y2 = order(y1, y2)

		local wallProps = if props then table.clone(props) else {}
		local trimEnabled = wallProps.Trim ~= false
		local trimProps = { Color = wallProps.TrimColor or P.STEEL_DARK, Material = Enum.Material.Metal }
		wallProps.Trim = nil
		wallProps.TrimColor = nil

		local model = BK.model(parent, name)

		local function slab(partName, from, to, yFrom, yTo, depth, slabProps)
			if to - from < EPS or yTo - yFrom < EPS then
				return nil
			end
			local half = depth / 2
			if axis == "X" then
				return BK.box(model, partName, Vector3.new(from, yFrom, center - half), Vector3.new(to, yTo, center + half), slabProps)
			end
			return BK.box(model, partName, Vector3.new(center - half, yFrom, from), Vector3.new(center + half, yTo, to), slabProps)
		end

		local holes = {}
		for _, opening in ipairs(openings or {}) do
			local from, to = order(opening.from, opening.to)
			local oy1, oy2 = order(opening.y1, opening.y2)
			from, to = math.max(from, a1), math.min(to, a2)
			oy1, oy2 = math.max(oy1, y1), math.min(oy2, y2)
			if to - from > EPS and oy2 - oy1 > EPS then
				table.insert(holes, { from = from, to = to, y1 = oy1, y2 = oy2, trim = trimEnabled and opening.trim ~= false })
			end
		end
		table.sort(holes, function(l, r)
			return l.from < r.from
		end)

		local trimDepth = thickness + 2 * TRIM_PROUD
		local cursor = a1
		local segments = 0
		for i, hole in ipairs(holes) do
			if hole.from < cursor - EPS then
				error(("[BuildKit] BK.wallWithOpenings '%s': openings overlap or sit closer than the trim near %.2f"):format(name, hole.from), 2)
			end
			local t = if hole.trim then TRIM_WIDTH else 0
			local left = math.max(cursor, hole.from - t)
			local right = math.min(a2, hole.to + t)
			local headTop = math.min(y2, hole.y2 + t)
			local sillBottom = math.max(y1, hole.y1 - t)

			if left - cursor > EPS then
				segments += 1
				slab(("%s_Seg%d"):format(name, segments), cursor, left, y1, y2, thickness, wallProps)
			end
			slab(("%s_Lintel%d"):format(name, i), left, right, headTop, y2, thickness, wallProps)
			slab(("%s_Sill%d"):format(name, i), left, right, y1, sillBottom, thickness, wallProps)
			if hole.trim then
				-- Jambs take the corners; head and sill sit between them.
				slab(("%s_Trim%d_L"):format(name, i), left, hole.from, sillBottom, headTop, trimDepth, trimProps)
				slab(("%s_Trim%d_R"):format(name, i), hole.to, right, sillBottom, headTop, trimDepth, trimProps)
				slab(("%s_Trim%d_Head"):format(name, i), hole.from, hole.to, hole.y2, headTop, trimDepth, trimProps)
				slab(("%s_Trim%d_Sill"):format(name, i), hole.from, hole.to, sillBottom, hole.y1, trimDepth, trimProps)
			end
			model:SetAttribute(("Opening%d_Span"):format(i), Vector2.new(hole.from, hole.to))
			model:SetAttribute(("Opening%d_Y"):format(i), Vector2.new(hole.y1, hole.y2))
			cursor = right
		end
		if a2 - cursor > EPS then
			segments += 1
			slab(("%s_Seg%d"):format(name, segments), cursor, a2, y1, y2, thickness, wallProps)
		end

		model:SetAttribute("Openings", #holes)
		model:SetAttribute("Axis", axis)
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		return model
	end

	---------------------------------------------------------------------------
	-- Railings and stairs
	---------------------------------------------------------------------------
	-- A railing along a polyline of base points: top rail, mid rail, posts, and one invisible collider
	-- panel per segment (the visible bars never collide, so characters slide along cleanly).
	-- Extra opts: sink (posts and collider reach this far below the base points), collide (default true).
	function BK.railing(parent, name, points, opts)
		opts = opts or {}
		local height = opts.height or 3.5
		local postSpacing = opts.postSpacing or 5
		local color = opts.color or P.STEEL_DARK
		local sink = opts.sink or 0
		local collide = opts.collide ~= false
		if #points < 2 then
			error("[BuildKit] BK.railing needs at least 2 points", 2)
		end

		local model = BK.model(parent, name)
		local up = Vector3.yAxis
		local bar = { Color = color, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }
		local posts = 0
		local started = false

		local function post(position, direction)
			posts += 1
			local center = position + up * ((height - sink) / 2)
			local flat = Vector3.new(direction.X, 0, direction.Z)
			BK.part(model, {
				Name = ("%s_Post%02d"):format(name, posts),
				Size = Vector3.new(RAIL_THICKNESS, height + sink, RAIL_THICKNESS),
				CFrame = if flat.Magnitude > EPS then BK.lookAlong(center, flat) else CFrame.new(center),
				Color = color,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
			})
		end

		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			if length > EPS then
				local top = up * (height - RAIL_THICKNESS / 2)
				BK.beam(model, ("%s_Top%d"):format(name, i), a + top, b + top, RAIL_THICKNESS, RAIL_THICKNESS, bar)
				local mid = up * (height / 2)
				BK.beam(model, ("%s_Mid%d"):format(name, i), a + mid, b + mid, RAIL_THICKNESS * 0.66, RAIL_THICKNESS * 0.66, bar)

				local spans = math.max(1, math.ceil(length / postSpacing - EPS))
				for j = (if started then 1 else 0), spans do
					post(a + delta * (j / spans), delta)
				end
				started = true

				if collide then
					local center = up * ((height - sink) / 2)
					BK.beam(model, ("%s_Collider%d"):format(name, i), a + center, b + center, COLLIDER_THICKNESS, height + sink, {
						Transparency = 1,
						CastShadow = false,
						Tags = { "NoCollideCamera" },
					})
				end
			end
		end

		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		return model
	end

	-- Stairs. bottomFrontCenter is the floor point at the foot of the first riser; dir is the horizontal
	-- unit vector pointing uphill. The top of the last step is level with the upper floor.
	-- The invisible ramp collider runs through every step nosing; it starts on the floor one tread before the
	-- first riser, so walking up and down is smooth.
	function BK.stairs(parent, name, bottomFrontCenter, dir, width, totalRise, opts)
		opts = opts or {}
		local stepRise = opts.stepRise or 1
		local stepRun = opts.stepRun or 1.5
		local wantRailings = opts.railings ~= false
		local wantStringers = opts.stringers ~= false
		local material = opts.material or Enum.Material.DiamondPlate
		local color = opts.color or P.STEEL_MID

		if math.abs(dir.Y) > EPS or math.abs(dir.Magnitude - 1) > 0.01 then
			error("[BuildKit] BK.stairs: dir must be a horizontal unit vector", 2)
		end
		local steps = math.floor(totalRise / stepRise + 0.5)
		if steps < 1 or math.abs(steps * stepRise - totalRise) > EPS then
			error("[BuildKit] BK.stairs: totalRise must be a positive multiple of stepRise", 2)
		end

		local model = BK.model(parent, name)
		BK.attr(model, { Steps = steps, StepRise = stepRise, StepRun = stepRun })

		-- Local frame: origin at the foot of the first riser, -Z uphill, +X to the right when looking uphill.
		local base = CFrame.lookAt(bottomFrontCenter, bottomFrontCenter + dir)
		local function at(x, h, run)
			return base * CFrame.new(x, h, -run)
		end
		local function point(x, h, run)
			return at(x, h, run).Position
		end

		local firstStep
		for i = 1, steps do
			local step = BK.part(model, {
				Name = ("%s_Step%02d"):format(name, i),
				Size = Vector3.new(width, stepRise, stepRun),
				CFrame = at(0, (i - 0.5) * stepRise, (i - 0.5) * stepRun),
				Color = color,
				Material = material,
			})
			firstStep = firstStep or step
		end

		local totalRun = steps * stepRun
		local slope = math.atan2(stepRise, stepRun)

		BK.part(model, {
			Name = name .. "_RampCollider",
			Size = Vector3.new(width, RAMP_THICKNESS, math.sqrt(totalRun ^ 2 + totalRise ^ 2)),
			CFrame = at(0, totalRise / 2, (steps - 2) * stepRun / 2) * CFrame.Angles(slope, 0, 0) * CFrame.new(0, -RAMP_THICKNESS / 2, 0),
			Transparency = 1,
			CastShadow = false,
			Tags = { "NoCollideCamera" },
		})

		if wantStringers and steps >= 2 then
			-- Two beams under the treads; their top faces touch the back-bottom edge of every step.
			local dropH = math.cos(slope) * STRINGER_DEPTH / 2
			local pushRun = math.sin(slope) * STRINGER_DEPTH / 2
			local inset = math.min(0.6, width / 4)
			for _, side in ipairs({ { "L", -1 }, { "R", 1 } }) do
				local x = side[2] * (width / 2 - inset)
				BK.beam(
					model,
					("%s_Stringer%s"):format(name, side[1]),
					point(x, -dropH, stepRun + pushRun),
					point(x, totalRise - stepRise - dropH, totalRun + pushRun),
					STRINGER_WIDTH,
					STRINGER_DEPTH,
					{ Color = P.STEEL_DARK, Material = Enum.Material.Metal }
				)
			end
		end

		if wantRailings then
			for _, side in ipairs({ { "L", -1 }, { "R", 1 } }) do
				local x = side[2] * (width / 2 - RAIL_THICKNESS / 2)
				BK.railing(model, ("%s_Rail%s"):format(name, side[1]), {
					point(x, stepRise, 0),
					point(x, totalRise, (steps - 1) * stepRun),
					point(x, totalRise, totalRun),
				}, { sink = stepRise })
			end
		end

		model.PrimaryPart = firstStep
		return model
	end

	---------------------------------------------------------------------------
	-- Columns, windows, doors
	---------------------------------------------------------------------------
	-- A square column. `height` is the total height including base and capital. Extra opts: material.
	function BK.column(parent, name, baseCenter, height, width, opts)
		opts = opts or {}
		local hasBase = opts.base ~= false
		local hasCapital = opts.capital ~= false
		local props = { Color = opts.color or P.CONCRETE_LIGHT, Material = opts.material or Enum.Material.Concrete }
		local model = BK.model(parent, name)
		local x, y, z = baseCenter.X, baseCenter.Y, baseCenter.Z

		local function block(partName, yFrom, yTo, w)
			return BK.box(model, partName, Vector3.new(x - w / 2, yFrom, z - w / 2), Vector3.new(x + w / 2, yTo, z + w / 2), props)
		end

		local shaftBottom = y + (if hasBase then COLUMN_CAP_HEIGHT else 0)
		local shaftTop = y + height - (if hasCapital then COLUMN_CAP_HEIGHT else 0)
		local shaft = block(name .. "_Shaft", shaftBottom, shaftTop, width)
		if hasBase then
			block(name .. "_Base", y, shaftBottom, width + 2 * COLUMN_FLARE)
		end
		if hasCapital then
			block(name .. "_Capital", shaftTop, y + height, width + 2 * COLUMN_FLARE)
		end
		model.PrimaryPart = shaft
		return model
	end

	-- A framed glass window that fills a width x height opening. Extra opts: depth (frame depth).
	function BK.window(parent, name, cframe, width, height, opts)
		opts = opts or {}
		local mullions = opts.mullions or 2
		local depth = opts.depth or WINDOW_DEPTH
		local frame = WINDOW_FRAME
		local innerW, innerH = width - 2 * frame, height - 2 * frame
		if innerW < EPS or innerH < EPS then
			error(("[BuildKit] BK.window '%s' is too small for its %.1f-stud frame"):format(tostring(name), frame), 2)
		end
		local frameProps = { Color = opts.frameColor or P.STEEL_DARK, Material = Enum.Material.Metal }
		local model = BK.model(parent, name)

		local function bar(partName, x, y, sx, sy, sz, props)
			local p = table.clone(props)
			p.Name = partName
			p.Size = Vector3.new(sx, sy, sz)
			p.CFrame = cframe * CFrame.new(x, y, 0)
			return BK.part(model, p)
		end

		bar(name .. "_FrameL", -(width - frame) / 2, height / 2, frame, height, depth, frameProps)
		bar(name .. "_FrameR", (width - frame) / 2, height / 2, frame, height, depth, frameProps)
		bar(name .. "_FrameTop", 0, height - frame / 2, innerW, frame, depth, frameProps)
		bar(name .. "_FrameBottom", 0, frame / 2, innerW, frame, depth, frameProps)
		local glass = bar(name .. "_Glass", 0, height / 2, innerW, innerH, GLASS_THICKNESS, {
			Color = P.GLASS,
			Material = Enum.Material.Glass,
			Transparency = GLASS_TRANSPARENCY,
			CastShadow = false,
		})
		for i = 1, mullions do
			bar(("%s_Mullion%d"):format(name, i), -innerW / 2 + innerW * i / (mullions + 1), height / 2, 0.2, innerH, depth * 0.7, frameProps)
		end

		model.PrimaryPart = glass
		return model
	end

	-- A door for a width x height doorway: leaf (or two), a Neon status strip above the frame on both wall
	-- faces (amber = open, drawn with BK.GLOW.amber; DANGER_RED = locked; docs/maps/map_01 section 2) and an
	-- optional sign.
	-- Extra opts: leaf = false (open passage: strips and sign only), locked, wallThickness (default 1).
	-- The model is tagged "Door" and carries attributes Locked, Width, Height.
	function BK.door(parent, name, cframe, width, height, opts)
		opts = opts or {}
		local double = opts.double == true
		local locked = opts.locked == true
		local wallThickness = opts.wallThickness or 1
		local color = opts.color or P.STEEL_MID
		local model = BK.model(parent, name)
		BK.tag(model, "Door")
		BK.attr(model, { Locked = locked, Width = width, Height = height })

		local firstLeaf
		if opts.leaf ~= false then
			local function leaf(partName, x, w)
				local part = BK.part(model, {
					Name = partName,
					Size = Vector3.new(w, height, DOOR_LEAF_THICKNESS),
					CFrame = cframe * CFrame.new(x, height / 2, 0),
					Color = color,
					Material = Enum.Material.Metal,
				})
				firstLeaf = firstLeaf or part
			end
			local function handle(partName, x)
				BK.part(model, {
					Name = partName,
					Size = Vector3.new(0.2, 1.2, DOOR_LEAF_THICKNESS + 0.4),
					CFrame = cframe * CFrame.new(x, 3.4, 0),
					Color = P.STEEL_LIGHT,
					Material = Enum.Material.Metal,
					CanCollide = false,
					CanQuery = false,
				})
			end
			if double then
				local leafWidth = width / 2 - 0.05
				leaf(name .. "_LeafL", -(width / 4 + 0.025), leafWidth)
				leaf(name .. "_LeafR", width / 4 + 0.025, leafWidth)
				handle(name .. "_HandleL", -0.5)
				handle(name .. "_HandleR", 0.5)
			else
				leaf(name .. "_Leaf", 0, width)
				handle(name .. "_Handle", width / 2 - 0.6)
			end
		end

		local stripY = height + TRIM_WIDTH + 0.35
		local faceZ = wallThickness / 2 + 0.05
		for _, side in ipairs({ { "F", -faceZ }, { "B", faceZ } }) do
			BK.part(model, {
				Name = ("%s_StatusStrip_%s"):format(name, side[1]),
				Size = Vector3.new(math.max(width - 1, 1), 0.3, 0.1),
				CFrame = cframe * CFrame.new(0, stripY, side[2]),
				Color = if locked then P.DANGER_RED else BK.GLOW.amber.Color,
				Transparency = if locked then 0 else BK.GLOW.amber.Transparency,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
		end

		if opts.sign then
			local signCFrame = cframe * CFrame.new(0, height + TRIM_WIDTH + 1.6, -(wallThickness / 2 + 0.06))
			BK.sign(model, name .. "_Sign", signCFrame, Vector2.new(math.max(width + 2, 6), 1.2), opts.sign)
		end

		model.PrimaryPart = firstLeaf or model:FindFirstChildWhichIsA("BasePart")
		return model
	end
end
