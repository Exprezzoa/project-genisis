# 12 — Combat System (authority, timing, hitboxes, damage)

**Authoritative numbers live in `Shared/Config/CombatConfig.lua`.** The tables here are the initial values. If a number changes during tuning, update the config **and** this doc, and log it in `decisions.md`.

---

> **Scale note (user direction 2026-10-10, D-044).** The Vanguard is built **1.6 × the size written in this document: 64 studs tall** instead of 40. Every length, position, speed, range and box given here for the Vanguard is the 40-stud number; the game uses it × 1.6. The config files write it that way (`30 * S`), and the rig builder builds the 40-stud model and scales it. Times, angles, damage, energy and poise are unchanged.

## 1. Authority model

| Thing | Owner | Notes |
|---|---|---|
| Frame movement physics | Pilot client (network owner) | The server sanity-checks speed (§10) |
| Frame action start (attack, dodge, special, core strike) | **Server** | The client requests; the server validates and runs the timeline |
| Hit detection (both directions) | **Server** | Spatial queries on the server |
| Damage, HP, Integrity, Poise, Energy | **Server** | Published as attributes |
| Titan AI and movement | **Server** | The Titan is server-owned |
| Animation, VFX, sound, camera feel, hitstop | Client | Driven by attributes and `Combat_Feedback` events |
| Lock-on target selection | Client picks, server validates | The server uses the zone for hit-zone choice |

## 2. Frame action state machine (server, per Frame)

```
Parked ──board──▶ Idle
Idle/Moving ──Light──▶ Light1 ──(chain)──▶ Light2 ──(chain)──▶ Light3
Idle/Moving ──Heavy──▶ Heavy
Idle/Moving ──Special──▶ Special
Idle/Moving/Recovery(cancelable) ──Dodge──▶ Dodge
Idle/Moving ──CoreStrike(valid)──▶ CoreStrike
any (except CoreStrike/Disabled) ──hit──▶ HitStunLight | HitStunHeavy
Integrity ≤ 0 ──▶ Disabled
Hangar zone or cinematic ──▶ Locked (no actions)
```
Each action has phases: **Startup → Active → Recovery**. The server uses `workspace:GetServerTimeNow()` for every phase timestamp.

## 3. Vanguard move table (`CombatConfig.Frames.Vanguard`)

*Timings slowed to about 1.7 × the first values on the user's direction (2026-10-10, D-052: "he swings way too fast"). First values: Light1 0.18 / 0.12 / 0.30, Light2 0.16 / 0.12 / 0.30, Light3 0.24 / 0.16 / 0.50, Heavy 0.55 / 0.18 / 0.70 (lunge 0.40–0.60, cancel before 0.35), Special 0.40 / 0.10 / 0.80, chain delay 0.10.*

| Move | Startup | Active | Recovery | Damage | Poise | Energy | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| Light1 | 0.35 | 0.20 | 0.45 | 40 | 15 | 0 | — | Chains to Light2 |
| Light2 | 0.32 | 0.20 | 0.45 | 45 | 15 | 0 | — | Chains to Light3 |
| Light3 | 0.45 | 0.25 | 0.70 | 70 | 30 | 0 | — | Ends the chain. Low aim (ankles) |
| Heavy | 0.90 | 0.28 | 0.90 | 140 | 50 | 0 | — | Lunge 12 studs during 0.70–1.00. Dodge-cancel allowed before 0.60 |
| Special: Pile Driver | 0.60 | 0.15 | 1.00 | 90 | 120 | 50 | 6.0 s | Low-mid aim. Not cancelable after startup begins |
| Dodge | — | 0.35 total | — | — | — | 25 | 0.8 s from start | i-frames 0.05–0.30. Distance 55 |
| Core Strike | — | 1.6 total | — | 700 flat at 0.62 | — | 0 | — | Invulnerable for the whole duration |

**Chaining:** if Light is pressed while in LightN (N < 3) at any time after LightN's startup began, the next light is queued and **starts at LightN's recovery start + 0.15 s** (cutting the remaining recovery). After Light3, the chain ends and full recovery plays. No input by the end of recovery resets the chain.

**Recovery cancel:** Light and Heavy recoveries can be canceled into **Dodge** after 50% of the recovery has elapsed. Special recovery can't be canceled.

**Energy:** max 100. Regen 18/s, starting 1.0 s after the last spend. Not enough energy → request rejected (`Combat_Feedback {kind = "NoEnergy"}` → UI flash on the energy bar).

## 4. Attack hitboxes (Frame → Titan)

Boxes are defined in the **Frame HRP's local space** (HRP center at Y 19 above the ground; front = −Z). The server inflates every box by `LAG_PAD = 2` studs per axis.

