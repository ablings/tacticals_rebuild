"""Check the Arena v2 layout in plan view (no Studio). Reads notes/maps/arena_v2_layout.json, writes
notes/maps/arena_v2_checks.json, arena_v2_plan.png and arena_v2_exposure.png, and prints a summary.

    python -I tools/arena_v2_layout.py && python -I tools/arena_v2_check.py

What it checks (Tacticals movement numbers are in the layout's "movement" block):
  overlaps        no two pieces share volume; gaps between pieces are 0 (touch), <= 1.5 (cover chain: CoverController walks
                  between them without leaving cover) or >= 4 (a lane a player fits through); 1.5..4 is a snag gap
  climbs          nothing a player can stand next to has a top 0 < dz <= 5.6 (the CLIMB reach) unless it's meant to be climbed:
                  low walls / sills need a clear landing on both sides (so Space vaults, never climbs); deck edges need a
                  parapet, a ramp or the box; no wall / pillar top within climb reach of a deck
  spawns          no line of sight between the two spawn pockets (eye 4.6 to eye 4.6 and to standing chest 4.0)
  exposure        % of the floor each 2.5-stud cell sees at eye height; 10-stud bands along the long axis
  sight lengths   distance of every visible floor-to-floor pair (median, p90, max, longest lines)
  cover distance  farthest floor spot from any cover face (a cover dash reaches 26: every spot should be <= 13 from cover)
  gaps            each named crossing: length, sprint / dash / walk time, who watches it
  timing          Dijkstra at sprint speed from each spawn spot to the middle and to every advantage spot (vaults and drops
                  included, ramps the only way up); A vs B within 10 %
  ramps           slope, run, width, time on the ramp, how much of the enemy's floor sees the climb
  perches         which low cover a perch cancels (a crouched player behind it shows >= 1 stud to the perch's eye)
  windows         opening clear height vs the vault arc; what each window looks onto
"""
import json, math, os, heapq, itertools
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(os.path.dirname(HERE), "notes", "maps")
D = json.load(open(os.path.join(MAPS, "arena_v2_layout.json")))
MV = D["movement"]
BOX = D["box"]
RES = 0.5
X0, X1, Y0, Y1 = BOX["x0"], BOX["x1"], BOX["y0"], BOX["y1"]
NX, NY = int((X1 - X0) / RES), int((Y1 - Y0) / RES)
EYE, CHEST, CROUCH_TOP = MV["eye"], 4.0, MV["crouch_top"]
SPRINT, WALK, DASH, DASH_MAX = MV["sprint"], MV["walk"], MV["cover_dash"], MV["cover_dash_max"]
VAULT_S, CLIMB_REACH = MV["vault_s"], MV["climb_max_above_feet"]
R_AGENT = 1.0  # body radius for walking (R15 shoulders ~2 wide)

# ------------------------------------------------------------------------------------------------ rasterise
top1 = np.zeros((NX, NY))            # solid from 0 up to top1 (floor = 0)
lo2 = np.full((NX, NY), np.inf)      # overhead solid lo2..top2 (lintels)
top2 = np.full((NX, NY), -np.inf)
role = np.zeros((NX, NY), dtype=np.int8)   # 0 open, 1 deck, 2 ramp, 3 low/sill (base 0), 4 parapet (base = deck), 5 tall solid, 6 curb
owner = np.full((NX, NY), -1, dtype=np.int32)
ROLE = {"deck": 1, "ramp": 2, "low": 3, "sill": 3, "parapet": 4, "solid": 5, "curb": 6}
xs = X0 + (np.arange(NX) + 0.5) * RES
ys = Y0 + (np.arange(NY) + 0.5) * RES


def cells(x0, x1, y0, y1):
    i0, i1 = int(round((x0 - X0) / RES)), int(round((x1 - X0) / RES))
    j0, j1 = int(round((y0 - Y0) / RES)), int(round((y1 - Y0) / RES))
    return slice(max(i0, 0), min(i1, NX)), slice(max(j0, 0), min(j1, NY))


