# 18 — Roadmap, Phases and Acceptance Tests

Work strictly in order. A phase is complete only when **every acceptance test passes and is recorded in the journal**. Each phase lists the docs to read.

Legend: 🧱 build (geometry) · 🧠 code · 🎨 presentation · ✅ acceptance test

---

## Phase 0 — Audit and setup
**Read:** `CLAUDE.md`, `01`, `07`, `16`, `19`, `maps/map_00`.
- [ ] List the MCP tools; confirm the Studio connection.
- [ ] Inspect the existing place (dump the tree). Note anything already present in `docs/tracking/journal.md`.
- [ ] Ask the user to: publish the place; enable Studio access to API Services; set Max Players = 1 (Game Settings → Places); confirm the Studio version is current.
- [ ] Create the local folders `src/`, `builders/` per `07` §1 and `16` §2 (empty skeletons plus a README in each).
- [ ] Create the Studio folders: `Workspace.Map`, `Workspace.Runtime`, `ServerStorage.DevTools`, `ServerStorage.Templates.{Rigs,NPCs,Frames,Titans,Props}`.
- [ ] Write `builders/lib/BuildKit.lua` and `Palette.lua`; push them to DevTools; run a smoke test (build a 3-part test model, then delete it).
- [ ] Set Workspace properties: `StreamingEnabled = false`, `Gravity = 196.2` (default), `SignalBehavior = Deferred` (default), `FallenPartsDestroyHeight = -500`.
- ✅ The BuildKit smoke test returns stats; the tree dump matches the planned skeleton; the user confirmed publishing and API access.

## Phase 1 — Foundation (hub blockout, Elias, core frameworks, saving v1)
**Read:** `03`, `06`, `07`, `08` §1, `11` §1–3, `13`, `14` §1–4, `16`, `17` §1–5, `map_01`, `map_02` (shell only).
- 🧠 Bootstrap (`Main.server/client`), Net, Signal, Trove, Log, RateLimiter, StateMachine, Easing, MathUtil.
- 🧠 CollisionService, ZoneService, TriggerService, InteractionService, CharacterService.
- 🧠 PlayerDataService (schema v1, session lock, retries, memory-only fallback), FlagService, Settings saving.
- 🧱 Central Command **blockout** of all areas (`map_01`), plus the hangar shell blockout and launch platform (`map_02` §1–2). Gameplay objects in place (spawns, triggers, nav nodes, prompts).
- 🧱 Elias `StarterCharacter` (CharacterKit). Verify the default animations play.
- 🧠 Read the default animation IDs from the live Animate script → `Config/AnimationIds.lua`.
- 🎨 UI foundation: UIStyle, components, fade layer, on-foot HUD (objective tracker, toasts, subtitles), custom prompts, Mission Log shell, Settings menu (functional and saved), loading screen.
- 🧠 Lighting presets plus LightingController (MORNING active in the hub).
- 🧠 DebugService and DebugController (`19` §2): teleports, step jumps, toggles.
- ✅ **Tests:** (1) Spawn in Q-3; walk to every area via the nav nodes without getting stuck (walk test + nav check script). (2) Every door opening is ≥ 5 wide and 8 tall. (3) Interact with the photo/locker/poster prompts → thoughts show as subtitles. (4) Change a setting, rejoin → it persists (with API access on). (5) Kick yourself mid-session → data saved; rejoin within 10 s → the session lock resolves within 30 s. (6) Works with the touch emulator (Studio device emulation: a phone) and with gamepad navigation in menus. (7) No errors or warnings in Output.

