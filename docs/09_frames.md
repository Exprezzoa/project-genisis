# 09 — Frames (Vanguard full spec, unit variants, ally AI, future classes)

Base rig dimensions and joints: `08_rigs_and_animation.md` §3.1. Colors: `06_art_direction.md` §3 (Frames). Combat numbers: `12_combat_system.md` (authoritative; duplicated here for convenience).

---

## 1. Vanguard — design brief

> **Scale note (user direction 2026-10-10, D-044).** The Vanguard is built **1.6 × the size written in this document: 64 studs tall** instead of 40. Every length, position, speed, range and box given here for the Vanguard is the 40-stud number; the game uses it × 1.6. The config files write it that way (`30 * S`), and the rig builder builds the 40-stud model and scales it. Times, angles, damage, energy and poise are unchanged.

- **Role:** balanced close-range melee. The most accessible Frame.
- **Silhouette:** heavy blocky torso, **oversized pauldrons**, thick forearms, digitigrade-free straight legs with big feet, a small sensor head with a single horizontal **amber visor**, the **Breaker Blade** (a giant industrial cleaver) in the right hand, and a **Pile Driver** spike launcher on the left forearm.
- **Personality in motion:** deliberate, grounded, every step a thud. Attacks have clear windups. When it stops, it settles (0.2 s of Root bob overshoot).
- **Height 64 studs** (40 × 1.6, see the scale note). Width ~50 with pauldrons. **Budget ≤ 1,500 parts** (raised from 450 for the detail pass, D-041; the first build is 1,291).

## 2. Part-by-part build (`builders/rigs/Vanguard/`)

### Form language (user direction 2026-10-10, D-041) — overrides the box shapes in the tables below

The user asked for Frames that "go all out with attention to detail like wires" with "smooth ridges instead of blocky". The tables below still give each element's **name, place, rough size and color**; its **shape** now follows these rules, and the builder is the reference for exact numbers.

- **The main parts are invisible bones.** They keep the sizes, centers and joints of `08` §3.1 (poses, hitboxes and the rig check depend on them), but nothing of them is drawn. Everything visible is a detail welded to a bone.
- **Round, not boxy.** Limbs are cylinders with rolled rims and seam rings. Armor over them is **curved**: flat staves set round a barrel, tapered where the limb tapers, with a raised spine and a rolled rim top and bottom. The chest is a barrel lying across the shoulders with curved pec, belly and back plates on a ribbed waist. Pauldrons are drums with a painted accent band, vent slots and a domed cap. Flat plates (skirts, cheeks, hatch panel) have their edges rounded over. Small domes (knee caps, elbow guards, helmet) are ellipsoids made with the engine's built-in sphere mesh (no asset).
- **Smooth ridges** are runs of thin cylinders with a ball in each bend, following the curve they sit on.
- **Machinery shows in the gaps:** ball joints, joint drums with covers and pins, pistons (dark sleeve, bright rod, gland ring, an eye at each end), round rivet heads.
- **Wires and hoses** on every limb, a three-cable bundle under each flank, coolant lines, the Pile Driver's gas line and feed hose, a power feed on the blade. Cables that **cross a joint** (knees, elbows, neck) are camera-facing `Beam`s between the two parts, so they bend with the joint.
- **Materials:** flat armor and all dark steel are `Metal`; **curved armor is `SmoothPlastic`**, because a round Metal surface mirrors the sky and ground and reads as black instead of its armor color.
- **Not hand-detailed:** nothing here is modeled outside Studio or imported; it is all parts.
- The builder is split by body region: `init` (bones, joints, Humanoid), `Kit` (the shapes), `Legs`, `Torso`, `Arms` (with the Breaker Blade).

Every detail part is welded to the listed main part. Positions are relative to that main part's center, in model space (rig facing −Z, so **front = −Z**). Mirror Left/Right where noted. Approximate part counts are in brackets.

### Feet (each) [18]
| Part | Size | Offset | Color / Material |
|---|---|---|---|
| Foot core | 6 × 3 × 10 | main | `VG_FRAME` Metal |
| Toe armor (wedge, slope to the front) | 6 × 2 × 3 | (0, 0.5, −3.5) | `VG_ARMOR` Metal |
| Heel block | 5 × 2.5 × 2.5 | (0, 0.25, 3.8) | `VG_ARMOR_DARK` |
| Side plates (×2) | 0.5 × 2 × 7 | (±3.1, 0.3, −0.5) | `VG_ARMOR` |
| Sole tread strips (×4) | 5.8 × 0.3 × 1 | (0, −1.4, −3.5 / −1.5 / 0.5 / 2.5) | `KICKPLATE` |
| Ankle collar (cylinder, axis Y) | Ø5 × 1.5 | (0, 1.8, 1.5) | `STEEL_DARK` |
| Achilles piston (cylinder, axis Y) | Ø0.8 × 3 | (0, 2.5, 3.2) | `VG_HYDRAULIC` |
| Bolts (×6) | 0.4 cube | on the toe armor and heel | `STEEL_LIGHT` |

