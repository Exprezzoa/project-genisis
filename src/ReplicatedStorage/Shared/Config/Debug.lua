--!strict
-- Shared/Config/Debug.lua  (docs/19_testing_and_debug.md §2)
--
-- Debug command table. Studio only: the server rejects Debug_Command outside Studio.
-- side: "server" (sent with Debug_Command) or "client" (handled by DebugController).
-- phase: the phase whose systems the command needs; until then it answers "not available yet".

return {
	TOGGLE_KEY = Enum.KeyCode.F2,

	-- /zone <name> -> default spawn. Zones without a built map answer "not built yet".
	ZoneSpawns = {
		hub = "SPAWN_OPS",
		hangar = "SPAWN_HANGAR_FLOOR",
		training = "SPAWN_TRAINING",
		outpost = "FRAME_OP_START_02",
		basin = "FRAME_OP_FIGHT",
		memory = "SPAWN_MEMORY",
	},

	-- /door <name> -> DoorId of the door part (stand-ins until the real doors are built).
	Doors = { west = "DOOR_HANGAR_WEST", east = "DOOR_HANGAR_EAST" },

	-- Hurtbox colors by zone for /hurtboxes.
	ZoneColors = {
		Body = Color3.fromHex("#E8A33D"), Head = Color3.fromHex("#E5484D"), AnkleL = Color3.fromHex("#46C17A"), AnkleR = Color3.fromHex("#46C17A"),
		ArmL = Color3.fromHex("#9AA6B2"), ArmR = Color3.fromHex("#9AA6B2"), Core = Color3.fromHex("#E25B2D"),
	},

	Commands = {
		tp = { side = "server", phase = 1, usage = "/tp <spawnId>" },
		zone = { side = "server", phase = 1, usage = "/zone <hub|hangar|training|outpost|basin|memory>" },
		flags = { side = "server", phase = 1, usage = "/flags" },
		flag = { side = "server", phase = 1, usage = "/flag <NAME> [on|off]" },
		save = { side = "server", phase = 1, usage = "/save" },
		wipe = { side = "server", phase = 1, usage = "/wipe confirm" },
		dsfail = { side = "server", phase = 1, usage = "/dsfail <on|off>" },
		lighting = { side = "server", phase = 1, usage = "/lighting <MORNING|OVERCAST|EVENING|NIGHT|MEMORY>" },
		fps = { side = "client", phase = 1, usage = "/fps" },
		nav = { side = "client", phase = 1, usage = "/nav" },
		help = { side = "client", phase = 1, usage = "/help" },

		frame = { side = "server", phase = 2, usage = "/frame" },
		god = { side = "server", phase = 2, usage = "/god" },
		energy = { side = "server", phase = 2, usage = "/energy" },
		hitboxes = { side = "client", phase = 2, usage = "/hitboxes" },
		hurtboxes = { side = "server", phase = 2, usage = "/hurtboxes" },
		door = { side = "server", phase = 2, usage = "/door <west|east> [open|close]" },
		titan = { side = "server", phase = 3, usage = "/titan Strider | kill | hp <n>   (down and freeze come with the behavior)" },
		timescale = { side = "server", phase = 3, usage = "/timescale <0.25-2>" },
		step = { side = "server", phase = 4, usage = "/step <stepId>" },
		checkpoint = { side = "server", phase = 4, usage = "/checkpoint <id>" },
		rel = { side = "server", phase = 5, usage = "/rel <var> <value>" },
		give = { side = "server", phase = 6, usage = "/give xp|credits <n>" },
	},

	CURRENT_PHASE = 3,
}
