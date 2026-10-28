"""Check the House layout in 3D (no Studio). Reads notes/maps/house_layout.json (or a read-back from Studio), writes
notes/maps/house_checks.json / .txt and _house_cache.npz (images: house_plot.py), prints a summary.

    python -I tools/house_layout.py && python -I tools/house_check.py [layout.json] [tag]

Model: a 0.5-stud voxel grid of every collision part (boxes, stair ramps, door leaves turned on their hinges).
  walk        a body (radius 1, 5 tall) stands on a voxel with 5 studs of headroom and nothing between 1.5 and 5 within 1 stud;
              moves to a neighbour (16 directions) if the floor rises or falls <= 1.5 (stairs are ramps). Player barriers block
              the walk. Vault graph: low furniture + the pass-through sill are crossable at +0.34 s.
  sight       eye 4.6 above the floor (crouched 2.6), voxel ray march (0.3 step) through everything but the player barriers.
  timing      Dijkstra at sprint (20/s) from each team's spawn slots (1v1 slot 1; 2v2 slots 1-2; 3v3 slots 1-3).
Checks (Edward's brief):
  spawns      no line of sight between any two enemy slots (eye-eye, eye-chest, crouched); no landing cell sees a slot
  fairness    per mode, A vs B within 10 %: time to first contact (the earliest mutually visible pair, each side's own
              arrival time), exposure of each side's half (cells it reaches first), spawn sight (floor seen from the slots),
              spawn exposure (floor that sees a slot)
  reach       every playable room reached from both spawns; the ensuite (door closed) not reached; nothing outside the shell
"""
import json, math, os, sys, time
import numpy as np
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(os.path.dirname(HERE), "notes", "maps")
LAYOUT_IN = sys.argv[1] if len(sys.argv) > 1 else os.path.join(MAPS, "house_layout.json")
TAG = ("_" + sys.argv[2]) if len(sys.argv) > 2 else ""
D = json.load(open(LAYOUT_IN))
MV = D["movement"]
EYE, CHEST, CROUCH = MV["eye"], MV["chest"], MV["crouch_eye"]
SPRINT, VAULT_S = MV["sprint"], MV["vault_s"]
RES = 0.5
X0, X1, Y0, Y1, Z0, Z1 = -43.0, 43.0, -33.0, 33.0, -1.5, 28.5
NX, NY, NZ = int((X1 - X0) / RES), int((Y1 - Y0) / RES), int((Z1 - Z0) / RES)
xs = X0 + (np.arange(NX) + 0.5) * RES
ys = Y0 + (np.arange(NY) + 0.5) * RES
zs = Z0 + (np.arange(NZ) + 0.5) * RES
t0 = time.time()

# ------------------------------------------------------------------------------------------------ rasterise
solid_walk = np.zeros((NX, NY, NZ), bool)     # what a body collides with
solid_vis = np.zeros((NX, NY, NZ), bool)      # what blocks sight / bullets (no player barriers)
lowmask = np.zeros((NX, NY, NZ), bool)        # low furniture + pass-through sills (vault graph removes these)
EPS = 1e-6


def rng(a, b, o, n):
    i0 = int(math.floor((a - o) / RES + EPS)); i1 = int(math.ceil((b - o) / RES - EPS))
    return max(i0, 0), min(i1, n)


def mark(arrs, x0, x1, y0, y1, z0, z1):
    i0, i1 = rng(x0, x1, X0, NX); j0, j1 = rng(y0, y1, Y0, NY); k0, k1 = rng(z0, z1, Z0, NZ)
    for a in arrs:
        a[i0:i1, j0:j1, k0:k1] = True


