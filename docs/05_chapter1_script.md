# 05 — Chapter 1 Script: "The Last Quiet Morning"

This is the complete, buildable script for the Vertical Slice: every scene, trigger, objective, line, choice, flag, camera shot and checkpoint. Data formats are defined in `13_missions_dialogue_relationships.md`. Coordinates are world space (Central Command) or Outpost-local (add the Outpost origin **(6000, 0, 0)**). Both are defined in `maps/`.

**In-world date:** 2187-03-16. **Morning** lighting preset in the hub, **Overcast** at the outpost, **Evening** on return, **Night** after the chapter ends (`06_art_direction.md` §5).

**Line format:** `ID | SPEAKER | Text`. Speaker codes: `E` Elias, `M` Mara, `V` Vale, `VS` Voss, `R` Rhein, `H` Hollis, `O` Okafor (Overwatch), `T` Tamsin, `PA` public address, `VOICE` the anomaly voice (cyan italic). `[E-thought]` = Elias's inner line (subtitle in italics, no speaker name). Radio lines get a "📻"-style indicator: the speaker name in brackets, e.g. `[OVERWATCH]`.

Default subtitle timing: `max(2.2 s, 0.06 s × characters)`. Player can advance with click / A / tap after 0.6 s, except in timed cinematics (marked ⏱).

---

## 0. Chapter flow at a glance

| # | Scene | Location | Checkpoint on completion |
|---|---|---|---|
| S01 | Cold open | Black screen → Quarters Q-3 | — |
| S02 | Quarters (free roam) | Pilot Quarters | — |
| S03 | Walk through Ops Hall | Ops Hall | — |
| S04 | Hangar reveal | Hangar entrance | — |
| S05 | Mara at the viewing line | Hangar, Bay 2 | — |
| S06 | Walk to briefing | Hangar → Briefing Room | — |
| S07 | Briefing | Briefing Room One | `CH1_BRIEFED` |
| S08 | Boarding + Frame tutorial | Hangar Bay 2 | — |
| S09 | Deployment door reveal | Hangar east door | — |
| S10 | Launch | Launch Platform | `CH1_DEPLOYED` |
| S20 | Outpost arrival | Outpost road | — |
| S21 | South gate | Outpost | — |
| S22 | Reset breaker | Power station | `M01_POWER` |
| S23 | Dismount at Pad A | Bunker pad | — |
| S24 | Restore comms | Bunker interior | `M01_COMMS` |
| S25 | Investigate damage (3 clues) | Outpost | — |
| S26 | Tracks found / remount | Outpost | `M01_TRAIL` |
| S27 | Trail walk | Trail | — |
| S28 | Strider rises + fight | Kessler Basin | `M01_FIGHT` (on basin entry) |
| S30 | Victory | Basin | `M01_TITAN_DOWN` |
| S31 | The Watcher | Basin | — |
| S32 | The rover (on foot) | Basin | — |
| S33 | Upload + anomaly | Basin | `M01_COMPLETE` |
| S40 | Return: Vale and Rhein | Hangar (evening) | `CH1_RETURNED` |
| S41 | Medical: Voss | Medical Bay | `CH1_MEDICAL` |
| S42 | (Optional) Mara on the deck | Observation Deck | — |
| S43 | The message | Quarters Q-3 | `CH1_COMPLETE` |

---

## S01 — Cold open ⏱ (~20 s)

- Screen: black. Letterbox off. Title text fades in (Michroma, 28 px, `#E8ECEF`, letter-spacing via spaced characters):
  `2187` (1.5 s), then `NEW HALDEN — HALDEN CENTRAL COMMAND` (2.5 s), then fade out.
- Audio: radio broadcast through a lo-fi filter (EqualizerSoundEffect: High −12 dB) while the screen is still black.

```
S01_01 | PA | Good morning, Halden. Day four thousand one hundred and twelve without a breach of the Bulwark.
S01_02 | PA | Ash advisory for the eastern districts. Masks recommended after noon.
S01_03 | PA | And to the newest pilots of the Third: the whole city's proud of you. The Frame stands—
S01_04 | E  | —humanity stands. (radio click off)
```
- On S01_04: fade from black (1.2 s) to **Quarters room Q-3**. Elias stands at the desk facing his father's photo (spawn CFrame in `map_01` §Q-3). Control is enabled.
- **Objective set:** `OBJ_CH1_HANGAR` "Report to the Frame Hangar." Waypoint: Hangar entrance (0, 0, −72).

## S02 — Quarters (free roam, optional interactions)

All are ProximityPrompts (`Interactable` tag), HoldDuration 0, MaxActivationDistance 8.

| Prompt | Object | Lines (first use / repeat use) |
|---|---|---|
| "Look" | Father's photo (desk, Q-3) | `S02_PHOTO_1 [E-thought] Dad's last unit photo. Ninth Frontier Defense. He's the one not smiling.` / `S02_PHOTO_2 [E-thought] Six years. They never found anything.` |
| "Take" | Locker (Q-3) | `S02_LOCKER [E-thought] His old patch. For luck.` → set flag `CH1_TOOK_PATCH`. The patch part on the desk disappears (moves to "inventory"; cosmetic only). |
| "Look" | Window slit (Q-3) | `S02_WINDOW [E-thought] Ash on the glass again.` |
| "Talk" | **Tamsin Rook** (quarters hallway, leaning on the wall by Q-5) | Dialogue `DLG_CH1_TAMSIN` below |

```
DLG_CH1_TAMSIN
T_01 | T | Veyne! First deployment, right? Don't puke in the cockpit. They make you clean it.
T_02 | E | Is that an actual rule?
T_03 | T | It's an actual smell. Oh—and if you start feeling core-sick out there, keep it to yourself.
T_04 | E | Why?
T_05 | T | Two guys from my class reported it. Got "reassigned." Nobody's heard from them since.
T_06 | T | Probably just paperwork. Probably.
T_07 | E | ...Thanks, Rook.
T_08 | T | Good hunting, Ember-2.
```
→ flag `CH1_TALKED_TAMSIN` (clue 12). Repeat talk: `T_R1 | T | Go, go. Your squad lead's going to kill you.`

## S03 — Ops Hall (ambient, optional)

