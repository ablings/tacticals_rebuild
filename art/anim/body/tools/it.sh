#!/bin/sh
# it.sh <set> <clip[,clip...]> : build in Blender, push to Studio (incl. mirrors listed by the set)
cd /c/Users/aroki/Documents/tacticals_rebuild
SET=$1; CL=$(echo "$2" | tr ',' ' ')
"/c/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b art/anim/rig/Starter_Blocky_Rig.blend --python art/anim/body/blender/make_body.py -- $SET $CL 2>&1 | grep -E "EXPORTED|Error|Traceback|line [0-9]" 
NAMES=$(ls -t out/anim_body/json/*.json | head -40 | xargs -n1 basename | sed 's/.json$//' )
python - "$SET" $CL <<'PY'
import sys, json, os, subprocess, time
setname, clips = sys.argv[1], sys.argv[2:]
J = "out/anim_body/json"
names = []
for c in clips:
    names.append(c)
    # mirrors written in the same build
for f in os.listdir(J):
    d = json.load(open(os.path.join(J, f)))
    src = d["attrs"]["Source"]
    if any(src.endswith("(%s)" % c) for c in clips) and d["name"] not in names and time.time() - os.path.getmtime(os.path.join(J, f)) < 600:
        names.append(d["name"])
r = subprocess.run([sys.executable, "art/anim/body/tools/push.py"] + names, capture_output=True, text=True)
print(r.stdout.strip(), r.stderr[-300:])
PY
