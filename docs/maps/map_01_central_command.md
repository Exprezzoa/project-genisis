# MAP 01 — Halden Central Command (hub)

**Purpose:** introduce military life; the player's main social hub. It must be navigable **without a map**: every key place has a landmark and a sign, and the main routes are straight and wide.

**Folder:** `Workspace.Map.CentralCommand.<Area>`. **Builders:** `builders/maps/central_command/<Area>.lua`. **Budget:** 9,000 parts, 220 lights (shadowed ≤ 24 per 150-stud radius).

All coordinates are world space (Ops Hall center = origin). Walls on centerlines. Floor top Y 0.

---

## 1. Top-down layout

```
                    N (−Z)
   Training Yard              ┌────────────────── FRAME HANGAR (map_02) ───────────────┐
   X−420..−122                │ X −120..120, Z −230..−70, roof Y 90                    │──Launch──▶ Causeway ─▶ Bulwark
   Z−300..−40                 └────────────┬──────────────┬────────────────────────────┘  X123..200
   (map §12)                               │ Hangar Gate  │       ┌─ Research Corridor (locked at X100) ──┐┌ Voss Lab ┐
                                           │ X−15..15     │       │ X 80..200, Z −60..−48                 ││X200..250 │
 ┌─────────────┬──────┬────────────────────┴──Z−70..−40───┴──┬──────┤                                       ││Z−80..−20 │
 │ BRIEFING    │ WEST │            OPS HALL                   │ EAST │ EQUIPMENT  X80..130, Z−40..0          │└──────────┘
 │ X−130..−80  │ CORR │   X −60..60, Z −40..40, ceiling 36    │ CORR │───────────────── (roof = Observation Deck, Y 20)
 │ Z−40..0     │X−80..│   mezzanine Y16 on north side         │X60..80├ MEDICAL    X80..130, Z0..40
 ├─────────────┤ −60  │                                       │Z−60..│
 │ PILOT QTRS  │Z−40..│                                       │  40  │
 │ X−130..−80  │  40  │                                       ├──────┤ Stairwell X60..80, Z40..60 (to deck)
 │ Z0..40      │      │                                       │
 └─────────────┴──────┴───────┬───────────────┬───────────────┘
                              │ Concourse     │
                              │ X−10..10      │
                              │ Z 40..80      │
                  ┌───────────┴───────────────┴───────────┐
                  │ ARRIVAL PLATFORM X −80..80, Z 80..130  │
                  └────────────────────────────────────────┘
                   ═══ Rail line Z 132..148 (X −600..600) ═══
                                  S (+Z)
```

## 2. Common construction
- **Exterior walls:** `Concrete` `CONCRETE_MID`, 2 thick, pilasters every 24 (structure pass), kickplate. Roof slabs 1–2 thick in `CONCRETE_DARK`, parapets 2 tall.
- **Interior walls:** `SmoothPlastic` `WALL_INTERIOR`, wainscot (lower 3 studs) `WALL_INTERIOR_LOW`, a `SLATE` trim band at Y 3, ceiling trim `STEEL_DARK`.
- **Interior floors:** `FLOOR_INTERIOR` with tile seams every 8 (dressed pass).
- **Doors:** human doors 5 × 8 (single) / 8 × 9 (double) with `STEEL_DARK` frames and an amber Neon status strip over the door (green for unlocked is NOT used; amber = open, red `DANGER_RED` = locked). Doorways are open passages (no physical doors) except the locked research door.
- **Ceilings:** a 1-thick `#8A9096` slab with light fixtures (`06_art_direction.md` §5).

---

## 3. Ops Hall (X −60…60, Z −40…40, ceiling Y 36, roof top Y 38)

**Landmark:** the giant **holo-table** in the center and the **status wall** on the north wall.

