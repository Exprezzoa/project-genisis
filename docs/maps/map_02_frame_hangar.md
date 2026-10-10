# MAP 02 — Frame Hangar, Launch Platform, Causeway, Bulwark Gate

**Purpose:** the visual centerpiece of the opening. It must feel **enormous** next to a 5.5-stud human, stay practical for repeated visits, and give the Frame a physical home (no "Frame in an inventory").

**Folder:** `Workspace.Map.Hangar.<Section>` (Bulwark under `Workspace.Map.Backdrops.Bulwark`). **Budget:** 6,000 parts (hangar, launch and causeway) plus 400 (Bulwark); 90 lights; ≤ 20 shadowed.

> **Roblox limit:** PointLight/SpotLight/SurfaceLight `Range` is **max 60**. Any light meant to reach the hangar floor must hang at Y ≤ 60.

---

## 1. Shell
| Element | Spec |
|---|---|
| Footprint | X −120…120, Z −230…−70 (240 × 160). Walls 3 thick (centerlines on the boundary), `Concrete` `CONCRETE_MID`, interior face with **pilasters every 24** (3 × 90 × 2, `CONCRETE_DARK`) and a 1-stud kickplate |
| Height | Walls Y 0…90. **Roof:** steel trusses (`STEEL_DARK`) every 24 along Z spanning X, bottom chord at Y 88, top at Y 96 (a sloped roof made of 2 big wedges from Y 92 at the walls to Y 98 at center), roof deck `#5A5F66` `Metal` |
| Floor | Slab top Y 0, `Concrete` `FLOOR_HANGAR`; expansion joints (0.2 strips, `KICKPLATE`) on a 24-stud grid |
| South entrance (human) | Opening X −15…15, Y 0…16 in the south wall (Z −70), from the Hangar Gate Corridor (§12). Hazard stripe frame. Sign above: "FRAME HANGAR" (Michroma, amber, 20 × 3) |
| East wall | **Deployment door** opening Z −180…−120, Y 0…70 (§4) |
| West wall | **Training door** opening Z −140…−80, Y 0…70 (§4) |
| Clerestory windows | South wall Y 60…80, six 30-wide window bays between X −110 and 110 (skip X −15…15 above the entrance sign), Glass transparency 0.5, `STEEL_DARK` mullions every 5. Sun shafts at MORNING come through (SunRays) |
| Wall graphics | North wall (above the back walkway), Y 50…70: "THIRD FRONTIER FRAME DIVISION" (SurfaceGui, Michroma, `#E8ECEF` at 0.1 transparency, LightInfluence 1). Below it, smaller: "EVERY WALL WAS BUILT BY SOMEONE WHO CARED." 2 giant **division banners** (16 × 28 Fabric `SLATE_DEEP` plus an amber chevron) on the south wall at X ±40, Y 30…58 |
| Pipes | Two pipe runs along the east, north and west walls at Y 60 (Ø2.4, `STEEL_MID`) and Y 75 (Ø1.6, `#7B848C`) with brackets every 12 |

## 2. Bays and Frames
| Bay | Floor rectangle | Frame (FRAME_BAY*) | Notes |
|---|---|---|---|
| **Bay 1** | X −95…−45, Z −230…−180 | Unit 01 (Mara), (−70, 0, −205), facing +Z | Ally Frame |
| **Bay 2** | X −25…25, Z −230…−180 | **Unit 02 (Elias)**, (0, 0, −205), facing +Z | Hero bay; 2 extra floodlights |
| **Bay 3** | X 45…95, Z −230…−180 | Unit 03 (repair prop), (70, 0, −205), facing +Z | Scaffolds, detached arm, exposed core (clue 2), welding |

