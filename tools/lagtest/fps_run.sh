#!/bin/bash
# staged FPS run: bash tools/lagtest/fps_run.sh <studio> <pid> <Map> <Mode> <out>   (Play must be stopped; the window on the stage)
S=$1; PID=$2; MAP=$3; MODE=$4; OUT=$5; R="python tools/lagtest/run.py $S"
cd /c/Users/aroki/Documents/tacticals_rebuild
log() { echo "$@" | tee -a $OUT; }
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":true}" >/dev/null; sleep 12
log "=== FPS $MAP $MODE $(date +%H:%M:%S)"
$R Client tools/lagtest/sampler.lua MODE=start >/dev/null; $R Client tools/lagtest/sampler.lua MODE=mark A=start >/dev/null
$R Server tools/lagtest/tm.lua MAP=$MAP MODE=$MODE VS=bots CMD=start >/dev/null
for i in $(seq 1 40); do st=$($R Server tools/lagtest/state.lua); case "$st" in Live*) break;; esac; sleep 2; done
$R Client tools/lagtest/sampler.lua MODE=mark A=live >/dev/null
log "start->live: $($R Client tools/lagtest/sampler.lua MODE=report A=start B=live)"
for q in 1 3 5 10 21; do
  $R Client tools/lagtest/setq.lua Q=$q >/dev/null; sleep 2
  $R Client tools/lagtest/sampler.lua MODE=mark A=q$q >/dev/null; sleep 8
  log "q$q: $($R Client tools/lagtest/sampler.lua MODE=report A=q$q) || $($R Client tools/lagtest/fps_line.lua)"
done
$R Server tools/lagtest/fx_server.lua ACT=arm:Frag >/dev/null
$R Client tools/lagtest/sampler.lua MODE=mark A=frag >/dev/null; $R Client tools/lagtest/fx_client.lua GADGET=Frag POW=0.5 AT= TP= >/dev/null; sleep 4
log "q21 frag: $($R Client tools/lagtest/sampler.lua MODE=report A=frag)"
$R Client tools/lagtest/setq.lua Q=1 >/dev/null
for tier in "lowphone 1 25" "midphone 2 30" "tablet 2 60"; do
  set -- $tier
  python tools/lagtest/throttle.py $PID $2 $3 >/dev/null; sleep 2
  $R Client tools/lagtest/sampler.lua MODE=mark A=$1 >/dev/null; sleep 8
  log "q1 cpu-$1 ($2 core(s) at $3%): $($R Client tools/lagtest/sampler.lua MODE=report A=$1)"
  $R Server tools/lagtest/fx_server.lua ACT=arm:Frag >/dev/null
  $R Client tools/lagtest/sampler.lua MODE=mark A=f$1 >/dev/null; $R Client tools/lagtest/fx_client.lua GADGET=Frag POW=0.5 AT= TP= >/dev/null; sleep 4
  log "   frag under $1: $($R Client tools/lagtest/sampler.lua MODE=report A=f$1)"
done
python tools/lagtest/throttle.py $PID off >/dev/null
$R Client tools/lagtest/setq.lua Q=21 >/dev/null
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":false}" >/dev/null; sleep 4
