--!nonstrict
-- Props/Display: Console, HoloTable, HoloPanel, Banner, Flag, Poster, Vent, CableRun.
-- Recipes: docs/07_building_with_parts.md §6. Holograms are amber AMBER_LAMP Neon; parts tagged `Hologram` shimmer
-- on clients, `HoloBlink` parts blink at their BlinkHz, `HoloSweep` parts turn around their PivotCenter
-- (Client/Controllers/AmbientController).

local V = Vector3.new

return function(Props, BK)
	local P = Props.P
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }

	local function with(base, extra)
		local t = table.clone(base)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	local holo = with(soft, { Color = Props.HOLO, Material = "Neon", Transparency = BK.GLOW.holo.Transparency, Tags = { "Hologram" } })

	-- Console 6 x 3 x 2.5: base STEEL_DARK 6 x 2.6 x 2.5; a slanted top STEEL_MID; a Neon #1B2A33 screen 4.6 x 1.6 at
	-- a 25 degree tilt (read as from the horizontal, a desk slope: the slope makes the console 3.3 tall) with three
	-- lines of amber text and a bar graph; a keyboard strip 3.8 x 0.15 x 0.6 KICKPLATE on the ledge in front.
	-- opts.lines (3 strings), opts.seed (bar heights), opts.holo = true adds a small projection above the back.
	function Props.Console(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Console", cframe)
		local rng = BK.rng(opts.seed or 7)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local base = k.box("Base", V(6, 2.6, 2.5), V(0, 1.3, 0), steel)
		k.box("Kick", V(5.8, 0.4, 0.06), V(0, 0.2, -1.27), with({ Color = P.KICKPLATE }, soft))
		-- The slope rises toward the back: a wedge 6 wide, 0.68 tall, 1.45 deep on the back of the top.
		local tilt = math.rad(25)
		local depth = 1.6 * math.cos(tilt)
		local rise = 1.6 * math.sin(tilt)
		k.wedge("Slope", V(6, rise, depth), CFrame.new(0, 2.6 + rise / 2, 1.25 - depth / 2), { Color = P.STEEL_MID, Material = "Metal" })
		k.box("Ledge", V(6, 0.1, 2.5 - depth), V(0, 2.65, -1.25 + (2.5 - depth) / 2), with({ Color = P.STEEL_MID, Material = "Metal" }, soft))
		k.box("Keyboard", V(3.8, 0.15, 0.6), V(0, 2.775, -0.62), with({ Color = P.KICKPLATE }, soft))
		for i = 0, 9 do
			k.box("Key" .. i, V(0.28, 0.04, 0.4), V(-1.6 + i * 0.355, 2.87, -0.62), with({ Color = P.STEEL_MID }, soft))
		end
		-- The screen lies on the slope, 0.03 proud of it; its Front face is the slope's face (normal up and toward
		-- the operator), so the text's top edge points up the slope.
		local normal = V(0, math.cos(tilt), -math.sin(tilt))
		local center = V(0, 2.6 + rise / 2, 1.25 - depth / 2) + normal * 0.03
		local screen = k.part("Screen", V(4.6, 1.4, 0.04), CFrame.lookAt(center, center + normal), {
			Color = Props.SCREEN_BASE, Material = "Neon", Transparency = 0.3, CanCollide = false, CastShadow = false, CanQuery = false,
		})
		local gui = Props.gui(screen, Enum.NormalId.Front, 0, 60)
		gui.Name = "ScreenGui"
		Props.rect(gui, 0, 0, 1, 1, Props.SCREEN_BASE, 0.1, "Back")
		local lines = opts.lines or { "LINK 04 · NOMINAL", "SECTOR GRID 7-E", "CORRIDOR TRAFFIC 112" }
		for i, line in ipairs(lines) do
			Props.label(gui, line, 0.04, 0.1 + (i - 1) * 0.26, 0.5, 0.18, { name = "Line" .. i, color = if i == 1 then P.AMBER else P.AMBER_LAMP })
		end
		for b = 0, 7 do
			local h = rng.next(0.2, 0.75)
			Props.rect(gui, 0.6 + b * 0.045, 0.85 - h, 0.03, h, P.AMBER, 0.25, "Bar" .. b)
		end
		Props.rect(gui, 0.58, 0.86, 0.38, 0.02, P.AMBER, 0.5, "Axis")
		-- Status lights on the ledge left of the keyboard and a cable leaving the back.
		for i = 0, 3 do
			local lamp = if i == 3 and opts.alert then { Color = P.DANGER_RED, Material = "Neon" } else Props.glow
			k.box("Lamp" .. i, V(0.16, 0.05, 0.16), V(2.2 + (i % 2) * 0.3, 2.72, -0.85 + math.floor(i / 2) * 0.3), with(lamp, soft))
		end
		k.box("CableOut", V(0.25, 0.25, 1.2), V(2.4, 0.12, 1.85), with({ Color = P.HAZARD_BLACK }, soft))
		if opts.holo then
			local panel = k.part("HoloSlab", V(2.4, 1.0, 0.04), CFrame.new(-1.5, 2.6 + rise + 0.9, 1.0) * CFrame.Angles(math.rad(-8), 0, 0), with(holo, { Transparency = 0.8 }))
			local hg = Props.gui(panel, Enum.NormalId.Front, 0, 60)
			Props.label(hg, opts.holo == true and "UPLINK" or tostring(opts.holo), 0.05, 0.05, 0.9, 0.3, { color = P.AMBER, font = Props.FONT.header })
			for b = 0, 5 do
				Props.rect(hg, 0.08 + b * 0.14, 0.45 + rng.next(0, 0.3), 0.09, 0.04, P.AMBER, 0.2, "Tick" .. b)
			end
			k.box("Emitter", V(0.5, 0.1, 0.5), V(-1.5, 2.6 + rise + 0.05, 1.0), with(Props.glow, soft))
		end
		return k.finish(base)
	end

	-- Holo-table, diameter 20 x 3.2: base cylinder STEEL_DARK 20 x 2.8; rim ring AMBER Neon 0.3; a top glass disc;
	-- the hologram (map_01 §3): the territory in 25-40 small transparent Neon AMBER_LAMP parts — New Halden (a block
	-- cluster west), the Bulwark line, corridor lines, terrain, the outposts, Outpost 07's red marker 41 km east
	-- (blinks 1 Hz on clients: HoloBlink) — plus a slow scan sweep and three floating labels facing south.
	-- opts.markerName names the Outpost 07 marker part.
	function Props.HoloTable(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "HoloTable", cframe)
		local base = k.cyl("Base", "Y", V(20, 2.4, 20), V(0, 1.6, 0), { Color = P.STEEL_DARK, Material = "Metal" })
		k.cyl("Toe", "Y", V(19, 0.4, 19), V(0, 0.2, 0), { Color = P.KICKPLATE })
		k.cyl("Rim", "Y", V(20.1, 0.3, 20.1), V(0, 2.95, 0), with(Props.glow, soft))
		k.cyl("Inner", "Y", V(19.4, 0.34, 19.4), V(0, 2.95, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		k.cyl("Glass", "Y", V(19.4, 0.08, 19.4), V(0, 3.16, 0), { Color = P.GLASS, Material = "Glass", Transparency = 0.45, CastShadow = false })
		-- Panel seams down the drum and eight lit service ports.
		for i = 0, 7 do
			local a = math.rad(i * 45 + 22.5)
			local dir = V(math.sin(a), 0, math.cos(a))
			k.part("Seam" .. i, V(0.2, 2.3, 0.1), CFrame.lookAt(dir * 10.0 + V(0, 1.6, 0), dir * 20 + V(0, 1.6, 0)), with({ Color = P.KICKPLATE }, soft))
			local b = math.rad(i * 45)
			local d2 = V(math.sin(b), 0, math.cos(b))
			k.part("Port" .. i, V(1.2, 0.18, 0.08), CFrame.lookAt(d2 * 9.98 + V(0, 2.2, 0), d2 * 20 + V(0, 2.2, 0)), with(Props.glow, soft))
		end
		-- The projection floor and the hologram (local +X east, -Z north; one map unit = 1 stud).
		k.cyl("ProjectionDisc", "Y", V(17, 0.02, 17), V(0, 3.22, 0), with(holo, { Transparency = 0.9 }))
		local y0 = 3.25
		local rng = BK.rng(2187)
		-- New Halden: a cluster of 10 blocks west.
		local city = { { -6.6, -0.8 }, { -5.8, 0.4 }, { -6.9, 1.2 }, { -5.2, -1.6 }, { -4.6, 0.9 }, { -7.4, -0.1 }, { -6.0, 2.0 }, { -4.9, -0.4 }, { -5.6, -2.4 }, { -7.0, -1.8 } }
		for i, c in ipairs(city) do
			local h = rng.next(0.4, 1.7)
			k.box("City" .. i, V(rng.next(0.6, 1.0), h, rng.next(0.6, 1.0)), V(c[1], y0 + h / 2, c[2]), holo)
		end
		-- The Bulwark: a long wall line north-south east of the city, with four tower blocks.
		k.box("Bulwark", V(0.35, 0.8, 13), V(-3.4, y0 + 0.4, 0), holo)
		for i, z in ipairs({ -5, -1.7, 1.7, 5 }) do
			k.box("BulwarkTower" .. i, V(0.6, 1.2, 0.6), V(-3.4, y0 + 0.6, z), holo)
		end
		-- Corridor lines east from the Bulwark and the outposts at their ends (07 is the red marker).
		local outposts = { { 3.2, -4.6 }, { 4.6, 3.8 }, { 2.0, 1.2 }, { 5.2, -1.4 }, { 3.6, 5.6 } }
		for i, o in ipairs(outposts) do
			k.beam("Corridor" .. i, V(-3.2, y0 + 0.05, o[2] * 0.4), V(o[1], y0 + 0.05, o[2]), 0.1, 0.05, holo)
			k.box("Outpost" .. i, V(0.4, 0.4, 0.4), V(o[1], y0 + 0.2, o[2]), holo)
		end
		k.beam("Corridor07", V(-3.2, y0 + 0.05, -0.8), V(6.6, y0 + 0.05, -2.6), 0.12, 0.05, holo)
		-- Terrain east of the wall: low ridges and the dry basin north of 07 (a ring of four blocks).
		for i = 1, 8 do
			local x, z = rng.next(-1.5, 7), rng.next(-6.5, 6.5)
			local h = rng.next(0.12, 0.45)
			k.part("Ridge" .. i, V(rng.next(1.2, 2.6), h, rng.next(0.4, 0.9)), CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, rng.next(-0.8, 0.8), 0), holo)
		end
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			k.part("Basin" .. i, V(1.0, 0.12, 0.2), CFrame.new(6.6 + math.sin(a) * 0.7, y0 + 0.06, -4.6 + math.cos(a) * 0.7) * CFrame.Angles(0, a, 0), holo)
		end
		local marker = k.part(opts.markerName or "Outpost07_Marker", V(0.6, 0.6, 0.6), CFrame.new(6.6, y0 + 0.9, -2.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)), with(soft, { Color = P.DANGER_RED, Material = "Neon", Transparency = 0.2, Tags = { "HoloBlink" }, Attributes = { BlinkHz = 1 } }))
		k.box("Outpost07_Beam", V(0.08, 3.2, 0.08), V(6.6, y0 + 1.6, -2.6), with(soft, { Color = P.DANGER_RED, Material = "Neon", Transparency = 0.6, Tags = { "HoloBlink" }, Attributes = { BlinkHz = 1 } }))
		-- The sweep: a faint vertical plane turning about the table's axis.
		local pivot = cframe.Position + V(0, y0 + 1.2, 0)
		k.part("Sweep", V(8.4, 2.4, 0.02), CFrame.new(4.2, y0 + 1.2, 0), with(holo, { Transparency = 0.88, Tags = { "HoloSweep" }, Attributes = { PivotCenter = pivot, Radius = 4.2, Period = 6 } }))
		-- Labels standing above the map, readable from the south (the side the hall's entrances are on).
		local function tag(name, text, x, z, w, y)
			local part = k.part(name, V(w, 0.5, 0.02), CFrame.new(x, y0 + y, z) * CFrame.Angles(0, math.pi, 0), with(holo, { Transparency = 1 }))
			local gui = Props.gui(part, Enum.NormalId.Front, 0, 60)
			Props.label(gui, text, 0, 0, 1, 1, { color = P.AMBER_LAMP, xAlign = "Center", font = Props.FONT.header })
			return part
		end
		tag("Label_NewHalden", "NEW HALDEN", -6.0, 0.2, 3.6, 2.6)
		tag("Label_Bulwark", "THE BULWARK", -3.4, 4.0, 3.4, 1.7)
		tag("Label_Outpost07", "OUTPOST 07 · 41 KM", 6.0, -2.6, 4.2, 3.5)
		return k.finish(base), marker
	end

	-- HoloPanel (new, docs/07 §6): a floating amber projection W x H — a calibrated amber Neon plane at 0.8, a SurfaceGui
	-- title and lines, two edge lines; with opts.emitter = the drop to an emitter puck below it and a faint beam.
	-- cframe = the panel's center, facing -Z. opts: size (Vector2), title, lines, emitter, name, bars (true),
	-- titleHeight / lineHeight (fractions of the panel, 0.2 / 0.12), backFace (true: the text shows from behind too).
	function Props.HoloPanel(parent, cframe, opts)
		opts = opts or {}
		local size = opts.size or Vector2.new(3, 2)
		local k = Props.kit(parent, opts.name or "HoloPanel", cframe)
		local plane = k.box("Plane", V(size.X, size.Y, 0.03), V(0, 0, 0), with(holo, { Transparency = 0.8 }))
		k.box("EdgeTop", V(size.X, 0.05, 0.03), V(0, size.Y / 2, 0), with(holo, { Transparency = 0.45 }))
		k.box("EdgeBottom", V(size.X, 0.05, 0.03), V(0, -size.Y / 2, 0), with(holo, { Transparency = 0.45 }))
		local guis = { Props.gui(plane, Enum.NormalId.Front, 0, 60) }
		if opts.backFace ~= false then
			local backGui = Props.gui(plane, Enum.NormalId.Back, 0, 60)
			backGui.Name = "BackFace"
			table.insert(guis, backGui)
		end
		local titleHeight = opts.titleHeight or 0.2
		local lineHeight = opts.lineHeight or 0.12
		for _, g in ipairs(guis) do
			Props.label(g, opts.title or "", 0.05, 0.05, 0.9, titleHeight, { color = P.AMBER, font = Props.FONT.header, name = "Title" })
			for i, line in ipairs(opts.lines or {}) do
				Props.label(g, line, 0.05, 0.1 + titleHeight + (i - 1) * (lineHeight + 0.03), 0.9, lineHeight, { color = P.AMBER_LAMP, name = "Line" .. i })
			end
			if opts.bars ~= false and not opts.lines then
				local rng = BK.rng(math.floor(size.X * 100 + size.Y))
				for b = 0, 9 do
					local h = rng.next(0.1, 0.55)
					Props.rect(g, 0.08 + b * 0.085, 0.9 - h, 0.05, h, P.AMBER, 0.3, "Bar" .. b)
				end
			end
		end
		if opts.emitter then
			local drop = opts.emitter
			local bottom = -size.Y / 2
			k.cyl("Puck", "Y", V(0.7, 0.14, 0.7), V(0, bottom - drop + 0.07, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
			k.cyl("Lens", "Y", V(0.4, 0.04, 0.4), V(0, bottom - drop + 0.16, 0), with(Props.glow, soft))
			k.box("Beam", V(size.X * 0.9, drop, 0.02), V(0, bottom - drop / 2, 0), with(holo, { Transparency = 0.93 }))
		end
		return k.finish(plane)
	end

	-- Banner 4 x 12 x 0.2: Fabric SLATE_DEEP, the amber Division insignia (chevron over a wall), amber edge bands, a
	-- hanging rod on two brackets. Wall prop: cframe = the center of its back on the wall, -Z out of the wall.
	function Props.Banner(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Banner", cframe)
		local cloth = k.box("Cloth", V(4, 12, 0.2), V(0, 0, -0.35), { Color = P.SLATE_DEEP, Material = "Fabric", CanCollide = false })
		k.box("BandTop", V(4, 0.25, 0.04), V(0, 5.4, -0.47), with({ Color = P.AMBER }, soft))
		k.box("BandBottom", V(4, 0.25, 0.04), V(0, -5.4, -0.47), with({ Color = P.AMBER }, soft))
		k.box("StripeL", V(0.12, 10.4, 0.04), V(-1.75, 0, -0.47), with({ Color = P.SLATE }, soft))
		k.box("StripeR", V(0.12, 10.4, 0.04), V(1.75, 0, -0.47), with({ Color = P.SLATE }, soft))
		Props.insignia(k, CFrame.new(0, 2.0, -0.475), 2.6)
		k.cyl("Rod", "X", V(4.8, 0.25, 0.25), V(0, 6.15, -0.35), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		for _, x in ipairs({ -2.1, 2.1 }) do
			k.box("Bracket", V(0.2, 0.2, 0.45), V(x, 6.15, -0.18), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
			k.ball("Finial", 0.35, V(x * 1.17, 6.15, -0.35), with({ Color = P.AMBER, Material = "Metal" }, soft))
		end
		return k.finish(cloth)
	end

	-- Scanner arch 7 x 9 x 2 (docs/07 §6): two MEDICAL_WHITE pillars and a top beam, LIGHT_COOL Neon strips on their
	-- inner faces, a floor plate. One walks through it along local Z. (S41's moving ring is a runtime effect.)
	function Props.ScannerArch(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "ScannerArch", cframe)
		local white = { Color = P.MEDICAL_WHITE, Material = "SmoothPlastic" }
		local cool = with({ Color = P.LIGHT_COOL, Material = "Neon" }, soft)
		local left = k.box("PillarL", V(1.2, 9, 2), V(-2.9, 4.5, 0), white)
		k.box("PillarR", V(1.2, 9, 2), V(2.9, 4.5, 0), white)
		k.box("Beam", V(7, 1.2, 2), V(0, 8.4, 0), white)
		k.box("StripL", V(0.1, 7.4, 0.5), V(-2.28, 4.2, 0), cool)
		k.box("StripR", V(0.1, 7.4, 0.5), V(2.28, 4.2, 0), cool)
		k.box("StripTop", V(4.5, 0.1, 0.5), V(0, 7.78, 0), cool)
		k.box("FloorPlate", V(4.6, 0.05, 2.4), V(0, 0.025, 0), with({ Color = P.STEEL_LIGHT, Material = "DiamondPlate" }, soft))
		for _, z in ipairs({ -1.15, 1.15 }) do
			k.box("FloorLine", V(4.4, 0.06, 0.12), V(0, 0.03, z), cool)
		end
		local screen = k.box("Screen", V(0.9, 0.6, 0.05), V(-2.9, 6.2, -1.03), with({ Color = Props.SCREEN_BASE, Material = "Neon", Transparency = 0.3 }, soft))
		local gui = Props.gui(screen, Enum.NormalId.Front, 0, 120)
		Props.label(gui, "SCAN · READY", 0.05, 0.2, 0.9, 0.6, { color = P.LIGHT_COOL, xAlign = "Center" })
		return k.finish(left)
	end

	-- Flag (new, docs/07 §6) 3.2 x 8.8 x 1.2: the Directorate's flag on a stand — a weighted base, a pole with an amber
	-- finial, a crossbar, a SLATE cloth with the Division insignia and an amber band. Faces -Z; the cloth hangs to -X.
	function Props.Flag(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Flag", cframe)
		local metal = with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft)
		local base = k.cyl("Base", "Y", V(1.2, 0.3, 1.2), V(0, 0.15, 0), { Color = P.STEEL_DARK, Material = "Metal" })
		k.cyl("Pole", "Y", V(0.22, 8.4, 0.22), V(0, 4.3, 0), metal)
		k.ball("Finial", 0.4, V(0, 8.6, 0), with({ Color = P.AMBER, Material = "Metal" }, soft))
		k.box("Crossbar", V(3.2, 0.12, 0.12), V(-1.6, 8.2, 0), metal)
		k.box("Cloth", V(3.0, 4.2, 0.08), V(-1.65, 6.0, 0), with({ Color = P.SLATE, Material = "Fabric" }, soft))
		k.box("ClothBand", V(3.0, 0.2, 0.1), V(-1.65, 4.0, 0), with({ Color = P.AMBER }, soft))
		Props.insignia(k, CFrame.new(-1.65, 6.3, -0.065), 1.8)
		return k.finish(base)
	end

	-- Poster 3 x 4 x 0.05: a SurfaceGui with a propaganda line and a blocky Frame silhouette made of UI Frames.
	-- Wall prop (cframe = center of its back on the wall). opts.text, opts.partName (the prompt part's name).
	function Props.Poster(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Poster", cframe)
		local sheet = k.box(opts.partName or "Sheet", V(3, 4, 0.05), V(0, 0, -0.03), { Color = P.SLATE_DEEP, CanCollide = false, CastShadow = false })
		local gui = Props.gui(sheet, Enum.NormalId.Front, 0.6, 80)
		Props.rect(gui, 0, 0, 1, 1, P.SLATE_DEEP, 0, "Paper")
		-- A sunburst behind the machine: amber rays as thin rotated frames.
		for i = 0, 8 do
			local ray = Props.rect(gui, 0.48, 0.05, 0.04, 0.6, P.AMBER, 0.55, "Ray" .. i)
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.42)
			ray.Rotation = -80 + i * 20
		end
		Props.rect(gui, 0, 0.66, 1, 0.34, P.HAZARD_BLACK, 0, "Band")
		-- The Frame: head, shoulders, torso, arms, legs, a blade, a visor.
		local body = P.STEEL_DARK
		Props.rect(gui, 0.44, 0.14, 0.12, 0.08, body, 0, "Head")
		Props.rect(gui, 0.46, 0.165, 0.08, 0.02, P.AMBER_CORE, 0, "Visor")
		Props.rect(gui, 0.3, 0.22, 0.4, 0.08, body, 0, "Shoulders")
		Props.rect(gui, 0.38, 0.3, 0.24, 0.18, body, 0, "Torso")
		Props.rect(gui, 0.46, 0.33, 0.08, 0.05, P.AMBER_CORE, 0, "Core")
		Props.rect(gui, 0.3, 0.3, 0.07, 0.2, body, 0, "ArmL")
		Props.rect(gui, 0.63, 0.3, 0.07, 0.2, body, 0, "ArmR")
		Props.rect(gui, 0.66, 0.08, 0.03, 0.3, P.STEEL_LIGHT, 0, "Blade")
		Props.rect(gui, 0.39, 0.48, 0.09, 0.2, body, 0, "LegL")
		Props.rect(gui, 0.52, 0.48, 0.09, 0.2, body, 0, "LegR")
		Props.label(gui, opts.text or "THE FRAME STANDS. HUMANITY STANDS.", 0.06, 0.7, 0.88, 0.18, { color = P.AMBER, xAlign = "Center", font = Props.FONT.header, wrap = true })
		Props.label(gui, "THIRD FRONTIER FRAME DIVISION", 0.1, 0.9, 0.8, 0.05, { color = P.SIGN_WHITE, xAlign = "Center", font = Props.FONT.body })
		-- Four pins in the corners.
		for _, c in ipairs({ { -1.35, 1.85 }, { 1.35, 1.85 }, { -1.35, -1.85 }, { 1.35, -1.85 } }) do
			k.box("Pin", V(0.1, 0.1, 0.04), V(c[1], c[2], -0.07), with({ Color = P.STEEL_LIGHT }, soft))
		end
		return k.finish(sheet)
	end

	-- Vent 4 x 3 x 0.5: a frame and six slats STEEL_DARK, plus docs/07 §7's grime strip under it (2 long).
	-- Wall prop (cframe = center of its back on the wall). opts.grime = false leaves the strip out.
	function Props.Vent(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Vent", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local back = k.box("Back", V(3.6, 2.6, 0.1), V(0, 0, -0.05), with({ Color = P.HAZARD_BLACK }, soft))
		k.box("FrameT", V(4, 0.2, 0.5), V(0, 1.4, -0.25), with(steel, soft))
		k.box("FrameB", V(4, 0.2, 0.5), V(0, -1.4, -0.25), with(steel, soft))
		k.box("FrameL", V(0.2, 2.6, 0.5), V(-1.9, 0, -0.25), with(steel, soft))
		k.box("FrameR", V(0.2, 2.6, 0.5), V(1.9, 0, -0.25), with(steel, soft))
		for i = 0, 5 do
			k.part("Slat" .. i, V(3.6, 0.32, 0.06), CFrame.new(0, 1.05 - i * 0.42, -0.25) * CFrame.Angles(math.rad(35), 0, 0), with(steel, soft))
		end
		if opts.grime ~= false then
			k.box("Grime", V(2, 0.9, 0.1), V(0, -1.95, -0.05), with(soft, { Color = P.KICKPLATE, Transparency = 0.6 }))
		end
		return k.finish(back)
	end

	-- CableRun (floor), from a to b (world points on the floor): 2-3 thin dark cylinders #1B1D20 side by side with a
	-- clamp every 6 studs. Not a cframe prop: it follows its two points.
	function Props.CableRun(parent, a, b, opts)
		opts = opts or {}
		local model = BK.model(parent, opts.name or "CableRun")
		local dir = (b - a) * V(1, 0, 1)
		local length = dir.Magnitude
		local cf = BK.lookAlong(a, dir.Unit)
		local count = opts.count or 3
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 0.22
			BK.cyl(model, with(soft, { Name = "Cable" .. i, Axis = "Z", Size = V(0.18, 0.18, length), CFrame = cf * CFrame.new(x, 0.09, -length / 2), Color = P.HAZARD_BLACK }))
		end
		for d = 3, length - 1, 6 do
			BK.part(model, with(soft, { Name = "Clamp", Size = V(count * 0.22 + 0.25, 0.24, 0.3), CFrame = cf * CFrame.new(0, 0.12, -d), Color = P.STEEL_MID, Material = "Metal" }))
		end
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		return model
	end
end
