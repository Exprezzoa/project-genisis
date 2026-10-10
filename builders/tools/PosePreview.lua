--!nonstrict
-- builders/tools/PosePreview.lua  ->  ServerStorage.DevTools.Tools.PosePreview   (docs/08 §6)
--
-- Shows a rig template in a pose in edit mode, for judging poses by eye:
--
--   local Preview = require(DT.Tools.PosePreview:Clone())
--   Preview.show("Vanguard_02", "Light3", 0.32)                  -- a clip at a time (seconds)
--   Preview.show("Vanguard_02", "Idle", 0, { gait = { speed = 30, phase = 0 } })   -- with the walk cycle
--   Preview.show("Vanguard_02", "Light1", 0.18, { at = CFrame.new(40, 0, 0), keep = true })   -- side by side
--   Preview.clear()
--
-- The copy stands in Workspace.DevPreview, fully anchored. Joints aren't simulated in edit mode, so the tool
-- works the pose out itself: each joint's part is placed at Part0 * C0 * pose * C1^-1, and welded details
-- follow their part. NEVER ship DevPreview content: clear it before the user saves or publishes.

local Preview = {}

Preview.DEFAULT_AT = CFrame.new(-250, 0, -170) -- open ground in the Training Yard

function Preview.clear()
	local folder = workspace:FindFirstChild("DevPreview")
	if folder then
		folder:Destroy()
	end
end

function Preview.show(templateName, clipName, t, opts)
	opts = opts or {}
	local Shared = game:GetService("ReplicatedStorage").Shared:Clone()
	local PoseAnimator = require(Shared.Modules.PoseAnimator)
	local Locomotion = require(Shared.Config.Locomotion)
	local template = game:GetService("ServerStorage").Templates.Frames:FindFirstChild(templateName)
		or error("PosePreview: no template " .. tostring(templateName))
	local class = template:GetAttribute("Class")
	local set = PoseAnimator.compile(require(Shared.Poses[class]))
	local clip = set.clips[clipName] or error("PosePreview: no clip " .. tostring(clipName))

	if not opts.keep then
		Preview.clear()
	end
	local folder = workspace:FindFirstChild("DevPreview")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DevPreview"
		folder.Parent = workspace
	end
	local model = template:Clone()
	model.Name = ("%s_%s_%.2f"):format(templateName, clipName, t)

	-- The pose: idle (plus the gait when asked) with the clip laid over it.
	local offsets = nil
	if opts.gait then
		local params, amplitude = PoseAnimator.gaitParams(Locomotion[class], opts.gait.speed, Locomotion.IDLE_BELOW)
		offsets = PoseAnimator.gait(params, amplitude, opts.gait.phase or 0, Locomotion[class].bladeArm)
	end
	local pose = PoseAnimator.compose(set.poses.Idle, offsets, nil, PoseAnimator.sample(clip, t), 1, clip.upperBodyOnly and opts.gait ~= nil)

	-- Rest offsets of the welded details, then forward kinematics over the joints.
	local root = model.PrimaryPart
	local followers, children = {}, {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") and descendant.Part0 and descendant.Part1 then
			table.insert(followers, { anchor = descendant.Part0, part = descendant.Part1, offset = descendant.Part0.CFrame:ToObjectSpace(descendant.Part1.CFrame) })
		elseif descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			children[descendant.Part0] = children[descendant.Part0] or {}
			table.insert(children[descendant.Part0], descendant)
		end
	end
	local place = (opts.at or Preview.DEFAULT_AT) * CFrame.new(0, root.Position.Y, 0)
	local world = { [root] = place }
	local queue = { root }
	while #queue > 0 do
		local part = table.remove(queue)
		for _, motor in ipairs(children[part] or {}) do
			local entry = pose[motor.Name]
			local transform = if entry then PoseAnimator.toCFrame(entry, model:GetScale()) else CFrame.identity
			world[motor.Part1] = world[part] * motor.C0 * transform * motor.C1:Inverse()
			table.insert(queue, motor.Part1)
		end
	end
	-- Details can hang on details (a louver on a vent): resolve until nothing is left.
	local pending = followers
	while #pending > 0 do
		local nextPending = {}
		for _, follower in ipairs(pending) do
			if world[follower.anchor] then
				world[follower.part] = world[follower.anchor] * follower.offset
			else
				table.insert(nextPending, follower)
			end
		end
		if #nextPending == #pending then
			break
		end
		pending = nextPending
	end
	for part, cframe in pairs(world) do
		part.Anchored = true
		part.CFrame = cframe
	end
	model.Parent = folder
	return model
end

return Preview
