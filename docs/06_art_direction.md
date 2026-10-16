# 06 — Art Direction (style, scale, palette, materials, lighting, VFX)

## 1. Style statement

**"High-detail Roblox showcase, built from parts."** Chunky readable silhouettes, crisp panel lines, deliberate color blocking, dramatic lighting. People are classic Roblox avatars. Titans are **uncanny**: lanky proportions, smooth ashen skin, exposed sinew, wide lipless mouths, small too-human eyes. Frames are **industrial and heavy**: plating, pistons, bolts, hazard markings, glowing core vents. The world is **grey concrete and steel warmed by amber light**, with ash in the air.

Three words: **Heavy. Worn. Warm-under-grey.**

### Do
- Sell scale with human-sized details on giant things: railings, ladders, signs, doors, technicians next to 40-stud Frames.
- Chamfer big blocks: 0.5–1 stud wedges on top edges of walls, plinths and armor plates.
- Break large surfaces: anything over 20 × 20 studs gets panel seams, trim bands, pilasters, pipes, vents or signage.
- Use **value contrast** for readability: dark floors, mid walls, bright accents and lights.
- Ground everything: 1-stud dark kickplates at wall bases, grime strips under vents, dust near doors.

### Don't
- Big flat untextured walls. Random rainbow colors. Neon everywhere (Neon only for lights, screens, glows, indicators). Floating parts. Z-fighting (overlapping coplanar faces: offset decals and seams by 0.02–0.05).
- **Cyan anywhere except Lattice resonance moments.** This is a storytelling color.

**Glows (D-099):** Roblox's Neon brightens a color, so a Neon part in `AMBER` shows as lemon yellow. A part meant to *glow amber* (status strips, lamps, indicators, holograms) is drawn with BuildKit's `BK.GLOW` (`WARNING_ORANGE` in Neon at 0.4, holograms 0.6), which shows on screen as `AMBER`. Lights, paint, text and UI keep `AMBER` itself.

## 2. Scale chart (canon)

| Thing | Studs | Notes |
|---|---|---|
| 1 stud | 0.33 m | Lore conversion |
| Human (R15 default) | 5.5 tall | Eye height ~4.8 |
| Human door | 5 wide × 8 tall | Double door 8 × 9 |
| Corridor | 10 wide (main), 7 (secondary) | |
| Room ceiling | 12–16 (min 12) | Ops Hall 36, Hangar 90 |
| Stair step | rise 1, run 1.5 | Width ≥ 6. Landing every 14 steps max |
| Railing | 3.5 tall | Posts every 4–6 studs |
| Catwalk | 6–8 wide | DiamondPlate |
| Table / console | 2.6–3 tall | |
| Vanguard Frame | 40 tall | Shoulder width 16 (29 with pauldrons) |
| Frame door | 50–60 wide × 60–75 tall | |
| Strider Titan | 56 tall | |
| The Watcher | 68 tall | |
| Bulwark wall | 120 tall, 30 thick | |
| Outpost perimeter wall | 18 tall, 4 thick | Frames step through gates and breaches |
| Frame stride (one step) | ~11 | Footprint 7 × 10 |
| Strider footprint | 6 × 12 | Watcher footprint 7 × 14 |

## 3. Master palette (hex). Use only these.

### Architecture
| Key | Hex | Use |
|---|---|---|
| `CONCRETE_LIGHT` | `#8A8F94` | Exterior walls, upper |
| `CONCRETE_MID` | `#6E7378` | Exterior walls, main |
| `CONCRETE_DARK` | `#4F5459` | Plinths, bases, kickplates (exterior) |
| `WALL_INTERIOR` | `#A7ADB2` | Interior walls |
| `WALL_INTERIOR_LOW` | `#7C838A` | Interior wainscot (lower 3 studs) |
| `FLOOR_INTERIOR` | `#50565C` | Polished interior floors |
| `FLOOR_HANGAR` | `#3A3D42` | Hangar and industrial floors |
| `KICKPLATE` | `#2E3236` | Dark base strips |
| `STEEL_DARK` | `#2A2D31` | Structural steel, frames, machine internals |
| `STEEL_MID` | `#4A4F55` | Catwalks, decks, panels |
| `STEEL_LIGHT` | `#9AA1A6` | Pistons, rails, bright metal |
| `SLATE` | `#4A5A6A` | Division trim, banners |
| `SLATE_DEEP` | `#3B4A5A` | Officer coats, banners |
| `HAZARD_YELLOW` | `#E8B923` | Safety lines, stripes |
| `HAZARD_BLACK` | `#1B1D20` | Stripe pairs |
| `GLASS` | `#9FB4C4` | Windows (Glass material, Transparency 0.55) |
| `MEDICAL_WHITE` | `#E6E8EA` | Medical surfaces, lab coats |
| `RUST` | `#8A4B2A` | Outpost metal |
| `RUST_DARK` | `#5E3520` | Deep rust, stains |
| `WOOD_OLD` | `#6A5440` | Crates, pallets |
| `FABRIC_DARK` | `#33383F` | Seats, mattresses |

