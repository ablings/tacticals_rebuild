#!/bin/bash
# open a place file in Studio, run fix/perf_settings_1030.lua, run it again (must be all "="), print the state. Usage: <file.rbxl>
cd /c/Users/aroki/Documents/tacticals_rebuild
F=$1; N=$(basename $F)
pwsh -NoProfile -Command "Start-Process '$(cygpath -w $PWD/$F)'" 
for i in $(seq 1 40); do sleep 5; ID=$(python ../roblox_kits/tools/mcpcli.py call list_roblox_studios '{}' | python -c "import sys,json;t=sys.stdin.read();d=json.loads(t[t.index('{'):]);print(next((s['id'] for s in d['studios'] if s['name']=='$N'),''))"); [ -n "$ID" ] && break; done
echo "studio $ID"
sleep 8
R="python tools/lagtest/run.py $ID Edit"
echo "before: $($R tools/perf_settings_hash.lua)"
echo "install: $($R fix/perf_settings_1030.lua | tr '\n' ' ')"
echo "rerun: $($R fix/perf_settings_1030.lua | tr '\n' ' ')"
echo "after: $($R tools/perf_settings_hash.lua)"
