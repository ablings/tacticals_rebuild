"""record_hashes.py: read the SourceHash of every published clip from MY Studio (what was uploaded) into
art/anim/reload_variants/published_hash.json, so gen_install.py only applies an id while the clip still matches the upload."""
import json, os, subprocess
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(H, "..", "..", "..", "out", "anim_reload_variants")
pub = json.load(open(os.path.join(H, "published.json")))
hp = os.path.join(H, "published_hash.json")
hashes = json.load(open(hp)) if os.path.exists(hp) else {}
lua = ("local S = game.ReplicatedStorage.Repository.AnimationSources local o = {} for _, n in %s do local k = S:FindFirstChild(n) "
       "o[n] = k and k:GetAttribute('SourceHash') or '' end return game:GetService('HttpService'):JSONEncode(o)") % (
       "{" + ",".join('"%s"' % n for n in pub if n not in hashes) + "}")
f = os.path.join(D, "_rh.lua"); open(f, "w").write(lua)
out = subprocess.run(["sh", os.path.join(H, "tools", "run.sh"), f, "Edit"], capture_output=True, text=True).stdout.strip()
got = json.loads(out[out.index("{"):out.rindex("}") + 1])
hashes.update({k: v for k, v in got.items() if v})
json.dump(hashes, open(hp, "w"), indent=1, sort_keys=True)
print(len(hashes), "hashes recorded")
