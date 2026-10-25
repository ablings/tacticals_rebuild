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
case "$KIND" in
  Matchmaking) PYTHONIOENCODING=utf-8 python ui/deploy_ui.py "$ID" --matchmaking 2>&1 | tail -1 ;;
  Ranked) PYTHONIOENCODING=utf-8 python ui/deploy_ui.py "$ID" --ranked 2>&1 | tail -1 ;;
esac
# [PLAYQUEUE] (2026-10-25) Play Again queues from the match server (MatchmakingManager in the match places + RoundManager edits)
case "$KIND" in
  Matchmaking|Ranked) python tools/run_luau_at.py "$ID" fix/play_again_queue.lua ;;
esac
python tools/run_luau_at.py "$ID" out/v.lua
python tools/run_luau_at.py "$ID" out/v2.lua
$PS -File tools/save_studio.ps1 "\\${KIND}_place.rbxl"
$PS -File tools/bring_primary.ps1 "\\${KIND}_place.rbxl" $BRING_ARGS
