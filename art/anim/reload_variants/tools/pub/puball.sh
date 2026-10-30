#!/bin/sh
# puball.sh <list.txt>: publish every clip in the list not yet in art/anim/reload_variants/published.json, holding the screen stage for
# 6 clips at a time; stops on the first problem (copied from the weapons animator's proven loop, anim-body paths).
cd "$(dirname "$0")"
export MY_STUDIO_PID=$(pwsh -NoProfile -Command "(Get-Process RobloxStudioBeta | Where-Object { \$_.MainWindowTitle -like '*anim_reload_variants*' }).Id")
LIST="$1"
L=$(python -c "
import json, os, sys
p='../../published.json'
pub=json.load(open(p)) if os.path.exists(p) else {}
names=[l.strip() for l in open(sys.argv[1]) if l.strip() and not l.startswith('#')]
print(' '.join(n for n in names if n not in pub))" "$LIST")
set -- $L
while [ $# -gt 0 ]; do
  until pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1" stage -place anim_reload_variants.rbxl -wait 2 2>&1 | grep -q "^stage: '"; do
    echo "waiting for the stage $(date +%T)"; sleep 15
  done
  B=""; for i in 1 2 3 4 5 6; do [ $# -gt 0 ] && { B="$B $1"; shift; }; done
  python pub.py $B > _last.txt 2>&1; cat _last.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File desk.ps1 frontdlg anim_reload_variants.rbxl unpin > /dev/null 2>&1
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1" release -place anim_reload_variants.rbxl > /dev/null 2>&1
  grep -q "STOP\|Traceback\|Error" _last.txt && { echo STOPPED; exit 1; }
  sleep 20
done
echo PUBALLDONE
