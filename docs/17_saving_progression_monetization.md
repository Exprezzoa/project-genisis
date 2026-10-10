# 17 — Saving, Progression, Monetization

## 1. Requirements before saving works in Studio
- The place must be **published** (File → Publish to Roblox).
- **Game Settings → Security → "Enable Studio Access to API Services" = ON.**
- Claude must ask the user to do both in Phase 0/1. If API access is off, PlayerDataService runs in **memory-only mode** with a loud Studio warning (`[PlayerDataService] API services disabled: profiles will NOT persist`).

## 2. Profile schema v1 (`PlayerDataService`)

DataStore: `PG_Profiles_v1`. Key: `u_<UserId>`.

```lua
{
  schemaVersion = 1,
  createdAt = 0,            -- os.time()
  lastSaveAt = 0,
  saveCount = 0,
  _lock = nil,              -- { jobId = string, time = number } while a server holds the session

  story = {
    chapter = 1,
    sequenceId = "CH1",
    checkpoint = nil,        -- e.g. "M01_FIGHT"; nil = start of the chapter
    flags = {},              -- set: [flagName] = true
    completedChapters = {},  -- set
    relLog = {},             -- array of {var, delta, reason, t} (max 50, oldest dropped)
  },
  relationships = { mara = 0, vale = 0, voss = 0, orin = -1 },
  evidence = {},             -- set: [evidenceId] = os.time()

  progression = {
    xp = 0, rank = 1, credits = 0,
    grants = {},             -- set of idempotency keys already granted
    upgrades = {},           -- set: [upgradeId] = true
  },

  cosmetics = { owned = {}, equipped = { framePaint = "DEFAULT", suit = "DEFAULT" } },

  settings = {
    camSensitivity = 1.0, invertY = false, cameraShake = 1.0,
    sprintToggle = false, strideToggle = false,
    subtitles = true, subtitleSize = "M",
    musicVolume = 0.6, sfxVolume = 0.9, ambienceVolume = 0.7,
    reduceFlashing = false, tutorialHints = true, damageNumbers = false,
  },

  purchases = { receipts = {} },   -- [PurchaseId] = os.time()  (keep the newest 200)
  stats = { titansDefeated = 0, framesDisabled = 0, playTimeSec = 0 },
}
```

