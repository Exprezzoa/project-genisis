# 13 — Sequences, Missions, Dialogue, Relationships, Interactions

The whole of Chapter 1 (hub scenes **and** the Outpost mission) runs through one data-driven system: the **Sequence Runner**. Content (steps, dialogue, objectives) is data in `ReplicatedStorage.Shared`; the server executes it; clients render it.

---

## 1. Sequence format (`Shared/Sequences/CH1.lua`)

```lua
return {
  id = "CH1",
  title = "THE LAST QUIET MORNING",
  steps = {
    { id = "S01_COLD_OPEN",
      onEnter = {
        { "fade", to = 1, duration = 0 },
        { "lighting", preset = "MORNING", instant = true },
        { "teleport", spawn = "SPAWN_Q3_DESK" },
        { "card", kind = "Title", lines = {"2187", "NEW HALDEN — HALDEN CENTRAL COMMAND"}, block = true },
        { "dialogue", id = "DLG_CH1_COLD_OPEN", block = true },
        { "fade", to = 0, duration = 1.2 },
      },
      objective = "OBJ_CH1_HANGAR",
      waypoint = { spawn = "WP_HANGAR_ENTRANCE" },
      complete = { "trigger", id = "TRG_HANGAR_REVEAL", who = "foot" },
      onComplete = { { "cinematic", id = "CIN_HANGAR_REVEAL", once = "SEEN_HANGAR_REVEAL", block = true } },
    },
    -- ...
    { id = "S22_BREAKER", checkpoint = "M01_POWER", ... },
  },
}
```

### 1.1 Step fields
| Field | Meaning |
|---|---|
| `id` | Unique step ID (matches the scene IDs in `05_chapter1_script.md` where possible) |
| `checkpoint` | If set, saved when this step **completes** (or when it begins, if `checkpointOnEnter = true`, as for `M01_FIGHT`) |
| `onEnter` | Ordered list of actions. `block = true` waits for completion before continuing |
| `objective` | Objective ID (text in `Shared/Objectives.lua`), plus optional `objectiveArgs` for counters |
| `optionalObjectives` | List of objective IDs shown in secondary style |
| `waypoint` | `{spawn = "<SpawnId>"}`, `{entity = "Frame:Player" / "NPC:Mara"}`, `{pos = Vector3}`, or a list of these |
| `complete` | Completion condition (§1.3) |
| `onComplete` | Ordered list of actions |
| `parallel` | Optional list of side listeners active during the step (optional interactions, barks) |

### 1.2 Actions (each is implemented once in `SequenceService/Actions`)
| Action | Params |
|---|---|
| `dialogue` | `id`, `block` |
| `cinematic` | `id`, `block`, `once = "<FLAG>"` (skip if the flag is set; set it after) |
| `bark` | `id` |
| `tutorial` | `id` (shows once per profile; flag `TUT_<id>`) |
| `setFlag` / `clearFlag` | `flag` |
| `rel` | `var`, `add`, `toast` |
| `objective` | `id`, `args` |
| `teleport` | `spawn` (character), or `frame = true, spawn` |
| `lighting` | `preset`, `instant` |
| `fade` | `to` (0/1), `duration` |
| `card` | `kind`, data, `block` |
| `wait` | `seconds` |
| `spawnTitan` / `despawnTitan` | `type`, `id`, `spawn`, `state` |
| `titanCommand` | `id`, `command` (e.g. `"Rise"`, `"StartFight"`, `"WatcherPath"`) |
| `ally` | `mode` (`Follow`/`Hold`/`Combat`/`Scripted`), `params` |
| `npc` | `id`, `command` (`moveTo` spawn/node, `face`, `gesture`, `spawn`, `despawn`) |
| `frame` | `command` (`lockWeapons`, `unlockWeapons`, `forceBoard`, `forceDismount`, `repair`, `autoWalk(to)`) |
| `prompt` | `id`, `enabled` |
| `door` | `id`, `open`/`close` |
| `checkpoint` | `id` (explicit save) |
| `reward` | `key` (idempotent grant from `Config/Progression.Rewards`) |
| `zoneState` | e.g. outpost power on: `{ "zoneState", zone = "Outpost07", key = "Power", value = true }` |
| `pa` | `set` = `"MORNING"`/`"EVENING"`/`"OFF"` (PA loop set) |
| `music` | `cue`, `fade` |

