--!nonstrict
-- builders/maps/central_command/TrainingYard.lua  ->  DevTools.Builders.CentralCommand.TrainingYard
-- docs/maps/map_01_central_command.md §12 (X -420..-122, Z -300..-40), docs/07 §6 (Titan simulacrum, training
-- dummy), docs/10_titans.md §1.2 (hurtboxes of the Strider's standing state).
--
-- Blockout: the concrete pad, lane lines, the FrameBarrier ring (open at the hangar's west door), the Titan
-- Simulacrum with its hurtboxes, four training dummies, the dismount pad PAD_TRAINING, a stand-in for the
-- observation booth, and SPAWN_TRAINING. Jersey barriers and the pedestrian gate come with the later passes.

local Builder = {}

local V = Vector3.new

Builder.SIMULACRUM = V(-320, 0, -170) -- facing east
Builder.DUMMIES = { V(-260, 0, -250), V(-260, 0, -90), V(-380, 0, -250), V(-380, 0, -90) }

-- Strider main parts (docs/08 §3.2): { name, size, center }, model space (facing -Z, +X = its right).
local STRIDER = {
	{ "LowerTorso", V(12, 5, 7), V(0, 29.5, 0) },
	{ "UpperTorso", V(14, 14, 8), V(0, 39, 0) },
	{ "Head", V(7, 9, 7.5), V(0, 51.5, 0) },
	{ "LeftUpperArm", V(4, 14, 4), V(-9.5, 37, 0) },
	{ "RightUpperArm", V(4, 14, 4), V(9.5, 37, 0) },
	{ "LeftLowerArm", V(3.5, 14, 3.5), V(-9.5, 23, 0) },
	{ "RightLowerArm", V(3.5, 14, 3.5), V(9.5, 23, 0) },
	{ "LeftHand", V(4, 6, 2.5), V(-9.5, 13, 0) },
	{ "RightHand", V(4, 6, 2.5), V(9.5, 13, 0) },
	{ "LeftUpperLeg", V(5.5, 12, 5.5), V(-3.5, 21, 0) },
	{ "RightUpperLeg", V(5.5, 12, 5.5), V(3.5, 21, 0) },
	{ "LeftLowerLeg", V(4.5, 12, 4.5), V(-3.5, 9, 0) },
	{ "RightLowerLeg", V(4.5, 12, 4.5), V(3.5, 9, 0) },
	{ "LeftFoot", V(6, 3, 10), V(-3.5, 1.5, -2) },
	{ "RightFoot", V(6, 3, 10), V(3.5, 1.5, -2) },
}
local HRP_CENTER = V(0, 29.5, 0)
-- Standing hurtboxes (docs/10 §1.2): { zone, size, offset from the HRP center }.
local HURTBOXES = {
	{ "Body", V(14, 20, 8), V(0, 6, 0) },
	{ "Head", V(7, 9, 7.5), V(0, 22, 0) },
	{ "AnkleL", V(5.5, 7, 5.5), V(-3.5, -23, 0) },
	{ "AnkleR", V(5.5, 7, 5.5), V(3.5, -23, 0) },
	{ "ArmL", V(5, 28, 5), V(-9.5, -6.5, 0) },
	{ "ArmR", V(5, 28, 5), V(9.5, -6.5, 0) },
}

-- docs/07 §6 "Titan simulacrum": a static steel effigy with the Strider's main-part dimensions, ankle targets
-- in Neon amber, a core target on the back, and hurtboxes.
function Builder.simulacrum(BK, parent, cframe)
	local P = BK.Palette
	local model = BK.model(parent, "TitanSimulacrum")
	BK.attr(model, { TargetId = "SIMULACRUM", Simulacrum = true })
	local steel = { Color = P.STEEL_MID, Material = "Metal" }
	for _, spec in ipairs(STRIDER) do
		local props = table.clone(steel)
		props.Name, props.Size, props.CFrame = spec[1], spec[2], cframe * CFrame.new(spec[3])
		BK.part(model, props)
	end
	for _, sx in ipairs({ -1, 1 }) do
		BK.part(model, {
			Name = "AnkleTarget", Size = V(4.9, 1.2, 4.9), CFrame = cframe * CFrame.new(3.5 * sx, 6.5, 0), Color = P.AMBER,
			Material = "Neon", CanCollide = false, CanQuery = false,
		})
	end
	BK.cyl(model, {
		Name = "CoreTarget", Axis = "Z", Size = V(5, 5, 0.6), CFrame = cframe * CFrame.new(0, 41, 4.2), Color = P.AMBER,
		Material = "Neon", CanCollide = false, CanQuery = false,
	})
	local root = BK.part(model, {
		Name = "HumanoidRootPart", Size = V(10, 10, 6), CFrame = cframe * CFrame.new(HRP_CENTER), Transparency = 1,
		CanCollide = false, CanQuery = false, CastShadow = false,
	})
	model.PrimaryPart = root
	for _, spec in ipairs(HURTBOXES) do
		BK.part(model, {
			Name = "Hurtbox_" .. spec[1], Size = spec[2], CFrame = root.CFrame * CFrame.new(spec[3]), Transparency = 1,
			CanCollide = false, CanQuery = true, CanTouch = false, CastShadow = false, Tags = { "Hurtbox" },
			Attributes = { Zone = spec[1] },
		})
	end
	return model
end

-- docs/07 §6 "Training dummy (Frame-scale)", 14 x 36 x 10: plates on a spine, two arm stubs, a target disc.
function Builder.dummy(BK, parent, name, cframe)
	local P = BK.Palette
	local model = BK.model(parent, name)
	BK.part(model, { Name = "Spine", Size = V(3, 36, 3), CFrame = cframe * CFrame.new(0, 18, 0), Color = P.STEEL_DARK, Material = "Metal" })
	BK.part(model, { Name = "Base", Size = V(14, 2, 10), CFrame = cframe * CFrame.new(0, 1, 0), Color = P.STEEL_DARK, Material = "Metal" })
	BK.part(model, { Name = "Torso", Size = V(12, 14, 6), CFrame = cframe * CFrame.new(0, 22, 0), Color = P.VG_PRIMER, Material = "Metal" })
	BK.part(model, { Name = "Hips", Size = V(9, 8, 5), CFrame = cframe * CFrame.new(0, 10, 0), Color = P.STEEL_MID, Material = "Metal" })
	BK.part(model, { Name = "Head", Size = V(5, 5, 5), CFrame = cframe * CFrame.new(0, 33.5, 0), Color = P.STEEL_MID, Material = "Metal" })
	for _, sx in ipairs({ -1, 1 }) do
		BK.part(model, { Name = "ArmStub", Size = V(2, 4, 4), CFrame = cframe * CFrame.new(7 * sx, 26, 0), Color = P.STEEL_MID, Material = "Metal" })
	end
	BK.cyl(model, {
		Name = "TargetDisc", Axis = "Z", Size = V(6, 6, 0.3), CFrame = cframe * CFrame.new(0, 22, -3.1), Color = P.HAZARD_YELLOW,
		CanCollide = false,
	})
	return model
end

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "TrainingYard")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay

	-- The pad: top at Y 0, in two plates (parts stay under 512 studs).
	local concrete = { Color = P.CONCRETE_DARK, Material = "Concrete" }
	BK.box(S, "Pad_W", V(-420, -1, -300), V(-271, 0, -40), concrete)
	BK.box(S, "Pad_E", V(-271, -1, -300), V(-122, 0, -40), concrete)

	-- Painted lanes: the Frame lane from the west door to the simulacrum, and a ring around the target.
	local paint = { Color = P.HAZARD_YELLOW, CanCollide = false, CanQuery = false, CastShadow = false }
	for _, z in ipairs({ -135, -85 }) do
		BK.box(S, "LaneLine", V(-250, 0, z - 0.5), V(-122, 0.05, z + 0.5), paint)
	end
	local center = Builder.SIMULACRUM
	for index = 0, 23 do
		local angle = math.rad(index * 15)
		local segment = table.clone(paint)
		segment.Name = "RingSegment"
		segment.Size = V(1, 0.05, 12)
		segment.CFrame = CFrame.new(center + V(math.cos(angle) * 60, 0.025, math.sin(angle) * 60)) * CFrame.Angles(0, -angle, 0)
		BK.part(S, segment)
	end

	-- Frames can't leave the yard, except through the hangar's west door (Z -140..-80).
	BK.barrier(G, "FrameBarrier_W", V(-421, 0, -300), V(-420, 40, -40), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_N", V(-421, 0, -301), V(-122, 40, -300), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_S", V(-421, 0, -40), V(-122, 40, -39), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_E1", V(-123, 0, -300), V(-122, 40, -140), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_E2", V(-123, 0, -80), V(-122, 40, -40), "FrameBarrier")

	Builder.simulacrum(BK, G, BK.lookAlong(center, V(1, 0, 0)))
	for index, position in ipairs(Builder.DUMMIES) do
		Builder.dummy(BK, G, "TrainingDummy" .. index, BK.lookAlong(position, V(1, 0, 0)))
		-- A Frame's root floats 22 studs up, so it would walk onto a 36-stud dummy instead of into it (seen in
		-- play, D-049): every dummy gets a FrameBarrier box.
		BK.barrier(G, "FrameBarrier_Dummy" .. index, position + V(-6, 0, -10), position + V(6, 40, 10), "FrameBarrier")
	end

	BK.dismountPad(G, "PAD_TRAINING", V(-200, 0, -110), 22, BK.lookAlong(V(-174, 0, -110), V(1, 0, 0)))
	C.standIn(ctx, "ObservationBooth", V(-411, 0, -65), V(-399, 10, -55))

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
