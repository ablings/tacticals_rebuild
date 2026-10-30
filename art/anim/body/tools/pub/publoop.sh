#!/bin/sh
# publoop.sh <list>: rerun puball.sh after stops caused by windows / timing; halt for good on group / verification problems
cd "$(dirname "$0")"
export MY_STUDIO_PID=$(pwsh -NoProfile -Command "(Get-Process RobloxStudioBeta | Where-Object { \$_.MainWindowTitle -like '*anim_body*' }).Id")
for i in $(seq 1 30); do
  sh puball.sh "$1" && exit 0
  grep -q "NOT VERIFIED\|not gunsy\|no id copied\|Traceback" _last.txt && { echo "HARD STOP"; exit 1; }
  for t in "Convert To Package" "Asset Configuration"; do
    [ "$(powershell -NoProfile -ExecutionPolicy Bypass -File desk.ps1 rect "$t")" != "none" ] && { echo "HARD STOP: dialog open ($t)"; exit 1; }
  done
  sleep 5
done