parts_flat = []  # (piece index, part dict)
for pi, p in enumerate(D["pieces"]):
    for part in p["parts"]:
        parts_flat.append((pi, part))
        si, sj = cells(part["x0"], part["x1"], part["y0"], part["y1"])
        if part["role"] == "lintel":
            lo2[si, sj] = part["z0"]; top2[si, sj] = part["z1"]
            continue
        top1[si, sj] = np.maximum(top1[si, sj], part["z1"])
        r = ROLE[part["role"]]
        role[si, sj] = np.maximum(role[si, sj], r)
        owner[si, sj] = pi
    if p["kind"] == "deck":
        rp = p["ramp"]
        (fx, fy), (tx, ty), w, h = rp["foot"], rp["top"], rp["width"], rp["rise"]
        ux, uy = (tx - fx) / rp["run"], (ty - fy) / rp["run"]
        X, Y = np.meshgrid(xs, ys, indexing="ij")
        t = ((X - fx) * ux + (Y - fy) * uy) / rp["run"]
        side = np.abs((X - fx) * (-uy) + (Y - fy) * ux)
        m = (t >= 0) & (t <= 1) & (side <= w / 2)
        top1[m] = np.maximum(top1[m], h * t[m])
        role[m] = 2
        owner[m] = pi

walkH = np.where(np.isin(role, [0, 1, 2]), top1, np.nan)   # where you can stand (floor, deck, ramp)


def cell_of(x, y):
    return min(max(int((x - X0) / RES), 0), NX - 1), min(max(int((y - Y0) / RES), 0), NY - 1)


def ground(x, y):
    i, j = cell_of(x, y)
    return 0.0 if np.isnan(walkH[i, j]) else float(walkH[i, j])


# ------------------------------------------------------------------------------------------------ line of sight
def los_many(p, Q, step=0.25):
    """p: (3,), Q: (n,3). True where the segment p->q is clear of solids (cells outside the box = the box wall, 16 high)."""
    Q = np.atleast_2d(Q)
    d = Q - p
    L = np.hypot(d[:, 0], d[:, 1])
    S = int(max(L.max() / step, 2)) if len(L) else 2
    t = (np.arange(1, S) / S)[None, :]
    px = p[0] + d[:, 0:1] * t; py = p[1] + d[:, 1:2] * t; pz = p[2] + d[:, 2:3] * t
    inside = (px > X0) & (px < X1) & (py > Y0) & (py < Y1)
    i = np.clip(((px - X0) / RES).astype(int), 0, NX - 1)
    j = np.clip(((py - Y0) / RES).astype(int), 0, NY - 1)
    blocked = (pz < top1[i, j]) | ((pz >= lo2[i, j]) & (pz <= top2[i, j])) | (~inside & (pz < BOX["wall_h"]))
    return ~blocked.any(axis=1)


def los(a, b):
    return bool(los_many(np.array(a, float), np.array([b], float))[0])


# ------------------------------------------------------------------------------------------------ report
R = {"errors": [], "warnings": [], "info": {}}
err = R["errors"].append
warn = R["warnings"].append

# 1. overlaps and gaps between pieces ----------------------------------------------------------------
def fp(p):  # footprint rectangles of a piece (incl. its ramp as a box)
    rs = [(q["x0"], q["x1"], q["y0"], q["y1"], q["z0"], q["z1"]) for q in p["parts"] if q["role"] != "lintel"]
    if p["kind"] == "deck":
        rp = p["ramp"]; (fx, fy), (tx, ty), w = rp["foot"], rp["top"], rp["width"]
        if fy == ty: rs.append((min(fx, tx), max(fx, tx), fy - w / 2, fy + w / 2, 0, rp["rise"]))
        else: rs.append((fx - w / 2, fx + w / 2, min(fy, ty), max(fy, ty), 0, rp["rise"]))
    return rs


def rect_gap(a, b):
    dx = max(a[0] - b[1], b[0] - a[1], 0); dy = max(a[2] - b[3], b[2] - a[3], 0)
    return math.hypot(dx, dy), (min(a[1], b[1]) - max(a[0], b[0]) > 1e-6 and min(a[3], b[3]) - max(a[2], b[2]) > 1e-6
                                and min(a[5], b[5]) - max(a[4], b[4]) > 1e-6)


pairs = []
P = D["pieces"]
for (ia, a), (ib, b) in itertools.combinations(enumerate(P), 2):
    best, ov = 1e9, False
    for ra in fp(a):
        for rb in fp(b):
            g, o = rect_gap(ra, rb)
            best = min(best, g); ov = ov or o
    if ov:
        err(f"OVERLAP {a['id']} x {b['id']}")
    elif best < 1e-6:
        pairs.append((a["id"], b["id"], 0.0, "touch"))
    elif best <= 1.5:
        pairs.append((a["id"], b["id"], round(best, 2), "cover chain"))
    elif best < 4:
        warn(f"SNAG GAP {a['id']} - {b['id']}: {best:.2f} studs (make it 0, <= 1.5 or >= 4)")
    elif best < 8:
        pairs.append((a["id"], b["id"], round(best, 2), "lane"))
