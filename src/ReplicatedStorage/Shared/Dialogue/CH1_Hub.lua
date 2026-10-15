--!strict
-- Shared/Dialogue/CH1_Hub.lua  (docs/05_chapter1_script.md S02-S07; format: docs/13 §2)
--
-- Chapter 1's hub dialogue before the deployment. Line ids and text are exactly the script's; the dialogue ids
-- (DLG_CH1_...) are ours. [E-thought] lines use speaker "E" with style "thought" (italic, no name).
-- Actions: npc moves for NPCService, cam/slide hints for the briefing's cinematic (docs/13 §2 "action").

type Node = { [string]: any }

-- Linear lines: { id, speaker, text, extra? } each pointing at the next; the last one's next is `after`.
local function chain(nodes: { [string]: Node }, lines: { { any } }, after: string?)
	for index, line in ipairs(lines) do
		local node: Node = { speaker = line[2], text = line[3], next = if lines[index + 1] then lines[index + 1][1] else after }
		for key, value in pairs(line[4] or {}) do
			node[key] = value
		end
		nodes[line[1]] = node
	end
	return nodes
end

local function single(mode: string, id: string, speaker: string, text: string, extra: { [string]: any }?)
	local node: Node = { speaker = speaker, text = text }
	for key, value in pairs(extra or {}) do
		node[key] = value
	end
	return { mode = mode, start = id, nodes = { [id] = node } }
end

local maraHangar = chain({}, {
	{ "MH_01", "M", "There he is. I was about to send a search party." },
	{ "MH_02", "E", "I took the long way." },
	{ "MH_03", "M", "You got lost." },
	{ "MH_04", "E", "I took the scenic way." },
	{ "MH_05", "M", "Through a building with no windows. Inspiring." },
	{ "MH_06", "M", "She looks good. Hollis repainted your shoulder stripe. Twice. Said your first coat was \"emotionally upsetting.\"" },
	{ "MH_07", "E", "It was fine." },
	{ "MH_08", "M", "It was crooked, Eli." },
	{ "MH_09", "M", "So. First real deployment. No simulator. No reset button." },
})
maraHangar.MH_09.next = "MH_10"
-- Choice C1 (no timer). No relationship change; the flags change lines in S42.
maraHangar.MH_10 = {
	speaker = "M", text = "You nervous?",
	choices = {
		{ text = "Honestly? Yeah.", effects = { { flag = "CH1_ADMITTED_NERVES" } }, next = "MH_11a" },
		{ text = "Not as nervous as you'll be when I tie the score.", effects = { { flag = "CH1_JOKED_SCORE" } }, next = "MH_11b" },
	},
}
chain(maraHangar, {
	{ "MH_11a", "M", "...Good. Means you're paying attention." },
	{ "MH_12a", "M", "Me too. A little. Tell anyone and I'll deny it." },
}, "MH_14")
chain(maraHangar, {
	{ "MH_11b", "M", "Forty-one to thirty-nine, Veyne. Simulators. You'd need a real Titan to catch up." },
	{ "MH_12b", "E", "Don't tempt me." },
	{ "MH_13b", "M", "Don't tempt fate." },
}, "MH_14")
chain(maraHangar, {
	-- Hollis walks in from Bay 3 for MH_14 and back after MH_18 (docs/05 S05).
	{ "MH_14", "H", "Ember-2! Your girl's fueled, calibrated, and if you scratch my new paint I'll weld you to the floor.", { action = { npc = "Hollis", moveTo = "MARK_HOLLIS_TALK" } } },
	{ "MH_15", "E", "Good morning to you too, Chief." },
	{ "MH_16", "H", "And stay clear of Three today. She's moody." },
	{ "MH_17", "M", "Moody?" },
	{ "MH_18", "H", "Core's running warm. Pulsing. Happens sometimes. Don't ask me why. I fix the parts that don't breathe." },
	{ "MH_19", "PA", "Ember Squad, report to Briefing Room One. Ember Squad to Briefing Room One.", { action = { npc = "Hollis", moveTo = "MARK_HOLLIS_START" } } },
	{ "MH_20", "M", "That's us. Race you?" },
	{ "MH_21", "E", "We're not allowed to run in the hangar." },
	{ "MH_22", "M", "Then walk faster." },
})

