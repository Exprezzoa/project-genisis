-- job: 0003-research-exterior-dressed
-- Phase 7: build Research and Exterior at the dressed pass, then run HubCheck and NavCheck.
-- Each builder is idempotent: it clears and rebuilds only its own Workspace.Map.CentralCommand.<Area> folder.
return function(ctx)
	local function count(path)
		local root = ctx.find(path)
		if not root then
			return nil
		end
		local parts, lights = 0, 0
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("Light") then
				lights += 1
			end
		end
		return { parts = parts, lights = lights }
	end

	local BK = ctx.requireFresh("ServerStorage.DevTools.BuildKit")
	local Common = ctx.requireFresh("ServerStorage.DevTools.Builders.Common")
	local Props = ctx.requireFresh("ServerStorage.DevTools.Props")(BK)

	local out = { before = {}, built = {} }
	for _, area in ipairs({ "Research", "Exterior" }) do
		out.before[area] = count("Workspace.Map.CentralCommand." .. area)
		local builder = ctx.requireFresh("ServerStorage.DevTools.Builders.CentralCommand." .. area)
		local ok, stats = pcall(builder.Build, { BK = BK, Common = Common, Props = Props, pass = "dressed" })
		out.built[area] = if ok then stats else { error = tostring(stats) }
	end

	out.hubCheck = ctx.requireFresh("ServerStorage.DevTools.Checks.HubCheck").Run()
	out.navCheck = ctx.requireFresh("ServerStorage.DevTools.Checks.NavCheck").Run()
	return out
end