# gaps to the box walls
for p in P:
    for r in fp(p):
        for g, nm in ((r[0] - X0, "W"), (X1 - r[1], "E"), (r[2] - Y0, "S"), (Y1 - r[3], "N")):
            if 1e-6 < g < 4:
                warn(f"SNAG GAP {p['id']} - box {nm}: {g:.2f}")
R["info"]["close_pairs"] = pairs

# 2. climbs -------------------------------------------------------------------------------------------
climbs = []
for p in P:
    if p["kind"] in ("low",):
        q = p["parts"][0]
        # landing clear on both sides across the short axis: 3.5 of standable floor
        if p["along"] == "x":
            probes = [((q["x0"] + q["x1"]) / 2, q["y1"] + 3.5), ((q["x0"] + q["x1"]) / 2, q["y0"] - 3.5)]
        else:
            probes = [(q["x1"] + 3.5, (q["y0"] + q["y1"]) / 2), (q["x0"] - 3.5, (q["y0"] + q["y1"]) / 2)]
        for x, y in probes:
            i, j = cell_of(x, y)
            if not (X0 < x < X1 and Y0 < y < Y1) or role[i, j] not in (0,):
                climbs.append(f"{p['id']}: landing at ({x:.1f},{y:.1f}) blocked -> Space would CLIMB onto the low wall")
    if p["kind"] == "window":
        for q in p["parts"]:
            if q["role"] != "sill": continue
            if p["along"] == "y":
                probes = [(q["x1"] + 3.5, (q["y0"] + q["y1"]) / 2), (q["x0"] - 3.5, (q["y0"] + q["y1"]) / 2)]
            else:
                probes = [((q["x0"] + q["x1"]) / 2, q["y1"] + 3.5), ((q["x0"] + q["x1"]) / 2, q["y0"] - 3.5)]
            for x, y in probes:
                i, j = cell_of(x, y)
                if not (X0 < x < X1 and Y0 < y < Y1) or role[i, j] != 0:
                    climbs.append(f"{p['id']}: sill landing ({x:.1f},{y:.1f}) blocked -> climb onto the sill")
    if p["kind"] == "deck":
        d = p["parts"][0]; h = d["z1"]
        rp = p["ramp"]
        # walk each edge at 0.5 steps: covered by a parapet, the ramp, the box wall, or a tall piece touching it?
        for edge in "NSEW":
            pts = []
            if edge in "NS":
                y = d["y1"] if edge == "N" else d["y0"]; out = 0.6 if edge == "N" else -0.6
                pts = [(x, y, x, y + out) for x in np.arange(d["x0"] + 0.25, d["x1"], 0.5)]
            else:
                x = d["x1"] if edge == "E" else d["x0"]; out = 0.6 if edge == "E" else -0.6
                pts = [(x, y, x + out, y) for y in np.arange(d["y0"] + 0.25, d["y1"], 0.5)]
            open_run = 0
            for ex, ey, ox, oy in pts:
                if not (X0 < ox < X1 and Y0 < oy < Y1): continue          # the box wall
                io, jo = cell_of(ox, oy)
                if role[io, jo] == 2: continue                              # the ramp
                if role[io, jo] == 5 and top1[io, jo] > CLIMB_REACH: continue  # a tall piece against the face
                ii, jj = cell_of(ex - (ox - ex) * 0.4, ey - (oy - ey) * 0.4)  # 0.25 inside the edge, on the deck
                if role[ii, jj] in (4, 6): continue                         # a parapet or a kick-curb
                open_run += 1
            if open_run:
                climbs.append(f"{p['id']}: {open_run * 0.5:.1f} studs of its {edge} edge can be CLIMBED from the floor (deck {h} <= {CLIMB_REACH})")
        # tall pieces within climb reach of the deck top
        for q_p in P:
            if q_p is p: continue
            for q in q_p["parts"]:
                if q["role"] in ("lintel",): continue
                g, _ = rect_gap((d["x0"], d["x1"], d["y0"], d["y1"], 0, 1), (q["x0"], q["x1"], q["y0"], q["y1"], 0, 1))
                dz = q["z1"] - h
                if g <= 3.5 and 0 < dz <= CLIMB_REACH + 1.0:
                    msg = f"{q_p['id']} top {q['z1']} is {dz:.1f} above {p['id']} ({g:.1f} away)"
                    (climbs.append(msg + " -> climbable from the deck") if dz <= CLIMB_REACH else
                     warn(msg + f": only {CLIMB_REACH + 1.0 - dz:.1f} under the climb reach + 1 margin"))
