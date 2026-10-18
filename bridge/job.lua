-- job: 0004-training-yard
-- Phase 7: the Training Yard's structure and dressed passes (map_01 §12, D-105). Pushes the new builder (only if
-- Studio still holds the version from the baseline), builds blockout -> structure -> dressed (each idempotent, so the
-- last one stands), then runs HubCheck, NavCheck and BuildKitCheck's smoke test.
return function(ctx)
	local push = ctx.push({ { file = "builders/maps/central_command/TrainingYard.lua", expect = 977157613 } })
	if push[1].status ~= "updated" and push[1].status ~= "unchanged" then
		return { stopped = "push failed", push = push }
	end

	local BK = ctx.requireFresh("ServerStorage.DevTools.BuildKit")
	local Common = ctx.requireFresh("ServerStorage.DevTools.Builders.Common")
	local Props = ctx.requireFresh("ServerStorage.DevTools.Props")(BK)
	local Yard = ctx.requireFresh("ServerStorage.DevTools.Builders.CentralCommand.TrainingYard")

	local passes = {}
	for _, pass in ipairs({ "blockout", "structure", "dressed" }) do
		local ok, stats = pcall(Yard.Build, { BK = BK, Common = Common, Props = Props, pass = pass })
		passes[pass] = if ok then stats else { error = tostring(stats) }
	end

	-- What a few key parts ended up as, to check placement without a screenshot.
	local root = ctx.find("Workspace.Map.CentralCommand.TrainingYard")
	local probes = {}
	for _, name in ipairs({ "PedestrianGate", "ObservationBooth", "Mast1", "Mast5", "Crates_NW", "PlateRack1" }) do
		local inst = root and root:FindFirstChild(name, true)
		if inst and inst:IsA("Model") then
			local cf, size = inst:GetBoundingBox()
			probes[name] = { center = { cf.X, cf.Y, cf.Z }, size = { size.X, size.Y, size.Z } }
		else
			probes[name] = "missing"
		end
	end
	local jersey = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and string.sub(d.Name, 1, 7) == "Jersey_" then
			jersey += 1
		end
	end

	return {
		push = push,
		passes = passes,
		jerseyBarriers = jersey,
		probes = probes,
		hubCheck = ctx.requireFresh("ServerStorage.DevTools.Checks.HubCheck").Run(),
		navCheck = ctx.requireFresh("ServerStorage.DevTools.Checks.NavCheck").Run(),
	}
end
