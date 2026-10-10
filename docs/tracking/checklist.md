# Implementation Checklist

**Current phase: 1 — Foundation.** (Phase 0 completed 2026-10-09; see journal Session 1.)

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
- [ ] Vanguard rig (Units 01/02/03) within budget — Units 02 and 01 built, `RigCheck` passes (320 / 321 parts); Unit 03 (static prop) comes with the hangar bay
- [x] PoseAnimator + AnimationController — `PoseCheck` 102 cases; play test with a server-driven copy of Unit 02 (journal Session 5); looks not judged by eye yet
- [ ] FrameService (spawn, park, board, dismount, ownership, state machine, energy)
- [ ] FrameController + Frame camera
- [ ] Combat requests, timelines, hitbox sampling vs. simulacrum
- [ ] Frame HUD + feel (dust, trails, hitstop, shake)
- [ ] Training Yard blockout + simulacrum
- [ ] Phase 2 acceptance tests all PASS

## Phase 3 — Titan encounter
- [ ] Strider rig within budget
- [ ] TitanService + StriderBehavior (full state machine)
- [ ] Hurtbox states, Core Strike, lock-on
- [ ] Titan HUD, telegraph VFX, Ash Collapse
- [ ] Frame damage states and Disabled flow
- [ ] Phase 3 acceptance tests all PASS

## Phase 4 — First mission flow
- [ ] Outpost 07 blockout + structure (all areas)
- [ ] SequenceService + actions/conditions; CH1 S10–S33
- [ ] AllyFrameService
- [ ] Checkpoints + restore + fail/retry
- [ ] Phase 4 acceptance tests all PASS

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
