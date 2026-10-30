#!/bin/sh
# Port helper: close the previous published window, open <Kind>_place.rbxl, split_build it, run the UI's match deploy
# (Matchmaking / Ranked), verify, save, bring it to the primary monitor. Then do Publish As by hand (computer use).
# Usage: tools/port_prep.sh <Tutorial|Matchmaking|Ranked> [previous window title, e.g. "tacticals"]
set -e
KIND="$1"; PREV="$2"
cd /c/Users/aroki/Documents/tacticals_rebuild
PS="powershell.exe -NoProfile -ExecutionPolicy Bypass"
if [ -n "$PREV" ]; then
  $PS -Command "Get-Process RobloxStudioBeta | Where-Object { \$_.MainWindowTitle -like '$PREV - Roblox Studio*' } | Stop-Process -Force"
  sleep 3
fi
$PS -Command "Start-Process 'C:\Users\aroki\Documents\tacticals_rebuild\\${KIND}_place.rbxl'"
CLI=/c/Users/aroki/Documents/rivals_practice/mcpcli.py
until PYTHONIOENCODING=utf-8 python $CLI call list_roblox_studios '{}' 2>/dev/null | grep -q "${KIND}_place"; do sleep 3; done
ID=$(PYTHONIOENCODING=utf-8 python $CLI call list_roblox_studios '{}' | python -c "import json,sys; print([s['id'] for s in json.load(sys.stdin)['studios'] if s['name']=='${KIND}_place.rbxl'][0])")
echo "id $ID"
sleep 5
PYTHONIOENCODING=utf-8 python tools/split_build.py place "$ID" "$KIND" 2>&1 | grep -E "^after|PlaceKind =" || true
# [PORT51] (2026-10-30) the whole-file UI deploy runs from ui/ as of f714708e~1 (= what live ports 47-51 shipped). ui/ after it holds
# the UI survey r2 sources, which are to ship as anchor edits (fix/ui_survey_r2.lua; not live yet): today's ui/ copies are behind the
# places and would roll back other installers' edits (that is how live ports 47/48 lost the [GLASS] client edits).
UIPREV=out/ui_prev_f714708e; [ -f $UIPREV/ui/deploy_ui.py ] || { mkdir -p $UIPREV; git archive f714708e~1 ui | tar -x -C $UIPREV; }
case "$KIND" in
  Matchmaking) PYTHONIOENCODING=utf-8 python $UIPREV/ui/deploy_ui.py "$ID" --matchmaking 2>&1 | tail -1 ;;
  Ranked) PYTHONIOENCODING=utf-8 python $UIPREV/ui/deploy_ui.py "$ID" --ranked 2>&1 | tail -1 ;;
esac
# the deploy puts back [SET] controllers without fix/breakable_glass.lua's client edits: re-apply (idempotent, re-adds only those)
case "$KIND" in
  Matchmaking|Ranked) python tools/run_luau_at.py "$ID" fix/breakable_glass.lua | cut -c1-200 ;;
esac
# [PLAYQUEUE] (2026-10-25) Play Again queues from the match server (MatchmakingManager in the match places + RoundManager edits)
case "$KIND" in
  Matchmaking|Ranked) python tools/run_luau_at.py "$ID" fix/play_again_queue.lua ;;
esac
# [SWITCHNOW] (2026-10-25) Switch Weapons sessions: picks always swap at once, no fighting while switching (every match kind)
python tools/run_luau_at.py "$ID" fix/switch_now.lua
# [SURVEY1025] security + data (round 2, split places only), live since port 51. Idempotent (a second run changes nothing).
# [MOVE1029] is NOT live (port 51 grade FIX 7.9): for the port that ships it, add before SURVEY1025:
#   fix/move_rework_1029.lua fix/move_rework_1029_tests.lua fix/move1029_r5.lua fix/noclimb_1029.lua art/anim/pullup_lean/install_sources.lua
# UI survey r2 (fix/ui_survey_r2.lua) is NOT live either (UI grade FIX 7.3): add it LAST once it passes.
for f in fix/survey1025_security.lua fix/survey1025_data.lua; do python tools/run_luau_at.py "$ID" $f | cut -c1-200; done
PYTHONIOENCODING=utf-8 python tools/ranked_test.py --survey1025 "$ID" 2>&1 | grep -E "passed|failed" | tail -1
python tools/run_luau_at.py "$ID" tools/port_readback.lua
python tools/run_luau_at.py "$ID" out/v.lua
python tools/run_luau_at.py "$ID" out/v2.lua
$PS -File tools/save_studio.ps1 "\\${KIND}_place.rbxl"
$PS -File tools/bring_primary.ps1 "\\${KIND}_place.rbxl" $BRING_ARGS
