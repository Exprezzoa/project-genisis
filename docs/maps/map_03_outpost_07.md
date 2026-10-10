# MAP 03 — Frontier Outpost 07 "Greywatch", the Trail, Kessler Basin, East Ridge

**Purpose:** the first mission. It must show that **the place functioned normally until very recently**, then reveal a disturbance that doesn't fit Titan behavior. It needs multiple routes in the fight area, a compact size (no long empty stretches), and strong landmarks (comm mast, observation tower, intake tower, ridge).

**Coordinates are LOCAL to the Outpost origin O = (6000, 0, 0).** Builders add O. **Folder:** `Workspace.Map.Outpost07.<Area>`. **Budget:** 12,000 parts (road 1,000 · perimeter 1,200 · bunker 1,200 · power 700 · yard 900 · residential 1,800 · tower 500 · trail 1,000 · basin 2,500 · ridge and rover 1,000 · misc 200). **Lighting preset:** OVERCAST.

---

## 1. Layout (local, top-down)

```
                                   N (−Z)
        ┌──────────────────── CLIFFS Z −740…−724 (to Y 40) ─────────────────────┐
  DAM   │                 KESSLER BASIN   floor Y −12                            │ RIDGE slope X 182→260 (Y −12→30)
 X −200 │  RF4(−30,−680)     pylon (fallen)        RF3(110,−690)                  │ plateau X 260…340 (Y 30)
  …−186 │        intake tower (−95,−600)   ★Strider (−60,−580)    rover ▣(150,−600)│  W0 Watcher (290,30,−560)
 Y −12  │  boat wreck(−130,−650)            Pad B (120,−600)                     │
  →18   │  RF1(−140,−480)                 RF2(70,−470)                           │
        └──────────── embankment Z −424…−400 · RAMP X −30…30 (Z −390→−438) ──────┘
                                       │ TRAIL (winding) TR0…TR5
   ┌───────────────────────────────────┴ NORTH GATE (X −20…20, Z −160) ───────────────────────────┐
   │ POWER STATION  X −170…−90, Z −150…−80     BUNKER X −40…40, Z −60…0    OBS. TOWER (150,−120)  │
   │   breaker ◧ (−92,−115)                    comm mast (0,−30) 70 tall                           │
   │ FUEL DEPOT X −150…−120, Z −30…0  ⦿B       ⦿A cut cable (45,−30)       R2 Barracks B           │ EAST BREACH
   │ GARAGE X −170…−110, Z 20…80               PAD A ◯ (0,30)              X 125…170, Z 10…70      │ Z 40…80
   │                                           COURTYARD X −60…60, Z 40…160  ⦿C (60,58)  R3 MESS   │
   │                                           flagpole (0,120)              X 70…110, Z 40…76     │
   │                                                                         R1 Barracks A         │
   │                                                                         X 120…170, Z 100…150  │
   └──────────────────────────────── SOUTH GATE (X −20…20, Z 200) ────────────────────────────────┘
                                       │ CORRIDOR ROAD X −20…20, Z 200 → 650
                                       │ checkpoint booth (32, 320) · overturned truck (−15, 260)
                                                  S (+Z)
```

