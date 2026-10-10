--!strict
-- Shared/Config/LightingPresets.lua  (docs/06_art_direction.md §5)
--
-- The five lighting presets, applied by the client LightingController (tween 1.5 s, instant during a fade).
-- Each preset lists the properties of Lighting and of its Atmosphere, ColorCorrection, Bloom and SunRays.
-- Zones name a preset, or "HUB" for the current story preset (docs/maps/map_00 §2).

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local LightingPresets = {}

LightingPresets.TWEEN_TIME = 1.5
LightingPresets.DEFAULT_HUB = "MORNING"

-- Same for every preset. LightingStyle = Realistic and PrioritizeLightingQuality = true (D-018) are NOT here:
-- game scripts can't write them (plugin capability only), so they are place settings applied in edit mode
-- by builders/place/PlaceSettings.lua.
LightingPresets.BASE = {
	GlobalShadows = true,
}

-- Enabled only in cinematics (FocusDistance = distance to the shot target).
LightingPresets.DEPTH_OF_FIELD = { FarIntensity = 0.25, NearIntensity = 0, InFocusRadius = 30 }

local function preset(clock, brightness, ambient, outdoor, shiftTop, diffuse, specular, exposure, softness, atmosphere, color, bloom, sunRays)
	return {
		Lighting = {
			ClockTime = clock,
			GeographicLatitude = 41,
			Brightness = brightness,
			Ambient = hex(ambient),
			OutdoorAmbient = hex(outdoor),
			ColorShift_Top = hex(shiftTop),
			EnvironmentDiffuseScale = diffuse,
			EnvironmentSpecularScale = specular,
			ExposureCompensation = exposure,
			ShadowSoftness = softness,
		},
		Atmosphere = {
			Density = atmosphere[1],
			Offset = atmosphere[2],
			Color = hex(atmosphere[3]),
			Decay = hex(atmosphere[4]),
			Glare = atmosphere[5],
			Haze = atmosphere[6],
		},
		ColorCorrection = { Brightness = color[1], Contrast = color[2], Saturation = color[3], TintColor = hex(color[4]) },
		Bloom = { Intensity = bloom[1], Size = bloom[2], Threshold = bloom[3] },
		SunRays = { Intensity = sunRays[1], Spread = sunRays[2] },
	}
end

LightingPresets.presets = {
	MORNING = preset(7.2, 2.2, "#3A3F47", "#7A8088", "#FFE2C0", 0.6, 0.6, 0.1, 0.25,
		{ 0.32, 0.15, "#C9C2B6", "#8C8478", 0.4, 1.6 }, { 0.02, 0.08, -0.12, "#FFF6EC" }, { 0.6, 24, 1.6 }, { 0.06, 0.6 }),
	OVERCAST = preset(15.2, 1.4, "#40444A", "#808489", "#D9DDE2", 0.5, 0.4, 0, 0.5,
		{ 0.42, 0.05, "#BFC3C8", "#8E8778", 0, 2.2 }, { 0, 0.10, -0.28, "#E9ECEF" }, { 0.4, 24, 1.8 }, { 0, 0 }),
	EVENING = preset(18.9, 1.2, "#3A3340", "#6B5E66", "#FF9E5E", 0.5, 0.6, 0.1, 0.3,
		{ 0.36, 0.10, "#D79A72", "#5E4A5A", 0.6, 1.8 }, { 0.02, 0.12, -0.05, "#FFE7D6" }, { 0.8, 28, 1.4 }, { 0.10, 0.7 }),
	NIGHT = preset(22.5, 0.6, "#262B36", "#2E3442", "#9FB4FF", 0.4, 0.5, 0.2, 0.2,
		{ 0.38, 0.0, "#2A3140", "#121620", 0, 1.2 }, { 0, 0.14, -0.15, "#D8E2FF" }, { 1.0, 30, 1.2 }, { 0, 0 }),
	MEMORY = preset(12, 3, "#DFF8FB", "#FFFFFF", "#FFFFFF", 1, 0, 0.4, 1,
		{ 0.6, 0.3, "#E8FBFF", "#CFEFF5", 0, 3 }, { 0.1, -0.1, -0.6, "#E0FAFF" }, { 1.4, 40, 0.9 }, { 0, 0 }),
}

return LightingPresets
