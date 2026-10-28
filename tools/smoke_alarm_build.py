"""Embed fix/smoke_alarm/*.lua into fix/smoke_alarm.lua (between --@@BEGIN / --@@END SOURCES), and optionally run it.
Usage (from tacticals_rebuild):
  python tools/smoke_alarm_build.py                         embed only
  python tools/smoke_alarm_build.py --run <studio_id> [UNDO]  embed, then run in that Studio's Edit DataModel
Match places and the hub (the installer finds out which). DRY: add DRY to check without writing. Studio ids: python ../roblox_kits/tools/mcpcli.py call list_roblox_studios {}"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
CLI = os.path.join(ROOT, "..", "roblox_kits", "tools", "mcpcli.py")
FIX = os.path.join(ROOT, "fix", "smoke_alarm.lua")
SRC = os.path.join(ROOT, "fix", "smoke_alarm")
FILES = {
    "SmokeAlarm": "SmokeAlarm.lua",
    "SmokeAlarmController": "SmokeAlarmController.lua",
    "AlarmBlock": "ShootableConfig_Alarm.lua",
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
print("embedded", len(FILES), "sources into fix/smoke_alarm.lua")

if "--run" in sys.argv:
    sid = sys.argv[sys.argv.index("--run") + 1]
    code = fix
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