### 1.3 Completion conditions
| Kind | Params | Fires when |
|---|---|---|
| `trigger` | `id`, `who` = `"foot"` / `"frame"` / `"any"` | The player's character (or piloted Frame) HRP enters the trigger box |
| `interact` | `id` | ProximityPrompt `InteractId` used by this player |
| `counter` | `ids = {...}`, `n` | n distinct interacts completed (updates `objectiveArgs`) |
| `dialogueDone` | `id` | Dialogue ended |
| `cinematicDone` | `id` | Cinematic ended (server receives `Cinematic_Done`, or a timeout of duration + 5 s) |
| `event` | `name` (e.g. `"TitanDefeated"`, `"FrameBoarded"`, `"FrameDismounted"`, `"FrameDisabled"`) | Server event |
| `proximity` | `entity`, `radius` | The player's Frame or character is within the radius of an entity |
| `timer` | `seconds` | Elapsed |
| `any` / `all` | list of conditions | Combinators |

### 1.4 Sequence Runner rules
- One runner per player. State: `{sequenceId, stepIndex, stepState}`. It's saved only at checkpoints. On load, it jumps to the step that the checkpoint maps to (`05_chapter1_script.md` §11) and runs that step's **restore actions** (`onRestore`, if defined; else `onEnter`, minus anything marked `skipOnRestore = true`, such as one-time cinematics).
- **Failure handling:** `event FrameDisabled` during the fight → run the step's `onFail` actions (fail line, fade, reload checkpoint).
- Steps never directly reference Instances; they use IDs (SpawnId, TriggerId, InteractId, CamId, NPC IDs) resolved through registries built at server start by scanning tags.
- **Debug:** `DebugService` can jump to any step ID (`/step S28_FIGHT`).

## 2. Dialogue format (`Shared/Dialogue/*.lua`)

```lua
return {
  DLG_CH1_MARA_HANGAR = {
    mode = "conversation",          -- "conversation" | "radio" | "cinematic" | "bark"
    participants = {"Mara", "Hollis"},
    start = "MH_01",
    nodes = {
      MH_01 = { speaker = "M", text = "There he is. I was about to send a search party.", next = "MH_02" },
      MH_10 = { speaker = "M", text = "You nervous?",
                choices = {
                  { text = "Honestly? Yeah.", effects = { {flag = "CH1_ADMITTED_NERVES"} }, next = "MH_11a" },
                  { text = "Not as nervous as you'll be when I tie the score.", effects = { {flag = "CH1_JOKED_SCORE"} }, next = "MH_11b" },
                } },
      MH_12a = { speaker = "M", text = "Me too. A little. Tell anyone and I'll deny it.", next = "MH_14" },
      MH_14 = { speaker = "H", text = "Ember-2! ...", action = { npc = "Hollis", moveTo = "MARK_HOLLIS_TALK" }, next = "MH_15" },
      MH_22 = { speaker = "M", text = "Then walk faster." },   -- no next = end
    },
  },
}
```

