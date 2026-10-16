--!nonstrict
-- builders/lib/Props/init.lua  ->  ServerStorage.DevTools.Props (ModuleScript with child modules)
--
-- The props catalog of docs/07_building_with_parts.md §6: one function per prop,
--   Props.<Name>(parent, cframe, opts) -> Model      (PrimaryPart set, so it moves as a unit)
-- Floor props: `cframe` is the bottom-center on the floor, facing -Z. "Facing" is the prop's front: the side its
-- user stands or sits at, the side a screen or sign shows. A console its operator faces north is placed facing +Z.
-- Wall props (Banner, Poster, Vent, HoloPanel's wall mount): `cframe` is the center of the back face, on the wall
-- surface, its -Z pointing out of the wall.
--
--   local BK = require(DT.BuildKit:Clone())
--   local Props = require(DT.Props:Clone())(BK)
--   Props.Console(folder, CFrame.new(x, 0, z) * Props.FACE["+Z"], { lines = { ... } })
--
-- Child modules (each returns function(Props, BK) and adds its props): Furniture, Display.
-- Dev-time only: game code must never require anything under ServerStorage.DevTools.

return function(BK)
	local P = BK.Palette
	local Props = { BK = BK, P = P }

	-- Rotations that turn a prop's front (-Z) toward a world direction.
	Props.FACE = {
		["-Z"] = CFrame.identity,
		["+Z"] = CFrame.Angles(0, math.pi, 0),
		["+X"] = CFrame.Angles(0, -math.pi / 2, 0),
		["-X"] = CFrame.Angles(0, math.pi / 2, 0),
	}

	Props.FONT = {
		header = Font.fromEnum(Enum.Font.Michroma),
		body = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold),
		mono = Font.fromEnum(Enum.Font.RobotoMono),
	}

	-- Colors from docs/06 §3 (the prop recipes' own hexes are in their functions).
	Props.SCREEN_BASE = BK.hex("#1B2A33")
	-- Holograms and glows are amber (the Directorate's color; cyan stays reserved), drawn with BuildKit's calibrated
	-- Neon (BK.GLOW, D-099). `Props.glow` is the props table of an amber glowing part.
	Props.HOLO = BK.GLOW.holo.Color
	Props.glow = { Color = BK.GLOW.amber.Color, Material = "Neon", Transparency = BK.GLOW.amber.Transparency }

	---------------------------------------------------------------------------
	-- A kit builds one prop model in the prop's local frame (x right, y up, -z front).
	---------------------------------------------------------------------------
	function Props.kit(parent, name, cframe)
		local model = BK.model(parent, name)
		local kit = { model = model, cf = cframe }

		local function props(base, partName, size, localCF)
			local p = if base then table.clone(base) else {}
			p.Name = partName
			p.Size = size
			p.CFrame = cframe * localCF
			p.Position = nil
			p.Orientation = nil
			return p
		end

		-- An axis-aligned box centered at local `pos`.
		function kit.box(partName, size, pos, base)
			return BK.part(model, props(base, partName, size, CFrame.new(pos)))
		end
		-- A box at any local CFrame.
		function kit.part(partName, size, localCF, base)
			return BK.part(model, props(base, partName, size, localCF))
		end
		function kit.wedge(partName, size, localCF, base)
			return BK.wedge(model, props(base, partName, size, localCF))
		end
		function kit.ball(partName, diameter, pos, base)
			return BK.ball(model, props(base, partName, Vector3.one * diameter, CFrame.new(pos)))
		end
		-- A cylinder whose length runs along the local axis "X" | "Y" | "Z" (BK.cyl's logical box).
		function kit.cyl(partName, axis, size, localCF, base)
			local p = props(base, partName, size, if typeof(localCF) == "Vector3" then CFrame.new(localCF) else localCF)
			p.Axis = axis
			return BK.cyl(model, p)
		end
		-- A thin box from local point a to local point b.
		function kit.beam(partName, a, b, width, height, base)
			local w = cframe:PointToWorldSpace(a)
			local v = cframe:PointToWorldSpace(b)
			return BK.beam(model, partName, w, v, width, height, base)
		end
		function kit.world(localCF)
			return cframe * localCF
		end
		function kit.finish(primary)
			model.PrimaryPart = primary or model:FindFirstChildWhichIsA("BasePart")
			return model
		end
		return kit
	end

	---------------------------------------------------------------------------
	-- Surface GUIs (docs/06 §7: 50 px per stud, LightInfluence 0 for screens, 0.6 for painted signs)
	---------------------------------------------------------------------------
	function Props.gui(part, face, lightInfluence, pixelsPerStud)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face"
		gui.Face = face or Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or 50
		gui.LightInfluence = lightInfluence or 0
		gui.ClipsDescendants = true
		gui.Parent = part
		return gui
	end

	-- A text label in scale units. opts: font, color, xAlign ("Left" | "Center" | "Right"), transparency, name.
	function Props.label(parent, text, x, y, w, h, opts)
		opts = opts or {}
		local label = Instance.new("TextLabel")
		label.Name = opts.name or "Label"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(w, h)
		label.FontFace = opts.font or Props.FONT.mono
		label.Text = text
		label.TextScaled = true
		label.TextWrapped = opts.wrap == true
		label.TextColor3 = BK.toColor(opts.color or P.AMBER)
		label.TextTransparency = opts.transparency or 0
		label.TextXAlignment = Enum.TextXAlignment[opts.xAlign or "Left"]
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = parent
		return label
	end

	-- A filled rectangle in scale units.
	function Props.rect(parent, x, y, w, h, color, transparency, name)
		local frame = Instance.new("Frame")
		frame.Name = name or "Rect"
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(w, h)
		frame.BackgroundColor3 = BK.toColor(color)
		frame.BackgroundTransparency = transparency or 0
		frame.Parent = parent
		return frame
	end

	-- The Division insignia (docs/02 §4): an amber chevron over a stylized wall, "3 wedges plus a bar", drawn in
	-- the plane of local XY at `at` (a local CFrame on a face, -Z out), `width` across. Returns nothing.
	function Props.insignia(kit, at, width, color)
		local c = { Color = color or P.AMBER, Material = "SmoothPlastic", CanCollide = false, CastShadow = false, Tags = { "Detail" } }
		local s = width
		local t = 0.05
		-- The wall: a bar with three merlons.
		kit.part("Insignia_Wall", Vector3.new(s, 0.16 * s, t), at * CFrame.new(0, -0.3 * s, 0), c)
		for i = -1, 1 do
			kit.part("Insignia_Merlon", Vector3.new(0.16 * s, 0.08 * s, t), at * CFrame.new(i * 0.38 * s, -0.18 * s, 0), c)
		end
		-- The chevron (an upward ^): two arms from the feet (+-0.42, -0.06) to the apex (0, 0.28), and a pointed cap
		-- of two wedges back to back over the joint (a wedge turned -90 about Y has its vertical leg on its left).
		local angle = math.atan2(0.34, 0.42)
		local arm = math.sqrt(0.34 ^ 2 + 0.42 ^ 2) * s
		for _, side in ipairs({ -1, 1 }) do
			kit.part("Insignia_Arm", Vector3.new(arm, 0.13 * s, t), at * CFrame.new(side * 0.21 * s, 0.11 * s, 0) * CFrame.Angles(0, 0, -side * angle), c)
		end
		local half, tall = 0.13 * s, 0.16 * s
		kit.wedge("Insignia_Apex_L", Vector3.new(t, tall, half), at * CFrame.new(-half / 2, 0.3 * s + tall / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), c)
		kit.wedge("Insignia_Apex_R", Vector3.new(t, tall, half), at * CFrame.new(half / 2, 0.3 * s + tall / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), c)
	end

	for _, name in ipairs({ "Furniture", "Display" }) do
		local child = script:FindFirstChild(name)
		if not child then
			error("[Props] child module '" .. name .. "' is missing")
		end
		require(child)(Props, BK)
	end

	return Props
end
