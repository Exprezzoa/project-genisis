# 01 — Vision and Scope

## 1. Identity

| Item | Value |
|---|---|
| Working title | **PROJECT GENESIS** (a real title is decided after Chapter 1 ships; candidates in §7) |
| Genre | Third-person 3D action RPG, sci-fi drama, mystery |
| Engine / language | Roblox Studio / Luau (strict mode where practical: `--!strict` on shared modules) |
| Visual style | **Everything built from Roblox parts.** Roblox avatars for people. Giant part-built Titans and Frames, in the style of Roblox Attack-on-Titan-like games, but with an original world |
| Primary experience | Single-player narrative campaign |
| Later | Co-op activities and a multiplayer social hub (Phase 11+) |
| Narrative | Fixed protagonist (Elias Veyne), authored arcs, cinematic storytelling |
| Platforms | PC (keyboard + mouse), gamepad, mobile (touch). All three must be fully playable |
| Business model | Free-to-play. Optional cosmetics. No pay-to-win, no paywalled story |

## 2. The three pillars

1. **Care about the people.** Characters have ambitions, flaws, disagreements and memories. They react to what happened. They are never quest dispensers.
2. **Powerful, but never safe.** Piloting a 40-stud Frame must feel heavy and incredible: weighty steps, camera shake, hit-stop, debris. A 56-stud Titan must still be terrifying: it's bigger than you, it telegraphs attacks that hurt, and it regenerates.
3. **The truth reframes everything.** Every twist is set up by earlier clues: environmental details, odd behavior, small dialogue lines. `docs/04_campaign_and_secrets.md` holds the clue map. Clues are placed deliberately, never randomly.

**The game rewards players for paying attention.**

## 3. What "built from parts" means here

- **Allowed:** Part (Block, Ball, Cylinder, Wedge, CornerWedge), WedgePart, CornerWedgePart, TrussPart, Seat, SpawnLocation, small and sparing UnionOperations, Roblox **default avatar bodies** (R15 MeshParts from `HumanoidDescription`), Decals and Textures **only** from built-in `rbxasset://` content (e.g. the default face), SurfaceGui/BillboardGui text, ParticleEmitter/Beam/Trail with built-in textures, Lights, Atmosphere/Sky/post-effects.
- **Not allowed:** imported meshes, uploaded images, uploaded animations, Terrain (except an approved exception in `decisions.md`), Toolbox models (unless the user explicitly approves a specific one).
- **Approved exception (user, 2026-10-10, D-045):** the user's own mesh model `AttackTitan` is used as a Shifter as it is.
- **Approved exception (user, 2026-10-10, D-039):** hair accessories from the Roblox marketplace on **Titans**, picked at random per Titan. Each asset ID is verified through the Studio MCP before it enters the list (`10` "Look direction").
- **Animation:** player characters use Roblox's default avatar animations. Frames, Titans and gestures use the **procedural pose animator** (`docs/08_rigs_and_animation.md`).

## 4. Scope of the first release: the Vertical Slice

The Vertical Slice is **Chapter 1, "The Last Quiet Morning"**, fully polished, plus the hub. This is the product. Everything else is documented so later work stays consistent, but **not built** yet.

**In the Vertical Slice:**
- Maps: **Central Command** (hub, including Pilot Quarters, Ops Hall, Briefing Room, Equipment, Medical, Arrival Platform, Observation Deck, the locked Research Corridor, and the Training Yard), the **Frame Hangar** and Launch Platform, **Frontier Outpost 07** with **Kessler Basin**, and the backdrops (city, Bulwark wall, wilderness).
- On-foot control of Elias (walk, sprint, jump, interact, talk).
- **One Frame:** Vanguard (Elias's Unit 02). Mara's Unit 01 is an AI ally with simplified behavior. Unit 03 is a static repair-bay prop.
- **One combat Titan:** Strider-class. **One scripted Titan:** the Watcher (no combat).
- The full Chapter 1 story: dialogue, 3 meaningful choices, 3 optional evidence logs, cinematics, the anomaly, the ending hook.
- Saving (checkpoints, flags, relationships, evidence, settings), pilot XP and credits, and 4 Vanguard upgrades (Phase 6).
- UI: on-foot HUD, Frame HUD, dialogue, objective tracker, mission log, settings, pause, chapter cards, mobile controls.

**Not in the Vertical Slice (documented only):** Striker, Bastion, Ranger and Prototype Frames as playable; other Titan species; Chapters 2+; Site Kestrel (map 4); co-op; monetization storefront (Phase 10); multiplayer hub (Phase 11).

## 5. Server size and players

- **Vertical Slice server size: 1 player** (Game Settings → Places → Max Players = 1). This keeps story state, cinematics and Titans simple and per-player.
- **All code is still written per-player.** No global variables holding one player's state. State is keyed by `Player` so co-op and the hub can be added later (Phase 11) without rewrites.

## 6. Non-goals and anti-patterns

- No giant empty open world. Every area has a purpose and good pacing.
- No "same model, different color" as the main form of progression.
- No unfinished chapters added just to look big.
- No one enormous script. No undocumented magic numbers: all tuning values live in `ReplicatedStorage.Shared.Config`.
- No dialogue meters that go up when you pick nice answers. Relationships change only for story reasons.
- No real asset IDs invented. No copyrighted names, music or logos. **Original world only: it isn't Attack on Titan.** No ODM gear, no walls named Maria/Rose/Sina, no nape-slicing as the core weakness, no "titans are just humans" twist. Titans here have species-specific weak points (the Strider's is the Dorsal Core).

## 7. Title candidates (decide after Chapter 1)

*ASHFALL*, *Lattice*, *The Bulwark*, *Genesis Frame*, *Frames of Ash*. The user decides; don't rename anything in-game before that.

## 8. Success criteria for the Vertical Slice

A first-time player, without help, can:
1. Wake in Quarters, find the hangar, and feel the Vanguard's scale.
2. Understand who Mara is and why she matters within 2 minutes.
3. Pilot the Frame, fight the Strider, and understand dodging, poise breaks and Core Strikes by the end of the fight.
4. Feel unsettled by the Watcher and the anomaly.
5. Reach the final message and want to play Chapter 2.
6. Do all of this on PC, gamepad and phone, at stable performance (`docs/19_testing_and_debug.md` §6).

Target play time for Chapter 1: **25–35 minutes** (40+ if the player explores and reads every log).