| Element | Spec |
|---|---|
| Openings | South (to Concourse): X −10…10 at Z 40, 14 tall. North (to Hangar Gate): X −15…15 at Z −40, **14 tall** (under the mezzanine). West: Z −10…10 at X −60, 14 tall. East: Z −10…10 at X 60, 14 tall |
| **Mezzanine** | Floor top Y 16 (1 thick), Z −40…−24, X −60…60. Railing along Z −24 (3.5 tall, `STEEL_DARK` posts, glass infill panels). **Vale's office** X −20…20, Z −40…−30 behind a glass wall at Z −30 (Glass panels with mullions, door gap X −2…2). Office props: desk, 2 chairs, wall map, shelf, a Directorate flag. Two small offices X −56…−24 and X 24…56 (Z −40…−30) with frosted glass (Glass transparency 0.3, color `#C9D3DA`) |
| **Mezzanine stairs** | West: Z −24…−18 (6 wide), rising from X −30 (Y 0) to X −54 (Y 16), top landing X −60…−54. East: mirrored (X 30 → 54). 16 steps each (rise 1, run 1.5) |
| **Status wall** | On the north wall face above the mezzanine: X −40…40, Y 20…34. Neon base `#1B2A33` plus SurfaceGui: header "THIRD FRONTIER FRAME DIVISION — OPERATIONAL STATUS" (Michroma); a list of 8 outposts with status chips: OUTPOST 01–06 and 08 "NOMINAL" (green-grey text), **"OUTPOST 07 — REPORT OVERDUE"** (amber, blinking 1 Hz) in the morning; in the evening "OUTPOST 07 — COMMS RESTORED / UNDER REVIEW". A rolling ticker at the bottom (propaganda lines). Interactable `INT_STATUS_WALL` (prompt on a small floor-level kiosk at (0, 0, −20)) |
| **Holo-table** | Prop at (0, 0, 0), Ø20 (`07` §6). The hologram shows the territory: New Halden (big block cluster west), the Bulwark line, corridor lines, Outpost 07 marker (red blink) 41 km east (scaled). Interactable `INT_HOLO` |
| **Consoles** | 8 Console props facing north. Row 1 Z 14: **C1** (−36), **C2** (−24), **C3** (24), **C4** (36). Row 2 Z 26: **C5** (−36), **C6** (−24), **C7** (24), **C8** (36). Center aisle X −12…12 stays clear. Chairs at each |
| Columns | 4 freestanding columns 3 × 36 × 3 at (±46, 0, −12) and (±46, 0, 34), with base and capital, `CONCRETE_LIGHT` plus a `SLATE` band at Y 3 |
| Banners | 4 Banners (4 × 12) on the west and east walls at Z ±25, hung at Y 18…30 |
| Posters | West wall at (−59.4, 6, 20) "THE FRAME STANDS. HUMANITY STANDS." (`INT_POSTER`); east wall (59.4, 6, 20) "DISCIPLINE IS SURVIVAL." |
| Lighting | Ceiling Neon strips (0.4 × 0.2 × 16) in 4 rows along X at Z −14, 0, 14, 28, at Y 35.5 (every 12 studs along X); SurfaceLight per `06` §5. Console screens glow. Status wall SurfaceLight (front face, Brightness 0.8, Range 30, `AMBER`) |
| Sound | `AMB_HUB_INTERIOR` emitters at (0, 30, 0) and (0, 10, 30) |

**NPCs:** Okafor at C1 (seated, `Inspect` gesture loops); officers at C3, C4, C7 (seated; barks `BARK_OPS_1..3`); 2 officers at C5 and C8 (ambient); 1 officer walking route A (§13). Vale isn't in the Ops Hall in the morning (he's in the briefing room).

