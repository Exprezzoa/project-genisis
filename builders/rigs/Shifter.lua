--!nonstrict
-- builders/rigs/Shifter.lua  ->  ServerStorage.DevTools.Builders.Rigs.Shifter
-- docs/02 §8 (Shifters), docs/10 "Shifter transformation", docs/03 (Elias); D-095.
--
--   Build({ BK = BK, Body = require(DT.Builders.Rigs.Watcher:Clone()) })  -> stats
--       builds ServerStorage.Templates.Titans.Shifter_Elias
--
-- Elias's Titan form, a placeholder until it is designed (Q-020): the body of the user's Titan model rigged the
-- way the Watcher is (builders/rigs/Watcher.copy), without what is the Watcher's own (its white hair, pointed
-- ears and wrist bands), with Elias's skin tone, a dark messy head of hair from the checked Titan hair, and eyes
-- glowing Lattice cyan (a Shifter's glow, docs/02 §8). It is ridden like a Frame (Server/Services/ShifterService,
-- Client/Controllers/FrameController): a Humanoid, a root with its Facing (anchored here, let go at spawn), a
-- PilotSeat in the nape, and Dust attachments under the feet for the footfall puffs.

local Builder = {}

local V = Vector3.new

Builder.NAME = "Shifter_Elias"
Builder.SKIN = Color3.fromHex("#C69C7A") -- Elias's skin (docs/03)
Builder.HAIR = "MessyHair" -- "short messy crop, dark brown" (docs/03): one of ServerStorage.Templates.TitanHair
Builder.EYES = Color3.fromHex("#7FE3F0") -- LATTICE_CYAN: reserved for resonance and Shifters (docs/06 §3)

-- The colors of the reference's skin (as in builders/rigs/Strider).
local SKIN = { ["eab892"] = true, ["ffcc99"] = true }

function Builder.Build(opts)
	local BK, Body = opts.BK, opts.Body
	local startClock = os.clock()
	local ServerStorage = game:GetService("ServerStorage")
	local templates = BK.folder(BK.folder(ServerStorage, "Templates"), "Titans")
	local old = templates:FindFirstChild(Builder.NAME)
	if old then
		old:Destroy()
	end
	local model, info = Body.copy(BK, {
		name = Builder.NAME,
		leaveOut = function(part)
			return part.Material == Enum.Material.Ice or part.Name == "Ears" or part.Name == "Handle"
		end,
	})
	local main, hrp, jointAt = info.main, info.hrp, info.jointAt
	local head = main.Head

	-- Skin, eyes, hair.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if SKIN[part.Color:ToHex()] then
				part:SetAttribute("Skin", true)
				part.Color = Builder.SKIN
			elseif part.Material == Enum.Material.Neon and part:IsDescendantOf(head) then
				part.Color = Builder.EYES
			end
		end
	end
	model:SetAttribute("HeadWidth", head.Size.X)
	local anchor = Instance.new("Attachment")
	anchor.Name = "HairAnchor" -- at the head's center, turned like the rig (TitanLook.setHair)
	anchor.CFrame = head.CFrame:ToObjectSpace(CFrame.new(head.Position))
	anchor.Parent = head
	local TitanLook = require(game:GetService("ServerScriptService").Server.Titans.TitanLook:Clone())
	local hair = ServerStorage.Templates:FindFirstChild("TitanHair") and ServerStorage.Templates.TitanHair:FindFirstChild(Builder.HAIR)
	if hair then
		TitanLook.setHair(model, hair)
	else
		BK.warn(("Shifter builder: no Titan hair %s (run builders/rigs/Strider BuildHair)"):format(Builder.HAIR))
	end

	-- Ridden like a Frame: the root stands on the ground with the Humanoid's hip height and turns by Facing.
	hrp.CanCollide = true
	hrp.Massless = false
	hrp.RootPriority = 127
	hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hrp.Position.Y - hrp.Size.Y / 2
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxSlopeAngle = 50
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 0
	humanoid.Parent = model
	local facingAttachment = Instance.new("Attachment")
	facingAttachment.Name = "FacingAttachment"
	facingAttachment.Parent = hrp
	local facing = Instance.new("AlignOrientation")
	facing.Name = "Facing"
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = facingAttachment
	facing.RigidityEnabled = false
	facing.MaxTorque = math.huge
	facing.Responsiveness = 40
	facing.MaxAngularVelocity = math.rad(120)
	facing.Enabled = false
	facing.Parent = hrp

	-- The rider sits in the nape, hidden (FrameController hides the pilot on their own screen).
	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Size = V(2, 1, 2)
	seat.CFrame = CFrame.new(jointAt.Neck + V(0, -4, 3))
	seat.Transparency = 1
	seat.CanCollide, seat.CanTouch, seat.CanQuery = false, false, false
	seat.Massless = true
	seat.Anchored = false
	seat.Parent = model
	BK.weld(main.UpperTorso, seat)

	-- Where a footfall raises dust: under each sole.
	for _, side in ipairs({ "Left", "Right" }) do
		local foot = main[side .. "Foot"]
		local dust = Instance.new("Attachment")
		dust.Name = "Dust"
		dust.Position = foot.CFrame:PointToObjectSpace(V(foot.Position.X, 0.5, foot.Position.Z))
		dust.Parent = foot
	end

	-- Class = its pose set (Shared/Poses/Shifter) and its entry in Config/FrameConfig (how it is ridden).
	BK.attr(model, { Class = "Shifter", PivotToFeet = hrp.Position.Y, Height = info.top - info.low })
	model.Parent = templates
	local stats = BK.report(model, startClock)
	stats.height = info.top - info.low
	stats.hipHeight = humanoid.HipHeight
	stats.hair = model:GetAttribute("Hair")
	return stats
end

return Builder