| Move | Box size (W × H × D) | Box center offset | Aim point offset (for zone choice) |
|---|---|---|---|
| Light1 / Light2 | 24 × 30 × 26 | (0, −2, −15) | (0, −5, −20) → ~14 studs above ground |
| Light3 | 12 × 34 × 30 | (0, −3, −17) | (0, −11, −24) → ~8 above ground (ankle height) |
| Heavy | 34 × 30 × 30 | (0, −2, −14) | (0, −1, −20) → ~18 above ground |
| Pile Driver | 10 × 12 × 26 | (−4, −7, −16) | (−3, −9, −24) → ~10 above ground |

**Sampling:** during the Active window, the server runs `workspace:GetPartBoundsInBox(boxCFrame, size, overlapParams)` at **20 Hz** (first sample at active start, last at active end), with `OverlapParams` whitelisting parts tagged `Hurtbox` that have `CanQuery = true`. **Each target can be hit at most once per attack.**

**Zone choice** (one zone per target per attack):
1. If the player is locked onto this target with a selected zone **and** that zone's hurtbox is in the overlap results → use that zone.
2. Otherwise, use the overlapped hurtbox whose center is **nearest to the attack's aim point** (world space).

This makes aiming meaningful: Light3 and the Pile Driver naturally hit ankles; lock-on lets the player choose; the head can only be reached when the Titan is low (Downed or Lunge recovery).

## 5. Input buffering and prediction (client)
- Attack and dodge presses are buffered for 0.25 s and sent when they become valid locally.
- The client predicts the animation immediately (`08_rigs_and_animation.md` §4.4) and sends `Frame_Action {action, dir, seq}`.
- The server replies via the Frame's attributes (`Action`, `ActionT0`, `ActionSeq`). If `ActionSeq` doesn't arrive within 0.25 s, or the server sends `Combat_Feedback {kind = "Rejected", seq}`, the client cancels its prediction.

## 6. Damage formulas

```
hpDamage    = move.damage    × zone.hpMult    × upgradeMult(move, "damage")
poiseDamage = move.poise     × zone.poiseMult × upgradeMult(move, "poise")
-- Core Strike: hpDamage = 700 (flat), poiseDamage = 0
-- Exposed core hit by a normal attack: zone Core hpMult 2.0, poiseMult 0
```

| Zone | hpMult | poiseMult |
|---|---|---|
| Body | 1.0 | 1.0 |
| AnkleL / AnkleR | 0.8 | 1.6 (2.0 during Stomp recovery) |
| ArmL / ArmR | 0.9 | 0.8 |
| Head | 1.2 | 1.2 |
| Core (exposed) | 2.0 | 0 |

**Titan HP clamp:** while not `Downed`, the Titan's HP can't drop below 1. Reaching the clamp forces a poise break (`10_titans.md` §1.3).

**After each hit landed, the server:**
1. Updates `HP`, `Poise` and the timers (regen delay, poise regen delay, flinch accumulator).
2. Fires `Combat_Feedback {kind = "HitLanded", zone, amount, pos}` to the attacker (for hitstop, sparks, the number popup if enabled, and camera shake).
3. Checks flinch, poise break and death.

## 7. Titan attacks → Frame

The Frame's body target is a **vertical cylinder of radius 8 and height 40** at the Frame HRP's XZ.

| Shape | Test |
|---|---|
| Arc (Sweep) | XZ distance from the Titan HRP ≤ 45 + 8, and the angle between the Titan's facing and the direction to the Frame ≤ 60° |
| Circle (Stomp) | XZ distance from the landing point ≤ 26 + 8 |
| Path (Lunge) | Distance from the Frame to the segment [lunge start, current Titan position] ≤ 7 + 8, sampled during travel |
| Sphere (Roar) | Distance ≤ 35 + 8 → knockback only |

**Sampling:** 20 Hz during the attack's active window. **Each target is hit at most once per attack.**

**Invulnerability:** a hit is ignored if the Frame is in dodge i-frames (server time), in a Core Strike, or within **0.4 s of mercy invulnerability** after its last hit.

**Dodge grace (latency forgiveness):** if a valid Dodge request is received **≤ 0.15 s after** an attack's active window began, the server treats the Frame as having dodged that attack.

**Hit reactions:**
| Damage taken | Reaction | Hitstun | Knockback |
|---|---|---|---|
| < 200 | `HitReact_Light` | 0.25 s (no actions) | Sweep 12 studs away from the Titan |
| ≥ 200 | `HitReact_Heavy` | 0.50 s | Stomp 18 radial, Lunge 25 along the lunge direction |
| Roar | `HitReact_Light` visual | 0.6 s stagger | 40 radial |

