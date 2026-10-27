"""Warehouse 2 metrics: run the Warehouse study's analysis (notes/warehouse_study/analyze.py, unchanged) on the BUILT Warehouse 2
and compare with the old map's metrics.json (work order: routes, exposure and spawn sight within 5 %).

    python tools/wh2_metrics.py            (reads notes/warehouse2_dump.json, made by tools/wh2_dump.lua from the build)

Two runs, outputs in notes/warehouse2_metrics/:
  hall/   the same domain as the old study (the 81 x 114 hall): the like-for-like comparison the 5 % rule is about;
  yards/  the hall plus both 20-deep loading yards behind the open doors (end walls with their 20-wide openings, the trailer,
          the containers and the fences as walls), to show what the new space changes.
The old study's geom.py is not edited: a stand-in `geom` module with the new map's data is put in sys.modules before
analyze.py runs (same maths, same grid)."""
import json, math, os, runpy, sys, types

ROOT = r"C:/Users/Shadow/Documents/tacticals_rebuild"
STUDY = os.path.join(ROOT, "notes", "warehouse_study")
OUT = r"C:/Users/Shadow/Documents/tacticals_rebuild/captures/warehouse2/grade_r6/metrics"
CX, CZ, FY = -84.2, -300.0, 0.4          # fix/map_warehouse2.lua ORIGIN
KIND = {"P": "pillar", "C": "block", "W": "wall", "L": "low"}


def plan(p):
    x, y, z = p["pos"]; sx, sy, sz = p["size"]
    return dict(name=p["name"], e=-(x - CX), n=z - CZ, w=sx, d=sz, h=y + sy / 2 - FY, bot=y - sy / 2 - FY)


def load(dump):
    D = json.load(open(dump, encoding="utf-8"))
    pieces = []
    for p in D["proxies"]:
        nm = p["name"][5:]
        if nm and nm[0] in KIND and nm[1:].isdigit():
            q = plan(p); q["kind"] = KIND[nm[0]]; q["id"] = nm; pieces.append(q)
    barrels = []
    for p in D["shootables"]:
        if p["name"] == "Body":
            q = plan(p); q["kind"] = "barrel"; q["id"] = p["parent"]; barrels.append(q)
    camskin = [plan(p) for p in D["camskin"]]
    spawns = {p["name"]: dict(e=-(p["pos"][0] - CX), n=p["pos"][2] - CZ, yaw=p["rot"][1]) for p in D["spawns"]}
    return D, pieces, barrels, camskin, spawns


def rect(name, e0, e1, n0, n1):
    return dict(name=name, e=(e0 + e1) / 2, n=(n0 + n1) / 2, w=e1 - e0, d=n1 - n0, h=18, bot=0)


def yard_walls(D):
    """Hall end walls (door gaps) + everything that bounds the yards, as wall bumps (block walking and standing sight)."""
    out = []
    for p in D["proxies"]:
        nm = p["name"]
        if nm.startswith("COLP_Wall_N_") or nm.startswith("COLP_Wall_S_"):
            if "Header" in nm or "Gable" in nm:
                continue
            out.append(plan(p))
        if nm.startswith("COLP_Yard_") and "Floor" not in nm:
            out.append(plan(p))
    # outside the yards' outline: solid (the grid is a rectangle: e +-40.5 by n +-78.5)
    for s in (1, -1):
        e_fence = -24.8 if s > 0 else 24.8      # north yard fence on the west, south yard (turned 180) on the east
        if s > 0:
            out.append(rect("outside_N_W", -40.5, -24.8, 58.5, 80)); out.append(rect("outside_N_E", 24, 40.5, 58.5, 80))
        else:
            out.append(rect("outside_S_E", 24.8, 40.5, -80, -58.5)); out.append(rect("outside_S_W", -40.5, -24, -80, -58.5))
        _ = e_fence
    return out


def run(variant):
    D, pieces, barrels, camskin, spawns = load(r"C:/Users/Shadow/Documents/tacticals_rebuild/captures/warehouse2/grade_r6/wh2_dump_g6.json")
    g = types.ModuleType("geom")
    g.D, g.CX, g.CZ, g.FY = D, CX, CZ, FY
    g.pieces, g.barrels, g.spawns, g.CEIL, g.HALF_W = pieces, barrels, spawns, 18.0, 40.5
    if variant == "hall":
        g.camskin, g.HALF_L = camskin, 57.0
    else:
        g.camskin, g.HALF_L = camskin + yard_walls(D), 78.5
    sys.modules["geom"] = g
    od = os.path.join(OUT, variant)
    os.makedirs(od, exist_ok=True)
    cwd = os.getcwd()
    os.chdir(od)
    try:
        import io, contextlib
        with contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(os.path.join(STUDY, "analyze.py"), run_name="__main__")
    finally:
        os.chdir(cwd)
        sys.modules.pop("geom", None)
    return json.load(open(os.path.join(od, "metrics.json")))


def pct(a, b):
    if a == b:
        return 0.0
    if a == 0:
        return float("inf")
    return (b - a) / abs(a) * 100


