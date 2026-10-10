--!strict
-- Shared/Dialogue/Speakers.lua  (docs/13_missions_dialogue_relationships.md §2.1)
--
-- Speaker codes: display name and name color. radio: "piloting" (on comms while piloting), "missions",
-- "always", "lofi" (public address) or false.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

return {
	E = { name = "ELIAS", color = hex("#E8ECEF"), radio = "piloting" },
	M = { name = "MARA", color = hex("#E58A7E"), radio = "piloting" },
	V = { name = "CMDR. VALE", color = hex("#8FB3D9"), radio = "missions" },
	VS = { name = "DR. VOSS", color = hex("#B9D98F"), radio = false },
	R = { name = "CMDR. RHEIN", color = hex("#AEB6BF"), radio = false },
	H = { name = "CHIEF BRANDT", color = hex("#E8B923"), radio = false },
	O = { name = "OVERWATCH", color = hex("#E8A33D"), radio = "always" },
	T = { name = "ROOK", color = hex("#8FD9A0"), radio = false },
	PA = { name = "PUBLIC ADDRESS", color = hex("#9AA6B2"), radio = "lofi" },
	OFFICER = { name = "OFFICER", color = hex("#9AA6B2"), radio = false },
	VOICE = { name = "", color = hex("#7FE3F0"), radio = false, italic = true },
}
