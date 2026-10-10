# 19 — Testing and Debug

**Rule: nothing is "done" until it's tested, and the journal says how.** Prefer automated checks (scripts run through the MCP) plus short play-mode tests. Ask the user to playtest feel-related things and send screenshots.

## 1. How Claude tests through the MCP
1. **Edit-mode checks:** run Luau snippets that inspect the place (counts, names, positions, tags, bounding boxes).
2. **Play-mode checks** (if the MCP exposes start/stop play and script execution in play mode): start play, run test snippets on the server (and client if supported), read console output, stop play.
3. **If play-mode control isn't available through the MCP:** write test scripts that run automatically when play starts and only in Studio (e.g. `ServerScriptService.DevTests`, gated by `RunService:IsStudio()` and a `ServerStorage.DevTools:GetAttribute("RunTests")` flag). Ask the user to press Play and paste the Output, or read it via the console-output tool.
4. Always read the **Output** for errors and warnings after every test. Zero errors is required. Warnings must be explained or fixed.

## 2. Debug commands (Studio only; `DebugService` + `DebugController`)
Opened with **F2** (a debug panel with a command box) or typed as chat-like commands in the panel. **Disabled outside Studio** (the server rejects `Debug_Command` unless `RunService:IsStudio()`).

| Command | Effect |
|---|---|
| `/tp <spawnId>` | Teleport the character (or piloted Frame) to a spawn, e.g. `/tp SPAWN_HANGAR_FLOOR` |
| `/zone <name>` | Teleport to a zone's default spawn (`hub`, `hangar`, `training`, `outpost`, `basin`, `memory`) |
| `/step <stepId>` | Jump the sequence to a step (runs its restore actions) |
| `/checkpoint <id>` | Load a checkpoint as if rejoining |
| `/frame` | Spawn/board Unit 02 at the nearest pad (or the player's position) |
| `/titan <type> [state]` | Spawn a Titan ~120 studs in front (`Strider`, `Watcher`; state `Dormant`/`Engage`) |
| `/titan kill` / `/titan down` / `/titan hp <n>` / `/titan freeze` | Titan control. As built (D-057): `down` breaks every Titan's poise; `freeze` stops and restarts what they do (hits still count); `/titan Strider dormant` spawns one that only stands and takes hits (the `Dormant` state proper comes with the cinematic) |
| `/repair` | Full Integrity for the piloted Frame, and out of `Disabled` (added in Phase 3, D-057) |
| `/god` | Toggle player Frame invulnerability |
| `/door <west\|east> [open\|close]` | Open or close a hangar door stand-in (added in Phase 2, D-054). In Studio the Training (west) door starts open until the door system exists |
| `/energy` | Infinite energy toggle |
| `/hurtboxes` | Toggle the hurtbox visualization (Transparency 0.6, colored by zone) |
| `/hitboxes` | Toggle the attack-box visualization (client draws the boxes for 0.3 s on each attack) |
| `/flags` | Print all flags and relationships |
| `/flag <name> [on/off]` | Set or clear a flag |
| `/rel <var> <value>` | Set a relationship |
| `/give xp <n>` / `/give credits <n>` | Progression testing |
| `/save` / `/wipe` | Force save / reset the profile (with confirmation) |
| `/dsfail on/off` | Simulate DataStore failures |
| `/lighting <preset>` | Apply a lighting preset |
| `/timescale <x>` | Scale AI and animation time (0.25–2) for inspecting telegraphs (debug only). **Not built yet**: the command answers so |
| `/fps` | Toggle the stats overlay (FPS, ping, part count, Heartbeat Hz, memory) |
| `/nav` | Show nav nodes and links |

## 3. Automated check scripts (`builders/checks/` and `src/.../DevTests`)
| Check | Asserts |
|---|---|
| `MapCheck_<Area>` | Bounding box ± 1 stud of spec; required named objects exist; tags and attributes correct; part count within budget |
| `NavCheck` | Every nav node has a floor below (raycast) and headroom (5.5 + 1); every link is clear (capsule cast radius 1.5); the graph is connected |
| `PromptCheck` | Every `InteractId` referenced in the sequence data exists exactly once in the world |
| `TriggerCheck` | Every `TriggerId` referenced exists; trigger boxes don't overlap unintentionally |
| `DialogueCheck` | Every line ID in `05_chapter1_script.md` exists in the dialogue data (parse the doc for `ID \|` patterns or a maintained ID list); no line > 120 chars; every `next` points to an existing node; no unreachable nodes |
| `ConfigCheck` | Pose clip durations equal CombatConfig move totals; all sound keys referenced exist in the SoundRegistry; all spawn IDs referenced exist |
| `RigCheck_<Rig>` | Joint names, C0/C1 offsets vs the joint table (± 0.05), part count within budget, HRP and Humanoid settings |
| `CombatTimingTest` | Play mode: perform each move on the simulacrum; server-logged phase timestamps within ±0.03 s |
| `TitanFightSim` | Play mode with `/timescale 2` and an automated "bot pilot" (optional, Phase 3+): verifies state transitions occur (Engage → Telegraph → Active → Recover, Downed, Dead) |
| `SaveLoadTest` | Profile round-trip; migration scaffold; readOnly on simulated failure |

## 4. Manual test protocols (Claude asks the user when feel matters)
- **Feel test, Frame:** "Board the Frame, walk to the door, stride, turn in place. Does it feel heavy but responsive? 1–5." Tune acceleration and turn rate from the feedback (log it).
- **Feel test, combat:** "Fight the Strider twice. Were the telegraphs readable? Did you understand when to dodge? Was the Core Strike satisfying?"
- **Story test:** "Play S01 → S07. Any line feel wrong or confusing?"
- **Device test:** Studio's device emulator (phone 375 × 812 landscape and portrait, tablet) and a connected gamepad, if available.

## 5. Regression checklist (run before closing any phase)
1. A fresh profile starts at S01 correctly.
2. The hub navigation route Q-3 → Hangar → Briefing → Hangar works.
3. Boarding, walking, launching.
4. One full Strider fight.
5. Save and rejoin at the last checkpoint.
6. No errors in Output across the run.
7. Performance spot check (`/fps`).

## 6. Performance measurement procedure (Phase 7, and whenever FPS drops)
1. `/fps` overlay plus **MicroProfiler** (Ctrl+F6) during: the hangar reveal, launch, the outpost courtyard, the Strider fight, and Ash Collapse.
2. Developer Console (F9) → Memory and Network tabs: record numbers in the journal.
3. Script Performance window: no script > 3% average.
4. Compare against `16_technical_architecture.md` §11. If over budget, optimize the **measured** hotspot (common fixes: reduce shadowed lights, set CanQuery/CastShadow false on details, merge static detail into fewer parts, cut particle rates, LOD animation, throttle AI ticks).
5. Re-measure and record before/after.

## 7. Bug report template (`docs/tracking/journal.md`)
```
BUG-<n>: <title>
Where: <area/step>   Severity: blocker | major | minor | cosmetic
Repro: 1) ... 2) ... 3) ...
Expected: ...   Actual: ...
Notes / suspected cause: ...
Status: open | fixed (how verified)
```