for p in D["parts"]:
    role = p["role"]
    arrs = [solid_walk] if role == "barrier" else [solid_walk, solid_vis]
    if p["shape"] == "box":
        mark(arrs, p["x0"], p["x1"], p["y0"], p["y1"], p["z0"], p["z1"])
        if (role == "furniture" and p["cover"] == "low") or (role == "sill" and "Pass_" in p["id"]):
            mark([lowmask], p["x0"], p["x1"], p["y0"], p["y1"], p["z0"], p["z1"])
    elif p["shape"] == "ramp":
        i0, i1 = rng(p["x0"], p["x1"], X0, NX); j0, j1 = rng(p["y0"], p["y1"], Y0, NY)
        for j in range(j0, j1):
            # conservative: the cell's highest point under the slope
            yy = np.array([Y0 + j * RES, Y0 + (j + 1) * RES])
            t = np.clip((yy - p["foot_y"]) / (p["top_y"] - p["foot_y"]), 0, 1)
            ztop = p["z0"] + (p["z1"] - p["z0"]) * t.max()
            k0, k1 = rng(p["z0"], ztop, Z0, NZ)
            for a in arrs:
                a[i0:i1, j, k0:k1] = True
    elif p["shape"] == "obox":
        c, s = math.cos(math.radians(p["yaw"])), math.sin(math.radians(p["yaw"]))
        uu = np.arange(-p["w"] / 2, p["w"] / 2 + 0.001, 0.1); vv = np.arange(-p["d"] / 2, p["d"] / 2 + 0.001, 0.1)
        U, V = np.meshgrid(uu, vv)
        px = p["cx"] + U * c - V * s; py = p["cy"] + U * s + V * c
        ii = ((px - X0) / RES).astype(int); jj = ((py - Y0) / RES).astype(int)
        k0, k1 = rng(p["z0"], p["z1"], Z0, NZ)
        for a in arrs:
            a[ii.ravel(), jj.ravel(), k0:k1] = True

# ------------------------------------------------------------------------------------------------ standable cells
H = int(round(MV["headroom"] / RES))      # 10 cells of headroom
STEPC = 3                                 # 1.5 studs: what the body steps over / up
RB = int(round(MV["body_r"] / RES))       # 2 cells


def valid_cells(sw):
    free = ~sw
    cs = np.concatenate([np.zeros((NX, NY, 1), int), np.cumsum(free, axis=2)], axis=2)

    def free_run(a, b):   # all free in [k+a, k+b)
        k = np.arange(NZ)
        lo = np.clip(k + a, 0, NZ); hi = np.clip(k + b, 0, NZ)
        cnt = cs[:, :, hi] - cs[:, :, lo]
        return (cnt == (hi - lo)[None, None, :]) & ((k + b) <= NZ)[None, None, :]

    below = np.zeros_like(sw); below[:, :, 1:] = sw[:, :, :-1]
    stand = free & below & free_run(0, H)
    body = free_run(STEPC, H)
    yy, xx = np.mgrid[-RB:RB + 1, -RB:RB + 1]
    disk = (xx ** 2 + yy ** 2) <= RB * RB + 0.01
    body_ok = ndimage.binary_erosion(body, structure=disk[:, :, None], border_value=0)
    return stand & body_ok


valid = valid_cells(solid_walk)
valid_v = valid_cells(solid_walk & ~lowmask)
OFFS = [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (1, 2), (2, -1), (1, -2)]


def graph(vmask, pen_mask=None, pen=0.0):
    idx = -np.ones(vmask.shape, np.int64); cells = np.argwhere(vmask); idx[vmask] = np.arange(len(cells))
    rows, cols, ws = [], [], []
    for di, dj in OFFS:
        for dk in range(-STEPC, STEPC + 1):
            def sl(d, n): return slice(max(0, -d), n - max(0, d)), slice(max(0, d), n - max(0, -d))
            (ai, bi), (aj, bj), (ak, bk) = sl(di, NX), sl(dj, NY), sl(dk, NZ)
            sa = (ai, aj, ak); sb = (bi, bj, bk)
            A = idx[sa]; B = idx[sb]
            m = (A >= 0) & (B >= 0)
            a = A[m]; b = B[m]
            w = math.sqrt(di * di + dj * dj + dk * dk) * RES
            ww = np.full(len(a), w)
            if pen_mask is not None:
                pa = pen_mask[sa][m] | pen_mask[sb][m]
                ww = ww + pa * pen / 4.0
            rows.append(a); cols.append(b); ws.append(ww)
    r = np.concatenate(rows); c = np.concatenate(cols); w = np.concatenate(ws)
    G = coo_matrix((np.concatenate([w, w]), (np.concatenate([r, c]), np.concatenate([c, r]))), shape=(len(cells), len(cells))).tocsr()
    return G, idx, cells


