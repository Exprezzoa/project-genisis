# 15 — Audio

## 1. Rules
- **Claude never invents audio IDs.** Every sound is a key in `Shared/Config/SoundRegistry.lua` with `id = nil` until the **user** supplies a real asset ID.
- **The user finds sounds** in Studio: *Toolbox → Audio*, preferably uploaded by the **Roblox** account (licensed for use in experiences), or audio they uploaded or licensed themselves. They paste the ID into the registry (or give it to Claude to paste).
- **The game must run perfectly silent** with missing IDs. `AudioController` skips nil IDs and prints **one** warning per key in Studio only.
- **No voice acting** in the Vertical Slice. Dialogue is subtitles; radio lines get click/static SFX.
- Each registry entry includes **search terms** so the user can find a fitting sound quickly.

## 2. Registry format
```lua
-- Shared/Config/SoundRegistry.lua
return {
  SFX_VG_STEP = { id = nil, group = "SFX", volume = 0.8, rolloff = {min = 20, max = 400}, looped = false,
                  pitch = {0.95, 1.05}, desc = "Heavy mech footstep, metal on concrete", search = "mech footstep heavy metal stomp" },
  -- ...
}
```
`pitch` is a random range per play. 3D sounds are parented to an Attachment at the source; 2D (UI, music) to `SoundService` groups.

## 3. Sound groups and mixing
| SoundGroup | Default volume | Notes |
|---|---|---|
| Master | 1.0 | |
| Music | 0.6 | Ducked to 0.45× while dialogue or radio is showing (0.3 s fade) |
| SFX | 0.9 | |
| Ambience | 0.7 | |
| UI | 0.7 | |

Settings sliders control Music, SFX and Ambience (and UI follows SFX).

**Reverb by zone** (client `AudioController` sets `SoundService.AmbientReverb` when the zone changes):
| Zone | ReverbType |
|---|---|
| Quarters, Medical, Briefing | `Room` |
| Ops Hall, corridors | `Hallway` |
| Hangar | `Hangar` |
| Arrival, Observation Deck, Launch, outdoor hub | `City` |
| Outpost outdoor | `Plain` |
| Bunker | `StoneRoom` |
| Kessler Basin | `Quarry` |
| MemorySet | `Arena` (plus a low-pass on music and SFX) |

## 4. Full sound list (all `id = nil` initially)

### Frames
| Key | Description | Search terms |
|---|---|---|
| `SFX_VG_STEP` | Heavy mech footstep | mech footstep heavy metal stomp |
| `SFX_VG_SERVO` | Servo whine for joint movement (short) | servo motor whine robot |
| `SFX_VG_BOOT` | Systems power-up | power up machine startup sci-fi |
| `SFX_VG_SWING_LIGHT` | Big blade whoosh | large sword swing whoosh heavy |
| `SFX_VG_SWING_HEAVY` | Deeper, longer whoosh | heavy swing whoosh deep |
| `SFX_VG_PILEDRIVER` | Piston slam plus clank | piston slam hydraulic impact |
| `SFX_VG_STEAM` | Steam burst | steam release hiss burst |
| `SFX_VG_THRUSTER` | Short thruster burst (dodge) | thruster burst jet short |
| `SFX_VG_HIT_TAKEN` | Metal impact crunch | metal impact crash heavy |
| `SFX_VG_ALARM` | Cockpit warning beep loop | warning beep alarm loop cockpit |
| `SFX_VG_PLATE_DETACH` | Metal plate breaking off | metal clang break fall |
| `SFX_VG_DISABLED` | Power-down whir | power down shutdown machine |
| `SFX_HATCH` | Hatch open/close | hatch door hydraulic open |

### Titans
`SFX_STR_STEP` (deep fleshy thud: "giant footstep thud"), `SFX_STR_BREATH_LOOP` ("monster breathing loop"), `SFX_STR_SWEEP_TELL` ("monster groan rising"), `SFX_STR_SWEEP_WHOOSH` ("big whoosh swing"), `SFX_STR_STOMP_TELL` ("sharp inhale hiss creature"), `SFX_STR_STOMP_IMPACT` ("ground slam impact boom"), `SFX_STR_LUNGE_TELL` ("creature click growl"), `SFX_STR_ROAR` ("monster roar giant"), `SFX_STR_HIT_FLESH` ("flesh hit thump heavy", non-gory), `SFX_STR_HIT_BONE` ("bone crack hit"), `SFX_STR_FLINCH` ("creature pain grunt"), `SFX_STR_DOWNED` ("giant body fall thud"), `SFX_STR_CORE_OPEN` ("organic crack open"), `SFX_STR_CORE_STRIKE` ("heavy stab impact crunch"), `SFX_STR_DEATH_GROAN` ("monster death groan"), `SFX_ASH_CRACKLE` ("crackle crumble stone"), `SFX_ASH_VAPOR` ("steam hiss loop"), `SFX_WAT_STEP` ("soft heavy footstep"), `SFX_WAT_HUM` ("eerie hum drone").

