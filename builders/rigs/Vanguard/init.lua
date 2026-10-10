--!nonstrict
-- builders/rigs/Vanguard/init.lua  ->  ServerStorage.DevTools.Builders.Rigs.Vanguard   (children: Kit, Legs, Torso, Arms)
-- docs/09_frames.md §2-3 (part-by-part build, unit variants), docs/08_rigs_and_animation.md §2-3.1 (rig rules,
-- joint table).
--
--   Build({ BK = BK, unit = "02" })  -> stats     builds ServerStorage.Templates.Frames.Vanguard_<unit>
--   Builder.MAIN, Builder.JOINTS                  the tables of docs/08 §3.1 (RigCheck reads them)
--
-- Model space: origin on the ground under the HRP, facing -Z, +X = the rig's right. The main parts are the
-- rig's bones: they keep the sizes and centers of docs/08 but are invisible (D-041). Everything you see is a
-- detail welded to a bone, built by Legs, Torso and Arms out of the shapes in Kit.

local Builder = {}

local V = Vector3.new
local rad = math.rad

Builder.UNITS = {
	["01"] = { accent = "VG_ACCENT_MARA", tally = "41" },
	["02"] = { accent = "VG_ACCENT_ELIAS" },
}

-- name = { size, center }   (docs/08 §3.1; sx = -1 left, +1 right is applied to X)
Builder.MAIN = {
	LowerTorso = { V(12, 4, 8), V(0, 22, 0) },
	UpperTorso = { V(16, 11, 10), V(0, 29.5, 0) },
	Head = { V(5, 5, 5.5), V(0, 37.5, 0) },
	UpperArm = { V(3.5, 10, 3.5), V(10.5, 27, 0) },
	LowerArm = { V(4, 9, 4), V(10.5, 17.5, 0) },
	Hand = { V(4, 3, 3.5), V(10.5, 10.75, 0) },
	UpperLeg = { V(4.5, 8, 4.5), V(3.75, 16, 0) },
	LowerLeg = { V(5, 9, 5.5), V(3.75, 7.5, 0) },
	Foot = { V(6, 3, 10), V(3.75, 1.5, -1.5) },
}
Builder.HRP = { V(10, 10, 6), V(0, 19, 0) }
Builder.HIP_HEIGHT = 14

-- { joint, part0, part1, joint position }; "L/R" entries are expanded for both sides.
Builder.JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", V(0, 22, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", V(0, 24, 0) },
	{ "Neck", "UpperTorso", "Head", V(0, 35, 0) },
	{ "Shoulder", "UpperTorso", "UpperArm", V(10.5, 32, 0), sided = true },
	{ "Elbow", "UpperArm", "LowerArm", V(10.5, 22, 0), sided = true },
	{ "Wrist", "LowerArm", "Hand", V(10.5, 13, 0), sided = true },
	{ "Hip", "LowerTorso", "UpperLeg", V(3.75, 20, 0), sided = true },
	{ "Knee", "UpperLeg", "LowerLeg", V(3.75, 12, 0), sided = true },
	{ "Ankle", "LowerLeg", "Foot", V(3.75, 3, 0), sided = true },
}

local SIDES = { { "Left", -1 }, { "Right", 1 } }

function Builder.Build(opts)
	local BK = opts.BK
	local P = BK.Palette
	local unit = opts.unit or "02"
	local variant = Builder.UNITS[unit] or error("Vanguard builder: unknown unit " .. tostring(unit))
	local startClock = os.clock()

	local templates = game:GetService("ServerStorage").Templates.Frames
	local old = templates:FindFirstChild("Vanguard_" .. unit)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Vanguard_" .. unit
	BK.attr(model, { Class = "Vanguard", Unit = unit })

	local K = require(script.Kit).new(BK, model)
	local main = {}

	----------------------------------------------------------------------------------------------------------------
	-- Bones and joints
	----------------------------------------------------------------------------------------------------------------
	local hrp = K.raw("part", model, "HumanoidRootPart", Builder.HRP[1], CFrame.new(Builder.HRP[2]), P.VG_FRAME, "SmoothPlastic", {
		Transparency = 1, CanCollide = true, Massless = false, CastShadow = false,
	})
	hrp.RootPriority = 127
	hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	main.HumanoidRootPart = hrp
	model.PrimaryPart = hrp

	local function bone(name, size, center)
		main[name] = K.raw("part", model, name, size, CFrame.new(center), P.VG_FRAME, "Metal", { Transparency = 1, CastShadow = false })
	end
	for name, spec in pairs(Builder.MAIN) do
		if spec[2].X == 0 then
			bone(name, spec[1], spec[2])
		else
			for _, side in ipairs(SIDES) do
				bone(side[1] .. name, spec[1], V(spec[2].X * side[2], spec[2].Y, spec[2].Z))
			end
		end
	end

	local function joint(name, part0, part1, position)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = CFrame.new(position - part0.Position)
		motor.C1 = CFrame.new(position - part1.Position)
		motor.Parent = part1
		return motor
	end
	for _, entry in ipairs(Builder.JOINTS) do
		if entry.sided then
			for _, side in ipairs(SIDES) do
				local function sided(partName)
					return main[partName] or main[side[1] .. partName]
				end
				joint(side[1] .. entry[1], sided(entry[2]), sided(entry[3]), V(entry[4].X * side[2], entry[4].Y, entry[4].Z))
			end
		else
			joint(entry[1], main[entry[2]], main[entry[3]], entry[4])
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- Everything visible
	----------------------------------------------------------------------------------------------------------------
	local ctx = {
		BK = BK, K = K, P = P, model = model, main = main, unit = unit, variant = variant,
		accent = P[variant.accent], SIDES = SIDES,
	}
	require(script.Legs)(ctx)
	require(script.Torso)(ctx)
	require(script.Arms)(ctx)

	----------------------------------------------------------------------------------------------------------------
	-- Humanoid and facing control (docs/08 §2.6, §2.1)
	----------------------------------------------------------------------------------------------------------------
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = Builder.HIP_HEIGHT
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxSlopeAngle = 50
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = true
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local alignAttachment = K.attachment(hrp, "FacingAttachment", V(0, 0, 0))
	local align = Instance.new("AlignOrientation")
	align.Name = "Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = alignAttachment
	align.RigidityEnabled = false
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.MaxAngularVelocity = rad(150)
	align.PrimaryAxisOnly = false
	align.CFrame = CFrame.new()
	align.Enabled = false
	align.Parent = hrp

	model.Parent = templates
	return BK.report(model, startClock)
end

return Builder