- Bay floor markings: a 1-wide yellow outline (`HAZARD_YELLOW`, a 0.05-high strip) around each rectangle; a bay number painted on the floor at (bayX, 0.05, −186) ("01", "02", "03", SurfaceGui on a 16 × 10 plate, Michroma, yellow at 0.15 transparency).
- **Bay 3 dressing:** scaffold towers (TrussPart 6 × 30 × 6) at X 50…56 and X 84…90, Z −210…−200, with plank platforms (`WOOD_OLD`) at Y 18; Unit 03's detached left arm lying along X on two floor supports (yellow steel cradles at (84, 0, −186) and (98, 0, −186)); a pec-plate rack (2 plates standing) at (100, 0, −196); **Technician Pell** welding on the platform at (54, 18, −205) (spark emitter Rate 15 plus a flickering PointLight `#BFD9FF`, Brightness 2 ↔ 0, Range 14, random flicker 10–20 Hz) plus `AMB_WELDING`.
- **Hazard placards** on each bay's front supports: "DANGER — FRAME BAY — STAY BEHIND THE LINE".
- Bays are walkable on foot (only the catwalk route reaches the cockpit).

> **Changes for the 64-stud Frames (D-044); these override the numbers below and in §5, §9 and §11:**
> - Catwalk, walkway and bridge **deck top Y 45** (was 28): the height of the hatch, whose center is now at Y 49.6.
> - **Cockpit access bridges at Z −195…−191** (were −200…−196), just in front of the Frames' chests. Nav nodes and `WP_BAY2_BRIDGE` follow: Y 45, and Z −193 for the bridge nodes.
> - **Main stair:** still from (Z −144, Y 0) to (Z −186, Y 45), so its foot stays clear of the Training door; 45 steps of rise 1 and run 14/15 (steep).
> - **Crane:** the hanging plate at Y 70–74, hook block at Y 76 (was 48–52 / 54), above the Frames (64, 68 with the head fin).
> - **Pendant high-bays** hang to Y 78 (was 55). **Bay floodlights** at Y 47 (was 30).
> - Camera points that look at a Frame's chest look at Y 46–54 (were 29–34).
> - A Frame is about 51 wide and fills its 50-wide bay; the doors (70 tall) and the trusses (Y 88) still clear it.

