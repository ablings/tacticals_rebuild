#!/bin/sh
# install.sh <Clip> [<Clip> ...] -> builds those KeyframeSequences (from out/anim_weapons/json) into MY Studio
D="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons"
H="C:/Users/aroki/Documents/tacticals_rebuild/art/anim/weapons"
python - "$D" "$@" > "$D/_install.lua" <<'PY'
import json, sys, os
d = sys.argv[1]
clips = [json.load(open(os.path.join(d, "json", n + ".json"))) for n in sys.argv[2:]]
for c in clips:
    c.pop("quality", None); c.pop("nkeys", None)
print("local CLIPS_JSON = [==[" + json.dumps(clips) + "]==]")
PY
cat "$H/studio/build_clips.lua" >> "$D/_install.lua"
sh "$H/tools/run.sh" "$D/_install.lua" Edit
