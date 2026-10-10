--!strict
-- Client/Controllers/LightingController.lua  (docs/06_art_direction.md §5)
--
-- Applies the lighting presets of Config/LightingPresets: tweened over 1.5 s, or instantly.
-- The preset follows the player's zone (attribute "Zone", set by ZoneService): a zone names a preset, or
-- "HUB" for the current story preset, which the server changes with Lighting_Set {preset, instant}.
--
--   LightingController.apply(presetName, instant)   LightingController.getCurrent() -> presetName

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LightingPresets = require(Shared.Config.LightingPresets)
local Zones = require(Shared.Config.Zones)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local TAG = "LightingController"
local EFFECTS = {
	Atmosphere = "Atmosphere",
	ColorCorrection = "ColorCorrectionEffect",
	Bloom = "BloomEffect",
	SunRays = "SunRaysEffect",
}

local LightingController = {}

local player = Players.LocalPlayer
local targets: { [string]: Instance } = {}
local tweens: { Tween } = {}
local hubPreset = LightingPresets.DEFAULT_HUB
local current: string? = nil

local function ensure(className: string): Instance
	local instance = Lighting:FindFirstChildOfClass(className)
	if not instance then
		instance = Instance.new(className)
		instance.Parent = Lighting
	end
	return instance :: Instance
end

function LightingController.getCurrent(): string?
	return current
end

function LightingController.apply(name: string, instant: boolean?)
	local preset = (LightingPresets.presets :: any)[name]
	if not preset then
		Log.error(TAG, "unknown lighting preset %s", tostring(name))
		return
	end
	for _, tween in ipairs(tweens) do
		tween:Cancel()
	end
	table.clear(tweens)
	current = name
	for group, properties in pairs(preset) do
		local target = targets[group]
		if instant then
			for property, value in pairs(properties) do
				(target :: any)[property] = value
			end
		else
			local tween = TweenService:Create(target, TweenInfo.new(LightingPresets.TWEEN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), properties)
			table.insert(tweens, tween)
			tween:Play()
		end
	end
end

-- The preset the player's zone asks for.
local function wanted(): string
	local zoneId = player:GetAttribute("Zone")
	for _, zone in ipairs(Zones) do
		if zone.id == zoneId then
			return if zone.lighting == "HUB" then hubPreset else zone.lighting
		end
	end
	return hubPreset
end

local function refresh(instant: boolean?)
	local name = wanted()
	if name ~= current then
		LightingController.apply(name, instant)
	end
end

function LightingController.Init()
	targets.Lighting = Lighting
	for group, className in pairs(EFFECTS) do
		targets[group] = ensure(className)
	end
	for property, value in pairs(LightingPresets.BASE) do
		(Lighting :: any)[property] = value
	end
	local depthOfField = ensure("DepthOfFieldEffect") :: DepthOfFieldEffect
	depthOfField.Enabled = false -- cinematics only
	LightingController.apply(wanted(), true)
end

function LightingController.Start()
	Net.on("Lighting_Set", function(payload: { preset: string, instant: boolean? })
		if (LightingPresets.presets :: any)[payload.preset] == nil then
			Log.error(TAG, "Lighting_Set with unknown preset %s", tostring(payload.preset))
			return
		end
		hubPreset = payload.preset
		refresh(payload.instant)
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		refresh(false)
	end)
end

return LightingController
