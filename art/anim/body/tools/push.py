"""push.py <clip> [...]: build out/anim_body/json/<clip>.json into the anim-body Studio (AnimationSources)."""
import json, os, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
J = os.path.join(ROOT, "out", "anim_body", "json")
clips = [json.load(open(os.path.join(J, n + ".json"))) for n in sys.argv[1:]]
for c in clips:  # keep the payload small: drop the quality block
    c.pop("quality", None)
pre = os.path.join(ROOT, "out", "anim_body", "_clips_pre.lua")
with open(pre, "w", encoding="utf-8") as f:
    f.write("local CLIPS_JSON = [==[" + json.dumps(clips) + "]==]\n")
r = subprocess.run(["sh", os.path.join(ROOT, "art/anim/body/tools/run.sh"), os.path.join(ROOT, "art/anim/body/studio/build_clips.lua"),
                    "Edit", pre], capture_output=True, text=True)
out = r.stdout.strip()
try:
    out = json.loads(out)
except Exception:
    pass
print(out, r.stderr[-500:])
