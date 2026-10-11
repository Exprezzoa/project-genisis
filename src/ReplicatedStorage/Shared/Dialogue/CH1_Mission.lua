--!strict
-- Shared/Dialogue/CH1_Mission.lua  (docs/05_chapter1_script.md S20-S27; format: docs/13 §2)
--
-- The radio lines of the Outpost 07 mission up to the basin. Line ids and text are exactly the script's; the
-- dialogue ids (DLG_M01_...) are ours. All are "radio" mode: the server steps through them by itself.
-- S28 onward (the fight, the Watcher, the rover) is added with those steps.

local function radio(lines: { { string } })
	local nodes = {}
	for index, line in ipairs(lines) do
		nodes[line[1]] = { speaker = line[2], text = line[3], next = if lines[index + 1] then lines[index + 1][1] else nil }
	end
	return { mode = "radio", start = lines[1][1], nodes = nodes }
end

return {
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
}
