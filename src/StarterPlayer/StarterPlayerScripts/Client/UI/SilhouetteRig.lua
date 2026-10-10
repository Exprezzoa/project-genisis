--!nonstrict
-- Client/UI/SilhouetteRig.lua  (docs/14_ui.md §1.2)
--
-- Poses an anchored copy of an R15 character by code, for the menu silhouette. A ViewportFrame has no physics
-- and the avatar's joints are AnimationConstraints, so nothing would move there on its own: this computes
-- each body part's CFrame from joint rotations (forward kinematics) and moves the welded gear along.
--
--   local rig = SilhouetteRig.new(model)        -- model: anchored R15 clone standing in its rest pose
--   rig:apply(pose, rootOffset)                 -- pose: { JointName = Vector3(rx, ry, rz) in degrees }
--
-- Rotation convention (docs/08 §4.1), in the joint's rest frame: +X swings a hanging limb forward (arm raise,
-- elbow bend) and tips the torso or head back; +Y turns to the character's left; +Z swings a hanging limb
-- toward the character's right.

local SilhouetteRig = {}
SilhouetteRig.__index = SilhouetteRig

local ROOT = "LowerTorso"
-- { joint, parent part, child part }, parents before children.
local JOINTS = {
	{ "Waist", "LowerTorso", "UpperTorso" },
	{ "Neck", "UpperTorso", "Head" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm" },
	{ "RightWrist", "RightLowerArm", "RightHand" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand" },
	{ "RightHip", "LowerTorso", "RightUpperLeg" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot" },
}

function SilhouetteRig.new(model)
	local self = setmetatable({ joints = {}, followers = {}, world = {} }, SilhouetteRig)
	local root = model:FindFirstChild(ROOT)
	if not root then
		error("SilhouetteRig: the model has no " .. ROOT, 2)
	end
	self.root = root
	self.rootRest = root.CFrame
	local body = { [root] = true }
	for _, entry in ipairs(JOINTS) do
		local parent, child = model:FindFirstChild(entry[2]), model:FindFirstChild(entry[3])
		local attachment = child and child:FindFirstChild(entry[1] .. "RigAttachment")
		if parent and child and attachment then
			-- The pivot keeps the parent's rest orientation, so rotations are in the rest frame.
			local pivot = CFrame.new(attachment.WorldPosition) * parent.CFrame.Rotation
			table.insert(self.joints, {
				name = entry[1],
				parent = parent,
				child = child,
				pivotInParent = parent.CFrame:ToObjectSpace(pivot),
				childFromPivot = pivot:ToObjectSpace(child.CFrame),
			})
			body[child] = true
		end
	end
	-- Gear and hair follow the body part they are welded to.
	for _, weld in ipairs(model:GetDescendants()) do
		if weld:IsA("WeldConstraint") and weld.Part0 and weld.Part1 then
			local anchor, part = weld.Part0, weld.Part1
			if body[part] and not body[anchor] then
				anchor, part = part, anchor
			end
			if body[anchor] and not body[part] then
				table.insert(self.followers, { part = part, anchor = anchor, offset = anchor.CFrame:ToObjectSpace(part.CFrame) })
			end
		end
	end
	return self
end

-- pose: { JointName = Vector3 degrees }; joints that are missing stay at rest. rootOffset: CFrame applied to
-- the whole body (bob, lean), default identity.
function SilhouetteRig:apply(pose, rootOffset)
	local world = self.world
	world[self.root] = self.rootRest * (rootOffset or CFrame.identity)
	self.root.CFrame = world[self.root]
	for _, joint in ipairs(self.joints) do
		local angles = pose[joint.name]
		local rotation = if angles then CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z)) else CFrame.identity
		local cframe = world[joint.parent] * joint.pivotInParent * rotation * joint.childFromPivot
		world[joint.child] = cframe
		joint.child.CFrame = cframe
	end
	for _, follower in ipairs(self.followers) do
		follower.part.CFrame = world[follower.anchor] * follower.offset
	end
end

return SilhouetteRig
