# 16 — Technical Architecture

**Read before writing any code.** It defines where everything lives, how systems talk, and the coding rules.

---

## 1. Principles
1. **Server-authoritative gameplay; client-side presentation.**
2. **Data-driven content:** sequences, dialogue, configs, poses and products are data modules. Systems are generic.
3. **One responsibility per module.** Services (server) and Controllers (client) have `Init()` (create state, no cross-calls) and `Start()` (connect events, may call other modules).
4. **Per-player state everywhere** (no global "the player" variables). Keyed by `Player`.
5. **Clean up everything:** every connection and instance created for a player, Frame or Titan is tracked in a `Trove` and cleaned on leave, despawn or reset.
6. **No deprecated APIs:** `task.wait/spawn/delay/defer` (never `wait`, `spawn`, `delay`); `Animator:LoadAnimation` (never `Humanoid:LoadAnimation`); `workspace:GetPartBoundsInBox/Radius` and `Raycast` (never `FindPartsInRegion3`); `RunService.PreSimulation/PostSimulation/Heartbeat/RenderStepped`.
7. **No busy loops.** No `while true do task.wait() end` without purpose. Use events, Heartbeat accumulators with fixed tick rates, or `task.delay`.
8. **Type safety:** `--!strict` in `Shared/Modules` and config modules. `--!nonstrict` allowed in UI-heavy controllers if needed. Export types from `Shared/Modules/Types.lua`.

## 2. Studio tree ↔ local `src/` mapping

Rule: `Name.server.lua` → Script, `Name.client.lua` → LocalScript, `Name.lua` → ModuleScript, folder → Folder (or a ModuleScript if the folder contains `init.lua`).

```
src/
├─ ReplicatedFirst/
│  └─ LoadingScreen.client.lua
├─ ReplicatedStorage/
│  └─ Shared/
│     ├─ Config/   GameConfig, FrameConfig, TitanConfig, CombatConfig, CameraFeel, Locomotion,
│     │            Bindings, LightingPresets, UIStyle, SoundRegistry, AnimationIds, NPCs,
│     │            Progression, Upgrades, Products, Zones, Debug
│     ├─ Poses/    Vanguard, Strider, Watcher, Human
│     ├─ Dialogue/ Speakers, CH1_Hub, CH1_M01, CH1_Return, Barks
│     ├─ Sequences/ CH1
│     ├─ Objectives.lua, Evidence.lua, Tutorials.lua, Cinematics.lua
│     └─ Modules/  Net, Signal, Trove, StateMachine, PoseAnimator, Easing, MathUtil,
│                  TableUtil, Geometry, RateLimiter, Log, Types, VFX, Glyphs
├─ ServerScriptService/
│  └─ Server/
│     ├─ Main.server.lua
│     ├─ Services/ PlayerDataService, CollisionService, ZoneService, CharacterService,
│     │            FrameService, AllyFrameService, TitanService, CombatService,
│     │            SequenceService, DialogueService, InteractionService, TriggerService,
│     │            RelationshipService, FlagService, EvidenceService, ProgressionService,
│     │            CinematicService, NPCService, AmbientService, DebugService,
│     │            MonetizationService (Phase 10)
│     ├─ Sequence/ Actions.lua, Conditions.lua, Registry.lua
│     └─ Titans/Behaviors/ StriderBehavior.lua, WatcherBehavior.lua
└─ StarterPlayer/
   └─ StarterPlayerScripts/
      └─ Client/
         ├─ Main.client.lua
         ├─ Controllers/ InputController, CameraController, CharacterController,
         │               FrameController, AnimationController, NPCAnimator, UIController,
         │               HUDController, FrameHUDController, DialogueController,
         │               CinematicController, InteractionController, WaypointController,
         │               LightingController, AudioController, VFXController,
         │               TutorialController, BarkController, AmbientController,
         │               MobileControlsController, SettingsController, MenuController,
         │               MissionLogController, DebugController
         └─ UI/ Components/ (Panel, Label, Button, Bar, SegmentedBar, Chip, Toggle, Slider, KeyGlyph)
                Screens/ (one module per screen from 14_ui.md)
```

Instances that aren't code (rigs, StarterCharacter, map, DevTools) are produced by `builders/`, not `src/`.

## 3. Bootstrap
- **Server `Main.server.lua`:** require every service module in `Services` → call `Init()` on all (in a fixed order list) → `Start()` on all → set `ReplicatedStorage:SetAttribute("ServerReady", true)` and fire `Server_Ready` to clients that send `Client_Ready`.
- **Client `Main.client.lua`:** wait for `ReplicatedStorage:GetAttribute("ServerReady")` (or its changed signal) → require controllers → `Init()` all → `Start()` all → send `Client_Ready`.
- **Order list (server):** Log → CollisionService → PlayerDataService → FlagService → RelationshipService → EvidenceService → ProgressionService → ZoneService → TriggerService → InteractionService → CharacterService → NPCService → AmbientService → FrameService → AllyFrameService → TitanService → CombatService → DialogueService → CinematicService → SequenceService → DebugService.
- A failing `Init`/`Start` must error loudly in Output with the module name. Never fail silently.

