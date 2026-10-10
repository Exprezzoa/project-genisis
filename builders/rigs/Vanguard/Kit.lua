--!nonstrict
-- builders/rigs/Vanguard/Kit.lua  ->  ServerStorage.DevTools.Builders.Rigs.Vanguard.Kit
-- The shape vocabulary of the Vanguard's detail pass (docs/09 §2 "Form language", D-041): rounded armor
-- (ellipsoids), tubes and capsules, smooth ridges that follow an ellipsoid, hoses, pistons, rivets, and beams
-- for the cables that cross a joint.
--
--   local K = Kit.new(BK, model)
--
-- Every helper takes the main part a detail hangs on and coordinates relative to that part's center
-- (model space: front = -Z, +X = the rig's right). Every detail is welded to its main part.

local Kit = {}

local V = Vector3.new
local rad = math.rad

function Kit.new(BK, model)
	local P = BK.Palette
	local K = {}
	-- The CFrame each part was asked for. A cylinder with an Axis is turned by BuildKit, so offsets of things
	-- attached to it are measured from this logical frame, not from the part's own CFrame.
	local frames = {}
	K.frames = frames

	-- Curved armor is SmoothPlastic: a round Metal surface mirrors the sky and ground and reads as black
	-- instead of its armor color (seen in the first build, D-041). Flat plates and dark steel stay Metal.
	local PAINTED = { [P.VG_ARMOR] = true, [P.VG_ARMOR_DARK] = true, [P.VG_PRIMER] = true }

	-- A rig part: unanchored, massless, never collides or answers queries (docs/08 §2.3 and §2.5). Only parts
	-- that are thick in two directions cast a shadow: wires and rivets don't.
	function K.raw(kind, parent, name, size, cframe, color, material, extra)
		local a, b, c = size.X, size.Y, size.Z
		local middle = a + b + c - math.max(a, b, c) - math.min(a, b, c)
		local round = kind == "cyl" or kind == "ball" or (extra and extra.Round)
		if extra and extra.Round then
			extra = table.clone(extra)
			extra.Round = nil
		end
		local props = {
			Name = name, Size = size, CFrame = cframe, Color = color or P.VG_FRAME,
			Material = material or (if round and PAINTED[color] then "SmoothPlastic" else "Metal"),
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
			CastShadow = middle > 1.2,
		}
		for key, value in pairs(extra or {}) do
			props[key] = value
		end
		local part = BK[kind](parent, props)
		frames[part] = cframe
		return part
	end

	-- A detail welded to a main part. at = Vector3 or CFrame relative to the main part's center.
	function K.add(on, kind, name, size, at, color, material, extra)
		local offset = if typeof(at) == "Vector3" then CFrame.new(at) else at
		local part = K.raw(kind, on, name, size, frames[on] * offset, color, material, extra)
		BK.weld(on, part)
		return part
	end

	function K.box(on, name, size, at, color, material, extra)
		return K.add(on, "part", name, size, at, color, material, extra)
	end

	function K.ball(on, name, diameter, at, color, material, extra)
		return K.add(on, "ball", name, V(diameter, diameter, diameter), at, color, material, extra)
	end

	-- An ellipsoid that fills `size`: a block with the engine's built-in sphere mesh (no asset).
	function K.egg(on, name, size, at, color, material, extra)
		extra = if extra then table.clone(extra) else {}
		extra.Round = true
		local part = K.add(on, "part", name, size, at, color, material, extra)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end

	-- A cylinder from point a to point b.
	function K.tube(on, name, a, b, diameter, color, material, extra)
		local delta = b - a
		local x = delta.Unit
		local reference = if math.abs(x.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local z = x:Cross(reference).Unit
		local y = z:Cross(x)
		local cframe = frames[on] * CFrame.fromMatrix((a + b) / 2, x, y, z)
		local part = K.raw("cyl", on, name, V(delta.Magnitude, diameter, diameter), cframe, color, material, extra)
		BK.weld(on, part)
		return part
	end

	local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

	-- A disc or collar: a short cylinder around `axis` ("X" | "Y" | "Z" or a unit vector) centered on `at`.
	function K.ring(on, name, at, axis, diameter, thickness, color, material, extra)
		local direction = AXES[axis] or axis
		return K.tube(on, name, at - direction * thickness / 2, at + direction * thickness / 2, diameter, color, material, extra)
	end

	-- A tube with rounded ends.
	function K.capsule(on, name, a, b, diameter, color, material, extra)
		K.ball(on, name .. "End", diameter, a, color, material, extra)
		K.ball(on, name .. "End", diameter, b, color, material, extra)
		return K.tube(on, name, a, b, diameter, color, material, extra)
	end

	-- A run of tubes through `points`, with a ball in every bend so the run reads as one bent rod.
	-- opts.caps rounds the two ends as well; opts.noJoints leaves the balls out (hair-thin wires).
	function K.poly(on, name, points, diameter, color, material, opts)
		opts = opts or {}
		for index = 1, #points - 1 do
			K.tube(on, name, points[index], points[index + 1], diameter, color, material, opts.extra)
		end
		if not opts.noJoints then
			local first, last = if opts.caps then 1 else 2, if opts.caps then #points else #points - 1
			for index = first, last do
				K.ball(on, name .. "Bend", diameter, points[index], color, material, opts.extra)
			end
		end
	end

	-- Points along a Bezier curve through 2, 3 or 4 control points.
	function K.bezier(control, segments)
		local points = {}
		for index = 0, segments do
			local t = index / segments
			local level = table.clone(control)
			while #level > 1 do
				local nextLevel = {}
				for i = 1, #level - 1 do
					nextLevel[i] = level[i]:Lerp(level[i + 1], t)
				end
				level = nextLevel
			end
			points[index + 1] = level[1]
		end
		return points
	end

	-- A hose or wire along a Bezier curve. Thin wires get no balls in their bends: the gaps are too small to see.
	function K.hose(on, name, control, diameter, color, segments, material, opts)
		opts = opts or (if diameter < 0.35 then { noJoints = true } else nil)
		K.poly(on, name, K.bezier(control, segments or 6), diameter, color or P.HAZARD_BLACK, material or "SmoothPlastic", opts)
	end

	-- Points on the surface of an ellipsoid (center, radii), along the section in `plane`:
	--   "YZ": 0 deg = front, 90 = top, 180 = back      "XZ": 0 = front, 90 = the +X side, 180 = back
	--   "XY": 0 = the +X side, 90 = top
	-- `offset` slides the section along the plane's normal (the section shrinks as it leaves the middle).
	function K.eggLine(center, radii, plane, from, to, segments, offset)
		offset = offset or 0
		local points = {}
		for index = 0, segments do
			local angle = rad(from + (to - from) * index / segments)
			local s, c = math.sin(angle), math.cos(angle)
			local point
			if plane == "YZ" then
				local k = math.sqrt(math.max(0, 1 - (offset / radii.X) ^ 2))
				point = V(offset, radii.Y * s * k, -radii.Z * c * k)
			elseif plane == "XZ" then
				local k = math.sqrt(math.max(0, 1 - (offset / radii.Y) ^ 2))
				point = V(radii.X * s * k, offset, -radii.Z * c * k)
			else
				local k = math.sqrt(math.max(0, 1 - (offset / radii.Z) ^ 2))
				point = V(radii.X * c * k, radii.Y * s * k, offset)
			end
			points[index + 1] = center + point
		end
		return points
	end

	-- A smooth ridge lying on an ellipsoid (see K.eggLine).
	function K.ridge(on, name, center, radii, plane, from, to, segments, diameter, color, material, offset)
		K.poly(on, name, K.eggLine(center, radii, plane, from, to, segments, offset), diameter, color, material, { caps = true })
	end

	-- A barrel's frame: a CFrame (relative to the bone) whose Y axis is the barrel's axis. K.axisX lays the
	-- barrel along the rig's X: angle 0 = front, positive = downward, 180 = back, negative = upward.
	function K.axisX(center)
		return CFrame.new(center) * CFrame.Angles(0, 0, rad(-90))
	end

	-- A point on a barrel: `angle` degrees round from the frame's front (-Z) toward its +X, `radius` out,
	-- `along` up the axis. The result's -Z points outward and its Y runs along the axis.
	function K.around(axis, angle, radius, along)
		return axis * CFrame.Angles(0, -rad(angle), 0) * CFrame.new(0, along or 0, -radius)
	end

	-- Curved armor: `count` flat staves round a barrel from angle `from` to `to`. The barrel's radius goes
	-- from r0 at the bottom of `length` to r1 at the top (a taper). Returns the staves.
	function K.shell(on, name, axis, from, to, count, r0, r1, length, thickness, color, material)
		local step = (to - from) / count
		local width = 2 * (math.max(r0, r1) + thickness) * math.tan(rad(math.abs(step)) / 2) + 0.02
		local tilt = CFrame.Angles(-math.atan2(r1 - r0, length), 0, 0)
		local staves = {}
		for index = 1, count do
			local at = K.around(axis, from + step * (index - 0.5), (r0 + r1) / 2 + thickness / 2) * tilt
			staves[index] = K.box(on, name, V(width, length, thickness), at, color, material)
		end
		return staves
	end

	-- A smooth ridge round a barrel (see K.around), `along` up its axis.
	function K.arc(on, name, axis, from, to, segments, radius, along, diameter, color, material)
		local points = {}
		for index = 0, segments do
			points[index + 1] = K.around(axis, from + (to - from) * index / segments, radius, along).Position
		end
		K.poly(on, name, points, diameter, color, material, { caps = true })
	end

	-- A plate (thickness = size.Z) whose edges are rounded over: `edges` lists which of "L", "R", "T", "B"
	-- (-X, +X, +Y, -Y of the plate); all four by default.
	function K.slab(on, name, size, at, color, material, edges)
		local cframe = if typeof(at) == "Vector3" then CFrame.new(at) else at
		local plate = K.box(on, name, size, cframe, color, material)
		local hx, hy = size.X / 2, size.Y / 2
		local corners = { V(-hx, -hy, 0), V(-hx, hy, 0), V(hx, hy, 0), V(hx, -hy, 0) }
		local sides = { L = { 1, 2 }, T = { 2, 3 }, R = { 3, 4 }, B = { 4, 1 } }
		local rounded = {}
		for edge in string.gmatch(edges or "LRTB", ".") do
			local a, b = sides[edge][1], sides[edge][2]
			K.tube(on, name .. "Edge", cframe * corners[a], cframe * corners[b], size.Z, color, material)
			rounded[a], rounded[b] = true, true
		end
		for index in pairs(rounded) do
			K.ball(on, name .. "Corner", size.Z, cframe * corners[index], color, material)
		end
		return plate
	end

	-- A hydraulic piston from a to b: a dark sleeve over the first half, a bright rod, an eye at each end.
	function K.piston(on, name, a, b, diameter)
		K.tube(on, name .. "Rod", a, b, diameter * 0.6, P.VG_HYDRAULIC, "Metal", { Reflectance = 0.15 })
		K.tube(on, name, a, a:Lerp(b, 0.55), diameter, P.STEEL_DARK)
		K.ring(on, name .. "Gland", a:Lerp(b, 0.55), (b - a).Unit, diameter * 1.25, 0.3, P.STEEL_MID)
		K.ball(on, name .. "Eye", diameter * 1.3, a, P.STEEL_MID)
		K.ball(on, name .. "Eye", diameter * 1.3, b, P.STEEL_MID)
	end

	-- Round rivet heads: { { position, normal }, ... }.
	function K.rivets(on, name, list, diameter, color)
		diameter = diameter or 0.45
		for index, entry in ipairs(list) do
			K.ring(on, name .. index, entry[1], entry[2].Unit, diameter, 0.24, color or P.STEEL_LIGHT)
		end
	end

	-- xAxis (optional) points the attachment's X axis: beams leave an attachment along it.
	function K.attachment(on, name, position, xAxis)
		local new = Instance.new("Attachment")
		new.Name = name
		local cframe = CFrame.new(position)
		if xAxis then
			local x = xAxis.Unit
			local reference = if math.abs(x.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
			local z = x:Cross(reference).Unit
			cframe = CFrame.fromMatrix(position, x, z:Cross(x), z)
		end
		new.CFrame = on.CFrame:ToObjectSpace(frames[on] * cframe)
		new.Parent = on
		return new
	end

	-- A cable that crosses a joint, so it has to bend with it: a camera-facing Beam between two parts.
	-- It leaves part0 along dir0 and arrives at part1 along dir1.
	function K.cable(name, part0, at0, dir0, part1, at1, dir1, width, curve, color)
		local a0 = K.attachment(part0, name .. "A", at0, dir0)
		local a1 = K.attachment(part1, name .. "B", at1, dir1)
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.CurveSize0 = curve
		beam.CurveSize1 = curve
		beam.Segments = 12
		beam.FaceCamera = true
		beam.Width0 = width
		beam.Width1 = width
		beam.Color = ColorSequence.new(BK.toColor(color or P.HAZARD_BLACK))
		beam.Transparency = NumberSequence.new(0)
		beam.LightEmission = 0
		beam.LightInfluence = 1
		beam.Parent = part0
		return beam
	end

	function K.stencil(on, name, size, at, text, color)
		local plate = K.box(on, name, V(size.X, size.Y, 0.05), at, P.VG_ARMOR, "Metal", { Transparency = 1 })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Font.fromEnum(Enum.Font.Michroma)
		label.TextScaled = true
		label.TextColor3 = BK.toColor(color or "#E8ECEF")
		label.Text = text
		label.Parent = gui
		return plate
	end

	return K
end

return Kit
