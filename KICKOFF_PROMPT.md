# Prompts to paste into Claude Code

Before each session, open Roblox Studio with your place, then open Claude Code in this folder.

---

## Prompt 1: first session (set effort to Max)

```
We're starting PROJECT GENESIS: a story-driven mech-vs-Titan action RPG for Roblox Studio, built entirely from Roblox parts (Roblox avatars for people, giant part-built Frames and Titans, in the style of Roblox Attack-on-Titan-like games but with an original world). This folder is the complete design pack and it is the authority.

1. Read CLAUDE.md completely. Then read fully: docs/01_vision_and_scope.md, docs/07_building_with_parts.md, docs/16_technical_architecture.md, docs/18_roadmap.md (Phase 0 and Phase 1), docs/19_testing_and_debug.md, docs/maps/map_00_world_layout.md. For every other doc, read only the headings for now so you know what exists. You'll read them in full when their phase comes.
2. List the Roblox_Studio MCP tools you actually have and confirm you can run code in my open Studio place.
3. Inspect what's currently in the place before changing anything, and summarize it.
4. Give me a short plan (5–10 bullets) for Phase 0 and the first steps of Phase 1, plus the exact things I need to do in Studio myself (publishing, API access, max players, anything else).
5. Then do Phase 0 exactly as docs/18_roadmap.md describes, testing as you go.

Rules: don't guess. The docs give names, numbers, coordinates, colors and dialogue, so use them exactly. If something truly isn't specified, choose the smallest reasonable option and log it in docs/tracking/decisions.md. If it affects story, scope or money, ask me first. Never say something works unless you tested it. When we stop, do the session-end checklist in CLAUDE.md.
```

---

## Prompt 2: every new session ("continue"; effort High)

```
Continue PROJECT GENESIS. Do the session-start checklist in CLAUDE.md: read the latest journal entry, the checklist and the open questions, then inspect the actual Studio state (don't trust the plan, check the place). Tell me in a few lines where we are and what you'll do this session, then continue the current phase. Test everything you build. Do the session-end checklist before we stop.
```

---

## Prompt 3: starting a new phase

```
Phase <N> is next. Read the docs listed for Phase <N> in docs/18_roadmap.md in full. Give me the build order for this phase as a numbered list, with how you'll test each step, then start. Remember the acceptance tests at the end of the phase must all pass and be recorded in the journal.
```

---

## Prompt 4: something is broken (effort Max if it's stubborn)

```
Something's wrong: <describe what you see / paste the Output errors / paste a screenshot>.
Find the root cause before changing code: reproduce it, read the relevant scripts and console output, and explain the cause in 2–3 sentences. Then fix it, re-test, and log it as a BUG entry in the journal.
```

---

## Prompt 5: you edited things by hand in Studio

```
I changed things by hand in Studio: <what you changed>. Read the current state of those instances back from Studio, merge my changes into the local files (src/ or builders/) so they won't be overwritten, and note it in the journal.
```

---

## Prompt 6: checking visuals with a screenshot

```
Here's a screenshot of <area> (attached). Compare it with docs/maps/<file>.md and docs/06_art_direction.md. List what's wrong or missing (scale, layout, colors, materials, props, lighting), then fix it and tell me what to screenshot next.
```

---

## Prompt 7: feel tuning after you playtest

```
I playtested <Frame movement / the Strider fight / Chapter 1 up to X>. Feedback: <what felt off>. Propose specific number changes (in the config and the matching doc), apply them, log them in docs/tracking/decisions.md, and tell me what to test again.
```

---

## Prompt 8: wrapping up

```
We're stopping for now. Do the session-end checklist from CLAUDE.md (journal entry, checklist, decisions, open questions) and tell me exactly what to save or publish in Studio.
```

---

### Tips
- If Claude starts drifting from the spec, say: **"Check the doc for this and follow it exactly."**
- If a session gets very long, start a fresh one with Prompt 2. The journal makes it resumable.
- Answer the questions in `docs/tracking/open_questions.md` when you can. Q-001 (approving the story secrets) matters most before Phase 5.
