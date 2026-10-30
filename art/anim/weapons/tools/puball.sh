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
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1" stage -place anim_weapons.rbxl > /dev/null 2>&1
  B=""; for i in 1 2 3 4 5 6; do [ $# -gt 0 ] && { B="$B $1"; shift; }; done
  python pub.py $B > _last.txt 2>&1; cat _last.txt
  grep -q "STOP\|Traceback" _last.txt && { echo STOPPED; exit 1; }
done
echo PUBALLDONE
