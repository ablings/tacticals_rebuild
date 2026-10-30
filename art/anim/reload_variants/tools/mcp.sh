#!/bin/sh
T="C:/Users/aroki/Documents/tacticals_rebuild/art/anim/reload_variants"
# mcp.sh <tool> '<json args without studio_id>' -> calls a Studio MCP tool on MY Studio
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_reload_variants"
SID=$(cat "$D/studio_id.txt")
python -c "import json,sys; a=json.loads(sys.argv[1]); a['studio_id']=sys.argv[2]; print(json.dumps(a))" "$2" "$SID" > "$D/_mcp.json"
cd "$D" && python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call "$1" "$D/_mcp.json"
