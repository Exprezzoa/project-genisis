--!nonstrict
-- Server/Sequence/ZoneEffects.lua  (docs/05_chapter1_script.md S22; docs/maps/map_03 §6, §7, §15)
--
-- What a zone state looks like in the world. The sequence action zoneState sets the attribute on the zone's map
-- folder and calls apply; an effect that has already run doesn't run again (loads set the same state again).
--
--   apply(zoneFolder, key, value)
--
-- Outpost07 Power = true: the breaker lever comes down (90 degrees about its top pivot, 1.0 s) with two spark
-- bursts; the OutpostLight group flickers three times and stays on; the bunker's emergency lamps dim; the
-- scorched transformers and the cut cable start to spark; the comm mast's aviation lights blink at 0.8 Hz.
-- Everything it reads is tagged by the builder (builders/maps/outpost07/CompoundStructure).

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local ZoneEffects = {}

local LEVER_TIME = 1.0
local BLINK = 0.625 -- half of a 0.8 Hz blink

local function tagged(tag, zone)
	local list = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsDescendantOf(zone) then
			table.insert(list, instance)
		end
	end
	return list
end

-- Lamp faces and their lights on or off together.
local function setLamps(zone, on)
	for _, light in ipairs(tagged("OutpostLight", zone)) do
		light.Enabled = on
	end
	for _, face in ipairs(tagged("OutpostLamp", zone)) do
		face.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		face.Color = face:GetAttribute(if on then "OnColor" else "OffColor") or face.Color
	end
end

local function outpostPower(zone)
	if zone:GetAttribute("PowerShown") then
		return
	end
	zone:SetAttribute("PowerShown", true)
	for _, part in ipairs(zone:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("DownCFrame") then
			TweenService:Create(part, TweenInfo.new(LEVER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = part:GetAttribute("DownCFrame") }):Play()
		end
	end
	task.spawn(function()
		task.wait(LEVER_TIME)
		for _, emitter in ipairs(tagged("BreakerSpark", zone)) do
			emitter:Emit(emitter:GetAttribute("EmitCount") or 25)
		end
		-- Three flickers, then on.
		for _ = 1, 3 do
			setLamps(zone, true)
			task.wait(0.06 + math.random() * 0.08)
			setLamps(zone, false)
			task.wait(0.1 + math.random() * 0.18)
		end
		setLamps(zone, true)
		for _, light in ipairs(tagged("EmergencyLight", zone)) do
			light.Brightness = light:GetAttribute("PoweredBrightness") or light.Brightness
		end
		for _, emitter in ipairs(tagged("PowerSpark", zone)) do
			emitter.Enabled = true
		end
		local beacons = tagged("AviationLight", zone)
		local lit = false
		while zone.Parent and zone:GetAttribute("Power") do
			lit = not lit
			for _, beacon in ipairs(beacons) do
				beacon.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
				beacon.Color = beacon:GetAttribute(if lit then "OnColor" else "OffColor") or beacon.Color
				local light = beacon:FindFirstChildWhichIsA("Light")
				if light then
					light.Enabled = lit
				end
			end
			task.wait(BLINK)
		end
	end)
end

function ZoneEffects.apply(zone, key, value)
	if zone and zone.Name == "Outpost07" and key == "Power" and value == true then
		outpostPower(zone)
	end
end

return ZoneEffects
