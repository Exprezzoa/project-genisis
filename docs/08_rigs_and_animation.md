# 08 — Rigs and Animation (humans, Frames, Titans, procedural animator)

No uploaded animations exist in this project. Humans use **Roblox's default avatar animations**. Everything else is animated by the **Procedural Pose Animator (PPA)**: code-defined keyframe poses applied to `Motor6D.Transform` every frame on each client.

---

> **Scale note (user direction 2026-10-10, D-044).** The Vanguard is built **1.6 × the size written in this document: 64 studs tall** instead of 40. Every length, position, speed, range and box given here for the Vanguard is the 40-stud number; the game uses it × 1.6. The config files write it that way (`30 * S`), and the rig builder builds the 40-stud model and scales it. Times, angles, damage, energy and poise are unchanged.

## 1. Human characters (player and NPCs)

### 1.1 Base rig
1. In edit mode (MCP run-code), create the base R15 rig:
   ```lua
   local desc = Instance.new("HumanoidDescription")
   local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
   rig.Name = "R15Base"; rig.Parent = game.ServerStorage.Templates.Rigs
   ```
   If that call fails in edit mode, **ask the user** to insert one via *Avatar tab → Rig Builder → R15 → Block Avatar (or Mesh)*, then move it to `ServerStorage.Templates.Rigs.R15Base`.
2. `builders/characters/CharacterKit.lua` turns R15Base into a character:
   - `CharacterKit.build(spec) -> Model`, where `spec` = the character's row in `03_characters.md` (skin, body scale, suit colors, hair recipe, gear list).
   - Body color: set each body part's `Color` directly (and a `BodyColors` instance to match).
   - Scale: `Humanoid` NumberValues (`BodyHeightScale`, `BodyWidthScale`, etc.) **or** `HumanoidDescription` scales before creation. Pick one method and log it.
   - Gear and hair: Parts welded with `WeldConstraint` to the relevant body part, positioned relative to that part's CFrame. All gear parts: `Massless = true, CanCollide = false, CanQuery = false, CanTouch = false`.
   - The default face decal stays on the Head.
3. **Player character:** `StarterPlayer.StarterCharacter` = the Elias model (must contain `Humanoid` and `HumanoidRootPart`). Verify in play mode that the default `Animate` LocalScript is present in the spawned character and walking animates. If it isn't, copy the default `Animate` script from a default character spawned in a blank test and log this.
4. **StarterPlayer settings:** CharacterWalkSpeed **14**, CharacterJumpHeight **7.2** (UseJumpPower false), CameraMaxZoomDistance **22**, CameraMinZoomDistance **6**, DevCameraOcclusionMode **Zoom**, AutoJumpEnabled **true**, CharacterUseJumpPower false, EnableMouseLockOption **false** (we manage the camera), LoadCharacterAppearance (irrelevant with StarterCharacter).

### 1.2 NPC humans
- Built with the same CharacterKit and stored in `ServerStorage.Templates.NPCs.<Name>`.
- **Animation:** each NPC gets an `Animator` and plays the **default Roblox R15 idle/walk animations**. **Do not type animation IDs from memory.** In Phase 1, run a play-mode script that reads the IDs from the live player's `Animate` script (`Animate.idle.Animation1.AnimationId`, `Animate.walk.WalkAnim.AnimationId`, `Animate.run.RunAnim.AnimationId`) and write them into `Shared/Config/AnimationIds.lua`.
- `NPCAnimator` (client): for each NPC, plays idle when the root velocity is < 0.5, walk otherwise (AdjustSpeed = speed / 14).
- **Gesture overlays** (§4.6) are layered on top for talking characters.
- NPC Humanoid: `DisplayDistanceType = None`, `HealthDisplayType = AlwaysOff`, `BreakJointsOnDeath = false`, `SetStateEnabled(Dead, false)` (server), collision group `NPCs`.
- **NPC movement:** `Humanoid:MoveTo()` along nav nodes (`map_01` §Navigation). Re-issue `MoveTo` if not reached within 7 s (the Humanoid MoveTo timeout is 8 s).

---

## 2. Giant rig construction rules (Frames, Titans)