-- The briefing (S07): a cinematic; each line names its shot and slide (docs/05 S07 table).
local briefing = chain({}, {
	{ "BR_01", "V", "Ember Squad. Sit.", { action = { cam = "CAM_BRF_WIDE", slide = 1 } } },
	{ "BR_02", "V", "At zero-zero-ten, Frontier Outpost Seven missed its scheduled report. Then its next three.", { action = { cam = "CAM_BRF_VALE", slide = 2 } } },
	{ "BR_03", "V", "Last contact was routine. Weather nominal. No Titan activity flagged.", { action = { cam = "CAM_BRF_VALE", slide = 3 } } },
	{ "BR_04", "V", "Most likely cause is relay failure. Garrison strength is twelve, under Lieutenant Ferris.", { action = { cam = "CAM_BRF_WIDE", slide = 4 } } },
	{ "BR_05", "V", "Your orders: travel to Outpost Seven, assess, restore communications, and report.", { action = { cam = "CAM_BRF_VALE", slide = 5 } } },
	{ "BR_06", "M", "Expected resistance, sir?", { action = { cam = "CAM_BRF_PILOTS" } } },
	{ "BR_07", "V", "Nearest recorded Titan is a Class-Two Strider, Kessler Basin. Stale data.", { action = { cam = "CAM_BRF_VALE", slide = 6 } } },
	{ "BR_08", "V", "Anything above Class-Two, you report and you withdraw. Is that understood?", { action = { cam = "CAM_BRF_VALE" } } },
	{ "BR_09", "M", "Understood, sir.", { action = { cam = "CAM_BRF_PILOTS" } } },
	{ "BR_10", "E", "Understood.", { action = { cam = "CAM_BRF_PILOTS" } } },
})
briefing.BR_10.next = "BR_11"
-- Choice C2 (timer 12 s; timeout = option 3, saying nothing).
briefing.BR_11 = {
	speaker = "V", text = "Outpost Five at Lowmarch is your fallback if you lose contact with Halden.", action = { cam = "CAM_BRF_WIDE", slide = 7 },
	timer = 12, timeoutChoice = 3,
	choices = {
		{ text = "Could it just be a broken relay?", next = "BR_12a" },
		{ text = "Lowmarch... my father's unit was there.", effects = { { flag = "CH1_ASKED_LOWMARCH" } }, next = "BR_12b" },
		{ text = "[Say nothing]", next = "BR_14" },
	},
}
chain(briefing, { { "BR_12a", "V", "That's what I'm hoping you'll tell me." } }, "BR_14")
chain(briefing, {
	{ "BR_12b", "V", "Lowmarch was a bad week.", { pause = 1.2 } },
	{ "BR_13b", "V", "Focus on today, Pilot." },
}, "BR_14")
chain(briefing, {
	{ "BR_14", "V", "Overwatch runs your comms. Corporal Okafor has the net." },
	{ "BR_15", "V", "First deployments are where good pilots learn to be careful. Be careful." },
	{ "BR_16", "V", "Dismissed." },
})

