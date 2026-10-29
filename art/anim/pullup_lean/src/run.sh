#!/bin/sh
# run.sh <file.lua> [Edit|Server|Client]  -> executes in my Studio window (anim_pullup_lean.rbxl); --@lib files get lib.lua as L
SID=8fab1250-ec8f-41de-95d4-67bba4221d0a
DM=${2:-Edit}
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_pullup_lean"
python - "$1" "$SID" "$DM" "$D/lua/lib.lua" > "$D/_args.json" <<'PY'
import json,sys
src=open(sys.argv[1],encoding="utf-8").read()
if src.startswith("--@lib"):
    src="local L = (function()\n"+open(sys.argv[4],encoding="utf-8").read()+"\nend)()\n"+src
print(json.dumps({"code":src,"studio_id":sys.argv[2],"datamodel_type":sys.argv[3]}))
PY
cd "$D" && python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call execute_luau "$D/_args.json"
