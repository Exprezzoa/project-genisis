"""Prints the Luau push list for a bridge job: every .lua file under src/ and builders/ that changed between the
commit Studio's scripts are known to match (bridge/studio_state.txt) and HEAD (or the working tree with --worktree).
studio_state.txt: the first word of the first line is the base commit; each further non-comment line
"<commit> <path>" records a file Studio holds at another commit (one a job pushed).

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


lines = [l.split("#")[0].split() for l in open(os.path.join(root, "bridge", "studio_state.txt"))]
lines = [l for l in lines if l]
state = lines[0][0]
override = {l[1]: l[0] for l in lines[1:]}
target = [] if "--worktree" in sys.argv else ["HEAD"]


def current(path):
    """The file's text in the working tree or at HEAD."""
    if target:
        return git("show", f"HEAD:{path}")
    return open(os.path.join(root, path), "rb").read()


def studio(path):
    """The file's text as Studio holds it, or None if Studio doesn't have it."""
    try:
        return git("show", f"{override.get(path, state)}:{path}")
    except subprocess.CalledProcessError:
        return None


changed = set(git("diff", "--name-only", state, *target, "--", "src", "builders").decode().split())
if not target:
    changed |= set(git("ls-files", "--others", "--exclude-standard", "--", "src", "builders").decode().split())
changed |= set(override)
items = []
for path in sorted(changed):
    if not path.endswith(".lua"):
        continue
    if not os.path.exists(os.path.join(root, path)) and not target:
        print(f"-- deleted, remove by hand if needed: {path}", file=sys.stderr)
        continue
    try:
        now = current(path)
    except subprocess.CalledProcessError:
        print(f"-- deleted, remove by hand if needed: {path}", file=sys.stderr)
        continue
    held = studio(path)
    if held is None:
        items.append(f'\t{{ file = "{path}" }},')
    elif adler(held) != adler(now) or len(held.replace(b"\r\n", b"\n")) != len(now.replace(b"\r\n", b"\n")):
        items.append(f'\t{{ file = "{path}", expect = {adler(held)} }},')
print("{")
print("\n".join(items))
print("}")