### Light and signal
| Key | Hex | Use |
|---|---|---|
| `AMBER` | `#E8A33D` | Directorate color, UI accent, signage |
| `AMBER_CORE` | `#FFB347` | Normal Frame core glow |
| `AMBER_LAMP` | `#FFD38A` | Warm lamps |
| `LIGHT_NEUTRAL` | `#FFF1DA` | Ceiling and high-bay lights |
| `LIGHT_COOL` | `#DDE9F2` | Medical, labs, floodlights |
| `WARNING_ORANGE` | `#E07A1F` | Beacons, Elias's accent stripe |
| `DANGER_RED` | `#E5484D` | Alarms, UI danger |
| `EMERGENCY_RED` | `#B3262B` | Emergency lights |
| `SUCCESS_GREEN` | `#46C17A` | UI success only |
| `TITAN_GLOW` | `#FF7A2E` | Feral Titan eyes and core |
| `TITAN_GLOW_DEEP` | `#E25B2D` | Feral veins, crest |
| `LATTICE_CYAN` | `#7FE3F0` | **RESERVED: resonance / Shifters only** |
| `SHIFT_LIGHTNING` | `#FFE14A` | **RESERVED: the lightning of a Shifter's transformation only** (user direction, D-039) |

### Nature (outpost, wilderness)
| Key | Hex | Use |
|---|---|---|
| `GROUND` | `#6B6252` | Dirt ground (Ground material) |
| `MUD_DRY` | `#8C7B66` | Basin floor (Mud material) |
| `MUD_CRACK` | `#5A4E40` | Crack lines |
| `ROCK` | `#6B6660` | Rocks (Rock material) |
| `ROCK_DARK` | `#4E4A45` | Rock shadows, cliff bases (Basalt) |
| `ASH` | `#9C9893` | Ash drifts, Titan death |
| `ASH_DARK` | `#6F6B66` | Old ash fields |
| `GRASS_DEAD` | `#6F6A4A` | Dry grass tufts (LeafyGrass material) |
| `GRASS_SPARSE` | `#556B3A` | Rare living patches |
| `TREE_DEAD` | `#4A3F35` | Dead trees (Wood material) |
| `ASPHALT` | `#3E4044` | Roads (Asphalt material) |
| `ROAD_LINE` | `#C9B98A` | Faded road paint |

### Frames
| Key | Hex | Use |
|---|---|---|
| `VG_ARMOR` | `#5B6770` | Vanguard armor plates (Metal) |
| `VG_ARMOR_DARK` | `#46515A` | Secondary plates |
| `VG_FRAME` | `#2A2D31` | Internals, joints (Metal / DiamondPlate) |
| `VG_HYDRAULIC` | `#9AA1A6` | Pistons |
| `VG_ACCENT_ELIAS` | `#E07A1F` | Unit 02 stripes |
| `VG_ACCENT_MARA` | `#C8483C` | Unit 01 stripes |
| `VG_PRIMER` | `#8A9096` | Unit 03 unpainted plates |
| `VG_VISOR` | `#FFB347` | Sensor visor (Neon, 0.2 transparency) |

