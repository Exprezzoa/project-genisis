--!nonstrict
-- builders/characters/Elias.lua  ->  ServerStorage.DevTools.Builders.Characters.Elias
-- docs/03_characters.md "Elias Veyne": the player character. Build() installs it as
-- StarterPlayer.StarterCharacter (replacing the previous one).

local Builder = {}

local V = Vector3.new
local HAIR = "#3A2A1E"
local SUIT = "#2B2F36"

function Builder.spec(Kit)
	return {
		name = "Elias",
		height = 1.02,
		colors = { skin = "#C69C7A", torso = SUIT, arms = SUIT, legs = SUIT, hands = "#2A2D31", feet = "#1E2125" },
		-- "Short messy crop" (docs/03), the pilot suit with Unit 02's orange, the mask, one rank bar, patch, squad tag.
		gear = Kit.join(Kit.pilotSuit("#E07A1F"), Kit.shortHair(HAIR), Kit.pilotMask(), Kit.rankBars(1), Kit.divisionPatch(), Kit.chestTag("EMBER-2")),
	}
end

function Builder.Build(opts)
	local BK, Kit = opts.BK, opts.Kit
	local startClock = os.clock()
	local StarterPlayer = game:GetService("StarterPlayer")
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	local model = Kit.build(BK, Builder.spec(Kit))
	model.Name = "StarterCharacter"
	model.Parent = StarterPlayer
	return BK.report(model, startClock)
end

return Builder
