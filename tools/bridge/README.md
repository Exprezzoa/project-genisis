# Genesis Bridge: Claude in Studio through GitHub

Lets a Claude **cloud** session (which can't reach the Studio MCP on your PC) work in your place (D-104).

```
Claude (cloud) --push--> GitHub: claude/yo-0sxhcv  bridge/job.lua + code
                                     |
            Studio plugin polls every 10 s, runs a new job in your open place
                                     |
Claude <--reads-- GitHub: bridge-reports  reports/<job id>.json  (result, Output, errors)
```

## Install (once)

1. **Make a GitHub token** that can only touch this repo:
   GitHub → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
   - Repository access: **Only select repositories** → `Exprezzoa/project-genisis`
   - Permissions → Repository permissions → **Contents: Read and write** (nothing else)
   - Copy the token (starts with `github_pat_`).
2. **Install the plugin.** Download `tools/bridge/GenesisBridge.rbxmx` from the `claude/yo-0sxhcv` branch on GitHub (open the file → "Download raw file").
   In Studio: **Plugins tab → Plugins Folder**, drop the file in, then restart Studio.
   (Or: insert a Script, paste `GenesisBridge.server.lua` into it, right-click it → **Save as Local Plugin**, then delete the Script.)
3. Open your place. **Plugins tab → Genesis Bridge → Bridge** opens the panel. Paste the token, press **Save settings**, then **Start watching**.
4. Studio asks twice the first time: allow **HTTP requests to api.github.com** and **script injection**. Both are needed.

The panel shows what it's doing. Leave Studio open with the place while Claude works. Press **Ctrl+S / Publish** when Claude asks.

## Safety

- Jobs run with plugin permissions in your open place, like the MCP's run-code tool. Anyone who can push to the work branch can run code in your Studio, so keep the repo private and the token scoped as above.
- Each job is one undo step: **Ctrl+Z** undoes it.
- The token is stored in Studio's plugin settings on your PC (plain text). Revoke it on GitHub any time.
- A job never overwrites a script you edited by hand unless the job says it expected that exact version (`expect`) or forces it.
- Keep only one Studio window watching at a time.

## For Claude: writing a job

`bridge/job.lua` on the work branch. First line `-- job: <id>` (letters, digits, `.`, `_`, `-`); a new id runs once.
The body is a ModuleScript: return a value, or a function called with `ctx`:

| ctx | |
|---|---|
| `ctx.commit` | the commit the job came from |
| `ctx.fetch(path)` | a repo file's text at that commit |
| `ctx.files(luaPattern)` | repo paths at that commit, e.g. `"^builders/.*%.lua$"` |
| `ctx.map(path)` | Studio path (array) and kind, per docs/16 §2 and builders/README.md |
| `ctx.studioSums(paths)` | Studio's current `{file, target, status, bytes, sum}` for repo files |
| `ctx.push(items)` | writes repo files into Studio; item = `"path"` or `{file=, expect=<sum>, force=, target=, kind=}`; result status `created / updated / unchanged / conflict / error` (a conflict carries `studioSource`) |
| `ctx.sum(text)` | bytes, adler32 (same as `tools/checksum.ps1`) |
| `ctx.find("Service.A.B")`, `ctx.dump(inst, depth)` | look around |
| `ctx.requireFresh(instOrPath)` | `require(inst:Clone())`, for builders and checks |
| `ctx.note(value)` | adds to the report's `notes` |
| `ctx.playtest(args)` | `StudioTestService:ExecutePlayModeAsync` (waits until the test calls `EndTest`); untested |

Read the result: `git fetch origin bridge-reports && git show origin/bridge-reports:reports/<id>.json`.

Tests (cloud side, no Studio): `luau tools/bridge/test.luau` and `python3 tools/bridge/test_files.py <luau>`. Rebuild the model file after any plugin change: `python3 tools/bridge/build_rbxmx.py`.
