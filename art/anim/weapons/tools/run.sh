#!/bin/sh
# run.sh <file.lua> [Edit|Server|Client] [prepend.lua ...] -> runs Luau in MY Studio (id in out/anim_weapons/studio_id.txt)
# cap_lib.lua is wrapped as `local C = (function() ... end)()`.
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons"
SID=$(cat "$D/studio_id.txt")
F="$1"; DM=${2:-Edit}; shift; [ $# -gt 0 ] && shift
python "C:/Users/aroki/Documents/tacticals_rebuild/art/anim/weapons/tools/mkargs.py" "$F" "$SID" "$DM" "$@" > "$D/_args.json"
cd "$D" && MCP_TIMEOUT=600 python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call execute_luau "$D/_args.json"