def compare(old, new, label):
    rows = []
    def add(name, a, b, tol=5.0, absolute=None):
        d = pct(a, b)
        ok = abs(d) <= tol if absolute is None else abs(b - a) <= absolute
        rows.append((name, a, b, d, "OK" if ok else "OUT"))
    # routes
    for s in ("SpawnA", "SpawnB"):
        for k in ("novault_sprint", "vault_sprint", "path_len"):
            add(f"route {s} -> centre {k}", old["centre"][s][k], new["centre"][s][k])
    add("route spawn -> spawn path", old["spawn_to_spawn_path"], new["spawn_to_spawn_path"])
    tA = {t["id"]: t for t in old["times"]}; tB = {t["id"]: t for t in new["times"]}
    worst = max((abs(pct(tA[i]["tA"], tB[i]["tA"])) if tA[i]["tA"] else 0, i) for i in tA if i in tB)
    worstB = max((abs(pct(tA[i]["tB"], tB[i]["tB"])) if tA[i]["tB"] else 0, i) for i in tA if i in tB)
    rows.append(("route per-piece time from A, worst", "", worst[1], worst[0], "OK" if worst[0] <= 5 else "OUT"))
    rows.append(("route per-piece time from B, worst", "", worstB[1], worstB[0], "OK" if worstB[0] <= 5 else "OUT"))
    # exposure
    for k in ("mean", "p10", "p90", "min", "max"):
        add(f"exposure {k}", old["exposure"][k], new["exposure"][k])
    bo = dict((b[0], b[1]) for b in old["exposure"]["bands"]); bn = dict((b[0], b[1]) for b in new["exposure"]["bands"])
    wb = max((abs(pct(bo[k], bn[k])), k) for k in bo if k in bn)
    rows.append(("exposure 10-stud band, worst", "", f"band {wb[1]}", wb[0], "OK" if wb[0] <= 5 else "OUT"))
    # spawn sight
    add("spawn-to-spawn sight %", old["spawn_to_spawn_los_pct"], new["spawn_to_spawn_los_pct"], absolute=0.5)
    for s in ("SpawnA", "SpawnB"):
        add(f"spawn view {s} floor seen %", old["spawn_view"][s]["stand_floor_pct"], new["spawn_view"][s]["stand_floor_pct"])
        rows.append((f"spawn view {s} sees centre", old["spawn_view"][s]["sees_centre_stand"], new["spawn_view"][s]["sees_centre_stand"], 0,
                     "OK" if old["spawn_view"][s]["sees_centre_stand"] == new["spawn_view"][s]["sees_centre_stand"] else "OUT"))
    # cover
    for k in ("mean_walls", "max_pieces", "mean_tall"):
        add(f"cover distance {k}", old["cover"][k], new["cover"][k])
    add("footprint % all", old["footprint_pct"]["all"], new["footprint_pct"]["all"])
    lines = [f"## {label}", "| metric | old | new | diff % | |", "|---|---|---|---|---|"]
    for r in rows:
        a = r[1] if not isinstance(r[1], float) else round(r[1], 2)
        b = r[2] if not isinstance(r[2], float) else round(r[2], 2)
        lines.append(f"| {r[0]} | {a} | {b} | {r[3]:+.1f} | {r[4]} |")
    return lines, sum(1 for r in rows if r[4] != "OK")


if __name__ == "__main__":
    old = json.load(open(os.path.join(STUDY, "metrics.json")))
    hall = run("hall")
    if "--yards" not in sys.argv:
        # round 6: both doors are shut in a match, so the playable space is the hall alone (the old study's own domain);
        # the yards variant (doors open) only matters for a cutscene and is run with --yards
        l1, bad1 = compare(old, hall, "Hall (same domain as the old study; doors shut, the whole playable space): the 5 % check")
        txt = "\n".join(l1)
        open(os.path.join(OUT, "compare.md"), "w", encoding="utf-8").write(txt + "\n")
        print(txt)
        print("\nOUT of 5 %: hall", bad1)
        sys.exit(1 if bad1 else 0)
    yards = run("yards")
    l1, bad1 = compare(old, hall, "Hall (same domain as the old study): the 5 % check")
    l2, bad2 = compare(old, yards, "Hall + both yards (new space; informative)")
    # what the yards add: sight from each yard into the hall, and from the hall into the yards (standing eye, tall cover blocks)
    import numpy as np
    G = np.load(os.path.join(OUT, "yards", "grids.npz"))
    block = G["tall"] | G["wallbump"]
    samp, ns_ = G["samp"], G["ns"]
    sn = ns_[samp[:, 0]]
    hallM, yN, yS = (np.abs(sn) < 57), sn > 58.5, sn < -58.5

    def seen(src_mask, dst_mask):
        src, dst = samp[src_mask], samp[dst_mask]
        out = []
        for c in src:
            t = np.linspace(0, 1, 260)[:, None]
            pz = c[0] + (dst[:, 0][None] - c[0]) * t; px = c[1] + (dst[:, 1][None] - c[1]) * t
            out.append((~block[pz.round().astype(int), px.round().astype(int)].any(0)).mean() * 100)
        return np.array(out)
    extra = ["", "## The yards (new space behind the open doors)",
             f"- floor: hall {hall['room']['floor_area']:.0f} sq studs; each yard ~{int(hall['room']['floor_area'] and 40 * 11.5 + 8 * 8.5)} sq studs of open apron (dead end, behind each team's spawn)"]
    for nm, ym in (("north (B's end)", yN), ("south (A's end)", yS)):
        a = seen(ym, hallM); b = seen(hallM & (np.abs(sn) > 30), ym)
        extra.append(f"- {nm} yard: {ym.sum()} sample cells; from the yard a player sees {a.mean():.1f} % of the hall floor on average "
                     f"(max {a.max():.1f} %, through the 20-wide door); from the hall's end third the yard is {b.mean():.1f} % visible")
    extra.append("- routes: the yards are dead ends behind the spawns: every route between the spawns and to the centre is unchanged (table above)")
    extra.append(f"- hall exposure bands with the doors open (denominator now includes yard cells, so not comparable 1:1): {yards['exposure']['bands']}")
    txt = "\n".join(l1 + [""] + l2 + extra)
    open(os.path.join(OUT, "compare.md"), "w", encoding="utf-8").write(txt + "\n")
    print(txt)
    print("\nOUT of 5 %: hall", bad1, "| hall+yards", bad2)