## 2. Ground and bounds
- **Ground:** `Ground` material plates (`GROUND`), 512 × 512 tiles covering X −500…500, Z −400…650 at top Y 0 (except the basin and ridge, built separately). `ASH_DARK` drift patches (flat irregular plates 0.05 above) every 30–60 studs. Grass tufts (`GRASS_DEAD`) in clumps near walls and rocks.
- **FrameBarriers** (invisible, 40 tall): road corridor walls at X ±120 from Z 200 to 650 plus a cap at Z 650; outside the east breach (X 200…206, Z 20…100); trail corridor walls at ±55 from the trail centerline (6 boxes per side); basin: the dam's inner face (X −186), the cliff line (Z −724), the ridge foot (X 182), the south embankment top (Z −398) except the ramp (X −30…30).
- **PlayerBarriers** (on foot): outpost gates (South X −20…20 at Z 200; North X −20…20 at Z −160), the east breach (X 180, Z 40…80), and the rover area box X 90…200, Z −660…−540 (inner-faced walls, so the player stays inside while on foot at the rover).
- **Bounds warnings:** triggers `TRG_OOB_*` 15 studs inside each FrameBarrier (`12_combat_system.md` §9).
- The perimeter walls themselves block Frames (their tops at Y 18–19 intersect the Frame HRP's Y 14–24).

## 3. Corridor Road (Z 650 → 200)
| Element | Spec |
|---|---|
| Road | X −20…20, `Asphalt` `ASPHALT`, cracks (thin dark strips), potholes (shallow recessed dark plates), faded dashed center line (`ROAD_LINE`, 1 × 8 dashes every 16) |
| Shoulders | 6 wide each side, gravel (`Slate` `#6B6660`) |
| Guardrails | Steel posts every 8 plus a W-beam rail (`STEEL_MID`) on both sides from Z 600 to 260; 3 damaged sections (bent, missing posts) |
| Streetlights | Dead, every 50 on the east side (Z 600 → 250), 2 tilted |
| Power-line poles | Wooden (`WOOD_OLD`), every 60 on the west side at X −50, sagging cables (`BK.cable`), 1 fallen pole across the shoulder at Z 470 |
| **Checkpoint** | Booth 8 × 9 × 8 at (32, 0, 320) (windows broken, door open); boom barrier raised and snapped (pivot at X 26); sandbag walls (2); sign on a gantry over the road at Z 330: "FRONTIER OUTPOST 07 — GREYWATCH — HALT FOR INSPECTION" |
| **Overturned truck** | (−15, 0, 260): a military truck (Truck prop) on its side across the west lane, `RUST` / `CorrodedMetal`, tires, 4 spilled crates. Trigger `TRG_OP_TRUCK` (X −40…40, Z 255…275, who = frame) |
| Roadside | Low rolling wedges, 24 dead trees, rocks, ash drifts |
| Mission start | `FRAME_OP_START_02` (10, 0, 560), `FRAME_OP_START_01` (−14, 0, 566), facing −Z |
| Waypoint | `WP_OP_SOUTHGATE` (0, 0, 200) |

## 4. Perimeter, gates, towers
- **Walls:** WallSegment props (20 × 18 × 4, `07` §6). South wall Z 200 (X −180…−20 and 20…180); north wall Z −160 (same spans); west wall X −180 (Z −160…200); east wall X 180 (Z −160…40 and 80…200). **East breach** Z 40…80: 3 debris piles plus a broken segment leaning at 30°, rebar.
- **Corner guard towers (4)** at (±180, ±…) corners: 8 × 24 × 8 concrete base, a roofed platform at Y 18 (railing), a ladder, a dead searchlight.
- **South Gate:** gate posts 4 × 22 × 4 at X ±22; an arch beam at Y 20 with the sign "FRONTIER OUTPOST 07 — GREYWATCH"; 2 chain-link gate leaves (20 × 14): the west leaf hangs from one hinge (rotated 70°, tilted 8°), the east leaf is swung fully open. Trigger `TRG_OP_SOUTHGATE` (X −40…40, Z 195…215, who = frame).
- **North Gate:** posts plus both leaves open; a hazard barrier pushed aside. `FRAME_OP_NORTHGATE` (0, 0, −150) facing −Z.

## 5. Courtyard (X −60…60, Z 40…160)
- `Pavement` `#7C8086`, crack network, faded parade-ground markings (white lines at 50% transparency).
- **Flagpole** (0, 0, 120): Ø0.8 × 30 plus a plinth; a torn flag (2 Fabric pieces, `SLATE_DEEP`, one hanging limp) at the top.
- 4 sandbag positions at the courtyard corners; 6 Jersey barriers; a truck parked at (−40, 0, 140) with its door open; a crate pallet at (40, 0, 100).
- **"Abandoned in unusual locations"** details: a radio pack dropped at (10, 0, 80), a helmet at (−8, 0, 60), an overturned chair outside the bunker at (−12, 0, 8), a pair of boots by the bunker door, a rifle-less sling on a barrier (no weapons visible: the garrison took them).
- `MARK_MARA_COURTYARD` (−20, 0, 110) facing −Z (Mara's Unit 01 holds here during S22–S26).
- 4 courtyard floodlight poles (height 30) at (±55, 0, 45) and (±55, 0, 155): SpotLights aimed inward, Range 60, Brightness 1.5, **Shadows true**, tag `OutpostLight` (off until power).

## 6. Command Bunker (X −40…40, Z −60…0) and Pad A
**Exterior:** battered concrete walls (base 4 thick tapering to 2 at the top via wedges), height 14, roof slab Y 14…15.5 with a 1.5 parapet; a roof hatch; **CommMast** (70 tall, `07` §6) on the roof center (0, 15.5, −30) with 2 remaining dishes plus red aviation lights (blink when powered); the **third dish fallen** on the ground at (30, 0, 20), cracked. A cable tray runs down the east wall to a junction box at (41, 2, −30).
- **Clue A, cut cable** (`INT_CLUE_A`, hold 1.5) at (45, 1.5, −30): the main comm cable (Ø0.8) from the junction box into the ground conduit, **cut cleanly**: two ends 1 stud apart with flat faces; after power is restored, a tiny spark emitter (Rate 1) at the cut.
- **Entrance:** south face opening X −4…4, Y 0…9 at Z 0; a blast door panel (8 × 9 × 1) slid into the wall (open); a canopy wedge above; sign "COMMAND BUNKER".

**Interior** (ceiling 11, floor `FLOOR_HANGAR`, walls `CONCRETE_LIGHT`, interior walls 1 thick):
| Room | Bounds | Contents |
|---|---|---|
| Corridor | X −6…6, Z −24…0 | Lockers, coat rack with ash masks, notice board (duty roster: FERRIS, OKOYE, MBEKI, ADEYEMI, KOWALCZYK, REYES, HALVERSEN, NAKASHIMA, DUBOIS, ORTEGA, SATO, BRENNAN) |
| Bunk room | X −38…−6, Z −24…−2; door at X −6, Z −14…−9 | 6 bunks (blankets thrown back), personal items, a small part-built guitar, a photo strip on the wall, boots |
| Armory | X 6…38, Z −24…−2; door at X 6, Z −14…−9 | Empty wall racks with pegs, open empty ammo crates, sign "SIGN OUT ALL WEAPONS" |
| **Ops room** | X −38…38, Z −58…−24; opening from the corridor at Z −24, X −6…6 | **Comm console** at (0, 0, −40): an 8 × 3 × 4 desk with radio stacks, `INT_COMMS_CONSOLE` (hold 3.0); **LOG1 terminal** on a desk at (−20, 0, −45): `INT_EV_LOG1`; radio racks along the north wall (Z −57); a wall map (SurfaceGui: outpost, basin, ridge, "OUTPOST 05 — LOWMARCH" arrow south); a half-eaten ration tray, 3 mugs, a clipboard on the floor, an overturned chair |

- **Lighting:** 4 caged emergency lamps (`EMERGENCY_RED`, always on, dimmed to 0.3 after power); 6 ceiling panels (`OutpostLight`, SurfaceLight `LIGHT_NEUTRAL` Brightness 0.8 Range 16), one flickering (client, irregular 0.1–0.6 s).
- `SPAWN_OP_BUNKER` (0, 0, −30) facing −Z.
- **Pad A** (`PAD_A`): center (0, 0, 30), radius 14; concrete disc with a yellow ring, "PAD A" floor text, 4 amber edge lights; **ExitPoint** (16, 0, 24) facing −Z. The Frame kneels facing north.

## 7. Power Station (X −170…−90, Z −150…−80)
- **Fence:** chain-link (posts every 8, 10 tall, mesh as 3 horizontal rails plus diagonal thin parts in the dressed pass), an open gate on the east side (Z −125…−105).
- **Generator building** X −170…−140, Z −150…−130 (30 × 20 × 16): corrugated `CorrodedMetal` roof, 2 exhaust stacks, a closed roll door, sign "GENERATOR 1".
- **4 Transformers** at (−125, 0, −140), (−108, 0, −140), (−125, 0, −95), (−108, 0, −95); cable runs and a PipeRack between them; 2 have scorch marks and spark emitters (active only after power).
- **Frame-scale Breaker** (`07` §6) at (−92, 0, −115), housing facing **east**; lever arm `BreakerLever`. Prompt `INT_BREAKER` (FrameOnly, hold 2.0, MaxActivationDistance 30). Lever animation: rotates 90° down over 1.0 s about its top pivot (server tween).
- `FRAME_OP_BREAKER` (−70, 0, −115) facing −X. `WP_OP_BREAKER` (−92, 0, −115).
- FrameBarrier over the transformer yard interior (X −172…−98, Z −152…−78).

## 8. Maintenance Yard (X −170…−80, Z −40…100)
- **Garage** X −170…−110, Z 20…80, 18 tall: 3 bay doors on the east face (14 × 12) at Z 26…40, 43…57, 60…74. The middle door is open, with a truck inside, a workbench, tire stacks and oil stains.
- APC at (−100, 0, 60) facing south; a truck at (−100, 0, 20).
- **Fuel depot** X −150…−120, Z −30…0: a low bund wall (1.5 tall) around **3 FuelTanks** lying along X, centered X −135, at Z −25, −15 and −5, plus a pump station. **Clue B, untouched fuel** (`INT_CLUE_B`, hold 1.5): the prompt part is the fuel gauge panel at the east end of the middle tank (−126, 3, −15).
- FrameBarrier around the garage and depot.

## 9. Residential block (east)
| Building | Bounds | Spec |
|---|---|---|
| **R1 Barracks A** | X 120…170, Z 100…150 | 3 floors (30 tall), window rows (dark glass), exterior switchback stair on the west face (decor), roof water tank; doors closed with the sign "QUARTERS — 7TH GARRISON". Not enterable |
| **R2 Barracks B** | X 125…170, Z 10…70 | 3 floors; the **NE corner (X 155…170, Z 10…25) collapsed** (old damage: missing wall chunks, exposed slabs, rebar, rubble pile). Not enterable |
| **R3 Mess Hall** | X 70…110, Z 40…76 | **Single story, 12 tall**, enterable. South door X 86…94 at Z 76 (open). Interior: serving counter (X 74…106, Z 42…46) with pots and a radio; **4 mess table sets** with trays of half-eaten food (evacuated mid-meal); mugs; 2 ceiling panels (`OutpostLight`). **LOG2 datapad** on a table at (92, 0, 60): `INT_EV_LOG2` |

- Laundry lines between R1 and R2 (2 lines, colored cloth parts).
- **Watcher footprints** (Footprint (Watcher) prop, 7 × 14, oriented along the walking direction), the deliberate path that "stepped over the mess hall":
  P1 (8, 0, −150) → P2 (30, 0, −126) → P3 (52, 0, −100) → P4 (70, 0, −74) → P5 (88, 0, −48) → P6 (104, 0, −22) → P7 (116, 0, 6) → P8 (122, 0, 34) → **P9 (122, 0, 60)** [the alley between R3 and R2] → **P10 (60, 0, 58)** [west of the mess hall: it stepped over it] → P11 (46, 0, 30) → P12 (48, 0, 2) → P13 (50, 0, −28) [at the cut cable] → P14 (40, 0, −70) → P15 (24, 0, −110) → P16 (6, 0, −150) → out the North Gate and along the trail.
- **Clue C, footprints** (`INT_CLUE_C`, hold 1.5) at P10 (60, 0, 58).

## 10. Observation Tower (base center (150, 0, −120))
- Concrete core 12 × 50 × 12 (X 144…156, Z −126…−114). An **exterior steel switchback stair**: 5 flights of 10 rise, each 15 run, going around the faces (south → east → north → west → south) with 4 × 4 corner landings; stair band 4 wide, 0.5 outside the core.
- **Top platform** at Y 50: 20 × 20 (X 140…160, Z −130…−110), railing, a roof at Y 58 on 4 posts, a broken searchlight on a pivot. The **LOG3 note** is taped to the searchlight: `INT_EV_LOG3` at (150, 50, −120).
- The view from the top looks north along the trail toward the basin haze.
- FrameBarrier around the base (X 138…166, Z −132…−108).

## 11. Trail (North Gate → Kessler Basin)
- Centerline nodes: **TR0** (0, 0, −165) → **TR1** (18, 0, −215) → **TR2** (−8, 0, −270) → **TR3** (12, 0, −325) → **TR4** (0, 0, −390) (ramp top) → **TR5** (0, −12, −440) (ramp bottom). Waypoints follow these.
- Surface: a 30-wide dirt strip (`Ground` `#5A5244`) as rotated segments along the polyline; edges with tufts and small rocks.
- Rock outcrops (height 20–40) lining both sides 35–60 studs from the centerline; dead trees; a broken signpost "KESSLER RESERVOIR — NO ENTRY" at (25, 0, −230); an old rusty pipeline (Ø4 on supports) parallel, 45 studs west.
- Watcher footprints continue every 28 studs along the trail (alternating X ±5 from the centerline).
- **Triggers:** `TRG_TRAIL_1` (X −60…60, Z −205…−195), `TRG_TRAIL_2` (Z −305…−295), `TRG_TRAIL_3` (Z −375…−365), **`TRG_BASIN_ENTRY`** (X −40…40, Z −440…−420, Y −20…40), all who = frame.

## 12. Kessler Basin (the arena)
| Element | Spec |
|---|---|
| **Floor** | X −186…182, Z −724…−424, top Y −12; `Mud` `MUD_DRY` tiles; a crack network of 40 polygons (`MUD_CRACK` strips 0.05 above); ash drifts |
| **Ramp** | X −30…30, from (Z −390, Y 0) down to (Z −438, Y −12) (14°), with concrete wing walls where it cuts the embankment |
| South embankment | Z −424…−400, slope from Y −12 up to 0 (Rock/Ground wedges), except the ramp |
| **Dam** (west) | X −200…−186 (14 thick), Z −724…−424, Y −12…18; `Concrete` `CONCRETE_DARK` with a waterline stain band (`#4A4F45`, Y −12…0) and painted depth markers ("5", "10", "15" m); a **spillway notch** at Z −590…−560 (top lowered to Y 4, broken edge); railing remnants and a small control hut on top at (−193, 18, −470) |
| **Cliffs** (north) | Z −740…−724, irregular rock masses (Basalt/Rock) up to Y 40 |
| **Intake tower** (landmark, blocking) | Cylinder Ø18, Y −12…34, at (−95, −12, −600); concrete with rust streaks; 4 dark intake grates at the base; a ring walkway with a railing on top; a small control house; a broken access-bridge stub (10 long) pointing west at Y 30 |
| **Large rock formations** (blocking cover, 28–36 tall from the floor) | RF1 (−140, −12, −480) ~30 × 28 × 24; RF2 (70, −12, −470) ~26 × 32 × 22; RF3 (110, −12, −690) ~34 × 36 × 26; RF4 (−30, −12, −680) ~28 × 30 × 24, each from 4–7 rotated Rock wedges/blocks, `CanCollide = true` |
| Small rock clusters (decor, `CanCollide = false`) | (−60, −470), (20, −520), (−120, −560), (40, −620), (−150, −700), (140, −520), (0, −700), (−60, −640), all at Y −12 |
| **Fallen power pylon** | Lattice lying from (−60, −12, −705) to (60, −12, −712), `CanCollide = false`; its broken base on the north rim |
| Boat wreck | A small rusted hull on its side at (−130, −12, −650) (a reservoir detail) |
| Trees | 12 dead trees on the rim, 3 bleached ones (`#8A8378`) in the basin |
| Strider footprints | 15 scattered (6 × 12) plus drag marks |
| Low mist | 4 large faint emitters near the floor at the basin corners (smoke texture, Size 30–60, transparency 0.85, Rate 1) |
| **Strider start** | `TITAN_STRIDER_DORMANT` (−60, −12, −580), **facing −Z (north), its back to the approaching player** |
| Fight spawns | `FRAME_OP_FIGHT` (0, −12, −445) facing −Z; `FRAME_OP_POSTFIGHT` (20, −12, −520) |
| Mara marks | `MARK_MARA_REGROUP` (40, −12, −520) |
| Cams | `CAM_STR_1` (−20, −10, −505) → look (−60, 0, −580); `CAM_STR_2` (−60, 10, −470) → look (−60, 44, −580) |

**Playable fight space:** roughly X −170…170, Z −700…−445, minus the intake tower and RF1–RF4. Routes: around both sides of the intake tower, between RF1 and the dam, between RF2 and the ridge foot, and the open center.

## 13. East Ridge and the Watcher route
- **Slope:** X 182…260, Z −724…−424, from Y −12 up to Y 30 (big Ground/Rock wedges with outcrops). **Plateau** X 260…340 at Y 30. **Beyond:** X 340…520 rising gently to Y 40, fading into fog.
- Watcher footprints on the plateau.
- **FrameBarrier** at X 182 (Z −724…−424); the player can't climb the ridge. The Watcher (TitanRoot) passes through.
- **Watcher nodes:** `W0` (290, 30, −560) → `W1` (250, 25, −575) → `W2` (205, 1, −590) → `W3` (172, −12, −598) [kneel facing the rover] → (after) `W2` → `W1` → `W4` (300, 30, −560) → `W5` (460, 37, −560) → despawn.
- **Cams (S31):** `CAM_WA_1` (20, 30, −505) → look (290, 50, −560); `CAM_WA_2` (120, 20, −540) → look (290, 62, −560), FOV 30; `CAM_WA_3` (60, 25, −640) tracking the Watcher; `CAM_WA_4` (110, 0, −570) → look (150, 5, −600); `CAM_WA_5` behind the Watcher toward Unit 02 (computed at runtime: Watcher head position + 20 behind, looking at Unit 02).

## 14. Rover crash site
- **Rover SR-12** (`07` §6) at (150, −12, −600), lying on its **right side**, front facing north, **roof facing east** (toward W3). Its long axis runs along Z (Z −612…−588). Rear doors face south with the **ECHO 3-ring symbol and "SR-12"**: `INT_ROVER_MARKING` at (150, −8, −587).
- **RoofPanel** (hinged Model): closed until S31; the Watcher peels it open (rotates 110° outward over 1.5 s, server tween). It then forms an opening into the cargo bay on the east side with a debris ramp (wedge) at (158, −12, −600) for on-foot entry.
- **Cargo bay** (interior space 8 × 7 × 14 on its side): the cryo cradle (`INT_ROVER_CRADLE`) at (150, −10, −604) with the label SurfaceGui "SUBJECT T-V / ECHO-9" (empty after S31); the **sealed case** (`INT_ROVER_CASE`, MetalCase with `LockLight`) at (150, −11, −596); scattered papers; a broken screen.
- `TV_Canister` starts in the cradle (hidden inside the closed rover); the Watcher removes it in S31.
- Skid marks: 4 dark strips curving from (60, −12, −560) to the rover. Debris: a torn-off wheel, 3 crates, a bent antenna.
- **Pad B** (`PAD_B`): center (120, −12, −600), radius 14, ExitPoint (134, −12, −596) facing +X.

## 15. Lighting, atmosphere, audio
- Preset OVERCAST (`06` §5). Ambient ash particles ON outdoors.
- `OutpostLight` group (enabled at `M01_POWER` with a 3× flicker): 4 courtyard floods (shadows), 16 building wall lamps (SpotLight `AMBER_LAMP`, Range 30, Angle 60, no shadows), 6 bunker panels, 2 mess hall panels, 4 gate lamps, comm mast aviation lights (blink 0.8 Hz).
- Audio emitters: `AMB_OUTDOOR_WIND` (3 points), `AMB_POWER_HUM` at the transformers (after power), `AMB_BASIN` (3 points in the basin), creaking metal on the fallen dish and the intake tower.

## 16. Gameplay object registry (all IDs)
`FRAME_OP_START_01/02`, `FRAME_OP_BREAKER`, `FRAME_OP_NORTHGATE`, `FRAME_OP_FIGHT`, `FRAME_OP_POSTFIGHT`, `SPAWN_OP_BUNKER`, `TITAN_STRIDER_DORMANT`, `TITAN_WATCHER_W0`, `PAD_A`, `PAD_B`, `TRG_OP_TRUCK`, `TRG_OP_SOUTHGATE`, `TRG_TRAIL_1/2/3`, `TRG_BASIN_ENTRY`, `TRG_OOB_*`, `INT_BREAKER`, `INT_COMMS_CONSOLE`, `INT_CLUE_A/B/C`, `INT_EV_LOG1/2/3`, `INT_ROVER_MARKING`, `INT_ROVER_CRADLE`, `INT_ROVER_CASE`, `WP_OP_SOUTHGATE`, `WP_OP_BREAKER`, `WP_OP_PADA` (0, 0, 30), `WP_OP_CONSOLE` (0, 0, −40), `WP_OP_PADB` (120, −12, −600), `MARK_MARA_COURTYARD`, `MARK_MARA_REGROUP`, `CAM_STR_1/2`, `CAM_WA_1..4`, nodes `TR0..TR5`, `W0..W5`.

## 17. Acceptance checklist
- [ ] Every ID in §16 exists exactly once (PromptCheck, TriggerCheck).
- [ ] Unit 02 can drive the whole route (road → gate → breaker → Pad A → north gate → trail → basin) with no snags; the FrameBarriers hold.
- [ ] On foot: Pad A → bunker console → clues A/B/C → logs 1–3 (tower stairs climbable) → back to the Frame, with no snags.
- [ ] Basin: the Strider can reach every part of the fight space; the player has at least 3 distinct routes around the cover; the ramp and fight spawn are on the floor (no floating or sinking).
- [ ] Power-off vs. power-on states look clearly different.
- [ ] ≤ 12,000 parts; light limits respected.
