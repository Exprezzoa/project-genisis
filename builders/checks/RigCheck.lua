--!nonstrict
-- builders/checks/RigCheck.lua  ->  ServerStorage.DevTools.Checks.RigCheck   (docs/08 §2-3.1, docs/09 §1-2)
--
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.RigCheck:Clone()).Run())
--
-- Checks every Vanguard template in ServerStorage.Templates.Frames against the rig rules:
--   * main parts: size and center from the builder's table; joints: C0 = joint - Part0 center,
--     C1 = joint - Part1 center, no rotation (the PileDriver's C1 may carry the cylinder's own turn, BladeGrip's
--     C0 is the grip angle of docs/09 §2);
--   * HRP and Humanoid settings of docs/08 §2; no Animator; nothing anchored; every part reaches the HRP;
--   * detail parts never collide or answer queries (the Hatch answers queries: it carries the boarding prompt);
--   * required named parts and attachments exist; at most 1500 parts (D-041); the main parts top out at 40 studs.

local Check = {}

local V = Vector3.new
local BUDGET = 1500
local REQUIRED = {
	"Hatch", "PD_Spike", "PilotSeat", "Prompt_Board", "Blade_Grip", "TrailBase", "TrailTip", "Visor", "Facing", "FacingAttachment",
	"HatchHinge", "PileDriver", "BladeGrip",
}
local QUERYABLE = { Hatch = true }

local function near(a, b, tolerance)
	return (a - b).Magnitude <= (tolerance or 0.01)
end

local function isPureOffset(cframe)
	return near(cframe.XVector, V(1, 0, 0), 1e-4) and near(cframe.YVector, V(0, 1, 0), 1e-4)
end