### World and ambience
| Key | Where |
|---|---|
| `AMB_HUB_INTERIOR` | Ops Hall air handling and distant chatter ("office ambience hum") |
| `AMB_HANGAR` | Industrial hum, distant clanks ("factory ambience industrial") |
| `AMB_WELDING` | Bay 3 welding crackle loop ("welding sparks loop") |
| `AMB_CRANE` | Crane motor hum (3D on the crane) |
| `AMB_OUTDOOR_WIND` | Outpost wind ("wind ambience desolate") |
| `AMB_POWER_HUM` | Electrical hum after power is restored ("electric hum transformer") |
| `AMB_BASIN` | Hollow wind, distant creaks ("canyon wind ambience") |
| `AMB_CITY_EVENING` | Distant city ("city ambience distant evening") |
| `SFX_DOOR_HANGAR` | Massive door rising ("large metal door opening heavy") |
| `SFX_SIREN` | Deployment siren ("industrial siren alarm") |
| `SFX_BREAKER` | Big lever clunk plus electric surge ("lever switch heavy electric") |
| `SFX_SPARKS` | Spark burst ("electric sparks short") |
| `SFX_CONSOLE_BEEP` | Console interaction ("computer beep sci-fi") |
| `SFX_CASE_UNLOCK` | Case unlock ("lock click unlock mechanical") |
| `SFX_RESONANCE_PING` | Deep bass thump plus a shimmering ring ("bass pulse shimmer sci-fi") |
| `SFX_SCANNER` | Medical scanner sweep ("scanner beep sweep") |
| `PA_CHIME` | PA announcement chime ("announcement chime") |

### UI
`UI_HOVER`, `UI_CLICK`, `UI_OBJECTIVE` (soft rising tone), `UI_TOAST`, `UI_TYPE` (terminal typing blip, very short), `UI_CARD`, `SFX_RADIO_IN`, `SFX_RADIO_OUT` (radio click/static), `UI_DENIED` (energy insufficient).

### Music cues (looping unless noted)
| Key | Mood | Search terms |
|---|---|---|
| `MUS_HUB_MORNING` | Calm, hopeful, light synth or strings | calm ambient hopeful synth |
| `MUS_HANGAR_REVEAL` | Rising swell (one-shot) | epic swell orchestral rise |
| `MUS_DEPLOY` | Driving, determined | determined action build |
| `MUS_OUTPOST_TENSION` | Low drone, sparse | tension drone dark ambient |
| `MUS_COMBAT_STRIDER` | Heavy percussion, urgent | epic battle drums intense |
| `MUS_WATCHER` | Eerie, choir-like, slow | eerie choir mysterious |
| `MUS_ANOMALY` | Dissonant swell into silence (one-shot) | dissonant swell horror sting |
| `MUS_EVENING` | Melancholic piano | sad piano melancholy |
| `MUS_CHAPTER_END` | Resolution with an unresolved final chord (one-shot) | emotional ending piano strings |

## 5. Music state machine (client `AudioController`, driven by `music` sequence actions)
`HUB_MORNING` → (S04) `HANGAR_REVEAL` sting over the hub music → (S09) `DEPLOY` → (S20) `OUTPOST_TENSION` → (S28) `COMBAT_STRIDER` → (S30) fade out 3 s → (S31) `WATCHER` → (S33) `ANOMALY` → silence → (S40) `EVENING` → (S43) `CHAPTER_END`. Cross-fade 1.5 s unless specified.

## 6. 3D audio rules
- Frame and Titan footsteps: RollOffMode `InverseTapered`, min 20, max 400. Titan roars: max 900.
- Ambience loops in 3D emitters at fixed positions (hangar hum at 4 points, welding at Bay 3, power hum at transformers).
- At most 24 simultaneous non-UI sounds. `AudioController` drops the lowest-priority sounds beyond that.
