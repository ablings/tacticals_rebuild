#!/bin/sh
# cap.sh <capture_id> cx cy cz lx ly lz  (positions relative to stage origin 0,800,0)
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_pullup_lean"
python - "$@" > "$D/_cap.json" <<'PY'
import json,sys
a=sys.argv[1:]; f=[float(x) for x in a[1:]]
print(json.dumps({"capture_id":a[0],"studio_id":"8fab1250-ec8f-41de-95d4-67bba4221d0a","camera_position":[f[0],f[1]+800,f[2]],"look_at_position":[f[3],f[4]+800,f[5]]}))
PY
cd "$D" && python "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py" call screen_capture "$D/_cap.json" | tail -1
