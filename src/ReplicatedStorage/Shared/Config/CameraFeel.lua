--!strict
-- Shared/Config/CameraFeel.lua  (docs/06_art_direction.md §6 "Camera feel parameters", docs/11 §4)
--
-- Shake magnitudes are multiplied by the Camera Shake setting (0-100%).

local CameraFeel = {}

-- Lengths are the 40-stud Vanguard's numbers of docs/11 times the rig's scale (D-044).
local S = require(script.Parent.FrameConfig).Vanguard.scale

-- Frame camera (docs/11 §4).
CameraFeel.Frame = {
	pivotHeight = 18 * S, -- above the HRP
	distance = { default = 62 * S, min = 40 * S, max = 80 * S },
	pitch = { default = 12, min = -20, max = 60 }, -- degrees of elevation
	shoulder = 6 * S, -- studs to the right; 0 while locked on
	shoulderBlend = 0.3,
	sensitivity = { mouse = 0.25, gamepad = 220, touch = 0.35 }, -- deg/px, deg/s, deg/px
	collision = { radius = 2, pad = 2, minDistance = 12 * S, zoomOutSpeed = 30 * S },
	fov = { base = 70, stride = 78, strideBlend = 0.3, dodgeKick = 6, dodgeKickTime = 0.2 },
	-- The cockpit glass: the whole view is tinted warm while piloting (user direction, D-055). color is AMBER_LAMP;
	-- amount is how far the tint goes from white toward it; time is the fade in and out.
	tint = { color = Color3.fromHex("#FFD38A"), amount = 0.55, time = 0.5 },
	-- Lock-on (docs/11 §4). offset = degrees the player can push the view sideways; it decays back.
	-- side and focus are as built (D-058): the Frame (64) is taller than a Strider (56), so a camera straight
	-- behind it hid the Titan. The locked camera stands `side` degrees off the line to the target and looks at
	-- a point `focus` of the way toward it: the Frame sits left of center, the Titan right. pitch = the least
	-- elevation the view takes when a lock begins (the player can still change it).
	lock = { yawBlend = 6, offset = 25, offsetDecay = 0.6, range = 220 * S, lostSightTime = 2, side = 55, focus = 0.4, focusBlend = 5, pitch = 20 },
}

-- Core Strike camera (docs/11 §4): from the Frame's right, looking at the core, drifting forward round it.
-- orbit = degrees it drifts over the strike; blendIn is as built (the doc only gives the way back, 0.3 s).
CameraFeel.CoreStrike = { distance = 50 * S, height = 10 * S, orbit = 25, blendIn = 0.2, blendOut = 0.3 }

-- Events: shake magnitude, duration (s), hitstop (s), fovPunch (degrees).
CameraFeel.Events = {
	FrameFootstep = { shake = 0.08, duration = 0.15 },
	StriderFootstep = { shake = 0.15, duration = 0.2, fullWithin = 80, zeroAt = 160 },
	LightHit = { shake = 0.12, duration = 0.1, hitstop = 0.05 },
	HeavyHit = { shake = 0.3, duration = 0.18, hitstop = 0.09, fovPunch = -3 },
	PileDriverHit = { shake = 0.45, duration = 0.25, hitstop = 0.12, fovPunch = -5 },
	CoreStrike = { shake = 0.6, duration = 0.4, hitstop = 0.15, fovPunch = -7 },
	PlayerHitLight = { shake = 0.25, duration = 0.2 },
	PlayerHitHeavy = { shake = 0.5, duration = 0.35 },
	Roar = { shake = 0.6, duration = 1.2 },
	StriderStomp = { shake = 0.7, duration = 0.4, within = 40 },
}

-- Which event a landed move plays.
CameraFeel.MoveEvent = {
	Light1 = "LightHit", Light2 = "LightHit", Light3 = "LightHit",
	Heavy = "HeavyHit",
	Special = "PileDriverHit",
	CoreStrike = "CoreStrike",
}

return CameraFeel
