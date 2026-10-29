#!/bin/sh
# MOVE1029 port build: tools/port_prep.sh's steps, but the UI deploy from ui as of f714708e~1 (= live; f714708e is ungraded),
# then the MOVE1029 installers again (a UI deploy may rewrite controllers they edit). Usage: port_build.sh <Tutorial|Matchmaking|Ranked>
set -e
KIND="$1"
cd /c/Users/aroki/Documents/tacticals_rebuild
cp match_place_ref.rbxl ${KIND}_place.rbxl
WINP="C:/Users/aroki/Documents/tacticals_rebuild/${KIND}_place.rbxl"; powershell.exe -NoProfile -Command "Start-Process $WINP"
CLI=/c/Users/aroki/Documents/rivals_practice/mcpcli.py
until PYTHONIOENCODING=utf-8 python $CLI call list_roblox_studios '{}' 2>/dev/null | grep -q "\"${KIND}_place.rbxl\""; do sleep 3; done
ID=$(PYTHONIOENCODING=utf-8 python $CLI call list_roblox_studios '{}' | python -c "import json,sys; print([s['id'] for s in json.load(sys.stdin)['studios'] if s['name']=='${KIND}_place.rbxl'][0])")
echo "id $ID"; echo $ID > out/move_rework/sid_$KIND.txt
sleep 5
PYTHONIOENCODING=utf-8 python tools/split_build.py place "$ID" "$KIND" 2>&1 | grep -E "^after|PlaceKind =" || true
case "$KIND" in
  Matchmaking) PYTHONIOENCODING=utf-8 python out/move_rework/ui_prev/ui/deploy_ui.py "$ID" --matchmaking 2>&1 | tail -1 ;;
  Ranked) PYTHONIOENCODING=utf-8 python out/move_rework/ui_prev/ui/deploy_ui.py "$ID" --ranked 2>&1 | tail -1 ;;
esac
# the UI deploy puts back the [SET] controllers without fix/breakable_glass.lua's client edits (Cover: stop at a window barrier,
# Camera: barriers aren't camera blockers): live ports 47/48 lost them that way. Re-apply (idempotent, re-adds only those)
case "$KIND" in
  Matchmaking|Ranked) python tools/run_luau_at.py "$ID" fix/breakable_glass.lua | cut -c1-200 ;;
esac
case "$KIND" in
  Matchmaking|Ranked) python tools/run_luau_at.py "$ID" fix/play_again_queue.lua | cut -c1-150 ;;
esac
python tools/run_luau_at.py "$ID" fix/switch_now.lua | cut -c1-150
for f in fix/move_rework_1029.lua fix/move_rework_1029_tests.lua fix/noclimb_1029.lua art/anim/pullup_lean/install_sources.lua; do python tools/run_luau_at.py "$ID" $f | cut -c1-200; done
python tools/run_luau_at.py "$ID" out/v.lua
python tools/run_luau_at.py "$ID" out/v2.lua
