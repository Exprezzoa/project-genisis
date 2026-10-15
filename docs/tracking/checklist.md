# Implementation Checklist

**Current phase: 4 — First mission flow** (structure pass of Outpost 07 left). Phases 0–3 are built; their open acceptance tests need the user (touch and gamepad in Phases 1–2, timed fights in Phase 3). See the journal.

Tick an item only after it was **tested** and the journal records how. Full task lists and acceptance tests: `docs/18_roadmap.md`.

## Phase 0 — Audit and setup ✅ (2026-10-09)
- [x] MCP tools listed; Studio connection confirmed
- [x] Existing place inspected and summarized in the journal
- [x] User: place published; Studio API access on; Max Players = 1 — published and API read access verified by script; Max Players confirmed by the user only (Q-007, re-confirmed after the session); cloud save of the final Phase 0 state verified (D-021)
- [x] Local `src/` and `builders/` skeletons created
- [x] Studio folders created (Map, Runtime, DevTools, Templates)
- [x] BuildKit and Palette written, pushed, smoke-tested (plus a 29-case self-test, all passing)
- [x] Workspace settings applied (StreamingEnabled false, etc.) — SignalBehavior isn't scriptable; verified Deferred by behavior (D-015)

## Phase 1 — Foundation
- [x] Shared modules (Net, Signal, Trove, Log, RateLimiter, StateMachine, Easing, MathUtil) — SharedCheck 12/12 (journal Session 2)
- [x] Bootstrap (server/client Main) with Init/Start ordering — play-tested incl. a failing service
- [x] CollisionService, ZoneService, TriggerService, InteractionService, CharacterService — play-tested; the client side of the control lock and sprint comes with the UI step
- [x] PlayerDataService v1 (+ session lock, retries, memory-only fallback), FlagService, settings persistence — verified at server level (5 play sessions); the Settings menu itself is part of the UI item
- [x] Central Command blockout (all areas) + hangar shell + launch platform blockout — HubCheck and NavCheck pass; not yet checked by eye (screenshots failed); stairwell layout provisional (Q-009); Training Yard is Phase 2 (D-026)
- [x] Gameplay objects placed (spawns, triggers, prompts, nav nodes, waypoints) — 3 helper nav nodes pending Q-010
- [x] Elias StarterCharacter; default animations verified; AnimationIds captured
- [x] UI foundation (style, components, fade, on-foot HUD, prompts, Mission Log shell, Settings, loading screen) — tested on the keyboard and mouse path; touch and gamepad wait for acceptance test 6
- [x] Lighting presets + controller
- [x] DebugService/Controller
- [ ] Phase 1 acceptance tests (roadmap) all PASS — 1, 2, 3, 4, 5, 7 pass (journal Sessions 2 and 3); **6 (touch emulator, gamepad) needs the user**

## Phase 2 — Frame prototype
- [x] Vanguard rig (Units 01/02/03) within budget — Units 02 and 01: 1,307 / 1,308 parts at 64 studs, `RigCheck` passes; Unit 03 is the static repair prop in Bay 3 (journal Session 5)
- [x] PoseAnimator + AnimationController — `PoseCheck` 102 cases; play test with a server-driven copy of Unit 02 (journal Session 5); looks not judged by eye yet
- [x] FrameService (spawn, park, board, dismount, ownership, state machine, energy) — play-tested (journal Session 5); the action states live in `CombatService`
- [x] FrameController + Frame camera — walk, stride, acceleration, turn rate, camera orbit, zoom and collision play-tested with simulated keys (journal Session 5); mouse, gamepad and touch look not tried by hand; root motion, separation, lock-on and shake come with combat
- [x] Combat requests, timelines, hitbox sampling vs. simulacrum — play-tested (journal Session 5): lock in the hangar, light chain, heavy with lunge, special with cost and cooldown, dodge, dodge-cancel, zones and damage, separation; lock-on and Core Strike wait for Titans
- [x] Frame HUD + feel (dust, trails, hitstop, shake) — play-tested with screenshots (journal Session 5); effects counted, not judged in motion; no sounds
- [x] Training Yard blockout + simulacrum — `HubCheck` passes, hurtboxes read back (journal Session 5); not yet walked in play mode
- [ ] Phase 2 acceptance tests all PASS — 1–6 and 8 PASS (journal Session 5); test 7 only in part: gamepad buttons simulated, sticks and touch need the user

## Phase 3 — Titan encounter
- [x] Strider rig within budget — built from the user's Titan body (D-056), 55 parts, play-tested standing and taking hits (journal Session 6); look approved by the user 2026-10-10
- [x] TitanService + StriderBehavior (full state machine) — D-057; play-tested state by state (journal Session 6, continued)
- [x] Hurtbox states, Core Strike, lock-on — D-057, D-060, D-062; play-tested (the blade lands 0.9 studs from the core). The lock marker and the strike camera are verified by state only: the user's eyes are still wanted on both
- [ ] Titan HUD, telegraph VFX, Ash Collapse — built and play-tested by state and screenshots (D-059); several effects not yet seen in motion (journal)
- [x] Frame damage states and Disabled flow — D-063; states, plates, card and retry play-tested by state (journal); not yet seen as pictures
- [ ] Phase 3 acceptance tests all PASS — 2 to 8 pass (journal); **1 (three fights, 2–3.5 min) needs the user**: their first fight took about a minute, health was raised to 6000 (D-064), re-timing wanted. The user said to go on to Phase 4 (2026-10-10)

## Phase 4 — First mission flow
- [x] Outpost 07 blockout + structure (all areas) — blockout (D-067) driven and walked end to end (Session 7 autopilot run); structure pass: Ridge (D-070), the compound with the power-on effect (D-078), Trail and Basin (D-079); 1,057 parts, 46 lights. Props are the dressed pass (Phase 7)
- [x] SequenceService + actions/conditions; CH1 S10–S33 — S08–S33 built and play-tested (D-069, D-071, D-075; journal Session 7); split into Sequence/Actions and Conditions; cinematics, C3 and the hub scenes are Phase 5
- [x] AllyFrameService — Follow, Hold, Combat, Scripted, Parked (D-074); play-tested (journal Session 7); Scripted not used by any step yet
- [x] Checkpoints + restore + fail/retry — resume on join, all 7 mission checkpoints rejoined for real (D-072, D-076; journal Session 7); fail/retry of S28 from Session 6
- [x] Phase 4 acceptance tests all PASS — 1–6 PASS (journal Session 7; test 1 by a client autopilot with no debug commands, in two legs joined by a rejoin)

## Phase 5 — Story introduction
- [ ] All NPCs, Watcher rig, MemorySet
- [ ] Dialogue, relationships, evidence, barks, tutorials, NPC behaviors, cinematics, PA
- [ ] All scenes S01–S43 wired exactly per script
- [ ] Cards, terminal, boot, anomaly effects
- [ ] Phase 5 acceptance tests all PASS

## Phase 6 — Progression and saving
- [ ] ProgressionService, Mission Complete card, upgrades terminal
- [ ] Saves at all checkpoints, BindToClose, migration scaffold
- [ ] Phase 6 acceptance tests all PASS

## Phase 7 — Presentation
- [ ] Dressed pass on all areas
- [ ] Final lighting, VFX, ambient movers and NPCs
- [ ] Audio hookup (IDs from user)
- [ ] UI polish + mobile check
- [ ] Performance budgets met
- [ ] User approved 12 key screenshots

## Phases 8–11
- [ ] (planned — see roadmap)
