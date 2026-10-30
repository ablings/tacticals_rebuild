"""prints the DONE.md clip table from out/anim_reload_variants/json (right-hand clips; ...Left mirrors share every value)"""
import json, glob, os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "out", "anim_reload_variants", "json")
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "published.json")
pub = json.load(open(P)) if os.path.exists(P) else {}
print("| Clip (+Left) | Rounds left | Length | Base it replaces | Markers (s) | Published id | Grade |")
print("|---|---|---|---|---|---|---|")
for p in sorted(glob.glob(D + "/*.json")):
    c = json.load(open(p))
    if c["attrs"].get("Mirrored"): continue
    ms = ", ".join("%s %.3f%s" % (m["name"], m["t"], (" (" + m["value"] + ")") if m.get("value") else "") for m in sorted(c["markers"], key=lambda m: m["t"]))
    n = c["name"]
    print("| %s | %s | %.3f | %s | %s | %s | pending (HQ grader) |" % (n, c["attrs"].get("RoundsLeft", ""), c["length"], c["attrs"].get("BaseReload", ""),
          ms or "-", pub.get(n, "ready to publish") + (" / L " + pub[n + "Left"] if n + "Left" in pub else "")))
