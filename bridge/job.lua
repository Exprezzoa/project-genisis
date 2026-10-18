-- job: 0005-sync-review-fixes
-- Sync every script changed since the Studio state (tools/bridge/sync_list.py), rebuild the areas the review fixes
-- touched (Arrival, Research, Exterior, Training Yard at the dressed pass; the hangar's Gameplay with the launch
-- platform's Frame walls), then run HubCheck, NavCheck and the new BudgetCheck. Stops before building if a push
-- conflicts (a script was edited by hand in Studio).
return function(ctx)
	local push = ctx.push({
	{ file = "builders/checks/BudgetCheck.lua" },
	{ file = "builders/checks/HubCheck.lua", expect = 1572554657 },
	{ file = "builders/lib/Props/Industrial.lua", expect = 1752245319 },
	{ file = "builders/lib/Props/Vehicles.lua", expect = 1491819250 },
	{ file = "builders/maps/central_command/Arrival.lua", expect = 507775611 },
	{ file = "builders/maps/central_command/Exterior.lua", expect = 436741040 },
	{ file = "builders/maps/central_command/Research.lua", expect = 2935445444 },
	{ file = "builders/maps/central_command/TrainingYard.lua", expect = 3349727375 },
	{ file = "builders/maps/hangar/Gameplay.lua", expect = 2757640032 },
	{ file = "builders/maps/outpost07/Compound.lua", expect = 559188777 },
	{ file = "builders/maps/outpost07/Wilds.lua", expect = 3875662824 },
})
	for _, r in ipairs(push) do
		if r.status ~= "updated" and r.status ~= "unchanged" and r.status ~= "created" then
			return { stopped = "push " .. r.status .. ": " .. tostring(r.file), push = push }
		end
	end

	local BK = ctx.requireFresh("ServerStorage.DevTools.BuildKit")
	local Common = ctx.requireFresh("ServerStorage.DevTools.Builders.Common")
	local Props = ctx.requireFresh("ServerStorage.DevTools.Props")(BK)
	local built = {}
	for _, area in ipairs({ "Arrival", "Research", "Exterior", "TrainingYard" }) do
		local builder = ctx.requireFresh("ServerStorage.DevTools.Builders.CentralCommand." .. area)
		local ok, stats = pcall(builder.Build, { BK = BK, Common = Common, Props = Props, pass = "dressed" })
		built[area] = if ok then stats else { error = tostring(stats) }
	end
	local gameplay = ctx.requireFresh("ServerStorage.DevTools.Builders.Hangar.Gameplay")
	local ok, stats = pcall(gameplay.Build, { BK = BK, Common = Common, pass = "dressed" })
	built.HangarGameplay = if ok then stats else { error = tostring(stats) }

	local function check(name)
		local ok2, result = pcall(function()
			return ctx.requireFresh("ServerStorage.DevTools.Checks." .. name).Run()
		end)
		return if ok2 then result else { error = tostring(result) }
	end
	return {
		push = push,
		built = built,
		hubCheck = check("HubCheck"),
		navCheck = check("NavCheck"),
		budgetCheck = check("BudgetCheck"),
	}
end