return {
	DLG_CH1_THOUGHTS = {
		mode = "radio",
		nodes = {
			S02_PHOTO_1 = { speaker = "E", style = "thought", text = "Dad's last unit photo. Ninth Frontier Defense. He's the one not smiling." },
			S02_PHOTO_2 = { speaker = "E", style = "thought", text = "Six years. They never found anything." },
			S02_LOCKER = { speaker = "E", style = "thought", text = "His old patch. For luck." },
			S02_WINDOW = { speaker = "E", style = "thought", text = "Ash on the glass again." },
			S03_BOARD = { speaker = "E", style = "thought", text = "Outpost Seven: report overdue. Six hours." },
			S03_POSTER = { speaker = "E", style = "thought", text = "\"The Frame stands, humanity stands.\" Dad had this one in the kitchen." },
			S03_HOLO = { speaker = "E", style = "thought", text = "Forty-one kilometers to Seven. Feels further on the map." },
			-- map_01 §10 gives this line without an id; the id is ours (D-030).
			S03_RESEARCH_DOOR = { speaker = "E", style = "thought", text = "Clearance three. Not today." },
		},
	},
	-- S02: Tamsin Rook in the quarters hallway (clue 12), and her line on a repeat talk.
	DLG_CH1_TAMSIN = {
		mode = "conversation",
		participants = { "Tamsin" },
		start = "T_01",
		onEnd = { { flag = "CH1_TALKED_TAMSIN" } },
		nodes = chain({}, {
			{ "T_01", "T", "Veyne! First deployment, right? Don't puke in the cockpit. They make you clean it." },
			{ "T_02", "E", "Is that an actual rule?" },
			{ "T_03", "T", "It's an actual smell. Oh—and if you start feeling core-sick out there, keep it to yourself." },
			{ "T_04", "E", "Why?" },
			{ "T_05", "T", "Two guys from my class reported it. Got \"reassigned.\" Nobody's heard from them since." },
			{ "T_06", "T", "Probably just paperwork. Probably." },
			{ "T_07", "E", "...Thanks, Rook." },
			{ "T_08", "T", "Good hunting, Ember-2." },
		}),
	},
	DLG_CH1_TAMSIN_REPEAT = single("conversation", "T_R1", "T", "Go, go. Your squad lead's going to kill you."),
	-- S03: Okafor at console C1, once.
	DLG_CH1_OKAFOR = {
		mode = "conversation",
		participants = { "Okafor" },
		start = "OK_01",
		nodes = chain({}, {
			{ "OK_01", "O", "Morning, Ember-2. I'll be your voice out there today. Try to keep your radio on this time." },
			{ "OK_02", "E", "That was one time." },
			{ "OK_03", "O", "Twice. But who's counting? Me. I'm counting." },
		}),
	},
	-- S03: the PA loop (one line every 45 s in Central Command until S07) and the officers' ambient barks.
	DLG_CH1_PA_A1 = single("radio", "PA_A1", "PA", "Corridor Train Six departing Halden Central, platform one."),
	DLG_CH1_PA_A2 = single("radio", "PA_A2", "PA", "Reminder: hangar access requires active clearance."),
	DLG_CH1_PA_A3 = single("radio", "PA_A3", "PA", "Maintenance crew to Bay Three. Maintenance crew to Bay Three."),
	DLG_CH1_PA_A4 = single("radio", "PA_A4", "PA", "Ember Squad, report to the Frame Hangar for pre-deployment check."),
	DLG_BARK_OPS_1 = single("bark", "BARK_OPS_1", "OFFICER", "Seven's still dark? That's six hours past window."),
	DLG_BARK_OPS_2 = single("bark", "BARK_OPS_2", "OFFICER", "Relay's probably iced. Happens every winter."),
	DLG_BARK_OPS_3 = single("bark", "BARK_OPS_3", "OFFICER", "It's March."),
	-- S04: the end of the hangar reveal.
	DLG_CH1_HANGAR_REVEAL = single("cinematic", "S04_01", "E", "...Hey, Oh-Two.", { style = "thought" }),
	-- S05: Mara at the viewing line; choice C1.
	DLG_CH1_MARA_HANGAR = { mode = "conversation", participants = { "Mara", "Hollis" }, start = "MH_01", nodes = maraHangar },
	-- S06: walk banter in the Ops Hall.
	DLG_CH1_WALK = {
		mode = "radio",
		start = "WB_01",
		nodes = chain({}, {
			{ "WB_01", "M", "Okafor's on our net today." },
			{ "WB_02", "E", "She's going to bring up the radio thing." },
			{ "WB_03", "M", "She's already brought up the radio thing. To me. Twice." },
		}),
	},
	-- S07: the briefing (cinematic, choice C2) and Mara's line at the door afterwards.
	DLG_CH1_BRIEFING = { mode = "cinematic", participants = { "Vale", "Mara" }, start = "BR_01", nodes = briefing },
	DLG_CH1_BRIEF_END = single("radio", "BR_17", "M", "\"Be careful.\" That's practically a hug, for him."),
}
