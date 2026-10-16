--!strict
-- Server/Data/Migrations.lua  (docs/17_saving_progression_monetization.md §3.2)
--
-- Brings a stored profile up to the current schema: STEPS[fromVersion](data) upgrades it by one version, then the
-- defaults fill whatever is missing (deep reconcile; unknown keys are never deleted). Pure, so the unit test
-- (builders/checks/SaveCheck) can run it with its own steps.
--
--   run(data, defaults, steps?, current?) -> boolean   false = unusable (no or newer version, a missing step)

local TableUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Modules.TableUtil)

local Migrations = {}

Migrations.CURRENT_VERSION = 1

-- None yet: schema v1 (docs/17 §2).
Migrations.STEPS = {} :: { [number]: (data: any) -> () }

function Migrations.run(data: any, defaults: any, steps: { [number]: (data: any) -> () }?, current: number?): boolean
	local list = steps or Migrations.STEPS
	local target = current or Migrations.CURRENT_VERSION
	local version = data.schemaVersion
	if type(version) ~= "number" or version > target then
		return false
	end
	while version < target do
		local step = list[version]
		if not step then
			return false
		end
		step(data)
		version += 1
		data.schemaVersion = version
	end
	TableUtil.reconcile(data, defaults)
	return true
end

return Migrations
