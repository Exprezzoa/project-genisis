# 10 — Titans (Strider full spec, Watcher, future species)

Rig layouts: `08_rigs_and_animation.md` §3.2–3.3. Colors: `06_art_direction.md` §3 (Titans). Damage rules: `12_combat_system.md`.

**Design rules for every Titan:**
1. A **distinct silhouette** (never "the same humanoid in another color").
2. **Uncanny, biological, heavy.** Organic shapes from cylinders, balls and wedges. No greebles. Detail comes from sinew strips, bone plates and skin folds.
3. **Every attack has 3 telegraph signals:** an anticipation pose, a glow brightening, and a unique sound cue. Area attacks also show a ground danger disc.
4. **Species-specific weak point** (the core node). Regeneration makes chip damage insufficient: you must break poise and strike the core.
5. **No blood or gore.** Hits release pale bone-dust and grey vapor.

### Look direction from the user (2026-10-10, D-039) — overrides rule 2 and the skin, face and head rows below

**Frames look like machines; Titans look like giant people.** The contrast is the point.

- **Human skin.** Titan bodies use human skin tones (SmoothPlastic), not the grey `STR_SKIN`. The palette gets a small set of skin tones in `06` §3 when the Strider is built; each Titan picks one.
- **Human faces.** A Titan's head carries a human face: eyes with whites and irises, brows, a nose, a mouth with lips and teeth. It is built from parts (the built-in default face decal is allowed on top if it reads better at that size). The "wide lipless mouth" and the dark eye sockets of §1.1 go; the too-human eyes stay and become the rule.
- **Random hair.** Each Titan gets a hair style picked at random (seeded per spawn) from a list of hair accessories from the Roblox marketplace, scaled to the head. This is an approved exception to "built from parts" (`01` §3). **Every asset ID in that list must be verified first** through the Studio MCP (search the asset, insert it, check that it loads and what it looks like); no ID is ever typed from memory. If no usable hair can be inserted, the fallback is part-built hair like the human characters' (`03`).
- **What stays:** the silhouettes and proportions (a Strider is still lanky and hunched with arms to its knees), the heights and rigs of `08` §3, every attack, telegraph, hurtbox and number, the species weak point (the Strider's Dorsal Core under its back plates), the feral orange-red glow of eyes and core, the Ash Collapse, and **no blood or gore**.
- **What is still open until Phase 3:** how much of the Strider's exposed muscle, sinew and bone plating stays on a human-skinned body (recommended: keep the back plates over the core and the forearm vein glow, because attacks and the Core Strike depend on them; drop the rest). The part-by-part table below is rewritten at the start of Phase 3 and shown to the user before the rig is built.
- **Still an original world.** Human-looking Titans are fine; names, designs, sounds and story beats of existing series are not copied (`01` §7).

**The user's Shifter (2026-10-10, D-042, D-045):** `ServerStorage.Reference.AttackTitan`. It is both the look reference for other Shifters **and a Shifter in the game itself**, used as the model it is (an approved exception to "built from parts", like the marketplace hair). It was scaled from 116 to **80 studs** on the user's direction, so it stands a head above the 64-stud Frames. **It is the Watcher** (user, 2026-10-10, D-047: "this shifter should be the watcher, the model suits its description"). Wherever this document or `03`, `05`, `08` describe the Watcher's body, rig or height (68), this model at 80 studs replaces it; the Watcher's role, scenes and behavior are unchanged. Description: a Shifter Titan the user made for an older game. It is an R15 mesh body 116 studs tall (muscled torso and limb meshes, skin `#EAB892`), white hair, pointed ears, blank white eyes, pale blue bands at the wrists, invisible `Eyes` and `Nape` hit parts, no scripts. It shows the look the user wants for Shifters and is the reference when the first Shifter is designed. It is the user's own work: never delete, move or edit it without asking. Open points for Phase 3 are in Q-013.

**Shifter transformation (user direction, same date):** a Shifter changes form after **hurting themselves on purpose**; a **bolt of yellow lightning** strikes where they stand, with a **thunder-crack sound**, and the Titan form stands there when the flash clears. Details in `02` §8 and `06` §6.

---

## 1. Strider-class (Class-3 specimen in Chapter 1)

> **As built in Phase 3 (D-056), replacing the part list of §1.1 and the main-part sizes of `08` §3.2.** The Strider is no longer made of parts. Its body is a copy of the body of the user's own Titan model (`ServerStorage.Reference.AttackTitan`: a blocky avatar body with sculpted muscle over it), which keeps Striders and the Watcher one species to the eye:
> - **Left out:** everything that is the Shifter's own: its white hair, pointed ears, the pale blue wrist bands, its hit parts.
> - **Proportions:** body 0.8 as wide and 0.86 as deep as the reference, arms 1.3 times as long (the hands hang to just above the knees), head unchanged, the whole sized to **56 studs** to the top of the head. About 38 wide.
> - **Rig:** the same joint names as a Frame (`Root`, `Waist`, `Neck`, `Left/Right` `Shoulder`, `Elbow`, `Wrist`, `Hip`, `Knee`, `Ankle`) as clean Motor6Ds, plus `CoreHingeL` / `CoreHingeR`. **No `Jaw` joint** (the head is one sculpted piece); the Roar opens no mouth. HRP 10 × 10 × 6 at Y 29.5, HipHeight 24.5, as in `08` §3.2.
> - **The feral marks, from parts:** orange-red (`TITAN_GLOW`) eyes; a grin of seven teeth in a dark slit; the Dorsal Core (orb Ø4 in a dark socket) between the shoulder blades under two hinged bone plates; a glowing vein (`TITAN_GLOW_DEEP`) down the outside of each forearm; a wrap of dark cloth round the hips.
> - **Per Titan, from a seed** (`Server/Titans/TitanLook`): one of five human skin tones (`06` §3) and one of 24 hair styles.
> - **Hair:** 24 free, rigid hair accessories made by Roblox, natural colors. Every ID came from a catalog search run through Studio, and each was put on an avatar there to measure how it sits; the list is in `builders/rigs/Strider.lua`. Newer "layered" hair is not used: the engine bends it onto a head with a cage, which a sculpted Titan head doesn't have.
> - 55 parts without hair. The old budget, sinew, ribs, toes and crest of §1.1 are gone; hurtboxes, stats, attacks and the AI below are unchanged.

- **Height 56.** Lanky, hunched, arms that dangle to the knees, long three-toed feet, an elongated head with a **wide lipless mouth** and small, too-human eyes. Bone plates on the shoulders and spine. **Dorsal Core** between the shoulder blades, under two hinged bone plates.
- **Glow color:** `TITAN_GLOW` (eyes, core), `TITAN_GLOW_DEEP` (forearm veins, crest lines).
- **Budget ≤ 350 parts.**

### 1.1 Part-by-part build (`builders/rigs/Strider.lua`)
Skin parts are `STR_SKIN` SmoothPlastic unless noted. Offsets are relative to the main part's center (front = −Z).

| Main part | Details (welded) |
|---|---|
| **Feet** (each) [14] | Foot core 6 × 3 × 10; **3 long toes** (1.6 × 1.2 × 4 blocks plus a wedge tip each) at the front, spread ±10°; heel pad (Ball Ø3, squashed 3 × 2 × 3); 3 sinew strips on top (0.3 × 0.3 × 6, `STR_SINEW`) |
| **Lower legs** (each) [14] | Shin block 4.5 × 12 × 4.5; calf roundness (cylinder axis Y Ø4.6 × 9 at (0, 0.5, 0.6)); **exposed calf muscle** on the back: 4 striated strips 0.6 × 8 × 0.4 (`STR_MUSCLE`); knee bone cap (Ball Ø3.5 scaled 3.5 × 2.5 × 2 in `STR_BONE` Limestone) at (0, 6, −2) |
| **Upper legs** (each) [8] | Thigh cylinder Ø5.6 × 12 (axis Y); 2 sinew lines (0.3 × 10 × 0.3) on the front |
| **LowerTorso** [10] | Pelvis 12 × 5 × 7; hip bone plates (Limestone wedges 2 × 3 × 4) at (±6.2, 0.5, 0); abdomen block 10 × 4 × 6 at (0, 3.5, 0) in `STR_SKIN_SHADE` (the narrow waist) |
| **UpperTorso** [60] | Chest 14 × 14 × 8 (top slightly wider: add 2 wedges at the shoulders); **ribs:** 5 strips per side (5 × 0.5 × 0.6, tilted 15–25° down toward the front, `STR_SKIN_SHADE`), front and sides; sternum ridge (0.8 × 8 × 0.6); **collarbones** (2 Limestone bars 6 × 0.6 × 0.6, angled); **spine ridge:** 6 vertebra bumps (Limestone 1.5 × 1.2 × 1.2) down the back centerline, skipping the core zone; **shoulder bone plates:** 2 layered plates per shoulder (Limestone 6 × 1 × 6 and 5 × 1 × 5, tilted 20°) at (±6, 6.5, 0.5); **core socket** ring (cylinder axis Z Ø5.4 × 0.6, `STR_SOCKET`) at (0, 2, 4.2); **Dorsal Core** (`CoreOrb`: Ball Ø4, Neon `TITAN_GLOW`, with PointLight Range 20, Brightness 0.3 closed / 2.0 open) at (0, 2, 4.4); **CorePlateL/R** (Limestone 4 × 6 × 1, separate parts on Motor6Ds `CoreHingeL/R`) |
| **Head** [45] | Cranium 6.6 × 5 × 7 at (0, 1.5, 0.3); face block 6 × 4 × 1 at (0, −1.5, −3.4); brow ridge wedge 6 × 1 × 1.4 (`STR_SKIN_SHADE`); **eye sockets** 2 × (1.6 × 1.1 × 0.3, `STR_SOCKET`) at (±1.3, 1, −3.95); **eyes** 2 × Ball Ø0.7 Neon `TITAN_GLOW` (transparency 0.2) inside the sockets; nose (wedge 1 × 1.4 × 0.6) with 2 dark nostril dots; **mouth:** wraparound slit (center 5 × 0.8 × 0.3 plus 2 side pieces angled 30° back, `STR_SOCKET`) at Y −2.2; **upper teeth** 10 × (0.45 × 0.6 × 0.3, `STR_TEETH`) along the slit; sunken cheeks (2 dark wedges); **sensory crest:** 5 fins on the top-back (Limestone wedges 0.4 × (2–3.5) × 3), each with a glow line (0.15 Neon `TITAN_GLOW_DEEP`, transparency 0.5); neck block 3.5 × 2 × 3.5 below; 2 neck sinew cords (cylinders Ø0.8 × 5) from behind the jaw to the collarbones (welded to UpperTorso) |
| **Jaw** [12] | Jaw 6 × 2 × 6; **lower teeth** 10 × (0.45 × 0.6 × 0.3); chin wedge |
| **Upper arms** (each) [6] | Cylinder Ø4 × 14 (axis Y); elbow bone knob (Ball Ø2.5 Limestone) at (0, −7, 1.5) |
| **Lower arms** (each) [8] | Forearm 3.5 × 14 × 3.5 plus cylinder roundness; **exposed muscle** on the outer forearm: 3 strips 0.6 × 10 × 0.4 (`STR_MUSCLE`); **vein glow line** 0.2 × 10 × 0.2 Neon `TITAN_GLOW_DEEP` (transparency 0.6 idle → 0.0 during the Sweep telegraph) |
| **Hands** (each) [11] | Palm 4 × 6 × 2.5; **4 long fingers** in 2 segments each (0.8 × 1.6 × 0.8 + 0.7 × 1.4 × 0.7, slightly curled); thumb in 2 segments |

### 1.2 Hurtboxes (invisible parts welded to the HRP; C0 per state)

Offsets are relative to the HRP center. The **server swaps the weld C0** when the state changes (`TitanService.setHurtboxState`). **Verify with PosePreview** by showing hurtboxes semi-transparent (debug toggle) over each pose; adjust until each box overlaps its visual body part.

| Hurtbox | Size | Standing | Downed | LungeRecover (on hands) | Notes |
|---|---|---|---|---|---|
| `Hurtbox_Body` | 14 × 20 × 8 | (0, 6, 0) | (0, −10, −6) rotated −75° X | (0, −12, −8) rotated −80° X | HP ×1.0, poise ×1.0 |
| `Hurtbox_Head` | 7 × 9 × 7.5 | (0, 22, 0) | (0, −7.5, −18) | (0, −14, −22) | HP ×1.2, poise ×1.2 |
| `Hurtbox_AnkleL/R` | 5.5 × 7 × 5.5 | (∓3.5, −23, 0) | (∓3.5, −26, 10) | (∓3.5, −26, 8) | HP ×0.8, poise ×1.6 (×2.0 during Stomp recovery) |
| `Hurtbox_ArmL/R` | 5 × 28 × 5 | (∓9.5, −6.5, 0) | (∓9.5, −18, −14) | (∓9.5, −20, −18) | HP ×0.9, poise ×0.8 |
| `Hurtbox_Core` | 5 × 5 × 3 | disabled | (0, −8.7, −7.5), facing up | disabled | `CanQuery` only while `Downed`. Normal hits ×2.0 HP, 0 poise. Core Strike target |

### 1.3 Stats (`Shared/Config/TitanConfig.lua` → `Strider`)

| Stat | Value |
|---|---|
| HP | 2400 |
| HP regen | +10 HP/s when not `Downed` and no HP damage taken for 4.0 s |
| Poise | 300 base; **+60 max poise after each break** (300 → 360 → 420 → 480 cap) |
| Poise regen | 25/s after 3.0 s without poise damage |
| Flinch | accumulated poise damage ≥ 60 within 1.5 s, outside an active window → `Flinch` (0.6 s), cancels a windup. Flinch cooldown 4.0 s |
| Downed duration | 6.0 s total (`DownedFall` 1.0 + `DownedLoop` 5.0), then `GetUp` 1.5 s (the core closes at 0.5–0.9 of GetUp) |
| Can't die standing | HP is clamped at 1 while not `Downed`. Reaching that clamp forces an immediate poise break → `Downed` |
| Walk / chase speed | 16 / 22 studs/s |
| Turn rate | approach 70°/s; Sweep windup tracking 45°/s; Lunge windup tracking 90°/s; 0 during active windows |
| Body radius (for separation) | 9 studs |
| Aggro radius | 220 (the Chapter 1 fight starts from a cinematic, so this matters only for debug spawns) |

### 1.4 Attacks (authoritative numbers; `CombatConfig.TitanAttacks.Strider`)

| Attack | Range / shape | Windup | Active | Recovery | Damage | Telegraph signals |
|---|---|---|---|---|---|---|
| **Sweep** | arc 120° in front, radius 45 from the Titan's HRP, height 0–30 | 1.1 s (**1.8 s for the first one in Chapter 1**) | 0.35 s | 1.4 s | 180 | Right arm pulls back across the body; the **forearm vein glow** brightens 0.6 → 0; a low rising groan (`SFX_STR_SWEEP_TELL`) |
| **Stomp** | circle radius 26 around the right foot's landing point (≈ 8 studs in front) | 0.9 s | 0.15 s | 1.6 s | 220 | Right leg lifts high; a **ground danger disc** (Neon `TITAN_GLOW_DEEP` cylinder, 0.2 thick, transparency 0.75 ↔ 0.55 pulsing at 4 Hz) appears for the windup; a sharp intake hiss (`SFX_STR_STOMP_TELL`) |
| **Lunge** | rectangle 14 wide along the travel path (50 studs forward) | 1.3 s | 0.5 s (travel) | 2.2 s (on hands; head exposed) | 260 | Crouches low; **eyes flash** (Neon brightness pulse plus PointLight flash at 0.2 s); a guttural click-growl (`SFX_STR_LUNGE_TELL`) |
| **Roar** | sphere radius 35 | 0.6 s | 0.9 s | 0.6 s | 0 damage; knockback 40 studs + 0.6 s stagger unless the player is mid-dodge | Leans back, jaw opens wide, crest glow full; (`SFX_STR_ROAR`) |

- **Lunge travel:** the server applies a `LinearVelocity` (VelocityConstraintMode `Plane`, world XZ, 100 studs/s, MaxForce 1e7) to the HRP for 0.5 s, then removes it. The path is pre-checked with a box cast; it stops early at walls or FrameBarriers.
- **Roar trigger:** first at HP ≤ 50% (at the next decision point, never interrupting an active window), then every 25–35 s while HP ≤ 50%. After the first Roar the Titan is **Enraged**: windups ×0.87, between-attack cooldowns ×0.8.

### 1.5 AI state machine (`Server/Services/TitanService` + `Shared/Modules/StateMachine`)

Decision tick: **10 Hz** (accumulate Heartbeat dt; decide every 0.1 s). Movement commands are re-issued at most 4×/s.

```
Dormant ──(trigger: cinematic Rise)──▶ Rising ──▶ Engage
Engage: choose action each tick when not on cooldown
  ├─ Approach (walk/chase toward the target until preferred range)
  ├─ Telegraph(attack) ──▶ Active(attack) ──▶ Recover(attack) ──▶ Engage (+ cooldown 1.2–2.0 s)
  ├─ Roar ──▶ Engage
Any state except Active/Downed/Dead ──(flinch condition)──▶ Flinch ──▶ Engage
Any state except Dead ──(poise ≤ 0)──▶ DownedFall ──▶ DownedLoop ──▶ GetUp ──▶ Engage
Downed* ──(HP ≤ 0)──▶ Dead ──▶ AshCollapse ──▶ (destroyed)
```

**Target selection** (every 1.0 s): score(player's Frame) = 100 − distance / 10; score(Mara's Unit 01) = 60 − distance / 10. Pick the highest. **Never target on-foot humans** in the Vertical Slice.

**Attack choice** (when in Engage and the cooldown has elapsed), weighted random by target distance `d`:

| d | Weights |
|---|---|
| < 22 | Stomp 60, Sweep 40 |
| 22–30 | Sweep 80, Stomp 20 |
| 30–45 | Sweep 60, Lunge 30, Stomp 10 |
| 45–70 | Lunge 70, Approach 30 |
| > 70 | Approach (chase speed beyond 110) |

Rules: never the same attack 3 times in a row; **Stomp is only chosen if the target is within 26 + 6 studs of the predicted landing point**; the Titan won't start a new Telegraph while the player is in a Core Strike (it can't, since it's Downed).

**Facing:** the server sets `AlignOrientation.CFrame` to look at the target (yaw only), limited by the state's turn rate (§1.3).

**Separation:** if a Frame comes within (9 + 8) = 17 studs of the Titan's HRP center (XZ), the Frame's controller pushes the Frame outward (`12_combat_system.md` §9). Titans are never pushed.

### 1.6 Attributes published on the Titan model (for UI and animation)
`TitanType = "Strider"`, `DisplayName = "STRIDER-CLASS — UNREGISTERED"`, `Class = 3`, `HP`, `MaxHP`, `Poise`, `MaxPoise`, `State`, `Anim`, `AnimT0`, `AnimSpeed`, `Enraged` (bool), `CoreExposed` (bool), `LookTarget` (Vector3).

### 1.7 Audio (keys in SoundRegistry, `15_audio.md`)
`SFX_STR_STEP`, `SFX_STR_BREATH_LOOP`, `SFX_STR_SWEEP_TELL`, `SFX_STR_SWEEP_WHOOSH`, `SFX_STR_STOMP_TELL`, `SFX_STR_STOMP_IMPACT`, `SFX_STR_LUNGE_TELL`, `SFX_STR_ROAR`, `SFX_STR_HIT_FLESH`, `SFX_STR_HIT_BONE`, `SFX_STR_FLINCH`, `SFX_STR_DOWNED`, `SFX_STR_CORE_OPEN`, `SFX_STR_CORE_STRIKE`, `SFX_STR_DEATH_GROAN`, `SFX_ASH_CRACKLE`, `SFX_ASH_VAPOR`.

## 2. Ash Collapse (death sequence, all Titans) — 12 s, client visuals, server cleanup

| Time | Event |
|---|---|
| 0.0 | `Death` clip (2.0 s). `SFX_STR_DEATH_GROAN`. The camera does a client impact frame (`05_chapter1_script.md` S30) |
| 1.5 | All skin parts tween color → `ASH` over 4.0 s; glow parts tween to `ASH` and their lights → 0 over 2.0 s |
| 2.0 | Vapor emitters on the torso, head and limbs (smoke texture, `ASH`, Size 6 → 14, Transparency 0.3 → 1, Rate 30, Lifetime 3–4, Speed 3–6, Acceleration (0, 4, 0)). `SFX_ASH_VAPOR` loop |
| 4.0 | 6 ash mounds (flattened cylinders and wedges, `ASH`/`ASH_DARK`, CanCollide false) appear under the body and grow over 6 s |
| 5.0–11.0 | Crumble: every 0.1 s, 3 random detail parts unweld, switch to `Debris`, get a small random impulse, fade to transparent over 1.5 s, then are destroyed. `SFX_ASH_CRACKLE` bursts |
| 8.0–12.0 | Main parts fade Transparency 0 → 1 |
| 12.0 | Grey flake burst (sparkles texture tinted `ASH`, 80 particles) |
| 12.5 | Server destroys the Titan model. The ash mounds remain (server-spawned at 12.0, static, CanCollide false) |

## 3. The Watcher (Orin in Titan form): scripted, non-combat

- **Height 68.** Taller, leaner and darker than the Strider. Calm, deliberate, *intelligent* body language: it stops, tilts its head, studies. **It never attacks.**
- **Skin** `WAT_SKIN`; **plates** `WAT_BONE` (smoother, armor-like, on the shoulders, forearms and shins); **glow** `WAT_GLOW` = `LATTICE_CYAN`.
- **Budget ≤ 380 parts.**

| Feature | Build |
|---|---|
| Base | Strider layout scaled per `08_rigs` §3.3 |
| Head | Smooth, elongated, no visible teeth (a closed mouth line, 4.5 × 0.2 × 0.2 dark); **larger calm eyes** (Ball Ø1.0 Neon cyan, transparency 0.1); 3 subtle forehead ridges |
| **Cyan vein lines** | Neon strips 0.2 wide, transparency 0.3, along both arms (2 each), legs (2 each), the spine (1), and a branching pattern on the chest (5 strips). Pulse transparency 0.3 ↔ 0.6, period 3.0 s (client) |
| **Dorsal filaments** | 8 hair-like strands hanging from the back of the head and the shoulders, each a chain of 3 thin parts (0.6 × 6 × 0.6, `WAT_SKIN` with 1 cyan tip). Welded (no physics); sway is procedural on the client: ±6° rotation, staggered phase |
| Canister (`TV_Canister`) | Cylinder Ø1.2 × 2.4, `MEDICAL_WHITE`, a frost emitter (smoke texture, white, small). Starts in the rover cradle. During `LiftCanister` the server re-welds it to the Watcher's RightHand |
| Hurtboxes / collision | None. `TitanRoot` group, invulnerable. Ignored by targeting and lock-on |

**Scripted path** (Outpost-local; the ridge top is at Y 30, see `map_03`):
`W0 (290, 30, −560)` → `W1 (250, 25, −575)` → `W2 (205, 1, −590)` → `W3 (172, −12, −598)` [kneel facing the rover at (150, −12, −600)] → after `RiseAndTurn`: `W2` → `W1` → `W4 (300, 30, −560)` → `W5 (460, 37, −560)` → despawn.
Movement: `Humanoid:MoveTo` at 10 studs/s with `WalkCareful` locomotion. Facing via AlignOrientation at 40°/s.

## 4. Future species (documented, not built)

| Species | Class | Body plan / silhouette | Weak point (core node) | Signature behavior |
|---|---|---|---|---|
| **Bulwark-back** | 3–4 | Heavy, hunched, an enormous armored back carapace, short powerful arms | Under-chin node (exposed when it rears up) | Charges and plows through cover; the carapace is immune to frontal damage |
| **Crawler** | 2 | Low, long-limbed, moves on all fours with its arms, flat head | Nodes in the wrist joints | Fast flanking; leaps onto Frames and must be shaken off (dodge) |
| **Siren** | 2–3 | Thin, a throat sac, ribbed neck frills | Throat sac | A vocal pulse that disables Frame HUD and thrusters briefly; attracts other Titans |
| **Dormant** | 3 | Half-buried, looks like a rock formation until disturbed | Nodes in the back mounds | Ambush; triggered by noise and stride speed |
| **Regenerator** ("Hydra-type") | 3 | Asymmetric extra arm buds | A wandering node that moves between 3 locations | Regrows severed limbs; must be tracked |

Each new species = rig builder + pose set + `TitanConfig` entry + attacks in `CombatConfig` + hurtbox table. **No changes to TitanService core logic.** If a new behavior is needed, add a pluggable behavior module (`Server/Titans/Behaviors/<Name>.lua`).
