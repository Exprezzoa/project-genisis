# 11 — Controls and Camera (PC, gamepad, mobile)

All bindings live in `Shared/Config/Bindings.lua` and are bound through **ContextActionService** by the client `InputController`. **Input contexts:** `OnFoot`, `Frame`, `Dialogue`, `Cinematic`, `Menu`. Exactly one gameplay context (`OnFoot` or `Frame`) is active; `Dialogue`, `Cinematic` and `Menu` temporarily suspend it (gameplay actions are unbound, and movement is disabled via the PlayerModule `ControlModule:Disable()`, always restored in a guaranteed cleanup path).

> **Scale note (user direction 2026-10-10, D-044).** The Vanguard is built **1.6 × the size written in this document: 64 studs tall** instead of 40. Every length, position, speed, range and box given here for the Vanguard is the 40-stud number; the game uses it × 1.6. The config files write it that way (`30 * S`), and the rig builder builds the 40-stud model and scales it. Times, angles, damage, energy and poise are unchanged.

## 1. Bindings

### On foot
| Action | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD | Left stick | Roblox dynamic thumbstick |
| Camera | Right-mouse drag, wheel zoom (Roblox default camera) | Right stick | Drag on screen, pinch zoom |
| Sprint | Hold Left Shift (setting: toggle) | L3 (toggle) | `Sprint` toggle button |
| Jump | Space | A | Roblox jump button |
| Interact (ProximityPrompt) | E | X | Tap the prompt |
| Mission Log | Tab | View/Back (`ButtonSelect`) | `LOG` button (top-left) |
| Menu (pause/settings) | P or M | D-pad Up | `≡` button (top-right) |

### Piloting a Frame
| Action | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD | Left stick | Thumbstick |
| Camera | Mouse (cursor locked to center) | Right stick | Drag on the empty right half of the screen |
| Stride | Hold Left Shift (setting: toggle) | L3 (toggle) | `STRIDE` toggle |
| Aim lock (user direction, D-055): the Frame faces where the camera looks and strafes | Left Ctrl (toggle) | D-pad Down | `AIM` (not built yet) |
| Light attack (combo) | Left mouse | RB (`ButtonR1`) | `LIGHT` (big button) |
| Heavy attack | Right mouse | RT (`ButtonR2`) | `HEAVY` |
| Dodge (toward move input; backstep with no input) | Space | B | `DODGE` |
| Pile Driver (special) | Q | LB (`ButtonL1`) | `SPECIAL` |
| Core Strike (contextual) | F | Y | `CORE` (appears only when available) |
| Lock-on toggle | R or middle mouse | R3 | `LOCK` |
| Cycle lock zone | C (or mouse wheel while locked) | D-pad ← / → | Tap `LOCK` again while locked (long-press 0.5 s = unlock) |
| Interact (Frame prompts, pads) | E | X | Tap the prompt |
| Mission Log / Menu | Tab / P | View / D-pad Up | `LOG` / `≡` |

### Dialogue and cinematics
| Action | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Advance / complete text | Left click, Space or E | A | Tap the dialogue box |
| Choose option | 1–4 or click | D-pad ↑ ↓ + A | Tap the option |
| Skip cinematic (only already-seen or skippable ones) | Hold Space 1.0 s | Hold A 1.0 s | Hold the `SKIP` button 1.0 s |

**Input buffer:** attack and dodge inputs are buffered for **0.25 s** (`12_combat_system.md` §5).

**Device glyphs:** the UI shows the binding for the **last used input type** (`UserInputService.LastInputTypeChanged`). Glyph text set: KB/M `E, LMB, RMB, SPACE, SHIFT, Q, F, R, C, TAB, P`; gamepad (Xbox labels) `A, B, X, Y, LB, RB, LT, RT, L3, R3, D-PAD, VIEW`; touch: button names. Tutorial strings in `05_chapter1_script.md` list all three; the UI may show only the current device's part.

## 2. Mobile layout (`MobileControlsController`; only when `TouchEnabled` and the last input was touch)

All positions are relative to the bottom-right corner (AnchorPoint (1, 1)) and use **Scale + Offset** so they stay inside the safe area (`GuiService:GetGuiInset()` and `ScreenGui.ScreenInsets = CoreUISafeInsets`).

| Button | Size (px at 1× UIScale) | Position (from bottom-right) | Notes |
|---|---|---|---|
| LIGHT | 120 | (−40, −40) | Biggest; tap and hold repeats the combo |
| HEAVY | 84 | (−180, −50) | |
| DODGE | 84 | (−70, −180) | |
| SPECIAL | 72 | (−190, −160) | Shows the energy requirement (2 pips) |
| LOCK | 64 | (−300, −70) | |
| CORE | 110 | screen center-bottom (0.5, −180) | Appears and pulses only when available |
| STRIDE / SPRINT | 64 | bottom-left above the thumbstick zone (+40, −220) from the bottom-left (was −260; lowered to stay clear of the objective tracker on phones, D-031) | Toggle |
| LOG | 56 | top-right, left of the menu button (−96, 24) (was top-left under the objective tracker, where it overlapped SPRINT on a phone in landscape; D-031) | |
| ≡ (menu) | 56 | top-right (−24, 24) | |

