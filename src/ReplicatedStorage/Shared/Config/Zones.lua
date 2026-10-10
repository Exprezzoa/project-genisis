--!strict
-- Shared/Config/Zones.lua  (docs/maps/map_00_world_layout.md §2)
--
-- Axis-aligned zone boxes for ZoneService. When boxes overlap, the FIRST match in this list wins
-- (interiors before exteriors), so the order is part of the data.
--   lighting: "HUB" = the current story preset (MORNING / EVENING / NIGHT), otherwise a preset name.
--   reverb:   an Enum.ReverbType name.
--   weapons:  "None" (on foot only, n/a), "Locked" or "Free".

export type Zone = {
	id: string,
	min: Vector3,
	max: Vector3,
	lighting: string,
	reverb: string,
	weapons: "None" | "Locked" | "Free",
}

local function zone(id: string, min: Vector3, max: Vector3, lighting: string, reverb: string, weapons: any): Zone
	return { id = id, min = min, max = max, lighting = lighting, reverb = reverb, weapons = weapons }
end

local V = Vector3.new

local Zones: { Zone } = {
	zone("Quarters", V(-131, -1, -1), V(-79, 13, 41), "HUB", "Room", "None"),
	zone("Briefing", V(-131, -1, -41), V(-79, 17, 1), "HUB", "Room", "None"),
	zone("Medical", V(79, -1, -1), V(131, 19, 41), "HUB", "Room", "None"),
	zone("Equipment", V(79, -1, -41), V(131, 19, 1), "HUB", "Room", "None"),
	zone("Research", V(79, -1, -61), V(251, 13, -19), "HUB", "Hallway", "None"),
	zone("OpsHall", V(-61, -1, -41), V(61, 37, 41), "HUB", "Hallway", "None"),
	zone("Corridors", V(-81, -1, -71), V(81, 21, 61), "HUB", "Hallway", "None"),
	zone("Arrival", V(-100, -1, 39), V(100, 25, 150), "HUB", "City", "None"),
	zone("ObservationDeck", V(59, 19, -41), V(141, 40, 61), "HUB", "City", "None"),
	zone("Hangar", V(-121, -1, -231), V(121, 91, -69), "HUB", "Hangar", "Locked"),
	zone("LaunchArea", V(121, -1, -200), V(460, 130, -100), "HUB", "City", "Locked"),
	zone("TrainingYard", V(-420, -1, -300), V(-121, 120, -40), "HUB", "City", "Free"),
	zone("HubExterior", V(-1400, -50, -1000), V(2000, 400, 1400), "HUB", "City", "Locked"),
	zone("Bunker", V(5958, -1, -62), V(6042, 15, 2), "OVERCAST", "StoneRoom", "None"),
	zone("Basin", V(5780, -40, -760), V(6360, 120, -400), "OVERCAST", "Quarry", "Free"),
	zone("Trail", V(5900, -20, -400), V(6100, 80, -160), "OVERCAST", "Plain", "Free"),
	zone("Outpost", V(5500, -50, -170), V(6500, 300, 650), "OVERCAST", "Plain", "Free"),
	zone("Memory", V(-250, 1950, -250), V(250, 2200, 250), "MEMORY", "Arena", "Locked"),
}

return Zones