Knockback is executed by the pilot client (LinearVelocity for 0.25 s) upon `Combat_Feedback {kind = "HitTaken", knockback = Vector3}`. The server validates the resulting position loosely (§10).

## 8. Lock-on
- **Target candidates:** Titans (not the Watcher) within 220 studs and in line of sight. On toggle, pick the candidate within 60° of the camera's forward direction with the smallest angle; otherwise the nearest.
- **Zones and cycle order:** Body → AnkleL → AnkleR → Head (only listed while the Head is reachable: `Downed` or `LungeRecover`) → Core (only while `CoreExposed`).
- Client sends `Frame_Lock {targetId, zone}` on change. The server validates: the target exists, is within range, and the zone is currently enabled; otherwise it falls back to Body.
- **Marker:** a BillboardGui diamond on the zone's hurtbox (`14_ui.md` §5.4).

## 9. Separation, barriers and arena bounds
- **Frame ↔ Titan:** each frame, the pilot client checks the XZ distance to every Titan's HRP. If it's less than 17 (Titan body radius 9 + Frame 8), it adds a push velocity outward of `(17 − d) × 12` studs/s (max 40). Titans never get pushed.
- **Frame ↔ Frame (ally):** the same with radius 16; the ally (server-owned) yields.
- **FrameBarrier:** collision blocks the Frame HRP (`07_building_with_parts.md` §5).
- **Out of bounds:** if the player's Frame enters a `Bounds_Warning` trigger, show "RETURN TO THE MISSION AREA" (UI) and Overwatch line `OOB_01 [O] Ember-2, you're leaving the operations area.` If the Frame stays outside 6 s, fade and teleport it back to the nearest nav node.

## 10. Anti-exploit (server)
- Rate limits (per remote, `16_technical_architecture.md` §5).
- **Speed check, as built (D-054):** it measures **distance per 0.25 s interval**, not speed, because the pilot's position updates reach the server in bursts. Allowed distance = normal speed × 1.25 × the interval, plus the whole distance of a running dodge or lunge × 1.2 while that action runs and for 0.5 s after. A move the server made itself (`FrameService.moveTo`) restarts the measurement. The rest is as first written:
- **Speed check, first design** (every 0.25 s per piloted Frame): allowed horizontal speed = 48 × 1.25 normally; 170 during a dodge window; 60 during root-motion windows; plus knockback allowances. Exceeding it for more than 0.5 s cumulative within 3 s → the server sets the Frame back to its last valid position (server sets `HRP.CFrame`) and logs a warning. No kicks in single-player.
- **Action validation:** state, cooldown, energy, distance (Core Strike within 34 + 4 tolerance), facing (60° + 10° tolerance).
- Never trust a client-sent damage value, target HP, position for hit tests, or timestamp.

## 11. Feel (client)
- **Hitstop:** freeze the attacker's (and Titan's) local animation time for the duration in `Config/CameraFeel` (0.05–0.15 s). Physics continues; it's visual only.
- **Hit flash** on the Titan (Highlight, 0.08 s), bone-dust particles at the hit point, sound by zone (`SFX_STR_HIT_FLESH` for Body/Arm/Head, `SFX_STR_HIT_BONE` for Ankle/Core).
- **Damage numbers:** off by default. A setting enables small white numbers (yellow for weak zones).
- **Player hit:** red edge vignette (0.25 s), shake, HUD jitter (±3 px for 0.15 s), alarm beep when Integrity is under 34%.

## 12. Upgrades (configurable without code changes)

An upgrade is data: `{id, name, desc, cost, rankRequired, modifiers = {{path = "Frames.Vanguard.Light1.recovery", op = "mul", value = 0.85}, ...}}`. `ProgressionService` computes each player's **effective CombatConfig** (base + owned upgrades), keeps it server-side, and sends a read-only copy to that client (for UI and prediction).

| Upgrade ID | Name | Effect | Cost | Rank |
|---|---|---|---|---|
| `VG_SERVO_1` | Servo Tuning I | Light1–3 recovery ×0.85 | 300 credits | 1 |
| `VG_CAPACITOR_1` | Capacitor Bank I | Energy regen ×1.2 | 350 | 1 |
| `VG_THRUSTER_BAFFLES` | Thruster Baffles | Dodge cooldown −0.15 s, dodge cost −5 | 400 | 2 |
| `VG_PILEDRIVER_MK2` | Pile Driver Mk II | Special poise ×1.3, cooldown −1.0 s | 500 | 2 |

**Upgrades change behavior** (timing, cooldowns, costs) rather than only raw damage, as the design bible requires.