**PA loop** (a random line every 45 s while the player is in Central Command, until S07; never repeat consecutively):
```
PA_A1 | PA | Corridor Train Six departing Halden Central, platform one.
PA_A2 | PA | Reminder: hangar access requires active clearance.
PA_A3 | PA | Maintenance crew to Bay Three. Maintenance crew to Bay Three.
PA_A4 | PA | Ember Squad, report to the Frame Hangar for pre-deployment check.
```

**Ambient barks** (one-shot, play when the player passes within 18 studs; shown as small floating subtitles above the speaker via BillboardGui, max 1 at a time):
```
BARK_OPS_1 | OFFICER | Seven's still dark? That's six hours past window.
BARK_OPS_2 | OFFICER | Relay's probably iced. Happens every winter.
BARK_OPS_3 | OFFICER | It's March.
```
(Officers at consoles C3, C4, C7; positions in `map_01`.)

**Okafor** (console C1). Prompt "Talk", one time:
```
OK_01 | O | Morning, Ember-2. I'll be your voice out there today. Try to keep your radio on this time.
OK_02 | E | That was one time.
OK_03 | O | Twice. But who's counting? Me. I'm counting.
```

**Interactables:**
| Object | Line |
|---|---|
| Status wall (north wall display) | `S03_BOARD [E-thought] Outpost Seven: report overdue. Six hours.` (clue 1) |
| Recruitment poster (west wall) | `S03_POSTER [E-thought] "The Frame stands, humanity stands." Dad had this one in the kitchen.` |
| Holo-table | `S03_HOLO [E-thought] Forty-one kilometers to Seven. Feels further on the map.` |

## S04 — Hangar reveal ⏱ (6.5 s, first entry only)