1. **Model space:** origin on the ground under the HRP, rig faces **−Z** (Roblox forward). +X = the rig's right.
2. **HumanoidRootPart** (`HRP`): invisible box (Transparency 1), `CanCollide = true`, `CanQuery = false`, `CanTouch = false`, `RootPriority = 127`, `CustomPhysicalProperties = (density 0.7, friction 0.3, elasticity 0, frictionWeight 1, elasticityWeight 1)`, collision group `FrameRoot` or `TitanRoot`.
3. **Main limb parts** (named R15-style: `LowerTorso, UpperTorso, Head, LeftUpperArm, LeftLowerArm, LeftHand, RightUpperArm, ..., LeftUpperLeg, LeftLowerLeg, LeftFoot, ...`): `Massless = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false` (hurtboxes handle queries).
4. **Joints:** `Motor6D` named as in the joint tables below, parented to Part1, with **no rotation in rest C0/C1** (pure offsets). This keeps pose math consistent.
5. **Detail parts** (armor plates, greebles, sinew, bone plates, teeth...) are welded (`WeldConstraint`) to their limb part, `Massless`, non-colliding, `CanQuery = false`, `CastShadow` true only if bigger than 1 stud.
6. **Humanoid:** `RigType = R15`, `HipHeight` from the table, `AutoRotate = false` (rotation is controlled; §2.1), `UseJumpPower = true`, `JumpPower = 0`, `MaxSlopeAngle = 50`, `BreakJointsOnDeath = false`, `RequiresNeck = false`, `HealthDisplayType = AlwaysOff`, `DisplayDistanceType = None`, `EvaluateStateMachine = true`. Server calls `SetStateEnabled(Dead, false)`, `(Ragdoll, false)`, `(FallingDown, false)`, `(Climbing, false)`, `(Swimming, false)`, `(Jumping, false)`. **Gameplay health is NOT `Humanoid.Health`.** It lives in attributes (`Integrity`, `HP`).
7. **No `Animator`** inside Frame or Titan humanoids (the PPA owns `Motor6D.Transform`).
   - **Collision groups, found in Phase 2 (D-040):** a Humanoid switches collisions back on for the parts named `UpperTorso`, `LowerTorso` and `HumanoidRootPart` every frame, whatever `CanCollide` says. So at spawn every part of a giant rig except the root goes into the group `NoCollide`, and the root into `FrameRoot` or `TitanRoot`.
   - **Humanoid states, found in Phase 2 (D-046):** `SetStateEnabled` does not replicate. A parked Frame's Humanoid was `FallingDown` on the client, so on boarding the Frame dropped onto its root and needed 3 s to get up. The list `FrameConfig.DisabledStates` is switched off by the server at spawn **and by every client** when the rig is registered, followed by `ChangeState(Running)`.
   - **Poses exist only on clients.** On the server a rig's parts stay in the rest pose, so the server must never use a limb's position (a hand, a blade) for gameplay; it uses the root plus offsets.
8. **Hurtboxes** (Titans; the Frame uses a single body hurtbox): invisible parts named `Hurtbox_<Zone>`, `CanQuery = true`, `CanCollide = false`, `CanTouch = false`, tag `Hurtbox`, attribute `Zone`. They attach to the **HRP with a `Weld`** whose C0 changes per state (§ in `10_titans.md`). This way the server knows where weak points are without running animations.

### 2.1 Facing control (both rig types)
An `AlignOrientation` on the HRP (`Mode = OneAttachment`, `RigidityEnabled = false`, `MaxTorque = math.huge`, `Responsiveness = 40`, `MaxAngularVelocity = rad(turnRate)`, `PrimaryAxisOnly = false`, `AlignType = PrimaryAxisLookAt` is not used; set `CFrame` directly). The controller sets `AlignOrientation.CFrame` to the desired yaw (pitch and roll always 0). Frames: the piloting client sets it. Titans: the server sets it.

---

## 3. Joint tables

Positions are in model space (rest pose). `C0` = joint position minus Part0 center; `C1` = joint position minus Part1 center.

### 3.1 Vanguard (40 studs; full part list in `09_frames.md`)

| Part | Size (W×H×D) | Center |
|---|---|---|
| HRP | 10 × 10 × 6 | (0, 19, 0) |
| LowerTorso | 12 × 4 × 8 | (0, 22, 0) |
| UpperTorso | 16 × 11 × 10 | (0, 29.5, 0) |
| Head | 5 × 5 × 5.5 | (0, 37.5, 0) |
| L/R UpperArm | 4.5 × 10 × 4.5 | (∓10.5, 27, 0) |
| L/R LowerArm | 5 × 9 × 5 | (∓10.5, 17.5, 0) |
| L/R Hand | 4 × 4.5 × 3.5 | (∓10.5, 10.75, 0) |
| L/R UpperLeg | 5.5 × 8 × 5.5 | (∓3.75, 16, 0) |
| L/R LowerLeg | 5 × 9 × 5.5 | (∓3.75, 7.5, 0) |
| L/R Foot | 6 × 3 × 10 | (∓3.75, 1.5, −1.5) |

