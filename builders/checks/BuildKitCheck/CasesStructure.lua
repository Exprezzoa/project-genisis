--!nonstrict
-- BuildKitCheck cases: BuildKit/Structure.

return function(T)
	local BK, P, O = T.BK, T.P, T.O
	local expect, near, vec, fails, hex = T.expect, T.expectNear, T.expectVec, T.expectError, T.hex
	local V3 = Vector3.new
	local Y = O.Y

	-- Name of the part a ray hits, or nil.
	local function hitName(from, direction, root)
		local result = T.ray(from, direction, root)
		return result and result.Instance.Name
	end

	-- Fails when two parts under root overlap by more than a sliver (the parts must be axis-aligned).
	local function expectNoOverlaps(root)
		local parts = T.parts(root)
		for i = 1, #parts do
			local aMin, aMax = T.bounds(parts[i])
			for j = i + 1, #parts do
				local bMin, bMax = T.bounds(parts[j])
				local overlap = aMax:Min(bMax) - aMin:Max(bMin)
				if overlap.X > 0.01 and overlap.Y > 0.01 and overlap.Z > 0.01 then
					error(parts[i].Name .. " overlaps " .. parts[j].Name, 2)
				end
			end
		end
	end

	T.case("box floor ceiling walls", function(f)
		local box = BK.box(f, "B", O + V3(10, 4, 6), O + V3(2, 0, 0), { Color = P.STEEL_MID })
		vec(box.Size, V3(8, 4, 6), "box size from unordered corners")
		vec(box.Position, O + V3(6, 2, 3), "box center")
		expect(box.Name == "B" and hex(box.Color) == hex(P.STEEL_MID), "box name and color")

		local floor = BK.floor(f, "F", -60, 60, -40, 40, Y, 1, {})
		vec(floor.Size, V3(120, 1, 80), "floor size")
		local _, floorHi = T.bounds(floor)
		near(floorHi.Y, Y, "floor top is at yTop")

		local ceiling = BK.ceiling(f, "C", -60, 60, -40, 40, Y + 36, 1)
		local ceilingLo = T.bounds(ceiling)
		near(ceilingLo.Y, Y + 36, "ceiling bottom is at yBottom")

		local wallX = BK.wallX(f, "WX", -60, 60, -40, Y, Y + 36, 2)
		vec(wallX.Size, V3(120, 36, 2), "wallX size")
		vec(wallX.Position, O + V3(0, 18, -40), "wallX sits on its centerline")

		local wallZ = BK.wallZ(f, "WZ", -40, 40, 60, Y, Y + 36, 2)
		vec(wallZ.Size, V3(2, 36, 80), "wallZ size")
		vec(wallZ.Position, O + V3(60, 18, 0), "wallZ sits on its centerline")

		fails(function()
			BK.box(f, "Flat", O, O + V3(4, 0, 4))
		end, "zero-height box")
	end)

	T.case("wallWithOpenings along X", function(f)
		local wall = BK.wallWithOpenings(f, "W", "X", 0, 40, 10, Y, Y + 14, 1, {
			{ from = 25, to = 31, y1 = Y + 3, y2 = Y + 9 }, -- window, listed first: openings get sorted
			{ from = 10, to = 15, y1 = Y, y2 = Y + 8 }, -- door 5 x 8
		}, { Color = P.WALL_INTERIOR })
		expect(wall:IsA("Model") and wall.PrimaryPart ~= nil, "model with a PrimaryPart")
		expect(#T.parts(wall) == 13, "13 parts, got " .. #T.parts(wall))
		expect(wall:GetAttribute("Openings") == 2 and wall:GetAttribute("Axis") == "X", "attributes")
		expect(wall:GetAttribute("Opening1_Span") == Vector2.new(10, 15), "Opening1_Span")
		expect(wall:GetAttribute("Opening1_Y") == Vector2.new(Y, Y + 8), "Opening1_Y")

		local function through(x, height)
			return hitName(V3(x, Y + height, 5), V3(0, 0, 10), wall)
		end
		for _, p in ipairs({ { 12.5, 4 }, { 10.05, 4 }, { 14.95, 4 }, { 12.5, 7.95 }, { 12.5, 0.05 } }) do
			expect(through(p[1], p[2]) == nil, ("door opening is clear at (%.2f, %.2f)"):format(p[1], p[2]))
		end
		expect(through(9.8, 4) == "W_Trim1_L", "left jamb")
		expect(through(15.2, 4) == "W_Trim1_R", "right jamb")
		expect(through(12.5, 8.2) == "W_Trim1_Head", "door head trim")
		expect(through(12.5, 10) == "W_Lintel1", "door lintel")
		expect(through(5, 4) == "W_Seg1", "first wall segment")
		expect(through(20, 4) == "W_Seg2", "middle wall segment")
		expect(through(38, 4) == "W_Seg3", "last wall segment")
		expect(through(28, 6) == nil, "window opening is clear")
		expect(through(28, 2.8) == "W_Trim2_Sill", "window sill trim")
		expect(through(28, 1) == "W_Sill2", "wall under the window")
		expect(through(28, 9.2) == "W_Trim2_Head", "window head trim")
		expect(through(28, 12) == "W_Lintel2", "window lintel")

		local jamb = wall:FindFirstChild("W_Trim1_L")
		expect(hex(jamb.Color) == hex(P.STEEL_DARK) and jamb.Material == Enum.Material.Metal, "trim is STEEL_DARK metal")
		expect(jamb.CanCollide, "trim collides (it is the edge of the opening)")
		expect(hex(wall:FindFirstChild("W_Seg1").Color) == hex(P.WALL_INTERIOR), "wall color")

		local lo, hi = T.bounds(wall)
		vec(lo, V3(0, Y, 9.4), "bounds min (trim stands 0.1 proud)")
		vec(hi, V3(40, Y + 14, 10.6), "bounds max")
		expectNoOverlaps(wall)
	end)

	T.case("wallWithOpenings along Z and trim options", function(f)
		local wall = BK.wallWithOpenings(f, "WZ", "Z", -10, 10, 60, Y, Y + 14, 2, {
			{ from = -10, to = -4, y1 = Y, y2 = Y + 14 }, -- full-height gap at the start of the wall
			{ from = 2, to = 7, y1 = Y, y2 = Y + 8, trim = false },
		})
		expect(#T.parts(wall) == 4, "4 parts, got " .. #T.parts(wall))
		expect(wall:GetAttribute("Axis") == "Z" and wall:GetAttribute("Opening2_Span") == Vector2.new(2, 7), "attributes")

		local function through(z, height)
			return hitName(V3(55, Y + height, z), V3(10, 0, 0), wall)
		end
		expect(through(-7, 4) == nil, "full-height gap is clear")
		expect(through(-7, 13.9) == nil, "full-height gap has no lintel")
		expect(through(-3.8, 4) == "WZ_Trim1_R", "jamb on the wall side of the gap")
		expect(through(0, 4) == "WZ_Seg1", "segment between the openings")
		expect(through(4.5, 4) == nil, "untrimmed opening is clear")
		expect(through(4.5, 10) == "WZ_Lintel2", "lintel over the untrimmed opening")
		expect(through(8.5, 4) == "WZ_Seg2", "last segment")

		local lo, hi = T.bounds(wall)
		vec(lo, V3(58.9, Y, -4), "bounds min")
		vec(hi, V3(61.1, Y + 14, 10), "bounds max")
		expectNoOverlaps(wall)

		local plain = BK.wallWithOpenings(f, "Plain", "X", 0, 20, 30, Y, Y + 10, 1, { { from = 5, to = 10, y1 = Y, y2 = Y + 8 } }, { Trim = false })
		expect(#T.parts(plain) == 3, "Trim = false: 2 segments + lintel, got " .. #T.parts(plain))
		local plainLo, plainHi = T.bounds(plain)
		near(plainHi.Z - plainLo.Z, 1, "Trim = false: nothing stands proud of the wall")

		local solid = BK.wallWithOpenings(f, "Solid", "X", 0, 20, 40, Y, Y + 10, 1, {})
		expect(#T.parts(solid) == 1, "no openings: one part")

		fails(function()
			BK.wallWithOpenings(f, "Bad", "X", 0, 20, 50, Y, Y + 10, 1, {
				{ from = 5, to = 10, y1 = Y, y2 = Y + 8 },
				{ from = 9, to = 12, y1 = Y, y2 = Y + 8 },
			})
		end, "overlapping openings")
		fails(function()
			BK.wallWithOpenings(f, "Bad2", "Y", 0, 20, 50, Y, Y + 10, 1, {})
		end, "bad axis")
	end)

	T.case("stairs", function(f)
		local stairs = BK.stairs(f, "St", O + V3(-30, 0, -21), V3(-1, 0, 0), 6, 16)
		expect(stairs:GetAttribute("Steps") == 16, "16 steps")
		expect(#T.parts(stairs) == 47, "47 parts with railings and stringers, got " .. #T.parts(stairs))

		local last = stairs:FindFirstChild("St_Step16")
		expect(last ~= nil, "last step exists")
		vec(last.Position, O + V3(-53.25, 15.5, -21), "last step position")
		local lo, hi = T.bounds(last)
		vec(hi - lo, V3(1.5, 1, 6), "step world size (run, rise, width)")
		near(hi.Y, Y + 16, "top step is level with the upper floor")
		near(lo.X, -54, "stairs end 24 studs of run from the start")
		expect(last.Material == Enum.Material.DiamondPlate and hex(last.Color) == hex(P.STEEL_MID), "default stair material and color")

		-- The ramp collider follows the step nosings: height = rise * (run + stepRun) / stepRun.
		local ramp = stairs:FindFirstChild("St_RampCollider")
		expect(ramp and ramp.Transparency == 1 and ramp.CanCollide and ramp:HasTag("NoCollideCamera"), "ramp collider flags")
		for _, sample in ipairs({ { -0.75, 0.5 }, { 0.75, 1.5 }, { 11.25, 8.5 }, { 20.25, 14.5 } }) do
			local result = T.ray(V3(-30 - sample[1], Y + 40, -21), V3(0, -60, 0), stairs)
			expect(result and result.Instance == ramp, ("the ramp is the walking surface at run %.2f"):format(sample[1]))
			near(result.Position.Y, Y + sample[2], ("ramp height at run %.2f"):format(sample[1]), 0.02)
		end
		local top = T.ray(V3(-53.25, Y + 40, -21), V3(0, -60, 0), stairs)
		expect(top and top.Instance == last, "the top tread is the walking surface at the top")
		near(top.Position.Y, Y + 16, "top tread height")
		local _, rampHi = T.bounds(ramp)
		expect(rampHi.Y <= Y + 16.01, "the ramp never rises above the upper floor")

		local railTop = stairs:FindFirstChild("St_RailL_Top1", true)
		expect(railTop ~= nil, "stair railing exists")
		near(railTop.Position.Y, Y + 11.85, "the stair rail runs 3.5 above the nosing line")
		local stringer = stairs:FindFirstChild("St_StringerL")
		expect(stringer ~= nil, "stringer exists")
		local _, stringerHi = T.bounds(stringer)
		expect(stringerHi.Y <= Y + 15.01, "stringers stay under the treads")

		local bare = BK.stairs(f, "Bare", O + V3(0, 0, 40), V3(0, 0, -1), 6, 4, { railings = false, stringers = false, stepRun = 2 })
		expect(#T.parts(bare) == 5, "bare stairs: 4 steps + ramp, got " .. #T.parts(bare))
		local bareLo, bareHi = T.bounds(bare:FindFirstChild("Bare_Step04"))
		near(bareLo.Z, 32, "custom stepRun: 4 steps of 2 reach 8 studs uphill")
		near(bareHi.Y, Y + 4, "custom stairs top")

		fails(function()
			BK.stairs(f, "E1", O, V3(1, 0, 1), 6, 4)
		end, "dir must be a unit vector")
		fails(function()
			BK.stairs(f, "E2", O, V3(1, 0, 0), 6, 4.5)
		end, "totalRise must be a multiple of stepRise")
	end)

	T.case("railing", function(f)
		local rail = BK.railing(f, "R", { O + V3(0, 16, -24), O + V3(20, 16, -24), O + V3(20, 16, -10) })
		expect(#T.parts(rail) == 14, "14 parts, got " .. #T.parts(rail))
		local posts = 0
		for _, part in ipairs(T.parts(rail)) do
			if string.find(part.Name, "_Post") then
				posts += 1
				near(part.Size.Y, 3.5, "post height")
				expect(not part.CanCollide and not part.CanQuery, "posts never collide")
				expect(hex(part.Color) == hex(P.STEEL_DARK), "default railing color")
			end
		end
		expect(posts == 8, "8 posts (spacing <= 5, shared corner post), got " .. posts)

		local top = rail:FindFirstChild("R_Top1")
		vec(top.Position, O + V3(10, 19.35, -24), "top rail center")
		local lo, hi = T.bounds(top)
		vec(hi - lo, V3(20, 0.3, 0.3), "top rail size")
		near(hi.Y, Y + 19.5, "the railing is 3.5 tall")

		local collider = rail:FindFirstChild("R_Collider1")
		expect(collider.Transparency == 1 and collider.CanCollide and collider:HasTag("NoCollideCamera"), "collider flags")
		local clo, chi = T.bounds(collider)
		vec(clo, O + V3(0, 16, -24.2), "collider min")
		vec(chi, O + V3(20, 19.5, -23.8), "collider max")
		expect(hitName(O + V3(10, 17.75, -30), V3(0, 0, 12), rail) == "R_Collider1", "only the collider blocks")

		local open = BK.railing(f, "Open", { O, O + V3(4, 0, 0) }, { collide = false, height = 4, postSpacing = 2, color = P.STEEL_LIGHT })
		expect(open:FindFirstChild("Open_Collider1") == nil, "collide = false builds no collider")
		expect(#T.parts(open) == 5, "2 rails + 3 posts, got " .. #T.parts(open))
		near(open:FindFirstChild("Open_Post01").Size.Y, 4, "custom height")
		expect(hex(open:FindFirstChild("Open_Top1").Color) == hex(P.STEEL_LIGHT), "custom color")
		fails(function()
			BK.railing(f, "One", { O })
		end, "needs 2 points")
	end)

	T.case("column", function(f)
		local column = BK.column(f, "Col", O + V3(46, 0, -12), 36, 3)
		expect(#T.parts(column) == 3, "shaft + base + capital")
		local lo, hi = T.bounds(column)
		vec(lo, O + V3(44, 0, -14), "column bounds min (base flares 0.5)")
		vec(hi, O + V3(48, 36, -10), "column bounds max (total height includes base and capital)")
		local shaft = column:FindFirstChild("Col_Shaft")
		vec(shaft.Size, V3(3, 34, 3), "shaft size")
		expect(column.PrimaryPart == shaft, "PrimaryPart is the shaft")
		expect(hex(shaft.Color) == hex(P.CONCRETE_LIGHT) and shaft.Material == Enum.Material.Concrete, "default column look")

		local plain = BK.column(f, "Plain", O + V3(60, 0, 0), 12, 2, { base = false, capital = false, color = P.STEEL_DARK })
		expect(#T.parts(plain) == 1, "no base, no capital: one part")
		vec(plain.PrimaryPart.Size, V3(2, 12, 2), "plain column size")
		expect(hex(plain.PrimaryPart.Color) == hex(P.STEEL_DARK), "custom color")
	end)

	T.case("window", function(f)
		local window = BK.window(f, "Win", CFrame.new(O + V3(0, 3, -40)), 6, 6)
		expect(#T.parts(window) == 7, "4 frame bars + glass + 2 mullions, got " .. #T.parts(window))
		local lo, hi = T.bounds(window)
		vec(lo, O + V3(-3, 3, -40.3), "window bounds min (cframe is the bottom-center)")
		vec(hi, O + V3(3, 9, -39.7), "window bounds max")
		local glass = window:FindFirstChild("Win_Glass")
		expect(glass.Material == Enum.Material.Glass and hex(glass.Color) == hex(P.GLASS), "glass material and color")
		near(glass.Transparency, 0.55, "glass transparency")
		vec(glass.Size, V3(5.2, 5.2, 0.2), "glass size")
		near(window:FindFirstChild("Win_Mullion1").Position.X, -5.2 / 6, "mullions are evenly spaced")
		expect(hex(window:FindFirstChild("Win_FrameL").Color) == hex(P.STEEL_DARK), "default frame color")

		local turned = BK.window(f, "Turned", CFrame.new(O + V3(50, 3, 0)) * CFrame.Angles(0, math.rad(90), 0), 6, 6, { mullions = 0 })
		expect(#T.parts(turned) == 5, "mullions = 0: frame + glass")
		local tlo, thi = T.bounds(turned)
		vec(tlo, O + V3(49.7, 3, -3), "turned window bounds min")
		vec(thi, O + V3(50.3, 9, 3), "turned window bounds max")
		fails(function()
			BK.window(f, "Tiny", CFrame.new(O), 0.6, 4)
		end, "window smaller than its frame")
	end)

	T.case("door", function(f)
		local door = BK.door(f, "D1", CFrame.new(O), 5, 8, { sign = "Briefing Room One" })
		expect(door:HasTag("Door"), "Door tag")
		expect(door:GetAttribute("Locked") == false and door:GetAttribute("Width") == 5 and door:GetAttribute("Height") == 8, "door attributes")
		expect(#T.parts(door) == 5, "leaf + handle + 2 strips + sign, got " .. #T.parts(door))
		local leaf = door:FindFirstChild("D1_Leaf")
		vec(leaf.Size, V3(5, 8, 0.4), "leaf size")
		vec(leaf.Position, O + V3(0, 4, 0), "leaf stands on the threshold")
		expect(door.PrimaryPart == leaf and leaf.CanCollide, "leaf is the PrimaryPart and collides")
		local strip = door:FindFirstChild("D1_StatusStrip_F")
		vec(strip.Position, O + V3(0, 8.75, -0.55), "front status strip position")
		expect(strip.Material == Enum.Material.Neon and hex(strip.Color) == hex(P.AMBER), "open door: amber strip")
		expect(door:FindFirstChild("D1_StatusStrip_B") ~= nil, "back status strip")
		local sign = door:FindFirstChild("D1_Sign")
		expect(sign and sign.Face.Text.Text == "BRIEFING ROOM ONE", "sign text in caps")
		vec(sign.Position, O + V3(0, 10, -0.56), "sign position")

		local double = BK.door(f, "D2", CFrame.new(O + V3(20, 0, 0)), 8, 9, { double = true, locked = true, wallThickness = 2 })
		local left, right = double:FindFirstChild("D2_LeafL"), double:FindFirstChild("D2_LeafR")
		vec(left.Size, V3(3.95, 9, 0.4), "double leaf size")
		near(right.Position.X - left.Position.X, 4.05, "double leaves meet in the middle with a 0.1 gap")
		local dlo, dhi = T.bounds(left)
		near(dlo.X, 16, "double door spans the full width")
		local redStrip = double:FindFirstChild("D2_StatusStrip_F")
		expect(hex(redStrip.Color) == hex(P.DANGER_RED), "locked door: red strip")
		near(redStrip.Position.Z, -1.05, "strip sits on the face of a 2-thick wall")
		expect(double:GetAttribute("Locked") == true, "Locked attribute")
		expect(dhi.Y <= Y + 9.001, "leaf height")

		local passage = BK.door(f, "D3", CFrame.new(O + V3(40, 0, 0)), 5, 8, { leaf = false })
		expect(#T.parts(passage) == 2, "open passage: status strips only, got " .. #T.parts(passage))
	end)
end
