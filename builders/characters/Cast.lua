--!nonstrict
-- builders/characters/Cast.lua  ->  ServerStorage.DevTools.Builders.Characters.Cast
-- docs/03_characters.md: Chapter 1's cast as CharacterKit specs, built into ServerStorage.Templates.NPCs.<Name>.
-- Named characters follow their build rows exactly; the ambient officers, technicians and guards rotate the
-- skin-tone list and a few hair colors so crowds look varied (docs/03 "Skin tone list"). Only Elias wears the
-- pilot mask (D-055); every other face is the default decal (docs/03 "Default proportions").
--
--   Builder.Build({ BK = BK, Kit = CharacterKit, Wardrobe = Wardrobe, only = { "Mara" }? })

local Builder = {}

local SUIT, GLOVE, BOOT, AMBER = "#2B2F36", "#2A2D31", "#1E2125", "#E8A33D"
local OFFICER_TORSO, OFFICER_LEGS = "#3B4A5A", "#2B3440"
local COVERALL = "#5E6B48"
local SKINS = { "#F0C8A8", "#E1B899", "#D3A685", "#C69C7A", "#B7835F", "#9E6B4A", "#8D5A3B", "#5C3A26", "#3F2A1E" }
local HAIRS = { "#15110F", "#3A2A1E", "#5B4A3A", "#1C1A19", "#7A6A55", "#8F8A84" }

local function specs(Kit, W)
	local list = {
		Mara = {
			height = 0.98,
			colors = { skin = "#8D5A3B", torso = SUIT, arms = SUIT, legs = SUIT, hands = "#8D5A3B", feet = BOOT },
			gear = Kit.join(Kit.pilotSuit("#C8483C"), W.ponytail("#15110F", "#C8483C"), Kit.rankBars(1), Kit.divisionPatch(), Kit.chestTag("EMBER-1"), W.wristBands(GLOVE)),
		},
		Tamsin = {
			colors = { skin = "#F0C8A8", torso = SUIT, arms = SUIT, legs = SUIT, hands = GLOVE, feet = BOOT },
			gear = Kit.join(Kit.pilotSuit("#5FAF6A"), W.bob("#A8432A"), Kit.rankBars(1), Kit.divisionPatch()),
		},
		Vale = {
			height = 1.06, width = 1.05,
			colors = { skin = "#B7835F", torso = OFFICER_TORSO, arms = OFFICER_TORSO, legs = OFFICER_LEGS, hands = "#B7835F", feet = BOOT },
			gear = Kit.join(W.officerUniform(AMBER, OFFICER_TORSO), W.chevron(AMBER), Kit.divisionPatch(), W.sidepart("#8F8A84"), W.datapad()),
		},
		Rhein = {
			height = 1.04,
			colors = { skin = "#D3A685", torso = "#24282E", arms = "#24282E", legs = "#1E2125", hands = BOOT, feet = BOOT },
			gear = Kit.join(W.officerUniform("#AEB6BF", "#24282E"), W.chevron("#AEB6BF"), W.slicked("#1C1A19"), W.echoPin()),
		},
		Voss = {
			height = 0.97,
			colors = { skin = "#E1B899", torso = "#6C7A89", arms = "#6C7A89", legs = "#3B3F45", hands = "#E1B899", feet = BOOT },
			gear = Kit.join(W.labCoat(), W.lowBun("#7A3E22"), W.glasses(), W.badge()),
		},
		Hollis = {
			width = 1.15,
			colors = { skin = "#C79A7E", torso = COVERALL, arms = COVERALL, legs = COVERALL, hands = GLOVE, feet = BOOT },
			gear = Kit.join(W.technicianCoverall(), W.greyBeard("#9B958C"), W.goggles()),
		},
		Okafor = {
			colors = { skin = "#5C3A26", torso = COVERALL, arms = COVERALL, legs = COVERALL, hands = "#5C3A26", feet = BOOT },
			gear = Kit.join(W.technicianCoverall(), W.crop("#15110F"), W.headset()),
		},
		Morrow = {
			colors = { skin = "#9E6B4A", torso = COVERALL, arms = COVERALL, legs = COVERALL, hands = GLOVE, feet = BOOT },
			gear = Kit.join(W.technicianCoverall(), W.armoredVest("#4A5538"), W.crop("#1C1A19")),
		},
		Pell = {
			colors = { skin = "#C69C7A", torso = COVERALL, arms = COVERALL, legs = COVERALL, hands = GLOVE, feet = BOOT },
			gear = Kit.join(W.technicianCoverall(), W.weldingMask()),
		},
	}
	for index = 1, 6 do
		local skin = SKINS[(index * 2) % #SKINS + 1]
		list["Officer" .. index] = {
			height = 0.96 + (index % 3) * 0.03,
			colors = { skin = skin, torso = OFFICER_TORSO, arms = OFFICER_TORSO, legs = OFFICER_LEGS, hands = skin, feet = BOOT },
			gear = Kit.join(W.officerUniform(AMBER, OFFICER_TORSO), Kit.rankBars(1 + index % 2), Kit.divisionPatch(), W.crop(HAIRS[index % #HAIRS + 1])),
		}
		local techSkin = SKINS[(index * 3 + 1) % #SKINS + 1]
		list["Technician" .. index] = {
			height = 0.95 + (index % 4) * 0.025,
			colors = { skin = techSkin, torso = COVERALL, arms = COVERALL, legs = COVERALL, hands = GLOVE, feet = BOOT },
			gear = Kit.join(W.technicianCoverall(), W.crop(HAIRS[(index + 2) % #HAIRS + 1])),
		}
	end
	for index = 1, 3 do
		local skin = SKINS[(index * 4) % #SKINS + 1]
		list["Guard" .. index] = {
			height = 1.02,
			colors = { skin = skin, torso = "#24282E", arms = "#24282E", legs = "#24282E", hands = BOOT, feet = BOOT },
			gear = W.guardKit("#2E3238"),
		}
	end
	return list
end

function Builder.Build(opts)
	local BK, Kit, W = opts.BK, opts.Kit, opts.Wardrobe
	local startClock = os.clock()
	local templates = game:GetService("ServerStorage"):WaitForChild("Templates")
	local folder = BK.folder(templates, "NPCs")
	local built = {}
	for name, spec in pairs(specs(Kit, W)) do
		if not opts.only or table.find(opts.only, name) then
			spec.name = name
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local model = Kit.build(BK, spec)
			model:SetAttribute("NPC", name)
			model.Parent = folder
			table.insert(built, name)
			BK.breathe()
		end
	end
	table.sort(built)
	local report = BK.report(folder, startClock)
	report.built = built
	return report
end

return Builder
