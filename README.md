# PROJECT GENESIS — Design Pack for Claude Code + Roblox Studio

This folder is a complete, buildable design for your game. It's written for Claude Code to follow so it doesn't have to guess. It's **not one giant prompt**: it's a project folder Claude reads piece by piece.

- `CLAUDE.md` is loaded automatically every session (short rules plus an index).
- `docs/` is the full spec: story, characters, every map with coordinates, combat numbers, UI, saving, roadmap, tests.
- `docs/tracking/` holds the journal, checklist, decisions and open questions that Claude keeps updated, so work continues across sessions.
- `KICKOFF_PROMPT.md` has the short prompts you paste into Claude Code.

---

## One-time setup (on your Windows PC)

1. **Put this folder somewhere permanent**, e.g. `C:\Users\<you>\Documents\project-genesis`. Optional: make it a Git repo so you can roll back.
2. **Install Claude Code** on the PC (the desktop app is easiest) and sign in.
3. **Roblox Studio:**
   - Create a new place (Baseplate is fine).
   - **File → Publish to Roblox** (needed for saving data and version history).
   - **Game Settings → Security → turn ON "Enable Studio Access to API Services"** (needed for save data).
   - Set **Max Players = 1** for this place (Game Settings → Places, or the Creator Dashboard). The story mode is single-player.
   - Make sure Studio's MCP server feature is enabled (it's what lets Claude control Studio).
4. **Connect Claude Code to Studio.** Open a terminal **inside this folder** and run:
   ```
   claude mcp add --transport stdio Roblox_Studio -- "cmd.exe" "/c" "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
   ```
   (Add `-s user` after `add` if you want it available in every folder.) Then start Claude Code in this folder and run `/mcp`. `Roblox_Studio` should show as connected **while Studio is open with your place**.

## How to work with Claude
1. **Open Studio with your place first**, then open Claude Code in this folder.
2. **First session:** paste **Prompt 1** from `KICKOFF_PROMPT.md`.
3. **Every later session:** paste **Prompt 2** ("continue").
4. **Save/publish in Studio whenever Claude asks** (Ctrl+S, then File → Publish). Claude can't save the place file itself.
5. **Send screenshots.** You can paste images into Claude Code. It's the best way for Claude to check that builds look right.
6. **Effort setting:** use **High** for normal building sessions. Use **Max** for the first session, the combat, networking and save-system phases, and any bug that survives 1–2 fix attempts.
7. **One phase at a time.** The roadmap goes Phase 0 → 7 for the full Chapter 1 vertical slice. Don't ask Claude to build everything at once; the docs already tell it not to.

## What's realistic
- Claude can build **everything from parts** through the Studio MCP: maps, props, characters (Roblox avatars plus part-built gear and hair), the Frames and the Titans, plus all the code, UI and code-driven animation.
- **Claude can't upload assets** (images, meshes, animations, sounds). The design avoids needing them. For sound, you'll find free Roblox-provided audio in the Studio Toolbox and give Claude the IDs (see `docs/15_audio.md`). The game runs silent until then.
- Expect **many sessions**. Each phase is several sessions of work. The journal and checklist make it resumable at any point.

## Things I added that you should review
Your original bible left some things open, and Claude needs answers to place clues and build scenes. I wrote them as **canon v1**, and you can change any of it:
- **Story secrets** (`docs/04_campaign_and_secrets.md`): what the Titans are (the Lattice), why Frames and Titans are connected, Elias's father's real fate, who the Watcher is, the coming "Bloom", three endings. See open question Q-001.
- **Names and supporting cast** (Okafor, Hollis Brandt, Tamsin Rook, Sgt. Morrow, Lt. Ferris...), places (New Halden, Corrow, Kessler Basin), and the squad callsigns (Ember-1 / Ember-2).
- **The complete Chapter 1 script**, with all dialogue and choices (`docs/05_chapter1_script.md`).
- **All numbers:** sizes, speeds, damage, timings, colors, coordinates. They're starting values that Claude tunes with your playtest feedback, logging every change.

To change something, edit the doc (or tell Claude to) **before** that phase is built, and note it in `docs/tracking/decisions.md`.

## File map
```
CLAUDE.md                      operating manual (auto-loaded)
KICKOFF_PROMPT.md              prompts to paste
docs/01_vision_and_scope.md    pillars, scope, what "built from parts" means
docs/02_world_and_lore.md      world, history, factions, glossary
docs/03_characters.md          cast + exact avatar build specs
docs/04_campaign_and_secrets.md  acts, canon truth, clue map, endings
docs/05_chapter1_script.md     full Chapter 1: scenes, dialogue, triggers, cameras
docs/06_art_direction.md       scale, palette, materials, lighting presets, VFX
docs/07_building_with_parts.md build-as-code system, BuildKit API, props catalog
docs/08_rigs_and_animation.md  avatars, giant rigs, procedural animation
docs/09_frames.md              Vanguard part-by-part, ally AI, future Frames
docs/10_titans.md              Strider part-by-part + AI, Watcher, future species
docs/11_controls_and_camera.md PC / gamepad / mobile controls, cameras
docs/12_combat_system.md       authority, timings, hitboxes, damage, upgrades
docs/13_missions_dialogue_relationships.md  sequence runner, dialogue format
docs/14_ui.md                  every screen and HUD element
docs/15_audio.md               sound registry, music, mixing
docs/16_technical_architecture.md  code structure, networking, rules
docs/17_saving_progression_monetization.md
docs/18_roadmap.md             phases + acceptance tests
docs/19_testing_and_debug.md   test methods, debug commands, performance
docs/maps/map_00..04           world layout, hub, hangar, Outpost 07, Site Kestrel
docs/tracking/                 journal, checklist, decisions, open questions
```