**HipHeight = 14** (HRP bottom Y). (∓ means Left = −X, Right = +X.)

| Joint | Part0 → Part1 | Joint pos | C0 | C1 |
|---|---|---|---|---|
| Root | HRP → LowerTorso | (0, 22, 0) | (0, 3, 0) | (0, 0, 0) |
| Waist | LowerTorso → UpperTorso | (0, 24, 0) | (0, 2, 0) | (0, −5.5, 0) |
| Neck | UpperTorso → Head | (0, 35, 0) | (0, 5.5, 0) | (0, −2.5, 0) |
| LeftShoulder | UpperTorso → LeftUpperArm | (−10.5, 32, 0) | (−10.5, 2.5, 0) | (0, 5, 0) |
| LeftElbow | LeftUpperArm → LeftLowerArm | (−10.5, 22, 0) | (0, −5, 0) | (0, 4.5, 0) |
| LeftWrist | LeftLowerArm → LeftHand | (−10.5, 13, 0) | (0, −4.5, 0) | (0, 2.25, 0) |
| Right* | mirror of Left (X → +10.5) | | | |
| LeftHip | LowerTorso → LeftUpperLeg | (−3.75, 20, 0) | (−3.75, −2, 0) | (0, 4, 0) |
| LeftKnee | LeftUpperLeg → LeftLowerLeg | (−3.75, 12, 0) | (0, −4, 0) | (0, 4.5, 0) |
| LeftAnkle | LeftLowerLeg → LeftFoot | (−3.75, 3, 0) | (0, −4.5, 0) | (0, 1.5, 1.5) |
| Right* | mirror | | | |
| BladeGrip | RightHand → Blade_Grip | hand center | see `09_frames.md` | |
| PileDriver | LeftLowerArm → PD_Spike | | see `09_frames.md` | |
| HatchHinge | UpperTorso → Hatch | (0, 34, −5) | (0, 4.5, −5) | (0, 3, 0.3) |

### 3.2 Strider (56 studs)

| Part | Size | Center |
|---|---|---|
| HRP | 10 × 10 × 6 | (0, 29.5, 0) |
| LowerTorso | 12 × 5 × 7 | (0, 29.5, 0) |
| UpperTorso | 14 × 14 × 8 | (0, 39, 0) |
| Head (incl. neck block welded below) | 7 × 9 × 7.5 | (0, 51.5, 0) |
| Jaw | 6 × 2 × 6 | (0, 48, −1) |
| L/R UpperArm | 4 × 14 × 4 | (∓9.5, 37, 0) |
| L/R LowerArm | 3.5 × 14 × 3.5 | (∓9.5, 23, 0) |
| L/R Hand | 4 × 6 × 2.5 | (∓9.5, 13, 0) (4 finger parts 0.8 × 3 × 0.8 welded below, to Y 7) |
| L/R UpperLeg | 5.5 × 12 × 5.5 | (∓3.5, 21, 0) |
| L/R LowerLeg | 4.5 × 12 × 4.5 | (∓3.5, 9, 0) |
| L/R Foot | 6 × 3 × 10 | (∓3.5, 1.5, −2) |
| CorePlateL / CorePlateR | 4 × 6 × 1 | (∓2, 41, 4.6) |

**HipHeight = 24.5.**

| Joint | Part0 → Part1 | Joint pos |
|---|---|---|
| Root | HRP → LowerTorso | (0, 29.5, 0) |
| Waist | LowerTorso → UpperTorso | (0, 32, 0) |
| Neck | UpperTorso → Head | (0, 46, 0) |
| Jaw | Head → Jaw | (0, 49, 2) (hinge at the back) |
| L/R Shoulder | UpperTorso → UpperArm | (∓9.5, 44, 0) |
| L/R Elbow | UpperArm → LowerArm | (∓9.5, 30, 0) |
| L/R Wrist | LowerArm → Hand | (∓9.5, 16, 0) |
| L/R Hip | LowerTorso → UpperLeg | (∓3.5, 27, 0) |
| L/R Knee | UpperLeg → LowerLeg | (∓3.5, 15, 0) |
| L/R Ankle | LowerLeg → Foot | (∓3.5, 3, 0) |
| CoreHingeL / CoreHingeR | UpperTorso → CorePlateL/R | (∓4, 41, 4.6) (outer edges; rotate about Y to open) |

