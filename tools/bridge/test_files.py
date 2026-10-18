"""Checks the bridge's sum, base64 and mapping on every .lua file under src/ and builders/.

Usage: python3 tools/bridge/test_files.py <path to the luau CLI>
Embeds each file in a generated Luau script, runs it, and compares with Python's own results.
"""
import base64, os, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
luau = sys.argv[1]
files = sorted(
    os.path.relpath(os.path.join(d, f), root)
    for top in ("src", "builders")
    for d, _, fs in os.walk(os.path.join(root, top))
    for f in fs if f.endswith(".lua")
)

def adler(data: bytes):
    data = data.replace(b"\r\n", b"\n")
    a, b = 1, 0
    for byte in data:
        a = (a + byte) % 65521
        b = (b + a) % 65521
    return len(data), b * 65536 + a

def long_string(data: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in data:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + data + "]" + eq + "]"

plugin = os.path.join(root, "tools", "bridge", "GenesisBridge.server.lua")
lines = ['local Pure = require("./GenesisBridge.server")', "local cases = {"]
for f in files:
    text = open(os.path.join(root, f), "rb").read().decode("utf-8")
    lines.append("{" + repr(f).replace("'", '"') + ", " + long_string(text) + "},")
lines.append("}")
lines.append("""for _, c in ipairs(cases) do
	local names, kind = Pure.map(c[1])
	local bytes, sum = Pure.sum(c[2])
	print(c[1] .. "\\t" .. bytes .. "\\t" .. sum .. "\\t" .. (names and table.concat(names, ".") or ("ERR " .. kind)) .. "\\t" .. (names and kind or "") .. "\\t" .. Pure.base64(c[2]))
end""")
# Written next to the plugin (Luau's require is relative to the script) and removed afterwards.
harness = os.path.join(os.path.dirname(plugin), "_harness.luau")
open(harness, "w").write("\n".join(lines))
try:
    run = subprocess.run([luau, harness], capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit("luau failed:\n" + run.stdout[-2000:] + run.stderr[-2000:])
    out = run.stdout
finally:
    os.remove(harness)

bad = 0
for line in out.splitlines():
    f, n, s, target, kind, b64 = line.split("\t")
    raw = open(os.path.join(root, f), "rb").read()
    # A long bracket drops one newline right after "[[": the harness adds one, so raw text is intact.
    if (int(n), int(s)) != adler(raw):
        bad += 1; print("SUM MISMATCH", f)
    if base64.b64decode(b64) != raw:
        bad += 1; print("BASE64 MISMATCH", f)
    print(f"{f} -> {target} ({kind})")
print(f"{len(files)} files, {bad} mismatches")
sys.exit(1 if bad else 0)