# tall-on-floor: walls 7 next to low walls (stand on the low wall only if its vault is refused: covered above)
for c in climbs: err("CLIMB " + c)

# 3. spawns -------------------------------------------------------------------------------------------
def pocket_pts(pk, step=1.0):
    x0, x1, y0, y1 = pk
    out = []
    for x in np.arange(x0 + 1, x1 - 0.99, step):
        for y in np.arange(y0 + 1, y1 - 0.99, step):
            i, j = cell_of(x, y)
            if role[i, j] == 0: out.append((x, y))
    return out


SA, SB = D["spawns"]["A"], D["spawns"]["B"]
pa, pb = pocket_pts(SA["pocket"]), pocket_pts(SB["pocket"])
Qb_eye = np.array([(x, y, EYE) for x, y in pb]); Qb_ch = np.array([(x, y, CHEST) for x, y in pb])
vis_eye = vis_ch = 0
for x, y in pa:
    p = np.array([x, y, EYE])
    vis_eye += int(los_many(p, Qb_eye).sum()); vis_ch += int(los_many(p, Qb_ch).sum())
npairs = len(pa) * len(pb)
R["info"]["spawn_los"] = dict(pairs=npairs, eye_to_eye=vis_eye, eye_to_chest=vis_ch)
if vis_eye or vis_ch:
    err(f"SPAWN LOS: {vis_eye} eye-eye and {vis_ch} eye-chest pairs of {npairs} between the pockets")

# 4/5. exposure + sight lengths (2.5 grid of standable cells) -----------------------------------------
G = float(os.environ.get("ARENA_G", "2.5"))
samples = []
for x in np.arange(X0 + G / 2, X1, G):
    for y in np.arange(Y0 + G / 2, Y1, G):
        i, j = cell_of(x, y)
        # standable and clear of solids within the body radius
        ri, rj = int(R_AGENT / RES), int(R_AGENT / RES)
        blk = role[max(i - ri, 0):i + ri + 1, max(j - rj, 0):j + rj + 1]
        if role[i, j] in (0, 1, 2) and not np.isin(blk, [3, 4, 5]).any():
            samples.append((x, y, float(walkH[i, j])))
S = np.array(samples)
n = len(S)
vis = np.zeros((n, n), dtype=bool)
for k in range(n):
    p = np.array([S[k, 0], S[k, 1], S[k, 2] + EYE])
    Q = np.column_stack([S[:, 0], S[:, 1], S[:, 2] + CHEST])
    vis[k] = los_many(p, Q, step=0.4)
np.fill_diagonal(vis, False)
expo = vis.mean(axis=1) * 100
dist = np.hypot(S[:, None, 0] - S[None, :, 0], S[:, None, 1] - S[None, :, 1])
vd = dist[vis]
bands = {}
for b0 in range(int(X0), int(X1), 10):
    m = (S[:, 0] >= b0) & (S[:, 0] < b0 + 10) & (S[:, 2] == 0)
    if m.any(): bands[f"{b0}..{b0 + 10}"] = round(float(expo[m].mean()), 1)
R["info"]["exposure"] = dict(cells=n, min=round(float(expo.min()), 1), mean=round(float(expo.mean()), 1),
                             max=round(float(expo.max()), 1), bands=bands,
                             band_spread=round(max(bands.values()) - min(bands.values()), 1),
                             band_spread_outside_pockets=round(max(list(bands.values())[1:-1]) - min(list(bands.values())[1:-1]), 1))
R["info"]["sight"] = dict(median=round(float(np.median(vd)), 1), p90=round(float(np.percentile(vd, 90)), 1),
                          max=round(float(vd.max()), 1), over_90=round(float((vd > 90).mean() * 100), 2))
# longest floor lines (both ends on the floor), deduplicated by area
lines = []
ii, jj = np.where(np.triu(vis & vis.T))
order = np.argsort(-dist[ii, jj])
for k in order:
    a, b = S[ii[k]], S[jj[k]]
    if a[2] or b[2]: continue
    if any(math.hypot(a[0] - l[0][0], a[1] - l[0][1]) < 12 and math.hypot(b[0] - l[1][0], b[1] - l[1][1]) < 12 or
           math.hypot(a[0] - l[1][0], a[1] - l[1][1]) < 12 and math.hypot(b[0] - l[0][0], b[1] - l[0][1]) < 12 for l in lines):
        continue
    lines.append(((float(a[0]), float(a[1])), (float(b[0]), float(b[1])), round(float(dist[ii[k], jj[k]]), 1)))
    if len(lines) >= 6: break
