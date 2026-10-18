"""Prints the Luau push list for a bridge job: every .lua file under src/ and builders/ that changed between the
commit Studio's scripts are known to match (bridge/studio_state.txt) and HEAD (or the working tree with --worktree).

Each item carries `expect`, the bytes/adler32 sum of the file as Studio holds it (computed from that commit, the
same sum as tools/checksum.ps1 and the plugin), so the plugin refuses to overwrite anything edited by hand in
Studio since. New files have no `expect` (the plugin creates them, and refuses if something is already there).

Usage: python3 tools/bridge/sync_list.py [--worktree]
"""
import os, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def git(*args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, check=True).stdout


def adler(data: bytes):
    data = data.replace(b"\r\n", b"\n")
    a, b = 1, 0
    for byte in data:
        a = (a + byte) % 65521
        b = (b + a) % 65521
    return b * 65536 + a


state = open(os.path.join(root, "bridge", "studio_state.txt")).read().split()[0]
target = [] if "--worktree" in sys.argv else ["HEAD"]
changed = git("diff", "--name-status", state, *target, "--", "src", "builders").decode().splitlines()
items = []
for line in changed:
    status, path = line.split("\t")[0], line.split("\t")[-1]
    if not path.endswith(".lua"):
        continue
    if status.startswith("D"):
        print(f"-- deleted, remove by hand if needed: {path}", file=sys.stderr)
        continue
    if status.startswith("A"):
        items.append(f'\t{{ file = "{path}" }},')
    else:
        old = git("show", f"{state}:{path}")
        items.append(f'\t{{ file = "{path}", expect = {adler(old)} }},')
print("{")
print("\n".join(items))
print("}")
