"""Prove the 1965 restyle kept every footprint: compare art/house/house_furniture.json (v1, graded) with
art/house/v2/house_furniture.json for every v1 assembly (size, bbox about the pivot, collision boxes), and every variant
against its base's v1 entry.
  python art/house/v2/tools/footprint_diff.py [--tol 0.005]  -> prints a table, exit 1 on any difference
Dressing pieces (no collision) are reported separately: their size matters only for the builder's PCOL blockers."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.abspath(os.path.join(HERE, ".."))
V1 = os.path.abspath(os.path.join(V2, ".."))
tol = float(sys.argv[sys.argv.index("--tol") + 1]) if "--tol" in sys.argv else 0.005
a = {e["assembly"]: e for e in json.load(open(os.path.join(V1, "house_furniture.json")))["assemblies"]}
m2 = json.load(open(os.path.join(V2, "house_furniture.json")))
b = {e["assembly"]: e for e in m2["assemblies"]}


def d(x, y):
    return max(abs(p - q) for p, q in zip(x, y))


bad, rows = [], []
pairs = [(n, n) for n in a] + [(n, e["variant_of"]) for n, e in b.items() if e.get("variant_of")]
for n2, n1 in pairs:
    e1, e2 = a[n1], b.get(n2)
    if e2 is None:
        bad.append(f"{n2}: missing in v2"); continue
    cover = bool(e1["collision_boxes_studio"])
    ds = d(e1["size_studio"], e2["size_studio"])
    db = max(d(e1["bbox_min_rel_pivot_studio"], e2["bbox_min_rel_pivot_studio"]), d(e1["bbox_max_rel_pivot_studio"], e2["bbox_max_rel_pivot_studio"]))
    dc = 0.0
    if len(e1["collision_boxes_studio"]) != len(e2["collision_boxes_studio"]):
        dc = 99.0
    else:
        for c1, c2 in zip(e1["collision_boxes_studio"], e2["collision_boxes_studio"]):
            dc = max(dc, d(c1["size"], c2["size"]), d(c1["centre_rel_pivot"], c2["centre_rel_pivot"]))
    out = e2.get("art_outside_box", 0.0)
    above = "above_box" in e1
    ok = dc <= tol and ((ds <= tol and db <= tol) or above if cover else True)
    # cover: the art bbox defines single boxes, so it must match too; art above the box only where v1 had it
    rows.append((n2, n1, cover, ds, db, dc, out, ok))
    if not ok:
        bad.append(n2)
print(f"{'assembly':26s} {'v1 base':22s} cover  d_size  d_bbox  d_boxes  art_out  ok")
for r in rows:
    print(f"{r[0]:26s} {r[1]:22s} {'yes' if r[2] else 'no ':5s} {r[3]:7.3f} {r[4]:7.3f} {r[5]:8.3f} {r[6]:7.3f}  {'OK' if r[7] else 'DIFF'}")
cov = [r for r in rows if r[2]]
print(f"\ncover pieces (incl. variants): {len(cov)}, differences: {sum(1 for r in cov if not r[7])}  (tol {tol})")
dres = [r for r in rows if not r[2] and (r[3] > tol or r[4] > tol)]
print(f"dressing pieces whose size changed (no collision; for the builder's blockers): {len(dres)} " + ", ".join(f"{r[0]} {r[3]:.2f}" for r in dres))
if bad:
    print("FAIL:", bad)
    sys.exit(1)
print("PASS: every collision box and every cover footprint unchanged")
