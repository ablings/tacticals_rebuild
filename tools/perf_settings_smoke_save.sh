#!/bin/bash
# Play smoke ([PERFSET] rows + restore + console), then stage + Ctrl+S. Usage: <studio id> <file.rbxl>
cd /c/Users/aroki/Documents/tacticals_rebuild
S=$1; F=$2
python tools/play_lock.py take lagtest >/dev/null
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":true}" >/dev/null; sleep 25
echo "smoke: $(python tools/lagtest/run.py $S Client tools/perf_settings_smoke.lua)"
echo "console errors: $(python ../roblox_kits/tools/mcpcli.py call get_console_output "{\"studio_id\":\"$S\"}" | grep -i -E "error|stack|traceback" | grep -v -i "permission to use asset\|proxy register\|HttpError\|DataStore\|studio access to API" | head -5)"
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":false}" >/dev/null; sleep 3
python tools/play_lock.py release lagtest >/dev/null
pwsh -NoProfile -ExecutionPolicy Bypass -File ../roblox_kits/tools/screen.ps1 stage -place $F -wait 8 | tail -1 | cut -c1-60
before=$(stat -c %Y $F)
# Studio's "Auto Recovery File Found" dialog (a RobloxStudio window ~366 x 190) blocks Ctrl+S: answer Ignore (keep the file as committed)
python tools/studio_recovery_ignore.py $F
sleep 2
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/save_studio.ps1 "$F" 2>&1 | tail -1; sleep 8
[ "$(stat -c %Y $F)" != "$before" ] && echo "SAVED $F" || { echo "NOT SAVED"; python out/port51/clk.py shot out/port52/notsaved.png; }
pwsh -NoProfile -ExecutionPolicy Bypass -File ../roblox_kits/tools/screen.ps1 release -place $F | tail -1