### Lower legs (each) [30]
| Part | Size | Offset | Color |
|---|---|---|---|
| Main part (strut) | 5 × 9 × 5.5 | main | `VG_FRAME` |
| Shin guard | 5.4 × 7 × 1.2 | (0, 0.5, −2.6) | `VG_ARMOR` |
| Shin top chamfer (wedge) | 5.4 × 1 × 1.2 | (0, 4.5, −2.6) | `VG_ARMOR` |
| Accent stripe (vertical) | 0.6 × 5 × 0.1 | (−1.6, 0.5, −3.25) (outer side) | `VG_ACCENT_*` SmoothPlastic |
| Calf armor | 4.5 × 5 × 1 | (0, 1, 2.5) | `VG_ARMOR_DARK` |
| Side pistons (×2, cylinder axis Y) | Ø0.9 × 6 | (±2.6, 0, 1) | `VG_HYDRAULIC` |
| Knee cap (block plus 2 wedges) | 4 × 3 × 2 | (0, 4.2, −2.4) | `VG_ARMOR` |
| Calf vent (3 slats) | 2.4 × 0.3 × 0.3 each | (0, −1 / −1.6 / −2.2, 3.05) | `STEEL_DARK` |
| Bolts (×6), greebles (×4 small boxes) | | sides | |

### Upper legs (each) [22]
Thigh core 4.5 × 8 × 4.5 (`VG_FRAME`); front thigh plate 5.6 × 6 × 1 at (0, 0, −2.6) (`VG_ARMOR`) with a bottom chamfer; outer side plate 1 × 6 × 5 at (∓2.9, 0, 0) (`VG_ARMOR_DARK`); hip joint drum (cylinder axis X) Ø4 × 6 at (0, 3.5, 0) (`STEEL_DARK`); rear actuator piston Ø1 × 6 at (0, 0, 2.6); 6 bolts; 2 greebles.

### LowerTorso / pelvis [25]
Pelvis block 12 × 4 × 8 (`VG_FRAME`); codpiece armor 6 × 3.5 × 1.2 at (0, −0.2, −4.4) with 2 side chamfers (`VG_ARMOR`); side skirt plates (×2) 1 × 4.5 × 6 at (±6.4, −1.5, 0) (`VG_ARMOR`); rear plate 10 × 3 × 1 at (0, 0, 4.3) (`VG_ARMOR_DARK`); waist ring 10 × 1 × 7 at (0, 2.2, 0) (`STEEL_DARK`); 8 bolts; 4 greebles.

### UpperTorso / chest [70]
| Part | Size | Offset | Color |
|---|---|---|---|
| Chest core | 16 × 11 × 10 | main | `VG_FRAME` |
| Pec plates (×2, tilted 8° outward) | 7 × 5 × 1.5 | (±4.6, 2, −5.4) | `VG_ARMOR` |
| **Cockpit hatch** (separate part `Hatch`, Motor6D `HatchHinge`) | 6 × 6 × 0.6 | (0, 1.5, −5.3) | `VG_ARMOR_DARK`, handle bar 2 × 0.3 × 0.3 `HAZARD_YELLOW` |
| Hatch frame (4 thin parts) | 0.4 wide | around the hatch | `STEEL_DARK` |
| **Core vents** (×2, Neon) | 1.2 × 5 × 0.3 | (±3.9, −1.2, −5.6) | `AMBER_CORE` Neon; 3 louver slats each in `STEEL_DARK` |
| Abdominal plates (×3 stacked) | 10 × 1.8 × 1 | (0, −3.2 / −4.3 / −5.4 + 1, −5.2) | `VG_ARMOR_DARK` |
| Collar ridge | 12 × 1.5 × 3 | (0, 5.2, −3) | `VG_ARMOR` |
| Back core housing ring (cylinder axis Z) | Ø6 × 1.5 | (0, 0.5, 5.6) | `STEEL_DARK` |
| Back core disc (Neon, cylinder axis Z) | Ø4 × 0.4 | (0, 0.5, 6.4) | `AMBER_CORE` + PointLight (Brightness 1.2, Range 18, `AMBER_CORE`) |
| Thruster nozzles (×2, cylinder pointing down-back 20°) | Ø3 × 4 | (±4, −3, 6.2) | `STEEL_DARK`, inner Ø2 disc `KICKPLATE`; fire emitter attachment (Dodge) |
| Coolant tanks (×2, cylinder axis Y) | Ø2 × 7 | (±6, 1, 5.6) | `VG_HYDRAULIC` |
| Radiator fins (×6) | 0.2 × 4 × 2 | back center | `STEEL_MID` |
| Antenna (cylinder) | Ø0.3 × 6 | (5, 7, 4) | `STEEL_LIGHT`, tip Neon `AMBER` 0.4 ball |
| Unit number | SurfaceGui | chest right side face (+X) | Michroma, white `#E8ECEF`, "02" |
| Accent stripe | 4 × 0.6 × 0.1 | (−5, 4.2, −6.2) | `VG_ACCENT_*` |
| **PilotSeat** (Seat) | 2 × 1 × 2 | (0, −0.5, 0) inside | Transparency 1, CanCollide false, CanTouch false |
| Greebles / bolts | ~20 | seams and edges | |

