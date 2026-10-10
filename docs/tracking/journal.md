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
