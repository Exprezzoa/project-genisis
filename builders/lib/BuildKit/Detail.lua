--!nonstrict
-- BuildKit/Detail: seams, trims, kickplates, hazard stripes, pipes, cables, bolts.
-- Everything here is decoration: tagged "Detail" (CanCollide false, CanQuery false) unless noted.
-- Recipes: docs/07_building_with_parts.md section 7 and docs/06_art_direction.md section 4.

return function(BK)
	local P = BK.Palette

	local EPS = 0.001
	local SEAM_DARKEN = 0.08 -- seams are 8% darker than their surface (docs/07 section 7)
	local PAINT_THICKNESS = 0.05 -- painted lines are thin parts 0.05 above the floor (docs/06 section 4)
	local PAINT_LIFT = 0.02 -- black paint sits this much above the yellow so the faces never z-fight
	local BRACKET_SPACING = 8

	local AXIS = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
	local WORLD_AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

	-- Per face: outward normal, the two in-plane local axes (u, v) and the axis along the normal (w).
	local FACES = {
		[Enum.NormalId.Front] = { normal = -Vector3.zAxis, u = "X", v = "Y", w = "Z" },
		[Enum.NormalId.Back] = { normal = Vector3.zAxis, u = "X", v = "Y", w = "Z" },
		[Enum.NormalId.Left] = { normal = -Vector3.xAxis, u = "Z", v = "Y", w = "X" },
		[Enum.NormalId.Right] = { normal = Vector3.xAxis, u = "Z", v = "Y", w = "X" },
		[Enum.NormalId.Top] = { normal = Vector3.yAxis, u = "X", v = "Z", w = "Y" },
		[Enum.NormalId.Bottom] = { normal = -Vector3.yAxis, u = "X", v = "Z", w = "Y" },
	}

	local function faceInfo(faceEnum, functionName)
		local info = FACES[faceEnum]
		if not info then
			error(("[BuildKit] %s: the face must be an Enum.NormalId"):format(functionName), 3)
		end
		return info
	end

	local function detailFolder(face, opts, defaultName)
		local folder = Instance.new("Folder")
		folder.Name = opts.name or defaultName
		folder.Parent = opts.parent or face.Parent
		return folder
	end

	-- Rotation that points a cylinder's length (the engine's local X) along `direction`.
	local function lengthAlong(position, direction)
		return BK.lookAlong(position, direction) * CFrame.Angles(0, math.rad(90), 0)
	end

	---------------------------------------------------------------------------
	-- Seams
	---------------------------------------------------------------------------
	-- Thin strips on one face of a part, half sunk (0.05 proud with the default depth).
	--   spacing     distance between lines (nil for none)
	--   opts.along  local axis the lines run along ("X" | "Y" | "Z"); default: both in-plane axes (a grid)
	--   opts.at     extra lines at these offsets, measured from the face's minimum edge
	--   opts.align  "world" (default: lines sit on world multiples of spacing, so neighbouring parts line
	--               up), "center" (a line through the face center) or "edge" (from the minimum edge)
	--   opts.parent / opts.name  where the returned Folder goes (default: next to the part, "Seams_<Face>")
	function BK.seams(face, faceEnum, spacing, opts)
		opts = opts or {}
		local info = faceInfo(faceEnum, "BK.seams")
		local depth = opts.depth or 0.1
		local width = opts.width or 0.2
		local color = if opts.color ~= nil then BK.toColor(opts.color) else BK.darken(face.Color, SEAM_DARKEN)
		local size = face.Size
		local folder = detailFolder(face, opts, "Seams_" .. faceEnum.Name)
		local count = 0

		local function offsetsAcross(acrossAxis)
			local length = size[acrossAxis]
			local offsets = {}
			if opts.at then
				for _, offset in ipairs(opts.at) do
					table.insert(offsets, offset)
				end
			end
			if spacing and spacing > 0 then
				local align = opts.align or "world"
				local grid, sign
				if align == "world" then
					local worldAxis = face.CFrame:VectorToWorldSpace(AXIS[acrossAxis])
					for _, candidate in ipairs(WORLD_AXES) do
						local dot = worldAxis:Dot(candidate)
						if math.abs(dot) > 0.999 then
							grid, sign = candidate, math.sign(dot)
						end
					end
					if not grid then
						align = "center" -- the part is rotated off the world axes
					end
				end
				if align == "world" then
					local centerCoord = face.Position:Dot(grid)
					local first = math.ceil((centerCoord - length / 2) / spacing - EPS)
					local last = math.floor((centerCoord + length / 2) / spacing + EPS)
					for k = first, last do
						table.insert(offsets, (k * spacing - centerCoord) * sign + length / 2)
					end
				elseif align == "center" then
					local reach = math.floor(length / 2 / spacing + EPS)
					for k = -reach, reach do
						table.insert(offsets, length / 2 + k * spacing)
					end
				elseif align == "edge" then
					local k = 1
					while k * spacing < length do
						table.insert(offsets, k * spacing)
						k += 1
					end
				else
					error("[BuildKit] BK.seams: opts.align must be 'world', 'center' or 'edge'", 3)
				end
			end
			return offsets
		end

		-- Lines run along `alongAxis` and repeat along `acrossAxis`.
		local function run(alongAxis, acrossAxis)
			local acrossLength = size[acrossAxis]
			for _, offset in ipairs(offsetsAcross(acrossAxis)) do
				if offset > width and offset < acrossLength - width then
					count += 1
					local dims = { X = 0, Y = 0, Z = 0 }
					dims[alongAxis] = size[alongAxis]
					dims[acrossAxis] = width
					dims[info.w] = depth
					local localPosition = info.normal * (size[info.w] / 2) + AXIS[acrossAxis] * (offset - acrossLength / 2)
					BK.part(folder, {
						Name = ("Seam%03d"):format(count),
						Size = Vector3.new(dims.X, dims.Y, dims.Z),
						CFrame = face.CFrame * CFrame.new(localPosition),
						Color = color,
						CastShadow = false,
						Tags = { "Detail" },
					})
				end
			end
		end

		local along = opts.along
		if along == nil then
			run(info.u, info.v)
			run(info.v, info.u)
		elseif along == info.u then
			run(info.u, info.v)
		elseif along == info.v then
			run(info.v, info.u)
		else
			error(("[BuildKit] BK.seams: opts.along must be '%s' or '%s' for the %s face"):format(info.u, info.v, faceEnum.Name), 2)
		end
		return folder
	end

	---------------------------------------------------------------------------
	-- Trim bands and kickplates
	---------------------------------------------------------------------------
	-- A decorative band. `cframe` is its center; length runs along X, height along Y, depth along Z.
	function BK.trimBand(parent, name, cframe, length, height, depth, color)
		return BK.part(parent, {
			Name = name,
			Size = Vector3.new(length, height, depth),
			CFrame = cframe,
			Color = if color ~= nil then color else P.SLATE,
			Tags = { "Detail" },
		})
	end

	-- The 1-stud dark base strip along the bottom of one side face of a wall part.
	-- Extra opts: color (default KICKPLATE; exterior walls use CONCRETE_DARK), height (1), depth (0.1).
	function BK.kickplate(parent, name, wallPart, side, opts)
		opts = opts or {}
		local info = faceInfo(side, "BK.kickplate")
		if info.w == "Y" then
			error("[BuildKit] BK.kickplate: side must be Front, Back, Left or Right", 2)
		end
		local size = wallPart.Size
		local height = math.min(opts.height or 1, size.Y)
		local dims = { X = 0, Y = height, Z = 0 }
		dims[info.u] = size[info.u] - 0.04 -- keep the ends just inside the wall's own end faces
		dims[info.w] = opts.depth or 0.1
		local localPosition = info.normal * (size[info.w] / 2) + Vector3.new(0, -size.Y / 2 + height / 2, 0)
		return BK.part(parent, {
			Name = name,
			Size = Vector3.new(dims.X, dims.Y, dims.Z),
			CFrame = wallPart.CFrame * CFrame.new(localPosition),
			Color = if opts.color ~= nil then opts.color else P.KICKPLATE,
			Tags = { "Detail" },
		})
	end

	---------------------------------------------------------------------------
	-- Hazard stripes
	---------------------------------------------------------------------------
	-- A painted hazard band lying on a surface. `cframe` is the band's center ON the surface: length runs
	-- along its X, width along its Z, the surface normal is its Y. Yellow base strip plus black diagonal
	-- stripes built from flat triangles and rectangles; nothing pokes outside the band.
	--   opts.stripe  stripe width measured along the band (default 2)
	--   opts.angle   stripe angle from the band's length axis in degrees, 15 to 90 (default 45)
	function BK.hazardStripe(parent, name, cframe, length, width, opts)
		opts = opts or {}
		local stripe = opts.stripe or 2
		local angle = opts.angle or 45
		if angle < 15 or angle > 90 then
			error("[BuildKit] BK.hazardStripe: opts.angle must be between 15 and 90 degrees", 2)
		end

		local model = BK.model(parent, name)
		local function paint(color)
			return { Color = color, CastShadow = false, Tags = { "Detail" } }
		end

		local base = paint(P.HAZARD_YELLOW)
		base.Name = name .. "_Base"
		base.Size = Vector3.new(length, PAINT_THICKNESS, width)
		base.CFrame = cframe * CFrame.new(0, PAINT_THICKNESS / 2, 0)
		model.PrimaryPart = BK.part(model, base)

		local black = paint(P.HAZARD_BLACK)
		local thickness = PAINT_THICKNESS + PAINT_LIFT
		local y = thickness / 2
		local shear = if angle > 89.999 then 0 else width / math.tan(math.rad(angle))
		-- Split the width into bands so each band's shear never exceeds the stripe width.
		local bands = math.max(1, math.ceil(shear / stripe - EPS))
		local bandWidth = width / bands
		local bandShear = shear / bands
		local count = math.floor((length - shear + stripe) / (2 * stripe) + EPS)
		local used = (count - 1) * 2 * stripe + stripe + shear
		local xAxis, zAxis = cframe.XVector, cframe.ZVector
		local function world(x, z)
			return (cframe * CFrame.new(x, y, z)).Position
		end

		local index = 0
		for i = 0, count - 1 do
			local x0 = -used / 2 + i * 2 * stripe
			for j = 0, bands - 1 do
				index += 1
				local xb = x0 + j * bandShear
				local zLo = -width / 2 + j * bandWidth
				local zHi = zLo + bandWidth
				if bandShear > EPS then
					BK.triangle(model, ("%s_S%03dA"):format(name, index), world(xb + bandShear, zLo), xAxis * -bandShear, zAxis * bandWidth, thickness, black)
					BK.triangle(model, ("%s_S%03dB"):format(name, index), world(xb + stripe, zHi), zAxis * -bandWidth, xAxis * bandShear, thickness, black)
				end
				if stripe - bandShear > EPS then
					local rect = table.clone(black)
					rect.Name = ("%s_S%03dC"):format(name, index)
					rect.Size = Vector3.new(stripe - bandShear, thickness, bandWidth)
					rect.CFrame = cframe * CFrame.new(xb + (bandShear + stripe) / 2, y, (zLo + zHi) / 2)
					BK.part(model, rect)
				end
			end
		end
		return model
	end

	---------------------------------------------------------------------------
	-- Pipes and cables
	---------------------------------------------------------------------------
	-- A pipe along a polyline, with ball elbows at the corners and clamp brackets along the straights.
	-- Extra opts: collide = true makes the pipes solid (default: decoration only).
	function BK.pipeRun(parent, name, points, radius, opts)
		opts = opts or {}
		local color = if opts.color ~= nil then BK.toColor(opts.color) else P.STEEL_MID
		local wantBrackets = opts.brackets ~= false
		local solid = opts.collide == true
		local diameter = radius * 2
		local model = BK.model(parent, name)

		local function pipeProps(partName)
			local p = { Name = partName, Color = color, Material = Enum.Material.Metal }
			if not solid then
				p.Tags = { "Detail" }
			end
			return p
		end

		local brackets = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			if length > EPS then
				local pipe = pipeProps(("%s_Pipe%02d"):format(name, i))
				pipe.Size = Vector3.new(length, diameter, diameter)
				pipe.CFrame = lengthAlong((a + b) / 2, delta)
				BK.cyl(model, pipe)

				if wantBrackets and length >= 3 then
					local n = math.max(1, math.floor(length / BRACKET_SPACING))
					for k = 1, n do
						brackets += 1
						BK.part(model, {
							Name = ("%s_Bracket%02d"):format(name, brackets),
							Size = Vector3.new(diameter + 0.3, diameter + 0.3, 0.3),
							CFrame = BK.lookAlong(a + delta * (k / (n + 1)), delta),
							Color = P.STEEL_DARK,
							Material = Enum.Material.Metal,
							Tags = { "Detail" },
						})
					end
				end
			end
			if i > 1 then
				local elbow = pipeProps(("%s_Elbow%02d"):format(name, i - 1))
				elbow.Size = Vector3.one * (diameter * 1.1)
				elbow.CFrame = CFrame.new(a)
				BK.ball(model, elbow)
			end
		end

		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		return model
	end

	-- A sagging cable from a to b: `segments` straight pieces along a parabola that drops `sag` studs at
	-- mid-span. Extra opts: color (default HAZARD_BLACK, the cable color of docs/07 section 6).
	function BK.cable(parent, name, a, b, sag, segments, thickness, opts)
		opts = opts or {}
		segments = math.max(1, math.floor(segments or 6))
		thickness = thickness or 0.2
		local color = if opts.color ~= nil then BK.toColor(opts.color) else P.HAZARD_BLACK
		local model = BK.model(parent, name)

		local function pointAt(t)
			return a:Lerp(b, t) - Vector3.yAxis * (sag * 4 * t * (1 - t))
		end

		local previous = pointAt(0)
		for i = 1, segments do
			local current = pointAt(i / segments)
			local delta = current - previous
			BK.cyl(model, {
				Name = ("%s_Seg%02d"):format(name, i),
				Size = Vector3.new(delta.Magnitude + thickness * 0.4, thickness, thickness),
				CFrame = lengthAlong((previous + current) / 2, delta),
				Color = color,
				CastShadow = false,
				Tags = { "Detail" },
			})
			previous = current
		end

		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		return model
	end

	---------------------------------------------------------------------------
	-- Bolts
	---------------------------------------------------------------------------
	-- A grid of bolt heads on one face of a part. grid = Vector2(columns, rows).
	-- Extra opts: margin (distance from the face edges), parent / name (as for BK.seams).
	function BK.bolts(face, faceEnum, grid, opts)
		opts = opts or {}
		local info = faceInfo(faceEnum, "BK.bolts")
		local boltSize = opts.size or 0.3
		local color = if opts.color ~= nil then BK.toColor(opts.color) else P.STEEL_DARK
		local margin = opts.margin or math.max(boltSize * 2, 0.5)
		local height = boltSize * 0.4
		local size = face.Size
		local columns = math.max(1, math.floor(grid.X + 0.5))
		local rows = math.max(1, math.floor(grid.Y + 0.5))
		local folder = detailFolder(face, opts, "Bolts_" .. faceEnum.Name)

		local function spread(count, length, index)
			if count == 1 then
				return 0
			end
			local usable = length - 2 * margin
			return -usable / 2 + usable * (index - 1) / (count - 1)
		end

		local rotation = lengthAlong(Vector3.zero, info.normal)
		local n = 0
		for c = 1, columns do
			for r = 1, rows do
				n += 1
				local localPosition = info.normal * (size[info.w] / 2 + height / 2)
					+ AXIS[info.u] * spread(columns, size[info.u], c)
					+ AXIS[info.v] * spread(rows, size[info.v], r)
				BK.cyl(folder, {
					Name = ("Bolt%03d"):format(n),
					Size = Vector3.new(height, boltSize, boltSize),
					CFrame = face.CFrame * CFrame.new(localPosition) * rotation,
					Color = color,
					Material = Enum.Material.Metal,
					Tags = { "Detail" },
				})
			end
		end
		return folder
	end
end