C0/C1 follow the rule `C0 = jointPos − Part0Center`, `C1 = jointPos − Part1Center`.

### 3.3 Watcher (68 studs)

Same part list and joint layout as the Strider, with **S = 68 / 56 = 1.2143**:
- every Y position and Y size × S; X/Z sizes × 1.05 (leaner look comes from detail parts, not the base); arm lengths (UpperArm, LowerArm Y size) × S × 1.1 with joint positions recomputed so the hands reach Y ≈ 6;
- **HipHeight = 29.75**.
- Replace the CorePlates with a **dorsal filament set** (§ in `10_titans.md`).

---

## 4. Procedural Pose Animator (PPA)

### 4.1 Rotation convention
Joint rotations are written as `{rx, ry, rz}` in **degrees** and applied as `CFrame.Angles(rad(rx), rad(ry), rad(rz))` in the joint's rest frame:
- **+X:** downward-pointing children (arms, legs) swing **forward**; upward-pointing children (torso, head) tip **backward**. So: arm raise forward = +X, leg step forward = +X, knee bend = −X (lower leg goes back), elbow bend = +X, lean forward (Waist) = −X, nod down (Neck) = −X, jaw open = −X.
- **+Y:** turn to the rig's **left**. Waist +Y = twist left.
- **+Z:** downward-pointing children swing toward the rig's **right (+X)**. Right arm abduct (out to the side) = +Z. Left arm abduct = −Z.
- Position offsets `{px, py, pz}` in studs (used mainly on Root for bob, crouch and kneel, and on the PileDriver spike).

### 4.2 Data format (`ReplicatedStorage.Shared.Poses.<Rig>`)
```lua
-- Shared/Poses/Vanguard.lua
return {
  rig = "Vanguard",
  poses = {
    Idle = { RightShoulder = {rot = {10, 0, 8}}, RightElbow = {rot = {35, 0, 0}}, RightWrist = {rot = {-25, 0, 0}},
             LeftShoulder = {rot = {5, 0, -6}}, LeftElbow = {rot = {15, 0, 0}}, Waist = {rot = {-3, 0, 0}} },
    -- ...
  },
  clips = {
    Light1 = {
      duration = 0.60, loop = false, blendIn = 0.06, blendOut = 0.12,
      keys = {
        { t = 0.00, pose = "Idle" },
        { t = 0.18, ease = "QuadOut",  pose = { Waist = {rot = {0,-35,0}}, RightShoulder = {rot = {20,0,70}}, RightElbow = {rot = {60,0,0}}, LeftShoulder = {rot = {10,0,-10}} } },
        { t = 0.24, ease = "Linear",   pose = { Waist = {rot = {0,10,0}},  RightShoulder = {rot = {70,40,30}}, RightElbow = {rot = {20,0,0}} } },
        { t = 0.30, ease = "Linear",   pose = { Waist = {rot = {0,35,0}},  RightShoulder = {rot = {60,80,-10}}, RightElbow = {rot = {15,0,0}} } },
        { t = 0.60, ease = "QuadInOut", pose = "Idle" },
      },
      events = { {t = 0.16, name = "TrailOn"}, {t = 0.17, name = "Whoosh"}, {t = 0.18, name = "HitboxStart"},
                 {t = 0.30, name = "HitboxEnd"}, {t = 0.32, name = "TrailOff"} },
    },
  },
}
```
- Missing joints in a key **inherit the previous key's value** for that joint (not identity), so keys can be sparse. The first key should be a full named pose.
- A key whose `pose` is a **name** is a full pose: joints that pose doesn't list go back to rest (otherwise a root drop from an earlier key would stay forever). A key with an inline pose stays sparse (D-037).
- Clip flags: `loop`, `upperBodyOnly`, and `hold` (the clip stays in its last key at full weight until another clip replaces it: `Kneel`, `Disabled`).
- Ease names: `Linear, SineIn, SineOut, SineInOut, QuadIn, QuadOut, QuadInOut, CubicOut, BackOut`.
- **Event names are visual-only on clients** (trails, sounds, particles, shakes). **Gameplay timing (hitboxes) is driven by the server from `CombatConfig`**, which uses the same numbers. Keep both in sync; `CombatConfig` is authoritative.

