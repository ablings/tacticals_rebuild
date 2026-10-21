"""Embed scripts/secure/* into fix/secure_install.lua (between --@@BEGIN / --@@END SOURCES).
Usage (from tacticals_rebuild): python tools/secure_build.py [--run lobby|match] [UNDO]
  --run lobby  runs the install in Tacticals_rebuild.rbxl (829eb64d); --run match in match_place_ref.rbxl (331cb3a0).
Studio ids change on reload (list_roblox_studios). Order: see the header of fix/secure_install.lua."""
import json, os, re, subprocess, sys, tempfile

SIDS = {"lobby": "ddbec6a6-8f28-4bef-9054-7be5bea3e83a", "match": "221cdf09-8c72-40c3-83ef-afb3ad146aac"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
FIX = os.path.join(ROOT, "fix", "secure_install.lua")
FILES = {
    "MatchSpec": "secure/MatchSpec.lua",
    "HitRewind": "secure/HitRewind.lua",
    "MoveGuard": "secure/MoveGuard.server.lua",
}


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


lines = [f"SOURCES.{k} = {long_string(open(os.path.join(ROOT, 'scripts', f), encoding='utf-8').read())}" for k, f in FILES.items()]
block = "--@@BEGIN SOURCES\n" + "\n".join(lines) + "\n--@@END SOURCES"
fix = open(FIX, encoding="utf-8").read()
fix = re.sub(r"--@@BEGIN SOURCES.*?--@@END SOURCES", lambda _: block, fix, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(fix)
print("embedded", len(FILES), "sources into", os.path.relpath(FIX, ROOT))
if "--run" in sys.argv:
    place = sys.argv[sys.argv.index("--run") + 1]
    code = fix
    if "UNDO" in sys.argv[1:]:
        code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SIDS[place], "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    print(r.stdout); print(r.stderr[-2000:], file=sys.stderr); os.remove(path); sys.exit(r.returncode)
