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
