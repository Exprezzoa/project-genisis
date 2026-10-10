--!nonstrict
-- BuildKit/Fx: lights, signs, screens, painted floor text, particle emitters.
-- Rules: docs/06_art_direction.md sections 5 (lights), 6 (VFX) and 7 (signage and screens).
--
-- Signs and screens face -Z: the readable side is the part's Front face (the CFrame's LookVector).
-- `cframe` is the CENTER of the sign or screen.

return function(BK)
	local P = BK.Palette

	local MAX_LIGHT_RANGE = 60 -- Roblox limit (docs/06 section 5)
	local PIXELS_PER_STUD = 50 -- docs/06 section 7
	local SIGN_THICKNESS = 0.1
	local PAINTED_LIGHT_INFLUENCE = 0.6 -- painted signs; screens and lit signs use 0 (docs/06 section 7)
	local SCREEN_BASE = "#1B2A33" -- screen base color (docs/07 section 6: Console, Terminal)
	local SCREEN_TRANSPARENCY = 0.3 -- screens sit at 0.3-0.5 transparency (docs/06 section 4)
	local FLOOR_TEXT_TRANSPARENCY = 0.15 -- painted floor text (docs/06 section 7)
	local FONT_HEADER = Enum.Font.Michroma
	local FONT_MONO = Enum.Font.RobotoMono

	---------------------------------------------------------------------------
	-- Lights
	---------------------------------------------------------------------------
	local LIGHT_CLASSES = { Point = "PointLight", Spot = "SpotLight", Surface = "SurfaceLight" }
	local LIGHT_KEYS = {
		Name = true,
		Color = true,
		Brightness = true,
		Range = true,
		Angle = true,
		Face = true,
		Shadows = true,
		Enabled = true,
		Tags = true,
		Attributes = true,
	}

	-- props: Name, Color (default LIGHT_NEUTRAL), Brightness, Range (clamped to 60 with a warning),
	-- Angle and Face (Spot and Surface), Shadows (default false: shadows are budgeted), Enabled, Tags,
	-- Attributes. Brightness, Range and Angle keep the engine defaults when omitted.
	function BK.light(onPart, kind, props)
		local className = LIGHT_CLASSES[kind]
		if not className then
			error("[BuildKit] BK.light: kind must be 'Point', 'Spot' or 'Surface', got " .. tostring(kind), 2)
		end
		props = props or {}
		for key in pairs(props) do
			if not LIGHT_KEYS[key] then
				error(("[BuildKit] BK.light: unknown props key '%s'"):format(tostring(key)), 2)
			end
		end

		local light = Instance.new(className)
		light.Name = props.Name or className
		light.Color = BK.toColor(if props.Color ~= nil then props.Color else P.LIGHT_NEUTRAL)
		light.Shadows = props.Shadows == true
		if props.Brightness then
			light.Brightness = props.Brightness
		end
		if props.Range then
			local range = props.Range
			if range > MAX_LIGHT_RANGE then
				BK.warn(("light on %s: Range %s is above the Roblox maximum, clamped to %d"):format(onPart:GetFullName(), tostring(range), MAX_LIGHT_RANGE))
				range = MAX_LIGHT_RANGE
			end
			light.Range = range
		end
		if props.Enabled ~= nil then
			light.Enabled = props.Enabled
		end
		if kind ~= "Point" then
			if props.Angle then
				light.Angle = props.Angle
			end
			if props.Face then
				light.Face = props.Face
			end
		end
		if props.Tags then
			BK.tag(light, table.unpack(props.Tags))
		end
		if props.Attributes then
			BK.attr(light, props.Attributes)
		end
		light.Parent = onPart
		return light
	end

	---------------------------------------------------------------------------
	-- Signs, screens, floor text
	---------------------------------------------------------------------------
	local function toFont(font, fallback)
		font = font or fallback
		local kind = typeof(font)
		if kind == "Font" then
			return font
		elseif kind == "EnumItem" then
			return Font.fromEnum(font)
		end
		error("[BuildKit] a font must be an Enum.Font or a Font", 3)
	end

	-- SurfaceGui "Face" on the part's Front face with one scaled TextLabel "Text".
	local function surfaceText(part, lightInfluence, pixelsPerStud)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or PIXELS_PER_STUD
		gui.LightInfluence = lightInfluence
		gui.ClipsDescendants = true

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.TextWrapped = true

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.12, 0)
		padding.Parent = label

		label.Parent = gui
		gui.Parent = part
		return gui, label
	end

	-- A painted sign. Text is forced to ALL CAPS (the signage standard) unless opts.upper == false.
	-- Defaults: amber Michroma text on SLATE_DEEP. opts.light = true makes it self-lit with a soft glow.
	-- Extra opts: textTransparency, upper, pixelsPerStud.
	function BK.sign(parent, name, cframe, size, text, opts)
		opts = opts or {}
		local lit = opts.light == true
		local textColor = BK.toColor(if opts.textColor ~= nil then opts.textColor else P.AMBER)
		local part = BK.part(parent, {
			Name = name,
			Size = Vector3.new(size.X, size.Y, SIGN_THICKNESS),
			CFrame = cframe,
			Color = if opts.bgColor ~= nil then opts.bgColor else P.SLATE_DEEP,
			Transparency = opts.bgTransparency or 0,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		local _, label = surfaceText(part, if lit then 0 else PAINTED_LIGHT_INFLUENCE, opts.pixelsPerStud)
		label.Text = if opts.upper == false then text else string.upper(text)
		label.FontFace = toFont(opts.font, FONT_HEADER)
		label.TextColor3 = textColor
		label.TextTransparency = opts.textTransparency or 0
		if lit then
			BK.light(part, "Surface", { Name = "Glow", Face = Enum.NormalId.Front, Color = textColor, Brightness = 0.6, Range = 10 })
		end
		return part
	end

	-- A self-lit screen: Neon base plus a SurfaceGui with LightInfluence 0. Text keeps its case
	-- (sentence case is the terminal standard). opts.color is the base color.
	-- Extra opts: textColor (default AMBER), font (default RobotoMono), transparency, pixelsPerStud.
	function BK.screen(parent, name, cframe, size, opts)
		opts = opts or {}
		local part = BK.part(parent, {
			Name = name,
			Size = Vector3.new(size.X, size.Y, SIGN_THICKNESS),
			CFrame = cframe,
			Color = if opts.color ~= nil then opts.color else SCREEN_BASE,
			Material = Enum.Material.Neon,
			Transparency = opts.transparency or SCREEN_TRANSPARENCY,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		local _, label = surfaceText(part, 0, opts.pixelsPerStud)
		label.Text = opts.text or ""
		label.FontFace = toFont(opts.font, FONT_MONO)
		label.TextColor3 = BK.toColor(if opts.textColor ~= nil then opts.textColor else P.AMBER)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		return part
	end

	-- Painted floor text (docs/06 section 7). `position` is a point ON the floor; the text lies flat,
	-- 0.05 above it, reads from above, and its top edge points along opts.textUp (default -Z, north).
	-- Other opts are passed to BK.sign (defaults: no background, HAZARD_YELLOW at 0.15 transparency).
	function BK.floorText(parent, name, position, size, text, opts)
		opts = if opts then table.clone(opts) else {}
		local textUp = opts.textUp or -Vector3.zAxis
		opts.textUp = nil
		if opts.bgTransparency == nil then
			opts.bgTransparency = 1
		end
		if opts.textColor == nil then
			opts.textColor = P.HAZARD_YELLOW
		end
		if opts.textTransparency == nil then
			opts.textTransparency = FLOOR_TEXT_TRANSPARENCY
		end
		return BK.sign(parent, name, CFrame.lookAt(position, position + Vector3.yAxis, textUp), size, text, opts)
	end

	---------------------------------------------------------------------------
	-- Particle emitters
	---------------------------------------------------------------------------
	local TEXTURE_SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
	local TEXTURE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

	local function dustPuff(emitter, hex)
		emitter.Texture = TEXTURE_SMOKE
		emitter.Color = ColorSequence.new(BK.hex(hex))
		emitter.Size = NumberSequence.new(2, 6)
		emitter.Lifetime = NumberRange.new(0.8, 1.2)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.SpreadAngle = Vector2.new(80, 10)
		emitter.Enabled = false
		emitter:SetAttribute("EmitCount", 14)
	end

	-- Values copied from the table in docs/06_art_direction.md section 6. Anything the table does not give
	-- keeps the engine default. Burst presets are created disabled and carry an EmitCount attribute:
	-- fire them with emitter:Emit(emitter:GetAttribute("EmitCount")).
	local PRESETS = {
		Sparks = function(emitter)
			emitter.Texture = TEXTURE_SPARKLES
			emitter.Color = ColorSequence.new(BK.hex("#FFD38A"), BK.hex("#E07A1F"))
			emitter.Size = NumberSequence.new(0.25, 0)
			emitter.Lifetime = NumberRange.new(0.3, 0.6)
			emitter.Speed = NumberRange.new(15, 30)
			emitter.SpreadAngle = Vector2.new(60, 60)
			emitter.Acceleration = Vector3.new(0, -60, 0)
			emitter.LightEmission = 1
			emitter.Enabled = false
			emitter:SetAttribute("EmitCount", 25)
		end,
		Smoke = function(emitter)
			emitter.Texture = TEXTURE_SMOKE
			emitter.Color = ColorSequence.new(BK.hex("#3A3D42"))
			emitter.Size = NumberSequence.new(3, 8)
			emitter.Transparency = NumberSequence.new(0.4, 1)
			emitter.Lifetime = NumberRange.new(2, 3)
			emitter.Speed = NumberRange.new(4, 8)
			emitter.Rate = 12
			emitter.RotSpeed = NumberRange.new(-30, 30)
		end,
		DustPuffOutdoor = function(emitter)
			dustPuff(emitter, "#8C7B66")
		end,
		DustPuffHangar = function(emitter)
			dustPuff(emitter, "#5A5E63")
		end,
		AshFlakes = function(emitter)
			emitter.Color = ColorSequence.new(BK.hex("#9C9893"))
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15, 0.05),
				NumberSequenceKeypoint.new(1, 0.15, 0.05),
			})
			emitter.Lifetime = NumberRange.new(8)
			emitter.Speed = NumberRange.new(1, 3)
			emitter.Acceleration = Vector3.new(2, -1.5, 0)
			emitter.Rate = 40
		end,
		TitanRegen = function(emitter)
			emitter.Color = ColorSequence.new(BK.hex("#9C9893"))
			emitter.Size = NumberSequence.new(1, 3)
			emitter.Transparency = NumberSequence.new(0.6, 1)
			emitter.Rate = 6
			emitter.Enabled = false
		end,
	}

	BK.emitterPresets = { "AshFlakes", "DustPuffHangar", "DustPuffOutdoor", "Smoke", "Sparks", "TitanRegen" }

	function BK.emitter(onPart, presetName)
		local preset = PRESETS[presetName]
		if not preset then
			error(("[BuildKit] BK.emitter: unknown preset '%s' (valid: %s)"):format(tostring(presetName), table.concat(BK.emitterPresets, ", ")), 2)
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = presetName
		preset(emitter)
		emitter:SetAttribute("Preset", presetName)
		emitter.Parent = onPart
		return emitter
	end
end