R["info"]["longest_lines"] = lines
if R["info"]["exposure"]["max"] > 45: warn(f"EXPOSURE max {R['info']['exposure']['max']}% (> 45)")

# 6. cover distance ---------------------------------------------------------------------------------------
cov = np.isin(role, [3, 4, 5])
ci, cj = np.where(cov)
cpts = np.column_stack([xs[ci], ys[cj]])
far = []
for x, y, h in S:
    if h: continue
    dd = np.hypot(cpts[:, 0] - x, cpts[:, 1] - y).min()
    dd = min(dd, x - X0, X1 - x, y - Y0, Y1 - y) if False else dd  # the box walls are not cover (NotCover)
    far.append((dd, x, y))
far.sort(reverse=True)
fd = np.array([f[0] for f in far])
R["info"]["cover_distance"] = dict(max=round(float(fd.max()), 1), mean=round(float(fd.mean()), 1),
                                   p90=round(float(np.percentile(fd, 90)), 1),
                                   worst=[(round(f[0], 1), f[1], f[2]) for f in far[:5]])
if fd.max() > 13: warn(f"COVER DISTANCE: a floor spot is {fd.max():.1f} from cover (> 13 = half a cover dash)")

# 7. pathing (Dijkstra, sprint) -----------------------------------------------------------------------------
# a cell is walkable at its walkH unless a solid that rises above its feet + 1.6 is within the body radius
ri = int(R_AGENT / RES)
walk = ~np.isnan(walkH)
blocked = np.zeros_like(walk)
for di in range(-ri, ri + 1):
    for dj in range(-ri, ri + 1):
        if di * di + dj * dj > ri * ri: continue
        sh_role = np.roll(np.roll(role, di, 0), dj, 1)
        sh_top = np.roll(np.roll(top1, di, 0), dj, 1)
        blocked |= np.isin(sh_role, [3, 4, 5]) & (sh_top > np.nan_to_num(walkH, nan=0) + 1.6)