### Titans
| Key | Hex | Use |
|---|---|---|
| `TITAN_SKIN_1…5` | `#EAB892`, `#F0C9A8`, `#D9A47C`, `#C68E6A`, `#A8704F` | Human skin tones of Titans, one per Titan (D-056; the first is the tone of the user's model). Replaces `STR_SKIN` on bodies |
| `STR_SKIN` | `#8C8378` | Strider skin (SmoothPlastic) — no longer used on bodies (D-039) |
| `STR_SKIN_SHADE` | `#756D63` | Under-surfaces, ribs |
| `STR_SINEW` | `#5E554C` | Sinew strips |
| `STR_MUSCLE` | `#7A3B33` | Exposed forearm and calf muscle |
| `STR_BONE` | `#CFC6B4` | Bone plates (Limestone) |
| `STR_TEETH` | `#E8E2C8` | Teeth |
| `STR_SOCKET` | `#1B1714` | Eye sockets, mouth interior |
| `WAT_SKIN` | `#3B3A3F` | Watcher skin |
| `WAT_BONE` | `#9A9AA3` | Watcher plates |
| `WAT_GLOW` | `#7FE3F0` | Watcher veins and eyes (Lattice cyan) |

## 4. Materials map

| Surface | Material | Notes |
|---|---|---|
| Exterior walls | `Concrete` | Panel seams every 16 studs |
| Interior walls | `SmoothPlastic` | Wainscot band at 3 studs, `WALL_INTERIOR_LOW` |
| Interior floors | `SmoothPlastic`, Reflectance 0.03 | Floor tile seams every 8 studs (0.1-high strips, `KICKPLATE`) |
| Hangar floor | `Concrete` | Painted lines = thin SmoothPlastic parts 0.05 above |
| Catwalks, stairs, decks | `DiamondPlate` | `STEEL_MID` |
| Structural steel | `Metal` | `STEEL_DARK` |
| Frame armor | `Metal` | Panels inset with `VG_FRAME` seams |
| Frame joints | `DiamondPlate` / `Metal` | |
| Glass | `Glass` | Transparency 0.55 |
| Lights, screens | `Neon` | Screens at 0.3–0.5 transparency with a SurfaceGui on top |
| Fabric (banners, seats) | `Fabric` | |
| Crates | `WoodPlanks` | `WOOD_OLD` |
| Rusted metal | `CorrodedMetal` | Outpost |
| Roads | `Asphalt` | |
| Pavements | `Pavement` | |
| Ground | `Ground` / `Mud` / `Rock` / `Basalt` / `LeafyGrass` | Parts only, no Terrain |
| Titan skin | `SmoothPlastic` | |
| Titan bone | `Limestone` | |

## 5. Lighting presets (`Config/LightingPresets`)

Applied by the client `LightingController`, tweened over 1.5 s (instant during a fade to black). All presets use `Lighting.LightingStyle = Realistic` with `PrioritizeLightingQuality = true` (the scriptable replacement for `Technology = Future`, which scripts can't read or set in current Studio; D-018), `GlobalShadows = true`, and a default `Sky` (Roblox built-in; don't set skybox IDs).

| Property | MORNING (hub) | OVERCAST (outpost) | EVENING (return) | NIGHT (post-ch1) | MEMORY (anomaly) |
|---|---|---|---|---|---|
| ClockTime | 7.2 | 15.2 | 18.9 | 22.5 | 12 |
| GeographicLatitude | 41 | 41 | 41 | 41 | 41 |
| Brightness | 2.2 | 1.4 | 1.2 | 0.6 | 3 |
| Ambient | `#3A3F47` | `#40444A` | `#3A3340` | `#262B36` | `#DFF8FB` |
| OutdoorAmbient | `#7A8088` | `#808489` | `#6B5E66` | `#2E3442` | `#FFFFFF` |
| ColorShift_Top | `#FFE2C0` | `#D9DDE2` | `#FF9E5E` | `#9FB4FF` | `#FFFFFF` |
| EnvironmentDiffuseScale | 0.6 | 0.5 | 0.5 | 0.4 | 1 |
| EnvironmentSpecularScale | 0.6 | 0.4 | 0.6 | 0.5 | 0 |
| ExposureCompensation | 0.1 | 0 | 0.1 | 0.2 | 0.4 |
| ShadowSoftness | 0.25 | 0.5 | 0.3 | 0.2 | 1 |
| Atmosphere Density | 0.32 | 0.42 | 0.36 | 0.38 | 0.6 |
| Atmosphere Offset | 0.15 | 0.05 | 0.10 | 0.0 | 0.3 |
| Atmosphere Color | `#C9C2B6` | `#BFC3C8` | `#D79A72` | `#2A3140` | `#E8FBFF` |
| Atmosphere Decay | `#8C8478` | `#8E8778` | `#5E4A5A` | `#121620` | `#CFEFF5` |
| Atmosphere Glare | 0.4 | 0 | 0.6 | 0 | 0 |
| Atmosphere Haze | 1.6 | 2.2 | 1.8 | 1.2 | 3 |
| CC Brightness | 0.02 | 0 | 0.02 | 0 | 0.1 |
| CC Contrast | 0.08 | 0.10 | 0.12 | 0.14 | −0.1 |
| CC Saturation | −0.12 | −0.28 | −0.05 | −0.15 | −0.6 |
| CC TintColor | `#FFF6EC` | `#E9ECEF` | `#FFE7D6` | `#D8E2FF` | `#E0FAFF` |
| Bloom Intensity / Size / Threshold | 0.6 / 24 / 1.6 | 0.4 / 24 / 1.8 | 0.8 / 28 / 1.4 | 1.0 / 30 / 1.2 | 1.4 / 40 / 0.9 |
| SunRays Intensity / Spread | 0.06 / 0.6 | 0 / 0 | 0.10 / 0.7 | 0 / 0 | 0 / 0 |

**DepthOfField:** disabled in gameplay. Enabled only in cinematics (`FarIntensity 0.25`, `NearIntensity 0`, `FocusDistance` = distance to the shot target, `InFocusRadius 30`).

### Interior light rules
| Space | Fixture | Light settings |
|---|---|---|
| Ops Hall | Ceiling Neon strips (0.4 × 0.2 × 16) every 12 studs | SurfaceLight Face=Bottom, Color `LIGHT_NEUTRAL`, Brightness 1.2, Range 24, Angle 120, Shadows false (1 in 3 strips: Shadows true) |
| Corridors | Neon strips 0.3 × 0.15 × 6 every 10 studs | SurfaceLight Brightness 1, Range 16, Shadows false |
| Quarters | Desk lamp + ceiling panel | PointLight `AMBER_LAMP` Brightness 0.8 Range 14 Shadows true (lamp); ceiling SurfaceLight Brightness 0.5 |
| Medical | Panels 4 × 0.2 × 4 | SurfaceLight `LIGHT_COOL` Brightness 1.4 Range 18 |
| Briefing | Strips plus screen glow | Brightness 1.0, dims to 0.35 during the briefing cinematic |
| Hangar | See `map_02` | |
| Outpost (powered) | Wall lamps, floodlights | SpotLight `AMBER_LAMP` Brightness 1.5 Range 30 Angle 60; disabled until power is restored (tag `OutpostLight`) |
| Emergency | Red caged lamps | PointLight `EMERGENCY_RED` Brightness 0.8 Range 12; on before power, dim after |

**Roblox limit:** `Range` on Point/Spot/Surface lights is **max 60 studs**. Lights in tall spaces (the hangar, the Ops Hall) must hang low enough to reach the floor (pendants), or be supplemented with wall-mounted fixtures.

**Shadow budget:** at most **24 shadow-casting lights** visible within any 150-stud radius. Small fixtures use `Shadows = false`. Tiny detail parts (every dimension < 0.5) use `CastShadow = false`.

## 6. VFX vocabulary (`Shared/Modules/VFX`)

Built-in textures only: `rbxasset://textures/particles/sparkles_main.dds`, `rbxasset://textures/particles/smoke_main.dds`, `rbxasset://textures/particles/fire_main.dds`. **Verify each loads in Studio during Phase 1.** If one fails, use the ParticleEmitter default texture and log it in `decisions.md`.

| Effect | Construction | Key settings |
|---|---|---|
| **Sparks** | ParticleEmitter (sparkles texture) | Color `#FFD38A`→`#E07A1F`, Size 0.25→0, Lifetime 0.3–0.6, Speed 15–30, SpreadAngle 60, Acceleration (0,−60,0), LightEmission 1, burst via `:Emit(25)` |
| **Smoke (damage)** | ParticleEmitter (smoke) | Color `#3A3D42`, Size 3→8, Transparency 0.4→1, Lifetime 2–3, Speed 4–8, Rate 12, RotSpeed ±30 |
| **Dust puff (Frame step)** | ParticleEmitter (smoke) at the foot | Color `#8C7B66` (outdoor) / `#5A5E63` (hangar), Size 2→6, Lifetime 0.8–1.2, Speed 6–10, SpreadAngle (80, 10), `:Emit(14)` |
| **Shockwave ring** | Flat Cylinder part (0.4 thick), SmoothPlastic, color `#CFC6B4` | Size 2→(2R) over 0.35 s, Transparency 0.3→1, plus 30 dust particles |
| **Blade trail** | Trail between 2 Attachments on the blade (base and tip) | Color `#FFF1DA`→`#E8A33D`, Transparency 0.2→1, Lifetime 0.15, LightEmission 0.6; enabled only during an attack's active window |
| **Hit flash (Titan)** | Highlight on the Titan model | FillColor white, FillTransparency 0.6→1 over 0.08 s, OutlineTransparency 1 |
| **Hit sparks / ichor** | ParticleEmitter at the hit point | Titan: color `#E8E2C8` and `#9C9893` "bone dust" (no blood). Frame: sparks |
| **Core glow pulse** | Neon parts + PointLight | Brightness oscillates 1.0↔1.6, period 2.4 s (sine). Unit 03 pulse period 1.6 s (clue 2) |
| **Ash flakes (ambient)** | ParticleEmitter on a client part that follows the camera (40 × 1 × 40, 30 studs up) | Color `#9C9893`, Size 0.1–0.2, Lifetime 8, Speed 1–3, Acceleration (2,−1.5,0), Rate 40 outdoor / 0 indoor |
| **Titan regen** | ParticleEmitter on the body | Color `#9C9893`, Size 1→3, Transparency 0.6→1, Rate 6, only while regenerating |
| **Ash collapse (death)** | See `10_titans.md` §8 | |
| **Resonance ping** | Screen effect (UI) plus a world sphere | Ball part, Neon cyan, Size 2→120 over 0.6 s, Transparency 0.5→1 (client) |
| **Shifter transformation** (user direction, D-039; built with the first on-screen shift, not in the Vertical Slice unless a scene needs it) | A jagged bolt from the sky to the Shifter: 6–9 Neon segments `SHIFT_LIGHTNING` with 2–3 short forks, redrawn 3 times; a full-screen yellow-white flash (UI); a ground ring and dust; a PointLight burst | Bolt visible 0.35 s; flash 0.12 s up, 0.6 s down (**Reduce Flashing: flash at 30%**); light Brightness 8 → 0, Range 60; sound `SFX_SHIFT_THUNDER`; the human model is swapped for the Titan while the screen is white |
| **Beacon spin** | SpotLight in a rotating housing (client TweenService loop, 1.2 s/rev) | `WARNING_ORANGE`, Brightness 4, Range 40, Angle 40 |

### Camera feel parameters (`Config/CameraFeel`)
| Event | Shake magnitude | Duration | Other |
|---|---|---|---|
| Vanguard footstep (pilot view) | 0.08 | 0.15 s | — |
| Strider footstep within 80 studs | 0.15 | 0.2 s | Falloff: linear to 0 at 160 studs |
| Light hit landed | 0.12 | 0.1 s | Hitstop 0.05 s |
| Heavy hit landed | 0.3 | 0.18 s | Hitstop 0.09 s, FOV punch −3 |
| Pile Driver landed | 0.45 | 0.25 s | Hitstop 0.12 s, FOV punch −5 |
| Core Strike | 0.6 | 0.4 s | Hitstop 0.15 s, FOV punch −7 |
| Player hit (light / heavy) | 0.25 / 0.5 | 0.2 / 0.35 s | Red edge vignette |
| Roar | 0.6 | 1.2 s | |
| Strider stomp within 40 | 0.7 | 0.4 s | |

The Settings "Camera Shake" slider (0–100%) multiplies all magnitudes.

## 7. Signage and screens

- SurfaceGui with `SizingMode = PixelsPerStud`, `PixelsPerStud = 50`, `LightInfluence = 0` for screens (self-lit), `0.6` for painted signs.
- **Fonts:** headers `Enum.Font.Michroma`, body `Enum.Font.TitilliumWeb` (SemiBold via FontFace weight), data and mono `Enum.Font.RobotoMono`. Fallbacks: `GothamBold`, `Gotham`, `Code` (log any fallback in `decisions.md`).
- **Sign colors:** amber text on `SLATE_DEEP`, or white `#E8ECEF` on `SLATE`. Hazard signs: black on `HAZARD_YELLOW`.
- **Painted floor text:** SurfaceGui on a thin part 0.05 above the floor, text color `HAZARD_YELLOW` at 0.15 transparency.
- **Text standard:** ALL CAPS for signage; sentence case for terminals.

**Sign list (minimum):** "FRAME HANGAR — AUTHORIZED PERSONNEL", "BRIEFING ROOM ONE", "PILOT QUARTERS", "MEDICAL", "EQUIPMENT / QUARTERMASTER", "RESTRICTED — SCIENCE DIVISION — CLEARANCE 3", "OBSERVATION DECK", "ARRIVALS — PLATFORM 1", "LAUNCH 1", "BAY 01 / 02 / 03", "SAFE VIEWING LINE — DO NOT CROSS", "THIRD FRONTIER FRAME DIVISION", plus 6 propaganda posters (`02_world_and_lore.md` §2).

## 8. Silhouette tests (run during Phase 7)

From 200 studs away in fog: the Vanguard reads as "heavy humanoid machine with big shoulders and a blade," the Strider as "too-tall thin creature with long arms," and the Watcher as "even taller, darker, with glowing lines." If not, adjust shapes, not colors.
