"""Embed fix/breakable_glass/*.lua into fix/breakable_glass.lua (between --@@BEGIN / --@@END SOURCES), and optionally run it.
Usage (from tacticals_rebuild):
  python tools/breakable_glass_build.py                                    embed only
  python tools/breakable_glass_build.py --run <studio_id> [UNDO] [DRY]     embed, then run in that Studio's Edit DataModel
  python tools/breakable_glass_build.py --file <lua> --run <studio_id>     run another Lua file there (tests, test window)
One installer for the hub (lobby pad duels) and the match places. Studio ids: python ../roblox_kits/tools/mcpcli.py call list_roblox_studios {}"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
CLI = os.path.join(ROOT, "..", "roblox_kits", "tools", "mcpcli.py")
FIX = os.path.join(ROOT, "fix", "breakable_glass.lua")
SRC = os.path.join(ROOT, "fix", "breakable_glass")
FILES = {
    "Openings": "Openings.lua",
    "WindowGlassController": "WindowGlassController.lua",
    "GlassBlock": "ShootableConfig_Glass.lua",
    "TestHook": "TestHook.lua",
}


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s or ("[" + "=" * n + "[") in s:
        n += 1
    return "[" + "=" * n + "[\n" + s + "]" + "=" * n + "]"   # a newline right after [==[ is dropped by Lua


lines = []
for k, f in FILES.items():
    text = open(os.path.join(SRC, f), encoding="utf-8").read().replace("\r\n", "\n")
    lines.append(f"SOURCES.{k} = {long_string(text)}")
block = "--@@BEGIN SOURCES\n" + "\n".join(lines) + "\n--@@END SOURCES"
fix = open(FIX, encoding="utf-8").read()
fix = re.sub(r"--@@BEGIN SOURCES.*?--@@END SOURCES", lambda _: block, fix, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(fix)
print("embedded", len(FILES), "sources into fix/breakable_glass.lua")

if "--run" in sys.argv:
    sid = sys.argv[sys.argv.index("--run") + 1]
    code = fix
    if "--file" in sys.argv:
        code = open(os.path.join(ROOT, sys.argv[sys.argv.index("--file") + 1]), encoding="utf-8").read()
    if "UNDO" in sys.argv[1:]:
        code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
    if "DRY" in sys.argv[1:]:
        code = re.sub(r"^local DRY = false --@DRY", "local DRY = true --@DRY", code, flags=re.M)
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       errors="replace", env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    os.remove(path)
    print(r.stdout.strip() or r.stderr[-2000:])
    sys.exit(r.returncode)
