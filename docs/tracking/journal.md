# Development Journal

Claude appends one entry per session (newest at the bottom). Keep entries factual and short.

## Template
```
### Session <n> — <YYYY-MM-DD> — Phase <x>
**Goal this session:** ...
**Studio state found at start:** ...
**Done:**
- ...
**Tested (how → result):**
- <test> → PASS/FAIL (numbers, console notes)
**Known bugs:** BUG-<n> ... (template in docs/19_testing_and_debug.md §7)
**Decisions made:** (also logged in decisions.md) ...
**Next steps:**
- ...
**User actions needed:** (save/publish, provide IDs, screenshots, manual settings)
```

---

<!-- Entries start below -->

### Session 1 — 2026-10-09 — Phase 0 (complete)
**Goal this session:** Phase 0, audit and setup, exactly as `docs/18_roadmap.md` describes.

**Studio state found at start:** place "Place2", PlaceId 122397499718036, GameId 10770033029, PlaceVersion 2 (already published), Studio 0.742.590. A fresh Baseplate template: `Workspace` = `Baseplate` (2048 × 16 × 2048, top at Y 0), `SpawnLocation` (0, 0.5, 0), `Camera`, empty `Terrain`; `Lighting` = default Atmosphere, Bloom, DepthOfField, Sky, SunRays; no scripts anywhere; ReplicatedStorage, ServerScriptService, ServerStorage, StarterGui, StarterPack empty. `StreamingEnabled = true`, Gravity 196.2, FallenPartsDestroyHeight −500. `Lighting.LightingStyle = Soft` (unified lighting; `Technology` isn't readable).

**Done:**
- Listed the 30 `Roblox_Studio` MCP tools; confirmed code execution (`return game.Name` → `Place2`).
- Local skeletons: `src/` (12 folders per `16` §2) and `builders/` (per `07` §1, plus `checks/`), each with a README.
- Studio folders: `Workspace.Map`, `Workspace.Runtime`, `ServerStorage.DevTools`, `ServerStorage.Templates.{Rigs,NPCs,Frames,Titans,Props}`.
- `builders/lib/Palette.lua` (93 lines, 65 colors) → `DevTools.Palette`.
- `builders/lib/BuildKit/` (6 modules, 1,784 lines, the full `07` §3 API: 45 functions plus documented additions) → `DevTools.BuildKit`.
- `builders/checks/BuildKitCheck/` (5 modules, 1,188 lines: smoke test + 29 self-test cases) → `DevTools.Checks.BuildKitCheck`.
- Workspace settings: `StreamingEnabled = false` (was true); Gravity and FallenPartsDestroyHeight already correct.
- `docs/07` §1 and §3 updated; new §3.1 documents the additions and conventions.
- Nothing permanent was added to `Workspace` besides the two empty folders. The template Baseplate and SpawnLocation are untouched.

**Tested (how → result):**
- DataStore access: one `GetAsync` on a missing key from edit mode → PASS (returned nil in 0.27 s, so Studio API access is on). No write was made.
- Push sync: bytes + Adler-32 of all 12 Studio modules vs. the local files → PASS (all equal; re-checked after the fix and after play mode).
- BuildKit load: `require(DevTools.BuildKit:Clone())` → PASS (45/45 spec functions present).
- **Smoke test** (`Check.Smoke`: 3-part model, then deleted) → PASS: `{parts: 3, lights: 0, shadowLights: 0, emitters: 0, guis: 0, ms: 0, warnings: [], builtInWorkspace: true, deleted: true}`; Workspace had 6 children before and after.
- **Self-test** (`Check.Full`) → first run 28/29 (BUG-1), after the fix **29/29 PASS**, twice in a row, ~13 ms per run, sandbox removed each time. It covers every BuildKit function: props defaults, cylinder axes, wall openings (ray-cast that a 5 × 8 doorway is fully clear and that no parts overlap), stair ramp heights, railing collider, hazard stripe paint sampled by rays, emitter presets against `06` §6, tags and attributes of every gameplay object, idempotent rebuild.
- Palette vs. `06` §3 (keys and hexes extracted from the doc by regex, compared in Studio) → PASS: 63 keys, 0 mismatches; the only extra keys are `SIGN_WHITE` and `DUST_HANGAR` (D-010).
- Large build: 4,000 parts in 63 ms (no yield needed). With `BK.yieldBudget = 0.005`: 4,000 parts in 100 ms across 12 frames → the cooperative yield works.
- Visual check: a temporary 195-part showcase, 4 screenshots → signs upright and not mirrored, floor text and pad text readable from above, hazard stripes clean, stairs, railings and mezzanine line up. Showcase removed afterwards.
- **Play-mode walk test** on the showcase (server script driving the character): up the 8-step stairs → +8.00 studs in 1.7 s, smooth (about 1.0 stud of height per 0.1 s); walking into the mezzanine railing → stopped at Z −9.03 (rail at −8.2), stayed on the mezzanine; back down → same floor height as at the start. PASS.
- Output during play → empty: no errors, no warnings.
- Final tree dump → matches the planned skeleton; no temporary folders left; only the `Default` collision group registered.

**Known bugs:**
```
BUG-1: Computed colors were stored one 8-bit step off
Where: BuildKit BK.darken / BK.vary (seams)   Severity: cosmetic
Repro: 1) BK.seams on a FLOOR_INTERIOR floor 2) compare the seam's stored Color with BK.darken(floor.Color, 0.08)
Expected: #4A4F55   Actual: #494F54
Notes / suspected cause: parts store 8-bit color channels and truncate (73.6 -> 73), while Color3:ToHex rounds.
Status: fixed (darken and vary snap to the nearest 8-bit color; self-test 29/29, with a new exact-color case)
```
No open bugs.

**Limitations (not bugs):**
- `Workspace.SignalBehavior` and `Lighting.Technology` can't be read or set through the MCP. SignalBehavior was verified by behavior (Deferred). Lighting is Q-005.
- `Players.MaxPlayers` reports 60 in edit and in play mode, so Max Players = 1 can't be verified by script (Q-007).
- `BK.door`, `BK.window`, `BK.column`, railing and stair details use default dimensions the docs don't give (D-011); to be re-checked against `map_01`/`map_02` in Phase 1.
- BuildKit's emitter presets duplicate what `Shared/Modules/VFX` will hold; unify in Phase 2.
- MCP notes for later sessions: run `screen_capture` calls one at a time (parallel calls hang); `_G` persists between `execute_luau` calls within a Studio session.

**Decisions made:** D-009 (BuildKit split into child modules), D-010 (Palette contents), D-011 (BuildKit default dimensions), D-012 (BuildKit API additions), D-013 (checks in `DevTools.Checks`), D-014 (checksum-verified pushes), D-015 (SignalBehavior verified by behavior), D-016 (Baseplate and SpawnLocation left alone), D-017 (8-bit color snap).

**Next steps (Phase 1, in roadmap order):**
- Read in full: `03`, `06`, `07`, `08` §1, `11` §1–3, `13`, `14` §1–4, `16`, `17` §1–5, `map_01`, `map_02` (shell).
- Re-check the D-011 defaults against `map_01`/`map_02`. Q-005 and Q-006 are answered: apply D-018 (lighting style) with the lighting presets, and D-019 (remove Baseplate and SpawnLocation) once the hub floors and `SPAWN_Q3_DESK` exist.
- Shared modules (Log, Signal, Trove, Net, RateLimiter, StateMachine, Easing, MathUtil) and the server/client bootstrap, each with a check script.
- CollisionService, ZoneService, TriggerService, InteractionService, CharacterService; then PlayerDataService v1.
- Hub blockout area by area, Ops Hall first, with `MapCheck` and `NavCheck`.
- Verify the three built-in particle textures load (`06` §6).

**User actions needed:**
- **Save now: Ctrl+S, then File → Publish to Roblox** (PlaceVersion is still 2; nothing from this session is in version history yet).
- Q-007: confirm Max Players = 1 once more in Game Settings / Creator Dashboard.
- Answer Q-005 (lighting style), Q-006 (remove Baseplate and SpawnLocation in Phase 1?) and Q-008 (Git). Q-001 (story secrets) still matters most before Phase 5.
- To re-run the BuildKit tests yourself, paste into the Studio command bar: `local DT = game:GetService("ServerStorage").DevTools; print(game:GetService("HttpService"):JSONEncode(require(DT.Checks.BuildKitCheck:Clone()).Full(require(DT.BuildKit:Clone()))))`

**After the wrap-up (same day, same Studio session):**
- The user reported saving and publishing, and checking Max Players = 1 again → Q-007 closed (still not machine-verifiable).
- Save check → PASS: `MarketplaceService:GetProductInfo(game.PlaceId).Updated` = 2026-10-09T20:33:08Z, which is 7 s after the last script run in Studio (20:33:01Z) and 2 min after the last change to the place (20:31:02Z, showcase removed). Nothing in the place was changed afterwards, so the cloud copy holds the final Phase 0 state.
- Publish check → not verifiable: `game.PlaceVersion` still reads 2 because it doesn't refresh during a Studio session, and nothing readable by script says whether a version is marked published. User-confirmed only (D-021).
- Found: the place is edited in a collaborative session (a player exists under `Players` in edit mode), which Roblox documents as auto-saving to the cloud every four minutes.
- The user answered **yes** to Q-005, Q-006 and Q-008 → D-018 (lighting: `LightingStyle = Realistic` + `PrioritizeLightingQuality = true`, checked against the Roblox reference, `06` §5 updated, **not applied in Studio yet**), D-019 (remove Baseplate and SpawnLocation in Phase 1), D-020 (Git).
- Git: repository initialized on branch `master`; commit `427ffbd` = the verified Phase 0 state (65 files); a second commit holds this follow-up.
- This follow-up changed nothing in the place.

### Session 2 — 2026-10-09 — Phase 1 (in progress)
**Goal this session:** Phase 1 in the build order given to the user (15 steps: shared modules → bootstrap → services → saving → hub blockout → Elias → lighting → UI → interactions → debug → acceptance tests).

**Studio state found at start:** exactly the end of Phase 0 (no game code, Baseplate and SpawnLocation present, `LightingStyle = Soft`, StarterPlayer defaults). Same Studio session as Session 1.

**Done so far (each pushed, checksum-equal to the local file, committed):**
- Step 1: `Shared/Modules` Log, Signal, Trove, Easing, MathUtil, TableUtil, RateLimiter, StateMachine, Types, Net (+ `Net/Validate`, `Net/Definitions`: all 25 remotes of `16` §5), `Config/GameConfig`. Check: `DevTools.Checks.SharedCheck`.
- Step 2: `Shared/Modules/Loader`, `Server/Main.server`, `Client/Main.client`; empty `Services`, `Controllers`, `UI`, `Sequence`, `Titans` folders in Studio.
- Step 4a: `CollisionService`, `ZoneService`, `TriggerService`, `InteractionService`, `Config/Zones`.
- `ServerScriptService.DevTests` (Studio-only test bridge, `ServerStorage.DevBridge`; gated by `DevTools` attribute `RunTests`, now true).

**Tested so far (how → result):**
- `SharedCheck.Full()` in edit mode → PASS 12/12, twice (signals, Trove cleanup order, 9 eases, token buckets with a fake clock, state machine, payload validators incl. NaN/infinity/non-unit vectors/65-char strings/unknown keys, handler wrap, Loader order and failure messages).
- Bootstrap in play mode → PASS: `ServerReady` set, 25 remotes on server and client, `Client_Ready` → `Server_Ready`, player attribute `ClientReady`.
- Boot failure → PASS: a temporary broken `DebugService` stopped the boot with `[Main] DebugService.Init failed: ...` plus a stack; `ServerReady` stayed nil. Module removed afterwards.
- Collision matrix → PASS: all 45 group pairs equal `07` §5 (read back with `CollisionGroupsAreCollidable`).
- Zones → PASS: origin = `OpsHall`, Q-3 = `Quarters`, hangar, bunker, void = nil; `Zone` attribute replicated.
- Triggers → PASS: walking into and out of a test box fired `Entered`/`Exited(…, foot)` once each; `isInside` correct.
- Interactions → PASS: prompt in range accepted (`Interacted` fired); `Once` prompt disabled for that player only (`PromptOff_<id>` attribute); `canInteract` refuses Frame-only on foot, too far, disabled, dead character, unknown id.
- Output after each play test → no errors, no warnings.

**Known bugs:**
```
BUG-2: "Once per session" rate limit let a second Client_Ready through
Where: Shared/Modules/RateLimiter   Severity: major
Repro: 1) play 2) fire Client_Ready again from the client a few seconds after boot
Expected: dropped   Actual: accepted (a second Server_Ready came back)
Notes / suspected cause: buckets were kept in a weak-keyed table; a Player key with no other Luau reference was collected, so the player got a fresh bucket.
Status: fixed (strong keys; Net resets a leaving player's buckets on PlayerRemoving; play test: 2 extra Client_Ready calls both dropped)
```

**Notes:**
- MCP snippets run in a different script context than game scripts, so `require` returns a separate copy of each module. Running services are reached through the DevBridge instead.
- The engine only fires `ProximityPrompt.Triggered` for the prompt it currently shows, so server-side refusals are tested through `InteractionService.canInteract`.
- Per `map_00` §2 order, the top of the east stairwell (Y > 21) resolves to `Arrival`, not `ObservationDeck`. Both zones have identical lighting/reverb/weapons, so nothing changes; left as specified.

**Session 2, continued (same day):**

**Done:**
- Step 4b/5: `PlayerDataService` v1 (load with session lock, migrate/reconcile, autosave, leave and shutdown saves, read-only and memory-only modes, `Profile_Snapshot`, `Settings_Update`), `FlagService`, `CharacterService` (spawn after profile load, respawn at last spawn, teleport, control-lock attribute), `tools/checksum.ps1`.
- Steps 6–8: 17 map builders + `builders/maps/Common.lua` (marker and nav registries). Blockout of all hub areas (Ops Hall with mezzanine, both corridors, Quarters, Briefing, Equipment, Medical, Observation Deck, stairwell, Research + Voss Lab shell, Arrival, exterior ground + perimeter) and of the hangar (shell, bay markings, catwalks/main stair/bridges, gate corridor, launch platform deck). Gameplay objects: 28 markers, 9 prompts, 4 triggers, 9 cam points, 3 doors, 51 nav nodes, FrameBarriers and PlayerBarriers. **871 parts** (hub 505, hangar 366), 0 lights.
- Checks: `DevTools.Checks.HubCheck`, `DevTools.Checks.NavCheck`.
- Step 9: `builders/place/PlaceSettings.lua` applied (D-028); **Baseplate and SpawnLocation removed** (D-019).
- Step 10: `R15Base` in `Templates.Rigs`; `CharacterKit` + `Elias` → `StarterPlayer.StarterCharacter` (16 body parts + 25 gear parts); `Config/AnimationIds` read from the live Animate script.

**Tested (how → result):**
- Saving, 5 play sessions → PASS: fresh profile loaded in < 1.5 s and the character spawned at `SPAWN_Q3_DESK` facing −Z; a flag and a `Settings_Update` (camSensitivity 1.5, subtitleSize L) were in the raw DataStore entry with this session's lock (`saveCount` 1); after Stop the entry had `_lock = nil`, `saveCount` 2; after Play again both values were back (**acceptance test 4 at server level**). An out-of-range setting (9) was rejected. `player:Kick()` → entry saved with the new flag, lock released, `Saved(…, leave)` (**first half of acceptance test 5**). A foreign lock written 12 s before joining → 6 tries × 5 s, then stolen with a warning, flags intact (30 s; a lock that is released normally is taken on the next try). `TestDataStoreFailure` → 5 logged attempts, read-only session, toast "Couldn't load your save…", play continued, stored entry byte-identical afterwards. `TestMemoryOnly` → the exact warning of `17` §1, character spawned, nothing written. Autosave fired at 120 s.
- CharacterService → PASS: teleport to `SPAWN_OPS`; killing the character respawned it there after 2.9 s; characters are in the `Players` group; the `PlayerBarrier` stopped the character (X −27.5 against a face at −28) while a `FrameBarrier` didn't.
- `HubCheck` → PASS: every registry id exactly once (deferred ids absent), 17 door openings, smallest 5 × 8 (**acceptance test 2**), 13 area bounds within 1 stud, budgets 505/9,000 and 366/6,000.
- `NavCheck` → PASS: 51 nodes, 50 links, floor + headroom on every node, every link walkable both ways, graph connected. First runs failed on the doc's stairwell and on three links (Q-009, Q-010) and found a railing collider leaning over the landing (fixed in the builder).
- Play-mode walk test → PASS: from Q-3, all 50 links walked with `Humanoid:MoveTo` at walk speed in 5 routes, 1,787 studs, never stuck, worst delay over the straight-line time 0.22 s; zones and `TRG_BRIEFING_ENTER` / `TRG_HANGAR_REVEAL` fired on the way (**acceptance test 1**, server-driven; a hands-on walk by the user is still worth doing).
- Without Baseplate → PASS: removed during a play session first; the character stayed at Y 3.06 on `SmoothPlastic`, then walked all routes.
- Elias → PASS: spawns as the built character (suit, skin, gloves, boots colors read back), 0 avatar accessories, default `Animate` present, idle track while standing, `WalkAnim`/`RunAnim` tracks while walking.
- Output after every play test → no errors; warnings only where a test provoked them (failed loads, lock steal, rejected payload).

**Not tested / limitations:**
- **Screenshots: untested.** `screen_capture` returned a black viewport twice this session, so nothing built today was checked by eye. Please look at the hub and send screenshots.
- Once, a client snippet found the fresh character 17 studs from the spawn (in the Quarters hallway). Not reproduced: an 8-second position trace after spawn in the next session stayed on the spawn. Possibly keyboard input in the play window. To watch.
- The interiors have no light fixtures yet (blockout pass); with the roofs on they will be dim until the lighting step.

**Next steps (Phase 1, remaining):**
- Step 11: `Config/LightingPresets` + `LightingController` (MORNING), verified against `06` §5; decide with screenshots whether the blockout needs the fixture lights of the structure pass.
- Step 12: UI foundation (`UIStyle`, components, fade, HUD with objective/toasts/subtitles, custom prompts, Mission Log shell, Settings menu, loading screen), `InputController`, `CharacterController` (sprint, control lock).
- Step 13: static interaction handlers (photo, locker, window, poster, holo, status wall, research door) → thought subtitles.
- Step 14: `DebugService` / `DebugController`.
- Step 15: acceptance tests 3, 5 (rejoin part), 6, 7 and the regression list; end-of-phase report.

**User actions needed:**
- **Save and publish now** (Ctrl+S, File → Publish to Roblox): the hub blockout exists and the Baseplate is gone; publishing creates the version to roll back to.
- Answer Q-009 (stairwell layout) and Q-010 (three helper nav nodes).
- Send 4–6 screenshots: Q-3, Ops Hall from the south door, the mezzanine stairs, the stairwell gallery, the hangar from the south entrance, the catwalk stair.

### Session 3 — 2026-10-09 — Phase 1 (steps 11–14; acceptance tests 1–5 and 7 pass, 6 needs the user)
**Goal this session:** finish the Phase 1 build order: lighting, UI foundation, hub thoughts, debug commands; then the acceptance tests.

**Studio state found at start:** as left by Session 2 (same Studio session). The user answered **yes** to Q-009 and Q-010 → D-025 and D-027 are final; `map_01` §9 and §13.2 now describe the built stairwell and nav graph. The cloud copy had been updated 15 min before the session.

**Done:**
- Step 11: `Config/LightingPresets` (5 presets), `LightingController` (zone-driven, `Lighting_Set`, 1.5 s tween or instant), client half of the test bridge (`StarterPlayerScripts.DevTests`, `PlayerScripts.DevBridge`).
- Step 12: `Config/UIStyle`, `Config/Bindings`, `UI/Components`, `UIController` (7 layers + scale rule + the one fade), `InputController`, `SettingsController`, `CharacterController` (sprint, control lock, FOV), `HUDController` (objective tracker, toasts, subtitles), `InteractionController` (custom prompt billboards), `MenuController` (pause + 12 settings rows), `MissionLogController` (shell, 3 tabs), `MobileControlsController` (SPRINT, LOG, menu), `ReplicatedFirst.LoadingScreen`.
- Step 13: `Dialogue/Speakers`, `Dialogue/CH1_Hub` (8 thought lines, text exactly as `05`), `Sequence/StaticInteractions`, handlers in `InteractionService`.
- Step 14: `Config/Debug`, `DebugService`, `DebugController` (F2 panel; `/tp /zone /flags /flag /save /wipe /dsfail /lighting /fps /nav /help`).
- Totals: 48 game scripts, 5,281 lines (longest: PlayerDataService, 475); map 871 parts.

**Tested (how → result):**
- Lighting → PASS: 25 MORNING values read back from `Lighting` equal `06` §5 (expected values typed separately from the config); tween to EVENING (ClockTime 13.1 mid-way, 18.9 at the end); instant NIGHT; `Lighting_Set` from the server; `/lighting`. First run FAILED at boot: game scripts can't write `LightingStyle` → moved out of the runtime presets (D-030).
- UI → PASS (client bridge, 859 × 392 viewport): layers HUD 10 / Prompts 15 / Dialogue 20 / Cards 30 / Menu 40 / Letterbox 50 / Fade 90 / Loading 100; scale 0.747 = 0.65 × 1.15 (phone rule); loading screen hid after 1.6 s with `Server_Ready`; objective + optional line; 4 toasts → 3 kept, gone after 3.5 s; radio subtitle `[OVERWATCH]` in the speaker color, cleared after its duration; fade to black and back; Menu/Tab open and close screens, switch the context to `Menu`, lock and restore movement, blur only on the Mission Log; sprint 14 ↔ 22.
- **Acceptance test 3** → PASS: photo (first line, then the repeat line), locker (line, flag `CH1_TOOK_PATCH`, prompt gone for good), window, poster, holo-table, status wall and research door (line once, "ACCESS DENIED" toast every time) each showed the script's text as an italic thought subtitle. Prompts only appear while on screen; two of my teleport tests first looked like failures for that reason.
- **Acceptance test 4** → PASS through the real path: `SettingsController.set` (subtitle size M, music 35%, invert Y on) → server profile → Stop/Play → the values came back, the subtitle label used 22 px, the Settings rows showed "M", "35%", "ON". The locker prompt stayed off after the rejoin.
- **Acceptance test 5** → PASS with a caveat: `Kick()` saved the profile and released the lock within 2 s; the rejoin (Stop/Play through the MCP) came **16 s** after the save, not within 10 s; the profile loaded at once with the flag, no lock wait. The held-lock case was measured in Session 2 (6 × 5 s, then stolen).
- Debug → PASS: every Phase 1 command gave the expected result (teleports, unknown spawn, unbuilt zone, flag on/off, bad flag name, lighting, `/dsfail on` → 3 failed attempts, `/dsfail off` → the retry wrote, later-phase commands refused, `/fps` "FPS 240 | ping 1 ms | parts 913 | physics 60 Hz", `/nav` 51 nodes + 50 links, `/wipe` asks for confirm).
- **Acceptance test 7** → PASS: Output clean in every play session, except lines a test provoked on purpose (simulated save failures, rejected payloads).
- Regression in edit mode after the last change → BuildKitCheck 29/29, SharedCheck 12/12, HubCheck pass, NavCheck pass (51 nodes, 50 links). All pushed files checksum-equal to the local files.
- Screenshots work again: hub overview and Ops Hall interior look as specified (mezzanine, stairs, offices, openings, columns). The interiors are dim (no fixtures in the blockout pass), and a thin line of daylight shows where the 1-thick Ops Hall side walls meet the corridor roofs.

**Not tested:**
- **Acceptance test 6 (touch emulator, gamepad menus): untested.** The MCP can't switch the device emulator or send gamepad input. The touch buttons and the gamepad selection code exist; only the keyboard/mouse path was exercised.
- The on-foot camera in small rooms and the look of the UI were not judged by eye in play mode (screenshots are edit-mode only).

**Known bugs:** none open. (The Session 2 note about a character found 17 studs from its spawn did not recur in 8 further play sessions.)

**Decisions made:** D-030. Q-009 and Q-010 closed.

**Next steps:**
- User: acceptance test 6 and a hands-on walk (below). If both are fine, Phase 1 is complete and the end-of-phase report can be written.
- Decide whether the hub should get its ceiling light fixtures now (they are structure-pass items) or stay dim until the structure pass.
- Then Phase 2 (read `08`, `09`, `11` §4–5, `12` §1–5 and §9–11, `14` §5, `map_02`, `map_01` Training Yard).

**User actions needed:**
- **Save and publish** (Ctrl+S, File → Publish to Roblox).
- Test 6: in Studio's Test tab choose Device → a phone (landscape), press Play: check that SPRINT, LOG and ≡ appear, that ≡ opens the menu, Settings rows can be changed by tapping, and a prompt (photo in Q-3) works by tapping. Then with a gamepad (if you have one): D-pad Up opens the menu, the stick/D-pad moves the amber selection, A activates, B goes back.
- Walk from Q-3 to the hangar and up the catwalk; try the Q-3 prompts; press F2 and type `/help`.
- The profile was wiped at the end of the tests, so you start fresh.

### Session 4 — 2026-10-10 — Phase 1 (UI feedback from the user)
**Goal this session:** the user tried the phone layout and reported (1) LOG and SPRINT overlap, (2) the UI is too simple and should look more advanced, taking inspiration from the Persona games.

**Studio state found at start:** as left by Session 3 (same Studio session).

**Done:**
- Touch layout: LOG moved to the top-right beside the menu button; SPRINT lowered 40 px (D-031, `11` §2).
- Angular restyle (D-031, `14` §1.1): `UI/Components` rebuilt around slanted slabs (`slab`, `paint`, `tweenPaint`, `title`, new button states idle / highlighted / accented / disabled); pause menu with the diagonal amber band and a tilted column; Settings and Mission Log on ink slabs with tilted titles; objective tag, toasts and prompts restyled; touch buttons are tilted squares. `HUDController`, `MenuController`, `MissionLogController` and `MobileControlsController` got `build(layer)` so their screens can be built into a preview.
- Session helper `_G.PG_preview(screen)`: builds the real screens into a temporary ScreenGui in StarterGui in edit mode so they can be screenshotted (play mode can't be captured). Removed after use; nothing is left in StarterGui.

**Tested (how → result):**
- Edit-mode previews with screenshots of Pause, Settings, Mission Log and HUD → the look was checked by eye and four defects were found and fixed that way: an amber title on the amber band; slabs cut to half their width (a single rotated gradient is scaled to the frame's short side; slabs are now three Frames); slider bars cut to a stub (now rectangular); the toast panel growing to the full column height (an auto-sized panel with a scale-sized backing; toasts now size themselves from their text).
- Text fit, numeric (`TextBounds` vs `AbsoluteSize`) on all four previews → 52–57 texts each, 0 overflowing, after widening the pause column to 440 and the fitted title width.
- Play mode → PASS: boot clean (8 services, 11 controllers, Output empty); pause/settings/log open and close and lock/restore controls; a settings toggle shows the accented "on" look; the photo prompt appears with its slanted slab and shows the thought line; toasts 360 × 44 (one line) and 360 × 58 (two lines), gone after 3.5 s.
- Touch layout at 859 × 392, computed from the buttons' rectangles → no overlaps between SPRINT, LOG, menu and the objective tracker; with two optional objective lines the tracker ends 18 px above SPRINT.

**Not tested:**
- The restyle on a real phone emulator, and gamepad selection on the new buttons (acceptance test 6 is still open).
- The band sweep and hover animations were not seen (screenshots are stills of edit-mode previews).

**Known bugs:** none open.

**Decisions made:** D-031.

**Next steps:** user review of the new look (pause menu, settings, mission log, HUD, prompts) on PC and in the phone emulator; then close acceptance test 6 and Phase 1.

**User actions needed:** save and publish; look at the UI in play mode and say what to push further (more tilt, bolder titles, more motion) or pull back.

**Session 4, continued: character stage (user request)**

**Done:** `Client/UI/CharacterStage` (silhouette of Elias in a ViewportFrame, color field, stripe, band; one shot and color set per screen; camera, color and slide transitions). `MenuController` opens/hides the stage and its `backdrop` is now an empty container; Settings body 760 wide at 40% from the left; Mission Log page limited to the left 62% (D-032, `14` §1.2).

**Tested (how → result):**
- Edit-mode previews with screenshots of Pause, Settings and Mission Log → the silhouette, shadow, field and stripe render; first shots were too close (black blobs) and were pulled back; the silhouette got its three flat tones.
- Play mode, values read from the client → PASS: stage hidden while closed; Pause: camera (−5.0, 3.6, −9.5), FOV 38, field `#E8A33D`, 41 silhouette parts and a shadow model (so `StarterCharacter` is reachable from the client); 0.2 s after switching to Settings the camera was part-way (−2.7, 5.0, −6.0) and the field color mid-blend, then settled at (−2.4, 5.2, −5.6), `#9FB4C4`; Mission Log (4.4, 3.7, −6.6), `#FFD38A`; closing hid the stage and unlocked movement. Output clean.

**Not tested:** the transitions in motion (only values were sampled; stills only), the stage in the phone emulator (the right side may be narrow there), gamepad.

**Session 4, continued: one-color animated silhouette (user request)**

**Done:** `Client/UI/SilhouetteRig` (new: poses an anchored R15 clone from joint angles, gear follows its welds). `Client/UI/CharacterStage` reworked: one ink color (three tones removed), a pose and a gesture per screen, an idle layer, `update(dt)` on RenderStepped while a menu is open; shots re-framed for a one-color outline (D-033, `14` §1.2).

**Tested (how → result):**
- Checksums local vs Studio → both files match (`CharacterStage` 11932 bytes / 2760684084, `SilhouetteRig` 4019 / 3647420698).
- Edit-mode previews with screenshots → Pause reads as a striding figure with a raised fist (first tries: hand on hip and legs were lost in the outline; the leading leg was swapped so the legs separate from that camera); Settings reads as a hand at the mask with the elbow out; Mission Log reads as a profile with the head bowed over a raised forearm (re-framed once: the head was behind the CLOSE button).
- Play mode, part positions sampled from the client → PASS: 1 distinct part color; on Pause the head yaw went 20.3° → 16.1° → 9.6° and the right hand rose and sank (Y 3.39 → 3.50 → 3.23) over 2.5 s; switching to Settings moved the left hand from Y 2.3 to 3.98 after 0.1 s and 4.95 after 0.35 s (eased, not a jump); Mission Log put the right hand at (1.4, 3.7, −1.6) and bowed the head; after closing, the stage was hidden and the parts no longer moved. Output clean.

**Not tested:** how the motion looks to the eye (only positions were sampled and stills captured); framing at 16:9 and in the phone emulator (the previews were in a wide, short Studio viewport); gamepad.

**Known:** arms and legs are the blocky avatar's, so the outline is chunky; knees and elbows only bend one way and feet are not planted (no ground is shown).

**User actions needed:** save and publish; open the pause menu in play mode and say whether the amount of motion is right (it can be turned up or down in `IDLE` and each screen's `motion`).

**Session 4, continued: more motion, menu opening show, detail pass on all UI (user request)**

**Done:** `Client/UI/Transitions` (wipe, slideIn) and `Client/UI/StageDressing` (motes, sweep line, faint screen name, zone and clock readout), both new. `CharacterStage`: opening show (wipe, camera pull-back, rise from a crouch, mote rush), 0.16 s close animation, stronger idle (13 waves plus body sway and turn), bigger gestures. `Components`: `enter`, `cascade`, `tag`, `tweenFade`, highlight tick, press kick. `MenuController`: content cascades in on every open, index tags on the pause buttons. `HUDController`: objective typewriter, toast draw-in and fade-out, subtitle fade. `InteractionController`: prompt pop and rocking key box. `LoadingScreen`: angular restyle with a wipe exit (D-034, `14` §1.2, §1.3, §2, §4).

**Tested (how → result):**
- Checksums local vs Studio → all 9 changed files match.
- Edit-mode preview with a screenshot of Pause → tags 01 to 05, motes, the faint "PAUSED", the readout and the sweep line render.
- Play mode, values sampled from the client → PASS. Opening: 0.03 s after open 3 wipe bars exist, dim 0.79, FOV 50.2, camera Z −6.3, torso Y 0.86, first button slab at −90 px; at 0.23 s dim 0.38, FOV 40.6, torso 1.63, slab at 0; at 0.63 s FOV 38.0, torso 2.15; at 1.8 s no bars left, torso 2.22. Readout read `QUARTERS  //  T+00:00:14` and counted up. Settings: body 37 px low at 0.05 s, in place at 0.95 s, word `SETTINGS`. Close: still visible and fading at 0.05 s, hidden at 0.35 s. Open, close and reopen within 0.1 s → ends open and correct; final close hides it and unlocks movement.
- HUD in play mode → PASS: objective text revealed 5 → 18 → all characters; toast underline 0.73 → 0.88, tick present, gone from the state at 3.5 s, still fading at 3.65 s, destroyed by 4.05 s; subtitle transparency 0.65 → 0 and back in place; the photo prompt showed at full scale with its key box rocking (1.6° at the sample).
- Loading screen in play mode → hid after 1.5 s with `ServerReady = true`, status `READY`, band in place, GUI disabled afterwards. Output clean in every run.

**Not tested:** how any of it looks in motion (values and stills only); the loading screen was never seen (it is gone before a capture is possible); 16:9 and phone framing; gamepad; touch.

**Known:** the lights for the hub interiors are postponed on the user's word ("lets do the lights later"). The touch buttons (`MobileControlsController`) did not get a detail pass.

**User actions needed:** save and publish; watch the menu open and the loading screen once and say what to push or pull back; run acceptance test 6 (phone emulator, gamepad).

---

## Session 5 — 2026-10-10 — Phase 2 start: configs and the Vanguard rig

**Start state:** Phase 1 done except acceptance test 6 (touch, gamepad; needs the user, D-036). Studio: hub and hangar blockouts, `Templates.Frames` and `Shared.Poses` empty.

**Build order for Phase 2:** (1) configs, (2) Vanguard rig builder, (3) PoseAnimator, pose set, PosePreview, AnimationController, (4) Training Yard blockout, simulacrum, pad, (5) FrameService, (6) FrameController and Frame camera, (7) combat, (8) Frame HUD and feel, (9) debug commands and the 8 acceptance tests.

**Done:**
- `Shared/Config/FrameConfig`, `CombatConfig`, `Locomotion`, `CameraFeel` (numbers from `09` §4, `12` §3 to §10, `08` §4.5, `06` §6, `11` §4).
- `builders/rigs/Vanguard.lua` and the templates `ServerStorage.Templates.Frames.Vanguard_02` and `Vanguard_01` (accent color, unit numbers, Mara's "41" tally).
- `builders/checks/RigCheck.lua`.

**Tested (how → result):**
- Checksums local vs Studio → all 6 new files match; the 4 configs load with `require`.
- `RigCheck` in edit mode → PASS for both units: 9 kinds of main part at the sizes and centers of the table, 15 limb joints with pure-offset C0/C1 at the joint positions, HatchHinge and PileDriver offsets, HRP and Humanoid settings, no Animator, nothing anchored, every part joined to the HRP, no detail part collides or answers queries, required parts present, 320 and 321 parts (budget 450), main parts top out at 40.00.
- Two screenshots of a preview copy → reads as the brief: blocky torso, big pauldrons, amber visor and core vents, the blade in the right hand pointing forward, the pile driver on the left forearm. The preview was removed afterwards.

**Not tested:** the rig in play mode (physics, standing on its HipHeight, the seat); wedge orientations were only judged from two angles.

**Known:** the first RigCheck run reported every part as not joined (`GetConnectedParts` returns nothing outside Workspace); the check now walks the joints itself and caps its messages at 20.

**Next:** step 3 (PoseAnimator, `Shared/Poses/Vanguard`, PosePreview, AnimationController).

**Session 5, continued: step 3 (pose animator)**

**Done:** `Shared/Modules/PoseAnimator` (compile, sample, weight, gait, compose), `Shared/Poses/Vanguard` (19 clips), `builders/tools/PosePreview` (edit-mode forward kinematics), `builders/checks/PoseCheck`, `Client/Controllers/AnimationController` (locomotion, action layer with cross-fade, breathing, head look, attribute sync, prediction hooks, hitstop, distance LOD, clip and footfall signals). Rojo declined by the user (Q-004 closed): code stays MCP-only.

**Tested (how → result):**
- Checksums local vs Studio → all 5 files match.
- `PoseCheck` in edit mode → PASS, 102 cases: every clip of `08` §5.1 exists, every pose joint is a rig joint, clip durations and HitboxStart/End equal `CombatConfig` for all 5 moves, dodge and Core Strike timings, sampling, inherited joints, weights, gait at phases 0, 0.25, 0.5, speed blend, upperBodyOnly, rotation convention, events.
- PosePreview, measured in the rig's space for 12 poses → feet within 0.1 stud of the floor in every attack pose (Kneel 0.4, Disabled 0.7 into the floor); Light1 swings the blade tip from the right (26, 46, −25) to the left (−35, 20, −5); Light3 raises it overhead and ends with the tip at ground level; the spike tip reaches (−8, 9, −24).
- Play mode with a test copy of Unit 02 in the Training Yard area, server-owned → the rig stands (HRP 19.0 above the ground, upright, Running state, mass 420). The client saw the server's clips 0.01 s after they were set; Light1 turned the waist from −35° to +35° (past −30° at 0.12 s, past +30° at 0.29 s); the spike was fully out 0.46 s into the Pile Driver; the action layer cleared after Light1 ended; walking at 30 studs/s ran the gait at full amplitude; Kneel ended held at weight 1 with the root 7 studs down. Output clean.

**Fixed on the way:** the clip's playback rate and the rig's walking speed shared one field, so clips froze while the Frame stood still (first play test: waist stayed within ±5°).

**Not tested:** how the poses and the walk look to the eye. Viewport captures came back black three times in a row while the previews stood there (the first two rig captures earlier had worked), so the poses were judged from measured positions only. Prediction (`playLocal`, `cancelLocal`), hitstop and the LOD distances have no caller yet.

**Next:** step 4 (Training Yard blockout, Titan Simulacrum, dismount pad), then FrameService.

**Session 5, continued: step 4 (Training Yard blockout)**

**Done:** `builders/maps/central_command/TrainingYard.lua` → `Workspace.Map.CentralCommand.TrainingYard` (100 parts): pad, lane lines and ring, 5 FrameBarrier walls open at the west door, the Titan Simulacrum (15 Strider-sized steel parts, 2 ankle targets, a core target, 6 hurtboxes), 4 training dummies, `PAD_TRAINING`, a stand-in for the observation booth, `SPAWN_TRAINING` (added to `Common.MARKERS`; `HubCheck` now expects it and the yard's bounds). D-038.

**Tested (how → result):**
- Checksums local vs Studio → the builder, `Common` and `HubCheck` match.
- `HubCheck` in edit mode → PASS: 29 spawn points (was 28), yard bounds within 1 stud, 605 parts in Central Command.
- Simulacrum read back in edit mode → root at (−320, 29.5, −170) facing +X, 56 tall; the 6 hurtboxes sit at the Standing offsets of `10` §1.2 (Body Y 35.5, Head 51.5, ankles 6.5, arms 23; its left side to the north), are tagged `Hurtbox` with their `Zone`, answer queries and don't collide; each covers its body part. `PAD_TRAINING`: radius 14, center (−200, 0, −110), exit (−186, 0, −110), tagged `DismountPad`. Barriers are in the `FrameBarrier` group.

**Not tested:** anything in play mode (a Frame walking the yard, the barriers stopping it); no screenshot (viewport captures still come back black).

**Next:** step 5, FrameService (park Units 01 and 02 in their bays, board from the Bay 2 bridge, dismount at the pad, ownership, the action state machine, energy), with Unit 03 as a static prop in Bay 3.

**Session 5, continued: new direction from the user (written down, nothing built)**

Titans get human skin, human faces and random marketplace hair; Frames stay machines. Shifters transform in a bolt of yellow lightning with a thunder crack after hurting themselves. Recorded as D-039 in `10`, `01`, `02`, `06`, `15` and `CLAUDE.md`; questions Q-011 (yellow and cyan together) and Q-012 (how the pain is shown) are open. The Strider's part-by-part table is rewritten at the start of Phase 3; the simulacrum in the Training Yard stays a steel effigy.

**Session 5, continued: step 5 (FrameService, first part)**

**Done:** `Server/Services/FrameService`: parks Units 02 and 01 in their bays at start, hatch and board-point prompts, `board`, `dismount`, network ownership, the pilot seat, published attributes, energy with regen, weapons lock from the pilot's zone, cleanup when the pilot leaves or loses the character. `AnimationController` animates the cockpit hatch from the `HatchOpen` attribute. D-040.

**Tested (how → result), play mode, server-side calls through the dev bridge:**
- Start → both Frames stand in their bays: Unit 02 at (0, 19, −205) and Unit 01 at (−70, 19, −205), facing +Z, anchored, `Parked`; Bay 2's hatch prompt on, Bay 1's off; root in `FrameRoot`, every other part in `NoCollide`.
- Board from the spawn room → refused, "too far". From the Bay 2 bridge platform (4.4 studs from the hatch) → `canInteract` true, boarding took 1.81 s: pilot seated in `PilotSeat`, Frame unanchored and owned by the player's client, `Boot` played, state `Idle`, weapons locked (zone Hangar), the Frame stayed standing at Y 19.00.
- Energy → spend 50: 100 → 50; spend 60: refused, still 50; 0.9 s later still 50 (the 1 s delay); 2.0 s after the spend 66.6 (18/s); full again by 5 s.
- Dismount inside the hangar → refused, "outside the pad". With the Frame moved onto `PAD_TRAINING` → `canInteract` true while piloting; after the dismount the pilot stood on the concrete at the exit point (−186, 3.3, −110), unseated; the Frame was anchored, `Kneeling`, `KneelIdle`, pilot 0, hand prompt on.
- Re-board → refused from 37 studs; standing next to the board point `canInteract` true, boarding took 1.36 s with `RiseFromKneel`, Frame owned by the client again, weapons unlocked (zone TrainingYard).
- Replacing the pilot's character while piloting → the Frame was left kneeling, anchored, pilot 0. Output clean in every run.

**Bugs found and fixed here:** the pilot was left standing on the Frame's chest after dismounting (torso collisions forced on by the Humanoid, and the exit teleport overridden in the unseat frame); the hand prompt was unreachable (server-side rest pose).

**Not tested:** the prompts pressed by a real player (only `canInteract` and the handlers' functions were called); the fades and the hatch seen on screen; walking a Frame (no FrameController yet: the Frame was moved by the server for the pad test). Not built yet: Unit 03 (static prop in Bay 3), the action state machine (comes with combat).

**Known:** the board point is beside the kneeling Frame, so it can be up to about 35 studs from the pad's exit point, depending on which way the Frame faces when it kneels.

**Next:** step 6 (FrameController: movement, facing, stride, root motion, separation; CameraController Frame mode), then combat.

**Session 5, continued: Vanguard detail pass (user direction)**

**Done:** the Vanguard builder rewritten for rounded, detailed Frames (D-041): invisible bones, cylinder limbs with rolled rims, curved stave armor, drum pauldrons, a barrel chest on a ribbed waist, ball joints, pistons, rivets, hoses and wires on every limb, flank cable bundles, and Beam cables across knees, elbows and neck. Split into `builders/rigs/Vanguard/` (`init`, `Kit`, `Legs`, `Torso`, `Arms`). `RigCheck` budget 450 → 1,500. `09` §1-2 updated. The user's `AttackTitan` model recorded as the Shifter look reference (D-042, Q-013).

**Tested (how → result):**
- Built Units 02 and 01 → 1,291 and 1,292 parts, 35 ms. `RigCheck` PASS (sizes, centers, 15 joints, nothing anchored, everything joined to the root, no collisions). `PoseCheck` PASS.
- Looked at in edit mode with `PosePreview` (Idle), front and back screenshots → reads as a machine with curved armor; the first version (ellipsoids everywhere) looked like balloons and was replaced; round Metal armor rendered black and was changed to SmoothPlastic.
- Play mode → both Frames park at Y 19.00 with every part in `NoCollide`; boarding Unit 02 from the bridge took 1.81 s, pilot seated, state `Idle`; server heartbeat median 4.0 ms, client frame median 4.2 ms with both Frames loaded; Output clean.
- Local files and Studio match by checksum (`Vanguard`, `Kit`, `Legs`, `Torso`, `Arms`, `RigCheck`).

**Not tested:** the new look in any pose but Idle (attack clips, kneel, walk) — parts may poke through each other when joints bend; the Beam cables seen while a joint moves; the look under the hangar's lighting; the hatch opening with its new panel.

**Known:** curved armor (SmoothPlastic) is a shade lighter than flat armor (Metal) of the same color. The unit number on the chest side sits in the armpit, as before. `AttackTitan` sinks about 27 studs when play starts (unanchored, D-042).

**Next:** step 6 (FrameController: movement, facing, stride, root motion, separation; CameraController Frame mode), checking the new armor in motion on the way; then combat.

**Session 5, continued: Frames grow to 64 studs; the user's Shifter (user direction)**

**Done:** D-043 (push over loopback), D-044 (Frames 64 studs: rig scaled ×1.6, configs written as `number * S`, animator scales pose offsets, catwalks to Y 45, bridges to Z −195…−191, steeper main stair, bigger dismount pad), D-045 (`AttackTitan` is a Shifter in the game, scaled to 80 studs, moved to `ServerStorage.Reference`; Shifters are a reveal). Q-013 answered, Q-014 opened.

**Tested (how → result):**
- Rebuilt Units 02 and 01 → 1,291 / 1,292 parts, model scale 1.60, bounding box 51.2 × 67.8 (with fin and antenna), main parts top out at 64.00, HipHeight 22.4. `RigCheck`, `PoseCheck`, `HubCheck`, `NavCheck` all PASS after the rebuild of `Catwalks`, the hangar `Gameplay` folder and the `TrainingYard`.
- Edit mode, Frame previewed in Bay 2 → stands inside the bay, the catwalk and bridge meet it at chest height (screenshot; the hangar has no lamps yet, so it is dark).
- Play mode → both Frames park with the root at Y 30.40; standing on the Bay 2 bridge (Y 48.3) the hatch is 5.5 studs away and the prompt allows boarding; boarding took 1.81 s; dismount on `PAD_TRAINING` put the pilot at the new exit point (−174, 3.3, −110) and the Frame kneeling; re-boarding from the board point (on the ground at Y 3.0) worked, weapons unlocked in the yard. Output clean.
- All changed files match Studio by checksum.

**Not tested:** walking up the steeper stair as a player (45 steps, 47°); the kneel and the other poses seen at the new size; the scaled attack boxes and camera numbers (nothing uses them yet); NPC routes over the raised catwalks beyond `NavCheck`.

**Known:** the Frame is 51.2 wide in a 50-wide bay (the pauldron hubs touch the painted lines). The Breaker Blade is now 45 long and sticks far out of the bay, as it did before in proportion.

**Next:** step 6 (FrameController and the Frame camera), then combat.

**Session 5, continued: boarding bug; the Watcher**

**Done:** D-046 (Frame sank into the floor on boarding: Humanoid states are now disabled on clients too), D-047 (the Watcher is the user's `AttackTitan` model, 80 studs). Q-014 answered, Q-015 opened (cyan glow on the model).

**Tested (how → result):** play mode, the Frame's root height sampled on the client every rendered frame during boarding. Before the fix: 30.4 → 8.0 within 0.4 s of being unanchored, held for 2.5 s, back to 30.4; the client's Humanoid went `FallingDown → GettingUp → Running`. After the fix: the client's Humanoid starts in `Running`, the root stays between 30.39 and 30.40 through the whole boarding, no state changes. Output clean. `FrameConfig`, `FrameService`, `AnimationController` match Studio by checksum.

**Not tested:** the same on a second player's client (one-player Studio test only); re-boarding a kneeling Frame after this change (it uses the same path).

**Next:** step 6 (FrameController and the Frame camera), then combat.

**Session 5, continued: step 6 (FrameController and the Frame camera)**

**Done:** `Client/Controllers/CameraController` (scripted orbit camera behind the piloted Frame: pivot, distance with wheel zoom, pitch limits, shoulder offset, mouse / right stick / touch-drag look with the sensitivity and invert settings, sphere-cast collision with instant zoom-in and slow zoom-out, stride FOV, mouse lock while piloting). `Client/Controllers/FrameController` (piloting from the `Pilot` attribute, camera-relative movement with acceleration and deceleration, stride, turn-rate limited facing, limp scale, input context and camera switching, hidden pilot). `Bindings.Frame.Stride`. D-048. The user recolored the Watcher model's eyes themselves (Q-015 closed).

**Tested (how → result), play mode, Unit 02 boarded through the dev bridge, keys sent with the MCP keyboard tool, values sampled on the client:**
- Boarding → context `Frame`, camera `Scriptable`, mouse `LockCenter`, the pilot's character hidden.
- Hold W → 0 to 48.0 studs/s in about 0.43 s (config: 48 at 112 studs/s²), straight out of the bay along +Z, root height 30.4 throughout.
- Add Left Shift → speed climbing past 64.7 toward 76.8 before the south wall stopped it; FOV 70 → 78; back to 70 after.
- Hold D (camera looking +Z) → the Frame walks toward −X and turns from yaw 180° to 90° in about 0.6 s (config: 150°/s).
- Release → 48 to 0 in about 0.33 s (config: 144 studs/s²).
- Camera → squeezed to 22 studs in the bay (the north wall is 23 behind the Frame), back out to 99.2 at 48 studs/s as the Frame walked clear; squeezed again at the west wall.
- Dismount on `PAD_TRAINING` → context `OnFoot`, camera `Custom` on the character, FOV 70, mouse free, character visible, jump enabled again.
- Output clean after the fixes below. All files match Studio by checksum.

**Bugs found and fixed here:** `Spherecast` arguments in the wrong order (an error every frame); no `PlayerModule` in this place, so the move vector is read from the pilot's `MoveDirection` instead.

**Not tested:** looking around with a real mouse, a gamepad stick or a touch drag (the turn code ran only through its start-up values); wheel zoom; the touch `SPRINT` button as stride; the walk animation seen by eye; a second player watching.

**Known:**
- In the bay the camera sits only about 22 studs from the Frame's head until it walks out, because of the wall behind it.
- At the south wall the Frame's root rose by 3.2 studs for a moment (it stepped up on something there) and came back down.
- `CharacterController.getControls` waits for the same missing `PlayerModule`, so its control lock (menus, dialogue) may not stop on-foot movement; found here, not fixed, to be checked.

**Next:** step 7 (combat: `Frame_Action` requests, server timelines, hitboxes against the simulacrum, root motion, separation), then the Frame HUD and feel.

**Session 5, continued: step 7 (combat)**

**Done:** `Server/Services/CombatService` (request validation, action timelines on server time, light chain, heavy, special with energy and cooldown, dodge with cancel rules, hitbox sampling at 20 Hz, zone choice, damage and poise, training targets, speed check). `Client/Controllers/CombatController` (input buffer, prediction, following the server, rejection and timeout handling, hitstop, root motion for the dodge and the lunge). `FrameController`: movement lock during actions, root-motion drive, separation. `Bindings.Frame`: Light, Heavy, Dodge, Special, CoreStrike. `CombatConfig.dodgeClip`. Training dummies got `FrameBarrier` boxes. D-049.

**Tested (how → result), play mode, Unit 02, inputs sent with the MCP keyboard and mouse tools, results logged on the server:**
- Light attack in the hangar → nothing starts (weapons locked).
- Training Yard, 30 studs from the simulacrum's side. One light → `Light1`, hit after 0.18 s on ArmR for 36 (40 × 0.9), poise 12, back to Idle after 0.60 s.
- Three lights 0.25 s apart → `Light1` → `Light2` after 0.40 s → `Light3` after another 0.38 s (recovery start + 0.10 s each); hits 36, 40 and, for `Light3`, AnkleR 56 (70 × 0.8) with poise 48 (30 × 1.6); chain over after 0.90 s.
- Heavy → hit after 0.55 s on Body for 140, poise 50; the lunge carried the Frame forward until separation stopped it 21.8 studs from the simulacrum (13 of its 19.2 studs).
- Special → energy 100 → 50, hit after 0.40 s for 81 (90 × 0.9), poise 96 (120 × 0.8); a second press 1.8 s later did nothing (cooldown 6 s).
- Dodge with no input → backstep, about 90 studs (config 88), energy −25. Dodge while holding D → to the camera's right.
- Heavy, then dodge 0.2 s in → the dodge replaces the heavy (allowed before 0.35 s).
- Real mouse clicks (left, right) → `Light1`, `Heavy`. Wheel up twice → camera distance 99.2 → 86.4.
- Separation → a Frame dropped 10 studs from the simulacrum's center was pushed out to 21.8.
- No speed-check warnings in normal play; Output clean.

**Bugs found and fixed here:** the Frame walked up onto the simulacrum's foot and onto a training dummy (root 36 studs too high), because a Frame's root floats 22 studs up and its Humanoid steps onto what doesn't block it → separation for the simulacrum, `FrameBarrier` boxes for the dummies.

**Not tested:** mouse look (the mouse tool doesn't move the locked cursor); gamepad sticks and touch; the attack, dodge and hit-stop animations seen by eye; rejection feedback on screen (there is no HUD yet); lock-on and Core Strike (they need Titans); a second player.

**Known:**
- The speed check tripped once in a test where the test script itself teleported the Frame twice within 3 s and the Frame was on top of a dummy; it did not trip again after the barrier fix. Worth watching.
- A dodge travels about 2 studs further than its 88.
- A Frame still steps up about 3 studs on something at the hangar's south wall (seen in step 6).

**Next:** step 8 (Frame HUD: integrity and energy bars, ability panel with cooldowns, refusal flashes; feel: dust, blade trail, shake, FOV punches), then step 9 (debug commands, the Training door, Unit 03, the Phase 2 acceptance tests).

**Session 5, continued: blade swings (user feedback) and step 8 (Frame HUD and feel)**

**Done:** D-050: `Light1`, `Light2` and `Heavy` reworked so they read as blade slashes (the user saw "punching with a sword"). `Client/Controllers/FrameHUDController` (integrity, energy, ability slots with cooldowns, banner, system panel, reticle, refusal feedback, slide-in). `Client/Controllers/VFXController` (dust, blade trail, thruster flame, steam, ground ring, hit sparks, shake and FOV punches). `CameraController.shake` / `punch`. D-051.

**Tested (how → result):**
- Swings: blade tip positions computed for every key (Light1 goes from 55 right / 37 behind, through 52 in front, to 49 left, at 27–33 high on the 40-stud rig); three-phase previews of `Light1` and `Heavy` looked at in edit mode → wide horizontal arcs with the blade in line with the arm. `PoseCheck` PASS after its three Light1 expectations were updated.
- HUD in the hangar (play-mode screenshot) → bars full, "1000 / 1000", banner "WEAPONS LOCKED — HANGAR SAFETY", all four slots dimmed, glyphs LMB / RMB / Q / SPACE.
- HUD in the Training Yard after three lights and a Pile Driver (screenshot) → energy at 2 of 4 segments, the SPECIAL slot amber on its shadow with "5.4" counting down, the others available, banner gone.
- Effects, counted on the client over that sequence → 3 blade trails, 4 hit sparks, 1 ground ring (Light3), 5 shakes; walking gave 2 dust puffs and 2 footstep shakes. Output clean.
- All files match Studio by checksum.

**Bugs found and fixed here:** the DODGE slot showed as active whenever nothing was running; slot names spilled out of 72-wide leaning slabs (now 92).

**Not tested:** how the swings, trail, dust, flame and shake look in motion (only stills and counts); the no-energy flash and the cooldown twitch seen on screen; `Light2`, `Light3`, dodges and the kneel by eye; touch layout of the HUD; small screens.

**Known:** the hangar is still unlit, so the HUD sits over a dark scene there. From behind, the Frame hides the training Titan it is facing at the default camera distance.

**Next:** step 9: debug commands (`/frame`, `/tp`, `/god`), the Training door opening for Frames, Unit 03 in Bay 3, then the eight Phase 2 acceptance tests.

**Session 5, continued: user feedback (grip, speed, suit) and step 9 (Phase 2 closing)**

**Done:**
- D-052: the blade hand grips the handle; attacks slowed to about 1.7 × (config, clips, `12` §3, `PoseCheck`).
- D-053: pilot suit second pass (`CharacterKit.pilotSuit`, `shortHair`, new piece shapes); `StarterCharacter` rebuilt (83 parts). Q-016 opened (blocky body or a slimmer catalog body).
- D-054: debug commands (`/frame`, `/tp` with a Frame, `/god`, `/energy`, `/hurtboxes`, `/hitboxes`, `/door`), the Training door open in Studio, Unit 03 in Bay 3, the speed check rewritten.

**Phase 2 acceptance tests (play mode, Unit 02; keys and clicks sent with the MCP input tools; times from server logs):**

| # | Test | Result |
|---|---|---|
| 1 | Board from the Bay 2 bridge; walk the hangar to the deployment door, weapons locked | **PASS.** On the bridge the prompt allowed boarding; boarding took 1.81 s. W then A walked the Frame to (114, −151), 6 studs from the east door, root at Y 30.4 throughout. A light press there started nothing (0 actions); the HUD showed "WEAPONS LOCKED — HANGAR SAFETY" |
| 2 | Light ×3, Heavy with lunge, Pile Driver, dodge in 4 directions; timings ±0.03 s | **PASS.** Light1 hit at +0.35 / +0.36 (config 0.35); Light2 began +0.70 and +0.71 after Light1 (0.70), hit +0.32; Light3 began +0.70 and +0.69 after Light2 (0.67: 0.03 late and 0.02 late), hit +0.45, chain over 1.40 / 1.41 after Light3 began (1.40); Heavy hit +0.90, over +2.08 (0.90, 2.08); Pile Driver hit +0.60, over +1.75 / +1.76 (0.60, 1.75); each dodge 0.45 s (0.35 + 0.10), about 80–83 studs toward S, A, D and W (the north barrier stopped the first S dodge) |
| 3 | Hits register the correct zone | **PASS for the aim rule.** From the simulacrum's side: Light1 and Light2 → ArmR 36 and 40 (×0.9), Light3 → AnkleR 56 (70 × 0.8), Heavy → Body 140 / ArmR 126, Pile Driver → ArmR 81. The lock rule can't be tested until lock-on exists (Phase 3) |
| 4 | Energy spend and regen; insufficient energy rejected and flashes | **PASS.** Special 100 → 50; 63 after 1.75 s (1 s delay, then 18/s); three dodges took it 46 → 25 → 5 with regen between. With energy set to 20: Special and Dodge started nothing, and a screenshot caught the energy bar flashing red with the SPECIAL slot dimmed |
| 5 | Dismount and remount | **PASS.** On `PAD_TRAINING`: pilot at the exit point (−174, 3.3, −110), Frame kneeling; re-boarded from the board point, Frame Idle at Y 30.40 |
| 6 | The speed check doesn't false-trigger | **PASS after a fix.** It tripped three times in the first runs: twice on debug teleports, once during four dodges in a row. After the rewrite (D-054): `/frame`, two server moves 0.6 s apart, seven dodges, a heavy lunge and a stride run gave no warning |
| 7 | Gamepad and touch for every action | **PARTLY.** Simulated gamepad buttons worked: RB light, RT heavy, LB Pile Driver, L3 stride (top speed 76.8). B (dodge) can't be simulated (the tool reports it as bound to the core UI), and sticks and touch can't be sent at all. **Needs the user** |
| 8 | 60 s of continuous play without errors; FPS ≥ 55 in the hangar | **PASS.** 3,602 frames in 60.0 s (60.0 fps, Studio's cap), worst frame 20.3 ms, 5.7% of frames slower than 55 fps; 5,050 parts in Workspace. The only error in Output was from a test script of mine |

**Also tested:** `/god`, `/energy`, `/hurtboxes` (6 shown, 6 hidden), `/door east` open and close, `/tp SPAWN_TRAINING` and `/tp SPAWN_HANGAR_FLOOR` with a Frame, `/frame` from the spawn room. `RigCheck`, `PoseCheck`, `HubCheck` PASS. Unit 03 and the grip looked at in screenshots; the suit in a three-view preview. Every changed file matches Studio by checksum.

**Not tested:** `/hitboxes` on screen; mouse look; the suit on a walking character in play; the Training door walked through by a Frame (the Frame was moved to the yard by command); how the slower swings feel.

**Known:**
- `/frame` in the spawn room leaves the Frame standing on the building's roof (it is a debug command; use it outdoors or with `/tp`).
- Unit 03 has no collisions: a player on foot can walk through it.
- The pilot stays stocky because the body is the default blocky avatar (Q-016).
- A test batch that aborted left a key held down, which made one run walk the Frame backwards; a reminder to release keys after a failed input batch.

**Next:** Phase 2 is complete except test 7's stick and touch part, which needs the user. Then Phase 3 (the Strider): first the redesigned, human-looking Strider part list for the user's approval (D-039).

**Session 5, continued: full-body swings, moving while attacking, aim lock, cockpit tint, pilot mask (user feedback, D-055)**

**Tested (how → result):**
- Stances: previews of `Light1` at 0.35 / 0.45 / 0.55 → wide stance turned right, crouch, stance on the other foot turned left; both feet at Y 2.3–2.5 in every phase (2.4 = flat on the floor). `PoseCheck` PASS with two expectations updated.
- Play mode, Training Yard: walking at 48, a light attack started → speed 29 for the whole attack (0.6 × 48), 48 again after; heading unchanged during it.
- Aim lock: Left Ctrl with the Frame facing 90° off the camera → it turned to the camera's heading in about 0.4 s (220°/s); holding D then moved it sideways at 48 with the heading fixed. Ctrl again switched it off. The HUD line read `AIM LOCK OFF [CTRL]`.
- Tint: `Lighting.PG_CockpitTint` at `#FFE7BF` while piloting; a play-mode screenshot shows the warm view.
- Mask: three-view preview → no skin visible on the head; visor, rebreather and filters read from the front. `StarterCharacter` rebuilt, 94 parts.
- Output clean. All changed files match Studio by checksum.

**Not tested:** how the stances and the walking-while-swinging look in motion; the tint under the hangar's lighting; aim lock with a real mouse turning the camera; the mask on a moving character in play; the tint going away on dismount (the tween is the same code path as coming on).

**Known:** feet slide a little between the two stances (there is no foot planting). The touch `AIM` button doesn't exist yet.

---

## Session 6 — Phase 3 start: the Strider's look, spawning and damage

**Done:**
- `builders/rigs/Strider.lua`: the Strider built from the body of the user's Titan model (D-056), with `BuildHair` (24 catalog hair styles, checked and measured in Studio). `Server/Titans/TitanLook` (skin tone and hair from a seed).
- `Shared/Config/TitanConfig` (Strider stats and hurtboxes of `10` §1.2-1.3), `Locomotion.Strider`, `Shared/Poses/Strider` (Idle only so far).
- `Server/Services/TitanService`: spawn with look, collision groups, hurtboxes welded to the root (per-state C0), HP with the stand-up clamp, poise, both regenerating, registration as a combat target, signals for the behavior to come.
- `/titan Strider | kill | hp <n>`; debug phase 3; the Frame camera ignores hurtboxes.

**Tested (how → result):**
- Builder → 55 parts, 56.0 studs to the top of the head, hands at Y 16.1 (knees at 12.9), HipHeight 24.5; 24 of 24 hair styles loaded, none failed.
- Edit-mode preview of eight Striders with different tones and hair (screenshot) → hair sits on the heads, eyes glow orange, the grin and hip cloth show. (The first screenshot was taken before the hair meshes had loaded and showed them missing.)
- Play mode → a Strider spawned in the Training Yard stands with its root at Y 29.5, state Running, on Concrete; seven hurtboxes at the documented offsets, Core switched off; the Pose Animator plays `Idle` (waist −15°).
- Attacking it with Unit 02 from 36 studs → Light1 −36 HP, Light2 −40, Light3 −56 with −48 poise (ankle), Heavy −140 with −50 poise: 2400 → 2128. Poise started back 3 s after the last hit at 25/s, HP 4 s after at 10/s. Output clean.

**Bugs found and fixed here:** new "layered" hair sat at chest height and half as wide (it needs the engine's head cage) → rigid hair only; the reference head's hair attachment was meaningless → own anchor at the head's center; `/titan` could spawn past the map's edge, where the Titan fell out of the world → it now needs ground under the spot.

**Not tested:** the Strider seen in play from the front (the Frame hid it in the screenshot); walking; anything of the behavior (not built); the `/titan` ground check (added after the test); more than one Titan at once.

**Known:** the body keeps the reference's stocky, muscular build even after narrowing (38 wide at 56 tall); the docs asked for lanky. The Shifter's face shape (pointed chin, no nose) is the Strider's too.

**Next:** the user's approval of the Strider's look; then the behavior: state machine, attacks with telegraphs, flinch, Downed, Core Strike, death, the Titan HUD bar and lock-on.

**Session 6, continued:** a Titan spawned during play was sometimes not animated on the client (its tag arrived before its parts: 2 of 3 in one run). `AnimationController.register` now waits for the root and tries again; after the fix 4 of 4 spawned Striders played `Idle`, Output clean. The `/titan` ground check was tested from the Training Yard spawn (`/zone training`, then `/titan strider` → a Strider 120 studs ahead at (−320, 29.5, −110)); a play-mode screenshot from behind the pilot shows two Striders from the front: glowing eyes, grins, different hair and skin, hunched idle.

**Session 6, continued: the Strider's behavior (D-057)**

**Done:**
- `Server/Titans/Behaviors/Strider.lua`: the state machine of `10` §1.5 (Idle, Engage, Telegraph, Active, Recover, Flinch, Downed, GetUp, Dead), targeting, the weighted attack choice, turn rates, Sweep, Stomp, Lunge (server-driven, path checked), Roar and enrage, flinch, poise break, the tougher get-up, death with ash mounds and removal.
- `Shared/Poses/Strider.lua`: clips for every attack and state. `CombatConfig.TitanAttacks.Strider`.
- `TitanService`: behavior hook-up, facing, core exposure, the ankle bonus after a Stomp, `/titan freeze`.
- `CombatService`: Titan hits on Frames (i-frames, dodge grace, mercy, hit stun, knockback, Disabled), Core Strike, `repair`. `FrameService.setIntegrity`, `getFrames`.
- Client: `CombatController` (Core Strike request, knockback, `Hurt` signal), a camera shake when hit, separation from a Titan on its hands, root motion that stops when it ends.
- Debug: `/titan down | freeze | <type> dormant`, `/repair`. `PoseCheck` now covers the Strider's clips.

**Tested (how → result):** play mode in the Training Yard, Unit 02 against a debug-spawned Strider, with the server's state changes logged on server time.
- Attack timings against the config: Lunge windup 1.30 / active 0.50 / recovery 2.21; Sweep 1.10 / 0.36 / 1.40; Stomp 0.90 / 0.15 / 1.60; Roar 0.60 / 0.90 / 0.60; pause between attacks 1.2–2.0 s. Enraged Sweep windup 0.95 (1.1 × 0.87).
- Damage to the Frame: Sweep −180 (light stun 0.25 s), Stomp −220 and Lunge −260 (heavy stun 0.50 s); five hits (Lunge, Sweep, Sweep, Stomp, Sweep) took 1000 → 0 → `Disabled`, the Titan went idle. `/repair` brought the Frame back.
- Knockback measured on the server: Sweep 12.0 studs, Stomp 18.0; after a Lunge 33.5 (25 plus the push out of the landed Titan). The Lunge travelled 50.0 studs.
- Dodge: a dodge request 0.10 s before the active window → `Dodged`, no damage; 0.10 s after it began → `Grace`, no damage; no dodge → hit at active start + 0.15. Mercy: a second hit 0.1 s after the first → `Mercy`; a third after 0.55 s → hit. `/god` → `God`.
- Frame attacks on the Titan: zone damage as in Session 6; three lights within 1.5 s (96 poise) → Flinch 0.60 s, next attack 1.33 s later.
- Poise break: 300 poise gone → Downed, core exposed 1.00 s later for 5.00 s, GetUp 1.50 s, max poise 300 → 360 → 420. While it is down the Frame is pushed back to 34.8 studs.
- Core Strike (F): started while the core showed → −700 at 0.62 s; the Titan stayed down until the strike's 1.6 s were over.
- Half health → Roar at the next decision → `Enraged`.
- Can't die standing: a Heavy on a standing Titan with 43 HP → HP 1 and Downed at once, with 250 poise left.
- Death: Core Strike on a downed Titan with 503 HP → HP 0 → `Dead`; the model was gone and six ash mounds lay there when checked 17 s later; `TitanService.Died` fired.
- HP regen +10/s from 4 s after the last hit; poise regen as before.
- Server Heartbeat during the fight: 240 Hz. Output clean in four play runs (only the MCP's own mouse-automation messages).
- `PoseCheck` PASS (136 checks). All changed files match Studio by checksum.

**Bugs found and fixed here:** no pause after a Flinch or GetUp; the Frame stood on a downed Titan's head; dodges slid to 109–113 studs (see D-057); a split comment line in `CombatConfig` from my own edit script.

**Not tested:** a whole fight played by a person (duration 2–3.5 min is acceptance test 1); dodge grace under simulated latency (test 3 asks for the Network Simulator); how the attack clips look in motion from the pilot's view (the camera sat behind the Frame in every screenshot); two Titans at once; the Lunge stopping at a wall on purpose (it did stop at the simulacrum by accident); the Roar's knockback and stagger on a Frame that isn't in `/god`; `/titan freeze` beyond switching it on and off; gamepad and touch.

**Known:**
- Nothing of the telegraph visuals, the Titan's health bar, the Core Strike prompt or the hit vignette exists yet: the fight is readable only from the animations. The Core Strike has no step-in and no camera, so the blade can come down well short of the core.
- A Titan has no path-finding: it walks straight at its target and stopped against the training simulacrum, climbing 6 studs onto its arm.
- A Lunge passes through the Frame (Titan and Frame roots don't collide); the Frame is then pushed out.
- A dodge now travels 84.7 studs (config 88).
- A Disabled Frame only kneels; the failure and retry flow comes with the damage states.

**Next:** the Titan HUD bar, danger disc, glow telegraphs, hit flash and Ash Collapse visuals; Core Strike positioning and camera; lock-on; Frame damage states and the Disabled flow; then the Phase 3 acceptance tests.

**Session 6, continued: user feedback (Titans "near impossible to kill", the dash "looks goofy"), Titan HUD, effects, lock-on (D-058, D-059, D-060)**

**Done:**
- Dodge reworked into a leap in all four directions; the legs blend between a swing's stance and the walk.
- `TitanHUDController`: Titan bar, CORE EXPOSED countdown, ENRAGED, Core Strike prompt, damage vignette, HUD jitter, lock-on hint.
- `TitanVFXController`: telegraphs (veins, danger disc, eye flash, Roar), Stomp shockwave, Roar blast, core glow, footfall dust and tremors, hit flash, Ash Collapse. Server: ash mounds at 4.0 s with `Grow`.
- `LockOnController` with zone marker; side-standing locked camera and target-relative steering (`CameraController.setLock`, `FrameController.setLock`, `getMoveInput`); server-side lock validation; bindings `LockOn`, `CycleZone`, `CycleZoneBack`.

**Tested (how → result):**
- Leap poses in edit mode, three keys per direction: lowest visible point of the rig −0.3…0 studs on the push-off and landing keys, 0.7…4.3 in flight; before the fix the blade tip was 33 studs under the floor. Side and front screenshots judged by eye. `PoseCheck` PASS (136). In play: two dodges (back, right) ran with a clean Output.
- Play mode, Training Yard. Titan bar appears with name, class chip, health and poise (screenshot). Before the lock: the Titan at point-blank range is hidden behind the Frame (screenshot); locked on: its head and torso stand clear to the right of the Frame (screenshot).
- Lock: `toggle` → target Strider_1, still held 3.5 s later, camera elevation 19.7°; zones cycle Body → AnkleL → AnkleR → Body while it stands; the server holds `TITAN_1 / AnkleL`; the lock ends when the Titan dies.
- Danger disc under a Stomp frozen mid-telegraph (screenshot). Counters after one fight: 21 telegraphs, 7 discs, 7 shockwaves, 1 Roar, 1 hit flash, 1 collapse.
- Downed: health bar at 25%, `CORE EXPOSED` with its countdown, the `F CORE STRIKE` prompt, the open core's glow (screenshot). F → Core Strike → death → body gone, six mounds on the ground, the bar slid away.
- Output clean in three play runs. All changed files match Studio by checksum.

**Bugs found and fixed here:** the first lock dropped after 2 s and could not be taken again: its sight test hit the Titan's own hurtbox (a non-solid part that answers queries); `CameraFeel.lock.offset` was scaled like a length; the regen shimmer was a gradient on a transparent frame and showed nothing.

**Not tested:**
- **The lock marker on screen:** the MCP's screenshots don't include BillboardGuis (two plain test billboards didn't show either). Checked only by its state: enabled, on the right hurtbox, right label.
- The Ash Collapse mid-sequence (tint, vapor, flakes): the screenshot came after it was over. The eye flash, the vein glow, the Roar blast, the vignette and the HUD jitter: counted or coded, not seen.
- Any of it in motion, by a person: how the leap reads, whether the side camera and target-relative steering feel right, mouse nudging the locked view, the wheel and middle button, gamepad, touch (no `LOCK` button yet).
- Two Titans (which one the bar and the lock pick), the lock breaking on sight loss behind a wall.

**Known:** the reticle still shows while locked on; the weapons banner would overlap the Titan bar if both showed; a Lunge still passes through the Frame; no path-finding; the Core Strike has no step-in or camera yet; no sounds.

**Next:** the user's verdict on the fight (Q-018) and on Titan size (Q-017); Core Strike positioning and camera; Frame damage states and the Disabled flow; then the Phase 3 acceptance tests.

**Session 6, continued: balance, Core Strike positioning and camera, damage states, retry (D-061, D-062, D-063)**

**Done:**
- Frame damage and poise × 1.7 (user decision); Titan size kept.
- Core Strike: step-in and aim on the pilot's client, target published by the server, the strike camera (`CameraController.setShot`).
- `FrameService` publishes `DamageState` and `PlatesDetached`; `FrameDamageController` (plates, sparks, smoke, flicker, dark, the FRAME DISABLED card); `RetryService`; `TitanService.reset` and the Strider's `reset`.

**Tested (how → result):** play mode, Training Yard, one run; Output clean.
- Core Strike from 32.8 studs off the core, a little off its line: the Frame moved 18.4 studs to 51.2 from the core during the raise; at impact the blade's center was 0.9 studs from the core sideways and 0.8 above it; the camera sat 80 studs from the Frame looking at the core (0–1° off) and was back at the gameplay camera 0.6 s after the strike; the Titan lost 700.
- Damage states through `CombatService.hitFrame`: 650 → Scuffed, 1 plate; 310 → Damaged, 3 plates; 110 → Critical; 0 → Disabled. On the client at Damaged: three plate parts hidden, three fallen copies on the ground, sparks 3/s, smoke 12/s; the HUD read 310 / 1000 in red and ARMOR DAMAGED.
- Disabled: the card was up 0.8 s in with FRAME DISABLED and its second line and went 2.55 s after; visor and core lights dark, smoke 16/s.
- Retry: 2.94 s after being disabled the Frame stood Idle and Pristine with 1000 Integrity and no plates off, back at the place noted before the Titan spawned; the Titan had 2400 HP and 300 poise again (it had 1700) and stood on its spawn point. Client after it: nothing hidden, no sparks or smoke, visor Neon again.
- All changed files match Studio by checksum.

**Phase 3 acceptance tests (roadmap), where they stand:** 2 (attack timings), 3 (i-frames negate damage; grace by sending the dodge 0.10 s late), 4 (poise break → core → Core Strike 700 → death → collapse → removed), 5 (can't die standing), 6 (regen after 4 s), 7 (Disabled flow resets) and 8 (240 Hz) pass, each in the journal above. **1 (a fight won in 2–3.5 min over three fights) needs the user.** 3's second half as written, the Network Simulator at 0.15 s lag, was not run; the grace was tested by timing the request instead.

**Not tested:**
- The new balance in a real fight: how long it takes, whether one Heavy flinching the Titan makes it too easy.
- The Core Strike and the damaged Frame as pictures: both screenshots of this run came back with the HUD over a black 3D view (the camera and lighting were checked by their values and were normal; earlier runs' screenshots were fine). So plates coming off, sparks, smoke, the dark visor, the card and the strike camera are verified by state, not seen.
- Core Strike on a Titan that went down by itself in a fight (this one was a passive Titan opened by hand), from behind it, and with the lock on.
- Retry with a Titan that has a behavior and is mid-attack; with no safe place noted; twice in a row in a real fight.
- Visor and vent flicker (it waits 3–5 s; not watched). Gamepad and touch.

**Known:** the retry card promises a checkpoint that doesn't exist yet; the reticle shows while locked on; a Lunge passes through the Frame; no path-finding; no sounds; the limp is slower walking only, not a limp in the animation.

**Next:** the user's three fights for acceptance test 1 and their verdict on feel; then Phase 4 (first mission flow).

**Session 6, continued: the user's fight, swing hit areas (D-064, D-065, D-066)**

The user fought the Strider: "It took about a minute", against a target of 2–3.5 minutes; the swings' hit areas felt wrong ("just a huge box and not the sword"); the built structures look too simple (they are the blockout / structure passes; the dressed pass is Phase 7, D-066). The user said to go on to Phase 4.

**Done:** Strider health 2400 → 6000; swing boxes enlarged to the blade's sweep, with a `reach` that trims their corners.

**Tested (how → result):** blade extents measured on the clips in edit mode (Light1: 82 studs ahead, 74 left, 94 right). Play mode: one Light1 with passive Striders 70 studs ahead, 60 to the side and 25 ahead, and 105 ahead → the first two lost 61 HP each, the third none. Studio had been restarted: helpers redefined, all sources still matched by checksum.

**Not tested:** fight length with 6000 HP (needs the user); Light3, Heavy and the Pile Driver's new boxes in play; `/hitboxes` drawing the new sizes.

**Phase 3 status:** everything built; acceptance test 1 stays open until the user has timed three fights with the new health. The user approved moving on to Phase 4.

---

## Session 6, continued — Phase 4 start: Outpost 07 blockout

**Done:**
- `builders/maps/outpost07/Layout.lua` (origin, local-coordinate helpers), `Compound.lua` (Ground, Road, Perimeter, Courtyard, Bunker with interior and Pad A, PowerStation, Yard, Residential with the mess hall interior and the Watcher's footprints, Tower with its stair), `Wilds.lua` (Trail, Basin, Ridge with the rover and Pad B). **Blockout pass only**: sizes, collisions, markers, cameras, triggers, barriers, prompts on stand-ins. No props, no lights.

**Tested (how → result):**
- Builders run in edit mode → 453 parts, no warnings. Registry check: all 53 ids of `map_03` §16 exist exactly once, plus 14 `TRG_OOB_*` triggers.
- Screenshots from above (compound) and from over the ramp (basin): the layout matches `map_03` §1.
- Play mode: `/tp SPAWN_OP_BUNKER` → on foot on the bunker floor, zone Bunker. Unit 02 moved to `FRAME_OP_START_02`, `FRAME_OP_BREAKER`, `FRAME_OP_NORTHGATE`, `FRAME_OP_FIGHT`, `FRAME_OP_POSTFIGHT` → standing on the ground each time (root at 30.3–30.4 in the compound, 18.4 on the basin floor at −12), zones Outpost and Basin, weapons free. Output clean.

**Not tested:** driving the route end to end (road → gate → breaker → Pad A → north gate → trail → ramp → basin) and whether every barrier holds; the on-foot route (console, clues, logs, tower stair, mess hall door); dismounting on Pad A and Pad B; the prompts (most are disabled until their steps exist); the Strider fighting in the basin among the rocks.

**Known:** it is a blockout: grey boxes, by design (D-066). No lighting preset work, no out-of-bounds handling yet (the triggers exist, nothing listens).

**Next (Phase 4):** drive and walk the routes and fix what snags; the structure pass of the outpost; then SequenceService with the mission steps S10–S33, deployment, AllyFrameService, checkpoints.

**Phase 4, continued: the outpost's routes checked**

**Tested (how → result):** play mode, real collision groups.
- A box the size of a Frame's root moved along Unit 02's route in 4-stud steps (road, east lane past the truck, south gate, courtyard, breaker, Pad A, round the bunker's east side, north gate, trail, ramp, basin, Pad B; 485 samples) → nothing in the way except one courtyard floodlight pole my test path clipped. The same box pushed at the west wall and over the bunker → stopped by their FrameBarriers. At both gates and the east breach a Frame is free.
- A character-sized box along the on-foot route (Pad A's exit, bunker door, corridor, ops room, Clue A, Clue C, mess hall door, the table with LOG2, Clue B; 281 samples) → clear apart from a pole and the yard truck on my test path. Bunk room and armory doors clear. On foot the gates, the breach and the rover fence are closed by their PlayerBarriers.
- The tower stair walked with `Humanoid:MoveTo`: all five landings reached at heights 10.3, 20.3, 30.3, 40.3 and 50.2 in 20.7 s; from the top landing north and west to the searchlight, 4.5 studs from the LOG3 prompt.
- Both dismount pads got their Dismount prompt from FrameService. Output clean.

**Changed:** rails round the tower platform's stairwell opening and the arrival landing (458 parts in all). I first read the character's drop to 46 studs as a fall into the well; it had walked down the top flight, which is what heading west off the landing does.

**Not tested:** the routes driven and walked by a person; actually dismounting on a pad and using a prompt in the outpost; the Strider among the basin's rocks.

**Noted:** in edit mode every collision group collides with every other (the game sets the pairs at run time), so barrier checks have to run in play mode.

**Phase 4, continued: the Sequence Runner and the mission from the arrival to the basin (D-068, D-069)**

**Done:**
- `Server/Services/SequenceService.lua`; `Shared/Sequences/CH1.lua` (S20–S27); `Shared/Objectives.lua`; `Shared/Dialogue/CH1_Mission.lua` (the script's radio lines AR, SG, PW, CM, IN, TW); the HUD's objective follows `Seq_State`; `/step` and `/checkpoint`; debug phase 4; the outpost's mission prompts carry the script's texts.
- Fixes: Frame triggers (`who = "frame"`) now fire; Frame-scale prompts are reachable from a 64-stud Frame.

**Tested (how → result):** play mode, driven from the server, the Frame placed with `FrameService.moveTo`.
- `/checkpoint CH1_DEPLOYED` → S20: fade, Overcast, boarded at the start. Frame into `TRG_OP_SOUTHGATE` → S21, breaker prompt on. Breaker → Power true on `Map.Outpost07`, checkpoint `M01_POWER`, S23. Dismount on Pad A → S24, console on. Console → `M01_COMMS`, S25 with 0/3. Clue B → 1/3; B again → still 1/3; A → 2/3 (flags `CH1_CLUE_A`, `CH1_CLUE_B`); C → S26. Boarding → `M01_TRAIL`, S27. Frame through the three trail triggers and into `TRG_BASIN_ENTRY` → the sequence ends. Fourteen step signals in order.
- A load: `/checkpoint M01_COMMS` with clues A and B flagged → on foot in the bunker, objective on the client "Investigate the damage (2/3).", only clue C's prompt on.
- Prompts: before any step all eight step-gated prompts are off and LOG1 is on.
- **Real prompt holds from the client:** the breaker from `FRAME_OP_BREAKER` → accepted, S23, Power true (from 130 studs away the server refuses it); the Dismount prompt on Pad A → the pilot stands at the exit point (16, 3.2, 24), the Frame kneels, S24.
- Output clean. All changed files match Studio by checksum.

**Not tested:** the mission played by a person at walking pace (my runs jumped the Frame from trigger to trigger, so the queued radio lines trailed far behind the steps); the console and clue prompts by a real hold on foot; whether the client draws the custom prompt for Frame-scale prompts (the hold worked; I didn't see the prompt's UI); saving and rejoining for real (loads were made with `/checkpoint` in one session); `timer`, `any`, `all` conditions (no step uses them yet).

**Known:** no waypoint markers yet (the positions are sent in `Seq_State`, nothing draws them); the power coming on changes nothing visible (no lights in the blockout); Mara isn't there; radio lines of a finished step keep playing after a fast player has moved on.

**Next:** waypoint markers; S28–S33 (the Strider's rise and the fight, victory, the Watcher, the rover, the upload) with the deployment and return; AllyFrameService; fail and retry through checkpoints; the outpost's structure pass.

**Phase 4, continued: waypoints, the Strider's rise and the fight step (S28, S30)**

**Done:**
- `WaypointController` (markers in screen space: diamond and distance on the spot, an arrow on the screen's edge while it is off screen); the three clues are waypoints until found.
- Strider: `Dormant`, `Rising`, `Standby` states, `command("Rise" / "StartFight")`, untouchable until the fight starts, the first Sweep with a 1.8 s windup; clips `Dormant` and `Rise`. The Titan bar stays away until the fight starts.
- Sequence Runner: `spawnTitan`, `despawnTitan`, `titanCommand`, `proximity`, a poll for unannounced conditions, `onFail` (the card, the step's fail actions, the checkpoint loaded again; RetryService stands back for such a step). Step S28 with the script's lines ST, FAIL, VI.

**Tested (how → result):** play mode.
- `/checkpoint M01_TRAIL` → S27, the Strider crouched in the basin (state Dormant) at its marker. Frame into the basin → S28, checkpoint `M01_FIGHT`; Rising for 2.5 s, Standby while the three lines play, Engage at 15.0 s with the objective "Defeat the Titan." and the Titan bar on.
- The first Sweep's windup 1.80 s, the next 1.10 (0.96 once enraged).
- Fail: Frame disabled → 6.5 s later step S28 again, Frame Idle with 1000 Integrity at the fight spawn, the old Strider gone, a new one engaging with 6000 HP.
- Kill: Strider at 400 HP brought down, a Core Strike requested by a client script the moment the core showed → Dead 1.9 s after the break → victory lines → checkpoint `M01_TITAN_DOWN` → the sequence ends; no Titan left.
- Output clean.

**Bug found and fixed:** `WaypointController` was already in the client's load list, so my added entry loaded it twice.

**Not tested:** the waypoint markers themselves (state and picture; the controller was loaded twice in this run); the Rise clip and the slow Sweep as animation; a Core Strike kill from a key press in a real fight (mine arrived after the core had closed, so the kill was made with a timed script).

**Known:** S28's three shots are a Phase 5 cinematic; for now the Strider rises while the player keeps control. The tutorial hints of S28 other than `TUT_LOCK`, and the fight barks, wait for their controllers.

---

### Session 7 — 2026-10-14 — Phase 4 (mission flow complete; structure pass started)
**Goal this session:** finish Phase 4's systems: the unjournaled S31–S33 work, AllyFrameService, checkpoints with resume, out of bounds, the deployment; then the acceptance tests.

**Studio state found at start:** Studio restarted (session helpers gone), all 132 scripts matched the local files by checksum, including uncommitted, untested S31–S33 work from a cut-off session (`WatcherStandIn`, rover prompts, `FrameService.park`). Outpost 07 at blockout (453 parts). Profile checkpoint `M01_COMPLETE`-era data. The user is away until about 22:00 EDT and asked for questions to be kept until then.

**Done:**
- **S31–S33 verified and fixed** (D-071): the Watcher walked backwards (stand-in turned by π; its model faces its pivot's look) and peeled the roof while still walking; now walk 12 s → peel → canister into its hand → turns to Unit 02 → leaves carrying it. The upload objective waits for RV_08; the case's lock light goes cyan 0.6 s then off (clue 10). **Rover SR-12 rebuilt hollow** (D-070, Ridge area at structure pass): bay the player walks into over the peeled roof, cradle with label and the T-V canister, MetalCase with LockLight, ECHO rings and SR-12 stencil, wheels, skid marks, debris.
- **Bug fixed:** `FrameService.park` re-registered the units' board prompts (error, and the handlers pointed at the destroyed Frame).
- **SequenceService split** into `Server/Sequence/Actions` and `Conditions` (`16` §2; it was 724 lines). New actions: `ally`, `door`, `card`, `unlock`, `frame autoWalk/stopWalk/park/kneel`; `say(player, id, urgent)`.
- **Resume on join** (D-072): a returning player loads the saved checkpoint behind black; a new profile starts CH1 at S08. Event conditions FrameBoarded/FrameDismounted count when already true (no soft-lock). Every load despawns leftover Titans.
- **Out of bounds** (D-073): `BoundsService` + the Frame HUD warning panel (`Client/UI/BoundsWarning`), OOB_01 urgent, recall after 6 s to the nearest return point.
- **AllyFrameService** (D-074): Mara's Unit 01 follows, holds (scanning), fights at 150° round the Titan with the 10% cap, walks round obstacles on the player's trail; wired through S20–S33.
- **Deployment** (D-075): S08 board → S09 east door (real 4-segment door, `map_02` §4) → S10 launch (auto-walk, Bulwark gate, Transit card) → S20. New builders: `hangar/Causeway`, `backdrops/Bulwark`; `CardController`; HubCheck limited to the hub's zones.
- **Restore fixes** (D-076, D-077): on-foot loads take the pilot out of the Frame first; after `M01_COMMS` Unit 02 kneels on Pad A; server moves publish `MovedYaw` and the pilot's Frame and camera take it; Frames kneel facing their pad's exit direction.

**Tested (how → result):** play mode throughout; Output clean at the end of every run.
- S31→S33 by real prompt holds (marking, cradle, case, both boards) → PASS; Watcher order and facing sampled every 0.5 s; lock light red → cyan (0.60 s) → off seen on the client; upload objective 17.7 s after the case (lines first).
- **Acceptance 2, rejoin at all 7 mission checkpoints** (`/checkpoint <id> save`, stop, start): `CH1_DEPLOYED` (outpost start, Mara at her mark), `M01_POWER` (piloting at the breaker, power on, Mara in the courtyard), `M01_COMMS` (on foot in the bunker, Unit 02 kneeling on Pad A, board by real hold → S27), `M01_TRAIL` (north gate, Strider dormant), `M01_FIGHT` (fight running, Mara in Combat), `M01_TITAN_DOWN` (post-fight spot, Watcher starts), `M01_COMPLETE` (hangar floor, Evening) → PASS.
- **Acceptance 3, clues persist** → PASS (clue A found, rejoin: its prompt off for this player, counter 1/3, 2 waypoints).
- **Acceptance 4, out of bounds** → PASS on the road (recalled to `FRAME_OP_START_02`) and the basin (to `FRAME_OP_POSTFIGHT`), 6.0 s countdown, panel seen in a screenshot; OOB_01 holds the radio 3.5 s.
- **Acceptance 5, Mara**: follows at ~48 studs on the road and steps round the overturned truck; holds in the courtyard facing north with a ±40° head sweep; fight: 150–160° round the Titan, never in the corridor, chains every 4.7–5.9 s, no swing while Downed, cap stops her HP damage (HP kept regenerating through her swings, 8 poise each); **camera blocked 0 frames** in 30 s of fight and 13 s of following with a turn (ray from the camera to the Frame each frame); walks to the regroup mark and turns to the Watcher; parked in Bay 1 at the end → PASS.
- **Acceptance 1, launch to Mission Complete without debug commands**: an autopilot on the client (steering through the Frame's `AutoWalkTo`, Humanoid:MoveTo on foot, real prompt holds, combat through `Frame_Action`) ran S08 → S20 (board by the hatch, door, launch, card, arrival) and, after a rejoin at `CH1_DEPLOYED`, S20 → S40: breaker, Pad A, console, clues A/B/C, remount, trail, fight (won in ~73 s after the rise, never disabled, Unit 02 at 560/1000), Watcher, Pad B, cradle, case, upload, return. Six checkpoints saved in order, no warnings → PASS. Two stops were my waypoints (a stand point 7.7 studs from clue C; the walk to the board point, which the kneel-facing fix then moved).
- **Acceptance 6, no soft-lock**: every completion condition of S08–S33 was triggered for real in the runs above (boarding, triggers, proximity, interacts, counter, TitanDefeated, any(proximity, timer)) → PASS.
- Deployment: the east door rose and closed, the Bulwark leaves opened and closed (positions sampled); Transit card: shown 3.1 s, both lines typed in 1.7 s, black before and after; HubCheck PASS.

**Known bugs / not done:**
- The **Outpost 07 structure pass** (lights, materials, signage) is not done beyond the Ridge; power-on still changes nothing visible.
- Fight balance: the autopilot (no dodging) wins in ~73 s; Phase 3's acceptance test 1 (2–3.5 min) still needs the user's fights.
- Not seen by eye: the Watcher stand-in in motion, Mara's gait, the door and gate moving, the rover peel.
- Placeholders until Phase 5: hub scenes S01–S07 and S40–S43, the cinematics (S09, S10, S28, S31, S33), choice C3, barks, tutorials as toasts; Mara stays parked during S08–S10 (her bay is ringed by barriers).

**Decisions made:** D-070 to D-077.

**Session 7, continued: Outpost 07 structure pass (compound) (D-078)**
- **Done:** lights, signs, gates, towers, wall trims, window rows, fence, transformers, breaker, comm mast for every compound area; the power-on effect. 924 parts, 46 lights (4 shadowed), no builder warnings.
- **Tested:** edit-mode screenshots (south gate with sign and leaves, power station, rover); play: `/checkpoint CH1_DEPLOYED` → 32 OutpostLights off, bunker dark and red; then a load with power → 32/32 on, emergency lamps 0.3, 3 spark emitters on, lever exactly at its down CFrame; before/after screenshots of the ops room.
- **Not done (next session):** the structure pass of the Trail and the Basin (dam markers, intake tower details, rock formations, signpost); the bunker's one flickering fixture (client ambient); the lever and flicker not watched in motion.
- **Next steps:** finish the Trail/Basin structure pass and tick the Phase 4 map item; then Phase 5. **User:** please save/publish the place (File → Publish to Roblox), and time three Strider fights (Phase 3 test 1; the autopilot won in ~73 s).

**Session 7, continued after the break: Trail and Basin structure pass (D-079)**
- **Done:** `WildsStructure` (signpost, pipeline, outcrops; dam notch, stain, depth marks, rails, hut; intake tower details; RF1–RF4 from pieces; boat wreck). Outpost 07: 1,057 parts.
- **Tested:** builders run with no warnings; checksums match; a screenshot of the basin from above the ramp (dam with the notch and rails, stain band, tower grates and walkway, rock formations). Not tested in play after this change: a Frame driving round the new rock pieces (they sit inside the old boxes, so the earlier route sweep still bounds them).
- **Phase 4 status:** every item ticked. Left for the user: save/publish; the Phase 3 fight timing. Next: Phase 5.
