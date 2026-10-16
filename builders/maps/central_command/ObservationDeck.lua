--!nonstrict
-- builders/maps/central_command/ObservationDeck.lua  ->  DevTools.Builders.CentralCommand.ObservationDeck
-- docs/maps/map_01_central_command.md §7-9: the roof of Equipment and Medical (X 80..130, Z -40..40, Y 20) plus
-- the roof bridge from the stairwell (X 80..92, Z 40..50, deck top Y 20). The deck surface and the parapet
-- walls belong to Equipment, Medical and the East Corridor; this builder adds the bridge and the edge barriers.
-- Dressed (05 S42: Mara at the east railing (126, 20, -10) in the evening, the Bulwark's amber lamps beyond): paver
-- joints, a rail on the parapets, benches and coin telescopes facing east, planters, the Directorate flag, two HVAC
-- units, an antenna with a blinking beacon, four lamps lit at EVENING and NIGHT (EveningLamp).

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "ObservationDeck")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

	BK.floor(S, "Bridge", 81, 92, 41, 50, 20, 1, ctx.DECK)
	BK.railing(S, "BridgeRail", { V(81, 20, 49.85), V(91.85, 20, 49.85), V(91.85, 20, 41) })

	-- Players can jump 7.2 studs, so every edge gets an invisible PlayerBarrier above the parapet or railing.
	BK.barrier(G, "Barrier_N", V(80, 22, -41), V(131, 34, -40), "PlayerBarrier")
	BK.barrier(G, "Barrier_E", V(130, 22, -40), V(131, 34, 40), "PlayerBarrier")
	BK.barrier(G, "Barrier_S", V(92, 22, 40), V(131, 34, 41), "PlayerBarrier")
	BK.barrier(G, "Barrier_W", V(79.5, 22, -40), V(80.5, 34, 39.5), "PlayerBarrier")
	BK.barrier(G, "Barrier_Bridge_E", V(92, 20, 41), V(93, 34, 51), "PlayerBarrier")
	BK.barrier(G, "Barrier_Bridge_S", V(81, 20, 50), V(92, 34, 51), "PlayerBarrier")

	if ctx.level >= 3 then
		Builder.dress(ctx, opts.Props)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.dress(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local joint = with({ Color = P.KICKPLATE })
	-- Paver joints every 8 over the deck (its surface is the two roofs' top at Y 20).
	for x = 88, 128, 8 do
		BK.box(ctx.Detail, "PaverJoint", V(x - 0.08, 20, -39), V(x + 0.08, 20.03, 39), joint)
	end
	for z = -32, 32, 8 do
		BK.box(ctx.Detail, "PaverJoint", V(80.5, 20, z - 0.08), V(129, 20.03, z + 0.08), joint)
	end
	-- A rail on top of the parapets (Y 22): a top rail and posts every 6.
	local rail = with({ Color = P.STEEL_LIGHT, Material = "Metal" })
	local runs = { { V(80.5, 22, -39.5), V(129.5, 22, -39.5) }, { V(129.5, 22, -39.5), V(129.5, 22, 39.5) }, { V(92, 22, 39.5), V(129.5, 22, 39.5) } }
	for i, r in ipairs(runs) do
		BK.beam(ctx.Detail, "ParapetRail" .. i, r[1] + V(0, 1.6, 0), r[2] + V(0, 1.6, 0), 0.2, 0.2, rail)
		local length = (r[2] - r[1]).Magnitude
		for d = 0, length, 6 do
			local p = r[1]:Lerp(r[2], d / length)
			BK.box(ctx.Detail, "RailPost", p + V(-0.08, 0, -0.08), p + V(0.08, 1.6, 0.08), rail)
		end
	end

	-- Benches and coin telescopes facing east (toward the Bulwark), clear of Mara's spot at (126, 20, -10).
	for i, z in ipairs({ -22, 18 }) do
		Lib.Bench(F, CFrame.new(108, 20, z) * Lib.FACE["+X"], { name = "Bench" .. i })
	end
	for i, z in ipairs({ -26, 6 }) do
		local scope = Lib.kit(F, "Telescope" .. i, CFrame.new(127, 20, z) * Lib.FACE["+X"])
		scope.cyl("Base", "Y", V(1.4, 0.3, 1.4), V(0, 0.15, 0), { Color = P.STEEL_DARK, Material = "Metal" })
		scope.cyl("Post", "Y", V(0.4, 3.2, 0.4), V(0, 1.9, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		scope.box("Body", V(1.4, 0.9, 1.2), V(0, 3.9, 0), with({ Color = P.SLATE, Material = "Metal" }))
		for _, x in ipairs({ -0.35, 0.35 }) do
			scope.cyl("Lens", "Z", V(0.42, 0.42, 1.0), V(x, 4.0, -0.9), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		end
		scope.box("Hood", V(1.6, 0.15, 1.6), V(0, 4.45, -0.1), with({ Color = P.SLATE, Material = "Metal" }))
		scope.finish()
	end

	-- Planters along the west parapet, the Directorate flag in the north-east corner.
	for i, z in ipairs({ -30, -10, 10, 30 }) do
		BK.box(F, "Planter" .. i, V(81, 20, z - 2.5), V(84, 21.6, z + 2.5), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		BK.box(F, "PlanterSoil" .. i, V(81.2, 21.6, z - 2.3), V(83.8, 21.65, z + 2.3), with({ Color = P.GROUND, Material = "Ground" }))
		local rng = BK.rng(500 + i)
		for leaf = 1, 7 do
			BK.part(F, with({
				Name = "Leaf", Size = V(0.3, rng.next(1.2, 2.4), 0.12), Color = P.GRASS_SPARSE, Material = "LeafyGrass",
				CFrame = CFrame.new(82.5 + rng.next(-0.8, 0.8), 22.3, z + rng.next(-1.8, 1.8)) * CFrame.Angles(rng.next(-0.4, 0.4), 0, rng.next(-0.4, 0.4)),
			}))
		end
	end
	Lib.Flag(F, CFrame.new(124.5, 20, -36.5) * Lib.FACE["+Z"], { name = "Flag" }) -- the cloth hangs east, clear of the parapet

	-- Rooftop plant: two HVAC units with fan grilles, an antenna with a blinking red beacon, a cable tray.
	for i, at in ipairs({ V(88, 20, -28), V(88, 20, 12) }) do
		BK.box(F, "HVAC" .. i, at + V(-3, 0, -2.5), at + V(3, 3.2, 2.5), { Color = P.STEEL_MID, Material = "Metal" })
		for _, dx in ipairs({ -1.4, 1.4 }) do
			BK.cyl(F, with({ Name = "HVACFan", Axis = "Y", Size = V(2.2, 0.15, 2.2), Position = at + V(dx, 3.25, 0), Color = P.STEEL_DARK, Material = "DiamondPlate" }))
		end
		BK.box(F, "HVACGrille" .. i, at + V(-2.9, 0.4, -2.56), at + V(2.9, 2.6, -2.5), with({ Color = P.STEEL_DARK, Material = "DiamondPlate" }))
	end
	local mast = V(84, 20, -36)
	BK.truss(F, { Name = "AntennaMast", Size = V(2, 14, 2), Position = mast + V(0, 7, 0), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	BK.cyl(F, with({ Name = "AntennaWhip", Axis = "Y", Size = V(0.15, 5, 0.15), Position = mast + V(0, 16.5, 0), Color = P.STEEL_LIGHT, Material = "Metal" }))
	BK.ball(F, with({ Name = "AntennaBeacon", Size = V(0.6, 0.6, 0.6), Position = mast + V(0, 14.3, 0), Color = P.DANGER_RED, Material = "Neon", Tags = { "HoloBlink" }, Attributes = { BlinkHz = 0.5 } }))
	BK.pipeRun(ctx.Detail, "CableTray", { V(84.6, 20.3, -33), V(84.6, 20.3, 36) }, 0.18, { color = P.HAZARD_BLACK })

	-- Four lamps lit at EVENING and NIGHT, at the north and south parapets, their arms over the deck.
	for i, at in ipairs({ { 100, -38, "+Z" }, { 120, -38, "+Z" }, { 100, 38, "-Z" }, { 120, 38, "-Z" } }) do
		Lib.StreetLamp(F, CFrame.new(at[1], 20, at[2]) * Lib.FACE[at[3]], { name = "DeckLamp" .. i, lightTags = { "EveningLamp", "HubLight" } })
	end
end

return Builder
