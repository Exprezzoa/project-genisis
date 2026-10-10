--!strict
-- builders/lib/Palette.lua  ->  ServerStorage.DevTools.Palette
--
-- The master palette from docs/06_art_direction.md section 3, as Color3 constants.
-- Keys and hex values are copied exactly from the doc. "Use only these."
-- To change a color: change the doc first, then this file, then rebuild.
--
-- Dev-time only: game code must never require anything under ServerStorage.DevTools.

local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local Palette = {
	-- Architecture ---------------------------------------------------------
	CONCRETE_LIGHT = c("#8A8F94"), -- exterior walls, upper
	CONCRETE_MID = c("#6E7378"), -- exterior walls, main
	CONCRETE_DARK = c("#4F5459"), -- plinths, bases, kickplates (exterior)
	WALL_INTERIOR = c("#A7ADB2"), -- interior walls
	WALL_INTERIOR_LOW = c("#7C838A"), -- interior wainscot (lower 3 studs)
	FLOOR_INTERIOR = c("#50565C"), -- polished interior floors
	FLOOR_HANGAR = c("#3A3D42"), -- hangar and industrial floors
	KICKPLATE = c("#2E3236"), -- dark base strips
	STEEL_DARK = c("#2A2D31"), -- structural steel, frames, machine internals
	STEEL_MID = c("#4A4F55"), -- catwalks, decks, panels
	STEEL_LIGHT = c("#9AA1A6"), -- pistons, rails, bright metal
	SLATE = c("#4A5A6A"), -- division trim, banners
	SLATE_DEEP = c("#3B4A5A"), -- officer coats, banners
	HAZARD_YELLOW = c("#E8B923"), -- safety lines, stripes
	HAZARD_BLACK = c("#1B1D20"), -- stripe pairs
	GLASS = c("#9FB4C4"), -- windows (Glass material, Transparency 0.55)
	MEDICAL_WHITE = c("#E6E8EA"), -- medical surfaces, lab coats
	RUST = c("#8A4B2A"), -- outpost metal
	RUST_DARK = c("#5E3520"), -- deep rust, stains
	WOOD_OLD = c("#6A5440"), -- crates, pallets
	FABRIC_DARK = c("#33383F"), -- seats, mattresses

	-- Light and signal -----------------------------------------------------
	AMBER = c("#E8A33D"), -- Directorate color, UI accent, signage
	AMBER_CORE = c("#FFB347"), -- normal Frame core glow
	AMBER_LAMP = c("#FFD38A"), -- warm lamps
	LIGHT_NEUTRAL = c("#FFF1DA"), -- ceiling and high-bay lights
	LIGHT_COOL = c("#DDE9F2"), -- medical, labs, floodlights
	WARNING_ORANGE = c("#E07A1F"), -- beacons, Elias's accent stripe
	DANGER_RED = c("#E5484D"), -- alarms, UI danger
	EMERGENCY_RED = c("#B3262B"), -- emergency lights
	SUCCESS_GREEN = c("#46C17A"), -- UI success only
	TITAN_GLOW = c("#FF7A2E"), -- feral Titan eyes and core
	TITAN_GLOW_DEEP = c("#E25B2D"), -- feral veins, crest
	LATTICE_CYAN = c("#7FE3F0"), -- RESERVED: resonance / Shifters only. Use cyan nowhere else.

	-- Nature (outpost, wilderness) -----------------------------------------
	GROUND = c("#6B6252"), -- dirt ground (Ground material)
	MUD_DRY = c("#8C7B66"), -- basin floor (Mud material)
	MUD_CRACK = c("#5A4E40"), -- crack lines
	ROCK = c("#6B6660"), -- rocks (Rock material)
	ROCK_DARK = c("#4E4A45"), -- rock shadows, cliff bases (Basalt)
	ASH = c("#9C9893"), -- ash drifts, Titan death
	ASH_DARK = c("#6F6B66"), -- old ash fields
	GRASS_DEAD = c("#6F6A4A"), -- dry grass tufts (LeafyGrass material)
	GRASS_SPARSE = c("#556B3A"), -- rare living patches
	TREE_DEAD = c("#4A3F35"), -- dead trees (Wood material)
	ASPHALT = c("#3E4044"), -- roads (Asphalt material)
	ROAD_LINE = c("#C9B98A"), -- faded road paint

	-- Frames ---------------------------------------------------------------
	VG_ARMOR = c("#5B6770"), -- Vanguard armor plates (Metal)
	VG_ARMOR_DARK = c("#46515A"), -- secondary plates
	VG_FRAME = c("#2A2D31"), -- internals, joints (Metal / DiamondPlate)
	VG_HYDRAULIC = c("#9AA1A6"), -- pistons
	VG_ACCENT_ELIAS = c("#E07A1F"), -- Unit 02 stripes
	VG_ACCENT_MARA = c("#C8483C"), -- Unit 01 stripes
	VG_PRIMER = c("#8A9096"), -- Unit 03 unpainted plates
	VG_VISOR = c("#FFB347"), -- sensor visor (Neon, 0.2 transparency)

	-- Titans ---------------------------------------------------------------
	STR_SKIN = c("#8C8378"), -- Strider skin (SmoothPlastic)
	STR_SKIN_SHADE = c("#756D63"), -- under-surfaces, ribs
	STR_SINEW = c("#5E554C"), -- sinew strips
	STR_MUSCLE = c("#7A3B33"), -- exposed forearm and calf muscle
	STR_BONE = c("#CFC6B4"), -- bone plates (Limestone)
	STR_TEETH = c("#E8E2C8"), -- teeth
	STR_SOCKET = c("#1B1714"), -- eye sockets, mouth interior
	WAT_SKIN = c("#3B3A3F"), -- Watcher skin
	WAT_BONE = c("#9A9AA3"), -- Watcher plates
	WAT_GLOW = c("#7FE3F0"), -- Watcher veins and eyes (Lattice cyan)

	-- Hexes that docs/06 uses without giving them a key (key names chosen here; see decisions.md D-010)
	SIGN_WHITE = c("#E8ECEF"), -- white sign text on SLATE (06 section 7)
	DUST_HANGAR = c("#5A5E63"), -- Frame-step dust puff inside the hangar (06 section 6)
}

return table.freeze(Palette)
