"""record_hashes.py: read the SourceHash of every published clip from the anim-body Studio (what was uploaded) into
art/anim/body/published_hash.json, so the installer only applies an id while the clip still matches the upload."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from mcpsess import Session
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
pub = json.load(open(os.path.join(ROOT, "art/anim/body/published.json")))
hp = os.path.join(ROOT, "art/anim/body/published_hash.json")
hashes = json.load(open(hp)) if os.path.exists(hp) else {}
s = Session(open(os.path.join(ROOT, "out/anim_body/studio_id.txt")).read().strip())
code = ("local S = game.ReplicatedStorage.Repository.AnimationSources local o = {} for _, n in %s do local k = S:FindFirstChild(n) "
        "o[n] = k and k:GetAttribute('SourceHash') or '' end return game:GetService('HttpService'):JSONEncode(o)") % (
        "{" + ",".join('"%s"' % n for n in pub if n not in hashes) + "}")
r = s.luau(code); s.close()
got = json.loads(json.loads(r) if r.strip().startswith('"') else r)
hashes.update({k: v for k, v in got.items() if v})
json.dump(hashes, open(hp, "w"), indent=1, sort_keys=True)
print(len(hashes), "hashes recorded")