G_n, idx_n, cells_n = graph(valid)
# vault penalty: cells whose body box overlaps a low piece (dilated footprint)
low_foot = ndimage.binary_dilation(lowmask.any(axis=2), iterations=RB + 1)
pen3 = np.repeat(low_foot[:, :, None], NZ, axis=2) & valid_v
G_v, idx_v, cells_v = graph(valid_v, pen3, VAULT_S * SPRINT)
print(f"grid {NX}x{NY}x{NZ}, nodes {len(cells_n)} / vault {len(cells_v)}, {time.time() - t0:.1f}s")


def nearest_node(idx, cells, x, y, z):
    i = int((x - X0) / RES); j = int((y - Y0) / RES); k = int((z - Z0) / RES + 0.5)
    for r in range(0, 12):
        best = None
        for di in range(-r, r + 1):
            for dj in range(-r, r + 1):
                if max(abs(di), abs(dj)) != r: continue
                for dk in range(-3, 4):
                    ii, jj, kk = i + di, j + dj, k + dk
                    if 0 <= ii < NX and 0 <= jj < NY and 0 <= kk < NZ and idx[ii, jj, kk] >= 0:
                        d = di * di + dj * dj + dk * dk * 0.1
                        if best is None or d < best[0]: best = (d, idx[ii, jj, kk])
        if best: return int(best[1]), r * RES
    return None, None


def node_xyz(cells, n):
    i, j, k = cells[n]
    return xs[i], ys[j], Z0 + k * RES      # floor height = bottom of the standing cell


# ------------------------------------------------------------------------------------------------ samples + sight
SUB = 4    # every 2 studs
_fr = dijkstra(G_n, indices=[nearest_node(idx_n, cells_n, D["spawns"]["A"]["x"], D["spawns"]["A"]["y"], D["spawns"]["A"]["z"])[0]])[0]
reach_mask = np.zeros(valid.shape, bool); reach_mask[tuple(cells_n[np.isfinite(_fr)].T)] = True
samp_sel = np.argwhere(reach_mask)
keep = (samp_sel[:, 0] % SUB == 0) & (samp_sel[:, 1] % SUB == 0)
samp = samp_sel[keep]
# one sample per column-level: drop stacked duplicates within 1 stud
sx = xs[samp[:, 0]]; sy = ys[samp[:, 1]]; sz = Z0 + samp[:, 2] * RES
order = np.lexsort((sz, sy, sx))
samp, sx, sy, sz = samp[order], sx[order], sy[order], sz[order]
dup = np.zeros(len(samp), bool)
dup[1:] = (sx[1:] == sx[:-1]) & (sy[1:] == sy[:-1]) & (np.abs(sz[1:] - sz[:-1]) < 1.01)
samp, sx, sy, sz = samp[~dup], sx[~dup], sy[~dup], sz[~dup]
P = len(samp)
print("samples", P)


def vis_pairs(A, B, step=0.3):
    """A, B: (n, 3) points; returns bool visible."""
    out = np.zeros(len(A), bool)
    d = np.linalg.norm(B - A, axis=1)
    order = np.argsort(d)
    CH = 40000
    for s in range(0, len(order), CH):
        ii = order[s:s + CH]
        n = max(2, int(math.ceil(d[ii].max() / step)) + 1)
        t = np.linspace(0, 1, n)[1:-1][:, None]
        a = A[ii]; b = B[ii]
        px = ((a[:, 0][None] + (b[:, 0] - a[:, 0])[None] * t - X0) / RES).astype(np.int32)
        py = ((a[:, 1][None] + (b[:, 1] - a[:, 1])[None] * t - Y0) / RES).astype(np.int32)
        pz = ((a[:, 2][None] + (b[:, 2] - a[:, 2])[None] * t - Z0) / RES).astype(np.int32)
        np.clip(px, 0, NX - 1, out=px); np.clip(py, 0, NY - 1, out=py); np.clip(pz, 0, NZ - 1, out=pz)
        hit = solid_vis[px, py, pz].any(axis=0)
        out[ii] = ~hit
    return out