### 4.3 Layers and blending
Final `Transform` per joint each frame:
`T = Locomotion(joint) ⊗ lerp(Identity, Action(joint), actionWeight) ⊗ Additive(joint)`
- **Locomotion layer:** procedural gait from speed (§4.5) blended with the `Idle` pose.
- **Action layer:** the current clip (attack, dodge, kneel...). `actionWeight` fades 0→1 over `blendIn` and 1→0 over `blendOut`. If an action clip covers a joint, it **replaces** locomotion for that joint at weight 1, except leg joints during `upperBodyOnly` clips (flag on the clip; Light1–3 are `upperBodyOnly = false`, but the Pile Driver is `upperBodyOnly = true` when moving).
- **Additive layer:** breathing (Waist ±1.5° X at 0.25 Hz), head look-at (Neck yaw/pitch toward `LookTarget`, clamped ±60°/±30°), hit flinches, the anomaly head override.
- Implementation: `Shared/Modules/PoseAnimator.lua` (pure math, no Roblox services) plus the client `AnimationController` that runs it in `RunService.PreSimulation` for every animated rig.
- A rig is animated when its Model carries the tag **`PoseRig`** and the attribute `Class` (the name of its pose set). When a clip starts while another is still showing, the action layer cross-fades from the old pose over the new clip's `blendIn`.

### 4.4 Network sync
- The server owns **what** a rig is doing. It sets attributes on the rig Model:
  - `Anim` (string clip name or `""`), `AnimT0` (number, `workspace:GetServerTimeNow()` at start), `AnimSpeed` (number, default 1), `State` (string), `LookTarget` (Vector3 or nil).
- Every client's `AnimationController` watches these attributes and plays the clip at `t = (GetServerTimeNow() − AnimT0) × AnimSpeed`. This keeps all viewers in sync and lets late joiners pick up mid-clip.
- **Prediction for the pilot:** when the local player presses an attack, `FrameController` starts the clip locally **immediately** (with `AnimT0 = local estimate`) and sends the request. When the server's `Anim` attribute arrives with the same clip, it adopts the server `AnimT0` if it differs by less than 0.15 s (otherwise it snaps by blending over 0.08 s). If the server rejects the action, it cancels with `blendOut = 0.1`.
- **Locomotion** is computed locally from the HRP's `AssemblyLinearVelocity` (replicated physics), so it needs no attributes.

### 4.5 Procedural locomotion parameters (`Config/Locomotion`)

| Param | Vanguard walk | Vanguard stride | Strider walk | Strider chase | Watcher careful walk |
|---|---|---|---|---|---|
| Step length (studs) | 15 | 20 | 14 | 16 | 18 |
| Hip swing (± deg) | 22 | 30 | 20 | 26 | 18 |
| Knee bend on swing (deg) | −35 | −55 | −40 | −50 | −30 |
| Ankle compensation | −0.5 × knee | −0.5 × knee | same | same | same |
| Root bob (studs, down at footfall) | 0.8 | 1.4 | 1.2 | 1.6 | 1.0 |
| Root roll sway (± deg) | 2 | 3 | 4 | 5 | 2 |
| Waist counter-yaw (± deg) | 5 | 7 | 8 | 10 | 4 |
| Arm swing (± deg) | 10 (blade arm 5) | 16 (blade arm 6) | 25 (dangling) | 35 | 12 |
| Lean (Waist X) | −3 | −8 | −12 (hunch) | −18 | −6 |
| Head stabilization | yes | yes | no (head bobs, creepy) | no | yes |

- Phase advances by `distanceTraveled / (2 × stepLength)` per cycle (two steps per cycle). Footfall events at phase 0.0 and 0.5 → dust puff at the foot, footstep sound, camera shake (`06_art_direction.md` §6).
- **Speed blend:** below 2 studs/s → idle; 2 → walk speed blends idle→walk amplitude; above walk speed → blends walk→stride parameters.
- **Turning in place:** if yaw velocity > 30°/s and speed < 2, play a small step shuffle (alternate feet ±8° hip yaw every 0.4 s).

### 4.6 Human gesture overlays (on top of default animations)
Applied in `RunService.PreSimulation` (after the Animator wrote Transforms) by multiplying onto the existing `Transform`:
| Overlay | Joints | Values |
|---|---|---|
| `LookAt(target)` | Neck (70%), Waist (30%) | yaw/pitch clamped ±60°/±30°, smoothing 8/s |
| `TalkFidget` | shoulders, elbows | sine offsets ±6–12°, 0.5–1.1 Hz, random phase, while the NPC's line is showing |
| `TapHatch` (Elias) | RightShoulder (95, 0, −10), RightElbow 30, then 2 taps: RightElbow ±8° at 0.25 s intervals | 1.2 s |
| `Point` | RightShoulder (90, 0, 10), RightElbow 5 | hold |
| `CrossArms` | L/R Shoulder (40, 0, ∓30), L/R Elbow (110, ±40, 0) | hold (Vale idle) |
| `HandsBehindBack` | shoulders (−25, 0, ±10), elbows (60, ∓30, 0) | hold (officer idle) |
| `Inspect` (techs) | Waist (−20, 0, 0), RightShoulder (70, 0, 0) | 3 s loops |

