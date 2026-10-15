--!strict
-- Shared/Config/Progression.lua  (docs/17_saving_progression_monetization.md §6; docs/05 §10)
--
-- Ranks and reward values. ProgressionService (Phase 6) grants them; until then the Mission Complete card shows
-- what the chapter earned from these numbers (D-090).

export type Rank = { rank: number, name: string, xp: number }

local ranks: { Rank } = {
	{ rank = 1, name = "Pilot Officer", xp = 0 },
	{ rank = 2, name = "Pilot Officer II", xp = 600 },
	{ rank = 3, name = "Lieutenant", xp = 1500 },
	{ rank = 4, name = "Senior Lieutenant", xp = 3000 },
	{ rank = 5, name = "Captain", xp = 5000 },
}

return {
	Ranks = ranks,
	Rewards = {
		CH1_M01_COMPLETE = { xp = 500, credits = 300 },
		CH1_STRIDER_DEFEATED = { xp = 300, credits = 100 },
		EV_OP07_LOG1 = { xp = 50, credits = 0 },
		EV_OP07_LOG2 = { xp = 50, credits = 0 },
		EV_OP07_LOG3 = { xp = 50, credits = 0 },
		CH1_CLEAN_KILL = { xp = 100, credits = 50 },
	},
	-- The rank held at an XP total, and the next one (nil at the top).
	rankAt = function(xp: number): (Rank, Rank?)
		local held, nextRank = ranks[1], nil
		for index, rank in ipairs(ranks) do
			if xp >= rank.xp then
				held, nextRank = rank, ranks[index + 1]
			end
		end
		return held, nextRank
	end,
}