### Head [25]
Head block 5 × 5 × 5.5 (`VG_FRAME`); helmet top plate 5.4 × 1 × 6 at (0, 2.6, 0.2) (`VG_ARMOR`); side plates (×2) 0.6 × 4 × 5 at (±2.8, 0.3, 0.2); brow wedge 5 × 1 × 1.5 at (0, 1.4, −3) (`VG_ARMOR`); **visor** Neon 3.6 × 0.8 × 0.2 at (0, 0.5, −2.85) (`VG_VISOR`, transparency 0.2) with a SurfaceLight (front face, Brightness 0.6, Range 10, `AMBER_CORE`); chin guard 4 × 1.2 × 1 at (0, −1.9, −2.6); sensor ears (×2, cylinder axis X) Ø1.2 × 1 at (±3.1, 0, 0); head fin wedge 0.3 × 3 × 1.5 at (−1.8, 3.6, 0.5) in `VG_ACCENT_*`; camera lens ball Ø0.6 Neon at (1.4, −0.9, −2.9).

### Upper arms (each) [18] and pauldrons (each, welded to UpperArm) [14]
- Upper arm core 3.5 × 10 × 3.5; sleeve plates front and back 4.4 × 7 × 0.8; bicep piston Ø0.9 × 6 at (0, −1, −2.4); elbow drum (cylinder axis X) Ø4.2 × 4.6 at (0, −5, 0).
- **Pauldron:** shell 7.5 × 4.5 × 9 centered at (∓0.5, 6.5, 0) relative to the UpperArm (so it sits over the shoulder at Y ≈ 33.5 world) in `VG_ARMOR`; top chamfers (2 wedges, 7.5 × 1 × 2) on the front and back edges; lower lip 7.5 × 1 × 9.4 at (∓0.5, 3.8, 0) `VG_ARMOR_DARK`; accent stripe 1 × 0.1 × 9 across the top in `VG_ACCENT_*`; unit-number SurfaceGui on the outer face; 4 bolts; marker light (0.4 Neon `AMBER`).

### Lower arms (each) [20]
Core 4 × 9 × 4; forearm armor shell = 4 plates (5.2 × 7 × 0.6 front, back, and both sides) `VG_ARMOR`; wrist ring (cylinder axis Y) Ø4.6 × 1 at (0, −4.2, 0) `STEEL_DARK`; elbow guard wedge at the top back.
- **Right forearm:** blade mount bracket 1.5 × 3 × 1.5 on the inner side.
- **Left forearm: Pile Driver** [14]: casing (cylinder axis Y) Ø3.2 × 8 at (−4.1, −0.5, 0) (outer side) `STEEL_DARK` with 3 `HAZARD_YELLOW` rings (0.2 thick); spike = separate part `PD_Spike` (cylinder axis Y) Ø1.4 × 7 in `STEEL_LIGHT`, rest position (−4.1, −3.5, 0), joined by Motor6D `PileDriver` (LowerArm → PD_Spike); thrust = position offset (0, −6, 0); spike tip = 4 wedges forming a point; 2 steam vent nubs (steam emitter, smoke texture, white, burst on `SteamBurst`).

### Hands (each) [16]
Palm 4 × 3 × 3.5; 4 finger blocks 0.9 × 2.2 × 1.2 curled (rotated 70° on X, front-lower); thumb wedge; knuckle guard 4.2 × 1 × 1 `VG_ARMOR`. The right hand gets the part `Prompt_Board` (invisible 3 × 3 × 3) used as the on-foot boarding prompt when the Frame kneels.