## Phase 2 — Frame prototype (Vanguard)
**Read:** `08` (all), `09`, `11` §4–5, `12` §1–5 and §9–11, `14` §5, `map_02`, `map_01` (Training Yard).
- 🧱 Vanguard rig builder (full detail per `09` §2), Unit 01, 02, 03 variants. Within budget.
- 🧠 PoseAnimator plus AnimationController (locomotion, actions, sync via attributes, LOD).
- 🧠 FrameService: spawn and park in bays, board/dismount (hangar bridge plus a test pad in the Training Yard), network ownership, action state machine, energy.
- 🧠 FrameController: movement with acceleration, turn rate, stride, camera-relative input; CameraController Frame mode; root motion; separation.
- 🧠 Combat input → requests → server validation; attack timelines; hitbox sampling against a **Titan Simulacrum** dummy with hurtboxes in the Training Yard.
- 🎨 Frame HUD (integrity, energy, ability panel, reticle, banner); footstep dust; blade trail; hitstop and shake.
- 🧠 Weapons lock in the hangar zone.
- 🧱 Training Yard blockout plus the simulacrum.
- ✅ **Tests:** (1) Board from the Bay 2 bridge; walk the hangar to the deployment door (weapons locked). (2) In the Training Yard: Light ×3 combo, Heavy (with lunge), Pile Driver, dodge in 4 directions; all timings within ±0.03 s of the config (log server timestamps). (3) Hits on the simulacrum's zones register the correct zone per the aim/lock rules (test log prints the zone and damage). (4) Energy spend and regen correct; insufficient energy is rejected and flashes. (5) Dismount and remount work. (6) The speed check doesn't false-trigger during normal play, dodges or lunges. (7) Gamepad and touch controls work for every action. (8) 60 s of continuous play shows no errors; FPS ≥ 55 in the hangar.

## Phase 3 — Titan encounter (Strider)
**Read:** `08` §3.2 and §5.2, `10`, `12` (all).
- 🧱 Strider rig builder (full detail), within budget.
- 🧠 TitanService plus StriderBehavior: state machine, targeting, attack choice, telegraphs, attacks, poise, flinch, Downed, regen, enrage, HP clamp, death.
- 🧠 Hurtbox state swaps; Core Strike (validation, strike positioning, camera).
- 🧠 Lock-on with zones and markers.
- 🎨 Titan HUD bar, danger disc, glow telegraphs, hit flash, bone dust, Ash Collapse.
- 🧠 Frame damage states (detaching plates, smoke, limp) and Disabled.
- ✅ **Tests:** (1) Debug-spawn a Strider in the Training Yard; a full fight is winnable in 2–3.5 min by a competent player (log fight duration over 3 test fights; if outside the range, tune and log). (2) Every attack's windup, active and recovery times match the config (server log). (3) Dodging during i-frames negates damage; dodge grace works under a simulated 150 ms latency (Studio Network Simulator: Incoming Replication Lag 0.15). (4) A poise break → Downed → core exposed → Core Strike deals 700 → after the 3rd break or so, death → Ash Collapse completes and the model is removed. (5) The Titan can't die standing (HP clamp → forced Downed). (6) Regen only after 4 s without damage. (7) Frame Disabled flow resets correctly. (8) Server Heartbeat ≥ 55 Hz during the fight.

