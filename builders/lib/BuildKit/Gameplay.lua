--!nonstrict
-- BuildKit/Gameplay: triggers, prompts, spawn points, camera points, nav nodes, dismount pads, barriers.
-- These are built in EVERY pass so gameplay can be tested on blockouts (docs/07 section 2).
-- Tags and attributes follow docs/13 sections 4-5 and docs/16 section 7. The server resolves IDs by
-- scanning tags, so every ID must be unique.

return function(BK)
	local P = BK.Palette

	local BARRIER_GROUPS = { FrameBarrier = true, PlayerBarrier = true }
	local MAX_ID_LENGTH = 64

	local function checkId(id, functionName)
		if type(id) ~= "string" or id == "" or #id > MAX_ID_LENGTH then
			error(("[BuildKit] %s: the id must be a non-empty string of at most %d characters"):format(functionName, MAX_ID_LENGTH), 3)
		end
	end

	-- An invisible, non-colliding marker part.
	local function marker(parent, name, cframe, tags, attributes)
		return BK.part(parent, {
			Name = name,
			Size = Vector3.one,
			CFrame = cframe,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Tags = tags,
			Attributes = attributes,
		})
	end

	-- Box trigger. TriggerService polls point-in-box at 5 Hz; .Touched is never used (docs/13 section 5).
	function BK.trigger(parent, name, min, max, id)
		checkId(id, "BK.trigger")
		return BK.box(parent, name, min, max, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = true,
			CastShadow = false,
			Tags = { "Trigger" },
			Attributes = { TriggerId = id },
		})
	end

	-- ProximityPrompt with the custom style (the client draws the UI, docs/14 section 4).
	-- frameOnly prompts default to MaxActivationDistance 70 and no line-of-sight check: the engine measures from
	-- the pilot, who sits about 49 studs up in a 64-stud Frame (docs/13 section 4 gives 30; GameConfig, D-068).
	-- Extra opts: once, enabled (step-gated prompts start disabled), lineOfSight, objectText.
	function BK.prompt(onPart, id, actionText, opts)
		checkId(id, "BK.prompt")
		opts = opts or {}
		local frameOnly = opts.frameOnly == true
		local onFootOnly = opts.onFootOnly == true
		if frameOnly and onFootOnly then
			error("[BuildKit] BK.prompt: frameOnly and onFootOnly cannot both be true", 2)
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = actionText or ""
		prompt.ObjectText = opts.objectText or ""
		prompt.HoldDuration = opts.hold or 0
		prompt.MaxActivationDistance = opts.dist or (if frameOnly then 70 else 8)
		prompt.RequiresLineOfSight = if opts.lineOfSight ~= nil then opts.lineOfSight else not frameOnly
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Enabled = opts.enabled ~= false
		prompt.Parent = onPart

		BK.tag(onPart, "Interactable")
		BK.attr(onPart, { InteractId = id, FrameOnly = frameOnly, OnFootOnly = onFootOnly, Once = opts.once == true })
		return prompt
	end

	-- The marker's CFrame is exactly the registry CFrame (position on the floor, facing along -Z).
	function BK.spawnPoint(parent, id, cframe)
		checkId(id, "BK.spawnPoint")
		return marker(parent, id, cframe, { "SpawnPoint" }, { SpawnId = id })
	end

	function BK.camPoint(parent, id, pos, lookAt)
		checkId(id, "BK.camPoint")
		return marker(parent, id, BK.lookAlong(pos, lookAt - pos), { "CinematicCam" }, { CamId = id, LookAt = lookAt })
	end

	-- links is a list of neighbouring node ids; stored as the comma-separated attribute Links.
	function BK.navNode(parent, id, pos, links)
		checkId(id, "BK.navNode")
		return marker(parent, id, CFrame.new(pos), { "NavNode" }, { NavId = id, Links = table.concat(links or {}, ",") })
	end

	-- Dismount pad (docs/maps/map_03 section 6): concrete disc with a yellow ring, floor text, 4 amber edge
	-- lights, and the invisible ExitPoint marker the pilot is teleported to. `center` is ON the ground.
	-- The model is tagged "DismountPad" with attributes PadId, Radius, Center. The visuals never collide.
	function BK.dismountPad(parent, id, center, radius, exitPoint)
		checkId(id, "BK.dismountPad")
		local model = BK.model(parent, id)
		BK.tag(model, "DismountPad")
		BK.attr(model, { PadId = id, Radius = radius, Center = center })

		local ring = BK.cyl(model, {
			Name = "Ring",
			Axis = "Y",
			Size = Vector3.new(radius * 2, 0.2, radius * 2),
			CFrame = CFrame.new(center),
			Color = P.HAZARD_YELLOW,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		BK.cyl(model, {
			Name = "Disc",
			Axis = "Y",
			Size = Vector3.new((radius - 1) * 2, 0.22, (radius - 1) * 2),
			CFrame = CFrame.new(center + Vector3.new(0, 0.01, 0)),
			Color = P.CONCRETE_MID,
			Material = Enum.Material.Concrete,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		BK.floorText(model, "Label", center + Vector3.new(0, 0.12, 0), Vector2.new(radius, radius * 0.25), (string.gsub(id, "_", " ")))

		for i, direction in ipairs({ -Vector3.zAxis, Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis }) do
			local lamp = BK.part(model, {
				Name = ("EdgeLight%d"):format(i),
				Size = Vector3.new(1, 0.3, 1),
				CFrame = CFrame.new(center + direction * (radius - 0.5) + Vector3.new(0, 0.15, 0)),
				Color = BK.GLOW.amber.Color,
				Transparency = BK.GLOW.amber.Transparency,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			BK.light(lamp, "Point", { Color = P.AMBER, Brightness = 1, Range = 12 })
		end

		marker(model, "ExitPoint", exitPoint, nil, nil)
		model.PrimaryPart = ring
		return model
	end

	-- Invisible collider in the FrameBarrier or PlayerBarrier collision group (docs/07 section 5).
	-- It stays queryable (lunge pre-checks box-cast against barriers) but cameras ignore it.
	function BK.barrier(parent, name, min, max, group)
		if not BARRIER_GROUPS[group] then
			error("[BuildKit] BK.barrier: group must be 'FrameBarrier' or 'PlayerBarrier', got " .. tostring(group), 2)
		end
		return BK.box(parent, name, min, max, {
			Transparency = 1,
			CanCollide = true,
			CanQuery = true,
			CanTouch = false,
			CastShadow = false,
			CollisionGroup = group,
			Tags = { "NoCollideCamera" },
		})
	end
end