### Breaker Blade [25] (Model `BreakerBlade`)
| Part | Size | Notes |
|---|---|---|
| `Blade_Grip` (Motor6D Part1) | 1.5 × 6 × 1.5 | `STEEL_DARK`, 3 wrap rings (cylinders Ø1.7 × 0.4) |
| Pommel | 2 × 1.2 × 2 | at the grip's −Y end |
| Guard | 6 × 1.5 × 3 | at the grip's +Y end, `VG_ARMOR` |
| Blade body | 2 × 28 × 7 | from the guard along +Y (its center 15 studs from the grip center), `STEEL_MID` Metal |
| Cutting edge | 0.4 × 28 × 1.2 | along the blade's −Z long side, `STEEL_LIGHT`, Reflectance 0.1 |
| Spine ridge | 2.4 × 26 × 1 | along the +Z side, `VG_FRAME` |
| Cleaver tip | wedge 2 × 4 × 7 | angled tip |
| Hazard stripes | 2 bands near the guard | `HAZARD_YELLOW` / `HAZARD_BLACK` |
| Serial stencil | SurfaceGui | "BRK-7" |
| Trail attachments | `TrailBase` 2 studs past the guard, `TrailTip` at the tip | Trail settings in `06_art_direction.md` §6 |

**BladeGrip Motor6D:** Part0 = RightHand, Part1 = Blade_Grip, `C0 = CFrame.new(0, -0.5, -0.5) * CFrame.Angles(math.rad(-90), 0, 0)` (the blade's +Y maps to the hand's forward −Z), `C1 = CFrame.new()`. Tune so the blade sits in the fist.

**Blade hitbox volume** isn't attached to the blade (the server uses attack boxes relative to the HRP; `12_combat_system.md` §4).

## 3. Unit variants

