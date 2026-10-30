#!/bin/bash
# CPU tiers in solo Play under the background 15 fps cap: bash tools/lagtest/tiers.sh <studio> <pid> <Map|lobby> <Mode> <Q> <out>
S=$1; PID=$2; MAP=$3; MODE=$4; Q=$5; OUT=$6; R="python tools/lagtest/run.py $S"
cd /c/Users/aroki/Documents/tacticals_rebuild
log() { echo "$@" | tee -a $OUT; }
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":true}" >/dev/null; sleep 15
log "=== TIERS $MAP $MODE q$Q $(date +%H:%M:%S)"
$R Client tools/lagtest/sampler.lua MODE=start >/dev/null
if [ "$MAP" != "lobby" ]; then
  $R Server tools/lagtest/tm.lua MAP=$MAP MODE=$MODE VS=bots CMD=start >/dev/null
  for i in $(seq 1 40); do st=$($R Server tools/lagtest/state.lua); case "$st" in Live*) break;; esac; sleep 2; done
fi
$R Client tools/lagtest/setq.lua Q=$Q >/dev/null; sleep 3
for tier in "none 0 0" "tablet 2 60" "midphone 2 30" "lowphone 1 25"; do
  set -- $tier
  [ "$1" != "none" ] && python tools/lagtest/throttle.py $PID $2 $3 >/dev/null
  sleep 3; $R Client tools/lagtest/sampler.lua MODE=mark A=$1 >/dev/null; sleep 10
  log "q$Q cpu-$1 ($2 core(s) at $3%): $(RUN_TIMEOUT=120 $R Client tools/lagtest/sampler.lua MODE=report A=$1)"
done
python tools/lagtest/throttle.py $PID off >/dev/null
$R Client tools/lagtest/setq.lua Q=21 >/dev/null
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":false}" >/dev/null; sleep 4
