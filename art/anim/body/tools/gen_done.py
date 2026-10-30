"""gen_done.py: writes art/anim/body/DONE.md from clips.txt, out/anim_body/json, published.json and grades.json."""
import json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
B = os.path.join(ROOT, "art/anim/body")
names = [l.strip() for l in open(os.path.join(B, "clips.txt")) if l.strip() and not l.startswith("#")]
pub = json.load(open(os.path.join(B, "published.json"))) if os.path.exists(os.path.join(B, "published.json")) else {}
gr = json.load(open(os.path.join(B, "grades.json")))
rows = []
for n in names:
    d = json.load(open(os.path.join(ROOT, "out/anim_body/json", n + ".json")))
    mk = ", ".join("%s %.3f" % (m["name"], m["t"]) for m in d["markers"]) or "-"
    rows.append("| %s | %s | %.2f | %s | %s | %s | %s |" % (n, pub.get(n, "ready to publish"), d["length"], "yes" if d["loop"] else "no",
                                                        d["priority"], mk, gr.get(n, "-")))
out = ["# Body / movement animations: DONE (anim-body, 2026-10-30)", "",
       "Final body set on the Starter Blocky rig (Blender -> JSON -> KeyframeSequences), style Grounded Tactical. Source of every",
       "clip: `art/anim/body/blender/clips/b1_cover.py .. b5_life.py`; install all sources (with PublishedId) by running",
       "`art/anim/body/install_sources.lua` in Studio (Edit mode). Published under the group **gunsy funsy** (102028987),",
       "each id read back from economy.roblox.com (AssetType 24, Creator group). Code wiring: `art/anim/body/HANDOFF_systems.md`.",
       "", "Batch grades (roblox-animation-grader, xhigh; pass 8.0, max 4 rounds): " + "; ".join("%s %s" % kv for kv in gr["_batches"].items()), "",
       "| Clip | Id | Len | Loop | Priority | Markers (s) | Grade |", "|---|---|---|---|---|---|---|"] + rows
open(os.path.join(B, "DONE.md"), "w").write("\n".join(out) + "\n")
print(len(rows), "rows,", sum(1 for n in names if n in pub), "published")
