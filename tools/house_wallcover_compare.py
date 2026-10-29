"""[WALLCOVER1029] Cover distance on House with and without wall cover (READ-ONLY, no Studio). Uses the checker's cached
standing samples (notes/maps/_house_cache_<tag>.npz from tools/house_check.py <layout> <tag>) and the layout's parts:
  off = furniture cover only (the game before WallCover: room walls were NotCover)
  on  = furniture + room-wall proxies (role "wall" reaching the floor), as fix/house_wallcover.lua marks them
Usage: python -I tools/house_wallcover_compare.py out/house/built_layout.json wallcover1029"""
import json, math, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); MAPS = os.path.join(os.path.dirname(HERE), "notes", "maps")
D = json.load(open(sys.argv[1])); tag = sys.argv[2]
C = np.load(os.path.join(MAPS, f"_house_cache_{tag}.npz"))
sx, sy, sz = C["sx"], C["sy"], C["sz"]
furn = [p for p in D["parts"] if p["role"] == "furniture" and p.get("cover") in ("low", "tall")]
walls = [p for p in D["parts"] if p["role"] == "wall" and "Above" not in p["id"] and "_Win_" not in p["id"]]
def dist(cov, x, y, z):
    best = 99
    for p in cov:
        if p["z1"] < z + 1 or p["z0"] > z + 3: continue
        dx = max(p["x0"] - x, 0, x - p["x1"]); dy = max(p["y0"] - y, 0, y - p["y1"]); best = min(best, math.hypot(dx, dy))
    return best
out = {}
for name, cov in (("off", furn), ("on", furn + walls)):
    d = np.array([dist(cov, sx[i], sy[i], sz[i]) for i in range(len(sx))])
    out[name] = dict(max=round(float(d.max()), 1), mean=round(float(d.mean()), 2), p90=round(float(np.percentile(d, 90)), 2),
                     within3=round(float((d <= 3).mean() * 100), 1))
out["wall_proxies"] = len(walls)
print(json.dumps(out))
json.dump(out, open(os.path.join(MAPS, f"house_wallcover_compare_{tag}.json"), "w"), indent=1)