## Phase 4 — First mission flow (Outpost 07)
**Read:** `05` (S20–S33), `13`, `map_03`, `09` §7.
- 🧱 Outpost 07 **blockout plus structure** (`map_03`): road, perimeter, courtyard, bunker (interior), power station, maintenance yard, residential (R3 interior), tower, trail, basin, ridge, bounds.
- 🧠 SequenceService plus Actions plus Conditions; CH1 steps **S10–S33** (mission portion) with placeholder text where dialogue isn't wired yet.
- 🧠 Deployment: hangar door, launch, transit, teleport; dismount pads A and B; breaker lever; comm console; the 3 investigation clues; trail; basin entry trigger; fight start; victory; Watcher placeholder (scripted path with a stand-in model if the Watcher isn't built yet); rover interactions; upload; mission complete; return teleport.
- 🧠 AllyFrameService (Follow, Hold, Combat, Scripted).
- 🧠 Checkpoints `CH1_DEPLOYED` … `M01_COMPLETE`, restore logic, fail and retry.
- 🎨 Waypoints, objective updates, Overcast lighting, out-of-bounds handling.
- ✅ **Tests:** (1) Play from Launch to Mission Complete without debug commands. (2) Quit and rejoin at each checkpoint → it resumes correctly (test all 7 mission checkpoints). (3) Already-found clues persist after a rejoin. (4) Out-of-bounds returns the player. (5) Mara follows, fights within her damage cap, holds during cinematics, and never blocks the player's camera for more than 2 s. (6) No step can soft-lock: each completion condition has been triggered manually in tests.

## Phase 5 — Story introduction (Chapter 1 complete)
**Read:** `03`, `04`, `05` (all), `13`, `14` §6–11, `15` §1–2.
- 🧱 All NPC templates (`03_characters.md`), placed per `map_01`/`map_02`. The Watcher rig (full detail). MemorySet.
- 🧠 DialogueService plus DialogueController (all modes, choices, timers, effects), RelationshipService, EvidenceService, BarkController, TutorialController, NPCService (routes, follow, talk), CinematicService plus CinematicController (all Chapter 1 cinematics), PA loops.
- 🧠 Wire **every** Chapter 1 scene S01–S43 exactly per the script, including flags, choices, conditional lines, evidence and rewards (rewards are wired in Phase 6 if not yet available; log it).
- 🎨 Letterbox, cards (Title, Transit, Frame Disabled, Mission Complete placeholder, Chapter End), terminal message, cockpit boot, anomaly glitch, resonance ping, Watcher glow.
- ✅ **Tests:** (1) A full playthrough S01 → S43 with each choice branch (C1 ×2, C2 ×3, C3 ×3, C4 ×2) verified via flags in the profile dump. (2) Every line ID in `05` §… appears exactly once in the dialogue data (a script compares the doc's IDs to the data). (3) Cinematic skip and interruption never lock controls (test: press Esc, alt-tab, reset the character during each cinematic). (4) The optional deck scene variants show the correct lines for each flag combination. (5) Subtitles readable on a phone (emulator at 375 × 812). (6) No dialogue line over 120 chars.

## Phase 6 — Progression and saving (complete)
**Read:** `17`, `12` §12, `14` §8–9.
- 🧠 ProgressionService (XP, ranks, credits, idempotent grants), the Mission Complete card with real data, Equipment Terminal upgrade UI, effective config application, profile snapshot to the client.
- 🧠 Save at all checkpoints; BindToClose; migrations scaffold (v1 → v2 test migration in a unit test only).
- ✅ **Tests:** (1) Rewards are granted exactly once even if the step is replayed via debug. (2) Buying an upgrade changes the behavior (e.g. the dodge cooldown measured before and after). (3) Rejoin preserves XP, credits and upgrades. (4) A simulated DataStore failure (DebugService toggle that forces errors) → readOnly mode, no data overwritten. (5) A simulated shutdown (`BindToClose`) saves.

## Phase 7 — Presentation pass (make it beautiful)
**Read:** `06` (all), `07` §6–7, `15` (all), every map doc.
- 🧱 **Dressed pass** on every area: all props from the specs, seams, trims, greebles, signage, posters, banners, cables, pipes, grime.
- 🎨 Final lighting per area (fixtures, shadows within budget), ambient particles (ash), VFX polish, ambient movers (crane, forklift, beacons), ambient NPC routes.
- 🎨 Audio hookup (keys with IDs supplied by the user), reverb zones, music state machine.
- 🎨 UI polish (motion, consistency), mobile layout check.
- 🧠 Performance measurement and optimization (`19` §6). Re-evaluate StreamingEnabled.
- ✅ **Tests:** (1) Silhouette tests (`06` §8). (2) The user approves screenshots of 12 key views: Q-3, the Ops Hall, the hangar reveal, Bay 3, the launch reveal, the outpost courtyard, the bunker interior, the basin overview, the Strider close-up, the Watcher on the ridge, the evening observation deck, the terminal message. (3) All performance budgets met (`16` §11) on PC and the phone emulator. (4) Budgets per area met (`07` §5).

## Phase 8 — Story expansion (Chapter 2: "Classified")
- Write the Chapter 2 script doc (`docs/06b_chapter2_script.md`) **with the user's approval of the outline** before building. Reuse all systems.

## Phase 9 — Additional systems
- More Frames (via config), more Titan species (via behaviors), relationship-driven optional missions, replayable Training Yard challenges.

## Phase 10 — Monetization
- `17` §7. Only after the user creates the products and supplies the IDs and prices.

## Phase 11 — Multiplayer expansion
- Social hub place plus mission instances via `TeleportService:ReserveServer`, co-op Titan hunts, party UI. Requires an architecture review (state is already per-player). Max players changes per place.

---

### End-of-phase report (Claude writes this in the journal and tells the user)
1. What was built (with part counts and scripts).
2. Tests performed and their results (pass/fail, measured numbers).
3. Known bugs and limitations.
4. Decisions made (linked to `decisions.md`).
5. What the user should look at or try (with debug commands).
6. Reminder: **save/publish now.**
