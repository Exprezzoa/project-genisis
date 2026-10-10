--!strict
-- Shared/Modules/MathUtil.lua
--
-- Small math helpers shared by server and client. Pure functions, no services.

local MathUtil = {}

MathUtil.STUDS_TO_METERS = 0.33 -- docs/06_art_direction.md §2

function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Where x sits between a and b (0 at a, 1 at b), clamped.
function MathUtil.inverseLerp(a: number, b: number, x: number): number
	if a == b then
		return 0
	end
	return math.clamp((x - a) / (b - a), 0, 1)
end

function MathUtil.remap(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return MathUtil.lerp(outMin, outMax, MathUtil.inverseLerp(inMin, inMax, x))
end

-- Moves current toward target by at most maxDelta (acceleration and turn-rate limits).
function MathUtil.approach(current: number, target: number, maxDelta: number): number
	local delta = target - current
	if math.abs(delta) <= maxDelta then
		return target
	end
	return current + math.sign(delta) * maxDelta
end

-- Frame-rate independent smoothing: the fraction to lerp this frame for a given rate per second.
function MathUtil.smoothAlpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function MathUtil.round(x: number, step: number?): number
	local s = step or 1
	return math.floor(x / s + 0.5) * s
end

function MathUtil.isFinite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function MathUtil.isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3" and MathUtil.isFinite(v.X) and MathUtil.isFinite(v.Y) and MathUtil.isFinite(v.Z)
end

function MathUtil.isUnitVector(v: any, tolerance: number?): boolean
	return MathUtil.isFiniteVector(v) and math.abs(v.Magnitude - 1) <= (tolerance or 0.05)
end

-- The vector with Y removed (horizontal distance and direction checks).
function MathUtil.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MathUtil.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Shortest signed difference between two angles in radians, in (-pi, pi].
function MathUtil.angleDelta(from: number, to: number): number
	local delta = (to - from) % (2 * math.pi)
	if delta > math.pi then
		delta -= 2 * math.pi
	end
	return delta
end

-- True when the world-space point lies inside the oriented box (trigger and zone tests).
function MathUtil.pointInBox(point: Vector3, boxCFrame: CFrame, boxSize: Vector3): boolean
	local localPoint = boxCFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= boxSize.X / 2
		and math.abs(localPoint.Y) <= boxSize.Y / 2
		and math.abs(localPoint.Z) <= boxSize.Z / 2
end

-- True when the point lies inside the axis-aligned box given by two corners.
function MathUtil.pointInBounds(point: Vector3, min: Vector3, max: Vector3): boolean
	return point.X >= min.X and point.X <= max.X
		and point.Y >= min.Y and point.Y <= max.Y
		and point.Z >= min.Z and point.Z <= max.Z
end

function MathUtil.studsToMeters(studs: number): number
	return studs * MathUtil.STUDS_TO_METERS
end

return MathUtil
