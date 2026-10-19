"""Embed scripts/abilities/* into fix/abilities_install.lua (between --@@BEGIN / --@@END SOURCES), and optionally run it.
Usage (from tacticals_rebuild): python tools/abilities_build.py [--run lobby|match|both] [UNDO]
Run fix/weapon_abilities.lua first (phase 1). Studio ids change on reload (list_roblox_studios)."""
import json, os, re, subprocess, sys, tempfile

SIDS = {"lobby": "d93b3ec2-422d-40e2-87ce-6dd7b5c4e24c", "match": "f297bc30-46c5-414e-a250-d1593301e5a0"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
FIX = os.path.join(ROOT, "fix", "abilities_install.lua")
FILES = {
    "Abilities": "abilities/Abilities.lua",
    "AbilityController": "abilities/AbilityController.lua",
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
    target = sys.argv[sys.argv.index("--run") + 1]
    code = fix
    if "UNDO" in sys.argv[1:]:
        code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
    rc = 0
    for place in (["lobby", "match"] if target == "both" else [target]):
        fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
        json.dump({"studio_id": SIDS[place], "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
        r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                           env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
        print(place + ":", (r.stdout.strip() or r.stderr[-2000:])); os.remove(path); rc = rc or r.returncode
    sys.exit(rc)
