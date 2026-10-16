--!nonstrict
-- builders/checks/SaveCheck.lua  ->  ServerStorage.DevTools.Checks.SaveCheck
--
-- Unit cases for Phase 6 (docs/19 §3 "SaveLoadTest", the edit-mode half): the migrations scaffold with a test-only
-- v1 -> v2 step (docs/18 Phase 6), EffectiveConfig against the Config/Upgrades data (docs/12 §12), and the reward
-- and rank tables (docs/17 §6). Runs in edit mode; creates nothing in the place. The play-mode half (rewards once,
-- a purchase changing behavior, rejoin, /dsfail, shutdown) is driven through DevBridge and written in the journal.
--
--   local DT = game:GetService("ServerStorage").DevTools
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.SaveCheck:Clone()).Full())

local Check = {}

function Check.Full()
	local startClock = os.clock()
	local report = { passed = 0, failed = 0, failures = {}, cases = {} }
	local Shared = game:GetService("ReplicatedStorage").Shared:Clone()
	local Migrations = require(game:GetService("ServerScriptService").Server.Data.Migrations:Clone())
	local CombatConfig = require(Shared.Config.CombatConfig)
	local FrameConfig = require(Shared.Config.FrameConfig)
	local Progression = require(Shared.Config.Progression)
	local Upgrades = require(Shared.Config.Upgrades)
	local EffectiveConfig = require(Shared.Modules.EffectiveConfig)

	local function expect(condition, label)
		if not condition then
			error("expected: " .. tostring(label), 2)
		end
	end
	local function near(actual, expected, label)
		if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
			error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
		end
	end
	local function case(name, fn)
		local ok, message = xpcall(fn, function(err)
			return tostring(err)
		end)
		table.insert(report.cases, name)
		if ok then
			report.passed += 1
		else
			report.failed += 1
			table.insert(report.failures, { case = name, error = message })
		end
	end

	local function defaults(version)
		return { schemaVersion = version, story = { flags = {} }, progression = { xp = 0, credits = 0, grants = {}, upgrades = {}, tier = "A" } }
	end

	case("Migrations: v1 -> v2 (test-only step)", function()
		-- A made-up v2: progression.tier is new, story.chapterName replaces story.chapter.
		local steps = {
			[1] = function(data)
				data.story.chapterName = "CH" .. tostring(data.story.chapter)
				data.story.chapter = nil
				data.progression.tier = if data.progression.xp >= 600 then "B" else "A"
			end,
		}
		local stored = { schemaVersion = 1, story = { chapter = 1, flags = { X = true } }, progression = { xp = 700, credits = 5, grants = {}, upgrades = {} }, custom = 42 }
		expect(Migrations.run(stored, defaults(2), steps, 2) == true, "migrates")
		expect(stored.schemaVersion == 2, "schemaVersion 2")
		expect(stored.story.chapterName == "CH1" and stored.story.chapter == nil, "the step ran")
		expect(stored.progression.tier == "B", "the step's value wins over the default")
		expect(stored.story.flags.X == true and stored.custom == 42, "unknown and existing keys kept")
	end)

	case("Migrations: reconcile fills missing keys", function()
		local stored = { schemaVersion = 2, story = {}, progression = { xp = 10 } }
		expect(Migrations.run(stored, defaults(2), {}, 2), "same version is fine")
		expect(type(stored.story.flags) == "table" and stored.progression.credits == 0 and stored.progression.xp == 10, "filled, kept")
	end)

	case("Migrations: unusable data", function()
		expect(Migrations.run({ schemaVersion = 3 }, defaults(2), {}, 2) == false, "newer version refused")
		expect(Migrations.run({ schemaVersion = 1 }, defaults(2), {}, 2) == false, "missing step refused")
		expect(Migrations.run({}, defaults(2), {}, 2) == false, "no version refused")
		expect(Migrations.run({ schemaVersion = "1" }, defaults(2), {}, 2) == false, "non-number version refused")
	end)

	case("Migrations: the live scaffold", function()
		expect(Migrations.CURRENT_VERSION == 1, "schema v1 (docs/17 §2)")
		expect(next(Migrations.STEPS) == nil, "no live steps yet")
		local stored = { schemaVersion = 1 }
		expect(Migrations.run(stored, defaults(1)), "v1 loads")
	end)

	case("Upgrades: the docs/12 §12 table", function()
		local expected = {
			{ "VG_SERVO_1", "Servo Tuning I", 300, 1 }, { "VG_CAPACITOR_1", "Capacitor Bank I", 350, 1 },
			{ "VG_THRUSTER_BAFFLES", "Thruster Baffles", 400, 2 }, { "VG_PILEDRIVER_MK2", "Pile Driver Mk II", 500, 2 },
		}
		expect(#Upgrades.List == #expected, "4 upgrades")
		for index, row in ipairs(expected) do
			local upgrade = Upgrades.List[index]
			expect(upgrade.id == row[1] and upgrade.name == row[2] and upgrade.cost == row[3] and upgrade.rankRequired == row[4], row[1])
			expect(Upgrades.ById[row[1]] == upgrade, row[1] .. " by id")
			for _, modifier in ipairs(upgrade.modifiers) do
				expect(EffectiveConfig.valueAt(EffectiveConfig.BASE, modifier.path) ~= nil, modifier.path .. " is a number in the base config")
			end
		end
	end)

	case("EffectiveConfig: base and each upgrade", function()
		local base = EffectiveConfig.build({})
		expect(base == EffectiveConfig.BASE, "no upgrades = BASE (cached)")
		near(base.combat.Frames.Vanguard.Light1.recovery, CombatConfig.Frames.Vanguard.Light1.recovery, "base light recovery")
		local servo = EffectiveConfig.build({ VG_SERVO_1 = true })
		for _, name in ipairs({ "Light1", "Light2", "Light3" }) do
			near(servo.combat.Frames.Vanguard[name].recovery, CombatConfig.Frames.Vanguard[name].recovery * 0.85, name .. " recovery x0.85")
		end
		near(servo.combat.Frames.Vanguard.Heavy.recovery, CombatConfig.Frames.Vanguard.Heavy.recovery, "Heavy untouched")
		local capacitor = EffectiveConfig.build({ VG_CAPACITOR_1 = true })
		near(capacitor.frame.Vanguard.energy.regen, FrameConfig.Vanguard.energy.regen * 1.2, "regen x1.2")
		local baffles = EffectiveConfig.build({ VG_THRUSTER_BAFFLES = true })
		near(baffles.combat.Dodge.Vanguard.cooldown, CombatConfig.Dodge.Vanguard.cooldown - 0.15, "dodge cooldown -0.15")
		near(baffles.combat.Dodge.Vanguard.energy, CombatConfig.Dodge.Vanguard.energy - 5, "dodge cost -5")
		local ram = EffectiveConfig.build({ VG_PILEDRIVER_MK2 = true })
		near(ram.combat.Frames.Vanguard.Special.poise, CombatConfig.Frames.Vanguard.Special.poise * 1.3, "special poise x1.3")
		near(ram.combat.Frames.Vanguard.Special.cooldown, CombatConfig.Frames.Vanguard.Special.cooldown - 1, "special cooldown -1")
	end)

	case("EffectiveConfig: bases untouched, untouched tables shared, cache by set", function()
		local all = EffectiveConfig.build({ VG_SERVO_1 = true, VG_CAPACITOR_1 = true, VG_THRUSTER_BAFFLES = true, VG_PILEDRIVER_MK2 = true })
		near(CombatConfig.Frames.Vanguard.Light1.recovery, 0.45, "CombatConfig itself unchanged")
		near(CombatConfig.Dodge.Vanguard.cooldown, 0.8, "CombatConfig.Dodge unchanged")
		near(FrameConfig.Vanguard.energy.regen, 18, "FrameConfig itself unchanged")
		expect(all.combat.Frames.Shifter == CombatConfig.Frames.Shifter, "the Titan form's moves are shared, not copied")
		expect(all.combat.Frames.Vanguard.Heavy == CombatConfig.Frames.Vanguard.Heavy, "an untouched move is shared")
		expect(all.combat.Frames.Vanguard ~= CombatConfig.Frames.Vanguard, "a touched class is a copy")
		expect(all.combat.total == CombatConfig.total and all.combat.dodgeClip == CombatConfig.dodgeClip, "functions carried over")
		expect(EffectiveConfig.build({ VG_PILEDRIVER_MK2 = true, VG_SERVO_1 = true, VG_CAPACITOR_1 = true, VG_THRUSTER_BAFFLES = true }) == all, "same set, same result")
		expect(all.key == "VG_SERVO_1,VG_CAPACITOR_1,VG_THRUSTER_BAFFLES,VG_PILEDRIVER_MK2", "key in list order: " .. all.key)
		expect(EffectiveConfig.build({ NOT_AN_UPGRADE = true }) == EffectiveConfig.BASE, "unknown ids ignored")
		local ok = pcall(EffectiveConfig.apply, { combat = CombatConfig, frame = FrameConfig }, { { path = "Frames.Nope.x", op = "mul", value = 2 } })
		expect(not ok, "a bad path is an error")
	end)

	case("Progression: ranks and Chapter 1 rewards (docs/17 §6)", function()
		local xps = { 0, 600, 1500, 3000, 5000 }
		for index, xp in ipairs(xps) do
			expect(Progression.rankAt(xp).rank == index, "rank at " .. xp)
			if xp > 0 then
				expect(Progression.rankAt(xp - 1).rank == index - 1, "rank below " .. xp)
			end
		end
		local _, nextRank = Progression.rankAt(99999)
		expect(nextRank == nil, "no rank above Captain")
		local xp, credits = 0, 0
		for _, reward in pairs(Progression.Rewards) do
			xp += reward.xp
			credits += reward.credits
		end
		expect(xp == 1050 and credits == 450, ("Chapter 1 max 1,050 XP / 450 credits, got %d / %d"):format(xp, credits))
		expect(Progression.rankAt(xp).rank == 2, "Chapter 1 ends at Rank 2")
	end)

	Shared:Destroy()
	report.total = report.passed + report.failed
	report.ms = math.floor((os.clock() - startClock) * 1000 + 0.5)
	return report
end

return Check