function Check.Run()
	local DT = game:GetService("ServerStorage").DevTools
	local Builder = require(DT.Builders.Rigs.Vanguard:Clone())
	local fails, info = {}, {}
	local function fail(message)
		table.insert(fails, message)
	end

	local templates = game:GetService("ServerStorage").Templates.Frames
	for unit in pairs(Builder.UNITS) do
		local tag = "Vanguard_" .. unit
		local model = templates:FindFirstChild(tag)
		if not model then
			fail(tag .. ": template missing")
			continue
		end
		local function part(name)
			local found = model:FindFirstChild(name)
			if not found then
				fail(tag .. ": main part " .. name .. " missing")
			end
			return found
		end

		-- Main parts.
		local top = 0
		for name, spec in pairs(Builder.MAIN) do
			local sides = if spec[2].X == 0 then { { "", 1 } } else { { "Left", -1 }, { "Right", 1 } }
			for _, side in ipairs(sides) do
				local found = part(side[1] .. name)
				if found then
					local center = V(spec[2].X * side[2], spec[2].Y, spec[2].Z)
					if not near(found.Size, spec[1]) then
						fail(("%s: %s size %s, expected %s"):format(tag, found.Name, tostring(found.Size), tostring(spec[1])))
					end
					if not near(found.Position, center) then
						fail(("%s: %s center %s, expected %s"):format(tag, found.Name, tostring(found.Position), tostring(center)))
					end
					top = math.max(top, found.Position.Y + found.Size.Y / 2)
				end
			end
		end
		if math.abs(top - 40) > 0.01 then
			fail(("%s: main parts top out at %.2f, expected 40"):format(tag, top))
		end

		-- Joints.
		local jointCount = 0
		for _, entry in ipairs(Builder.JOINTS) do
			local sides = if entry.sided then { { "Left", -1 }, { "Right", 1 } } else { { "", 1 } }
			for _, side in ipairs(sides) do
				local name = side[1] .. entry[1]
				local motor = model:FindFirstChild(name, true)
				if not (motor and motor:IsA("Motor6D")) then
					fail(tag .. ": joint " .. name .. " missing")
					continue
				end
				jointCount += 1
				local position = V(entry[4].X * side[2], entry[4].Y, entry[4].Z)
				local part0 = model:FindFirstChild(entry[2]) or model:FindFirstChild(side[1] .. entry[2])
				local part1 = model:FindFirstChild(entry[3]) or model:FindFirstChild(side[1] .. entry[3])
				if motor.Part0 ~= part0 or motor.Part1 ~= part1 or motor.Parent ~= part1 then
					fail(tag .. ": joint " .. name .. " connects the wrong parts or isn't parented to Part1")
				elseif not (isPureOffset(motor.C0) and isPureOffset(motor.C1)) then
					fail(tag .. ": joint " .. name .. " has a rotated rest C0/C1")
				elseif not (near(motor.C0.Position, position - part0.Position) and near(motor.C1.Position, position - part1.Position)) then
					fail(tag .. ": joint " .. name .. " C0/C1 don't match the joint position")
				end
			end
		end
		local hinge = model:FindFirstChild("HatchHinge", true)
		if hinge and not (near(hinge.C0.Position, V(0, 4.5, -5)) and near(hinge.C1.Position, V(0, 3, 0.3)) and isPureOffset(hinge.C0) and isPureOffset(hinge.C1)) then
			fail(tag .. ": HatchHinge C0/C1 differ from docs/08 §3.1")
		end
		local slide = model:FindFirstChild("PileDriver", true)
		if slide and not (near(slide.C0.Position, V(-4.1, -3.5, 0)) and isPureOffset(slide.C0) and near(slide.C1.Position, V(0, 0, 0))) then
			fail(tag .. ": PileDriver C0/C1 differ from docs/09 §2")
		end

		-- Root and Humanoid.
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp then
			if not (near(hrp.Size, Builder.HRP[1]) and near(hrp.Position, Builder.HRP[2])) then
				fail(tag .. ": HRP size or center wrong")
			end
			if not (hrp.Transparency == 1 and hrp.CanCollide and not hrp.CanQuery and not hrp.CanTouch and hrp.RootPriority == 127 and model.PrimaryPart == hrp) then
				fail(tag .. ": HRP settings differ from docs/08 §2.2")
			end
			local physical = hrp.CustomPhysicalProperties
			if not (physical and math.abs(physical.Density - 0.7) < 1e-3 and math.abs(physical.Friction - 0.3) < 1e-3 and physical.Elasticity == 0) then
				fail(tag .. ": HRP physical properties differ from docs/08 §2.2")
			end
		else
			fail(tag .. ": HumanoidRootPart missing")
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			fail(tag .. ": Humanoid missing")
		else
			if humanoid.HipHeight ~= Builder.HIP_HEIGHT or humanoid.AutoRotate or humanoid.JumpPower ~= 0 or humanoid.MaxSlopeAngle ~= 50 or humanoid.BreakJointsOnDeath or humanoid.RequiresNeck or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
				fail(tag .. ": Humanoid settings differ from docs/08 §2.6")
			end
			if model:FindFirstChildWhichIsA("Animator", true) then
				fail(tag .. ": has an Animator (the PPA owns the joints)")
			end
		end

		-- Every part.
		local parts, connected = 0, {}
		if hrp then
			-- Walk the joints by hand: GetConnectedParts only works inside Workspace.
			local links = {}
			for _, descendant in ipairs(model:GetDescendants()) do
				if (descendant:IsA("Motor6D") or descendant:IsA("WeldConstraint")) and descendant.Part0 and descendant.Part1 then
					for _, pair in ipairs({ { descendant.Part0, descendant.Part1 }, { descendant.Part1, descendant.Part0 } }) do
						links[pair[1]] = links[pair[1]] or {}
						table.insert(links[pair[1]], pair[2])
					end
				end
			end
			local queue = { hrp }
			connected[hrp] = true
			while #queue > 0 do
				for _, other in ipairs(links[table.remove(queue)] or {}) do
					if not connected[other] then
						connected[other] = true
						table.insert(queue, other)
					end
				end
			end
		end
		local main = { HumanoidRootPart = true }
		for name, spec in pairs(Builder.MAIN) do
			main[name], main["Left" .. name], main["Right" .. name] = true, true, true
		end
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				parts += 1
				if descendant.Anchored then
					fail(tag .. ": " .. descendant.Name .. " is anchored")
				end
				if hrp and not connected[descendant] and descendant ~= hrp then
					fail(tag .. ": " .. descendant.Name .. " isn't joined to the HRP")
				end
				if descendant ~= hrp then
					if descendant.CanCollide or descendant.CanTouch or not descendant.Massless then
						fail(tag .. ": " .. descendant.Name .. " collides, touches or has mass")
					end
					if descendant.CanQuery and not QUERYABLE[descendant.Name] then
						fail(tag .. ": " .. descendant.Name .. " answers queries")
					end
				end
			end
		end
		if parts > BUDGET then
			fail(("%s: %d parts, budget %d"):format(tag, parts, BUDGET))
		end
		for _, name in ipairs(REQUIRED) do
			if not model:FindFirstChild(name, true) then
				fail(tag .. ": " .. name .. " missing")
			end
		end
		if model:GetAttribute("Unit") ~= unit or model:GetAttribute("Class") ~= "Vanguard" then
			fail(tag .. ": Unit/Class attributes wrong")
		end
		info[tag] = { parts = parts, joints = jointCount, top = top }
	end
	-- At most 20 messages: one broken rule can repeat for every part.
	local shown = table.move(fails, 1, math.min(#fails, 20), 1, {})
	return { pass = #fails == 0, failCount = #fails, fails = shown, info = info }
end

return Check
