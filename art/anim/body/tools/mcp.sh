#!/bin/sh
# mcp.sh <tool> '<json args without studio_id>' -> a Studio MCP tool on the anim-body Studio
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_body"
SID=$(cat "$D/studio_id.txt")
python -c "import json,sys; a=json.loads(sys.argv[1]); a['studio_id']=sys.argv[2]; print(json.dumps(a))" "$2" "$SID" > "$D/_mcp.json"
cd "$D" && python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call "$1" "$D/_mcp.json"
