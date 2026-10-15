--!strict
-- Shared/Dialogue/CH1_Mission.lua  (docs/05_chapter1_script.md S08-S33; format: docs/13 §2)
--
-- The radio lines of the deployment and the Outpost 07 mission. Line ids and text are exactly the script's; the
-- dialogue ids (DLG_M01_...) are ours. All are "radio" mode: the server steps through them by itself.
-- S31 plays its lines in cinematic mode (choice C3, WA_09a-WA_10b, WA_09c, D-088); the VOICE lines of S33 come
-- with the anomaly.

local function radio(lines: { { string } })
	local nodes = {}
	for index, line in ipairs(lines) do
		nodes[line[1]] = { speaker = line[2], text = line[3], next = if lines[index + 1] then lines[index + 1][1] else nil }
	end
	return { mode = "radio", start = lines[1][1], nodes = nodes }
end

local function cinematic(lines: { { string } })
	local dialogue = radio(lines)
	dialogue.mode = "cinematic"
	return dialogue
end

return {
	-- The deployment (S08-S10). BD_01-03 belong to the first-boarding shot of Phase 5; until then they play as radio.
	DLG_CH1_BOARD = radio({
		{ "BD_01", "M", "Did you do the tap thing?" },
		{ "BD_02", "E", "...No." },
		{ "BD_03", "M", "You did the tap thing." },
		{ "BD_04", "O", "Ember Squad, Halden Overwatch. You're cleared to proceed to Launch One." },
	}),
	DLG_CH1_DOOR = radio({
		{ "DR_01", "M", "Never gets old." },
		{ "DR_02", "E", "We've done this once." },
		{ "DR_03", "M", "And it never got old." },
	}),
	DLG_CH1_LAUNCH = radio({
		{ "LA_01", "O", "Ember-1, Ember-2, Launch One is yours. Corridor gate opening. Good hunting." },
	}),
	DLG_M01_ARRIVAL = radio({
		{ "AR_01", "M", "Ember-1 to Overwatch. We're on the Seven approach. Visibility's poor." },
		{ "AR_02", "O", "Overwatch copies. Still no signal from the outpost on any band." },
		{ "AR_03", "E", "Road's empty. No patrol. No lights." },
		{ "AR_04", "M", "Stay on my left, Eli. Weapons free past the wall." },
	}),
	DLG_M01_TRUCK = radio({
		{ "AR_05", "E", "That truck's been here a while. Rust on the bolts." },
		{ "AR_06", "M", "Old damage. Keep moving." },
	}),
	DLG_M01_GATE = radio({
		{ "SG_01", "M", "Gate's open. Not broken—open." },
		{ "SG_02", "E", "Somebody left in a hurry." },
		{ "SG_03", "O", "Ember Squad, the outpost grid reads dead from here. Breaker yard is northwest." },
	}),
	DLG_M01_POWER = radio({
		{ "PW_01", "O", "Power's up. I see the bunker's array... but it isn't transmitting." },
		{ "PW_02", "M", "Array's on the bunker roof. Someone has to go in and reroute by hand." },
		{ "PW_03", "E", "I'll go." },
		{ "PW_04", "M", "Pad's south of the bunker. I'll cover you." },
	}),
	DLG_M01_COMMS = radio({
		{ "CM_01", "O", "—alden Overwatch, do you read? Ember Squad, signal's clean! Good work, Ember-2." },
		{ "CM_02", "E", "Overwatch, the bunker's empty. No garrison. Bunks unmade. Food still on the tables." },
		{ "CM_03", "O", "Copy. Command wants a damage assessment before anything else. Have a look around." },
		{ "CM_04", "M", "Eli. Some of this damage doesn't make sense. Check the cable run outside the east wall." },
	}),
	DLG_M01_CLUE_A = radio({
		{ "IN_A1", "E", "Main comm cable. Cut, not crushed. Clean edges." },
		{ "IN_A2", "M", "Titans don't cut." },
		{ "IN_A3", "E", "No. They don't." },
	}),
	DLG_M01_CLUE_B = radio({
		{ "IN_B1", "E", "Fuel depot's untouched. Titans go for heat sources first. Every textbook says so." },
		{ "IN_B2", "M", "So this one didn't read the textbook." },
	}),
	DLG_M01_CLUE_C = radio({
		{ "IN_C1", "E", "Footprints. Big. Bigger than a Class-Two." },
		{ "IN_C2", "E", "It stepped over the mess hall. Over it. Like it didn't want to break anything." },
		{ "IN_C3", "M", "...I don't like that, Eli." },
	}),
	DLG_M01_CLUES_DONE = radio({
		{ "IN_D1", "O", "Overwatch copies all of that. Command's... going to want to hear this directly." },
		{ "IN_D2", "M", "Ember-2, I've got tracks. Same prints, heading north out the far gate. Fresh." },
		{ "IN_D3", "O", "Command authorizes: follow the trail and observe. Do not engage anything above Class-Two." },
	}),
	DLG_M01_TRAIL_1 = radio({
		{ "TW_01", "M", "Remember the Corrow rooftop? Counting convoys?" },
		{ "TW_02", "E", "You always said the fifth one was carrying candy." },
		{ "TW_03", "M", "One time. One time I was right." },
	}),
	DLG_M01_TRAIL_2 = radio({
		{ "TW_04", "E", "Mara. If the garrison walked out... where'd they go?" },
		{ "TW_05", "M", "Five's closest. Lowmarch." },
		{ "TW_06", "E", "...Yeah." },
	}),
	DLG_M01_TRAIL_3 = radio({
		{ "TW_07", "O", "Ember Squad, you're approaching Kessler Basin. Old reservoir. Visibility's going to drop." },
	}),
	DLG_M01_CONTACT = radio({
		{ "ST_01", "M", "Contact! That's—that's no Class-Two!" },
		{ "ST_02", "O", "Ember Squad, readings put it at Class-Three. You're authorized to withdraw—" },
		{ "ST_03", "M", "It's sitting on the trail. We take it here. Eli, ankles first—bring it down!" },
	}),
	-- S28 fight barks (BarkController plays them as radio subtitles while the fight runs; when each one fires: D-087).
	DLG_FB_M1 = { mode = "bark", nodes = { FB_M1 = { speaker = "M", text = "I'm drawing its attention!" } } },
	DLG_FB_M2 = { mode = "bark", nodes = { FB_M2 = { speaker = "M", text = "Hit the legs!" } } },
	DLG_FB_M3 = { mode = "bark", nodes = { FB_M3 = { speaker = "M", text = "Watch the stomp!" } } },
	DLG_FB_M4 = { mode = "bark", nodes = { FB_M4 = { speaker = "M", text = "Eli, your armor's smoking!" } } },
	DLG_FB_M5 = { mode = "bark", nodes = { FB_M5 = { speaker = "M", text = "Core's open! Now!" } } },
	DLG_FB_M6 = { mode = "bark", nodes = { FB_M6 = { speaker = "M", text = "It's healing! Don't let up!" } } },
	DLG_FB_E1 = { mode = "bark", nodes = { FB_E1 = { speaker = "E", text = "Come on, come on..." } } },
	DLG_FB_E2 = { mode = "bark", nodes = { FB_E2 = { speaker = "E", text = "Got it!" } } },
	DLG_FB_O1 = { mode = "bark", nodes = { FB_O1 = { speaker = "O", text = "Its readings are spiking!" } } },
	DLG_FB_M7 = { mode = "bark", nodes = { FB_M7 = { speaker = "M", text = "Then we finish it fast." } } },
	DLG_M01_FAIL = radio({
		{ "FAIL_M1", "M", "Eli! Come on—get up, get up!" },
	}),
	DLG_M01_VICTORY = radio({
		{ "VI_01", "M", "...Is it—" },
		{ "VI_02", "E", "It's ashing." },
		{ "VI_03", "M", "Good. Good. Ember-1 to Overwatch. Target down." },
		{ "VI_04", "O", "Overwatch copies. Nice work, both of you. Secure the area." },
	}),
	-- S31 (the Watcher) plays as a cinematic: its lines sit in the letterbox, one dialogue per camera beat.
	DLG_M01_WATCHER_1 = cinematic({
		{ "WA_01", "M", "Eli. Ridge. Two o'clock." },
	}),
	DLG_M01_WATCHER_2 = cinematic({
		{ "WA_02", "E", "That's... bigger." },
		{ "WA_03", "M", "Why isn't it moving?" },
	}),
	DLG_M01_WATCHER_3 = cinematic({
		{ "WA_04", "O", "Ember Squad, I have a second contact. It's—it's not on any registry." },
	}),
	DLG_M01_WATCHER_4 = cinematic({
		{ "WA_05", "V", "Ember Squad, Vale. Status." },
		{ "WA_06", "M", "Second Titan. Class-Three, maybe Four. It's not attacking, sir." },
	}),
	-- Beat 7 and choice C3 (timer 10 s; timeout = option 3). The toast is the same for 1 and 2, deliberately.
	DLG_M01_WATCHER_5 = {
		mode = "cinematic",
		start = "WA_07",
		nodes = {
			WA_07 = { speaker = "V", text = "Ember Squad, pursue and maintain contact.", next = "WA_08" },
			WA_08 = {
				speaker = "M", text = "Sir, we're banged up. Two damaged Frames against a Class-Three-plus—",
				timer = 10, timeoutChoice = 3,
				choices = {
					{
						text = "She's right, sir. We're in no shape.", next = "WA_09a",
						effects = { { rel = "mara", add = 1, toast = "Mara will remember that." }, { rel = "vale", add = -1 }, { flag = "CH1_SIDED_MARA" } },
					},
					{
						text = "We can handle it, Mara.", next = "WA_09b",
						effects = { { rel = "mara", add = -1, toast = "Mara will remember that." }, { rel = "vale", add = 1 }, { flag = "CH1_SIDED_VALE" } },
					},
					{ text = "[Say nothing]", next = "WA_09c", effects = { { flag = "CH1_SILENT_PURSUIT" } } },
				},
			},
			WA_09a = { speaker = "V", text = "...Noted, Ember-2.", next = "WA_10a" },
			WA_10a = { speaker = "M", text = "Thanks.", style = "quiet", next = "WA_11" },
			WA_09b = { speaker = "M", text = "Eli—", next = "WA_10b" },
			WA_10b = { speaker = "V", text = "Noted.", next = "WA_11" },
			WA_09c = { speaker = "M", text = "Eli? ...Fine.", next = "WA_11" },
			WA_11 = { speaker = "V", text = "Negative on pursuit, then. Hold position. Observe and record. Do not engage." },
		},
	},
	DLG_M01_WATCHER_6 = cinematic({
		{ "WA_12", "O", "Contact's off my scope. It just... went." },
		{ "WA_13", "M", "Titans don't take things, Eli. They don't take things." },
		{ "WA_14", "V", "Ember Squad. Investigate that vehicle. I want to know what it was carrying." },
	}),
	DLG_M01_ROVER_MARKING = radio({
		{ "RV_01", "E", "Science Division markings. Three rings. Never seen that symbol before." },
	}),
	DLG_M01_ROVER_CRADLE = radio({
		{ "RV_02", "E", "Cryo cradle. Empty. Label says... \"Subject T-V. ECHO-9.\"" },
		{ "RV_03", "M", "Subject? Subject of what?" },
		{ "RV_04", "E", "Doesn't say." },
	}),
	DLG_M01_ROVER_CASE = radio({
		{ "RV_05", "E", "Huh. Lock just... let go." },
		{ "RV_06", "M", "What is it?" },
		{ "RV_07", "E", "Data spindle. Classified seals all over it." },
		{ "RV_08", "V", "Pilot, bring it to your Frame. Standard protocol: upload a copy to Overwatch." },
	}),
	-- S33's memory: the client shows these itself during the anomaly (italic cyan, no name; VOICE in Speakers).
	DLG_M01_VOICE = radio({
		{ "VOICE_01", "VOICE", "Eli... count the steps." },
		{ "VOICE_02", "VOICE", "All the way home." },
	}),
	DLG_M01_DARK = radio({
		{ "AN_01", "M", "Eli! Eli, answer me! Overwatch, his Frame's gone dark—" },
	}),
	-- Said by BoundsService when the Frame drives into a bounds warning (docs/12 §9).
	DLG_OOB = radio({
		{ "OOB_01", "O", "Ember-2, you're leaving the operations area." },
	}),
}
