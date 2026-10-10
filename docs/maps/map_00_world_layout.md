# MAP 00 — World Layout (master coordinates, zones, backdrops, MemorySet)

**Units:** studs. **Axes:** North = −Z, South = +Z, East = +X, West = −X. **Ground top surface = Y 0** unless stated. Coordinates in map docs are **wall centerlines** (exterior walls 2 thick, interior 1, hangar 3).

Everything lives in **one place** (no teleporting between places in the Vertical Slice). Zones far apart are hidden by distance and Atmosphere fog.

## 1. Zone placement

| Zone | Origin / extents (world) | Doc |
|---|---|---|
| **Central Command** (hub incl. Training Yard) | Ops Hall center at (0, 0, 0). Extents X −420…420, Z −320…420 | `map_01` |
| **Frame Hangar + Launch + Causeway** | Hangar X −120…120, Z −230…−70; launch platform X 123…200, Z −190…−110; causeway X 200…420, Z −175…−125 | `map_02` |
| **Bulwark wall** | X 420…450, Z −800…800, Y 0…120. Frame Gate at Z −180…−120 | `map_02` §8 |
| **City backdrop (New Halden)** | West: X −1400…−440, Z −900…900. South: X −900…900, Z 440…1400 | §3 |
| **Wilderness backdrop** | X 450…2000, Z −1000…1000 | §3 |
| **Frontier Outpost 07 + trail + Kessler Basin + ridge** | **Origin O = (6000, 0, 0).** Local extents X −500…500, Z −800…650 → world X 5500…6500 | `map_03` |
| **MemorySet** (anomaly void) | Center (0, 2000, 0); floor 400 × 400 | §4 |
| **Site Kestrel** (later phases) | Origin (−6000, −400, 0) | `map_04` |

**Separation rule:** nothing from the hub can be seen from the Outpost and vice versa (≥ 3,500 studs apart plus fog). Invisible walls (`PlayerBarrier`, `FrameBarrier`) keep players inside the playable areas.

## 2. Zones for `ZoneService` (`Shared/Config/Zones.lua`)

Axis-aligned boxes (min, max). When boxes overlap, the first match in this list wins (interiors before exteriors).

| ZoneId | Min | Max | Lighting | Reverb | Weapons |
|---|---|---|---|---|---|
| `Quarters` | (−131, −1, −1) | (−79, 13, 41) | hub preset | Room | n/a |
| `Briefing` | (−131, −1, −41) | (−79, 17, 1) | hub | Room | n/a |
| `Medical` | (79, −1, −1) | (131, 19, 41) | hub | Room | n/a |
| `Equipment` | (79, −1, −41) | (131, 19, 1) | hub | Room | n/a |
| `Research` | (79, −1, −61) | (251, 13, −19) | hub | Hallway | n/a |
| `OpsHall` | (−61, −1, −41) | (61, 37, 41) | hub | Hallway | n/a |
| `Corridors` | (−81, −1, −71) | (81, 21, 61) | hub | Hallway | n/a |
| `Arrival` | (−100, −1, 39) | (100, 25, 150) | hub | City | n/a |
| `ObservationDeck` | (59, 19, −41) | (141, 40, 61) | hub | City | n/a |
| `Hangar` | (−121, −1, −231) | (121, 91, −69) | hub | Hangar | **Locked** |
| `LaunchArea` | (121, −1, −200) | (460, 130, −100) | hub | City | **Locked** |
| `TrainingYard` | (−420, −1, −300) | (−121, 120, −40) | hub | City | Free |
| `HubExterior` | (−1400, −50, −1000) | (2000, 400, 1400) | hub | City | Locked |
| `Bunker` | (5958, −1, −62) | (6042, 15, 2) | OVERCAST | StoneRoom | n/a |
| `Basin` | (5780, −40, −760) | (6360, 120, −400) | OVERCAST | Quarry | Free |
| `Trail` | (5900, −20, −400) | (6100, 80, −160) | OVERCAST | Plain | Free |
| `Outpost` | (5500, −50, −170) | (6500, 300, 650) | OVERCAST | Plain | Free |
| `Memory` | (−250, 1950, −250) | (250, 2200, 250) | MEMORY | Arena | Locked |

"Hub preset" = the current story preset (MORNING / EVENING / NIGHT) set by the sequence.

## 3. Backdrops (`builders/maps/backdrops/`, budget 2,500 parts total, **no shadows**, all `CanCollide = false`, `CanQuery = false`, `CastShadow = false`)

### 3.1 City (New Halden)
- **Blocks:** 180–240 building masses (seeded RNG, seed `1187`) placed on a loose grid with 40-stud streets. Footprints 20–80 × 20–80, heights 30–160 (taller toward the far west). Material `Concrete`, colors varying `CONCRETE_MID` / `CONCRETE_DARK` / `#5A5F66` ±3%.
- **Windows:** per building, 2–4 Neon strips per face (0.4 tall, building width − 4), transparency 0.35, color `AMBER_LAMP`. Strips toggle by preset: MORNING 10% visible, EVENING 60%, NIGHT 85% (client sets transparency 1 for hidden strips; deterministic per strip from seed).
- **Rooftops:** 30% get a "garden net" (a 0.2-thick green-grey `#5D6650` plate on 4 posts); 15% get antenna masts with a red Neon blinker (client blink 0.8 Hz); 6 smokestacks (cylinders Ø8 × 60, with a slow smoke emitter: Rate 2, large and faint).
- **Elevated rail viaduct:** continues the arrival rail line west (X −600 → −1400) at Y 20 on pillars every 60.
- **Silhouette rule:** a lively skyline with no single landmark that competes with the Bulwark.

