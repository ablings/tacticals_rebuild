"""verify_hashes.py: every clip in art/anim/body/clips.txt: Studio AnimationSources SourceHash == out/anim_body/json hash?
Prints the mismatches and pushes them with --fix."""
import json, os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from mcpsess import Session
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
names = [l.strip() for l in open(os.path.join(ROOT, "art/anim/body/clips.txt")) if l.strip() and not l.startswith("#")]
want = {n: json.load(open(os.path.join(ROOT, "out/anim_body/json", n + ".json")))["attrs"]["SourceHash"] for n in names}
s = Session(open(os.path.join(ROOT, "out/anim_body/studio_id.txt")).read().strip())
r = s.luau("local S = game.ReplicatedStorage.Repository.AnimationSources local o = {} for _, k in S:GetChildren() do "
           "o[k.Name] = tostring(k:GetAttribute('SourceHash')) end return game:GetService('HttpService'):JSONEncode(o)")
s.close()
have = json.loads(json.loads(r) if r.strip().startswith('"') else r)
bad = [n for n in names if have.get(n) != want[n]]
print(len(names), "clips,", len(bad), "mismatched:", bad)
if bad and "--fix" in sys.argv:
    for i in range(0, len(bad), 6):
        print(subprocess.run([sys.executable, os.path.join(HERE, "push.py")] + bad[i:i + 6], capture_output=True, text=True).stdout[-300:])