Buttons: tilted (−8°) ink squares (were circles before the angular restyle, `14` §1.1), with a 2-px amber stroke, label in Michroma; pressed = amber fill with ink text. Pressed state: scale 0.92 plus brightness. Cooldown: a radial-ish sweep made of a darkening overlay Frame that shrinks vertically. Hit areas are at least 56 px.

## 3. On-foot camera
- Roblox default `Classic` camera. FOV 70. Zoom 6–22. `DevCameraOcclusionMode = Zoom` (camera collision; it never passes through walls).
- **Conversation soft framing:** during conversations the camera eases (0.5 s) to a two-shot: position = midpoint(Elias, speaker) + side vector × 9 + up × 2, looking at the midpoint at head height. Player camera input is ignored during conversation and restored afterwards.

## 4. Frame camera (`CameraController`, Scriptable)

| Parameter | Value |
|---|---|
| Pivot | Frame HRP position + (0, 18, 0) (head level) |
| Distance | default 62; wheel/pinch 40–80 |
| Pitch (elevation angle) | default +12°; clamp −20° … +60° |
| Shoulder offset | +6 studs right (camera space). Goes to 0 when locked-on (0.3 s blend) |
| Mouse sensitivity | 0.25 °/px × setting (0.2–2.0) |
| Gamepad sensitivity | 220 °/s at full deflection × setting, quadratic response curve |
| Touch sensitivity | 0.35 °/px × setting |
| Mouse behavior | `LockCenter` while piloting outside menus and dialogue |
| Collision | Spherecast (radius 2) from the pivot to the desired position, ignoring Frames, Titans, characters, `Debris` and parts tagged `NoCollideCamera`. If blocked: distance = hit − 2 (min 12). Zoom in instantly, zoom back out at 30 studs/s |
| FOV | 70; Stride 78 (0.3 s tween); dodge kick +6 for 0.2 s; FOV punches per `06_art_direction.md` §6 |
| Shake | Perlin-noise rotational offset; magnitudes from `Config/CameraFeel`, × the settings slider |

**Lock-on camera:** desired yaw = direction from the Frame to the lock point. Camera yaw blends toward it at 6/s. The player can still adjust pitch. Horizontal mouse/stick input adds a ±25° offset that decays back over 0.6 s. Lock breaks when the target dies, goes beyond 220 studs, or line of sight is lost for 2 s.

**Core Strike camera (1.6 s):** side orbit from the Frame's right at distance 50, height +10, looking at the core. Returns to the gameplay camera over 0.3 s.

## 5. Frame movement (client-side on the pilot's machine)

1. Read the move input: the seated pilot's own `Humanoid.MoveDirection`. Roblox's control script fills it from the keyboard, gamepad or touch stick with its deadzone, and a seated Humanoid doesn't act on it (D-048; this place has no `PlayerModule` to ask for a move vector).
2. It is already turned by the camera, so it is the world direction `dir`; its length is the input amount.
3. Target speed = (stride ? 48 : 30) × `|input|` (×0.75 when limping). **While attacking the Frame keeps 60% of its walk speed** and can't stride (user direction, D-055; it was 0); a dodge is root motion only.
4. Current speed approaches the target at 70 studs/s² (accelerate) / 90 studs/s² (decelerate). Write `frameHumanoid.WalkSpeed = currentSpeed` and call `frameHumanoid:Move(dir)` each frame (works because the pilot owns the Frame's physics).
5. **Facing:** free mode, so turn toward `dir` at 150°/s (stride 110°/s) via AlignOrientation; a running attack keeps its heading. **Aim lock** (D-055): face the camera's heading at 220°/s, also while attacking, and strafe. Locked mode: face the target at 220°/s; movement strafes.
6. **Root-motion actions** (Heavy lunge, Dodge, HitReact knockback, Core Strike step-in) use a temporary `LinearVelocity` (Plane mode, world XZ) on the HRP for the action's movement window, owned by the pilot client.
7. **Separation and barriers:** `12_combat_system.md` §9.

## 6. Cinematic camera (`CinematicController`)
- `CameraType = Scriptable`. A shot is defined by a start CFrame, end CFrame (or a look-at target that moves), duration, easing (default `SineInOut`), FOV start and end, and optional DOF.
- Cam points can come from tagged `CinematicCam` parts (attribute `CamId`) or literal positions in the cinematic data.
- **Guaranteed restore:** the previous camera type, subject, FOV, mouse behavior and input context are saved before playing and restored in a `finally`-style cleanup that runs on completion, skip, error (pcall), character death or teleport. Pressing Escape during a cinematic must never leave controls locked.
- **Multiplayer-safe:** cinematics only ever affect the local client that received `Cinematic_Play`.

## 7. Accessibility and settings that affect controls
Camera sensitivity, invert Y, camera shake (0–100%), hold vs. toggle for sprint and stride, reduce flashing (disables hit flashes and dampens the resonance flash to 30%), subtitle size (S 18 / M 22 / L 26 px), tutorial hints on/off. All persist in the profile (`17_saving_progression_monetization.md`).