eyes = np.stack([sx, sy, sz + EYE], 1)
iu, ju = np.triu_indices(P, 1)
# skip pairs that can't see each other cheaply? (no: the voxel march is the test)
vis_u = vis_pairs(eyes[iu], eyes[ju])
V = np.zeros((P, P), bool); V[iu, ju] = vis_u; V |= V.T
expo = V.mean(axis=1) * 100
print(f"sight matrix done {time.time() - t0:.1f}s")

# ------------------------------------------------------------------------------------------------ spawns
SP = D["spawns"]
MODES = {"1v1": 1, "2v2": 2, "3v3": 3}
report = dict(layout=os.path.basename(LAYOUT_IN), samples=int(P), nodes=int(len(cells_n)))
slot_pts = {}
for t in ("A", "B"):
    slot_pts[t] = [(x, y, SP[t]["z"]) for x, y in SP[t]["slots"]]

# slot <-> slot sight (all 9 pairs; eye-eye, eye-chest, crouch-eye to eye)
sp_rows = []
for a in slot_pts["A"]:
    for b in slot_pts["B"]:
        for ha, hb, nm in ((EYE, EYE, "eye-eye"), (EYE, CHEST, "eyeA-chestB"), (CHEST, EYE, "chestA-eyeB"), (CROUCH, CROUCH, "crouch")):
            v = vis_pairs(np.array([[a[0], a[1], a[2] + ha]]), np.array([[b[0], b[1], b[2] + hb]]))[0]
            if v: sp_rows.append(dict(a=a, b=b, kind=nm))
report["spawn_to_spawn_visible"] = sp_rows

# which samples see each slot (their eye to the slot's chest or eye)
def watchers(t, nslots):
    m = np.zeros(P, bool)
    for (x, y, z) in slot_pts[t][:nslots]:
        for h in (CHEST, EYE):
            tgt = np.repeat([[x, y, z + h]], P, 0)
            m |= vis_pairs(eyes, tgt)
    return m


def seen_from(t, nslots):
    m = np.zeros(P, bool)
    for (x, y, z) in slot_pts[t][:nslots]:
        src = np.repeat([[x, y, z + EYE]], P, 0)
        m |= vis_pairs(src, eyes)
    return m


def team_field(t, nslots, G, idx, cells):
    srcs = []
    for (x, y, z) in slot_pts[t][:nslots]:
        n, off = nearest_node(idx, cells, x, y, z)
        assert n is not None, (t, x, y, z)
        srcs.append(n)
    dd = dijkstra(G, indices=srcs, min_only=True)
    return dd


def field_at_samples(dd, idx):
    v = idx[samp[:, 0], samp[:, 1], samp[:, 2]]
    out = np.full(P, np.inf)
    ok = v >= 0
    out[ok] = dd[v[ok]]
    # samples blocked in the vault graph (should not happen: the vault graph has more cells)
    return out


def within(a, b, tol=0.10):
    return abs(a - b) / max(a, b, 1e-9) <= tol + 1e-9


def pct(a, b):
    return round((a - b) / max(a, b, 1e-9) * 100, 1)


