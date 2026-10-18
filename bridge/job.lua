-- job: 0002-arrival-dressed
-- Phase 7: build the Arrival (concourse, platform, rail line, train CT-9) at the dressed pass, then run HubCheck.
-- The builder is idempotent: it clears and rebuilds only Workspace.Map.CentralCommand.Arrival.
return function(ctx)
	local before = ctx.find("Workspace.Map.CentralCommand.Arrival")
	local beforeParts = 0
	if before then
		for _, d in ipairs(before:GetDescendants()) do
			if d:IsA("BasePart") then
				beforeParts += 1
			end
		end
	end

	local BK = ctx.requireFresh("ServerStorage.DevTools.BuildKit")
	local Common = ctx.requireFresh("ServerStorage.DevTools.Builders.Common")
	local Props = ctx.requireFresh("ServerStorage.DevTools.Props")(BK)
	local Arrival = ctx.requireFresh("ServerStorage.DevTools.Builders.CentralCommand.Arrival")

	local stats = Arrival.Build({ BK = BK, Common = Common, Props = Props, pass = "dressed" })
	local check = ctx.requireFresh("ServerStorage.DevTools.Checks.HubCheck").Run()

	return { beforeParts = beforeParts, arrival = stats, hubCheck = check }
end
