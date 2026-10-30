#!/bin/sh
# run.sh <file.lua> [Edit|Server|Client] [prepend.lua ...] -> runs Luau in the anim-body Studio (out/anim_body/studio_id.txt)
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_body"
SID=$(cat "$D/studio_id.txt")
F="$1"; DM=${2:-Edit}; shift; [ $# -gt 0 ] && shift
python - "$F" "$SID" "$DM" "$@" > "$D/_args.json" <<'PY'
import json,sys
pre="".join(open(p,encoding="utf-8").read()+"\n" for p in sys.argv[4:])
src=pre+open(sys.argv[1],encoding="utf-8").read()
print(json.dumps({"code":src,"studio_id":sys.argv[2],"datamodel_type":sys.argv[3]}))
PY
cd "$D" && MCP_TIMEOUT=600 python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call execute_luau "$D/_args.json"
