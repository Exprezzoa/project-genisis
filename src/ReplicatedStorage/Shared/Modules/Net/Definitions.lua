--!strict
-- Shared/Modules/Net/Definitions.lua  (docs/16_technical_architecture.md §5, "Remote definitions")
--
-- Every RemoteEvent of the game. C2S entries carry their validator and rate limit (tokens per second, burst).
-- A limit without a burst in the spec uses burst = max(1, rate).

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local V = require(script.Parent.Validate)

export type Definition = {
	direction: "C2S" | "S2C",
	validate: V.Validator?,
	rate: number?,
	burst: number?,
	studioOnly: boolean?,
}

local ID = V.string()

-- Settings_Update: any subset of the settings keys, each within its range; at least one key.
local settingsFields: { [string]: V.Validator } = {}
for key, spec in pairs(GameConfig.Settings :: { [string]: any }) do
	local validator: V.Validator
	if spec.kind == "number" then
		validator = V.number({ min = spec.min, max = spec.max })
	elseif spec.kind == "enum" then
		validator = V.enum(spec.values)
	else
		validator = V.boolean()
	end
	settingsFields[key] = V.optional(validator)
end

local function c2s(fields: { [string]: V.Validator }, rate: number, burst: number?, opts: { minKeys: number? }?): Definition
	return { direction = "C2S", validate = V.payload(fields, opts), rate = rate, burst = burst or math.max(1, rate) }
end

local S2C: Definition = { direction = "S2C" }

local Definitions: { [string]: Definition } = {
	-- Client -> server
	Client_Ready = c2s({}, 0, 1), -- 1 per session
	Frame_Action = c2s({
		action = V.enum({ "Light", "Heavy", "Dodge", "Special", "CoreStrike" }),
		dir = V.optional(V.unitVector()),
		seq = V.number({ min = 0, integer = true }),
	}, 15, 20),
	Frame_Lock = c2s({ targetId = V.optional(ID), zone = V.optional(ID) }, 6),
	Dialogue_Advance = c2s({ dialogueId = ID, nodeId = ID }, 10),
	Dialogue_Choose = c2s({ dialogueId = ID, nodeId = ID, index = V.number({ min = 1, max = 4, integer = true }) }, 4),
	Cinematic_Done = c2s({ cinematicId = ID }, 2),
	Cinematic_Skip = c2s({ cinematicId = ID }, 2),
	Tutorial_Seen = c2s({ id = ID }, 2), -- the card is up: the server sets TUT_<id> if it sent it (D-085)
	Settings_Update = c2s(settingsFields, 1, 1, { minKeys = 1 }),
	Checkpoint_Restart = c2s({}, 1 / 5, 1), -- 1 per 5 s
	Upgrade_Buy = c2s({ upgradeId = ID }, 2),
	Debug_Command = {
		direction = "C2S",
		validate = V.payload({ cmd = ID, args = V.array(ID, 8) }),
		rate = 5,
		burst = 5,
		studioOnly = true,
	},

	-- Server -> client
	Server_Ready = S2C,
	Seq_State = S2C,
	Dialogue_Node = S2C,
	Dialogue_End = S2C,
	Cinematic_Play = S2C,
	Combat_Feedback = S2C,
	UI_Toast = S2C,
	UI_Card = S2C,
	Tutorial_Show = S2C,
	Bark_Play = S2C,
	Lighting_Set = S2C,
	Fade = S2C,
	Music_Set = S2C,
	Profile_Snapshot = S2C,
}

return Definitions
