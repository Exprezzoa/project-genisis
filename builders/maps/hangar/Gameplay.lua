--!nonstrict
-- builders/maps/hangar/Gameplay.lua  ->  DevTools.Builders.Hangar.Gameplay
-- docs/maps/map_02_frame_hangar.md §11 (+ markers and nav nodes of the hangar, the gate corridor and the
-- launch platform from Common). Hatch prompts (INT_BOARD_BAY1/2) arrive with the Frames in Phase 2.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Gameplay", true)
	local BK, G = ctx.BK, ctx.Gameplay

	BK.trigger(G, "TRG_HANGAR_REVEAL", V(-15, 0, -80), V(15, 20, -70), "TRG_HANGAR_REVEAL")
	BK.trigger(G, "TRG_DEPLOY_DOOR", V(70, 0, -190), V(118, 60, -110), "TRG_DEPLOY_DOOR")

	BK.camPoint(G, "CAM_HANGAR_REVEAL_1", V(0, 3, -150), V(0, 54, -205))
	BK.camPoint(G, "CAM_HANGAR_REVEAL_2", V(-30, 42, -165), V(0, 48, -205))
	BK.camPoint(G, "CAM_DOOR_EXT", V(260, 40, -150), V(120, 35, -150))
	BK.camPoint(G, "CAM_DOOR_REVEAL", V(60, 46, -150), V(600, 40, -150))
	-- "-> Unit 02": at launch it stands on the platform center; the look-at is its chest height there.
	BK.camPoint(G, "CAM_LAUNCH_A", V(180, 20, -100), V(160, 46, -150))
	BK.camPoint(G, "CAM_LAUNCH_B", V(200, 110, -60), V(440, 40, -150))

	-- FrameBarriers (40 tall). Bays 1 and 3 are rings, so the Frames parked inside aren't pushed out.
	local function ring(name, x1, x2, z1, z2)
		BK.barrier(G, name .. "_N", V(x1, 0, z1), V(x2, 40, z1 + 2), "FrameBarrier")
		BK.barrier(G, name .. "_S", V(x1, 0, z2 - 2), V(x2, 40, z2), "FrameBarrier")
		BK.barrier(G, name .. "_W", V(x1, 0, z1 + 2), V(x1 + 2, 40, z2 - 2), "FrameBarrier")
		BK.barrier(G, name .. "_E", V(x2 - 2, 0, z1 + 2), V(x2, 40, z2 - 2), "FrameBarrier")
	end
	ring("FrameBarrier_Bay1", -97, -43, -232, -178)
	ring("FrameBarrier_Bay3", 43, 97, -232, -178)
	BK.barrier(G, "FrameBarrier_Stair", V(-120, 0, -232), V(-100, 40, -140), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_SouthEntrance", V(-16, 0, -72), V(16, 40, -68), "FrameBarrier")

	C.placeRegistry(ctx, { "Hangar", "GateCorridor", "LaunchPlatform" })
	return C.finish(ctx)
end

return Builder
