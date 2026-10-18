"""Embed scripts/ranked/* + scripts/admin/Commands/Ranked.lua into fix/ranked_install.lua (between --@@BEGIN / --@@END SOURCES).
Usage (from tacticals_rebuild): python tools/ranked_build.py [--run lobby|match] [UNDO]
  --run lobby  runs the install in Tacticals_rebuild.rbxl (829eb64d); --run match in match_place_ref.rbxl (331cb3a0).
Studio ids change on reload (list_roblox_studios). Order: see the header of fix/ranked_install.lua."""
import json, os, re, subprocess, sys, tempfile

SIDS = {"lobby": "d7ca5f9f-18c6-4c56-8fda-3225cb2e5dd1", "match": "379cc32b-4d46-4950-8fc4-c3187ba355bf"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
FIX = os.path.join(ROOT, "fix", "ranked_install.lua")
FILES = {
    "RankedCore": "ranked/RankedCore.lua",
    "RankedServer": "ranked/RankedServer.lua",
    "RankedService": "ranked/RankedService.server.lua",
    "Cmd_Ranked": "admin/Commands/Ranked.lua",
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
