--!nonstrict
-- builders/characters/Elias.lua  ->  ServerStorage.DevTools.Builders.Characters.Elias
-- docs/03_characters.md "Elias Veyne": the player character. Build() installs it as
-- StarterPlayer.StarterCharacter (replacing the previous one).

local Builder = {}

local V = Vector3.new
local HAIR = "#3A2A1E"
local SUIT = "#2B2F36"

local function hair(name, size, at)
	return { on = "Head", name = name, size = size, at = at, color = HAIR }
end

function Builder.spec(Kit)
	return {
		name = "Elias",
		height = 1.02,
		colors = { skin = "#C69C7A", torso = SUIT, arms = SUIT, legs = SUIT, hands = "#2A2D31", feet = "#1E2125" },
		gear = Kit.join(Kit.pilotHarness(), Kit.piping("#E07A1F"), Kit.rankBars(1), Kit.divisionPatch(), Kit.chestTag("EMBER-2"), {
			-- "Short messy crop": cap, three tufts on the top-front, two sides, back.
			hair("Hair_Cap", V(1.25, 0.35, 1.25), CFrame.new(0, 0.62, 0)),
			hair("Hair_Tuft1", V(0.4, 0.3, 0.5), CFrame.new(-0.35, 0.8, -0.3) * CFrame.Angles(math.rad(15), 0, math.rad(10))),
			hair("Hair_Tuft2", V(0.4, 0.3, 0.5), CFrame.new(0.05, 0.84, -0.38) * CFrame.Angles(math.rad(20), 0, math.rad(-5))),
			hair("Hair_Tuft3", V(0.4, 0.3, 0.5), CFrame.new(0.4, 0.8, -0.25) * CFrame.Angles(math.rad(10), 0, math.rad(-15))),
			hair("Hair_SideL", V(0.15, 0.5, 1.0), CFrame.new(-0.62, 0.25, 0.1)),
			hair("Hair_SideR", V(0.15, 0.5, 1.0), CFrame.new(0.62, 0.25, 0.1)),
			hair("Hair_Back", V(1.2, 0.6, 0.15), CFrame.new(0, 0.2, 0.62)),
		}),
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
