--!strict
-- Shared/Evidence.lua  (docs/05_chapter1_script.md §9; docs/13 §3; docs/14 §7)
--
-- Evidence id -> what the Mission Log and the Log Reader show. Texts are exactly the script's; the titles of LOG2
-- and LOG3 are ours (the script names only the first, "Outpost 07 Command Log", in docs/14 §7).
-- interact: the prompt that collects it.

export type Entry = { title: string, interact: string, text: string }

local Evidence: { [string]: Entry } = {
	OP07_LOG1 = {
		title = "Outpost 07 Command Log",
		interact = "INT_EV_LOG1",
		text = [[OUTPOST 07 — COMMAND LOG — LT. H. FERRIS

2187-03-15 / 16:20
Heavy impacts north, Kessler side. Thought it was the dam settling again.
Sent Okoye up the tower. Vapor over the basin. Class-2 Strider wandering. Standard. Reported to Halden.

2187-03-15 / 23:41
Something big inside the wire. NOT the Strider. Bigger.
It walked between the barracks like it knew where they were. Stopped at the bunker.
Looked at it. I swear it was counting us.
Then it pulled the comm cable. Pulled it. Like a person pulling a plug.

2187-03-16 / 00:58
No comms. No casualties. Not one. That's what scares me.
Taking everyone to Five on foot. If you're reading this: it's not like the others.]],
	},
	OP07_LOG2 = {
		title = "Okoye — Personal",
		interact = "INT_EV_LOG2",
		text = [[PVT. D. OKOYE — PERSONAL

Day 212 at Greywatch. Ferris says I'm the best spotter in the Seventh.
I'm the ONLY spotter in the Seventh.

Today the basin Strider went after a truck. Not ours. Grey, no unit markings,
three rings painted on the door. Science, I think. The truck ran. The Strider caught it.

Nobody got out. Nobody came for it either. Ferris called it in and Halden said
"acknowledged" and nothing else.

Why would Science be out past the posts without an escort?]],
	},
	OP07_LOG3 = {
		title = "Tower Watch — 03-15",
		interact = "INT_EV_LOG3",
		text = [[TOWER WATCH — 03-15 — 23:30 — CPL. R. MBEKI

Second contact, east ridge, moving in. Very tall. Lanky.
Light on its back—not orange like the basin one. BLUE. Blue-white.
It's not looking for food. It keeps stopping. Like it's listening.

They told us the color of a Titan's glow is just chemistry.
Then why have I never seen this chemistry before?]],
	},
}

return Evidence