---

## 5. Required clips (full list)

### 5.1 Vanguard
Timing must equal `CombatConfig` (`12_combat_system.md` §3). Values below are starting points; tune by eye within ±15% using PosePreview (§6).

| Clip | Duration | Key poses (joint {rx, ry, rz}; Root pos in studs) |
|---|---|---|
| `Idle` | loop | as in the example above, plus breathing |
| `Boot` | 1.2 | Neck (−30,0,0) → (0,0,0) over 0.8 (SineOut); the visor brightens (event `VisorOn` at 0.6) |
| `Light1` | 0.60 | see example (windup 0.18 → active 0.18–0.30 → recover) |
| `Light2` | 0.58 | 0.16: Waist (0,40,0), RS (60,90,−20), RE (70,0,0) → 0.22: Waist (0,0,0), RS (70,30,20) → 0.28: Waist (0,−35,0), RS (40,−20,60), RE (20,0,0) → 0.58 Idle. Hitbox 0.16–0.28 |
| `Light3` (overhead smash) | 0.90 | 0.24 windup: Root (0,0.5,0), Waist (12,0,0), RS (170,0,10), RE (40,0,0), LS (150,0,−10), LE (40,0,0) → 0.32: Waist (−25,0,0), RS (60,0,5), RE (10,0,0), LS (50,0,−5), Root (0,−1.2,0) → 0.40 hold, Root (0,−1.5,0) → 0.90 Idle. Hitbox 0.24–0.40. Event `GroundImpact` 0.36 at the blade tip |
| `Heavy` (spinning cleave) | 1.43 | 0.35 deep windup: Root (0,−1.5,0), Waist (0,−70,0), RS (10,0,85), RE (30,0,0), L/R Knee (−30,0,0) → 0.55 release → 0.64: Waist (0,20,0), RS (75,60,20) → 0.73: Waist (0,70,0), RS (60,100,−10) → 1.43 Idle. Hitbox 0.55–0.73. Root motion: 12 studs forward between 0.40 and 0.60 (applied by FrameController) |
| `Special_PileDriver` | 1.30 | 0.40 windup: Waist (0,30,0), LS (−30,0,−10), LE (90,0,0), Root (0,−1,0) → 0.45 thrust: Waist (0,−20,0), LS (85,0,−5), LE (5,0,0); PileDriver spike pos (0,−6,0) at 0.46 → hold to 0.50 → spike retract 0.90 → 1.30 Idle. Hitbox 0.40–0.50. Events `SteamBurst` 0.47, `Clank` 0.46 |
| `Dodge_F / _B / _L / _R` | 0.35 (+0.10 settle) | F: Waist (−15,0,0); B: Waist (12,0,0); L/R: Root rot (0,0,±15), Waist (0,0,±8). Mid (0.15): hips (30,0,0), knees (−50,0,0). Event `Thrusters` 0.0–0.30 (fire emitters on the back) |
| `CoreStrike` | 1.60 | 0.0–0.5: Root (0,2,0), RS (170,0,10), LS (170,0,−10), Waist (10,0,0) → 0.62 plunge: RS (40,0,5), LS (40,0,−5), Waist (−35,0,0), Root (0,−3,0) [**Impact** 0.62] → 0.7–1.2 grind: Waist (−35,10,0) oscillating ±4° Y at 6 Hz → 1.6 recover |
| `HitReact_Light` | 0.35 | 0.08: Waist (12,0,±8 random), Neck (8,0,0) → 0.35 Idle |
| `HitReact_Heavy` | 0.70 | 0.12: Root (0,−1.5,0), Waist (20,0,0), arms (−20,0,∓15) → 0.7 Idle. Root motion 4 studs backward over 0.0–0.3 |
| `Kneel` | 1.0 | end pose: Root (0,−8,0), LH (70,0,0), LK (−70,0,0), RH (−10,0,0), RK (−100,0,0), RA (40,0,0), Waist (−15,0,0), RS (60,0,10), RE (40,0,0), Neck (−15,0,0) |
| `KneelIdle` | loop | the Kneel end pose plus breathing |
| `RiseFromKneel` | 1.0 | Kneel end pose → Idle (SineInOut) |
| `Disabled` | 1.8 | end pose: Root (0,−9,0), L/R Hip (80,0,0), L/R Knee (−110,0,0), Waist (−30,0,0), Neck (−40,0,0), shoulders (10,0,±5), elbows (5,0,0); the visor goes dark (event `VisorOff` 1.2) |
| `HeadTurnAnomaly` | 2.5 (hold) | additive Neck yaw toward a world direction (computed), max ±70°, SineInOut |
| `TapIdleHangar` | loop | Idle with weapons lowered (blade tip angled down 30° more) for in-hangar movement |

