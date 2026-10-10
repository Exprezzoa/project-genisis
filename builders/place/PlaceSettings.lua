--!nonstrict
-- builders/place/PlaceSettings.lua  ->  ServerStorage.DevTools.Builders.Place.PlaceSettings
--
-- The place-level properties the docs ask for, applied in edit mode (idempotent). Returns what it changed.
--   Workspace     docs/18 Phase 0 (StreamingEnabled false, Gravity 196.2, FallenPartsDestroyHeight -500)
--   StarterPlayer docs/08 §1.1
--   Players       CharacterAutoLoads false: CharacterService spawns the character after the profile loads
--   Lighting      D-018: LightingStyle Realistic, PrioritizeLightingQuality true (the presets do the rest)

local Settings = {}

local WANTED = {
	{ "Workspace", "StreamingEnabled", false },
	{ "Workspace", "Gravity", 196.2 },
	{ "Workspace", "FallenPartsDestroyHeight", -500 },
	{ "StarterPlayer", "CharacterWalkSpeed", 14 },
	{ "StarterPlayer", "CharacterUseJumpPower", false },
	{ "StarterPlayer", "CharacterJumpHeight", 7.2 },
	{ "StarterPlayer", "CameraMaxZoomDistance", 22 },
	{ "StarterPlayer", "CameraMinZoomDistance", 6 },
	{ "StarterPlayer", "DevCameraOcclusionMode", Enum.DevCameraOcclusionMode.Zoom },
	{ "StarterPlayer", "AutoJumpEnabled", true },
	{ "StarterPlayer", "EnableMouseLockOption", false },
	{ "Players", "CharacterAutoLoads", false },
	{ "Lighting", "LightingStyle", Enum.LightingStyle.Realistic },
	{ "Lighting", "PrioritizeLightingQuality", true },
	{ "Lighting", "GlobalShadows", true },
}

function Settings.Apply()
	local changed, failed = {}, {}
	for _, entry in ipairs(WANTED) do
		local service = game:GetService(entry[1])
		local property, value = entry[2], entry[3]
		local current = service[property]
		local same = current == value or (type(value) == "number" and math.abs(current - value) < 1e-4)
		if not same then
			local ok, message = pcall(function()
				service[property] = value
			end)
			local line = ("%s.%s: %s -> %s"):format(entry[1], property, tostring(current), tostring(value))
			if ok then
				table.insert(changed, line)
			else
				table.insert(failed, line .. " (" .. tostring(message) .. ")")
			end
		end
	end
	return { checked = #WANTED, changed = changed, failed = failed }
end

return Settings