## 4. Service and controller responsibilities (public APIs)

| Module | Responsibility | Key API |
|---|---|---|
| **PlayerDataService** | Load/save profiles, session lock, migrations, autosave | `getProfile(p)`, `waitForProfile(p, timeout)`, `update(p, fn)`, `saveNow(p, reason)`, `Loaded` signal |
| **CollisionService** | Create collision groups and the matrix (`07` §5) | `assign(part, group)`, `assignModel(model, group)` |
| **ZoneService** | Track each player's zone (`Config/Zones`: bounds boxes) | `getZone(p)`, `ZoneChanged` signal → client lighting, reverb and weapon lock |
| **CharacterService** | Spawn and respawn, teleport to spawns, on-foot state, character settings | `teleport(p, spawnId)`, `setControlLocked(p, bool)` |
| **FrameService** | Spawn and park Frames, board/dismount, network ownership, the action state machine, energy, integrity, damage states | `spawnFrame(p, unitId, spawnId)`, `board(p, frame)`, `dismount(p, padId)`, `requestAction(p, payload)`, `applyDamage(frame, dmg, info)`, `repair(frame)`, `getPiloted(p)` |
| **AllyFrameService** | Mara's Unit 01 states (`09_frames.md` §7) | `setMode(p, mode, params)` |
| **TitanService** | Spawn, despawn, AI ticking, attacks, hurtbox states, HP/poise/regen, death | `spawn(p, type, spawnId, state)`, `command(id, cmd, args)`, `applyHit(titan, hitInfo)`, signals `Downed`, `Defeated` |
| **CombatService** | Hit tests (both directions), zone choice, damage formulas, feedback events, lock validation | `resolveFrameAttack(frame, move)`, `resolveTitanAttack(titan, attack)`, `setLock(p, targetId, zone)` |
| **SequenceService** | The Sequence Runner per player (`13` §1) | `start(p, seqId, fromCheckpoint)`, `jump(p, stepId)` (debug), `getState(p)` |
| **DialogueService** | Server-side dialogue state, effects, timers | `start(p, dlgId)` (yields if blocking), `advance`, `choose` |
| **InteractionService** | Prompt routing and validation | `register(interactId, handler)`, `setEnabled(interactId, bool, p?)` |
| **TriggerService** | Box triggers, 5 Hz | signals `Entered(p, id, who)`, `Exited` |
| **FlagService / RelationshipService / EvidenceService** | Story state | `13` §3 |
| **ProgressionService** | XP, ranks, credits, idempotent rewards, upgrades, effective config | `grant(p, key)`, `buyUpgrade(p, id)`, `getEffectiveConfig(p)` |
| **CinematicService** | Tells a client to play a cinematic, waits for done or timeout, keeps the server timeline (e.g. door opens at t = 1.0) | `play(p, cinId, params)` (yields) |
| **NPCService** | Spawn NPCs, routes, follow mode, talk prompts | `spawn(id)`, `command(id, cmd, args)` |
| **AmbientService** | Server-side ambient states (PA loop selection, door states) | `setPA(set)` |
| **DebugService** | Studio-only commands (`19_testing_and_debug.md`) | — |
| **InputController** | Contexts and bindings, buffered actions, device type | `setContext(name)`, `ActionPressed` signal, `getDevice()` |
| **CameraController** | On-foot, Frame, lock-on and core strike camera modes, shake, FOV | `setMode(mode)`, `shake(preset)`, `punchFOV(amount)` |
| **FrameController** | Pilot-side movement, prediction, separation, root motion | — |
| **AnimationController** | PPA for all giant rigs, attribute sync, distance LOD | `register(rig, poseSet)`, `playLocal(rig, clip)` |
| **UIController** | Creates ScreenGuis and screens, global fade, cards | `fade(to, t)`, `card(kind, data)` |
| **CinematicController** | Shot playback, letterbox, guaranteed restore | `play(cinId, params)` |
| others | as named | |

## 5. Networking (`Shared/Modules/Net.lua`)
- `Net` creates all RemoteEvents under `ReplicatedStorage.Remotes` at server start from a definitions table. Clients `WaitForChild` them (timeout 10 s, error if missing).
- **Prefer RemoteEvents.** RemoteFunctions **only** client → server for request/response where needed (none required in the Vertical Slice). **Never** server → client RemoteFunctions.
- **Every client → server remote** is wrapped with: a rate limiter (token bucket), argument validation (`typeof` checks, enum whitelists, finite numbers, unit-vector tolerance ±0.05, string length ≤ 64, table key whitelist), and pcall around the handler (errors are logged, never crash the service).