| Node field | Meaning |
|---|---|
| `speaker` | Speaker code (§2.1) |
| `text` | The line (≤ 120 chars; the line ID is the node key) |
| `next` | Next node ID; absent = end |
| `choices` | Up to 4. Each: `text`, `effects`, `next`, optional `cond` |
| `timer` | Seconds for a timed choice; `timeoutChoice` = index used on timeout |
| `cond` | `{flag = X}`, `{notFlag = X}`, `{rel = {"mara", ">=", 1}}`, or `{all = {...}}` / `{any = {...}}`. If false, the node is **skipped** (go to `next`) |
| `effects` | `{flag = X}`, `{rel = "mara", add = 1, toast = "Mara will remember that."}`, `{evidence = id}`, `{reward = key}` |
| `action` | Side effect on show: NPC move, gesture, look, camera hint (`cam = "CAM_BRF_VALE"`), slide change (`slide = 3`), sound |
| `duration` | Override auto-advance timing (radio and cinematic modes) |
| `pause` | Seconds of silence before the line (e.g. Vale's 1.2 s pause) |

**Server-authoritative flow:** the server sends `Dialogue_Node {dialogueId, nodeId}` → the client renders the text from its local copy of the data → the client sends `Dialogue_Advance` or `Dialogue_Choose` → the server validates that it's the current node, applies effects, and sends the next node. Timed choices are enforced on the server (it applies `timeoutChoice` when the timer expires). **Radio and cinematic** modes auto-advance on the server using `duration` (default `max(2.2, 0.06 × #text)`), and the client can't skip lines in those modes except via cinematic skip.

### 2.1 Speakers (`Shared/Dialogue/Speakers.lua`)
| Code | Display name | Name color | Radio? |
|---|---|---|---|
| `E` | ELIAS | `#E8ECEF` | when piloting |
| `M` | MARA | `#E58A7E` | when piloting |
| `V` | CMDR. VALE | `#8FB3D9` | on comms in missions |
| `VS` | DR. VOSS | `#B9D98F` | no |
| `R` | CMDR. RHEIN | `#AEB6BF` | no |
| `H` | CHIEF BRANDT | `#E8B923` | no |
| `O` | OVERWATCH | `#E8A33D` | always |
| `T` | ROOK | `#8FD9A0` | no |
| `PA` | PUBLIC ADDRESS | `#9AA6B2` | lo-fi |
| `OFFICER` | OFFICER | `#9AA6B2` | no |
| `VOICE` | (none) | `#7FE3F0` italic | special |

Lines tagged `[E-thought]` in the script use `speaker = "E"` with `style = "thought"` (italic, no name tab).

## 3. Relationships, flags, evidence

- **RelationshipService** (server): `get(player, var)`, `add(player, var, delta, reason)`. Clamped to −3…+3. Every change is logged (`reason` string) in `profile.story.relLog` (max 50 entries) for debugging. A toast only if `toast` is given. **Never show numbers in the UI.**
- **FlagService:** `set`, `clear`, `has`. Flags are strings, stored in a set. Use the naming `CH<n>_...`, `TUT_...`, `SEEN_...`.
- **EvidenceService:** `collect(player, id)` → flag `EV_<id>`, an idempotent reward (`EV_` key), and a UI toast "Evidence added to Mission Log." Evidence texts live in `Shared/Evidence.lua`.

## 4. Interactions (`InteractionService` server / `InteractionController` client)

- Every interactable is a part tagged `Interactable` with a `ProximityPrompt` child and attributes: `InteractId` (unique), `FrameOnly` (bool), `OnFootOnly` (bool), `Once` (bool).
- **The server listens to `ProximityPrompt.Triggered`** (no custom remote). It validates the context (piloting vs. on foot, distance, step state) and routes to the handler registered for that `InteractId` (by the Sequence Runner or by static handlers, e.g. photo, locker, poster).
- **Prompt visibility:** the server enables a prompt only when it's relevant (step-gated prompts start disabled). **Frame-scale prompts** use `MaxActivationDistance = 30` and `RequiresLineOfSight = false`, and the client only shows them while piloting.
- **As built (D-068):** Frame-only prompts carry `MaxActivationDistance` 70, because the engine measures from the pilot, who sits about 49 studs up in the 64-stud Frame; the server checks the Frame's root within 48 studs of the prompt along the ground (`GameConfig.Interaction`). **Step-gated prompts** are enabled in the world and switched off per player until their step (D-069).
- **Custom prompt style:** `ProximityPrompt.Style = Custom`. The client draws its own BillboardGui (`14_ui.md` §4).

## 5. Triggers (`TriggerService`)
- Trigger parts are tagged `Trigger` with attribute `TriggerId`. **Don't use `.Touched`.** Every 0.2 s, the server checks each player's character HRP and piloted-Frame HRP with a point-in-oriented-box test, and fires `TriggerService.Entered(player, triggerId, who)` and `Exited`.

## 6. NPCs (`NPCService` server, `NPCAnimator` client)
- NPC definitions live in `Shared/Config/NPCs.lua`: `{id, template, spawn, idle = "CrossArms"/"HandsBehindBack"/"Inspect"/nil, route = {nodes...}/nil, barks = {...}, talk = dialogueId/nil}`.
- **Ambient routes:** technicians and officers loop through nav nodes with random 2–6 s pauses and the `Inspect` gesture at certain nodes.
- **Follower mode** (Mara, S06): path along nav nodes toward the target, waiting if the player is more than 30 studs away. Speed matches the player (14/22).
- **Talkable NPCs** have a ProximityPrompt "Talk" (InteractId `TALK_<id>`). During conversation they turn to face Elias (AlignOrientation on the HRP or `Humanoid.AutoRotate` plus a MoveTo-in-place facing trick; pick one and log it) and use the `TalkFidget` overlay while their line is displayed.

## 7. Barks (`BarkController`)
- Bark data: `{id, speaker, text, cooldownGroup, maxPerFight}`. Played as a radio subtitle (Frame) or a BillboardGui above the NPC (on foot).
- Global bark cooldown 12 s in combat, 6 s ambient. One at a time; a new bark never interrupts dialogue.

## 8. Tutorials (`TutorialController`)
- Data `Shared/Tutorials.lua`: `{id, title, body (device variants), condition (client-evaluated, from the script table), duration = 5}`.
- Shown once per profile (flag `TUT_<id>` set via the server).
- Never shown during dialogue or cinematics. `TUT_DODGE` is the only tutorial allowed during a telegraph.
- Settings → "Tutorial hints: Off" suppresses all of them.