- **Trigger:** `TRG_HANGAR_REVEAL`, a volume at the hangar's south entrance (X −15..15, Z −80..−70, Y 0..20). Fires once (flag `SEEN_HANGAR_REVEAL`).
- Controls locked, letterbox in (0.4 s).
- **Shot 1 (3.5 s):** camera from (0, 3, −150) looking at (0, 34, −205) [Unit 02's head]. Linear move to (0, 5, −165), same target. FOV 55→50.
- **Shot 2 (3.0 s):** cut to (−30, 26, −175) looking at (0, 30, −205). Slow pan to look at (0, 22, −205). FOV 60.
- End: `S04_01 [E-thought] ...Hey, Oh-Two.` (it's what he calls Unit 02)
- Letterbox out. Control returns. Objective unchanged; the waypoint moves to the **Safe Viewing Line** at (0, 0, −168).

## S05 — Mara at the viewing line

- **Mara** stands at (6, 0, −168) facing north toward Unit 02. When the player comes within 12 studs: soft lock (controls disabled, camera stays player-controlled but the character turns to face Mara). Dialogue UI opens. No letterbox: this is a conversational scene. Camera: if the player doesn't move it, auto-frame a two-shot (CinematicController "soft framing": camera at the midpoint plus 9 studs to the side, 2 studs up).

```
DLG_CH1_MARA_HANGAR
MH_01 | M | There he is. I was about to send a search party.
MH_02 | E | I took the long way.
MH_03 | M | You got lost.
MH_04 | E | I took the scenic way.
MH_05 | M | Through a building with no windows. Inspiring.
MH_06 | M | She looks good. Hollis repainted your shoulder stripe. Twice. Said your first coat was "emotionally upsetting."
MH_07 | E | It was fine.
MH_08 | M | It was crooked, Eli.
MH_09 | M | So. First real deployment. No simulator. No reset button.
MH_10 | M | You nervous?
  CHOICE C1 (no timer):
   [1] "Honestly? Yeah."                           → flag CH1_ADMITTED_NERVES → MH_11a
   [2] "Not as nervous as you'll be when I tie the score." → flag CH1_JOKED_SCORE → MH_11b
MH_11a | M | ...Good. Means you're paying attention.
MH_12a | M | Me too. A little. Tell anyone and I'll deny it.
MH_11b | M | Forty-one to thirty-nine, Veyne. Simulators. You'd need a real Titan to catch up.
MH_12b | E | Don't tempt me.
MH_13b | M | Don't tempt fate.
(both branches continue)
MH_14 | H | Ember-2! Your girl's fueled, calibrated, and if you scratch my new paint I'll weld you to the floor.
MH_15 | E | Good morning to you too, Chief.
MH_16 | H | And stay clear of Three today. She's moody.
MH_17 | M | Moody?
MH_18 | H | Core's running warm. Pulsing. Happens sometimes. Don't ask me why. I fix the parts that don't breathe.
MH_19 | PA | Ember Squad, report to Briefing Room One. Ember Squad to Briefing Room One.
MH_20 | M | That's us. Race you?
MH_21 | E | We're not allowed to run in the hangar.
MH_22 | M | Then walk faster.
```
- Hollis walks in from Bay 3 for MH_14 (MoveTo from (70, 0, −175) to (14, 0, −170)), then walks back after MH_18.
- After MH_22: objective `OBJ_CH1_BRIEFING` "Go to Briefing Room One." Waypoint: Briefing Room door (−80, 0, −20).
- **No relationship change** in C1. The flag changes lines in S42.

## S06 — Walk to briefing

- Mara becomes a **follower NPC**: she paths to the briefing room ahead of the player, using waypoint nodes (`map_01` §Navigation nodes). If the player is more than 30 studs behind, she waits facing them. If the player sprints, she matches speed (22).
- Walk banter (plays once, triggered when both pass through the Ops Hall):
```
WB_01 | M | Okafor's on our net today.
WB_02 | E | She's going to bring up the radio thing.
WB_03 | M | She's already brought up the radio thing. To me. Twice.
```
- **Trigger:** `TRG_BRIEFING_ENTER` (inside the briefing room door) starts S07 when the player enters (Mara teleports to her seat during the fade if she's behind).

## S07 — Briefing ⏱/branching (~70 s)

- Fade to black (0.3 s) → Elias and Mara seated on tier 2 (seat CFrames in `map_01` §Briefing) → fade in. Letterbox in. Vale stands at the lectern. The screen (SurfaceGui on the west wall) shows slides.
- **Shots:** `CAM_BRF_WIDE` (−92, 9, −20) → look (−125, 7, −20) [over the seats toward Vale and the screen], `CAM_BRF_VALE` (−112, 6.5, −16) → look (−122, 6, −20), `CAM_BRF_PILOTS` (−113, 6, −24) → look (−104, 5, −26).

| Line | Shot | Slide |
|---|---|---|
| `BR_01 V Ember Squad. Sit.` | WIDE | Division emblem |
| `BR_02 V At zero-zero-ten, Frontier Outpost Seven missed its scheduled report. Then its next three.` | VALE | "OUTPOST 07 — 4 REPORTS MISSED" |
| `BR_03 V Last contact was routine. Weather nominal. No Titan activity flagged.` | VALE | Last-report text block |
| `BR_04 V Most likely cause is relay failure. Garrison strength is twelve, under Lieutenant Ferris.` | WIDE | Map: Halden → Outpost 07, "41 KM EAST" |
| `BR_05 V Your orders: travel to Outpost Seven, assess, restore communications, and report.` | VALE | "ORDERS: ASSESS / RESTORE COMMS / REPORT" |
| `BR_06 M Expected resistance, sir?` | PILOTS | — |
| `BR_07 V Nearest recorded Titan is a Class-Two Strider, Kessler Basin. Stale data.` | VALE | Strider silhouette, "CLASS-2 (est.)" |
| `BR_08 V Anything above Class-Two, you report and you withdraw. Is that understood?` | VALE | — |
| `BR_09 M Understood, sir.` / `BR_10 E Understood.` | PILOTS | — |
| `BR_11 V Outpost Five at Lowmarch is your fallback if you lose contact with Halden.` | WIDE | Map adds "OUTPOST 05 — LOWMARCH" |

```
  CHOICE C2 (timer 12 s; timeout = option 3):
   [1] "Could it just be a broken relay?"           → BR_12a
   [2] "Lowmarch... my father's unit was there."      → flag CH1_ASKED_LOWMARCH → BR_12b, BR_13b
   [3] [Say nothing]                                → (skip)
BR_12a | V | That's what I'm hoping you'll tell me.
BR_12b | V | (1.2 s pause) Lowmarch was a bad week.
BR_13b | V | Focus on today, Pilot.
BR_14 | V | Overwatch runs your comms. Corporal Okafor has the net.
BR_15 | V | First deployments are where good pilots learn to be careful. Be careful.
BR_16 | V | Dismissed.
```
- Fade out → players standing at the briefing room door → fade in, control returns.
```
BR_17 | M | "Be careful." That's practically a hug, for him.
```
- **Checkpoint `CH1_BRIEFED`.** Objective `OBJ_CH1_BOARD` "Board your Frame (Bay 2)." Waypoint: Bay 2 access bridge end (−4, 28, −198). Mara walks to Bay 1 and boards (she fades out at the Bay 1 bridge; Unit 01's chest lights turn on).

## S08 — Boarding and Frame tutorial

- At the bridge end, a ProximityPrompt on the cockpit hatch: "Board Frame" (HoldDuration 1.0).
- **First boarding only** (2.2 s mini-cinematic): close-up of Elias's hand tapping the hatch twice (procedural arm pose `TapHatch`), the hatch opens upward, fade.
```
BD_01 | [M] | Did you do the tap thing?
BD_02 | [E] | ...No.
BD_03 | [M] | You did the tap thing.
```
- **Cockpit boot overlay** (2.5 s, amber RobotoMono typed text, center screen):
  `VANGUARD // UNIT 02` → `CORE SYNC ........ 98.2%` → `INHIBITOR LATTICE . NOMINAL` → `PILOT: VEYNE, E.` → `ONLINE`
  ("INHIBITOR LATTICE" is a subtle early clue; nobody comments on it.)
- Frame HUD appears with **"WEAPONS LOCKED — HANGAR SAFETY"** banner (amber, top center).
```
BD_04 | [O] | Ember Squad, Halden Overwatch. You're cleared to proceed to Launch One.
```
- **Tutorial card** `TUT_MOVE`: "MOVE — WASD / Left Stick / Thumbstick. Your Frame is heavy: it takes time to speed up and turn. Hold SHIFT / L3 for Stride."
- Objective `OBJ_CH1_DOOR` "Walk to the deployment door." Waypoint (100, 0, −150).
- Mara's Unit 01 (ally AI) exits Bay 1 and walks to the door ahead of the player.

## S09 — Deployment door reveal ⏱ (9 s)

- **Trigger:** the player's Frame enters `TRG_DEPLOY_DOOR` (X 70..118, Z −190..−110).
- Sirens, beacons spin (client), the door segments rise over 4.0 s (server tween; door spec in `map_02`).
- **Shot 1 (4.0 s):** exterior camera (260, 40, −150) looking at (120, 35, −150): the door rising, light spilling out, Units 01 and 02 silhouetted inside.
- **Shot 2 (5.0 s):** behind Unit 02, from (60, 46, −150) looking east at (600, 40, −150): the launch platform, causeway, the Bulwark, and the wilderness beyond with distant ruins in haze. A slow push forward of 20 studs.
```
DR_01 | [M] | Never gets old.
DR_02 | [E] | We've done this once.
DR_03 | [M] | And it never got old.
```
- Control returns. Objective `OBJ_CH1_LAUNCH` "Step onto the launch platform." Waypoint (160, 0, −150).

## S10 — Launch ⏱ (8 s)

- **Trigger:** the player's Frame is within 20 studs (XZ) of (160, 0, −150).
```
LA_01 | [O] | Ember-1, Ember-2, Launch One is yours. Corridor gate opening. Good hunting.
```
- Both Frames auto-walk east along the causeway (scripted MoveTo toward (440, 0, −150)). The Bulwark Frame Gate opens (6 s rise). Camera: crane shot starting at (180, 20, −100) looking at Unit 02, rising to (200, 110, −60) looking at (440, 40, −150). Fade to black at 7 s.
- **Transit card** (3.0 s): `TRANSIT — 41 KM EAST` / `FRONTIER OUTPOST 07 "GREYWATCH"` (typewriter, RobotoMono).
- Lighting → **Overcast** preset. Server teleports both Frames to the Outpost start: Unit 02 at local (10, 0, 560), Unit 01 at local (−14, 0, 566), both facing north.
- **Checkpoint `CH1_DEPLOYED`.** Mission `M01_SILENT_OUTPOST` starts.

---

## S20 — Outpost arrival

- Fade in (1.0 s). Both Frames auto-walk north 2.0 s, then control returns. HUD banner: **"WEAPONS UNLOCKED"** (green-amber flash, 1.5 s).
```
AR_01 | [M] | Ember-1 to Overwatch. We're on the Seven approach. Visibility's poor.
AR_02 | [O] | Overwatch copies. Still no signal from the outpost on any band.
AR_03 | [E] | Road's empty. No patrol. No lights.
AR_04 | [M] | Stay on my left, Eli. Weapons free past the wall.
```
- Objective `OBJ_M01_REACH` "Reach Outpost 07." Waypoint: South Gate (local 0, 0, 200).
- Passing the overturned truck (local Z < 270), once:
```
AR_05 | [E] | That truck's been here a while. Rust on the bolts.
AR_06 | [M] | Old damage. Keep moving.
```

## S21 — South gate

- **Trigger:** `TRG_OP_SOUTHGATE` (local Z < 215, |X| < 40).
```
SG_01 | [M] | Gate's open. Not broken—open.
SG_02 | [E] | Somebody left in a hurry.
SG_03 | [O] | Ember Squad, the outpost grid reads dead from here. Breaker yard is northwest.
```
- Objective `OBJ_M01_POWER` "Restore power: reset the breaker at the power station." Waypoint: the breaker lever (local −92, 0, −115).
- Mara AI walks to the courtyard near the flagpole and idles in a "scanning" pose (head sweeps).

## S22 — Reset the breaker

- A Frame-scale ProximityPrompt on the breaker housing: "Reset Breaker" (HoldDuration 2.0, MaxActivationDistance 30, `RequiresLineOfSight` false). It **only appears while piloting**.
- On trigger: the lever arm rotates 90° down over 1.0 s, a spark burst (2 emitters, 0.6 s), outpost lights flicker 3× then stay on (all `OutpostLight` tagged lights enabled), a hum loop starts (SoundRegistry `AMB_POWER_HUM`).
```
PW_01 | [O] | Power's up. I see the bunker's array... but it isn't transmitting.
PW_02 | [M] | Array's on the bunker roof. Someone has to go in and reroute by hand.
PW_03 | [E] | I'll go.
PW_04 | [M] | Pad's south of the bunker. I'll cover you.
```
- **Checkpoint `M01_POWER`.** Objective `OBJ_M01_DISMOUNT` "Dismount at the bunker landing pad." Waypoint: Pad A (local 0, 0, 30).
- Tutorial card `TUT_DISMOUNT`: "DISMOUNT — Stand on a landing pad and use the prompt. You can only leave your Frame on pads."

## S23 — Dismount at Pad A

- With the Frame inside the pad circle (radius 14), a prompt appears: "Dismount" (HoldDuration 0.8).
- Transition (`08_rigs` §5.4): the Frame kneels (1.0 s), fade out 0.35 s, Elias appears standing at the Frame's right hand (pad-defined `ExitPoint`), fade in 0.35 s. The Frame stays kneeling with a "Board Frame" prompt on its right hand.
- Objective `OBJ_M01_COMMS` "Restore communications (bunker console)." Waypoint: console (local 0, 0, −40).

## S24 — Restore comms (on foot)

- Bunker interior (layout in `map_03`). Emergency lighting is red until power returns; it's on now, at reduced brightness with 1 flickering fixture.
- Console prompt "Reroute Signal" (HoldDuration 3.0). While holding, the console screen text scrolls.
```
CM_01 | [O] | —alden Overwatch, do you read? Ember Squad, signal's clean! Good work, Ember-2.
CM_02 | [E] | Overwatch, the bunker's empty. No garrison. Bunks unmade. Food still on the tables.
CM_03 | [O] | Copy. Command wants a damage assessment before anything else. Have a look around.
CM_04 | [M] | Eli. Some of this damage doesn't make sense. Check the cable run outside the east wall.
```
- **Checkpoint `M01_COMMS`.** Objective `OBJ_M01_INVESTIGATE` "Investigate the damage (0/3)." Three waypoints shown at once.
- **Evidence `EV_OP07_LOG1`** is on the ops-room terminal next to the comm console (optional; §9).

## S25 — Investigate the damage (any order, on foot)

Each clue is an `Interactable` with prompt "Investigate" (HoldDuration 1.5) and a highlight (Highlight instance, `#E8A33D` outline, only while the objective is active).

| Clue | Location (local) | Lines |
|---|---|---|
| **A — Cut cable** | (45, 0, −30), bunker east wall | `IN_A1 E Main comm cable. Cut, not crushed. Clean edges.` / `IN_A2 [M] Titans don't cut.` / `IN_A3 E No. They don't.` |
| **B — Fuel depot** | (−135, 0, −15), maintenance yard | `IN_B1 E Fuel depot's untouched. Titans go for heat sources first. Every textbook says so.` / `IN_B2 [M] So this one didn't read the textbook.` |
| **C — Footprints** | (60, 0, 60), beside the mess hall (R3) | `IN_C1 E Footprints. Big. Bigger than a Class-Two.` / `IN_C2 E It stepped over the mess hall. Over it. Like it didn't want to break anything.` / `IN_C3 [M] ...I don't like that, Eli.` |

The objective counter updates (1/3, 2/3). After the third:
```
IN_D1 | [O] | Overwatch copies all of that. Command's... going to want to hear this directly.
IN_D2 | [M] | Ember-2, I've got tracks. Same prints, heading north out the far gate. Fresh.
IN_D3 | [O] | Command authorizes: follow the trail and observe. Do not engage anything above Class-Two.
```
- Objective `OBJ_M01_REMOUNT` "Return to your Frame." Waypoint: Unit 02.

## S26 — Remount

- "Board Frame" prompt on the kneeling Frame's hand (HoldDuration 0.8) → fade transition → piloting.
- **Checkpoint `M01_TRAIL`.** Objective `OBJ_M01_TRAIL` "Follow the trail north." Waypoints follow the footprint trail (North Gate → basin entry).
- Mara AI joins in follow mode.

## S27 — Trail walk (auto banter at trigger lines)

| Trigger (local Z) | Lines |
|---|---|
| Z < −200 | `TW_01 [M] Remember the Corrow rooftop? Counting convoys?` / `TW_02 [E] You always said the fifth one was carrying candy.` / `TW_03 [M] One time. One time I was right.` |
| Z < −300 | `TW_04 [E] Mara. If the garrison walked out... where'd they go?` / `TW_05 [M] Five's closest. Lowmarch.` / `TW_06 [E] ...Yeah.` |
| Z < −370 | `TW_07 [O] Ember Squad, you're approaching Kessler Basin. Old reservoir. Visibility's going to drop.` |

## S28 — The Strider rises ⏱ (8.5 s) and the fight

- **Trigger:** `TRG_BASIN_ENTRY` (local Z < −420). **Checkpoint `M01_FIGHT`** is saved *before* the cinematic.
- The Strider is pre-placed in its **Dormant** pose (crouched, hands on the ground) at local (−60, −12, −580), **facing north, with its back to the player's approach**. During Shot 3 it turns its head, then its whole body (AlignOrientation, 70°/s), to face Unit 02.
- **Shot 1 (3.0 s):** low ground camera (−20, −10, −505) looking at the Strider's back (−60, 0, −580); dust drifts.
- **Shot 2 (2.5 s):** it rises to standing (procedural `Rise` animation, 2.5 s). Camera (−60, 10, −470) looking up at its head (−60, 44, −580).
- **Shot 3 (3.0 s):** its head turns **toward Unit 02** specifically; the eye glow flares orange (0.4 s bloom pulse) (clue 6). Roar: camera shake (magnitude 0.6, 1.2 s) and a dust ring.
```
ST_01 | [M] | Contact! That's—that's no Class-Two!
ST_02 | [O] | Ember Squad, readings put it at Class-Three. You're authorized to withdraw—
ST_03 | [M] | It's sitting on the trail. We take it here. Eli, ankles first—bring it down!
```
- Titan health bar appears: **"STRIDER-CLASS — UNREGISTERED"** (Class-3). The fight starts (`10_titans.md`, `12_combat_system.md`).
- **The first Sweep uses a 1.8 s windup** (tutorial), then normal values.

**Tutorial hints** (TutorialController; each shows once, 5 s, top-center card, never during a telegraph except T_DODGE):
| ID | Condition | Text |
|---|---|---|
| `TUT_LOCK` | fight start | "LOCK ON — R / R3 / LOCK. Cycle targets with C / D-pad ← → / tap LOCK again." |
| `TUT_DODGE` | first Sweep telegraph starts | "DODGE — SPACE / B / DODGE. You're invulnerable at the start of a dodge." |
| `TUT_ATTACK` | 5 s after start | "ATTACK — LMB light combo, RMB heavy. Hit the ANKLES to break its balance." |
| `TUT_SPECIAL` | energy ≥ 50 and Titan poise ≤ 60% | "PILE DRIVER — Q / LB / SPECIAL. Breaks balance fast. Costs 50 energy." |
| `TUT_CORE` | first Downed state | "IT'S DOWN — the Dorsal Core is exposed! CORE STRIKE — F / Y / CORE." |
| `TUT_REGEN` | Titan regenerated ≥ 100 HP since its last damage | "It REGENERATES. Keep the pressure on, and break it to finish it." |

**Fight barks** (BarkController; 12 s global cooldown, each line max 2× per fight):
```
FB_M1 | [M] | I'm drawing its attention!
FB_M2 | [M] | Hit the legs!
FB_M3 | [M] | Watch the stomp!
FB_M4 | [M] | Eli, your armor's smoking!        (player Integrity < 34%)
FB_M5 | [M] | Core's open! Now!                 (on Downed)
FB_M6 | [M] | It's healing! Don't let up!       (with TUT_REGEN)
FB_E1 | [E] | Come on, come on...
FB_E2 | [E] | Got it!                           (Core Strike connects)
FB_O1 | [O] | Its readings are spiking!         (Roar at ≤50% HP)
FB_M7 | [M] | Then we finish it fast.           (right after FB_O1)
```
- **If the Vanguard's Integrity hits 0:** "FRAME DISABLED" (`14_ui.md`), then `FAIL_M1 [M] Eli! Come on—get up, get up!`, fade, and reload checkpoint `M01_FIGHT` (Frame repaired, Strider reset, the S28 cinematic is skipped on retry and the fight starts with the Strider already standing).

## S30 — Victory

- The killing blow must be a Core Strike, or any hit while HP ≤ 0 during Downed. The camera does a 0.5 s client-side "impact frame" (FOV punch 75→68→75), then the Strider's **Ash Collapse** (12 s, `10_titans.md` §8).
```
VI_01 | [M] | ...Is it—
VI_02 | [E] | It's ashing.
VI_03 | [M] | Good. Good. Ember-1 to Overwatch. Target down.
VI_04 | [O] | Overwatch copies. Nice work, both of you. Secure the area.
```
- **Checkpoint `M01_TITAN_DOWN`.** Objective `OBJ_M01_REGROUP` "Regroup with Ember-1." Mara's Unit 01 walks to local (40, −12, −520) and waits.

## S31 — The Watcher ⏱/branching (~45 s)

- **Trigger:** the player's Frame comes within 40 studs of Unit 01 (or 25 s pass after VI_04).
- Letterbox in. The Watcher spawns at local (290, 30, −560) on the east ridge, in fog, facing west.

| Beat | Camera | Action / line |
|---|---|---|
| 1 | Over Unit 01's shoulder toward the ridge: cam (20, 30, −505) → look (290, 50, −560) | `WA_01 [M] Eli. Ridge. Two o'clock.` |
| 2 | Telephoto on the Watcher: cam (120, 20, −540) → look (290, 62, −560), FOV 30 | Cyan glow lines pulse slowly. `WA_02 [E] That's... bigger.` `WA_03 [M] Why isn't it moving?` |
| 3 | Same | The Watcher tilts its head (procedural `HeadTiltStudy`, 2 s). `WA_04 [O] Ember Squad, I have a second contact. It's—it's not on any registry.` |
| 4 | Wide: cam (60, 25, −640) → track the Watcher | The Watcher walks down the ridge to the rover at local (150, −12, −600) in long careful steps (12 s, path nodes in `map_03`). `WA_05 [V] Ember Squad, Vale. Status.` `WA_06 [M] Second Titan. Class-Three, maybe Four. It's not attacking, sir.` |
| 5 | Close: cam (110, 0, −570) → look (150, 5, −600) | The Watcher kneels, peels the rover's roof back (the roof part rotates open on a hinge, 1.5 s), lifts out a small frosted canister in its fingers (canister welded to its RightHand; frost particles). |
| 6 | Reverse: from behind the Watcher toward Unit 02 | The Watcher looks **directly at Unit 02** for 1.5 s. The player's HUD shows static for 0.2 s (client effect). No cyan on the player's Frame yet. |
| 7 | Over Unit 02 | `WA_07 [V] Ember Squad, pursue and maintain contact.` `WA_08 [M] Sir, we're banged up. Two damaged Frames against a Class-Three-plus—` |

```
  CHOICE C3 (timer 10 s; timeout = option 3):
   [1] "She's right, sir. We're in no shape."  → mara +1, vale −1, flag CH1_SIDED_MARA → WA_09a, WA_10a
   [2] "We can handle it, Mara."               → mara −1, vale +1, flag CH1_SIDED_VALE → WA_09b, WA_10b
   [3] [Say nothing]                           → flag CH1_SILENT_PURSUIT → WA_09c
WA_09a | [V] | ...Noted, Ember-2.
WA_10a | [M] | (quietly) Thanks.
WA_09b | [M] | Eli—
WA_10b | [V] | Noted.
WA_09c | [M] | Eli? ...Fine.
WA_11 | [V] | Negative on pursuit, then. Hold position. Observe and record. Do not engage.
```
- Toast after C3 option 1: "Mara will remember that." Option 2: "Mara will remember that." (same text, deliberately).
- Beat 8 (8 s): the Watcher rises and walks east up the ridge into the fog; it's removed when its local X > 450.
```
WA_12 | [O] | Contact's off my scope. It just... went.
WA_13 | [M] | Titans don't take things, Eli. They don't take things.
WA_14 | [V] | Ember Squad. Investigate that vehicle. I want to know what it was carrying.
```
- Letterbox out. Objective `OBJ_M01_ROVER` "Investigate the research vehicle." Waypoint: Pad B (local 120, −12, −600).

## S32 — The rover (on foot)

- Dismount at **Pad B** (same flow as Pad A). The rover is on its side with the roof peeled open; Elias can walk into the cargo bay through the open roof gap (ramp of debris).

| Interactable | Prompt | Lines | Effect |
|---|---|---|---|
| Rover door marking (ECHO 3-ring symbol, "SR-12") | Inspect | `RV_01 E Science Division markings. Three rings. Never seen that symbol before.` | flag `CH1_SAW_ECHO` (clue 9) |
| Empty cryo cradle (cargo bay) | Inspect | `RV_02 E Cryo cradle. Empty. Label says... "Subject T-V. ECHO-9."` / `RV_03 [M] Subject? Subject of what?` / `RV_04 E Doesn't say.` | flag `CH1_SAW_CRADLE` (clue 8) |
| Sealed case (cargo bay) **required** | Open (HoldDuration 2.0) | (on open) `RV_05 E Huh. Lock just... let go.` / `RV_06 [M] What is it?` / `RV_07 E Data spindle. Classified seals all over it.` / `RV_08 [V] Pilot, bring it to your Frame. Standard protocol: upload a copy to Overwatch.` | The case lock light changes red → **cyan for 0.6 s** → off (clue 10, subtle). Flag `CH1_HAS_SPINDLE`. |

- Objective `OBJ_M01_UPLOAD` "Return to your Frame and upload the data."

## S33 — Upload and the anomaly ⏱ (~28 s, client cinematic)

- Board Frame → cockpit HUD → an automatic upload overlay: `UPLOADING SPINDLE // 12%` (0.8 s) → `37%` (0.8 s) → `61%`.
- At 61%: **resonance ping** (bass thump sound + screen ripple: a full-screen Frame with UIGradient sweeping outward, 0.5 s).
- HUD glitch phase (5 s): HUD elements jitter (random ±4 px offsets each 0.05 s); the core indicator color tweens amber → **cyan `#7FE3F0`**; the system panel prints lines (RobotoMono, 0.25 s apart):
  ```
  CORE RESPONSE ............ ANOMALOUS
  CORE TISSUE ACTIVITY ..... 412%
  MITOTIC RATE ............. ACTIVE
  NEURAL LOAD .............. 340%
  RESONANCE ................ [ERROR: NO SUCH FIELD]
  INHIBITOR LATTICE ........ FAILING
  ```
- **External shot (3.5 s):** cam (−20, 20, −540) relative to the Frame's position → look at the Frame's head: the chest vents glow cyan, **and the Frame's head turns slowly east on its own** (toward where the Watcher went) (procedural override 45° over 2.5 s).
- **Shutdown (1.5 s):** HUD collapses (all elements scale Y → 0 over 0.3 s), black, a single amber line `CORE OFFLINE`, then black.
- **Sensory event (8 s):** white-cyan fade (full-screen Frame `#DFF8FB`, 0 → 0.1 transparency over 1 s). Audio muffled (SoundService low-pass). The camera cuts to the **MemorySet** (`map_00` §4): a pale void with a soft floor; two dark silhouettes, a man and a small child (R15 rigs colored `#2A2D31`, the child at scale 0.6), walking away hand in hand along a faint line of street lamps. Slow dolly.
  ```
  VOICE_01 | VOICE | Eli... count the steps.
  VOICE_02 | VOICE | All the way home.
  ```
  (VOICE lines: italic, cyan `#7FE3F0`, centered, no speaker name.)
- Hard cut to black (no sound) 1.0 s, then:
  ```
  AN_01 | [M] | Eli! Eli, answer me! Overwatch, his Frame's gone dark—
  ```
- Black 2.0 s. **Checkpoint `M01_COMPLETE`.** Server: mission complete, rewards queued (shown in S40). Lighting → **Evening**. Teleport to the hub.

---

## S40 — Return: Vale and Rhein (hangar, evening)

- Fade in. Elias stands on the hangar floor at (0, 0, −172) facing north. Unit 02 is in Bay 2, chest vents **dark** (no glow). Mara's Unit 01 is in Bay 1. Three Science Division guards (black-grey `#24282E` uniforms, helmets made of parts, ECHO pins) stand near Bay 2.
- Vale approaches from the south with **Rhein** beside him. A technician holds the spindle case.
- Letterbox in (conversational cinematic; shots auto-framed between speakers).
```
RT_01 | V  | Pilot Veyne. You're on your feet. Good.
RT_02 | E  | Sir, the spindle—my Frame, it—
RT_03 | V  | Is being handled.
RT_04 | R  | (takes the case from the technician) Pilot Veyne. That was good work today. Really.
RT_05 | R  | Get some rest. Let us worry about the rest.
RT_06 | E  | ...Sir.
```
- Rhein and the guards walk away toward the hangar's south exit (they despawn in the gate corridor). The camera holds on Rhein's **collar pin** (3 rings) for 1.0 s as he turns (clue 9).
```
RT_07 | V | Medical. Now. That's an order, not a suggestion.
RT_08 | E | Sir—the garrison. Lieutenant Ferris's people.
RT_09 | V | Arrived at Outpost Five on foot this afternoon. All twelve. They've been transferred to Science Division for debrief.
RT_10 | E | Science Division? Why not—
RT_11 | V | Medical, Pilot.
```
- Letterbox out. **Mission Complete card** (`14_ui.md` §9): "MISSION COMPLETE — SILENT OUTPOST", with rewards (§10).
- **Checkpoint `CH1_RETURNED`.** Objective `OBJ_CH1_MEDICAL` "Report to Medical." Waypoint: Medical Bay scanner arch (115, 0, 20).
- PA loop switches to evening lines:
```
PA_E1 | PA | Corridor Train Nine arriving, platform one.
PA_E2 | PA | Evening ash advisory lifted for the eastern districts.
PA_E3 | PA | Night shift, report to stations.
```

## S41 — Medical: Voss

- Voss stands at the scanner console (118, 0, 14). The player steps into the arch trigger (115, 0, 20) → soft lock, conversational camera.
- The scanner beam (a thin Neon ring part, `#DDE9F2`) sweeps down over Elias (2.0 s), twice.
```
MD_01 | VS | Pilot Veyne. Stand there—inside the arch. Thank you.
MD_02 | VS | Any nausea? Ringing in the ears? Metallic taste?
MD_03 | E  | A little ringing.
MD_04 | VS | Mm.
MD_05 | VS | Your Frame's core logged a response at the moment it shut down. It's... outside its operating parameters.
MD_06 | E  | Outside by how much?
MD_07 | VS | Enough that I've been asked not to discuss it.
MD_08 | VS | Pilot. When the interface went down, did you notice anything unusual? Sounds. Sensations. Anything.
  CHOICE C4 (no timer):
   [1] "I heard a voice. Someone I knew, I think." → voss +1, flag CH1_TOLD_VOSS → MD_09a..MD_13a
   [2] "Just a headache."                          → flag CH1_HID_VOICE → MD_09b..MD_10b
MD_09a | VS | (stops writing) ...Whose voice?
MD_10a | E  | I don't know. It told me to count the steps.
MD_11a | VS | I'm going to write "mild auditory disturbance."
MD_12a | VS | And I'm going to remember what you actually said.
MD_09b | VS | (studies him for a second) Of course.
MD_10b | VS | If the headache ever starts talking, Pilot... come find me. Not the duty doctor. Me.
MD_14 | VS | You're cleared. Get some sleep. Real sleep.
```
- Toast on option 1: "Dr. Voss will remember that."
- **Checkpoint `CH1_MEDICAL`.** Objective `OBJ_CH1_REST` "Get some rest (Pilot Quarters)." Optional objective `OBJ_CH1_DECK_OPT` "Optional: Mara is on the Observation Deck."
- Mara NPC is now at the Observation Deck's east railing (126, 20, −10) facing east.

## S42 — (Optional) Mara on the Observation Deck

- Evening/night: city lights, the Bulwark lit with amber lamps. Approach within 10 studs → conversational scene.
```
OD_01 | M | Hey.
OD_02 | E | Hey.
OD_03 | M | They wouldn't let me see you. Two hours. I counted.
  [if CH1_ADMITTED_NERVES] OD_04a | M | You said you were nervous this morning. I thought you meant the fight.
  [if CH1_JOKED_SCORE]     OD_04b | M | So you got your real Titan. Forty-one to forty, by the way. I'm counting it.
OD_05 | M | Your Frame went dark, Eli. Completely dark. I thought—
OD_06 | M | Never mind what I thought.
  [if CH1_SIDED_MARA]      OD_07a | M | And... thanks. For backing me up. Vale's going to make you pay for that.
                           OD_08a | E | Worth it.
  [if CH1_SIDED_VALE]      OD_07b | M | And next time I say we're in no shape to chase a Class-Four, maybe don't tell Vale we can handle it.
                           OD_08b | E | I was trying to—
                           OD_09b | M | I know what you were trying to do. That's the problem.
  [if CH1_SILENT_PURSUIT]  OD_07c | M | You went quiet out there. When Vale asked. You never go quiet.
OD_10 | M | That thing took something from the truck. Titans don't take things.
OD_11 | E | I know.
OD_12 | M | Get some sleep, Veyne. That's an order from your squad lead.
OD_13 | E | You're not my—
OD_14 | M | Ember-ONE.
```
- Mara walks off the deck (despawns in the stairwell). Flag `CH1_DECK_SCENE`.

## S43 — The message ⏱

- In Q-3, the desk terminal screen blinks amber: `1 NEW MESSAGE`. Prompt "Read".
- Full-screen terminal UI (RobotoMono, amber `#E8A33D` on `#0B0E10`, scanlines made from a repeating UIGradient), typed at 45 chars/s:
```
MESSAGE RECEIVED  23:47
FROM:  —
ATTACHMENT: spindle_frag_0071.dat (PARTIAL)
------------------------------------------------
[ IMAGE DATA CORRUPTED ]
SUBJECT T-V // ECHO-9 // TRANSFER LOG
DATE: 2181-10-14   ORIGIN: KESSLER BASIN
------------------------------------------------

Your father did not die where they told you he died.
```
- The last line types at 15 chars/s, in white `#E8ECEF`. Hold 3.0 s. The terminal flickers twice.
- Camera (letterboxed): slow push from behind Elias over his shoulder to the father's photo (4 s). No dialogue. Fade to black (2 s).
- **Chapter end card** (`14_ui.md` §9): `CHAPTER ONE` / `THE LAST QUIET MORNING` / `Evidence found: N/3` / `To be continued in Chapter Two: CLASSIFIED`. Then "Continue" → free roam in the hub with **Night** lighting, the Training Yard unlocked, and `CH1_COMPLETE` saved.

---

## 9. Evidence texts (optional collectibles)

Each opens the **Log Reader** UI (`14_ui.md` §7) and adds an entry to the Mission Log → Evidence tab. +50 XP each on first read.

**EV_OP07_LOG1**: Bunker ops-room terminal (local −20, 0, −45). Prompt "Read Log".
```
OUTPOST 07 — COMMAND LOG — LT. H. FERRIS

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
Taking everyone to Five on foot. If you're reading this: it's not like the others.
```

**EV_OP07_LOG2**: Datapad on a table in the Mess Hall, R3 (local 92, 0, 60). Prompt "Read Datapad".
```
PVT. D. OKOYE — PERSONAL

Day 212 at Greywatch. Ferris says I'm the best spotter in the Seventh.
I'm the ONLY spotter in the Seventh.

Today the basin Strider went after a truck. Not ours. Grey, no unit markings,
three rings painted on the door. Science, I think. The truck ran. The Strider caught it.

Nobody got out. Nobody came for it either. Ferris called it in and Halden said
"acknowledged" and nothing else.

Why would Science be out past the posts without an escort?
```

**EV_OP07_LOG3**: A note taped to the searchlight, top of the Observation Tower (local 150, 50, −120). Prompt "Read Note".
```
TOWER WATCH — 03-15 — 23:30 — CPL. R. MBEKI

Second contact, east ridge, moving in. Very tall. Lanky.
Light on its back—not orange like the basin one. BLUE. Blue-white.
It's not looking for food. It keeps stopping. Like it's listening.

They told us the color of a Titan's glow is just chemistry.
Then why have I never seen this chemistry before?
```

## 10. Rewards (granted by the server at `M01_COMPLETE`, shown in S40)

| Source | XP | Credits |
|---|---|---|
| Mission complete | 500 | 300 |
| Strider defeated | 300 | 100 |
| Each evidence log (first read) | 50 | 0 |
| No Frame Disabled during the fight | 100 ("Clean Kill") | 50 |

## 11. Checkpoints → respawn state

| Checkpoint | On load: location / state |
|---|---|
| (none) | S01 cold open |
| `CH1_BRIEFED` | Briefing room door, on foot, objective `OBJ_CH1_BOARD`, morning |
| `CH1_DEPLOYED` | Outpost start, piloting, S20 starts (no cinematic replay; lines AR_01..04 replay) |
| `M01_POWER` | In the Frame next to the breaker, objective `OBJ_M01_DISMOUNT` |
| `M01_COMMS` | On foot inside the bunker, objective `OBJ_M01_INVESTIGATE`; already-found clues persist via flags `CH1_CLUE_A/B/C` |
| `M01_TRAIL` | In the Frame at the North Gate, objective `OBJ_M01_TRAIL` |
| `M01_FIGHT` | In the Frame at local (0, −12, −445) (`FRAME_OP_FIGHT`), Strider standing, fight starts |
| `M01_TITAN_DOWN` | In the Frame at local (20, −12, −520), S31 triggers in 2 s |
| `M01_COMPLETE` / `CH1_RETURNED` | S40 replays (it's short) |
| `CH1_MEDICAL` | Medical Bay door, objective `OBJ_CH1_REST` |
| `CH1_COMPLETE` | Pilot Quarters hallway, night, free roam |

## 12. All Chapter 1 flags

`SEEN_HANGAR_REVEAL, CH1_TOOK_PATCH, CH1_TALKED_TAMSIN, CH1_ADMITTED_NERVES, CH1_JOKED_SCORE, CH1_ASKED_LOWMARCH, CH1_CLUE_A, CH1_CLUE_B, CH1_CLUE_C, CH1_SIDED_MARA, CH1_SIDED_VALE, CH1_SILENT_PURSUIT, CH1_SAW_ECHO, CH1_SAW_CRADLE, CH1_HAS_SPINDLE, CH1_TOLD_VOSS, CH1_HID_VOICE, CH1_DECK_SCENE, CH1_CLEAN_KILL`

## 13. All Chapter 1 objectives (ID → text)

```
OBJ_CH1_HANGAR      Report to the Frame Hangar.
OBJ_CH1_BRIEFING    Go to Briefing Room One.
OBJ_CH1_BOARD       Board your Frame (Bay 2).
OBJ_CH1_DOOR        Walk to the deployment door.
OBJ_CH1_LAUNCH      Step onto the launch platform.
OBJ_M01_REACH       Reach Outpost 07.
OBJ_M01_POWER       Restore power: reset the breaker at the power station.
OBJ_M01_DISMOUNT    Dismount at the bunker landing pad.
OBJ_M01_COMMS       Restore communications (bunker console).
OBJ_M01_INVESTIGATE Investigate the damage ({n}/3).
OBJ_M01_REMOUNT     Return to your Frame.
OBJ_M01_TRAIL       Follow the trail north.
OBJ_M01_FIGHT       Defeat the Titan.
OBJ_M01_REGROUP     Regroup with Ember-1.
OBJ_M01_ROVER       Investigate the research vehicle.
OBJ_M01_UPLOAD      Return to your Frame and upload the data.
OBJ_CH1_MEDICAL     Report to Medical.
OBJ_CH1_REST        Get some rest (Pilot Quarters).
OBJ_CH1_DECK_OPT    Optional: Mara is on the Observation Deck.
```
(`OBJ_M01_FIGHT` is set when ST_03 finishes.)