### Remote definitions
| Remote | Direction | Payload | Rate limit |
|---|---|---|---|
| `Client_Ready` | C→S | `{}` | 1 per session |
| `Frame_Action` | C→S | `{action: "Light"\|"Heavy"\|"Dodge"\|"Special"\|"CoreStrike", dir: Vector3?, seq: number}` | 15/s (burst 20) |
| `Frame_Lock` | C→S | `{targetId: string?, zone: string?}` | 6/s |
| `Dialogue_Advance` | C→S | `{dialogueId: string, nodeId: string}` | 10/s |
| `Dialogue_Choose` | C→S | `{dialogueId: string, nodeId: string, index: number}` | 4/s |
| `Cinematic_Done` | C→S | `{cinematicId: string}` | 2/s |
| `Cinematic_Skip` | C→S | `{cinematicId: string}` | 2/s |
| `Settings_Update` | C→S | `{[key]: value}` (whitelisted keys and ranges) | 1/s |
| `Checkpoint_Restart` | C→S | `{}` | 1 per 5 s |
| `Upgrade_Buy` | C→S | `{upgradeId: string}` | 2/s |
| `Debug_Command` | C→S | `{cmd: string, args: {string}}` (Studio only) | 5/s |
| `Server_Ready` | S→C | `{}` | — |
| `Seq_State` | S→C | `{objectiveId, objectiveArgs, optional: {ids}, waypoints: {...}}` | — |
| `Dialogue_Node` / `Dialogue_End` | S→C | `{dialogueId, nodeId, mode, timer?}` / `{dialogueId}` | — |
| `Cinematic_Play` | S→C | `{cinematicId, params, t0}` | — |
| `Combat_Feedback` | S→C | `{kind, seq?, zone?, amount?, pos?, knockback?}` | — |
| `UI_Toast` / `UI_Card` / `Tutorial_Show` / `Bark_Play` | S→C | `{text}` / `{kind, data}` / `{id}` / `{id}` | — |
| `Lighting_Set` / `Fade` / `Music_Set` | S→C | `{preset, instant}` / `{to, duration}` / `{cue, fade}` | — |
| `Profile_Snapshot` | S→C | `{settings, rank, xp, credits, upgrades, evidence, flags (UI-relevant subset)}` | on change, ≤ 2/s |

Large or continuous state (HP, energy, AI state, animation) goes through **Instance attributes**, not remotes.

## 6. State ownership summary
| State | Where | Replication |
|---|---|---|
| Profile (all persistent data) | Server memory (PlayerDataService) | `Profile_Snapshot` subset |
| Sequence step, objective | Server | `Seq_State` |
| Frame integrity, energy, action | Server | Frame Model attributes |
| Titan HP, poise, state, anim | Server | Titan Model attributes |
| Dialogue current node | Server | `Dialogue_Node` |
| Camera, input, UI, VFX, sounds | Client | — |
| Lock-on | Client → server validated | `Frame_Lock` |

## 7. Attributes and tags conventions
- **Attributes on models:** PascalCase (`Integrity`, `MaxIntegrity`, `Energy`, `Action`, `ActionT0`, `ActionSeq`, `Pilot`, `Anim`, `AnimT0`, `State`, `HP`, `MaxHP`, `Poise`, `MaxPoise`, `CoreExposed`, `Enraged`, `DisplayName`, `UnitId`).
- **Tags:** `CLAUDE.md` §7 list; plus `OutpostLight`, `Detail`, `NavNode`, `Hurtbox`, `Door`.
- **IDs:** `SPAWN_*`, `TRG_*`, `INT_*` (interact), `CAM_*`, `NAV_*`, `PAD_*`, `WP_*` (waypoint markers), `DOOR_*`, `MARK_*` (NPC marks).

## 8. Logging (`Shared/Modules/Log.lua`)
- `Log.debug/info/warn/error(tag, msg, ...)`. `debug` prints only in Studio. `warn`/`error` always.
- Tag every message with the module name (`[FrameService]`). Claude reads console output through the MCP while testing.

## 9. Time and randomness
- **Server time:** `workspace:GetServerTimeNow()` for all timelines shared between server and client.
- **Randomness:** `Random.new(seed)` per system. Titan AI uses a per-Titan Random seeded from its spawn (deterministic replays during tests when seeded via debug).

## 10. Error handling
- DataStore and Marketplace calls are always in pcall with retries (`17_saving_progression_monetization.md`).
- Sequence actions are wrapped in pcall. On error, log, then **continue the sequence** if the action isn't critical. If it is critical (teleport, spawnTitan), retry once and then fall back to a checkpoint reload with a visible message in Studio.
- Player leaving mid-sequence: the Trove cleans up everything, and the profile saves with the last checkpoint.

## 11. Performance budgets (server and client)
| Metric | Budget |
|---|---|
| Server Heartbeat | ≥ 55 Hz average during the Titan fight |
| Client FPS | ≥ 55 on a mid PC; ≥ 30 on a mid phone |
| Script activity (MicroProfiler / Script Performance) | No single script > 3% average |
| Network | < 30 KB/s per player average (receive) |
| Client memory | < 1.5 GB PC; < 900 MB phone (Developer Console → Memory) |
| Parts in Workspace | ≤ 40,000 |

## 12. Optional: Rojo workflow
If the user wants professional version control, use **Rojo** (Rokit/Aftman install, `default.project.json` mapping `src/` as above, `rojo serve` plus the Studio plugin). Then code syncs automatically and the MCP is used only for building and testing. **Don't switch to Rojo without the user's approval;** it's a setup change they must perform. If adopted, log it in `decisions.md` and update `CLAUDE.md` §2.