### 3.2 Wilderness (seen from the launch platform, the causeway and the Observation Deck)
- **Ground plates** (512 × 512 tiles) from X 450 to 2000: `Ground` (`GROUND`) with `ASH_DARK` patches (flat plates 0.05 above), slight rolling hills made of 60–200-stud wedges at 5–12° slopes.
- **Dead forest clusters:** 14 clusters of 6–12 dead trees (simplified 3–4-part trees, `TREE_DEAD`).
- **Ruined city silhouette** at X 1400…1900, Z −600…400: 18 broken tower blocks (40–140 tall), several tilted 5–15°, with jagged tops (wedges) and window holes (dark inset strips), `#4E5257`.
- **Distant Titan silhouette:** one static 70-stud humanoid figure made of 12 dark parts (`#2F2C2A`), standing in haze at (1600, 0, −300), facing south. It's barely visible. **It never moves** (environmental dread).
- **Ash particles** drift east → west near the Bulwark (one large emitter part above the wall, Rate 30, `ASH`).

### 3.3 Bulwark wall: see `map_02` §8.

## 4. MemorySet (anomaly vision)
- Center (0, 2000, 0). Floor 400 × 1 × 400 (top at Y 2000), `SmoothPlastic` `#EAF6F8`.
- **Street-lamp line:** 12 lamp posts (StreetLamp prop, painted `#DDE9F2`) along X = −6, from Z 60 to Z −160 every 20 studs; each with a PointLight (`#DFF8FB`, Brightness 1, Range 16).
- **Faint ground line:** a 1-wide, 0.05-tall strip along X = 0 from Z 70 to −180, `#CFEFF5`.
- **Silhouettes:** `Memory_Man` (R15 from CharacterKit, all body parts `#2A2D31`, no face decal, no gear, height scale 1.05) and `Memory_Child` (same, height scale 0.6, width 0.85). They hold hands (procedural: the man's LeftShoulder (10, 0, −15) and the child's RightShoulder (−50, 0, 20), positioned so the hands meet). Spawn at (0, 2000, 40) and (−1.6, 2000, 40), facing −Z; during the cinematic they walk to Z −120 at 6 studs/s.
- **Camera:** dolly from (8, 2004, 70) looking at (0, 2003, 30) → (6, 2004, 20) looking at (0, 2003, −20) over 8 s.
- Lighting preset `MEMORY`; music low-pass; ambient sound off.

## 5. Spawn ID registry (all zones)

| SpawnId | CFrame (position; facing) | Purpose |
|---|---|---|
| `SPAWN_Q3_DESK` | (−118, 0, 5) facing −Z | S01 start |
| `SPAWN_QH` | (−100, 0, 20) facing +X | Quarters hallway (CH1_COMPLETE) |
| `SPAWN_BRF_DOOR` | (−84, 0, −20) facing +X | After the briefing |
| `SEAT_BRF_ELIAS` / `SEAT_BRF_MARA` | (−103, 1, −25) / (−103, 1, −27.5), facing −X | Briefing seats |
| `SPAWN_OPS` | (0, 0, 20) facing −Z | Debug |
| `SPAWN_HANGAR_FLOOR` | (0, 0, −172) facing −Z | S40 return |
| `SPAWN_MED_DOOR` | (86, 0, 20) facing +X | After medical |
| `SPAWN_DECK` | (105, 20, 0) facing +X | Debug |
| `SPAWN_TRAINING` | (−200, 0, −110) facing −X | Training Yard |
| `FRAME_BAY1` / `FRAME_BAY2` / `FRAME_BAY3` | (−70, 0, −205) / (0, 0, −205) / (70, 0, −205), facing +Z | Parked Frames |
| `FRAME_OP_START_02` / `_01` | O + (10, 0, 560) / O + (−14, 0, 566), facing −Z | Outpost arrival |
| `FRAME_OP_FIGHT` | O + (0, −12, −445) facing −Z | M01_FIGHT |
| `FRAME_OP_POSTFIGHT` | O + (20, −12, −520) facing −Z | M01_TITAN_DOWN |
| `FRAME_OP_NORTHGATE` | O + (0, 0, −150) facing −Z | M01_TRAIL |
| `FRAME_OP_BREAKER` | O + (−70, 0, −115) facing −X | M01_POWER |
| `SPAWN_OP_BUNKER` | O + (0, 0, −30) facing −Z | M01_COMMS |
| `TITAN_STRIDER_DORMANT` | O + (−60, −12, −580) facing −Z (back to the player's approach) | Strider start |
| `TITAN_WATCHER_W0` | O + (290, 30, −560) facing −X | Watcher start |
| `SPAWN_MEMORY` | (0, 2000, 70) | MemorySet |