## 3. Catwalks, stairs, bridges (deck top Y 28, `DiamondPlate` `STEEL_MID`, railings 3.5 tall)
| Element | Spec |
|---|---|
| Back walkway | X −120…120, Z −230…−224 (6 deep), against the north wall, on wall brackets every 12 |
| Side catwalks (8 wide) | **Outer west** X −118…−110, Z −224…−186; **Bay1–2 gap** X −39…−31, Z −224…−186; **Bay2–3 gap** X 31…39, Z −224…−186; **outer east** X 110…118, Z −224…−186. Each is supported by 2 steel columns (2 × 28 × 2) at its south end |
| **Main stair** | X −118…−110 (8 wide), rising **northward** from the bottom (Z −144, Y 0) to the top (Z −186, Y 28): 28 steps (rise 1, run 1.5); landing joins the outer west catwalk. A stringer and railings on both sides. Sign at the bottom: "CATWALK ACCESS" |
| **Cockpit access bridges** (4 wide) | **Bay 2:** X −31…−2, Z −200…−196 (from the Bay1–2 catwalk east to Unit 02's chest). **Bay 1:** X −110…−72, Z −200…−196 (from the outer west catwalk to Unit 01). Each ends at a 4 × 4 platform in front of the hatch with a yellow kick-strip edge |
| Bay 3 | No bridge (under repair) |

**Hatch prompt:** `INT_BOARD_BAY2` on Unit 02's `Hatch` part (HoldDuration 1.0, MaxActivationDistance 8, OnFootOnly). Bay 1's prompt exists but stays disabled (Mara's).

## 4. Big doors (`DOOR_HANGAR_EAST`, `DOOR_HANGAR_WEST`), server-tweened
- **Construction:** 4 horizontal segments, each 60 × 17.5 × 3 (`STEEL_MID` `Metal` plus horizontal ribs, `HAZARD_YELLOW`/`HAZARD_BLACK` 45° stripes on the bottom 2 studs of the lowest segment, and a small "LAUNCH 1 →" stencil on the east door).
- **Header housing** on the exterior face above the opening: 13 deep × 22 tall × 64 wide (`CONCRETE_DARK`) at Y 68…90.
- **Open:** segments telescope: segment *k* (k = 1 bottom … 4 top) tweens to Y 70…87.5 and outward by 3 × k studs, nesting inside the housing. Stagger 0.3 s per segment, duration 3.0 s each (≈ 4 s total), `Quad InOut`. **Close** is the reverse.
- Two rotating **beacons** (`06` §6) on brackets at each side of the east door (Y 72), active while the door moves and during S09–S10. Siren `SFX_SIREN`.
- The east door opens in S09 and closes after launch. The west door opens only after `CH1_COMPLETE`, or in debug.

## 5. Overhead gantry crane (ambient, client-animated `AmbientMover`)
- Runway rails (box beams 2 × 3 along X) at Y 80 on wall brackets at Z −225 and Z −80.
- **Bridge girder:** a box girder 145 long (spanning Z −225…−80) × 3 wide × 4 tall, `HAZARD_YELLOW` with black end stripes, on 4 end trucks (wheels as cylinders).
- **Trolley** (8 × 4 × 6) at Z −150 on the girder; 2 hoist cables (Ø0.3) down to a hook block at Y 54; it carries a **pauldron plate** (7.5 × 4.5 × 9, `VG_PRIMER`) hanging at Y 48–52.
- Motion: the bridge travels X −100 ↔ 100 over 60 s each way (SineInOut). The plate sways ±2°. `AMB_CRANE` sound on the trolley.
- Clearance: the plate's bottom (Y 48) is above any Frame (40).

## 6. Control booth (decor)
On the south wall interior, X 40…80, Z −78…−72, Y 18…28: a glass front (Glass plus mullions), lit interior (2 consoles, a chair, a seated technician T3 visible), supported on 2 brackets. No access.

## 7. Floor props and markings (dressed pass unless marked ★ = structure pass)
| Item | Position / spec |
|---|---|
| ★ **Safe Viewing Line** | Hazard stripe 2 wide from X −100 to 100 at Z −168. Floor text "SAFE VIEWING LINE — DO NOT CROSS" at (0, 0.05, −165) |
| ★ **Frame lane** | Wide yellow chevrons (2 bars each, 1 wide × 10 long at ±45°) every 20 studs: from (0, −180) south to (0, −150), then east along Z −150 to the east door |
| ★ Pedestrian lane | 6 wide, yellow dashed edges: from the south entrance (0, −72) west along Z −80 to X −105, then north along X −105 to the stair bottom (−114, −144) |
| Tool carts (6) | (−60, 0, −172), (−95, 0, −172), (60, 0, −176), (95, 0, −172), (−40, 0, −100), (40, 0, −95) |
| Crate stacks (8) | Along the south wall at Z −80: X −90, −70, −50, −30, 30, 50, 70, 100; plus 2 along the east wall at X 112, Z −110 and −90 |
| Armor plate racks (3) | (100, 0, −190), (100, 0, −176), (−104, 0, −176) |
| Coolant tanks (6) | Cylinders Ø4 × 10, `#7B848C`, clusters under the back walkway at (108, 0, −220), (114, 0, −214), (102, 0, −214), (−108, 0, −220), (−102, 0, −214), (−114, 0, −214) |
| Power cabinets (3) | 6 × 9 × 3 against the south wall at X −50, 50, 90 (Z −72), with Neon indicator lights and cable runs to each bay |
| Floor cable runs | From each power cabinet to its nearest bay, 3 cables per run, clamps every 6 |
| Forklift (ambient mover) | Loop (−80, −120) → (−30, −120) → (−30, −95) → (−80, −95), 6 studs/s, pausing 3 s at the corners; T6 rides it |
| Mobile staircase (rolling stair, 14 tall) | (40, 0, −190) beside Bay 3 |
| Fire extinguisher stations (6) | Red boxes on the pilasters at Y 4 |
| Hazard bollards | Yellow Ø1.2 × 3.5 posts in pairs along the pedestrian lane every 16 |

## 8. Launch Platform, Causeway, Bulwark Gate
| Element | Spec |
|---|---|
| **Launch Platform** | X 123…200, Z −190…−110; deck top Y 0.5 (`DiamondPlate` `#4A4F55`), chamfered edges down to the ground (0.5 wedge). A **circle marking** of radius 25 (ring of 24 thin yellow segments) at center (160, 0.55, −150). Painted text "LAUNCH 1" (SurfaceGui 30 × 8) at (160, 0.55, −172). **4 FloodlightMasts** (height 50) at (126, −187), (197, −187), (126, −113), (197, −113), SpotLights aimed at the center (Range 60, Shadows true) |
| `WP_LAUNCH_CENTER` | (160, 0, −150). The S10 condition: the player's Frame within 20 studs (XZ) |
| **Causeway** | X 200…420, Z −175…−125 (50 wide), `Concrete` `CONCRETE_LIGHT` with a central dashed line (amber) and edge lines; Jersey barriers along both edges every 6 studs; StreetLamps every 40 on both sides; a `FrameBarrier` along both edges (height 40) |
| **Bulwark** (`Backdrops.Bulwark`) | X 420…450 (30 thick), Z −800…800, Y 0…120, `Concrete` `CONCRETE_MID` with horizontal pour lines every 12 (0.2 seams). **Buttresses** on the inner (west) face every 80 along Z: wedges 20 deep at the base × 100 tall. **Top walkway** at Y 120 with railings on both edges; amber lamp posts every 40 (PointLight `AMBER_LAMP`, Range 30, no shadows); gun emplacements every 160 (8 × 6 × 10 turret box plus 2 barrels Ø1.5 × 12) |
| **Frame Gate** (`DOOR_BULWARK_GATE`) | Opening Z −180…−120, Y 0…75. A massive concrete frame (8-thick border, hazard-striped inner edge). **Two leaves** (30 wide × 75 tall × 6 thick, `STEEL_DARK` plus vertical ribs) at Z −180…−150 and −150…−120, sliding apart along Z into wall pockets (to Z −210…−180 and −120…−90) over 6.0 s (server tween). A guard tower on the walkway above the gate (12 × 14 × 12, windows). Painted text on the inner face, north of the gate: "THIRD FRONTIER — HALDEN BULWARK" (120 × 12) |
| Beyond the gate | A road continues east (X 450 → 700) into the wilderness backdrop, fading into fog |
| `AUTO_CAUSEWAY_END` | (440, 0, −150): auto-walk target in S10 |

## 9. NPCs and ambient routes (morning)
| NPC | Placement / route |
|---|---|
| Hollis | `MARK_HOLLIS_START` (70, 0, −175) near Bay 3, `Inspect` idle → walks to `MARK_HOLLIS_TALK` (14, 0, −170) in S05 → back |
| Mara | `MARK_MARA_VIEW` (6, 0, −168) facing north (S05) |
| Pell | Welding at (54, 18, −205) |
| T1 | Loop (−60, −150) → (−60, −100) → (−20, −100) → (−20, −150) |
| T2 | Stands at (−70, 0, −176) inspecting Unit 01's legs (`Inspect` loop) |
| T3 | Seated in the control booth |
| T4 | Walks the back walkway (−100, 28, −227) ↔ (100, 28, −227) |
| T5 | At the tool cart (60, 0, −176), `Inspect` |
| T6 | Rides the forklift |

**Evening (S40):** Vale and Rhein enter from the south entrance and stop at `MARK_VALE_RETURN` (−3, 0, −160) / `MARK_RHEIN_RETURN` (3, 0, −160); a technician holding the spindle case at (8, 0, −166); 3 Science Division guards at (−10, 0, −178), (10, 0, −180), (14, 0, −174); T1, T5 and Pell remain; the others are removed.

## 10. Lighting
| Fixture | Count / placement | Settings |
|---|---|---|
| **Pendant high-bays** | 15: rows at Z −200, −150, −100 × columns X −96, −48, 0, 48, 96; hanging from the trusses on cables to **Y 55** | Lamp housing (cone of wedges) plus a Neon disc `LIGHT_NEUTRAL`; SpotLight Face=Bottom, Brightness 2.5, Range 60, Angle 90; **Shadows true only for the middle row (5)** |
| Bay floodlights | 2 per bay on the side-catwalk railings (Y 30), aimed at the Frame's chest | SpotLight `LIGHT_COOL` Brightness 3, Range 50, Angle 45; Shadows true (6) |
| Wall washers | SurfaceLights on 8 pilasters (Face toward the interior) | Brightness 0.6, Range 30, Angle 90, `LIGHT_NEUTRAL`, no shadows |
| Catwalk strips | Neon strips under the catwalk decks every 12 | SurfaceLight Bottom, Brightness 0.8, Range 18 |
| Door warning lights | Above each big door: 3 amber Neon boxes | PointLight `WARNING_ORANGE` Brightness 1, Range 20 |
| Beacons | 2 at the east door (rotating) | `06` §6 |
| Unit 03 core | PointLight at the core, `AMBER_CORE`, pulsing period 1.6 s | Range 24 |
| Launch masts | 4 | Shadows true (4) |

Shadowed total: 5 + 6 + 4 = **15 ≤ 20** ✓.

## 11. Gameplay objects
| ID | Type | Spec |
|---|---|---|
| `TRG_HANGAR_REVEAL` | Trigger | X −15…15, Z −80…−70, Y 0…20 (who = foot) |
| `TRG_DEPLOY_DOOR` | Trigger | X 70…118, Z −190…−110, Y 0…60 (who = frame) |
| `INT_BOARD_BAY2` / `INT_BOARD_BAY1` | Prompts | On the hatches |
| `CAM_HANGAR_REVEAL_1` | Cam | (0, 3, −150) → look (0, 34, −205) |
| `CAM_HANGAR_REVEAL_2` | Cam | (−30, 26, −175) → look (0, 30, −205) |
| `CAM_DOOR_EXT` | Cam | (260, 40, −150) → look (120, 35, −150) |
| `CAM_DOOR_REVEAL` | Cam | (60, 46, −150) → look (600, 40, −150) |
| `CAM_LAUNCH_A` / `CAM_LAUNCH_B` | Cam | (180, 20, −100) → Unit 02; (200, 110, −60) → look (440, 40, −150) |
| `WP_BAY2_BRIDGE` / `WP_DEPLOY_DOOR` / `WP_LAUNCH_CENTER` | Waypoints | (−4, 28, −198) / (100, 0, −150) / (160, 0, −150) |
| FrameBarriers | Invisible | Around Bay 1 (X −97…−43, Z −232…−178) and Bay 3 (X 43…97, Z −232…−178); around the stair/catwalk column zone (X −120…−100, Z −232…−140); the south entrance plug (X −16…16, Z −72…−68, Y 0…40); causeway edges |

## 12. Hangar Gate Corridor (X −15…15, Z −70…−40, ceiling 16)
- Floor `FLOOR_HANGAR`, walls `CONCRETE_LIGHT`, hazard stripes across both thresholds.
- A decontamination arch (decor, 2 pillars plus a beam with Neon strips) at Z −55.
- Pilot gear lockers along both walls (8 per side), a notice board: "EMBER SQUAD — DEPLOYMENT 06:30", "REMINDER: TAP-TESTING HATCHES IS NOT A SAFETY PROCEDURE. — H.B." (Hollis joke).
- Signs: "FRAME HANGAR — AUTHORIZED PERSONNEL" at the south end.

## 13. Acceptance checklist
- [ ] The scale reads: from the hangar floor at the south entrance, Unit 02's head is visibly far above (the screenshot test in Phase 7).
- [ ] The catwalk route from the entrance to the Bay 2 hatch is walkable without jumping; NavCheck passes for the nodes NAV_HG_* and NAV_CW_*.
- [ ] Unit 02 can walk from Bay 2 to the launch platform without snagging; FrameBarriers stop it from entering Bays 1 and 3 and the human corridor.
- [ ] The doors open and close in ≈ 4 s with beacons and siren; the Bulwark gate opens in 6 s.
- [ ] Light budget OK; the hangar floor is lit (no black areas) in MORNING and EVENING.
- [ ] ≤ 6,000 parts (excluding the Frames and the Bulwark).