## 4. West corridor (X −80…−60, Z −40…40, ceiling 14)
- Doors in the west wall (X −80): **Briefing** Z −24…−16 (8 wide double); **Quarters** Z 16…24 (8 wide).
- East wall (X −60) opening to the Ops Hall: Z −10…10.
- Signs above the doors: "BRIEFING ROOM ONE", "PILOT QUARTERS". A wall directory panel at (−79, 5, 0): "↑ HANGAR via OPS · ← BRIEFING · ← QUARTERS · → MEDICAL / EQUIPMENT".
- Props: 2 benches, a water fountain, a notice board ("Simulator rankings": SOLEN 41 — VEYNE 39 — ROOK 37; a small easter egg that pays off Mara's bet).

## 5. Pilot Quarters (X −130…−80, Z 0…40, ceiling 12)
- **Hallway** Z 16…24 from X −80 to X −130 (8 wide), lit by corridor strips.
- **Rooms** (16 × 16 each). North side (Z 0…16): **Q-1** X −96…−80, **Q-2** X −112…−96, **Q-3** X −128…−112. South side (Z 24…40): **Q-4** X −96…−80, **Q-5** X −112…−96, **Q-6** X −128…−112. Room doors (5 wide) on the hallway walls: Q-1/Q-4 at X −90…−85, Q-2/Q-5 at X −106…−101, Q-3/Q-6 at X −122…−117. Name plates beside the doors: Q-1 "ROOK, T.", Q-2 "VACANT", **Q-3 "VEYNE, E."**, Q-4 "SOLEN, M.", Q-5 "OKONJO, P.", Q-6 "VACANT".
- **Q-3 (Elias's room)**, the player's start:
  | Object | Position / spec |
  |---|---|
  | Bed (Bunk, long axis along Z) | center (−125.5, 0, 9), against the west wall |
  | Window slit | west exterior wall, Z 6…12, Y 6…7.5 (Glass); outside view: morning sky and ash |
  | Desk | center (−118, 0, 1.6), against the north wall, facing south |
  | Desk terminal | on the desk, screen facing south: `INT_Q3_TERMINAL` (S43; disabled until S43) |
  | Desk lamp | PointLight `AMBER_LAMP` Brightness 0.8, Range 14, Shadows true |
  | **Father's photo** | on the desk, left side: `INT_Q3_PHOTO` |
  | Father's patch | on the desk, next to the photo (hidden after `CH1_TOOK_PATCH`) |
  | Locker | (−123.5, 0, 1.2), against the north wall: `INT_Q3_LOCKER` |
  | Window prompt | `INT_Q3_WINDOW` on the window slit |
  | **Spawn** | `SPAWN_Q3_DESK` (−118, 0, 5) facing −Z (toward the desk and photo) |
  | Rug, chair, a shelf with 3 books and a core-chip card stack, uniform jacket on a hook | dressing |
- Other rooms: closed-door look (doorways have a closed door panel, since only Q-3 is enterable in Chapter 1). Q-4 (Mara's) door is ajar with a slit of light (dressing).
- **Tamsin** leans on the south hallway wall at (−104, 0, 23) facing north (`DLG_CH1_TAMSIN`, `TALK_TAMSIN`).

## 6. Briefing Room One (X −130…−80, Z −40…0, ceiling 16)
- Door from the west corridor at X −80, Z −24…−16.
- **Screen** on the west wall: Z −35…−5, Y 3…13 (30 × 10), SurfaceGui driven by the slide index (`BriefingScreen` controller; slides in `05` S07).
- **Lectern** at (−122, 0, −20), facing east.
- **Tiered seating** facing west: tier 1 floor Y 0 at X −112…−106 (bench at X −109), tier 2 floor top Y 1 at X −106…−100 (bench at X −103), tier 3 floor top Y 2 at X −100…−94 (bench at X −97). Benches in two blocks: Z −36…−24 and Z −16…−4; **center aisle Z −24…−16**. Tier edges have step lights (thin Neon strips, `AMBER`, 50% transparency).
- **Seats:** `SEAT_BRF_ELIAS` (−103, 1, −25), `SEAT_BRF_MARA` (−103, 1, −27.5).
- **Cam points:** `CAM_BRF_WIDE` (−92, 9, −20) → look (−125, 7, −20); `CAM_BRF_VALE` (−112, 6.5, −16) → look (−122, 6, −20); `CAM_BRF_PILOTS` (−113, 6, −24) → look (−104, 5, −26).
- Lighting: dimmable ceiling strips (Brightness 1.0 → 0.35 during S07) plus a screen glow.
- **Vale** stands at the lectern during S07 (pre-placed when S06 starts).

## 7. Equipment / Quartermaster (X 80…130, Z −40…0, ceiling 18)
- Door from the east corridor at X 80, Z −24…−16 (8 wide).
- **Counter** X 112…116, Z −34…−6 (2.8 tall, `STEEL_MID` top). **Sgt. Morrow** behind it at (120, 0, −20).
- **Equipment Terminal** (`INT_EQUIP_TERMINAL`): a large console at (126, 0, −20) facing west, enabled in Phase 6 (upgrades), showing "SERVICE OFFLINE" before that.
- Lockers (row of 10) along the north wall Z −39; pilot-suit racks (3 racks with 4 suits each: simple torso-shaped part stacks in suit colors); helmet shelf (12 helmets: a Ball plus a visor wedge each); crates.
- Sign "EQUIPMENT / QUARTERMASTER". Ceiling strips.

## 8. Medical Bay (X 80…130, Z 0…40, ceiling 18)
- Door from the east corridor at X 80, Z 16…24.
- **Scanner arch** prop at (115, 0, 20), oriented so you walk through it from west to east. Trigger `TRG_MED_ARCH` (X 113…117, Z 17…23, Y 0…8).
- **Voss's console** at (118, 0, 14) facing north-west; Voss stands at it in the evening (S41).
- 3 medical beds along the south wall (Z 38) at X 92, 104, 116, heads against the wall; curtain rails (thin bars on the ceiling) plus curtains (thin `#C9D2DA` Fabric panels, partially drawn).
- Medical cabinets (white, with glass fronts) along the east wall; a sink; a wall screen showing a heart-rate line (SurfaceGui).
- Lighting: `LIGHT_COOL` panels.

## 9. East corridor (X 60…80, Z −60…40, ceiling 14) and stairwell
- West wall opening to the Ops Hall: Z −10…10.
- East wall doors: Equipment Z −24…−16; Medical Z 16…24.
- North end (Z −60…−48) turns east into the **Research Corridor**.
- South end Z 40: door (X 66…74) into the **Stairwell** (X 60…80, Z 40…60): flight 1 X 61…69 from Z 42 (Y 0) to Z 57 (Y 10); landing Z 57…59, X 61…79; flight 2 X 71…79 from Z 57 (Y 10) to Z 42 (Y 20); top landing X 71…79, Z 40…42; **exit door** in the east wall (X 80, Z 42…50, Y 20…28) onto a short **roof bridge** (X 80…92, Z 40…50, deck top Y 20) leading onto the Observation Deck. Railings throughout.
- Signs: "MEDICAL", "EQUIPMENT", "OBSERVATION DECK ↑", "RESTRICTED →" (at the north end).

## 10. Research Corridor (restricted; X 80…200, Z −60…−48, ceiling 12) and Voss Lab
- Walls `MEDICAL_WHITE`, floor `#D5DADE`, `LIGHT_COOL` strips.
- **Security door** at X 100 (locked all of Chapter 1): `DOOR_RESEARCH`, steel 10 × 10 (fills the corridor cross-section), a red Neon status strip, a **window** 3 × 2 at Y 4…6 (Glass), sign "RESTRICTED — SCIENCE DIVISION — CLEARANCE 3". A card reader with a red light. Prompt `INT_RESEARCH_DOOR` → thought: `[E-thought] Clearance three. Not today.` (one-time) then "ACCESS DENIED" toast.
- **Visible through the window:** the corridor continues to X 200; at X 190 a **containment canister** on a pedestal: a glass cylinder Ø3 × 6, with an amber-orange organic mass inside (a cluster of 5 Balls, Neon `AMBER_CORE` at 0.3 transparency plus 3 darker nodules `#B5651D`), pulsing at a 2.0 s period (clue 3). Two Science Division guards (black-grey uniforms, ECHO pins) stand at X 150 in the evening only.
- **Voss Lab** (X 200…250, Z −80…−20): shell only (structure pass) in the Vertical Slice; the interior is for Chapter 2. Door at X 200 closed.
- Rhein and the guards exit the hangar and walk toward here in S40 (they despawn at the security door).

## 11. Arrival (Concourse X −10…10, Z 40…80; Platform X −80…80, Z 80…130)
- **Concourse:** ceiling 14, glass side walls (Glass panels with `STEEL_DARK` mullions every 4), benches, 2 info screens (train times: "CT-6 HALDEN CENTRAL → CORROW 07:40 · ON TIME"), turnstile gates at Z 76 (decorative, passable), sign "ARRIVALS — PLATFORM 1".
- **Platform:** concrete `CONCRETE_LIGHT`; yellow edge line at Z 129 (1 wide); **canopy** roof at Y 18 on 6 columns (X −60, 0, 60 at Z 88 and 124), with Neon strip lights beneath.
- **Rail line:** 2 rails (Metal `STEEL_LIGHT`, 0.4 × 0.6) at Z 136 and 144 on sleepers (every 3 studs, `WOOD_OLD`) on ballast (a 0.5-tall `#6B6660` strip, Slate material), from X −600 to 600.
- **Parked train** "CT-9" (5 cars, each 40 × 12 × 10, gaps 2), from X −104 to 104 at Z 134…146: body `#5B6770` with an amber stripe, windows (Glass dark, lit Neon interior strips), doors (2 per car, seams), a front cab at the east end with a slanted nose (wedges).
- **Spawn for post-chapter fast travel:** none in the Vertical Slice (decor).

## 12. Training Yard (X −420…−122, Z −300…−40)
- Concrete pad (`CONCRETE_DARK`), painted lanes (yellow), boundary barriers (Jersey barriers along the edges plus an invisible `FrameBarrier` ring 40 tall).
- Access: the hangar **west door** (map_02 §4) at Z −140…−80; an on-foot pedestrian gate at (−130, 0, −50) from the hub exterior.
- **Titan Simulacrum** (`07` §6) at (−320, 0, −170) facing east, with hurtboxes (same table as the Strider standing state). This is the Phase 2 test target.
- 4 **Frame-scale training dummies** at (−260, 0, −250), (−260, 0, −90), (−380, 0, −250), (−380, 0, −90).
- **Dismount pad** `PAD_TRAINING` center (−200, 0, −110), radius 14, ExitPoint (−186, 0, −110) facing +X.
- Observation booth at (−405, 0, −60) (a small 12 × 10 × 10 room with windows; decor).
- Locked until `CH1_COMPLETE` (except in debug). Before that, the west hangar door stays closed.

## 13. Exterior and navigation

### 13.1 Exterior
- Ground: `Pavement` `#7C8086` around buildings; `Asphalt` access roads 30 wide (the main road from the south gate at Z 420 north to Z 160, then west to the motor pool).
- Perimeter fence (chain-link look: thin posts every 8 plus a top rail plus 2 mid rails, `STEEL_MID`) along X ±420 and Z −320 / 420; main gate at (0, 0, 420) with a guard booth and the sign "HALDEN CENTRAL COMMAND — THIRD FRONTIER FRAME DIVISION".
- Motor pool at X −260…−160, Z 60…160: 2 trucks, 1 APC, a fuel tank, a canopy.
- Lamp posts every 40 along roads (StreetLamp, lit at EVENING and NIGHT).
- Flagpoles (3) in front of the Ops Hall south side at (−20, 0, 160), (0, 0, 160), (20, 0, 160).
- `PlayerBarrier` walls along the perimeter fence (players can't leave the hub).

### 13.2 Navigation nodes (`NAV_*`; NPC paths and NavCheck)
| Node | Position | Links |
|---|---|---|
| NAV_Q3_IN | (−120, 0, 8) | NAV_Q3_DOOR |
| NAV_Q3_DOOR | (−119.5, 0, 16) | NAV_Q3_IN, NAV_QH_W |
| NAV_QH_W | (−119.5, 0, 20) | NAV_Q3_DOOR, NAV_QH_E |
| NAV_QH_E | (−84, 0, 20) | NAV_QH_W, NAV_WC_Q |
| NAV_WC_Q | (−70, 0, 20) | NAV_QH_E, NAV_WC_MID |
| NAV_WC_MID | (−70, 0, 0) | NAV_WC_Q, NAV_WC_B, NAV_OPS_W |
| NAV_WC_B | (−70, 0, −20) | NAV_WC_MID, NAV_BRF_DOOR |
| NAV_BRF_DOOR | (−84, 0, −20) | NAV_WC_B, NAV_BRF_IN |
| NAV_BRF_IN | (−90, 0, −20) | NAV_BRF_DOOR, NAV_BRF_AISLE |
| NAV_BRF_AISLE | (−103, 1, −20) | NAV_BRF_IN |
| NAV_OPS_W | (−52, 0, 0) | NAV_WC_MID, NAV_OPS_C |
| NAV_OPS_C | (−14, 0, 8) | NAV_OPS_W, NAV_OPS_E, NAV_OPS_N, NAV_OPS_S |
| NAV_OPS_N | (0, 0, −32) | NAV_OPS_C, NAV_GATE_S |
| NAV_GATE_S | (0, 0, −42) | NAV_OPS_N, NAV_GATE_N |
| NAV_GATE_N | (0, 0, −68) | NAV_GATE_S, NAV_HG_S |
| NAV_HG_S | (0, 0, −80) | NAV_GATE_N, NAV_HG_VIEW, NAV_HG_SW |
| NAV_HG_VIEW | (0, 0, −160) | NAV_HG_S |
| NAV_HG_SW | (−100, 0, −100) | NAV_HG_S, NAV_HG_STAIR_B |
| NAV_HG_STAIR_B | (−114, 0, −140) | NAV_HG_SW, NAV_HG_STAIR_T |
| NAV_HG_STAIR_T | (−114, 28, −190) | NAV_HG_STAIR_B, NAV_CW_W, NAV_CW_B1S |
| NAV_CW_W | (−114, 28, −227) | NAV_HG_STAIR_T, NAV_CW_B2 |
| NAV_CW_B1S | (−114, 28, −198) | NAV_HG_STAIR_T, NAV_BAY1_HATCH |
| NAV_BAY1_HATCH | (−74, 28, −198) | NAV_CW_B1S |
| NAV_CW_B2 | (−35, 28, −227) | NAV_CW_W, NAV_CW_B2S |
| NAV_CW_B2S | (−35, 28, −198) | NAV_CW_B2, NAV_BAY2_HATCH |
| NAV_BAY2_HATCH | (−4, 28, −198) | NAV_CW_B2S |
| NAV_OPS_E | (52, 0, 0) | NAV_OPS_C, NAV_EC_MID |
| NAV_EC_MID | (70, 0, 0) | NAV_OPS_E, NAV_EC_EQ, NAV_EC_MED, NAV_EC_N |
| NAV_EC_EQ | (70, 0, −20) | NAV_EC_MID, NAV_EQ_DOOR |
| NAV_EQ_DOOR | (84, 0, −20) | NAV_EC_EQ, NAV_EQ_IN |
| NAV_EQ_IN | (100, 0, −20) | NAV_EQ_DOOR |
| NAV_EC_MED | (70, 0, 20) | NAV_EC_MID, NAV_MED_DOOR, NAV_EC_S |
| NAV_MED_DOOR | (84, 0, 20) | NAV_EC_MED, NAV_MED_IN |
| NAV_MED_IN | (100, 0, 20) | NAV_MED_DOOR, NAV_MED_ARCH |
| NAV_MED_ARCH | (113, 0, 20) | NAV_MED_IN |
| NAV_EC_S | (70, 0, 36) | NAV_EC_MED, NAV_STAIR_B |
| NAV_STAIR_B | (65, 0, 44) | NAV_EC_S, NAV_STAIR_L |
| NAV_STAIR_L | (70, 10, 58) | NAV_STAIR_B, NAV_STAIR_T |
| NAV_STAIR_T | (75, 20, 41) | NAV_STAIR_L, NAV_DECK_BR |
| NAV_DECK_BR | (86, 20, 45) | NAV_STAIR_T, NAV_DECK |
| NAV_DECK | (105, 20, 0) | NAV_DECK_BR |
| NAV_EC_N | (70, 0, −54) | NAV_EC_MID, NAV_RC_DOOR |
| NAV_RC_DOOR | (97, 0, −54) | NAV_EC_N |
| NAV_OPS_S | (0, 0, 36) | NAV_OPS_C, NAV_CONC |
| NAV_CONC | (0, 0, 60) | NAV_OPS_S, NAV_ARR |
| NAV_ARR | (0, 0, 100) | NAV_CONC |

**Ambient routes:** Officer route A: NAV_OPS_C → NAV_OPS_E → NAV_EC_MID → NAV_EC_EQ → back. Hangar technician routes in `map_02` §9.

### 13.3 Waypoint markers (`WP_*`)
`WP_HANGAR_ENTRANCE` (0, 0, −72) · `WP_BRIEFING_DOOR` (−80, 0, −20) · `WP_MEDICAL_ARCH` (115, 0, 20) · `WP_QUARTERS` (−119.5, 0, 16) · `WP_DECK` (126, 20, −10).

### 13.4 Gameplay object registry (hub; every ID must exist exactly once)
| ID | Type | Where |
|---|---|---|
| `SPAWN_Q3_DESK`, `SPAWN_QH`, `SPAWN_BRF_DOOR`, `SPAWN_OPS`, `SPAWN_MED_DOOR`, `SPAWN_DECK`, `SPAWN_TRAINING` | Spawns | `map_00` §5 |
| `SEAT_BRF_ELIAS`, `SEAT_BRF_MARA` | Seat marks | §6 |
| `INT_Q3_PHOTO`, `INT_Q3_LOCKER`, `INT_Q3_WINDOW`, `INT_Q3_TERMINAL` | Prompts | Q-3 (§5) |
| `TALK_TAMSIN` | Prompt (on Tamsin) | Quarters hallway |
| `TALK_OKAFOR` | Prompt (on Okafor) | Console C1 |
| `INT_STATUS_WALL`, `INT_HOLO`, `INT_POSTER` | Prompts | Ops Hall (§3) |
| `INT_RESEARCH_DOOR` | Prompt | Research security door (§10) |
| `INT_EQUIP_TERMINAL` | Prompt | Equipment (§7) |
| `TRG_BRIEFING_ENTER` | Trigger | X −92…−82, Z −24…−16, Y 0…10 (who = foot) |
| `TRG_MED_ARCH` | Trigger | §8 |
| `CAM_BRF_WIDE`, `CAM_BRF_VALE`, `CAM_BRF_PILOTS` | Cam points | §6 |
| `MARK_MARA_DECK` | NPC mark | (126, 20, −10) facing +X |
| `MARK_VOSS_MED` | NPC mark | (118, 0, 14) |
| `MARK_TAMSIN` | NPC mark | (−104, 0, 23) facing −Z |
| `PAD_TRAINING` | Dismount pad | §12 |
| `DOOR_RESEARCH` | Door | §10 |

## 14. Story-state variants (applied by sequence actions)
| State | Changes |
|---|---|
| MORNING (S01–S10) | Status wall "REPORT OVERDUE"; PA morning set; Tamsin in the hallway; officers at C3/C4/C7; Vale in the briefing room from S06 |
| EVENING (S40–S42) | Status wall "COMMS RESTORED / UNDER REVIEW"; PA evening set; 2 guards in the research corridor; Voss in Medical; Mara on the Observation Deck after S41; Tamsin gone |
| NIGHT (after S43) | Lights dimmed 30%; most ambient NPCs removed; the Training Yard unlocked (west hangar door opens on approach) |

## 15. Acceptance checklist (map)
- [ ] All areas, openings, stairs and the mezzanine built to spec; NavCheck passes.
- [ ] Every interactable, trigger, spawn, seat, cam point, nav node and waypoint listed here exists with the correct ID.
- [ ] Doors ≥ 5 × 8; corridors ≥ 7 wide; no geometry snags (walk test from Q-3 to every area and back).
- [ ] Budget: ≤ 9,000 parts; lights within limits.
- [ ] Signs present for every area; a first-time player can find the hangar from Q-3 without a waypoint (user test in Phase 7).