modes = {}
for mname, ns in MODES.items():
    fA = team_field("A", ns, G_v, idx_v, cells_v); fB = team_field("B", ns, G_v, idx_v, cells_v)
    tA = field_at_samples(fA, idx_v) / SPRINT; tB = field_at_samples(fB, idx_v) / SPRINT
    # first contact: min over visible pairs of max(tA[a], tB[b])
    big = 1e9
    tAm = np.where(np.isfinite(tA), tA, big); tBm = np.where(np.isfinite(tB), tB, big)
    T = np.maximum(tAm[:, None], tBm[None, :])
    T = np.where(V, T, big)
    flat = np.argsort(T, axis=None)[:40]
    ia, ib = np.unravel_index(flat, T.shape)
    best = []
    for a_, b_ in zip(ia, ib):
        best.append(dict(a=[round(sx[a_], 1), round(sy[a_], 1), round(sz[a_], 1)], b=[round(sx[b_], 1), round(sy[b_], 1), round(sz[b_], 1)],
                         tA=round(float(tAm[a_]), 2), tB=round(float(tBm[b_]), 2)))
    c0 = best[0]
    # the two kinds of first contact: A there first (A waits, B walks in) and B there first; mirror twins in a fair map
    Ta_first = float(np.min(np.where(tAm[:, None] <= tBm[None, :], T, big)))
    Tb_first = float(np.min(np.where(tBm[None, :] <= tAm[:, None], T, big)))
    # robust: the mean over the 10 earliest contacts
    tA10 = float(np.mean([b["tA"] for b in best[:10]])); tB10 = float(np.mean([b["tB"] for b in best[:10]]))
    halfA = tA < tB; halfB = tB < tA
    Tc = max(c0["tA"], c0["tB"]) + 0.5
    preA = tA <= Tc; preB = tB <= Tc
    apA = float(expo[preA].mean()); apB = float(expo[preB].mean())
    eA = float(expo[halfA].mean()); eB = float(expo[halfB].mean())
    wA = watchers("A", ns); wB = watchers("B", ns)
    sA = seen_from("A", ns); sB = seen_from("B", ns)
    # the enemy's earliest arrival on a cell that sees the spawn (spawn-camp distance)
    campA = float(np.min(np.where(wA, tB, np.inf))); campB = float(np.min(np.where(wB, tA, np.inf)))
    row = dict(
        first_contact=dict(A=c0["tA"], B=c0["tB"], T=max(c0["tA"], c0["tB"]), diff_pct=pct(c0["tA"], c0["tB"]),
                           ok=within(c0["tA"], c0["tB"]), at=c0,
                           holder_A=round(Ta_first, 2), holder_B=round(Tb_first, 2), holder_diff_pct=pct(Ta_first, Tb_first),
                           holder_ok=within(Ta_first, Tb_first), mean10=dict(A=round(tA10, 2), B=round(tB10, 2), diff_pct=pct(tA10, tB10),
                                                                          ok=within(tA10, tB10)), first10=best[:10]),
        approach_exposure=dict(A=round(apA, 1), B=round(apB, 1), diff_pct=pct(apA, apB), ok=within(apA, apB),
                               cells=dict(A=int(preA.sum()), B=int(preB.sum()))),
        half_exposure=dict(A=round(eA, 1), B=round(eB, 1), diff_pct=pct(eA, eB), ok=within(eA, eB),
                           cells=dict(A=int(halfA.sum()), B=int(halfB.sum()))),
        spawn_sight=dict(A=round(float(sA.mean() * 100), 1), B=round(float(sB.mean() * 100), 1),
                         diff_pct=pct(sA.mean(), sB.mean()), ok=within(sA.mean(), sB.mean())),
        spawn_exposure=dict(A=round(float(wA.mean() * 100), 1), B=round(float(wB.mean() * 100), 1),
                            diff_pct=pct(wA.mean(), wB.mean()), ok=within(wA.mean(), wB.mean())),
        enemy_time_to_spawn_watch=dict(A_spawn_watched_by_B_after=round(campA, 2), B_spawn_watched_by_A_after=round(campB, 2),
                                       diff_pct=pct(campA, campB), ok=within(campA, campB)),
        spawn_to_spawn_path=dict(sprint_s=round(float(field_at_samples(fA, idx_v)[np.argmin(np.hypot(sx - slot_pts['B'][0][0], sy - slot_pts['B'][0][1]) + np.abs(sz - slot_pts['B'][0][2]))] / SPRINT), 2)),
    )
    modes[mname] = row
    if mname == "3v3":
        np.savez_compressed(os.path.join(MAPS, f"_house_cache{TAG}.npz"), sx=sx, sy=sy, sz=sz, expo=expo, tA=tA, tB=tB, wA=wA, wB=wB,
                            sA=sA, sB=sB)
report["modes"] = modes

