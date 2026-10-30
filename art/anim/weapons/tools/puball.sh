#!/bin/sh
# puball.sh: publish every clip not yet in published.json, renewing the stage every 6 clips; stops on the first problem
cd "$(dirname "$0")"
export MY_STUDIO_PID=55668
L=$(python -c "
import json
pub=json.load(open('../published.json'))
names=[l.strip() for l in open('../../../../out/anim_weapons/_all.txt') if l.strip()]
print(' '.join(n for n in names if n not in pub))")
set -- $L
while [ $# -gt 0 ]; do
  until pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1" stage -place anim_weapons.rbxl -wait 2 2>&1 | grep -q "^stage: '"; do
    echo "waiting for the stage $(date +%T)"; sleep 15
  done
  B=""; for i in 1 2 3 4 5 6; do [ $# -gt 0 ] && { B="$B $1"; shift; }; done
  python pub.py $B > _last.txt 2>&1; cat _last.txt
  MY_STUDIO_PID=55668 powershell -NoProfile -ExecutionPolicy Bypass -File desk.ps1 frontdlg anim_weapons.rbxl unpin > /dev/null 2>&1
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1" release -place anim_weapons.rbxl > /dev/null 2>&1
  grep -q "STOP\|Traceback" _last.txt && { echo STOPPED; exit 1; }
  sleep 20   # a gap so other agents waiting for the stage get it
done
echo PUBALLDONE
