# MAP 04 — Site Kestrel (the restricted research facility)

> **DO NOT BUILD during the Vertical Slice.** This doc exists so later chapters stay consistent. It appears at the **end of Act II** (Chapters 7–8). Its architecture, history and storytelling are fixed now.

**Origin:** (−6000, −400, 0) (underground). **Folder:** `Workspace.Map.Kestrel`. **Budget (when built):** 10,000 parts.

## 1. Purpose
- **Gameplay:** infiltration and exploration on foot, with tension (active security, a dormant Bearer), with one Frame segment in the Specimen Chamber.
- **Narrative:** reveal, through environment rather than exposition, that the site's **official description** ("Meridian Agricultural Research Station — soil remediation") hid the original Lattice experiments, the Bearers, and the **Kestrel Event (2061)**.
- **Mood:** abandoned but not dead. Some power still runs; some security still works; something still breathes in the dark.

## 2. Layout (descending)

```
 [Surface hatch & ruined pump station]  (Y +400 local surface)
          │ Entry Shaft (freight elevator, 120 deep, partial power)
 [Security Atrium] ── lockdown doors ── [Decontamination]
          │
 [OBSERVATION RING] — a circular corridor (radius 90) with windows into ↓
          ▼
 [SPECIMEN CHAMBER]  Ø120, 80 deep: the empty Bearer cradle, the calcified remains of a Bearer, roots of Lattice on the walls
          │
 ┌────────┼────────┬──────────────┐
 [LAB A]  [LAB B]  [LAB C]        [LAB D]
 Seed-0   Bearer   Resonance      Kessler's office
 culture  growth   studies        + personal archive
          │
 [MAINTENANCE TUNNELS] (partly flooded, low light)
          │
 [ARCHIVE VAULT] (resonance lock: needs a Resonant, i.e. Elias)
```

## 3. Spaces (key specs)
| Space | Size | Contents / storytelling |
|---|---|---|
| Surface pump station | 60 × 30 ruin | A rusted sign "MERIDIAN AGRICULTURAL RESEARCH STATION — SOIL REMEDIATION DIVISION" (the official lie) |
| Entry shaft | 20 × 20 × 120 | A freight elevator running on emergency power (slow, flickering); warning placards in pre-Emergence styling (`#2F6F8F` teal-blue Accord branding, distinct from Directorate amber) |
| Security Atrium | 50 × 40 × 16 | A guard desk, ID turnstiles, **still-active lockdown doors** (puzzle: reroute power), wall plaque listing Accord members (6 government seals + Halvorsen, Castell, Aurel logos built from parts) |
| Observation Ring | radius 90 corridor, 10 wide | Windows into the chamber, abandoned observation chairs, a whiteboard with Kessler's handwriting: "Resonance ≠ noise. It's language." |
| Specimen Chamber | Ø120 × 80 | Giant cradle frame (empty), a **calcified Bearer** (part-built, 60 long, ash-grey, half crumbled), Lattice "roots" (branching thin parts in dull amber) on the walls that **pulse cyan when Elias is near** (resonance) |
| Lab A — Seed-0 | 40 × 30 | Culture tanks (cracked), a sealed freezer bank, a log: "Seed-0 viable. Self-organizing. It's beautiful." |
| Lab B — Bearer growth | 60 × 40 | Growth vats, scale charts, a photo wall of Bearers (docile, grazing on toxic soil) |
| Lab C — Resonance | 40 × 30 | An audio-wave display wall (SurfaceGui), headsets, a test chair with restraints (unsettling, not gory), the first mention of "R-subjects" |
| Lab D — Kessler's office | 25 × 20 | A personal desk, a child's drawing of a "big gentle giant", **the Quiet Code** draft on a terminal (incomplete), a letter to the Accord: "If you bury this, it will bloom anyway." |
| Maintenance tunnels | 6 wide, ~300 long, partly flooded (water = transparent blue-grey parts at 0.4 transparency) | A security drone patrol (part-built hover drone, cone-of-light detection), a dormant mini-Lattice growth blocking one route |
| Archive Vault | 30 × 30 | Door with a **resonance lock** (concentric rings that align when Elias touches them, glowing cyan); inside: the Kestrel Event report, the Accord's burial order, the Bloom projections (120-year cycle) |

## 4. Active systems
- Emergency power grid (3 breakers to restore, each opening new areas).
- Lockdown doors (power-dependent).
- Security drones (2): detection cone, alarm → doors seal for 60 s.
- A dormant **Bearer remnant** organism in the tunnels (a non-hostile scare: it moves when lights flash).

## 5. Rules for builders and writers
- Pre-Emergence Accord style: teal-blue `#2F6F8F` and off-white `#D8D4C8`, rounded corners (wedges and cylinders), optimistic signage ("A GREENER TOMORROW"). It contrasts with the grim Directorate style.
- Every room must contain at least one environmental story element: an object, note or arrangement that hints at what happened, without full exposition.
- Clue payoffs here: clue map #2, #3, #8, #10, #11 (`04_campaign_and_secrets.md` §7).