| Unit | Pilot | Accent | Markings | State |
|---|---|---|---|---|
| **02** | Elias | `VG_ACCENT_ELIAS` `#E07A1F` | "02" on the chest and pauldrons; a straight orange stripe (Hollis's repaint) | Playable |
| **01** | Mara | `VG_ACCENT_MARA` `#C8483C` | "01"; a tiny "41" tally on the left pauldron (her sim score) | Ally AI |
| **03** | — | none (primer) | "03"; 40% of plates in `VG_PRIMER` | **Static repair prop** in Bay 3: the left arm is detached and lies on two floor supports, the chest pec plates sit on a rack beside it, and the **core is exposed** through the open chest: a Ball Ø4.5 Neon `AMBER_CORE` with 6 nodules (balls Ø1–1.5, `#E8963A`) inside an "inhibitor lattice" cage of 12 thin bars (`STEEL_LIGHT`, 0.2 thick). The core pulses with a 1.6 s period (clue 2). Scaffolding towers on both sides. Not a Humanoid rig (anchored model, no joints needed). |

## 4. Vanguard stats (`Shared/Config/FrameConfig.lua` → `Vanguard`)

| Stat | Value |
|---|---|
| Integrity (HP) | 1000 |
| Energy max / regen / regen delay | 100 / 18 per s / 1.0 s after the last spend |
| Walk speed / Stride speed | 30 / 48 studs/s |
| Acceleration / deceleration | 70 / 90 studs/s² |
| Turn rate (free / locked-on / striding) | 150 / 220 / 110 deg/s |
| Dodge | cost 25, duration 0.35 s, distance 55, i-frames 0.05–0.30 s, cooldown 0.8 s (from dodge start) |
| Light 1 / 2 / 3 | dmg 68 / 77 / 119; poise 26 / 26 / 51 (× 1.7 since D-061; first 40 / 45 / 70 and 15 / 15 / 30) |
| Heavy | dmg 238; poise 85 (first 140; 50) |
| Pile Driver (special) | cost 50 energy, cooldown 6 s, dmg 153, poise 204 (first 90; 120) |
| Core Strike | 700 flat to HP; range 34 studs from the core, facing within 60° |
| Body target (for enemy attacks) | vertical cylinder radius 8, height 40, centered on the HRP's XZ |
| Limp threshold | Integrity < 15%: walk ×0.75, stride disabled |

## 5. Damage states (visual + gameplay)

| Integrity | State | Visuals | Gameplay |
|---|---|---|---|
| 100–67% | Pristine | — | — |
| < 67% | Scuffed | Left pauldron accent stripe part detaches (falls as Debris, removed after 6 s); spark emitter on the left shoulder (Rate 3) | — |
| < 34% | Damaged | 2 more plates detach (right shin guard, left forearm side plate); a smoke emitter on the back (Rate 12); the visor flickers every 3–5 s | HUD warning amber |
| < 15% | Critical | Heavy smoke, sparks on both arms, the core vents flicker | Limp, alarm loop, HUD red pulse |
| 0 | Disabled | `Disabled` clip, the visor goes dark, all core lights off | Mission failure flow (`05_chapter1_script.md` S28) |

Detached plates: clone the part, unweld, unanchor, collision group `Debris`, apply a small random impulse (client-side visual only: each client spawns its own debris from a `PlateDetached` attribute change; the server only sets attributes). On repair/reset, restore all plates (rebuild visual state from attributes).

**As built (2026-10-10, D-063):** the server publishes `DamageState` and `PlatesDetached` (0, 1 or 3); `FrameDamageController` sheds the plates and runs the effects on each client. There is no alarm yet (no sound IDs) and the limp is the slower walk only. Until Phase 4's checkpoints, `RetryService` handles Disabled: the card for 2.5 s, fade, every Titan of the fight back to how it spawned, the Frame repaired and put back where it last stood clear of Titans.

## 6. Cockpit and pilot interface

- There's no interior cockpit model in the Vertical Slice. The **HUD is the cockpit** (`14_ui.md` §5).
- The **Frame camera** is third-person (`11_controls_and_camera.md`).
- **Boarding** uses the hatch (`HatchHinge` opens to −100° about X over 0.6 s, then closes after boarding).
- **Weapons lock:** in the hangar zone, attacks are disabled (server-enforced; HUD banner).

## 7. Mara's Unit 01: ally AI (`Server/Services/AllyFrameService`)

The ally makes the squad feel real without stealing the fight.

| State | Behavior |
|---|---|
| `Scripted` | Fully driven by cinematic or mission steps (MoveTo targets, look targets, clips). Default during cinematics. |
| `Follow` | Keeps an offset of (−20, 0, +12) relative to the player's Frame (left-rear). MoveTo is re-targeted every 0.5 s; matches the player's speed category (walk/stride). |
| `Hold` | Stands at a mission-defined point and plays idle with head sweeps ("scanning"). |
| `Combat` | Circles the Titan at radius 45, placing itself at an angle of ~150° around the Titan from the player (never between the player's camera and the Titan: if inside a 25-stud corridor of the player→Titan line, it repositions). Every 4–6 s (random): steps in to 22 studs and plays `Light1` → `Light2`. **Damage:** 15 per hit, poise 8, Body zone. Capped so Mara contributes **≤ 10% of the Titan's max HP** per fight (stops dealing HP damage at the cap, still deals poise). Doesn't attack while the Titan is `Downed` (the player gets the Core Strike). |

- **Mara is invulnerable.** If a Titan attack targets her, she plays a perfect `Dodge` at the windup end. Titan target selection favors the player (`10_titans.md` §5).
- Barks come from the BarkController (`05_chapter1_script.md` S28).
- Movement uses `Humanoid:MoveTo` with the same locomotion and turn-rate rules as the player's Frame (server-owned; network owner = server).

## 8. Future Frame classes (documented, not built)

| Class | Height | Silhouette | Weapon / kit | Signature mechanic | Colors |
|---|---|---|---|---|---|
| **Striker** | 36 | Slim, long legs, swept-back head fins, small pauldrons, back thruster wings | Twin short blades | Dash-chaining: up to 3 dodges in a row; dodging through an attack refunds energy | Armor `#6A747C`, accent per pilot |
| **Bastion** | 44 | Very broad, short neck, huge forearm shield, thick legs | Tower shield (left) + piston hammer | Guard stance (hold): blocks frontal damage, builds "Brace" for a counter slam | Armor `#55606A`, hazard trims |
| **Ranger** | 40 | Tall, lean torso, long sensor head, rifle backpack mount | Rail rifle (charged shots) | Scope mode with weak-point highlighting; bonus poise damage to marked zones | Armor `#5F6B63` (olive-grey) |
| **Prototype PF-0 "Herald"** | 42 | Sleek, asymmetric (an organic-looking left arm), **exposed chest core with cyan veins**, no visor (a single round "eye") | Living blade grown from the arm | **Resonance Surge:** briefly controls a Titan's attack timing. **Its core was grown from Tobias Veyne's tissue (Act II reveal).** | Armor `#2F3337`, veins `LATTICE_CYAN` (story-allowed cyan) |

The Frame architecture must support new classes **through configuration**: a class = rig builder + pose set + `FrameConfig` entry + move list in `CombatConfig`. No combat code is rewritten per class.
