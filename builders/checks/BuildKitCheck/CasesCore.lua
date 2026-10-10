--!nonstrict
-- BuildKitCheck cases: Palette and BuildKit/Core.

return function(T)
	local BK, P, O = T.BK, T.P, T.O
	local expect, near, vec, fails, hex = T.expect, T.expectNear, T.expectVec, T.expectError, T.hex
	local V3 = Vector3.new
	local Y = O.Y

	T.case("palette", function()
		local count = 0
		for key, value in pairs(P) do
			count += 1
			expect(type(key) == "string" and key == string.upper(key), "palette key is UPPER_SNAKE: " .. tostring(key))
			expect(typeof(value) == "Color3", "palette value is a Color3: " .. tostring(key))
		end
		expect(count == 65, "palette has 65 colors, got " .. count)
		expect(hex(P.CONCRETE_MID) == "6e7378", "CONCRETE_MID")
		expect(hex(P.LATTICE_CYAN) == "7fe3f0", "LATTICE_CYAN")
		expect(hex(P.WAT_GLOW) == hex(P.LATTICE_CYAN), "WAT_GLOW is Lattice cyan")
		expect(table.isfrozen(P), "palette is frozen")
	end)

	T.case("hex and coercion", function()
		expect(hex(BK.hex("#E8A33D")) == "e8a33d", "BK.hex value")
		expect(BK.toColor(P.AMBER) == P.AMBER, "toColor passes a Color3 through")
		expect(hex(BK.toColor("#7FE3F0")) == "7fe3f0", "toColor from a hex string")
		expect(BK.toMaterial("Concrete") == Enum.Material.Concrete, "toMaterial from a name")
		expect(BK.toMaterial(Enum.Material.Metal) == Enum.Material.Metal, "toMaterial passes an enum through")
		expect(hex(BK.darken(Color3.new(1, 1, 1), 0.08)) == hex(Color3.new(0.92, 0.92, 0.92)), "darken 8%")
		local probe = Instance.new("Part")
		probe.Color = BK.darken(P.FLOOR_INTERIOR, 0.08)
		expect(hex(probe.Color) == "4a4f55", "a darkened color is snapped to 8 bits, so a part keeps it exactly")
		probe:Destroy()
		fails(function()
			BK.hex("E8A33D")
		end, "hex without #")
		fails(function()
			BK.hex("#E8A33")
		end, "short hex")
		fails(function()
			BK.toColor(5)
		end, "toColor with a number")
		fails(function()
			BK.toMaterial("NotAMaterial")
		end, "unknown material name")
		fails(function()
			BK.toMaterial(Enum.NormalId.Top)
		end, "wrong enum type")
	end)

	T.case("part defaults and props", function(f)
		local a = BK.part(f, { Name = "A", Size = V3(4, 2, 6), Position = O + V3(0, 1, 0) })
		expect(a.ClassName == "Part" and a.Shape == Enum.PartType.Block, "block part")
		expect(a.Parent == f and a.Name == "A", "parent and name")
		expect(a.Anchored == true, "Anchored defaults to true")
		expect(a.CanTouch == false, "CanTouch defaults to false")
		expect(a.CanCollide and a.CanQuery and a.CastShadow, "a normal part collides, queries and casts shadows")
		expect(a.TopSurface == Enum.SurfaceType.Smooth and a.BottomSurface == Enum.SurfaceType.Smooth, "smooth surfaces")
		expect(a.Material == Enum.Material.SmoothPlastic, "default material")
		expect(hex(a.Color) == hex(P.CONCRETE_MID), "default color is a palette color")
		vec(a.Position, O + V3(0, 1, 0), "position")

		local tiny = BK.part(f, { Size = V3(0.4, 0.5, 0.3), Position = O })
		expect(not tiny.CanCollide and not tiny.CanQuery and not tiny.CastShadow, "a tiny part is soft")
		expect(tiny.Name == "Part", "default name is the class name")

		local detail = BK.part(f, { Size = V3(4, 4, 4), Position = O, Tags = { "Detail" } })
		expect(detail:HasTag("Detail"), "Detail tag applied")
		expect(not detail.CanCollide and not detail.CanQuery and detail.CastShadow, "Detail part: no collide, no query, shadow kept")

		local forced = BK.part(f, { Size = V3(0.2, 0.2, 0.2), Position = O, CanCollide = true, CanQuery = true, CastShadow = true })
		expect(forced.CanCollide and forced.CanQuery and forced.CastShadow, "explicit props beat the automatic defaults")

		local turned = BK.part(f, { Size = V3(4, 2, 6), Position = O, Orientation = V3(0, 90, 0), Color = "#E8A33D", Material = "Concrete" })
		near(turned.Orientation.Y, 90, "orientation in degrees")
		expect(hex(turned.Color) == "e8a33d", "hex string color")
		expect(turned.Material == Enum.Material.Concrete, "material by name")

		local rich = BK.part(f, {
			Size = V3(2, 2, 2),
			CFrame = CFrame.new(O + V3(5, 5, 5)),
			Transparency = 0.5,
			Reflectance = 0.03,
			Anchored = false,
			CanTouch = true,
			Massless = true,
			Locked = true,
			CollisionGroup = "PlayerBarrier",
			Tags = "Solo",
			Attributes = { Foo = 5, Bar = "x" },
		})
		near(rich.Transparency, 0.5, "Transparency")
		near(rich.Reflectance, 0.03, "Reflectance")
		expect(rich.Anchored == false and rich.CanTouch == true and rich.Massless and rich.Locked, "pass-through booleans")
		expect(rich.CollisionGroup == "PlayerBarrier", "CollisionGroup")
		expect(rich:HasTag("Solo"), "a single tag given as a string")
		expect(rich:GetAttribute("Foo") == 5 and rich:GetAttribute("Bar") == "x", "attributes")
		vec(rich.Position, O + V3(5, 5, 5), "CFrame position")

		fails(function()
			BK.part(f, { Colour = P.AMBER })
		end, "unknown props key")
	end)

	T.case("wedge cornerWedge ball truss", function(f)
		local wedge = BK.wedge(f, { Size = V3(4, 8, 8), Position = O + V3(0, 4, 0) })
		expect(wedge.ClassName == "WedgePart", "WedgePart")
		local low = T.ray(O + V3(0, 20, -2), V3(0, -40, 0), wedge)
		local high = T.ray(O + V3(0, 20, 2), V3(0, -40, 0), wedge)
		expect(low and high, "wedge rays hit")
		near(low.Position.Y, Y + 2, "wedge is low toward -Z")
		near(high.Position.Y, Y + 6, "wedge rises toward +Z")

		local corner = BK.cornerWedge(f, { Size = V3(8, 8, 8), Position = O + V3(20, 4, 0) })
		expect(corner.ClassName == "CornerWedgePart", "CornerWedgePart")
		local peak = T.ray(O + V3(23, 20, -3), V3(0, -40, 0), corner)
		expect(peak, "corner wedge ray hits")
		near(peak.Position.Y, Y + 7, "corner wedge is tallest at +X / -Z")

		local ball = BK.ball(f, { Size = V3(3, 3, 3), Position = O + V3(40, 4, 0) })
		expect(ball.ClassName == "Part" and ball.Shape == Enum.PartType.Ball, "ball shape")
		local truss = BK.truss(f, { Size = V3(2, 10, 2), Position = O + V3(60, 5, 0) })
		expect(truss.ClassName == "TrussPart" and truss.Anchored, "truss")
	end)

	T.case("cyl axis", function(f)
		local y = BK.cyl(f, { Axis = "Y", Size = V3(2.6, 3.6, 2.6), Position = O + V3(0, 1.8, 0) })
		expect(y.Shape == Enum.PartType.Cylinder, "cylinder shape")
		vec(y.Size, V3(3.6, 2.6, 2.6), "Axis Y: engine size is (length, d, d)")
		expect(math.abs(y.CFrame.XVector:Dot(Vector3.yAxis)) > 0.999, "Axis Y: length runs along world Y")
		local lo, hi = T.bounds(y)
		vec(hi - lo, V3(2.6, 3.6, 2.6), "Axis Y: world box matches the logical size")
		vec(y.Position, O + V3(0, 1.8, 0), "Axis Y: position kept")

		local z = BK.cyl(f, { Axis = "Z", Size = V3(2, 2, 5), Position = O })
		vec(z.Size, V3(5, 2, 2), "Axis Z: engine size")
		expect(math.abs(z.CFrame.XVector:Dot(Vector3.zAxis)) > 0.999, "Axis Z: length runs along world Z")

		local x = BK.cyl(f, { Axis = "X", Size = V3(5, 2, 2), Position = O })
		vec(x.Size, V3(5, 2, 2), "Axis X: size unchanged")
		expect(math.abs(x.CFrame.XVector:Dot(Vector3.xAxis)) > 0.999, "Axis X: length runs along world X")

		local raw = BK.cyl(f, { Size = V3(5, 2, 2), Position = O })
		expect(raw.CFrame.XVector:Dot(Vector3.xAxis) > 0.999, "no Axis: raw engine cylinder")

		local tilted = BK.cyl(f, { Axis = "Y", Size = V3(2, 6, 2), Position = O, Orientation = V3(0, 0, 90) })
		expect(math.abs(tilted.CFrame.XVector:Dot(Vector3.xAxis)) > 0.999, "Axis Y + Orientation: logical Y turned onto world X")

		fails(function()
			BK.cyl(f, { Axis = "W", Size = V3(1, 1, 1) })
		end, "bad Axis")
		fails(function()
			BK.cyl(f, { Axis = "Y" })
		end, "Axis without Size")
	end)

	T.case("beam and triangle", function(f)
		local vertical = BK.beam(f, "V", O, O + V3(0, 10, 0), 0.4, 0.6, { Color = P.STEEL_DARK })
		vec(vertical.Size, V3(0.4, 0.6, 10), "beam size")
		local lo, hi = T.bounds(vertical)
		near(lo.Y, Y, "vertical beam bottom")
		near(hi.Y, Y + 10, "vertical beam top")

		local diagonal = BK.beam(f, "D", O, O + V3(3, 4, 0), 0.2, 0.2)
		near(diagonal.Size.Z, 5, "diagonal beam length")
		vec(diagonal.Position, O + V3(1.5, 2, 0), "diagonal beam center")
		expect(diagonal.CFrame.LookVector:Dot(V3(3, 4, 0).Unit) > 0.999, "beam runs from a to b")
		fails(function()
			BK.beam(f, "Zero", O, O, 1, 1)
		end, "zero-length beam")

		local tri = BK.triangle(f, "T", O + V3(20, 0, 0), V3(4, 0, 0), V3(0, 0, 3), 0.2, { Color = P.HAZARD_BLACK })
		expect(tri.ClassName == "WedgePart", "triangle is a WedgePart")
		local tlo, thi = T.bounds(tri)
		vec(tlo, O + V3(20, -0.1, 0), "triangle bounds min")
		vec(thi, O + V3(24, 0.1, 3), "triangle bounds max")
		expect(T.ray(O + V3(20.5, 5, 0.5), V3(0, -10, 0), tri) ~= nil, "triangle is solid near its right angle")
		expect(T.ray(O + V3(23.5, 5, 2.5), V3(0, -10, 0), tri) == nil, "triangle is empty beyond its hypotenuse")
		fails(function()
			BK.triangle(f, "Bad", O, V3(1, 0, 0), V3(1, 0, 1), 0.2)
		end, "non-perpendicular legs")
	end)

	T.case("folder model and idempotent rebuild", function(f)
		local zone = BK.folder(f, "Zone")
		expect(zone:IsA("Folder") and zone.Parent == f, "folder created")
		BK.part(zone, { Size = V3(2, 2, 2), Position = O })
		expect(BK.folder(f, "Zone") == zone and #zone:GetChildren() == 1, "folder reused, children kept")
		expect(BK.folder(f, "Zone", true) == zone and #zone:GetChildren() == 0, "folder cleared")

		local model = BK.model(f, "Thing")
		expect(model:IsA("Model") and model.Name == "Thing" and model.Parent == f, "model created")
		fails(function()
			BK.folder(f, "Thing")
		end, "folder name taken by a non-folder")

		local outside = BK.part(f, { Name = "Outside", Size = V3(2, 2, 2), Position = O + V3(50, 0, 0) })
		local function build()
			local target = BK.folder(f, "Area", true)
			local structure = BK.folder(target, "Structure")
			for i = 1, 5 do
				BK.part(structure, { Name = "P" .. i, Size = V3(2, 2, 2), Position = O + V3(i * 3, 0, 0) })
			end
			BK.navNode(BK.folder(target, "Gameplay"), "NAV_REBUILD", O, {})
			return BK.stats(target).parts
		end
		local first, second = build(), build()
		expect(first == 6 and second == 6, ("a rebuild gives the same part count (%d, %d)"):format(first, second))
		expect(#f.Area:GetChildren() == 2, "no duplicate folders after a rebuild")
		expect(outside.Parent == f, "content outside the target is untouched")
	end)

	T.case("weld tag attr", function(f)
		local a = BK.part(f, { Name = "A", Size = V3(2, 2, 2), Position = O })
		local b = BK.part(f, { Name = "B", Size = V3(2, 2, 2), Position = O + V3(2, 0, 0) })
		local weld = BK.weld(a, b)
		expect(weld:IsA("WeldConstraint") and weld.Part0 == a and weld.Part1 == b and weld.Parent == a, "weld")

		local model = BK.model(f, "M")
		local root = BK.part(model, { Name = "Root", Size = V3(2, 2, 2), Position = O })
		BK.part(model, { Name = "C1", Size = V3(1, 1, 1), Position = O + V3(0, 2, 0) })
		BK.part(model, { Name = "C2", Size = V3(1, 1, 1), Position = O + V3(0, 4, 0) })
		BK.weldAllTo(model, root)
		local welds = 0
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("WeldConstraint") then
				welds += 1
				expect(descendant.Part0 == root, "weldAllTo welds to the root")
			end
		end
		expect(welds == 2, "weldAllTo made 2 welds, got " .. welds)

		BK.tag(a, "One", "Two")
		expect(a:HasTag("One") and a:HasTag("Two"), "tag varargs")
		BK.attr(a, { Number = 7, Text = "hello", Flag = true })
		expect(a:GetAttribute("Number") == 7 and a:GetAttribute("Text") == "hello" and a:GetAttribute("Flag") == true, "attr")
	end)

	T.case("rng and vary", function()
		local r1, r2, r3 = BK.rng(1187), BK.rng(1187), BK.rng(42)
		local list = { "a", "b", "c", "d", "e" }
		local different = false
		for _ = 1, 10 do
			local n1, n2, n3 = r1.next(0, 1), r2.next(0, 1), r3.next(0, 1)
			expect(n1 == n2, "same seed, same numbers")
			expect(n1 >= 0 and n1 <= 1, "next(min, max) stays in range")
			if n1 ~= n3 then
				different = true
			end
			local i1, i2 = r1.int(3, 9), r2.int(3, 9)
			expect(i1 == i2 and i1 >= 3 and i1 <= 9 and i1 % 1 == 0, "int is deterministic and in range")
			expect(r1.pick(list) == r2.pick(list), "pick is deterministic")
		end
		expect(different, "a different seed gives different numbers")
		local unit = BK.rng(5).next()
		expect(unit >= 0 and unit < 1, "next() without arguments is in [0, 1)")

		local rng = BK.rng(7)
		local base = P.CONCRETE_MID
		for _ = 1, 50 do
			local v = BK.vary(base, 0.03, rng)
			-- 3% of the channel, plus half a step for the 8-bit snap
			local within = math.abs(v.R - base.R) * 255 <= base.R * 255 * 0.03 + 0.51
				and math.abs(v.G - base.G) * 255 <= base.G * 255 * 0.03 + 0.51
				and math.abs(v.B - base.B) * 255 <= base.B * 255 * 0.03 + 0.51
			expect(within, "vary stays within 3%")
		end
		expect(hex(BK.vary(base, 0, rng)) == hex(base), "vary with amount 0 returns the color")
	end)

	T.case("stats and report", function(f)
		local startClock = os.clock()
		local model = BK.model(f, "M")
		local a = BK.part(model, { Size = V3(2, 2, 2), Position = O })
		BK.part(model, { Size = V3(2, 2, 2), Position = O + V3(3, 0, 0) })
		BK.wedge(model, { Size = V3(2, 2, 2), Position = O + V3(6, 0, 0) })
		BK.light(a, "Point", { Shadows = true })
		BK.light(a, "Spot", {})
		BK.emitter(a, "Smoke")
		BK.sign(model, "S", CFrame.new(O + V3(0, 5, 0)), Vector2.new(4, 1), "x")

		local stats = BK.stats(model)
		expect(stats.parts == 4, "parts = 4, got " .. stats.parts)
		expect(stats.lights == 2 and stats.shadowLights == 1, "2 lights, 1 shadowed")
		expect(stats.emitters == 1 and stats.guis == 1, "1 emitter and 1 gui")
		local report = BK.report(model, startClock)
		expect(report.parts == 4 and type(report.ms) == "number" and report.ms >= 0, "report has parts and ms")
		expect(type(report.warnings) == "table", "report has warnings")
		expect(BK.stats(workspace.Terrain).parts == 0, "Terrain is not counted as a part")
	end)
end
