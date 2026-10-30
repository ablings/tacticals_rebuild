#!/bin/sh
# strip.sh <Clip> <side|game> <fps> <gun|-> [left] [t0 t1] -> captures/anim/weapons/<Clip>_<view>_<fps>.png
# fps = samples per second of clip time (15 = the 1x strip, 60 = the 0.25x slow-motion strip: every frame)
H="C:/Users/aroki/Documents/tacticals_rebuild/art/anim/weapons"; D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons"
CAPS="C:/Users/aroki/Documents/tacticals_rebuild/captures/anim/weapons"; mkdir -p "$CAPS"
CLIP=$1; VIEW=$2; FPS=$3; GUN=$4; LEFT=${5:-}; T0=${6:-0}; T1=${7:-}
LEN=$(python -c "import json;print(json.load(open('$D/json/$CLIP.json'))['length'])")
[ -z "$T1" ] && T1=$LEN
python - "$CLIP" "$VIEW" "$FPS" "$GUN" "$LEFT" "$T0" "$T1" > "$D/_strip.lua" <<'PY'
import sys
clip, view, fps, gun, left, t0, t1 = sys.argv[1:8]
fps=float(fps); t0=float(t0); t1=float(t1)
n=int(round((t1-t0)*fps))+1
ts=[round(t0+i/fps,4) for i in range(n)]
g='nil' if gun=='-' else '"%s"'%gun
print('local JOB = {clip="%s", times={%s}, gun=%s, view="%s", left=%s}'%(clip, ",".join(map(str,ts)), g, view, 'true' if left=='left' else 'false'))
PY
cat "$H/studio/strip.lua" >> "$D/_strip.lua"
CAM=$(sh "$H/tools/run.sh" "$D/_strip.lua" Edit "$H/studio/cap_lib.lua" | grep -o "CAM [-0-9. ]*" | head -1)
[ -z "$CAM" ] && { echo "strip failed"; sh "$H/tools/run.sh" "$D/_strip.lua" Edit "$H/studio/cap_lib.lua" | tail -5; exit 1; }
set -- $CAM
ID="${CLIP}_${VIEW}_${FPS}${LEFT:+_L}"
sh "$H/tools/mcp.sh" screen_capture "{\"capture_id\":\"$ID\",\"camera_position\":[$2,$3,$4],\"look_at_position\":[$5,$6,$7]}" > /dev/null
F=$(ls -t "$D"/out/${ID}*.png 2>/dev/null | head -1)
[ -z "$F" ] && F=$(ls -t "$D"/${ID}*.png "$D"/out/*.png 2>/dev/null | head -1)
cp "$F" "$CAPS/$ID.png" && echo "$CAPS/$ID.png"