**Tuned while building (D-037; checked with PosePreview by measuring where the feet, blade tip and spike end up):**
- **Feet stay on the floor.** Every key that drops the Root also folds the legs: hips +a, knees −2a, ankles +a, where the body sinks 17 × (1 − cos a) studs (a = 20° for −1, 21° for −1.2, 24° for −1.5, 34° for −3). This replaces `Heavy`'s knees (−30, 0, 0).
- `Light3`: RightWrist (−70, 0, 0) from the 0.32 key, so the blade tip reaches the ground for `GroundImpact` (with the listed angles alone it stopped 25 studs up).
- `Special_PileDriver` thrust (0.45): Waist (−18, −20, 0), LS (55, 0, −5) instead of Waist (0, −20, 0), LS (85, 0, −5): the spike tip lands at about (−8, 9, −24) in front of the Frame, at the move's low aim point, instead of 30 studs up.
- `Kneel`: Root (0, −7, 0), LH (80, 0, 0), LK (−80, 0, 0): the front foot stands on the floor. `Disabled`: Root (0, −8, 0) plus ankles (30, 0, 0).
- `Dodge_*` lasts 0.45 (0.35 + 0.10 settle); the legs tuck without a root drop, so the Frame hops on its thrusters.

### 5.2 Strider
| Clip | Duration | Notes |
|---|---|---|
| `Dormant` | loop | crouched: Root (0,−14,0), L/R Hip (95,0,±10), L/R Knee (−120,0,0), Waist (−50,0,0), Neck (40,0,0) (head up), shoulders (60,0,±15), hands on the ground; slow breathing ±2° |
| `Rise` | 2.5 | Dormant → Idle, Waist leads, the head arrives last |
| `Idle` | loop | hunched: Waist (−12,0,0), Neck (10,0,0), shoulders (5,0,±6), elbows (10,0,0); head micro-tilts every 2–4 s (random ±10° Z) |
| `Sweep` | 2.85 | windup 0–1.1: Waist (0,−50,0), RS (20,−30,95), RE (40,0,0) [the right arm pulls back across]; forearm glow event `TelegraphGlow` at 0.0 → active 1.1–1.45: Waist (0,45,0), RS (80,70,40), RE (10,0,0) → recover to 2.85. *Tutorial version: windup 1.8 (scale only the windup keys)* |
| `Stomp` | 2.65 | windup 0–0.9: RH (75,0,0), RK (−80,0,0), Waist (10,0,0), arms out (shoulders (20,0,±50)) → active 0.9–1.05: RH (0,0,0), RK (0,0,0), Root (0,−2,0) [shockwave event at 0.92] → recover to 2.65 (ankle stays exposed: the hurtbox ankle multiplier rises during recovery) |
| `Lunge` | 4.0 | windup 0–1.3: Root (0,−8,0), Waist (−40,0,0), shoulders (−30,0,±20), Neck (30,0,0); eye flash event `TelegraphEyes` 0.2 → active 1.3–1.8: Waist (−70,0,0), shoulders (140,0,±10) reaching, travel 50 studs (server moves the HRP) → recover 1.8–4.0: falls onto its hands: Root (0,−16,0), Waist (−80,0,0), shoulders (90,0,±10), elbows (0) (head low: head hurtbox reachable), then rises |
| `Roar` | 1.5 | Waist (20,0,0) (lean back), Neck (35,0,0), Jaw (−45,0,0), arms (10,0,±60); event `RoarBlast` at 0.6 |
| `Flinch` | 0.6 | Waist (15,±10,0), Neck (−10,0,0) |
| `DownedFall` | 1.0 | to: Root (0,−18,0), L/R Hip (100,0,±15), L/R Knee (−110,0,0), Waist (−75,0,0), Neck (40,0,0), shoulders (85,0,±20) (on hands and knees, back exposed). CorePlate hinges open: CoreHingeL (0,−100,0), CoreHingeR (0,100,0) during 0.6–1.0 |
| `DownedLoop` | loop | the DownedFall end pose plus labored breathing (Waist ±4° X at 0.8 Hz); the core pulses fast (1.2 Hz) |
| `GetUp` | 1.5 | Downed → Idle; plates close at 0.5–0.9 |
| `Death` | 2.0 then Ash Collapse | knees buckle: Root (0,−20,0), Waist (−60,0,15), Neck (−30,0,20), arms limp; then the VFX in `10_titans.md` §8 |

