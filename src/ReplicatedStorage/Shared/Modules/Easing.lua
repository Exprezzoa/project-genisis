--!strict
-- Shared/Modules/Easing.lua
--
-- The ease names used by pose clips, cinematic shots and UI motion (docs/08_rigs_and_animation.md §4.2).
-- Every function maps t in [0, 1] to an eased value with f(0) = 0 and f(1) = 1. Pure math, no services.

export type EaseFn = (t: number) -> number

local BACK_OVERSHOOT = 1.70158

local Easing = {}

local functions: { [string]: EaseFn } = {
	Linear = function(t)
		return t
	end,
	SineIn = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,
	SineOut = function(t)
		return math.sin(t * math.pi / 2)
	end,
	SineInOut = function(t)
		return (1 - math.cos(t * math.pi)) / 2
	end,
	QuadIn = function(t)
		return t * t
	end,
	QuadOut = function(t)
		return 1 - (1 - t) * (1 - t)
	end,
	QuadInOut = function(t)
		if t < 0.5 then
			return 2 * t * t
		end
		return 1 - 2 * (1 - t) * (1 - t)
	end,
	CubicOut = function(t)
		local u = 1 - t
		return 1 - u * u * u
	end,
	BackOut = function(t)
		local u = t - 1
		return 1 + (BACK_OVERSHOOT + 1) * u * u * u + BACK_OVERSHOOT * u * u
	end,
}

Easing.names = { "Linear", "SineIn", "SineOut", "SineInOut", "QuadIn", "QuadOut", "QuadInOut", "CubicOut", "BackOut" }

-- Returns the ease function. An unknown name is an error (it catches typos in clip data).
function Easing.get(name: string): EaseFn
	local fn = functions[name]
	if not fn then
		error("Unknown ease name: " .. tostring(name), 2)
	end
	return fn
end

-- Eased value for t, with t clamped to [0, 1]. A nil name means Linear.
function Easing.apply(name: string?, t: number): number
	return Easing.get(name or "Linear")(math.clamp(t, 0, 1))
end

return Easing