# ------------------------------------------------------------------------------------------------ landing camp
def in_room(rid, x, y, z):
    r = next(r for r in D["rooms"] if r["id"] == rid)
    zf = D["storeys"][r["storey"]]["floor"]
    if abs(z - zf) > 1.0: return False
    return any(q["x0"] <= x <= q["x1"] and q["y0"] <= y <= q["y1"] for q in r["rects"])


ld_cells = [c for c in np.argwhere(valid) if in_room("LD", xs[c[0]], ys[c[1]], Z0 + c[2] * RES)]
camp = []
for t in ("A", "B"):
    for (x, y, z) in slot_pts[t]:
        for hh in (EYE, CROUCH):
            src = np.array([[xs[c[0]], ys[c[1]], Z0 + c[2] * RES + hh] for c in ld_cells])
            for ht in (CHEST, EYE, 1.0):
                tgt = np.repeat([[x, y, z + ht]], len(src), 0)
                v = vis_pairs(src, tgt)
                if v.any(): camp.append(dict(team=t, slot=[x, y], from_height=hh, target_height=ht, cells=int(v.sum())))
report["landing_sees_spawn"] = camp
report["landing_cells"] = len(ld_cells)

# ------------------------------------------------------------------------------------------------ reach
fA1 = team_field("A", 1, G_n, idx_n, cells_n); fB1 = team_field("B", 1, G_n, idx_n, cells_n)
reach = {}
for r in D["rooms"]:
    zf = D["storeys"][r["storey"]]["floor"]
    ok_any = []
    for q in r["rects"]:
        m = (cells_n[:, 0] >= int((q["x0"] - X0) / RES)) & (cells_n[:, 0] < int((q["x1"] - X0) / RES)) & \
            (cells_n[:, 1] >= int((q["y0"] - Y0) / RES)) & (cells_n[:, 1] < int((q["y1"] - Y0) / RES)) & \
            (np.abs(Z0 + cells_n[:, 2] * RES - zf) < 1.01)
        ok_any.append(m)
    m = np.any(ok_any, axis=0)
    reach[r["id"]] = dict(cells=int(m.sum()), from_A=int(np.isfinite(fA1[m]).sum()), from_B=int(np.isfinite(fB1[m]).sum()))
report["reach"] = reach
room_expo = {}
for r in D["rooms"]:
    m = np.array([in_room(r["id"], sx[i], sy[i], sz[i]) for i in range(P)])
    if m.any(): room_expo[r["id"]] = round(float(expo[m].mean()), 1)
report["room_exposure"] = room_expo
allA = np.isfinite(fA1)
pts = cells_n[allA]
px = xs[pts[:, 0]]; py = ys[pts[:, 1]]; pz = Z0 + pts[:, 2] * RES
sh = D["shell"]
outside = (px < sh["x0"]) | (px > sh["x1"]) | (py < sh["y0"]) | (py > sh["y1"]) | (pz < -0.5) | (pz > 17)
report["reached_cells"] = int(allA.sum()); report["reached_outside_shell"] = int(outside.sum())
report["outside_cells"] = [[round(float(a), 1), round(float(b), 1), round(float(c), 1)] for a, b, c in zip(px[outside], py[outside], pz[outside])][:60]
report["reached_B_from_A"] = bool(np.isfinite(fA1[nearest_node(idx_n, cells_n, *slot_pts['B'][0])[0]]))

# cover distance (farthest standing sample from any cover piece, 2D within its storey)
cov = [p for p in D["parts"] if p["role"] == "furniture" and p["cover"] in ("low", "tall")] + \
      [p for p in D["parts"] if p["role"] in ("wall", "sill")]
def cover_dist(x, y, z):
    best = 99
    for p in cov:
        if p["z1"] < z + 1 or p["z0"] > z + 3: continue
        dx = max(p["x0"] - x, 0, x - p["x1"]); dy = max(p["y0"] - y, 0, y - p["y1"])
        best = min(best, math.hypot(dx, dy))
    return best
cd = np.array([cover_dist(sx[i], sy[i], sz[i]) for i in range(P)])
report["cover_distance"] = dict(max=round(float(cd.max()), 1), mean=round(float(cd.mean()), 2),
                                worst=[round(float(sx[cd.argmax()]), 1), round(float(sy[cd.argmax()]), 1), round(float(sz[cd.argmax()]), 1)])
