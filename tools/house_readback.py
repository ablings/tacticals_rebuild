"""Read back the built House (tools/house_dump.lua through the build Studio) and diff it against the layout (0.001), then
write out/house/built_layout.json for tools/house_check.py (the checker runs on what was built).
    python tools/house_readback.py [dump.json]"""
import json, math, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
L = json.load(open(os.path.join(ROOT, "notes", "maps", "house_layout.json")))
if len(sys.argv) > 1:
    D = json.load(open(sys.argv[1]))
else:
    src = open(os.path.join(HERE, "house_dump.lua"), encoding="utf-8").read()
    D, i, STEP = None, 1, 120
    while True:
        code = re.sub(r"^local FROM, TO = .*--@CHUNK$", f"local FROM, TO = {i}, {i + STEP - 1}", src, flags=re.M)
        out = subprocess.run([sys.executable, os.path.join(HERE, "house_mcp.py"), "lua", "-"], input=code,
                             capture_output=True, text=True, encoding="utf-8").stdout
        d = json.loads(out[out.index("{"):out.rindex("}") + 1])
        if D is None: D = d
        else: D["parts"] += d["parts"]
        i += STEP
        if i > d["nparts"]: break
    json.dump(D, open(os.path.join(ROOT, "out", "house", "dump.json"), "w"), indent=1)
ox, oy, oz = D["origin"]
TOL = 0.001
diffs = []
def plan(pos): return (pos[0] - ox, -(pos[2] - oz), pos[1] - oy)
built = {}
for r in D["parts"]:
    pid = r["attrs"].get("PartId"); built[pid] = r
for d in D["doors"]:
    built[d["leaf"]["attrs"].get("PartId")] = d["leaf"]
newparts = []
for p in L["parts"]:
    r = built.get(p["id"])
    if not r: diffs.append(f"missing {p['id']}"); continue
    x, y, z = plan(r["pos"])
    sx, sy, sz = r["size"]
    if p["shape"] in ("box", "ramp"):
        if abs(r["rot"][0]) > 0.01 or abs(r["rot"][2]) > 0.01 or (p["shape"] == "box" and abs(r["rot"][1]) > 0.01):
            diffs.append(f"{p['id']} rotated {r['rot']}")
        if p["shape"] == "box":
            q = dict(p, x0=x - sx / 2, x1=x + sx / 2, y0=y - sz / 2, y1=y + sz / 2, z0=z - sy / 2, z1=z + sy / 2)
        else:
            # ramp: footprint from the wedge (yaw 0 or 180 keeps X along plan x); the high end = LookVector direction
            q = dict(p, x0=x - sx / 2, x1=x + sx / 2, y0=y - sz / 2, y1=y + sz / 2, z0=z - sy / 2, z1=z + sy / 2)
        for k in ("x0", "x1", "y0", "y1", "z0", "z1"):
            if abs(q[k] - p[k]) > TOL: diffs.append(f"{p['id']} {k} {q[k]:.4f} vs {p[k]}")
    else:
        q = dict(p, cx=x, cy=y, w=sx, d=sz, z0=z - sy / 2, z1=z + sy / 2, yaw=r["rot"][1])
        for k in ("cx", "cy", "w", "d", "z0", "z1"):
            if abs(q[k] - p[k]) > TOL: diffs.append(f"{p['id']} {k} {q[k]:.4f} vs {p[k]}")
        dy = (q["yaw"] - p["yaw"] + 180) % 360 - 180
        if abs(dy) > 0.01: diffs.append(f"{p['id']} yaw {q['yaw']:.3f} vs {p['yaw']}")
    # flags
    role = p["role"]
    if r["transp"] != 1: diffs.append(f"{p['id']} visible")
    if not r["anchored"]: diffs.append(f"{p['id']} not anchored")
    if not r["collide"]: diffs.append(f"{p['id']} not colliding")
    if role in ("barrier", "blocker"):
        if r["query"] or "WindowBarrier" not in r["tags"]: diffs.append(f"{p['id']} barrier flags")
    elif not r["query"]: diffs.append(f"{p['id']} not queryable")
    cover = (role == "furniture" and p["cover"] in ("low", "tall")) or (role == "sill" and "Pass_" in p["id"])
    if cover == bool(r["attrs"].get("NotCover")): diffs.append(f"{p['id']} NotCover wrong ({r['attrs'].get('NotCover')})")
    for k in ("x0", "x1", "y0", "y1", "z0", "z1", "cx", "cy", "w", "d", "yaw"):
        if k in q: q[k] = round(q[k], 3)
    newparts.append(q)
extra = set(built) - {p["id"] for p in L["parts"]}
if extra: diffs.append(f"extra parts {sorted(extra)[:10]}")
# spawns
for s in D["spawns"]:
    t = s["name"][-1]; x, y, z = plan(s["pos"]); ls = L["spawns"][t]
    if abs(x - ls["x"]) > TOL or abs(y - ls["y"]) > TOL or abs(z - 0.5 - ls["z"]) > TOL: diffs.append(f"spawn {t} at {x:.3f},{y:.3f},{z:.3f}")
    lx, lz = s["look"][0], s["look"][2]
    if abs(lx - ls["look"][0]) > 1e-3 or abs(-lz - ls["look"][1]) > 1e-3: diffs.append(f"spawn {t} look {lx},{lz}")
# doors
for d in L["doors"]:
    b = next((x for x in D["doors"] if x["name"] == d["id"]), None)
    if not b: diffs.append(f"door {d['id']} missing"); continue
    st = {"Ajar": "Open", "Closed": "Closed", "Locked": "Locked"}[d["state"]]
    if b["attrs"].get("DoorState") != st: diffs.append(f"door {d['id']} state {b['attrs'].get('DoorState')}")
    for k in ("ClosedCF", "OpenCF"):
        if k not in b["attrs"]: diffs.append(f"door {d['id']} no {k}")
    if not b["leaf"]["collide"] or not b["leaf"]["attrs"].get("NotCover"): diffs.append(f"door {d['id']} leaf flags")
nwin = sum(1 for o in L["openings"] if o["kind"] == "window")
# Shootables also holds the smoke alarms (Shootable = "SmokeAlarm"): only the glass entries are windows
D["windows"] = [w for w in D["windows"] if w["shootable"] != "SmokeAlarm"]
if len(D["windows"]) != nwin or any(w["shootable"] != "Glass" for w in D["windows"]): diffs.append("windows registry wrong")
if D["art"]["colliding"]: diffs.append(f"{D['art']['colliding']} art parts collide/query/touch")
if D.get("indoor") is not True: diffs.append("Indoor not true")
reg = D.get("registry")
if not reg or reg["attrs"].get("Modes") != "1v1,2v2,3v3": diffs.append("registry entry wrong")
B = dict(L, parts=newparts)
os.makedirs(os.path.join(ROOT, "out", "house"), exist_ok=True)
json.dump(B, open(os.path.join(ROOT, "out", "house", "built_layout.json"), "w"), indent=1)
print(f"read-back: {len(D['parts'])} proxies, {len(D['doors'])} doors, {len(D['windows'])} windows, art {D['art']['n']} parts; "
      f"{len(diffs)} differences")
for x in diffs[:40]: print("  ", x)
