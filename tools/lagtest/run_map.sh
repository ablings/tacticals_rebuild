#!/bin/bash
# one solo Play run of a Test-place map: bash tools/lagtest/run_map.sh <studio> <Map> <1v1|3v3> <outfile>
S=$1; MAP=$2; MODE=$3; OUT=$4; R="python tools/lagtest/run.py $S"
cd /c/Users/aroki/Documents/tacticals_rebuild
log() { echo "$@" | tee -a $OUT; }
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":true}" >/dev/null
sleep 12
log "=== $MAP $MODE $(date +%H:%M:%S)"
$R Client tools/lagtest/sampler.lua MODE=start >/dev/null
$R Client tools/lagtest/sampler.lua MODE=mark A=start >/dev/null
log "start: $($R Server tools/lagtest/tm.lua MAP=$MAP MODE=$MODE VS=bots CMD=start)"
for i in $(seq 1 40); do st=$($R Server tools/lagtest/state.lua); case "$st" in Live*) break;; esac; sleep 2; done
$R Client tools/lagtest/sampler.lua MODE=mark A=live >/dev/null
log "state: $st"
log "frames start->live: $($R Client tools/lagtest/sampler.lua MODE=report A=start B=live)"
sleep 3
log "server: $($R Server tools/lagtest/snap_server.lua LABEL=$MAP-$MODE)"
log "client: $($R Client tools/lagtest/snap_client.lua LABEL=$MAP-$MODE)"
log "$(RUN_TIMEOUT=300 $R Client tools/lagtest/render_sweep.lua CAMS=here LEVELS=1,3,5,10,21 HOLD=2.5)"
# effects
$R Server tools/lagtest/fx_server.lua ACT=arm:Frag >/dev/null
$R Client tools/lagtest/sampler.lua MODE=mark A=fx0 >/dev/null
$R Client tools/lagtest/fx_client.lua GADGET=Frag POW=0.5 AT= TP= >/dev/null
sleep 3.5
log "frag: $($R Client tools/lagtest/sampler.lua MODE=report A=fx0)"
case $MAP in
  Warehouse|Warehouse2) $R Client tools/lagtest/sampler.lua MODE=mark A=fx1 >/dev/null
     log "steam: $($R Server tools/lagtest/fx_server.lua ACT=steam:$MAP)"; log "barrels: $($R Server tools/lagtest/fx_server.lua ACT=barrels:$MAP)"; sleep 4
     log "steam window: $($R Client tools/lagtest/sampler.lua MODE=report A=fx1)";;
  House) $R Client tools/lagtest/sampler.lua MODE=mark A=fx1 >/dev/null
     log "glass: $($R Server tools/lagtest/fx_server.lua ACT=glass:House:10 | cut -c1-120)"; sleep 3
     log "glass window: $($R Client tools/lagtest/sampler.lua MODE=report A=fx1)";;
esac
$R Server tools/lagtest/fx_server.lua ACT=arm:Smoke >/dev/null
$R Client tools/lagtest/sampler.lua MODE=mark A=fx2 >/dev/null
$R Client tools/lagtest/fx_client.lua GADGET=Smoke POW=0.4 AT= TP= >/dev/null; sleep 4
log "smoke: $($R Client tools/lagtest/sampler.lua MODE=report A=fx2)"
log "client after fx: $($R Client tools/lagtest/snap_client.lua LABEL=$MAP-$MODE-fx)"
log "server after fx: $($R Server tools/lagtest/snap_server.lua LABEL=$MAP-$MODE-fx)"
python ../roblox_kits/tools/mcpcli.py call start_stop_play "{\"studio_id\":\"$S\",\"is_start\":false}" >/dev/null
sleep 4