report["exposure"] = dict(mean=round(float(expo.mean()), 1), p10=round(float(np.percentile(expo, 10)), 1),
                          p90=round(float(np.percentile(expo, 90)), 1), max=round(float(expo.max()), 1))
# longest sight lines
L = np.hypot(sx[iu] - sx[ju], sy[iu] - sy[ju])
vv = vis_u
report["sight"] = dict(max=round(float(L[vv].max()), 1), p90=round(float(np.percentile(L[vv], 90)), 1),
                       median=round(float(np.median(L[vv])), 1))

# ------------------------------------------------------------------------------------------------ verdict
fails = []
if sp_rows: fails.append(f"spawn-to-spawn sight: {len(sp_rows)} slot pairs see each other")
if camp: fails.append(f"landing sees a spawn slot: {len(camp)}")
for m, r in modes.items():
    for k in ("first_contact", "approach_exposure", "spawn_sight", "spawn_exposure"):
        # first contact: judged on the holder pair (A-holds vs B-holds contact times). The single earliest pair and the mean of
        # the 10 earliest are reported only: in a point-symmetric plan they come from one of two mirror-twin pairs.
        ok = r[k]["ok"] if k != "first_contact" else r[k]["holder_ok"]
        if not ok: fails.append(f"{m} {k} off by {r[k]['diff_pct'] if k != 'first_contact' else r[k]['holder_diff_pct']} %")
for rid, rr in reach.items():
    if rid == "EN":
        if rr["from_A"] or rr["from_B"]: fails.append("ensuite reachable (its door must be closed)")
    elif rr["from_A"] == 0 or rr["from_B"] == 0:
        fails.append(f"room {rid} not reached ({rr})")
if report["reached_outside_shell"]: fails.append(f"{report['reached_outside_shell']} reachable cells outside the shell")
report["fails"] = fails
report["verdict"] = "PASS" if not fails else "FAIL"
json.dump(report, open(os.path.join(MAPS, f"house_checks{TAG}.json"), "w"), indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o))

lines = [f"House layout check ({report['layout']}): {report['verdict']}  ({time.time() - t0:.0f}s)"]
lines.append(f"nodes {len(cells_n)}, samples {P}, reached {report['reached_cells']} cells, outside shell {report['reached_outside_shell']}")
lines.append(f"spawn-to-spawn visible pairs: {len(sp_rows)}; landing ({len(ld_cells)} cells) sees a slot: {len(camp)}")
for m, r in modes.items():
    fc = r["first_contact"]
    lines.append(f"[{m}] contact when A holds {fc['holder_A']} s / when B holds {fc['holder_B']} s ({fc['holder_diff_pct']} %); first contact A {fc['A']} s / B {fc['B']} s ({fc['diff_pct']} %), mean of 10 A {fc['mean10']['A']} / B {fc['mean10']['B']} ({fc['mean10']['diff_pct']} %) at A{fc['at']['a']} B{fc['at']['b']}")
    for k in ("approach_exposure", "half_exposure", "spawn_sight", "spawn_exposure"):
        lines.append(f"      {k}: A {r[k]['A']} / B {r[k]['B']} ({r[k]['diff_pct']} %) {'ok' if r[k]['ok'] else 'OFF'}")
    e = r["enemy_time_to_spawn_watch"]
    lines.append(f"      enemy reaches a cell that sees the spawn after: A's spawn {e['A_spawn_watched_by_B_after']} s, B's {e['B_spawn_watched_by_A_after']} s; spawn-to-spawn sprint {r['spawn_to_spawn_path']['sprint_s']} s")
lines.append("reach: " + ", ".join(f"{k} {v['from_A']}/{v['from_B']}" for k, v in reach.items()))
lines.append("room exposure: " + str(room_expo))
lines.append("outside: " + str(report["outside_cells"][:12]))
lines.append(f"exposure {report['exposure']}, sight {report['sight']}, cover distance {report['cover_distance']}")
lines += ["FAIL: " + f for f in fails]
open(os.path.join(MAPS, f"house_checks{TAG}.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
