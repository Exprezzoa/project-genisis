# src/ — game code (source of truth)

Every Script, LocalScript and ModuleScript of PROJECT GENESIS lives here and is pushed into Studio through the Roblox Studio MCP. The layout mirrors the Studio tree exactly (`docs/16_technical_architecture.md` §2). Read that doc before writing any code.

## Mapping rule

| Local | Studio |
|---|---|
| `Name.server.lua` | Script |
| `Name.client.lua` | LocalScript |
| `Name.lua` | ModuleScript |
| folder | Folder |
| folder containing `init.lua` | ModuleScript (the folder's other files become its children) |

## Tree

```
src/
├─ ReplicatedFirst/                         LoadingScreen.client.lua
├─ ReplicatedStorage/Shared/
│  ├─ Config/                               GameConfig, FrameConfig, TitanConfig, CombatConfig, ...
│  ├─ Poses/                                Vanguard, Strider, Watcher, Human
│  ├─ Dialogue/                             Speakers, CH1_Hub, CH1_M01, CH1_Return, Barks
│  ├─ Sequences/                            CH1
│  ├─ Modules/                              Net, Signal, Trove, StateMachine, PoseAnimator, ...
│  └─ Objectives.lua, Evidence.lua, Tutorials.lua, Cinematics.lua
├─ ServerScriptService/Server/
│  ├─ Main.server.lua
│  ├─ Services/                             one module per service (Init / Start)
│  ├─ Sequence/                             Actions, Conditions, Registry
│  └─ Titans/Behaviors/                     StriderBehavior, WatcherBehavior
└─ StarterPlayer/StarterPlayerScripts/Client/
   ├─ Main.client.lua
   ├─ Controllers/                          one module per controller (Init / Start)
   └─ UI/Components/, UI/Screens/
```

The folders are empty until Phase 1. Nothing here is built ahead of the roadmap (`docs/18_roadmap.md`).

## Rules

- Edit here first, then push the file into Studio (set the matching instance's `.Source`). Never edit only in Studio.
- If something was changed by hand in Studio, read it back and merge it into the local file before pushing again.
- After every push, compare the Studio source with the local file (length + checksum) so both stay in sync.
- The server is the authority. Clients never decide damage, health, currency, rewards or mission state.
- All tuning values live in `ReplicatedStorage/Shared/Config`. No magic numbers in systems.
- No script over ~600 lines; split by responsibility.
- Instances that aren't code (maps, rigs, the StarterCharacter, DevTools) come from `builders/`, not from here.
