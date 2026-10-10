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
