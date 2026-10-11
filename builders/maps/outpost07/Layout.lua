--!nonstrict
-- builders/maps/outpost07/Layout.lua  ->  DevTools.Builders.Outpost07.Layout
-- docs/maps/map_03_outpost_07.md, docs/maps/map_00_world_layout.md §2
--
-- Shared by the Outpost 07 builders: the outpost's origin and small helpers that take the map doc's LOCAL
-- coordinates and build at the world position. Inject it like BuildKit and Common:
--
--   local L = require(DT.Builders.Outpost07.Layout:Clone())
--   require(DT.Builders.Outpost07.Compound:Clone()).Build({ BK = BK, Common = Common, Layout = L, pass = "blockout" })
--
--   local T = L.tools(ctx)      T.box, T.slab, T.mark, T.node, T.cam, T.trigger, T.barrier, T.wall, T.standIn,
--                               T.prompt, T.slope                       (all in local coordinates)

local Layout = {}

local V = Vector3.new

Layout.ORIGIN = V(6000, 0, 0)
Layout.ZONE = "Outpost07"
-- A Frame's root floats 22 studs up and is 16 tall (the 64-stud Frame, D-044): it walks over anything lower
-- than that, so every wall and low building gets a FrameBarrier this tall. (map_03 §2 counted on the 18-stud
-- walls blocking the 40-stud Frame's root by themselves.)
Layout.BARRIER_TOP = 60

local FACING = { ["-Z"] = V(0, 0, -1), ["+Z"] = V(0, 0, 1), ["+X"] = V(1, 0, 0), ["-X"] = V(-1, 0, 0) }

function Layout.world(x, y, z)
	return Layout.ORIGIN + V(x, y, z)
end

function Layout.tools(ctx)
	local BK, P = ctx.BK, ctx.P
	local W = Layout.world
	local T = {}

	function T.box(parent, name, x1, y1, z1, x2, y2, z2, style)
		return BK.box(parent, name, W(x1, y1, z1), W(x2, y2, z2), style)
	end

	-- A flat plate with its top at yTop.
	function T.slab(parent, name, x1, x2, z1, z2, yTop, thickness, style)
		return BK.box(parent, name, W(x1, yTop - thickness, z1), W(x2, yTop, z2), style)
	end

	function T.mark(id, x, y, z, facing)
		return BK.spawnPoint(ctx.Gameplay, id, BK.lookAlong(W(x, y, z), FACING[facing or "-Z"]))
	end

	function T.node(id, x, y, z, links)
		return BK.navNode(ctx.Gameplay, id, W(x, y, z), links)
	end

	function T.cam(id, x, y, z, lx, ly, lz)
		return BK.camPoint(ctx.Gameplay, id, W(x, y, z), W(lx, ly, lz))
	end

	function T.trigger(id, x1, z1, x2, z2, y1, y2)
		return BK.trigger(ctx.Gameplay, id, W(x1, y1 or 0, z1), W(x2, y2 or 40, z2), id)
	end

	function T.barrier(name, x1, z1, x2, z2, group, y1, y2)
		return BK.barrier(ctx.Gameplay, name, W(x1, y1 or 0, z1), W(x2, y2 or Layout.BARRIER_TOP, z2), group or "FrameBarrier")
	end

	-- An invisible wall from (ax, az) to (bx, bz), for barriers that don't run along an axis.
	function T.wall(name, ax, az, bx, bz, group, y1, y2)
		local low, high = y1 or 0, y2 or Layout.BARRIER_TOP
		local a, b = W(ax, (low + high) / 2, az), W(bx, (low + high) / 2, bz)
		return BK.beam(ctx.Gameplay, name, a, b, 2, high - low, {
			Transparency = 1, CanCollide = true, CanQuery = true, CanTouch = false, CastShadow = false,
			CollisionGroup = group or "FrameBarrier", Tags = { "NoCollideCamera" },
		})
	end

	-- A blockout stand-in for a prop that blocks movement or carries a prompt; later passes replace it.
	function T.standIn(name, x1, y1, z1, x2, y2, z2, style)
		local props = table.clone(style or ctx.STANDIN)
		props.Attributes = { StandIn = true }
		return BK.box(ctx.Gameplay, name, W(x1, y1, z1), W(x2, y2, z2), props)
	end

	function T.prompt(part, id, text, opts)
		return BK.prompt(part, id, text, opts)
	end

	-- A sloping surface whose top runs from (·, y1, z1) to (·, y2, z2) across x1..x2 (dir "Z"), or from
	-- (x1, y1, ·) to (x2, y2, ·) across z1..z2 (dir "X"). 2 thick.
	function T.slope(parent, name, dir, a1, a2, b1, b2, y1, y2, style)
		local thick = 2
		local from, to, width
		if dir == "Z" then -- a = x span, b = z run
			from, to, width = W((a1 + a2) / 2, y1, b1), W((a1 + a2) / 2, y2, b2), math.abs(a2 - a1)
		else -- a = z span, b = x run
			from, to, width = W(b1, y1, (a1 + a2) / 2), W(b2, y2, (a1 + a2) / 2), math.abs(a2 - a1)
		end
		local along = (to - from).Unit
		local side = if dir == "Z" then Vector3.xAxis else Vector3.zAxis
		local normal = along:Cross(side)
		if normal.Y < 0 then
			normal = -normal
		end
		local drop = normal * (thick / 2)
		return BK.beam(parent, name, from - drop, to - drop, width, thick, style)
	end

	T.W = W
	T.GROUND = { Color = P.GROUND, Material = "Ground" }
	T.CONCRETE = { Color = P.CONCRETE_MID, Material = "Concrete" }
	T.CONCRETE_DARK = { Color = P.CONCRETE_DARK, Material = "Concrete" }
	T.CONCRETE_LIGHT = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	T.ASPHALT = { Color = P.ASPHALT, Material = "Asphalt" }
	T.ROCK = { Color = P.ROCK, Material = "Rock" }
	T.ROCK_DARK = { Color = P.ROCK_DARK, Material = "Basalt" }
	T.RUST = { Color = P.RUST, Material = "CorrodedMetal" }
	T.STEEL = { Color = P.STEEL_MID, Material = "Metal" }
	T.MARK = { Color = P.STEEL_DARK, CanCollide = false, CanQuery = false, CastShadow = false } -- flat marks on the ground
	return T
end

return Layout