### 5.3 Watcher
| Clip | Duration | Notes |
|---|---|---|
| `Idle` | loop | upright, still, Waist (−4,0,0); filaments sway |
| `WalkCareful` | procedural | locomotion table "Watcher careful walk"; feet lift high (knee −30 plus a 4-stud foot lift curve) |
| `HeadTiltStudy` | 2.0 | Neck (0,0,18) → (−5,10,10) → (0,0,0) |
| `KneelReach` | 3.0 | Root (0,−20,0), RH (60,0,0), RK (−100,0,0), Waist (−35,0,0), RS (80,0,10), RE (20,0,0) |
| `LiftCanister` | 1.5 | RS (60,0,10) → (40,0,10), RE (20) → (70) (brings the hand toward its face) |
| `LookAtTarget` | hold | additive head look at the target (Unit 02) |
| `RiseAndTurn` | 2.0 | back to Idle, then a 180° turn via AlignOrientation (server) |

### 5.4 Mount / dismount transitions
**Mount (board) in the hangar or at a kneeling Frame:**
1. Server validates (distance ≤ 10 from the prompt, the Frame isn't occupied, the story allows it).
2. Client fade out (0.35 s). Server: un-anchor the Frame HRP, `Seat:Sit(humanoid)` on `PilotSeat` (inside the UpperTorso at local (0, 29, 0)), set all character parts `Massless = true`, `HRP:SetNetworkOwner(player)`, Frame attribute `Pilot = player.UserId`, play `RiseFromKneel` if kneeling or `Boot` on first boarding.
3. Client: hide the character locally (`LocalTransparencyModifier = 1`), disable the character's jump (`SetStateEnabled(Jumping, false)` locally), switch `CameraController` to Frame mode, bind Frame controls, fade in (0.35 s).

**Dismount (at a DismountPad):**
1. Server validates (the Frame's HRP is within the pad radius, speed < 3, not in combat state).
2. Server sets `Anim = "Kneel"` (1.0 s). Client fades out at 0.8 s.
3. Server: break the SeatWeld, restore `Massless = false`, teleport the character to the pad's `ExitPoint` CFrame, set the Frame `HRP:SetNetworkOwner(nil)` then `Anchored = true` after the kneel completes, `Anim = "KneelIdle"`, attribute `Pilot = 0`. Enable the "Board Frame" prompt of the kneeling Frame. It sits on an invisible anchored part `BoardPoint` on the ground at the root's (14, −16, −18), under the hand the Kneel pose holds out, because on the server the hand itself is still at rest (D-040); `Prompt_Board` stays on the hand as a marker. The pilot is moved to the `ExitPoint` two frames after leaving the seat (a move in the same frame is overridden by the pilot's client).
4. Client: restore character visibility and jump, camera to on-foot mode, fade in.

---

## 6. Dev tool: PosePreview (edit mode)

`builders/tools/PosePreview.lua` clones a rig template into `Workspace.DevPreview`, and for a given pose or clip time sets each joint's **C0 = restC0 × poseCFrame** (C0, because `Transform` isn't simulated in edit mode). Usage: `PosePreview.show("Vanguard", "Light3", 0.32)`. It places a camera point and asks the user for a screenshot when visual judgment is needed. `PosePreview.clear()` removes the preview. **Never ship DevPreview content:** clear it before the user publishes.

## 7. Performance rules for animation

- Animate rigs within 600 studs at full rate. 600–1200 studs: update at 10 Hz. Beyond 1200: freeze.
- Cache joint references once per rig (a table of Motor6Ds), never `FindFirstChild` per frame.
- Zero allocations per frame in the hot path where practical (reuse CFrames; no table creation inside the per-joint loop).
- At most 4 giant rigs animated at once in the Vertical Slice (Unit 01, Unit 02, Strider or Watcher, plus Unit 03 static, which is not animated).
