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
	-- S01: the morning broadcast over black; the picture comes up on S01_04 (the step waits for that line).
	DLG_CH1_COLD_OPEN = {
		mode = "radio",
		start = "S01_01",
		nodes = chain({}, {
			{ "S01_01", "PA", "Good morning, Halden. Day four thousand one hundred and twelve without a breach of the Bulwark." },
			{ "S01_02", "PA", "Ash advisory for the eastern districts. Masks recommended after noon." },
			{ "S01_03", "PA", "And to the newest pilots of the Third: the whole city's proud of you. The Frame stands—" },
			{ "S01_04", "E", "—humanity stands." },
		}),
	},
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
	-- S40: the return (a conversational cinematic in the hangar). RT_04: Rhein takes the case from the technician.
	DLG_CH1_RETURN_1 = {
		mode = "cinematic",
		face = true, -- Elias turns to Vale, and they to him (NPCService)
		participants = { "ValeReturn", "Rhein" },
		start = "RT_01",
		nodes = chain({}, {
			{ "RT_01", "V", "Pilot Veyne. You're on your feet. Good." },
			{ "RT_02", "E", "Sir, the spindle—my Frame, it—" },
			{ "RT_03", "V", "Is being handled." },
			{ "RT_04", "R", "Pilot Veyne. That was good work today. Really.", { action = { npc = "Rhein", takeFrom = "TechCase" } } },
			{ "RT_05", "R", "Get some rest. Let us worry about the rest." },
			{ "RT_06", "E", "...Sir." },
		}),
	},
	-- After Rhein turns away (the camera holds on his pin), Vale sends Elias to Medical.
	DLG_CH1_RETURN_2 = {
		mode = "cinematic",
		face = true,
		participants = { "ValeReturn" },
		start = "RT_07",
		nodes = chain({}, {
			{ "RT_07", "V", "Medical. Now. That's an order, not a suggestion." },
			{ "RT_08", "E", "Sir—the garrison. Lieutenant Ferris's people." },
			{ "RT_09", "V", "Arrived at Outpost Five on foot this afternoon. All twelve. They've been transferred to Science Division for debrief." },
			{ "RT_10", "E", "Science Division? Why not—" },
			{ "RT_11", "V", "Medical, Pilot." },
		}),
	},
	-- S41: Medical, Voss at the scanner (conversation; choice C4, no timer).
	DLG_CH1_MEDICAL = {
		mode = "conversation",
		participants = { "Voss" },
		start = "MD_01",
		nodes = (function()
			local nodes = chain({}, {
				{ "MD_01", "VS", "Pilot Veyne. Stand there—inside the arch. Thank you." },
				{ "MD_02", "VS", "Any nausea? Ringing in the ears? Metallic taste?" },
				{ "MD_03", "E", "A little ringing." },
				{ "MD_04", "VS", "Mm." },
				{ "MD_05", "VS", "Your Frame's core logged a response at the moment it shut down. It's... outside its operating parameters." },
				{ "MD_06", "E", "Outside by how much?" },
				{ "MD_07", "VS", "Enough that I've been asked not to discuss it." },
			}, "MD_08")
			nodes.MD_08 = {
				speaker = "VS", text = "Pilot. When the interface went down, did you notice anything unusual? Sounds. Sensations. Anything.",
				choices = {
					{
						text = "I heard a voice. Someone I knew, I think.", next = "MD_09a",
						effects = { { rel = "voss", add = 1, toast = "Dr. Voss will remember that." }, { flag = "CH1_TOLD_VOSS" } },
					},
					{ text = "Just a headache.", next = "MD_09b", effects = { { flag = "CH1_HID_VOICE" } } },
				},
			}
			-- "(stops writing)" and "(studies him for a second)": a beat before the line.
			chain(nodes, {
				{ "MD_09a", "VS", "...Whose voice?", { pause = 0.8 } },
				{ "MD_10a", "E", "I don't know. It told me to count the steps." },
				{ "MD_11a", "VS", "I'm going to write \"mild auditory disturbance.\"" },
				{ "MD_12a", "VS", "And I'm going to remember what you actually said." },
			}, "MD_14")
			chain(nodes, {
				{ "MD_09b", "VS", "Of course.", { pause = 1.0 } },
				{ "MD_10b", "VS", "If the headache ever starts talking, Pilot... come find me. Not the duty doctor. Me." },
			}, "MD_14")
			chain(nodes, { { "MD_14", "VS", "You're cleared. Get some sleep. Real sleep." } })
			return nodes
		end)(),
	},
	-- S42 (optional): Mara on the Observation Deck. Lines that hang on the day's choices carry their flag.
	DLG_CH1_DECK = {
		mode = "conversation",
		participants = { "MaraDeck" },
		start = "OD_01",
		onEnd = { { flag = "CH1_DECK_SCENE" } },
		nodes = chain({}, {
			{ "OD_01", "M", "Hey." },
			{ "OD_02", "E", "Hey." },
			{ "OD_03", "M", "They wouldn't let me see you. Two hours. I counted." },
			{ "OD_04a", "M", "You said you were nervous this morning. I thought you meant the fight.", { cond = { flag = "CH1_ADMITTED_NERVES" } } },
			{ "OD_04b", "M", "So you got your real Titan. Forty-one to forty, by the way. I'm counting it.", { cond = { flag = "CH1_JOKED_SCORE" } } },
			{ "OD_05", "M", "Your Frame went dark, Eli. Completely dark. I thought—" },
			{ "OD_06", "M", "Never mind what I thought." },
			{ "OD_07a", "M", "And... thanks. For backing me up. Vale's going to make you pay for that.", { cond = { flag = "CH1_SIDED_MARA" } } },
			{ "OD_08a", "E", "Worth it.", { cond = { flag = "CH1_SIDED_MARA" } } },
			{ "OD_07b", "M", "And next time I say we're in no shape to chase a Class-Four, maybe don't tell Vale we can handle it.", { cond = { flag = "CH1_SIDED_VALE" } } },
			{ "OD_08b", "E", "I was trying to—", { cond = { flag = "CH1_SIDED_VALE" } } },
			{ "OD_09b", "M", "I know what you were trying to do. That's the problem.", { cond = { flag = "CH1_SIDED_VALE" } } },
			{ "OD_07c", "M", "You went quiet out there. When Vale asked. You never go quiet.", { cond = { flag = "CH1_SILENT_PURSUIT" } } },
			{ "OD_10", "M", "That thing took something from the truck. Titans don't take things." },
			{ "OD_11", "E", "I know." },
			{ "OD_12", "M", "Get some sleep, Veyne. That's an order from your squad lead." },
			{ "OD_13", "E", "You're not my—" },
			{ "OD_14", "M", "Ember-ONE." },
		}),
	},
	-- S40-S43: the evening PA loop.
	DLG_CH1_PA_E1 = single("radio", "PA_E1", "PA", "Corridor Train Nine arriving, platform one."),
	DLG_CH1_PA_E2 = single("radio", "PA_E2", "PA", "Evening ash advisory lifted for the eastern districts."),
	DLG_CH1_PA_E3 = single("radio", "PA_E3", "PA", "Night shift, report to stations."),
}
