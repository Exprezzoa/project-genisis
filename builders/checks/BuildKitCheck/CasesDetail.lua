--!nonstrict
-- BuildKitCheck cases: BuildKit/Detail.

return function(T)
	local BK, P, O = T.BK, T.P, T.O
	local expect, near, vec, fails, hex = T.expect, T.expectNear, T.expectVec, T.expectError, T.hex
	local V3 = Vector3.new
	local Y = O.Y

	-- The part of `root` whose center is at `position`, or nil.
	local function partAt(root, position)
		for _, part in ipairs(T.parts(root)) do
			if (part.Position - position).Magnitude < 0.01 then
				return part
			end
		end
		return nil
	end

	T.case("seams", function(f)
		local floor = BK.floor(f, "Fl", 4, 28, -12, 12, Y, 1, { Color = P.FLOOR_INTERIOR })
		local grid = BK.seams(floor, Enum.NormalId.Top, 8)
		expect(grid:IsA("Folder") and grid.Name == "Seams_Top" and grid.Parent == f, "seams folder sits next to the part")
		expect(#T.parts(grid) == 6, "world-aligned 8-stud grid on a 24 x 24 floor: 6 seams, got " .. #T.parts(grid))
		local alongZ = partAt(grid, V3(8, Y, 0))
		expect(alongZ ~= nil, "a seam lies on world X = 8")
		vec(alongZ.Size, V3(0.2, 0.1, 24), "seam running along Z")
		local alongX = partAt(grid, V3(16, Y, -8))
		expect(alongX ~= nil, "a seam lies on world Z = -8")
		vec(alongX.Size, V3(24, 0.1, 0.2), "seam running along X")
		expect(alongZ:HasTag("Detail") and not alongZ.CanCollide and not alongZ.CanQuery and not alongZ.CastShadow, "seams are soft details")
		expect(hex(alongZ.Color) == hex(BK.darken(floor.Color, 0.08)), "seams are 8% darker than the surface")
		local _, seamHi = T.bounds(alongZ)
		near(seamHi.Y, Y + 0.05, "seams stand 0.05 proud")

		local wall = BK.wallX(f, "W", 0, 40, -20, Y, Y + 14, 1, { Color = P.WALL_INTERIOR })
		local vertical = BK.seams(wall, Enum.NormalId.Back, 16, { along = "Y" })
		expect(#T.parts(vertical) == 2, "vertical seams every 16 on a 40-long wall: 2, got " .. #T.parts(vertical))
		local seam = partAt(vertical, V3(16, Y + 7, -19.5))
		expect(seam ~= nil, "a vertical seam sits on world X = 16 on the Back face")
		vec(seam.Size, V3(0.2, 14, 0.1), "vertical seam size")

		local horizontal = BK.seams(wall, Enum.NormalId.Back, nil, { along = "X", at = { 3, 10 }, name = "Horizontal" })
		expect(horizontal.Name == "Horizontal" and #T.parts(horizontal) == 2, "two horizontal seams from opts.at")
		expect(partAt(horizontal, V3(20, Y + 3, -19.5)) ~= nil and partAt(horizontal, V3(20, Y + 10, -19.5)) ~= nil, "horizontal seams at 3 and 10 above the wall base")

		local bench = BK.part(f, { Name = "Bench", Size = V3(12, 1, 4), Position = O + V3(100.3, 0, 0) })
		local holder = BK.folder(f, "Holder")
		local centered = BK.seams(bench, Enum.NormalId.Top, 5, { along = "Z", align = "center", parent = holder, color = P.KICKPLATE })
		expect(centered.Parent == holder, "opts.parent")
		expect(#T.parts(centered) == 3, "center-aligned: 3 seams, got " .. #T.parts(centered))
		expect(partAt(centered, O + V3(100.3, 0.5, 0)) ~= nil and partAt(centered, O + V3(95.3, 0.5, 0)) ~= nil, "center-aligned seam positions")
		expect(hex(T.parts(centered)[1].Color) == hex(P.KICKPLATE), "opts.color")

		local edge = BK.seams(bench, Enum.NormalId.Top, 5, { along = "Z", align = "edge", name = "Edge" })
		expect(#T.parts(edge) == 2, "edge-aligned: seams at 5 and 10, got " .. #T.parts(edge))

		fails(function()
			BK.seams(wall, Enum.NormalId.Back, 8, { along = "Z" })
		end, "along must lie in the face")
	end)

	T.case("trimBand and kickplate", function(f)
		local trim = BK.trimBand(f, "Trim", CFrame.new(O + V3(0, 3, 0)), 40, 0.4, 0.1, P.SLATE)
		vec(trim.Size, V3(40, 0.4, 0.1), "trim band size")
		expect(hex(trim.Color) == hex(P.SLATE) and trim:HasTag("Detail") and not trim.CanCollide, "trim band is a SLATE detail")

		local wall = BK.wallX(f, "KW", -20, 20, 0, Y, Y + 12, 1)
		local kick = BK.kickplate(f, "Kick", wall, Enum.NormalId.Front)
		vec(kick.Size, V3(39.96, 1, 0.1), "kickplate size")
		vec(kick.Position, O + V3(0, 0.5, -0.5), "kickplate hugs the base of the Front face")
		expect(hex(kick.Color) == hex(P.KICKPLATE) and kick:HasTag("Detail"), "kickplate color and tag")

		local side = BK.kickplate(f, "Side", wall, Enum.NormalId.Right, { color = P.CONCRETE_DARK, height = 2 })
		vec(side.Size, V3(0.1, 2, 0.96), "kickplate on a side face")
		vec(side.Position, O + V3(20, 1, 0), "side kickplate position")
		expect(hex(side.Color) == hex(P.CONCRETE_DARK), "kickplate color override")
		fails(function()
			BK.kickplate(f, "Top", wall, Enum.NormalId.Top)
		end, "kickplate on the top face")
	end)

	T.case("hazardStripe", function(f)
		local yellow, black = hex(P.HAZARD_YELLOW), hex(P.HAZARD_BLACK)
		-- Test only: the paint is not queryable by design, so switch it on to read colors with rays.
		local function makeQueryable(model)
			for _, part in ipairs(T.parts(model)) do
				expect(part:HasTag("Detail") and not part.CanCollide and not part.CanQuery, "hazard paint is a soft detail")
				part.CanQuery = true
			end
		end
		local function paintAt(model, position)
			local result = T.ray(position + V3(0, 5, 0), V3(0, -10, 0), model)
			return result and hex(result.Instance.Color)
		end

		local narrow = BK.hazardStripe(f, "H", CFrame.new(O), 20, 1)
		expect(#T.parts(narrow) == 16, "width 1: base + 5 stripes x 3 parts, got " .. #T.parts(narrow))
		local lo, hi = T.bounds(narrow)
		expect(lo.X >= -10.001 and hi.X <= 10.001 and lo.Z >= -0.501 and hi.Z <= 0.501, "nothing pokes outside the band")
		near(lo.Y, Y, "the paint sits on the surface")
		near(hi.Y, Y + 0.07, "black is 0.02 above the yellow")
		makeQueryable(narrow)
		expect(paintAt(narrow, O + V3(-8.0, 0, 0)) == black, "stripe body is black")
		expect(paintAt(narrow, O + V3(-9.2, 0, -0.4)) == black, "left triangle covers its half")
		expect(paintAt(narrow, O + V3(-9.2, 0, 0.3)) == yellow, "outside the left edge is yellow")
		expect(paintAt(narrow, O + V3(-7.0, 0, 0.3)) == black, "right triangle covers its half")
		expect(paintAt(narrow, O + V3(-7.0, 0, -0.3)) == yellow, "outside the right edge is yellow")
		expect(paintAt(narrow, O + V3(-6.0, 0, 0)) == yellow, "the gap between stripes is yellow")

		local wideOrigin = O + V3(0, 0, 20)
		local wide = BK.hazardStripe(f, "Wide", CFrame.new(wideOrigin), 20, 4)
		expect(#T.parts(wide) == 17, "width 4: base + 4 stripes x 2 bands x 2 triangles, got " .. #T.parts(wide))
		local wlo, whi = T.bounds(wide)
		expect(wlo.X >= -10.001 and whi.X <= 10.001 and wlo.Z >= 17.999 and whi.Z <= 22.001, "wide band stays inside its footprint")
		makeQueryable(wide)
		expect(paintAt(wide, wideOrigin + V3(-6.5, 0, -0.5)) == black, "wide: stripe in the lower band")
		expect(paintAt(wide, wideOrigin + V3(-8.5, 0, -0.5)) == yellow, "wide: left of the stripe")
		expect(paintAt(wide, wideOrigin + V3(-4.5, 0, -0.5)) == yellow, "wide: right of the stripe")
		expect(paintAt(wide, wideOrigin + V3(-7.5, 0, -1.5)) == black, "wide: stripe near the lower edge")
		expect(paintAt(wide, wideOrigin + V3(-4.5, 0, 1.5)) == black, "wide: the same stripe continues in the upper band")
		expect(paintAt(wide, wideOrigin + V3(-6.5, 0, 1.5)) == yellow, "wide: left of the stripe in the upper band")

		local square = BK.hazardStripe(f, "Sq", CFrame.new(O + V3(0, 0, 40)), 10, 1, { angle = 90 })
		expect(#T.parts(square) == 4, "angle 90: base + 3 rectangles, got " .. #T.parts(square))

		local turned = BK.hazardStripe(f, "Turned", CFrame.new(O + V3(0, 0, 70)) * CFrame.Angles(0, math.rad(90), 0), 20, 1)
		local tlo, thi = T.bounds(turned)
		expect(tlo.X >= -0.501 and thi.X <= 0.501 and tlo.Z >= 59.999 and thi.Z <= 80.001, "a turned band stays inside its footprint")

		fails(function()
			BK.hazardStripe(f, "Bad", CFrame.new(O), 10, 1, { angle = 10 })
		end, "angle below 15")
	end)

	T.case("pipeRun", function(f)
		local points = { O + V3(0, 10, 0), O + V3(20, 10, 0), O + V3(20, 10, -10), O + V3(20, 4, -10) }
		local run = BK.pipeRun(f, "Pipe", points, 0.6)
		expect(#T.parts(run) == 9, "3 pipes + 2 elbows + 4 brackets, got " .. #T.parts(run))
		local lengths = { 20, 10, 6 }
		for i = 1, 3 do
			local pipe = run:FindFirstChild(("Pipe_Pipe%02d"):format(i))
			expect(pipe and pipe.Shape == Enum.PartType.Cylinder, "pipe " .. i .. " is a cylinder")
			vec(pipe.Size, V3(lengths[i], 1.2, 1.2), "pipe " .. i .. " size")
			local direction = (points[i + 1] - points[i]).Unit
			expect(pipe.CFrame.XVector:Dot(direction) > 0.999, "pipe " .. i .. " runs along its segment")
			vec(pipe.Position, (points[i] + points[i + 1]) / 2, "pipe " .. i .. " center")
			expect(pipe:HasTag("Detail") and not pipe.CanCollide, "pipes are decoration by default")
		end
		local elbow = run:FindFirstChild("Pipe_Elbow01")
		expect(elbow and elbow.Shape == Enum.PartType.Ball, "elbow is a ball")
		vec(elbow.Position, points[2], "elbow sits on the corner")
		expect(run:FindFirstChild("Pipe_Bracket04") ~= nil and run:FindFirstChild("Pipe_Bracket05") == nil, "4 brackets")
		expect(hex(run:FindFirstChild("Pipe_Pipe01").Color) == hex(P.STEEL_MID), "default pipe color")

		local solid = BK.pipeRun(f, "Solid", { O + V3(0, 20, 0), O + V3(2, 20, 0) }, 1, { collide = true, brackets = false, color = P.RUST })
		expect(#T.parts(solid) == 1, "short solid pipe: one part")
		local pipe = solid:FindFirstChild("Solid_Pipe01")
		expect(pipe.CanCollide and not pipe:HasTag("Detail") and hex(pipe.Color) == hex(P.RUST), "collide = true makes a solid pipe")
	end)

	T.case("cable", function(f)
		local cable = BK.cable(f, "Cab", O + V3(0, 20, 0), O + V3(40, 20, 0), 1.6, 6, 0.2)
		expect(#T.parts(cable) == 6, "6 segments, got " .. #T.parts(cable))
		local lo, hi = T.bounds(cable)
		near(lo.Y, Y + 20 - 1.6 - 0.1, "the cable sags by `sag` at mid-span", 0.05)
		near(hi.Y, Y + 20 + 0.1, "the cable ends at its anchor height", 0.05)
		near(lo.X, 0, "cable starts at a", 0.15)
		near(hi.X, 40, "cable ends at b", 0.15)
		local piece = cable:FindFirstChild("Cab_Seg01")
		expect(piece.Shape == Enum.PartType.Cylinder and piece:HasTag("Detail") and not piece.CastShadow, "cable pieces are thin detail cylinders")
		expect(hex(piece.Color) == hex(P.HAZARD_BLACK), "default cable color")
	end)

	T.case("bolts", function(f)
		local plate = BK.part(f, { Name = "Plate", Size = V3(10, 10, 1), Position = O + V3(0, 5, 0) })
		local bolts = BK.bolts(plate, Enum.NormalId.Front, Vector2.new(4, 3))
		expect(bolts:IsA("Folder") and bolts.Name == "Bolts_Front", "bolts folder")
		expect(#T.parts(bolts) == 12, "4 x 3 bolts, got " .. #T.parts(bolts))
		local first = bolts:FindFirstChild("Bolt001")
		vec(first.Position, O + V3(-4.4, 0.6, -0.56), "first bolt position (margin 0.6, standing on the face)")
		vec(bolts:FindFirstChild("Bolt012").Position, O + V3(4.4, 9.4, -0.56), "last bolt position")
		vec(first.Size, V3(0.12, 0.3, 0.3), "bolt size")
		expect(math.abs(first.CFrame.XVector:Dot(Vector3.zAxis)) > 0.999, "bolt axis follows the face normal")
		expect(first:HasTag("Detail") and not first.CanCollide and not first.CastShadow, "bolts are soft details")

		local slab = BK.part(f, { Name = "Slab", Size = V3(6, 1, 6), Position = O + V3(30, 0, 0) })
		local top = BK.bolts(slab, Enum.NormalId.Top, Vector2.new(2, 2), { size = 0.4, color = P.STEEL_LIGHT })
		local bolt = top:FindFirstChild("Bolt001")
		expect(math.abs(bolt.CFrame.XVector:Dot(Vector3.yAxis)) > 0.999, "bolts on a top face point up")
		near(bolt.Position.Y, Y + 0.5 + 0.08, "top bolts stand on the face")
		expect(hex(bolt.Color) == hex(P.STEEL_LIGHT), "bolt color override")

		local single = BK.bolts(slab, Enum.NormalId.Bottom, Vector2.new(1, 1), { name = "One" })
		vec(single:FindFirstChild("Bolt001").Position, O + V3(30, -0.56, 0), "a single bolt is centered")
	end)
end
