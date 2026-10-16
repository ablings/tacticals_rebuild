"""Embed scripts/admin/*.lua into fix/admin_install.lua (between --@@BEGIN SOURCES / --@@END SOURCES).
Usage (from tacticals_rebuild): python tools/admin_build.py [--run] [UNDO]
  --run  also runs the install in Tacticals_rebuild.rbxl through tools/run_luau.py (studio id there).
The match place gets the same files later (notes/admin_framework.md, "Match place")."""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
SRC = os.path.join(ROOT, "scripts", "admin")
FIX = os.path.join(ROOT, "fix", "admin_install.lua")
FILES = {  # SOURCES key -> file
    "Config": "Config.lua",
    "Permissions": "Permissions.lua",
    "Args": "Args.lua",
    "DataAdapter": "DataAdapter.lua",
    "Audit": "Audit.lua",
    "Core": "Core.lua",
    "Cmd_Data": "Commands/Data.lua",
    "Cmd_Player": "Commands/Player.lua",
    "Cmd_Duel": "Commands/Duel.lua",
    "Cmd_World": "Commands/World.lua",
    "Cmd_Debug": "Commands/Debug.lua",
    "Cmd_Legacy": "Commands/Legacy.lua",
    "AdminCommands": "AdminCommands.server.lua",
    "AdminFeedback": "AdminFeedback.client.lua",
}


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


lines = []
for key, fn in FILES.items():
    src = open(os.path.join(SRC, fn), encoding="utf-8").read()
    lines.append(f"SOURCES.{key} = {long_string(src)}")
block = "--@@BEGIN SOURCES\n" + "\n".join(lines) + "\n--@@END SOURCES"
fix = open(FIX, encoding="utf-8").read()
fix = re.sub(r"--@@BEGIN SOURCES.*?--@@END SOURCES", lambda _: block, fix, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(fix)
print("embedded", len(FILES), "sources into", os.path.relpath(FIX, ROOT))
if "--run" in sys.argv:
    args = [sys.executable, os.path.join(HERE, "run_luau.py"), FIX] + (["UNDO"] if "UNDO" in sys.argv else [])
    sys.exit(subprocess.call(args, cwd=ROOT))
