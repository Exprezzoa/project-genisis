-- job: 0001-baseline
-- First contact (Genesis Bridge, D-102): what this place holds and how its scripts compare with the repo.
-- Changes nothing.
return function(ctx)
	local files = ctx.files("^src/.*%.lua$")
	for _, f in ipairs(ctx.files("^builders/.*%.lua$")) do
		table.insert(files, f)
	end
	local tree = {}
	for _, name in ipairs({ "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPlayer", "Lighting" }) do
		tree[name] = ctx.dump(game:GetService(name), 2)
	end
	print("Genesis Bridge baseline: " .. #files .. " repo scripts checked")
	return {
		place = game.Name,
		placeId = game.PlaceId,
		gameId = game.GameId,
		sums = ctx.studioSums(files),
		tree = tree,
	}
end
