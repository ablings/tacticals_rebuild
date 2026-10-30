#!/bin/sh
# publoop.sh: rerun puball.sh after stops caused by windows / timing; halt for good on group or verification problems
cd "$(dirname "$0")"
trap "MY_STUDIO_PID=55668 powershell -NoProfile -ExecutionPolicy Bypass -File desk.ps1 frontdlg anim_weapons.rbxl unpin > /dev/null 2>&1" EXIT
for i in $(seq 1 25); do
  sh puball.sh && exit 0
  grep -q "NOT VERIFIED\|not gunsy\|no id copied\|Traceback" _last.txt && { echo "HARD STOP"; exit 1; }
  export MY_STUDIO_PID=55668
  [ "$(powershell -NoProfile -ExecutionPolicy Bypass -File desk.ps1 rect 'Asset Configuration')" != "none" ] && { echo "HARD STOP: dialog open"; exit 1; }
  sleep 5
done
