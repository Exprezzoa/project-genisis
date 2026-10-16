--!nonstrict
-- BuildKit/Core: coercion, the props applier, primitives, containers, utilities.
-- API reference: docs/07_building_with_parts.md section 3.

return function(BK)
	local P = BK.Palette

	---------------------------------------------------------------------------
	-- Warnings (builders return them in their stats)
	---------------------------------------------------------------------------
	BK.warnings = {}

	function BK.warn(message)
		table.insert(BK.warnings, message)
		warn("[BuildKit] " .. message)
	end

	---------------------------------------------------------------------------
	-- Cooperative yielding
	---------------------------------------------------------------------------
	-- Edit-mode code freezes Studio until it yields. BuildKit yields for one frame whenever it has been
	-- creating parts for longer than BK.yieldBudget seconds. Set BK.yieldBudget = 0 to never yield.
	BK.yieldBudget = 0.1
	local lastYield = os.clock()

	function BK.breathe(force)
		if force or (BK.yieldBudget > 0 and os.clock() - lastYield >= BK.yieldBudget) then
			task.wait()
			lastYield = os.clock()
		end
	end

	---------------------------------------------------------------------------
	-- Coercion
	---------------------------------------------------------------------------
	function BK.hex(hex)
		if type(hex) ~= "string" or not string.match(hex, "^#%x%x%x%x%x%x$") then
			error("[BuildKit] a hex color must look like '#RRGGBB', got " .. tostring(hex), 2)
		end
		return Color3.fromHex(hex)
	end

	function BK.toColor(value)
		local kind = typeof(value)
		if kind == "Color3" then
			return value
		elseif kind == "string" then
			return BK.hex(value)
		end
		error("[BuildKit] a color must be a Color3 or a '#RRGGBB' string, got " .. kind, 2)
	end

	function BK.toMaterial(value)
		local kind = typeof(value)
		if kind == "EnumItem" and value.EnumType == Enum.Material then
			return value
		elseif kind == "string" then
			local ok, item = pcall(function()
				return Enum.Material[value]
			end)
			if ok and item then
				return item
			end
		end
		error("[BuildKit] unknown material: " .. tostring(value), 2)
	end

	-- Parts keep 8-bit color channels and truncate anything finer. Snapping to the nearest 8-bit color first
	-- means the color a builder computes is exactly the color the part keeps.
	local function snap(r, g, b)
		return Color3.fromRGB(math.round(math.clamp(r, 0, 1) * 255), math.round(math.clamp(g, 0, 1) * 255), math.round(math.clamp(b, 0, 1) * 255))
	end

	-- A darker shade of a color (amount 0.08 = 8% darker). Used for seams.
	function BK.darken(color, amount)
		local f = 1 - amount
		return snap(color.R * f, color.G * f, color.B * f)
	end

	-- Glow calibration (D-099): Neon brightens a color, and AMBER in Neon shows on screen as lemon yellow. Parts meant
	-- to glow amber use WARNING_ORANGE in Neon at these transparencies, which shows as the doc's amber (#E8A33D).
	-- Light objects keep AMBER (a light's color isn't brightened); amber paint, text and UI stay AMBER.
	BK.GLOW = {
		amber = { Color = P.WARNING_ORANGE, Transparency = 0.4 }, -- strips, lamps, indicators
		holo = { Color = P.WARNING_ORANGE, Transparency = 0.6 }, -- hologram solids (planes 0.8, edges 0.45)
	}

	---------------------------------------------------------------------------
	-- The props applier (docs/07 section 3, "props table keys" and automatic defaults)
	---------------------------------------------------------------------------
	local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic
	local AUTO_SOFT_SIZE = 0.5 -- a part with every dimension <= this never collides, queries or casts shadows

	local PROP_KEYS = {
		Name = true,
		Size = true,
		CFrame = true,
		Position = true,
		Orientation = true,
		Color = true,
		Material = true,
		Transparency = true,
		Reflectance = true,
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = true,
		Massless = true,
		Locked = true,
		Tags = true,
		Attributes = true,
		CollisionGroup = true,
	}

	local function pick(value, default)
		if value == nil then
			return default
		end
		return value
	end

	-- Explicit props always win over the automatic defaults.
	local function apply(part, parent, props, extraKeys)
		props = props or {}
		for key in pairs(props) do
			if not PROP_KEYS[key] and not (extraKeys and extraKeys[key]) then
				error(("[BuildKit] unknown props key '%s' (%s)"):format(tostring(key), part.ClassName), 3)
			end
		end

		part.Name = props.Name or part.ClassName
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = pick(props.Anchored, true)
		part.CanTouch = pick(props.CanTouch, false)
		part.Material = if props.Material ~= nil then BK.toMaterial(props.Material) else DEFAULT_MATERIAL
		part.Color = if props.Color ~= nil then BK.toColor(props.Color) else P.CONCRETE_MID
		if props.Size then
			part.Size = props.Size
		end
		if props.CFrame then
			part.CFrame = props.CFrame
		else
			if props.Position then
				part.Position = props.Position
			end
			if props.Orientation then
				part.Orientation = props.Orientation
			end
		end
		if props.Transparency ~= nil then
			part.Transparency = props.Transparency
		end
		if props.Reflectance ~= nil then
			part.Reflectance = props.Reflectance
		end
		if props.Massless ~= nil then
			part.Massless = props.Massless
		end
		if props.Locked ~= nil then
			part.Locked = props.Locked
		end
		if props.CollisionGroup ~= nil then
			part.CollisionGroup = props.CollisionGroup
		end

		local tags = props.Tags
		if type(tags) == "string" then
			tags = { tags }
		end
		local isDetail = false
		if tags then
			for _, tag in ipairs(tags) do
				part:AddTag(tag)
				if tag == "Detail" then
					isDetail = true
				end
			end
		end
		if props.Attributes then
			for key, value in pairs(props.Attributes) do
				part:SetAttribute(key, value)
			end
		end

		local size = part.Size
		local tiny = size.X <= AUTO_SOFT_SIZE and size.Y <= AUTO_SOFT_SIZE and size.Z <= AUTO_SOFT_SIZE
		local soft = tiny or isDetail
		part.CanCollide = pick(props.CanCollide, not soft)
		part.CanQuery = pick(props.CanQuery, not soft)
		part.CastShadow = pick(props.CastShadow, not tiny)

		part.Parent = parent
		BK.breathe()
		return part
	end

	---------------------------------------------------------------------------
	-- Primitives
	---------------------------------------------------------------------------
	function BK.part(parent, props)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Block
		return apply(part, parent, props)
	end

	-- WedgePart: the slope rises toward the part's Back (+Z); the right angle is at the bottom-back edge.
	function BK.wedge(parent, props)
		return apply(Instance.new("WedgePart"), parent, props)
	end

	-- CornerWedgePart: the full-height vertical edge is at +X / -Z.
	function BK.cornerWedge(parent, props)
		return apply(Instance.new("CornerWedgePart"), parent, props)
	end

	function BK.ball(parent, props)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		return apply(part, parent, props)
	end

	local TRUSS_KEYS = { Style = true }

	function BK.truss(parent, props)
		local part = Instance.new("TrussPart")
		if props and props.Style then
			part.Style = props.Style
		end
		return apply(part, parent, props, TRUSS_KEYS)
	end

	-- Rotations that take the engine's cylinder length axis (local X) onto the requested logical axis.
	local CYLINDER_ROTATION = {
		X = CFrame.identity,
		Y = CFrame.Angles(0, 0, math.rad(90)),
		Z = CFrame.Angles(0, math.rad(-90), 0),
	}

	-- Cylinder. Without props.Axis this is the raw engine cylinder (length along the part's local X).
	-- With props.Axis = "X" | "Y" | "Z", Size and CFrame/Position/Orientation describe a logical box whose
	-- cylinder length runs along that axis: a standing barrel is { Axis = "Y", Size = (2.6, 3.6, 2.6) }.
	function BK.cyl(parent, props)
		props = props or {}
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		local axis = props.Axis
		if axis == nil then
			return apply(part, parent, props)
		end
		local rotation = CYLINDER_ROTATION[axis]
		if not rotation then
			error("[BuildKit] BK.cyl: Axis must be 'X', 'Y' or 'Z', got " .. tostring(axis), 2)
		end
		local size = props.Size
		if not size then
			error("[BuildKit] BK.cyl: Size is required when Axis is given", 2)
		end

		local remapped = table.clone(props)
		remapped.Axis = nil
		if axis == "Y" then
			remapped.Size = Vector3.new(size.Y, size.X, size.Z)
		elseif axis == "Z" then
			remapped.Size = Vector3.new(size.Z, size.Y, size.X)
		end
		local logical = props.CFrame
		if not logical then
			local position = props.Position or Vector3.zero
			local o = props.Orientation or Vector3.zero
			logical = CFrame.new(position) * CFrame.fromOrientation(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
		end
		remapped.CFrame = logical * rotation
		remapped.Position = nil
		remapped.Orientation = nil
		return apply(part, parent, remapped)
	end

	---------------------------------------------------------------------------
	-- Oriented helpers (additions to docs/07 section 3)
	---------------------------------------------------------------------------
	-- A CFrame at `position` whose LookVector (-Z) points along `direction`. Safe for vertical directions.
	function BK.lookAlong(position, direction)
		local up = if math.abs(direction.Unit.Y) > 0.999 then Vector3.xAxis else Vector3.yAxis
		return CFrame.lookAt(position, position + direction, up)
	end

	-- A box running from point a to point b with cross-section sizeX (sideways) by sizeY.
	function BK.beam(parent, name, a, b, sizeX, sizeY, props)
		local delta = b - a
		local length = delta.Magnitude
		if length < 0.001 then
			error(("[BuildKit] BK.beam '%s': a and b are the same point"):format(tostring(name)), 2)
		end
		local p = if props then table.clone(props) else {}
		p.Name = name
		p.Size = Vector3.new(sizeX, sizeY, length)
		p.CFrame = BK.lookAlong((a + b) / 2, delta)
		p.Position = nil
		p.Orientation = nil
		return BK.part(parent, p)
	end

	-- A right-triangle prism (WedgePart). The right angle sits at `corner`; legA and legB are the two
	-- perpendicular edge vectors leaving it. `thickness` is centered on the triangle's plane.
	function BK.triangle(parent, name, corner, legA, legB, thickness, props)
		local lengthA, lengthB = legA.Magnitude, legB.Magnitude
		if lengthA < 0.001 or lengthB < 0.001 then
			error(("[BuildKit] BK.triangle '%s': a leg has zero length"):format(tostring(name)), 2)
		end
		if math.abs(legA.Unit:Dot(legB.Unit)) > 0.001 then
			error(("[BuildKit] BK.triangle '%s': the legs must be perpendicular"):format(tostring(name)), 2)
		end
		local yAxis = legA.Unit
		local zAxis = -legB.Unit
		local xAxis = yAxis:Cross(zAxis)
		local p = if props then table.clone(props) else {}
		p.Name = name
		p.Size = Vector3.new(thickness, lengthA, lengthB)
		p.CFrame = CFrame.fromMatrix(corner + legA / 2 + legB / 2, xAxis, yAxis, zAxis)
		p.Position = nil
		p.Orientation = nil
		return BK.wedge(parent, p)
	end

	---------------------------------------------------------------------------
	-- Containers
	---------------------------------------------------------------------------
	-- Finds or creates a Folder. With clear = true an existing folder is emptied (idempotent builders).
	function BK.folder(parent, name, clear)
		local folder = parent:FindFirstChild(name)
		if folder and not folder:IsA("Folder") then
			error(("[BuildKit] %s.%s exists but is a %s, not a Folder"):format(parent:GetFullName(), name, folder.ClassName), 2)
		end
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = parent
		elseif clear then
			for _, child in ipairs(folder:GetChildren()) do
				child:Destroy()
				BK.breathe()
			end
		end
		return folder
	end

	function BK.model(parent, name)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		return model
	end

	---------------------------------------------------------------------------
	-- Utilities
	---------------------------------------------------------------------------
	function BK.weld(a, b)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = a
		weld.Part1 = b
		weld.Parent = a
		return weld
	end

	function BK.weldAllTo(model, root)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= root then
				BK.weld(root, descendant)
			end
		end
	end

	function BK.tag(inst, ...)
		for i = 1, select("#", ...) do
			inst:AddTag((select(i, ...)))
		end
	end

	function BK.attr(inst, attributes)
		for key, value in pairs(attributes) do
			inst:SetAttribute(key, value)
		end
	end

	-- Deterministic randomness: one fixed seed per builder.
	function BK.rng(seed)
		local random = Random.new(seed)
		local rng = {}
		function rng.next(min, max)
			if min == nil then
				return random:NextNumber()
			end
			return random:NextNumber(min, max)
		end
		function rng.int(min, max)
			return random:NextInteger(min, max)
		end
		function rng.pick(list)
			return list[random:NextInteger(1, #list)]
		end
		return rng
	end

	-- Brightness variance: amount 0.03 = up to 3% brighter or darker.
	function BK.vary(color, amount, rng)
		local f = 1 + rng.next(-amount, amount)
		return snap(color.R * f, color.G * f, color.B * f)
	end

	-- Counts under root (root included). shadowLights is an addition: it is a budget in docs/07 section 5.
	function BK.stats(root)
		local stats = { parts = 0, lights = 0, shadowLights = 0, emitters = 0, guis = 0 }
		local function count(inst)
			if inst:IsA("BasePart") then
				if not inst:IsA("Terrain") then
					stats.parts += 1
				end
			elseif inst:IsA("Light") then
				stats.lights += 1
				if inst.Shadows then
					stats.shadowLights += 1
				end
			elseif inst:IsA("ParticleEmitter") then
				stats.emitters += 1
			elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
				stats.guis += 1
			end
		end
		count(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			count(descendant)
		end
		return stats
	end

	-- The stats table every builder returns: BK.stats plus ms (since startClock = os.clock()) and warnings.
	function BK.report(root, startClock)
		local stats = BK.stats(root)
		if startClock then
			stats.ms = math.floor((os.clock() - startClock) * 1000 + 0.5)
		end
		stats.warnings = table.clone(BK.warnings)
		return stats
	end
end
