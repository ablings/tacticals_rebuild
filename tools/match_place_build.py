"""Embed the match place sources into fix/match_place_install.lua (between --@@BEGIN SOURCES / --@@END SOURCES).
Usage (from tacticals_rebuild): python tools/match_place_build.py [--run] [UNDO]
  --run  also runs the install in match_place_ref.rbxl (studio id below; ids change on reload: list_roblox_studios).
Shared files (scripts/duels/*) are the same ones the lobby installer embeds: after changing one, rebuild BOTH installers
(tools/lobby_duels_build.py --run, then tools/admin_build.py --run in the lobby) and this one."""
import json, os, re, subprocess, sys, tempfile

SID = "331cb3a0-87e8-4413-ac74-1ffd00454ce2"  # match_place_ref.rbxl
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
FIX = os.path.join(ROOT, "fix", "match_place_install.lua")
FILES = {  # SOURCES key -> file (relative to scripts/)
    "MapRegistry": "duels/MapRegistry.lua",
    "MatchState": "duels/MatchState.lua",
    "MatchCore": "duels/MatchCore.lua",
    "MatchConfig": "duels/MatchConfig.lua",
    "RoundManager": "match/RoundManager.lua",
    "LobbyConfig": "match/LobbyConfig.lua",
    "MapInfo_Warehouse": "match/MapInfo_Warehouse.lua",
    "Admin_Config": "admin/Config.lua",
    "Admin_Permissions": "admin/Permissions.lua",
    "Admin_Args": "admin/Args.lua",
    "Admin_DataAdapter": "admin/DataAdapter.lua",
    "Admin_Audit": "admin/Audit.lua",
    "Admin_Core": "admin/Core.lua",
    "Cmd_Data": "admin/Commands/Data.lua",
    "Cmd_Player": "admin/Commands/Player.lua",
    "Cmd_Duel": "admin/Commands/Duel.lua",
    "Cmd_World": "admin/Commands/World.lua",
    "Cmd_Debug": "admin/Commands/Debug.lua",
    "Cmd_Legacy": "admin/Commands/Legacy.lua",
    "AdminCommands": "admin/AdminCommands.server.lua",
    "AdminFeedback": "admin/AdminFeedback.client.lua",
}


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


lines = []
for key, fn in FILES.items():
    src = open(os.path.join(ROOT, "scripts", fn), encoding="utf-8").read()
    lines.append(f"SOURCES.{key} = {long_string(src)}")
block = "--@@BEGIN SOURCES\n" + "\n".join(lines) + "\n--@@END SOURCES"
fix = open(FIX, encoding="utf-8").read()
fix = re.sub(r"--@@BEGIN SOURCES.*?--@@END SOURCES", lambda _: block, fix, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(fix)
print("embedded", len(FILES), "sources into", os.path.relpath(FIX, ROOT))
if "--run" in sys.argv:
    code = fix
    if "UNDO" in sys.argv[1:]:
        code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    print(r.stdout); print(r.stderr[-2000:], file=sys.stderr); os.remove(path); sys.exit(r.returncode)