## 3. Load algorithm
1. On `PlayerAdded`: `UpdateAsync(key, fn)` with retries (§5). Inside `fn`:
   - `nil` data → create the default profile.
   - Lock present, `jobId ≠ game.JobId`, and `os.time() − lock.time < 600` → **return nil** (don't write); the outer code waits 5 s and retries (max 6 tries ≈ 30 s). After that, **steal the lock** with a logged warning. (Single-player servers make conflicts rare: usually a fast rejoin.)
   - Otherwise set `_lock = {jobId = game.JobId, time = os.time()}` and return the data.
2. **Migrate** (`migrations[fromVersion](data)` up to `CURRENT_VERSION`). Fill missing keys from the defaults (deep reconcile, never deleting unknown keys).
3. **If loading fails after all retries:** mark the profile `readOnly = true` (play continues, nothing is saved) and show a toast: "Couldn't load your save. Progress this session won't be saved." **Never overwrite stored data with defaults after a failed load.**
4. Fire `Loaded(player, profile)`. Only then does SequenceService start the player's sequence.

## 4. Save algorithm
- **When:** at every checkpoint, every 120 s (autosave, if dirty), on `PlayerRemoving`, in `game:BindToClose` (save all, wait up to 25 s), after purchases (before returning PurchaseGranted), after upgrade purchases.
- **How:** `UpdateAsync(key, fn)`: in `fn`, verify `stored._lock.jobId == game.JobId` (if not, abort: another server owns the session, so log an error and don't write), then write the profile with `lastSaveAt` and `saveCount + 1`. On leave, the final save sets `_lock = nil`.
- Check `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)` before autosaves. If the budget is low, defer the autosave (never defer leave or BindToClose saves).
- Never save more than once every 6 s per key (queue the latest).

## 5. Retry policy
5 attempts with exponential backoff: 1, 2, 4, 8, 16 s (plus random jitter 0–0.5 s). Log every failure with the error message.

## 6. Progression
| Rank | Name | XP required |
|---|---|---|
| 1 | Pilot Officer | 0 |
| 2 | Pilot Officer II | 600 |
| 3 | Lieutenant | 1500 |
| 4 | Senior Lieutenant | 3000 |
| 5 | Captain | 5000 |

- Rewards are granted only via `ProgressionService.grant(player, key)`. `key` maps to `Config/Progression.Rewards[key] = {xp, credits}`. A key already in `progression.grants` is ignored (idempotent).
- **Chapter 1 reward keys:** `CH1_M01_COMPLETE` (500 XP / 300 cr), `CH1_STRIDER_DEFEATED` (300 / 100), `EV_OP07_LOG1/2/3` (50 / 0 each), `CH1_CLEAN_KILL` (100 / 50). Max Chapter 1 total: 1,050 XP (Rank 2) and 450 credits.
- **Upgrades** (`12_combat_system.md` §12) are bought at the **Equipment Terminal** (Sgt. Morrow) in Phase 6: UI list with name, description, cost, rank requirement, and Buy (server validates rank, credits and not-owned, deducts, saves, recomputes the effective config).
- Replaying content (post-chapter Training Yard) gives no XP in the Vertical Slice.

## 7. Monetization (Phase 10 only; don't build before)

### 7.1 Principles (from the design bible)
- Free to play. **The full story is playable without paying.**
- No selling story-critical information, no paywalled bosses, no frustration-for-profit, no misleading purchase UI, no randomized paid rewards (no loot boxes).
- Products are **cosmetic** or gentle convenience that never affects combat balance.
- **Never invent product IDs or prices.** `Config/Products.lua` holds entries with `id = nil` until the user creates them on the Creator Dashboard and supplies the IDs and prices.

### 7.2 Planned catalog (placeholders)
| Key | Type | Content |
|---|---|---|
| `PAINT_ASH_CAMO` | Developer Product (one-time unlock, tracked in the profile) or Game Pass | Vanguard paint: ash-grey camo (part color pattern swap) |
| `PAINT_CORROW_RUST` | same | Rust-red industrial paint |
| `PAINT_NIGHT_OPS` | same | Near-black with amber trims |
| `PAINT_PARADE` | same | Directorate parade white and slate |
| `SUIT_COLORS_PACK` | same | 4 pilot suit color sets (BodyColor swaps plus piping) |
| `HANGAR_BANNERS` | same | Bay 2 personal banners |
| `EMOTES_PACK` | same | Salute, wave, hatch-tap (procedural gestures) |
| `SUPPORTER` | Game Pass | Supporter badge in the Mission Log plus the parade paint |

A paint scheme is data: a map of `partRole → color` (armor, armor dark, accent, frame), applied by `FrameService` on spawn from `cosmetics.equipped`.

### 7.3 Receipt handling (`MonetizationService`)
```
ProcessReceipt(info):
  player = Players:GetPlayerByUserId(info.PlayerId); if not player → NotProcessedYet
  profile = waitForProfile(player, 10 s); if not profile or readOnly → NotProcessedYet
  if profile.purchases.receipts[info.PurchaseId] → PurchaseGranted        -- already done
  grant the product (idempotent: owned set)
  profile.purchases.receipts[info.PurchaseId] = os.time(); trim to the newest 200
  ok = saveNow(player, "purchase")    -- must succeed
  return ok and PurchaseGranted or NotProcessedYet
```
Game passes: check with `MarketplaceService:UserOwnsGamePassAsync` (pcall, cached per session) plus `PromptGamePassPurchaseFinished`.

### 7.4 Store UI
A tab in the Equipment Terminal: "CUSTOMIZATION". It shows previews (it applies the paint to a preview Frame in the hangar bay). Prices are shown exactly as Roblox provides them (`GetProductInfo`). Clear "Buy" buttons only; no fake timers or "limited" pressure.