# the box walls
edge = np.zeros_like(walk); edge[:ri, :] = edge[-ri:, :] = True; edge[:, :ri] = edge[:, -ri:] = True
ok = walk & ~blocked & ~edge
NB = [(1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
extra = {}  # (i,j) -> list of ((i2,j2), seconds): vaults and drops


def add_edge(a, b, s):
    extra.setdefault(a, []).append((b, s))


# vault edges across every low wall, sill and parapet (short axis), from a clear cell on one side to one on the other
for p in P:
    for q in p["parts"]:
        if q["role"] not in ("low", "sill", "parapet"): continue
        base = q["z0"]
        across_x = (q["x1"] - q["x0"]) < (q["y1"] - q["y0"])
        L0, L1 = (q["y0"], q["y1"]) if across_x else (q["x0"], q["x1"])
        for s in np.arange(L0 + 0.75, L1 - 0.5, 0.5):
            for sgn in (1, -1):
                if across_x:
                    a = (q["x0"] - 1.75, s) if sgn > 0 else (q["x1"] + 1.75, s)
                    b = (q["x1"] + 1.75, s) if sgn > 0 else (q["x0"] - 1.75, s)
                else:
                    a = (s, q["y0"] - 1.75) if sgn > 0 else (s, q["y1"] + 1.75)
                    b = (s, q["y1"] + 1.75) if sgn > 0 else (s, q["y0"] - 1.75)
                ca, cb = cell_of(*a), cell_of(*b)
                if not (X0 < a[0] < X1 and Y0 < a[1] < Y1 and X0 < b[0] < X1 and Y0 < b[1] < Y1): continue
                if not ok[ca] or not walk[cb]: continue
                if abs(walkH[ca] - base) > 0.6: continue          # you vault from the piece's own floor
                if walkH[cb] > base + 0.6: continue               # never up onto something
                add_edge(ca, cb, VAULT_S + 0.1 + (0.25 if walkH[cb] < base - 0.6 else 0))  # + landing after a drop
# drop edges off deck edges without parapets (to the floor next to the face)
for p in P:
    if p["kind"] != "deck": continue
    d = p["parts"][0]
    for x in np.arange(d["x0"] + 0.25, d["x1"], 0.5):
        for y in np.arange(d["y0"] + 0.25, d["y1"], 0.5):
            for ox, oy in ((0, 1.5), (0, -1.5), (1.5, 0), (-1.5, 0), (0, 2), (0, -2), (2, 0), (-2, 0)):
                c, o = cell_of(x, y), cell_of(x + ox, y + oy)
                if ok[c] and ok[o] and walkH[c] - walkH[o] > 1 and role[o] == 0:
                    mid = cell_of(x + ox * 0.6, y + oy * 0.6)
                    add_edge(c, o, 1.5 / SPRINT + 0.25 + (0.3 if role[mid] == 6 else 0))  # hop the curb, drop, land


def dijkstra(src):
    dist = np.full((NX, NY), np.inf)
    s = cell_of(*src)
    dist[s] = 0
    h = [(0.0, s)]
    while h:
        d0, (i, j) = heapq.heappop(h)
        if d0 > dist[i, j]: continue
        hi = walkH[i, j]
        for di, dj, w in NB:
            i2, j2 = i + di, j + dj
            if not (0 <= i2 < NX and 0 <= j2 < NY) or not ok[i2, j2]: continue
            if walkH[i2, j2] - hi > 0.6: continue          # no stepping up (ramps rise 0.17 per cell)
            if hi - walkH[i2, j2] > 0.6: continue          # drops go through the drop edges
            if di and dj and (not ok[i + di, j] or not ok[i, j + dj]): continue
            nd = d0 + w * RES / SPRINT
            if nd < dist[i2, j2]:
                dist[i2, j2] = nd; heapq.heappush(h, (nd, (i2, j2)))
        for (i2, j2), sec in extra.get((i, j), ()):
            nd = d0 + sec
            if nd < dist[i2, j2]:
                dist[i2, j2] = nd; heapq.heappush(h, (nd, (i2, j2)))
    return dist


def nearest_ok(x, y):
    i, j = cell_of(x, y)
    if ok[i, j]: return i, j
    best = None
    for r in range(1, 12):
        for di in range(-r, r + 1):
            for dj in range(-r, r + 1):
                a, b = i + di, j + dj
                if 0 <= a < NX and 0 <= b < NY and ok[a, b] and (best is None or di * di + dj * dj < best[0]):
                    best = (di * di + dj * dj, a, b)
        if best: return best[1], best[2]
    return i, j


fields = {}
for team in "AB":
    sp = D["spawns"][team]["spots"]
    fields[team] = [dijkstra(tuple(s)) for s in (sp[:1] if os.environ.get("ARENA_FAST") else sp)]
    fields[team] += [fields[team][0]] * (len(sp) - len(fields[team]))
times = {}
for name, s in D["spots"].items():
    c = nearest_ok(s["pos"][0], s["pos"][1])
    times[name] = {team: [round(float(f[c]), 2) for f in fields[team]] for team in "AB"}
R["info"]["times_sprint_s"] = times
reach_all = np.isfinite(fields["A"][0]) & ok
unreach = int((ok & ~np.isfinite(fields["A"][0])).sum())
R["info"]["unreachable_cells"] = unreach
if unreach: warn(f"REACH: {unreach * RES * RES:.0f} sq studs of standable floor can't be reached from spawn A")

pairs_t = [(x["what"], x["A"], x["B"]) for x in D["balance"]]
bal = []
for label, an, bn in pairs_t:
    ta = min(times[n]["A"][0] for n in an); tb = min(times[n]["B"][0] for n in bn)
    diff = abs(ta - tb) / max(min(ta, tb), 1e-6) * 100
    bal.append(dict(what=label, A=ta, B=tb, diff_pct=round(diff, 1)))
    if diff > 10 and "gap" not in label: warn(f"TIMING {label}: A {ta:.2f} s vs B {tb:.2f} s ({diff:.0f}% apart)")
R["info"]["balance"] = bal

# 8. gaps -----------------------------------------------------------------------------------------------------
spot_eyes = {k: (v["pos"][0], v["pos"][1], v["pos"][2] + EYE) for k, v in D["spots"].items()}
gres = []
for g in D["gaps"]:
    (ax, ay), (bx, by) = g["a"], g["b"]
    L = math.hypot(bx - ax, by - ay)
    mx, my = (ax + bx) / 2, (ay + by) / 2
    watchers = [k for k, e in spot_eyes.items() if los(e, (mx, my, CHEST))]
    # share of the floor that sees the gap's midpoint
    seen = los_many(np.array([mx, my, CHEST]), np.column_stack([S[:, 0], S[:, 1], S[:, 2] + EYE]))
    gres.append(dict(id=g["id"], length=round(L, 1), sprint_s=round(L / SPRINT, 2), walk_s=round(L / WALK, 2),
                     dash_s=round(L / DASH, 2) if L <= DASH_MAX else None, watched_by=watchers,
                     floor_seeing_mid_pct=round(float(seen.mean() * 100), 1), note=g["note"]))
R["info"]["gaps"] = gres

# 9. ramps --------------------------------------------------------------------------------------------------
rres = []
for p in P:
    if p["kind"] != "deck": continue
    rp = p["ramp"]
    (fx, fy), (tx, ty) = rp["foot"], rp["top"]
    enemy = "B" if p["side"] == "A" else "A"
    ex = (S[:, 0] > 0) if enemy == "B" else (S[:, 0] < 0)
    E = np.column_stack([S[ex, 0], S[ex, 1], S[ex, 2] + EYE])
    seen = []
    for t in np.linspace(0.1, 0.9, 5):
        x, y = fx + (tx - fx) * t, fy + (ty - fy) * t
        q = np.array([x, y, rp["rise"] * t + CHEST])
        seen.append(float(los_many(q, E).mean() * 100))
    rres.append(dict(deck=p["id"], rise=rp["rise"], run=round(rp["run"], 1), slope_deg=rp["slope_deg"], width=rp["width"],
                     on_ramp_sprint_s=round(rp["run"] / SPRINT, 2), on_ramp_walk_s=round(rp["run"] / WALK, 2),
                     enemy_half_seeing_climb_pct=[round(s, 1) for s in seen]))
R["info"]["ramps"] = rres

# 10. high ground: what it sees, what it doesn't, and low cover --------------------------------------------------------------
# A crouched player hugs a low wall at WallOffset 0.85 behind its FAR face, so the line that matters must clear the edge nearest
# the target: 1 stud of a crouched body shows only within 0.85 * (eye - 2.2) / 1.2 studs. Height doesn't break hugged low cover;
# it sees the floor BETWEEN cover (crouch-walkers, gap crossers, vaulters) and over 7-walls at range.
pres = []
FLOOR = S[:, 2] == 0
for name, sp in D["spots"].items():
    if sp["kind"] != "height": continue
    x, y, h = sp["pos"]
    e = np.array([x, y, h + EYE])
    seen_st = los_many(e, np.column_stack([S[FLOOR, 0], S[FLOOR, 1], np.full(FLOOR.sum(), CHEST)]))
    seen_cr = los_many(e, np.column_stack([S[FLOOR, 0], S[FLOOR, 1], np.full(FLOOR.sum(), CROUCH_TOP - 0.6)]))
    # the same spot's view if it stood on the floor instead (what the height adds)
    rx, ry = sp.get("ref", [x, y])
    e0 = np.array([rx, ry, EYE])                     # a floor spot just in front of the deck
    seen0 = los_many(e0, np.column_stack([S[FLOOR, 0], S[FLOOR, 1], np.full(FLOOR.sum(), CROUCH_TOP - 0.6)]))
    dd = np.hypot(S[FLOOR, 0] - x, S[FLOOR, 1] - y)
    near = dd <= 14
    # crouch strip behind each low wall facing it: 0.85 (hugging) and 3 (crouch-walking) behind the far face
    hug, walkc = [], []
    for q_p in P:
        for q in q_p["parts"]:
            if q["role"] not in ("low", "sill") or q_p["side"] == sp["side"] and False: continue
            cx, cy = (q["x0"] + q["x1"]) / 2, (q["y0"] + q["y1"]) / 2
            thin_x = (q["x1"] - q["x0"]) < (q["y1"] - q["y0"])
            vx, vy = x - cx, y - cy
            if abs(vx if thin_x else vy) < 0.5 * math.hypot(vx, vy) or math.hypot(vx, vy) > 70: continue
            for off, lst in ((0.85, hug), (3.0, walkc)):
                if thin_x: tx, ty = (q["x0"] - off if vx > 0 else q["x1"] + off), cy
                else: tx, ty = cx, (q["y0"] - off if vy > 0 else q["y1"] + off)
                if los(tuple(e), (tx, ty, CROUCH_TOP - 1.0)):
                    lst.append(f"{q_p['id']}@{math.hypot(tx - x, ty - y):.0f}")
    pres.append(dict(spot=name, eye=h + EYE, floor_seen_standing_pct=round(float(seen_st.mean() * 100), 1),
                     floor_seen_crouched_pct=round(float(seen_cr.mean() * 100), 1),
                     floor_in_front_crouched_pct=round(float(seen0.mean() * 100), 1),
                     own_foot_seen_pct=round(float(seen_cr[near].mean() * 100), 1) if near.any() else None,
                     hugging_crouch_exposed=hug, crouch_walk_3_behind_exposed=walkc,
                     one_stud_radius=round(0.85 * (h + EYE - 2.2) / 1.2, 1)))
R["info"]["perches"] = pres
rng = np.random.default_rng(1)
idx = rng.choice(np.where(FLOOR)[0], size=min(80, int(FLOOR.sum())), replace=False)
avg = [los_many(np.array([S[k, 0], S[k, 1], EYE]), np.column_stack([S[FLOOR, 0], S[FLOOR, 1], np.full(FLOOR.sum(), CROUCH_TOP - 0.6)])).mean()
       for k in idx]
R["info"]["floor_avg_crouched_seen_pct"] = round(float(np.mean(avg) * 100), 1)

# 11. windows ------------------------------------------------------------------------------------------------------
wres = []
for p in P:
    if p["kind"] != "window": continue
    for q in p["parts"]:
        if q["role"] != "sill": continue
        cx, cy = (q["x0"] + q["x1"]) / 2, (q["y0"] + q["y1"]) / 2
        out = []
        for sgn in (1, -1):
            if p["along"] == "y":
                e = (cx + sgn * (1.5 + 0.85 + 0.5), cy, EYE)
            else:
                e = (cx, cy + sgn * (1.5 + 0.85 + 0.5), EYE)
            onto = [k for k, s in spot_eyes.items() if los(e, s) and k not in (p["id"],)]
            seen = los_many(np.array(e), np.column_stack([S[:, 0], S[:, 1], S[:, 2] + CHEST]))
            out.append(dict(side=("east" if sgn > 0 else "west") if p["along"] == "y" else ("north" if sgn > 0 else "south"),
                            floor_seen_pct=round(float(seen.mean() * 100), 1), sees_spots=onto))
        wres.append(dict(window=p["id"], sill_centre=[cx, cy], opening="10 wide x 6.6 high (3.4 .. 10)",
                         vault_apex_head=round(3.4 + MV["vault_clearance"] + 2.2, 1), clear=10 - (3.4 + MV["vault_clearance"] + 2.2),
                         views=out))
R["info"]["windows"] = wres
R["info"]["highest_eye_plus_hop"] = max(p["parts"][0]["z1"] for p in P if p["kind"] == "deck") + EYE + MV["hop"]
if R["info"]["highest_eye_plus_hop"] >= BOX["wall_h"]: err("BOX: highest eye + hop reaches the box wall top")
cover_fp = sum((q["x1"] - q["x0"]) * (q["y1"] - q["y0"]) for _, q in parts_flat if q["role"] not in ("lintel",)) \
    + sum(p["ramp"]["run"] * p["ramp"]["width"] for p in P if p["kind"] == "deck")
R["info"]["footprint_pct"] = round(cover_fp / ((X1 - X0) * (Y1 - Y0)) * 100, 1)

json.dump(R, open(os.path.join(MAPS, "arena_v2_checks.json"), "w"), indent=1, default=float)
np.save(os.path.join(MAPS, "_arena_v2_cache.npy"), np.column_stack([S, expo]))

# ------------------------------------------------------------------------------------------------ print
print(f"ERRORS {len(R['errors'])}"); [print("  " + e) for e in R["errors"]]
print(f"WARNINGS {len(R['warnings'])}"); [print("  " + w) for w in R["warnings"]]
I = R["info"]
print("spawn LOS", I["spawn_los"]); print("exposure", I["exposure"]); print("sight", I["sight"]); print("longest", I["longest_lines"])
print("cover distance", I["cover_distance"]); print("footprint %", I["footprint_pct"], "| highest eye+hop", I["highest_eye_plus_hop"])
for b in I["balance"]: print("balance", b)
for g in I["gaps"]: print("gap", g)
for r in I["ramps"]: print("ramp", r)
for p in I["perches"]: print("high", p)
for w in I["windows"]: print("window", w["window"], w["sill_centre"], [(v["side"], v["floor_seen_pct"], v["sees_spots"]) for v in w["views"]])
print("close pairs", [(a, b, g, k) for a, b, g, k in I["close_pairs"] if k != "lane"])
