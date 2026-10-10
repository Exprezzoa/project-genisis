--!nonstrict
-- builders/lib/BuildKit/init.lua  ->  ServerStorage.DevTools.BuildKit (ModuleScript with child modules)
--
-- Build-as-code primitives and helpers. API: docs/07_building_with_parts.md section 3.
-- Dev-time only: game code must never require anything under ServerStorage.DevTools.
--
-- Always clone before require, so an edited module is never served from require's cache:
--   local DT = game:GetService("ServerStorage").DevTools
--   local BK = require(DT.BuildKit:Clone())
--   local P = BK.Palette
--
-- Child modules (each returns function(BK) and adds its functions to BK):
--   Core       coercion, props applier, primitives, containers, utilities
--   Structure  box, floor, ceiling, walls, wallWithOpenings, stairs, railing, column, window, door
--   Detail     seams, trimBand, kickplate, hazardStripe, pipeRun, cable, bolts
--   Fx         light, sign, screen, floorText, emitter
--   Gameplay   trigger, prompt, spawnPoint, camPoint, navNode, dismountPad, barrier

local ServerStorage = game:GetService("ServerStorage")

local BK = {}

BK.VERSION = "0.1.0"

local function loadPalette()
	local devTools = ServerStorage:FindFirstChild("DevTools")
	local module = devTools and devTools:FindFirstChild("Palette")
	if not module then
		error("[BuildKit] ServerStorage.DevTools.Palette is missing. Push builders/lib/Palette.lua first.")
	end
	return require(module:Clone())
end

-- The palette every builder should use (docs/06_art_direction.md section 3).
BK.Palette = loadPalette()

for _, name in ipairs({ "Core", "Structure", "Detail", "Fx", "Gameplay" }) do
	local child = script:FindFirstChild(name)
	if not child then
		error("[BuildKit] child module '" .. name .. "' is missing")
	end
	local install = require(child)
	install(BK)
end

return BK
