--!nonstrict
-- Props/Furniture: Chair, Bench, Bunk, Locker (row), Desk, Terminal, PhotoFrame, DeskLamp, Mug, Datapad, Clipboard.
-- Recipes: docs/07_building_with_parts.md §6. Each prop's cframe is its bottom-center on the floor, facing -Z.

local V = Vector3.new

return function(Props, BK)
	local P = Props.P
	-- Detail parts never collide, cast shadows or answer queries (docs/07 §5); a queryable detail in front of a
	-- prompt's part blocks the prompt's line of sight (the photo's picture did).
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }

	local function with(base, extra)
		local t = table.clone(base)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- Chair 2 x 3.6 x 2: seat FABRIC_DARK, back, one central post, a 5-star base. opts.seat = seat top (1.0: the
	-- console chairs' height, D-081, so a seated body's feet reach the floor).
	function Props.Chair(parent, cframe, opts)
		opts = opts or {}
		local seat = opts.seat or 1.0
		local k = Props.kit(parent, opts.name or "Chair", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local fabric = { Color = P.FABRIC_DARK, Material = "Fabric" }
		for i = 0, 4 do
			local a = math.rad(i * 72 + 18)
			local dir = V(math.sin(a), 0, math.cos(a))
			k.part("Leg" .. i, V(0.22, 0.16, 0.9), CFrame.lookAt(dir * 0.45 + V(0, 0.2, 0), dir * 2 + V(0, 0.2, 0)), with(steel, soft))
			k.ball("Caster" .. i, 0.22, dir * 0.88 + V(0, 0.11, 0), with(steel, soft))
		end
		k.cyl("Post", "Y", V(0.28, seat - 0.45, 0.28), V(0, 0.28 + (seat - 0.45) / 2, 0), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		k.box("SeatPan", V(1.7, 0.12, 1.7), V(0, seat - 0.4, 0), with(steel, soft))
		local cushion = k.box("Seat", V(2, 0.34, 1.9), V(0, seat - 0.17, -0.05), fabric)
		local backTop = 3.6
		k.box("BackStrut", V(0.3, backTop - seat, 0.14), V(0, seat + (backTop - seat) / 2 - 0.2, 0.92), with(steel, soft))
		k.box("Back", V(1.9, backTop - seat - 0.6, 0.26), V(0, (seat + 0.5 + backTop) / 2, 0.85), fabric)
		k.box("BackSeam", V(1.5, 0.06, 0.04), V(0, (seat + 0.5 + backTop) / 2, 0.71), with({ Color = BK.darken(P.FABRIC_DARK, 0.25) }, soft))
		return k.finish(cushion)
	end

	-- Bench 8 x 1.8 x 1.6: a seat slab FABRIC_DARK over two legs STEEL_DARK. opts.height (Q-019 is open: 1.8).
	function Props.Bench(parent, cframe, opts)
		opts = opts or {}
		local h = opts.height or 1.8
		local w = opts.width or 8
		local k = Props.kit(parent, opts.name or "Bench", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local seat = k.box("Seat", V(w, 0.4, 1.6), V(0, h - 0.2, 0), { Color = P.FABRIC_DARK, Material = "Fabric" })
		k.box("SeatRail", V(w - 0.2, 0.12, 1.5), V(0, h - 0.46, 0), with(steel, soft))
		for _, x in ipairs({ -(w / 2 - 0.9), w / 2 - 0.9 }) do
			k.box("Leg", V(0.4, h - 0.4, 1.3), V(x, (h - 0.4) / 2, 0), steel)
			k.box("Foot", V(0.7, 0.1, 1.5), V(x, 0.05, 0), with(steel, soft))
		end
		return k.finish(seat)
	end

	-- Bunk 7 x 2 x 3.5 (long along local X, head at +X): frame STEEL_DARK, mattress FABRIC_DARK 6.6 x 0.6 x 3.2,
	-- pillow #B7BCC2, folded blanket #4A5A6A. Two storage drawers underneath.
	function Props.Bunk(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Bunk", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local base = k.box("Base", V(6.8, 0.9, 3.3), V(0, 0.55, 0), steel)
		for _, z in ipairs({ -1.65, 1.65 }) do
			k.box("Rail", V(7, 0.3, 0.2), V(0, 1.0, z), steel)
		end
		k.box("Headboard", V(0.25, 2.0, 3.5), V(3.375, 1.0, 0), steel)
		k.box("Footboard", V(0.25, 1.4, 3.5), V(-3.375, 0.7, 0), steel)
		for i, x in ipairs({ -1.6, 1.6 }) do
			k.box("Drawer" .. i, V(2.8, 0.6, 0.06), V(x, 0.5, -1.68), with({ Color = P.STEEL_MID, Material = "Metal" }, soft))
			k.box("DrawerPull" .. i, V(0.8, 0.08, 0.06), V(x, 0.62, -1.73), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		end
		local mattress = k.box("Mattress", V(6.6, 0.6, 3.2), V(0, 1.3, 0), { Color = P.FABRIC_DARK, Material = "Fabric" })
		k.box("Pillow", V(1.3, 0.35, 2.6), V(2.45, 1.75, 0), with({ Color = "#B7BCC2", Material = "Fabric" }, { CastShadow = true, CanCollide = false }))
		k.box("Blanket", V(1.7, 0.24, 3.0), V(-2.2, 1.72, 0), with({ Color = "#4A5A6A", Material = "Fabric" }, { CanCollide = false }))
		k.box("BlanketFold", V(1.7, 0.16, 3.0), V(-2.2, 1.92, 0.05), with({ Color = BK.darken(BK.hex("#4A5A6A"), 0.12), Material = "Fabric" }, soft))
		return k.finish(base)
	end

	-- Locker row: `count` lockers 2 x 7 x 2 side by side along local X. Body SLATE, door seams, three vent slits,
	-- a tiny white name plate. opts.names = { "VEYNE", ... } prints them on the plates (painted, LightInfluence 0.6).
	function Props.Locker(parent, cframe, opts)
		opts = opts or {}
		local count = opts.count or 1
		local k = Props.kit(parent, opts.name or "Locker", cframe)
		local dark = with({ Color = P.KICKPLATE }, soft)
		local first
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 2
			local body = k.box("Body" .. i, V(2, 7, 2), V(x, 3.5, 0), { Color = P.SLATE, Material = "Metal" })
			first = first or body
			k.box("Plinth" .. i, V(2, 0.4, 1.9), V(x, 0.2, 0.06), with({ Color = P.KICKPLATE }, soft))
			-- Door outline (the seam between neighbours is the door edge) and a handle.
			k.box("SeamL" .. i, V(0.06, 6.4, 0.04), V(x - 0.94, 3.7, -1.01), dark)
			k.box("SeamR" .. i, V(0.06, 6.4, 0.04), V(x + 0.94, 3.7, -1.01), dark)
			k.box("SeamT" .. i, V(1.88, 0.06, 0.04), V(x, 6.9, -1.01), dark)
			k.box("SeamB" .. i, V(1.88, 0.06, 0.04), V(x, 0.5, -1.01), dark)
			for s = 0, 2 do
				k.box("Vent" .. i .. "_" .. s, V(1.0, 0.08, 0.04), V(x, 6.2 - s * 0.22, -1.01), dark)
			end
			k.box("Handle" .. i, V(0.12, 0.7, 0.1), V(x + 0.7, 3.6, -1.05), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
			local plate = k.box("Plate" .. i, V(0.9, 0.28, 0.04), V(x, 5.25, -1.01), with({ Color = P.SIGN_WHITE }, soft))
			local name = opts.names and opts.names[i]
			if name then
				local gui = Props.gui(plate, Enum.NormalId.Front, 0.6, 100)
				Props.label(gui, name, 0.04, 0.05, 0.92, 0.9, { color = P.HAZARD_BLACK, xAlign = "Center", font = Props.FONT.header })
			end
		end
		return k.finish(first)
	end

	-- Desk 5 x 2.8 x 2.5: top #5A5F66, two side panels, a drawer block (right of the knee space), a modesty panel.
	function Props.Desk(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Desk", cframe)
		local panel = { Color = P.STEEL_MID, Material = "Metal" }
		local top = k.box("Top", V(5, 0.2, 2.5), V(0, 2.7, 0), { Color = "#5A5F66" })
		k.box("Edge", V(5, 0.08, 0.06), V(0, 2.62, -1.24), with({ Color = P.STEEL_DARK }, soft))
		k.box("SideL", V(0.2, 2.6, 2.4), V(-2.3, 1.3, 0), panel)
		k.box("SideR", V(0.2, 2.6, 2.4), V(2.3, 1.3, 0), panel)
		k.box("Modesty", V(4.4, 1.6, 0.1), V(0, 1.6, 1.1), panel)
		k.box("Drawers", V(1.6, 2.2, 2.2), V(1.4, 1.4, 0.05), panel)
		for d = 0, 2 do
			local y = 0.75 + d * 0.68
			k.box("DrawerSeam" .. d, V(1.5, 0.05, 0.04), V(1.4, y + 0.33, -1.06), with({ Color = P.KICKPLATE }, soft))
			k.box("DrawerPull" .. d, V(0.6, 0.08, 0.08), V(1.4, y + 0.05, -1.09), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		end
		return k.finish(top)
	end

	-- Terminal (desk-top) 1.8 x 1.4 x 0.3: a Neon #1B2A33 screen with amber text on a base stand.
	-- opts.screenName names the screen part (it carries prompts and runtime screens); opts.lines = text lines.
	function Props.Terminal(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Terminal", cframe)
		local steel = { Color = P.STEEL_DARK, Material = "Metal" }
		local foot = k.box("Foot", V(0.9, 0.08, 0.55), V(0, 0.04, 0.05), steel)
		k.box("Neck", V(0.16, 0.38, 0.12), V(0, 0.27, 0.12), with(steel, soft))
		k.box("Housing", V(1.8, 1.0, 0.22), V(0, 0.9, 0.08), steel)
		local screen = k.box(opts.screenName or "Screen", V(1.62, 0.84, 0.05), V(0, 0.9, -0.05), {
			Color = Props.SCREEN_BASE, Material = "Neon", Transparency = 0.3, CanCollide = false, CastShadow = false,
		})
		local gui = Props.gui(screen, Enum.NormalId.Front, 0, 100)
		gui.Name = "ScreenGui"
		Props.rect(gui, 0, 0, 1, 1, Props.SCREEN_BASE, 0.15, "Back")
		local lines = opts.lines or { "HALDEN CC", "" }
		for i, line in ipairs(lines) do
			Props.label(gui, line, 0.06, 0.08 + (i - 1) * 0.19, 0.88, 0.15, { color = if i == 1 then P.AMBER else P.AMBER_LAMP, name = "Line" .. i })
		end
		Props.rect(gui, 0.06, 0.86, 0.88, 0.03, P.AMBER, 0.4, "Rule")
		k.box("Led", V(0.08, 0.04, 0.03), V(0.75, 0.43, -0.04), with(Props.glow, soft))
		k.finish(foot)
		return k.model, screen
	end

	-- Photo frame 0.8 x 1 x 0.1, standing on a desk (leaning back 10 degrees on a strut): frame #3A2A1E; the photo
	-- is a SurfaceGui with "9TH FDU — 2180" and five simple silhouette blocks. opts.photoName names the frame part.
	function Props.PhotoFrame(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "PhotoFrame", cframe)
		local lean = CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-10), 0, 0)
		local frame = k.part(opts.photoName or "Frame", V(0.8, 1, 0.06), lean, { Color = "#3A2A1E", Material = "Wood", CanCollide = false })
		k.part("Strut", V(0.08, 0.8, 0.04), CFrame.new(0, 0.4, 0.2) * CFrame.Angles(math.rad(22), 0, 0), with({ Color = "#3A2A1E" }, soft))
		local photo = k.part("Photo", V(0.66, 0.84, 0.02), lean * CFrame.new(0, 0, -0.035), with({ Color = P.ASH }, soft))
		local gui = Props.gui(photo, Enum.NormalId.Front, 0.6, 200)
		Props.rect(gui, 0, 0, 1, 1, P.ASH, 0, "Paper")
		Props.rect(gui, 0, 0.62, 1, 0.38, P.ASH_DARK, 0, "Ground")
		-- Five figures (one unsmiling face is the joke of S02's line; at this size they are just blocks).
		for i = 1, 5 do
			local x = 0.08 + (i - 1) * 0.175
			local tall = if i == 3 then 0.36 else 0.33
			Props.rect(gui, x + 0.035, 0.66 - tall - 0.08, 0.07, 0.08, P.STEEL_DARK, 0, "Head" .. i)
			Props.rect(gui, x, 0.66 - tall, 0.14, tall, P.STEEL_DARK, 0, "Body" .. i)
		end
		Props.label(gui, "9TH FDU — 2180", 0.06, 0.82, 0.88, 0.12, { color = P.KICKPLATE, xAlign = "Center", font = Props.FONT.header })
		return k.finish(frame)
	end

	-- DeskLamp (new, docs/07 §6): a weighted base, a two-part arm and a shade over a warm bulb with a PointLight.
	-- opts.light = BK.light props (default: Quarters' lamp, AMBER_LAMP 0.8 / range 14 / shadows, docs/06 §5);
	-- false = no light. The shade leans toward -Z.
	function Props.DeskLamp(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "DeskLamp", cframe)
		local steel = with({ Color = P.STEEL_DARK, Material = "Metal" }, soft)
		local base = k.cyl("Base", "Y", V(0.6, 0.08, 0.6), V(0, 0.04, 0.15), steel)
		k.beam("ArmLow", V(0, 0.08, 0.15), V(0, 0.95, 0.3), 0.07, 0.07, steel)
		k.ball("Elbow", 0.13, V(0, 0.95, 0.3), steel)
		k.beam("ArmHigh", V(0, 0.95, 0.3), V(0, 1.22, -0.18), 0.07, 0.07, steel)
		k.cyl("Shade", "Y", V(0.55, 0.3, 0.55), CFrame.new(0, 1.12, -0.3) * CFrame.Angles(math.rad(-20), 0, 0), with({ Color = P.STEEL_MID, Material = "Metal" }, soft))
		local bulb = k.ball("Bulb", 0.2, V(0, 0.99, -0.33), with({ Color = P.AMBER_LAMP, Material = "Neon" }, soft))
		if opts.light ~= false then
			local light = opts.light or { Color = P.AMBER_LAMP, Brightness = 0.8, Range = 14, Shadows = true }
			BK.light(bulb, "Point", light)
		end
		return k.finish(base)
	end

	-- Bed (medical) 3.4 x 2.6 x 7 (long along local Z, the head at +Z): a MEDICAL_WHITE frame on wheels, a #C9D2DA
	-- mattress and pillow, side rails, a headboard, and a monitor on an arm with a heart-rate line (SUCCESS_GREEN is the
	-- UI's success color; a monitor is a screen). opts.name.
	function Props.MedBed(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "MedBed", cframe)
		local white = { Color = P.MEDICAL_WHITE, Material = "SmoothPlastic" }
		local frame = k.box("Frame", V(3.2, 0.5, 6.8), V(0, 1.55, 0), white)
		for _, c in ipairs({ { -1.4, -3.1 }, { 1.4, -3.1 }, { -1.4, 3.1 }, { 1.4, 3.1 } }) do
			k.box("Leg", V(0.2, 1.1, 0.2), V(c[1], 0.75, c[2]), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
			k.cyl("Wheel", "X", V(0.2, 0.4, 0.4), V(c[1], 0.2, c[2]), with({ Color = P.KICKPLATE }, soft))
		end
		k.box("Mattress", V(3.1, 0.5, 6.6), V(0, 2.05, -0.05), { Color = "#C9D2DA", Material = "Fabric" })
		k.box("Pillow", V(2.2, 0.3, 1.0), V(0, 2.45, 2.7), with({ Color = P.MEDICAL_WHITE, Material = "Fabric" }, soft))
		k.box("Blanket", V(3.15, 0.12, 3.2), V(0, 2.34, -1.4), with({ Color = "#C9D2DA", Material = "Fabric" }, soft))
		k.box("Headboard", V(3.4, 2.6, 0.2), V(0, 1.3 + 0.6, 3.4), white)
		for _, x in ipairs({ -1.7, 1.7 }) do
			k.box("Rail", V(0.08, 0.08, 3.2), V(x, 2.6, 0.6), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
			k.box("RailPost", V(0.08, 0.8, 0.08), V(x, 2.2, -0.9), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		end
		-- The monitor on an arm from the headboard's right side.
		k.box("ArmPost", V(0.15, 2.4, 0.15), V(1.5, 4.2, 3.4), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		k.box("ArmReach", V(0.12, 0.12, 0.9), V(1.5, 5.3, 2.95), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		k.box("MonitorBody", V(1.3, 0.9, 0.2), V(1.5, 5.1, 2.4), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		local screen = k.box("Monitor", V(1.15, 0.75, 0.04), V(1.5, 5.1, 2.29), with({ Color = Props.SCREEN_BASE, Material = "Neon", Transparency = 0.3 }, soft))
		local gui = Props.gui(screen, Enum.NormalId.Front, 0, 120)
		Props.rect(gui, 0, 0, 1, 1, Props.SCREEN_BASE, 0.1, "Back")
		local pts = { 0.6, 0.6, 0.62, 0.3, 0.85, 0.55, 0.6, 0.6, 0.6, 0.58, 0.32, 0.82, 0.56, 0.6 }
		for i = 1, #pts - 1 do
			local x1, x2 = (i - 1) / (#pts - 1), i / (#pts - 1)
			local line = Props.rect(gui, x1, math.min(pts[i], pts[i + 1]), x2 - x1 + 0.01, math.max(0.02, math.abs(pts[i + 1] - pts[i])), P.SUCCESS_GREEN, 0.1, "Trace" .. i)
			line.Size = UDim2.fromScale(x2 - x1 + 0.01, math.max(0.025, math.abs(pts[i + 1] - pts[i])))
		end
		Props.label(gui, "HR 72", 0.05, 0.05, 0.4, 0.2, { color = P.SUCCESS_GREEN })
		return k.finish(frame)
	end

	-- MedCabinet (new) 3 x 7 x 1.4: a MEDICAL_WHITE cabinet with two glass doors, shelves of bottles and boxes, a label.
	function Props.MedCabinet(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 5)
		local k = Props.kit(parent, opts.name or "MedCabinet", cframe)
		local white = { Color = P.MEDICAL_WHITE, Material = "SmoothPlastic" }
		local body = k.box("Back", V(3, 7, 0.15), V(0, 3.5, 0.62), white)
		for _, x in ipairs({ -1.45, 1.45 }) do
			k.box("Side", V(0.1, 7, 1.4), V(x, 3.5, 0), white)
		end
		k.box("Top", V(3, 0.15, 1.4), V(0, 6.93, 0), white)
		k.box("Base", V(3, 0.6, 1.4), V(0, 0.3, 0), white)
		for s = 1, 4 do
			local y = 0.6 + s * 1.3
			k.box("Shelf" .. s, V(2.8, 0.08, 1.2), V(0, y - 0.04, 0), with(white, soft))
			for b = 1, rng.int(3, 6) do
				local x = rng.next(-1.2, 1.2)
				if b % 3 == 0 then
					k.box("Box", V(0.6, 0.45, 0.5), V(x, y + 0.23, rng.next(-0.2, 0.2)), with({ Color = rng.pick({ P.MEDICAL_WHITE, P.LIGHT_COOL, P.SLATE }) }, soft))
				else
					k.cyl("Bottle", "Y", V(0.28, rng.next(0.4, 0.8), 0.28), V(x, y + 0.3, rng.next(-0.25, 0.25)), with({ Color = rng.pick({ P.AMBER_LAMP, P.GLASS, P.MEDICAL_WHITE, P.RUST_DARK }), Material = "Glass", Transparency = 0.2 }, soft))
				end
			end
		end
		for _, x in ipairs({ -0.72, 0.72 }) do
			k.box("Door", V(1.4, 6.2, 0.05), V(x, 3.75, -0.68), with({ Color = P.GLASS, Material = "Glass", Transparency = 0.6 }, soft))
			k.box("DoorFrame", V(1.4, 0.12, 0.08), V(x, 0.7, -0.7), with(white, soft))
		end
		local label = k.box("Label", V(1.6, 0.35, 0.05), V(0, 6.6, -0.72), with({ Color = P.SLATE }, soft))
		local gui = Props.gui(label, Enum.NormalId.Front, 0.6, 80)
		Props.label(gui, "MEDICAL SUPPLIES", 0.05, 0.1, 0.9, 0.8, { font = Props.FONT.header, color = P.SIGN_WHITE, xAlign = "Center" })
		return k.finish(body)
	end

	-- Mug: a cylinder 0.35 x 0.45 with a handle. Datapad: a slab with a dim screen. Clipboard: a board, paper, clip.
	function Props.Mug(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Mug", cframe)
		local color = opts.color or P.SLATE
		local body = k.cyl("Body", "Y", V(0.34, 0.44, 0.34), V(0, 0.22, 0), with({ Color = color }, soft))
		k.box("Handle", V(0.06, 0.26, 0.14), V(0.21, 0.24, 0), with({ Color = color }, soft))
		k.cyl("Coffee", "Y", V(0.28, 0.02, 0.28), V(0, 0.41, 0), with({ Color = P.RUST_DARK }, soft))
		return k.finish(body)
	end

	function Props.Datapad(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Datapad", cframe)
		local body = k.box("Body", V(0.62, 0.05, 0.9), V(0, 0.025, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		local screen = k.box("Screen", V(0.52, 0.01, 0.74), V(0, 0.055, 0), with({ Color = Props.SCREEN_BASE, Material = "Neon", Transparency = 0.35 }, soft))
		if opts.lines ~= false then
			local gui = Props.gui(screen, Enum.NormalId.Top, 0, 200)
			for i = 1, 4 do
				Props.rect(gui, 0.1, 0.12 + i * 0.16, (if i % 2 == 0 then 0.55 else 0.8), 0.05, P.AMBER, 0.3, "Line" .. i)
			end
		end
		return k.finish(body)
	end

	function Props.Clipboard(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Clipboard", cframe)
		local board = k.box("Board", V(0.7, 0.04, 1.0), V(0, 0.02, 0), with({ Color = P.WOOD_OLD, Material = "Wood" }, soft))
		local paper = k.box("Paper", V(0.6, 0.01, 0.82), V(0, 0.045, 0.04), with({ Color = P.MEDICAL_WHITE }, soft))
		k.box("Clip", V(0.3, 0.06, 0.12), V(0, 0.06, -0.42), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		local gui = Props.gui(paper, Enum.NormalId.Top, 0.6, 200)
		for i = 1, 6 do
			Props.rect(gui, 0.1, 0.08 + i * 0.12, (if i % 3 == 0 then 0.5 else 0.8), 0.025, P.KICKPLATE, 0.2, "Line" .. i)
		end
		return k.finish(board)
	end
end
