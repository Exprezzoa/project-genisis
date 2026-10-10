# Open Questions (for the user)

Claude adds questions here when a decision belongs to the user. Format: question → options (recommended first) → status.

| # | Question | Options | Status |
|---|---|---|---|
| Q-001 | Approve the canon story secrets in `docs/04_campaign_and_secrets.md` (Tobias alive and in ECHO custody, Watcher = Orin, Elias is a Resonant, the Bloom, endings A/B/C)? | Approve as is (rec.) / Revise specific points | Open |
| Q-002 | Final game title (decide after Chapter 1) | ASHFALL / Lattice / The Bulwark / Genesis Frame / Frames of Ash / other | Open |
| Q-003 | Audio: will you supply sound IDs from the Creator Store (Roblox-uploaded audio), or ship the Vertical Slice silent at first? | Supply IDs during Phase 7 (rec.) / Silent first | Open |
| Q-004 | Use Rojo for code sync (needs a one-time install), or MCP-only? | MCP-only to start (rec.) / Rojo | Open. Note from Session 1: MCP-only works and every push is checksum-verified (D-014), but each file has to be sent twice (local + Studio). Rojo would remove that cost once the code base grows in Phase 1 |
| Q-005 | `06` §5 says every lighting preset uses `Lighting.Technology = Future`. This Studio (0.742) has unified lighting: `Technology` can't be read or set by script; the place is on `LightingStyle = Soft`, `PrioritizeLightingQuality = true` (both scriptable). Which setting should Phase 1 use? | `LightingStyle = Realistic` + `PrioritizeLightingQuality = true`, set by script in Phase 1 (rec.; the closest match to Future, to be confirmed against the Roblox docs first) / keep Soft | Open (needed in Phase 1, lighting presets) |
| Q-006 | The place still has the template `Baseplate` (2048 × 16 × 2048, top at Y 0) and the default `SpawnLocation` at the origin, exactly where the Ops Hall goes. Remove them when the hub blockout is built? | Remove both in Phase 1 once the hub floors and `SPAWN_Q3_DESK` exist (rec.) / keep the Baseplate as temporary ground until the exterior is built | Open (needed at the start of the Phase 1 blockout) |
| Q-007 | Max Players: you set it to 1, but Studio reports `Players.MaxPlayers = 60` in both edit and play mode, so Claude can't verify it by script | Please confirm once in Game Settings → Places (or the Creator Dashboard) that this place shows Max Players = 1 | Open (user-confirmed, not machine-verified) |
| Q-008 | Git is installed, but this folder isn't a repository. `CLAUDE.md` §2 asks for a commit after each verified task | Let Claude run `git init` and commit after each verified task (rec.) / no Git | Open |
