"""Read-only analysis of the Warehouse map (Tacticals tutorial place), from warehouse_dump.json.
Outputs: metrics.json, grids.npz. Plan coords from geom.py (e east, n north, heights above floor)."""
import json, math, numpy as np
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from geom import pieces, barrels, camskin, spawns, HALF_W, HALF_L, CEIL

RES = 0.5
es = np.arange(-HALF_W + RES / 2, HALF_W, RES)
ns = np.arange(-HALF_L + RES / 2, HALF_L, RES)
NE, NN = len(es), len(ns)
EE, NNg = np.meshgrid(es, ns)          # [n, e]

def rect_mask(q, pad=0.0):
    return (np.abs(EE - q['e']) <= q['w'] / 2 + pad) & (np.abs(NNg - q['n']) <= q['d'] / 2 + pad)

tall = np.zeros(EE.shape, bool); low = np.zeros(EE.shape, bool); wallbump = np.zeros(EE.shape, bool)
for q in pieces:
    (tall if q['h'] >= 5 else low)[rect_mask(q)] = True
for b in barrels:
    low[rect_mask(b)] = True
for c in camskin:
    m = rect_mask(c); wallbump |= m
solid = tall | low | wallbump
free = ~solid

STAND_EYE, CROUCH_EYE = 4.6, 2.6      # R15 eye standing; crouched behind 3.4 low cover (eye under its top)
SPRINT, WALK, CROUCH, DASH = 20.0, 10.0, 4.8, 24.0
R_BODY = 1.0                          # R15 half-width

def to_idx(e, n):
    return int(np.clip(round((n + HALF_L) / RES - 0.5), 0, NN - 1)), int(np.clip(round((e + HALF_W) / RES - 0.5), 0, NE - 1))

# ---------- walk graph (body radius 1, edge of the room too) ----------
def walk_grid(block):
    dt = ndimage.distance_transform_edt(~block) * RES
    border = np.minimum.reduce([EE + HALF_W, HALF_W - EE, NNg + HALF_L, HALF_L - NNg])
    return (dt > R_BODY) & (border > R_BODY)

def dist_field(walk, src, low_cells=None, vault_pen=0.0):
    idx = -np.ones(walk.shape, int); cells = np.argwhere(walk); idx[walk] = np.arange(len(cells))
    rows, cols, w = [], [], []
    for dn, de in [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (1, 2), (2, -1), (1, -2)]:
        i0, i1 = 0, NN - dn                      # dn >= 0 always
        j0, j1 = max(0, -de), NE - max(0, de)
        A = idx[i0:i1, j0:j1]; B = idx[i0 + dn:i1 + dn, j0 + de:j1 + de]
        m = (A >= 0) & (B >= 0)
        rows.append(A[m]); cols.append(B[m]); w.append(np.full(m.sum(), math.hypot(dn, de) * RES))
    r = np.concatenate(rows); c = np.concatenate(cols); ww = np.concatenate(w)
    if low_cells is not None:
        lc = low_cells[walk]
        ww = ww + (lc[r] | lc[c]) * vault_pen / 4.0   # ~4 grid steps across a low wall's blocked band
    G = coo_matrix((np.concatenate([ww, ww]), (np.concatenate([r, c]), np.concatenate([c, r]))), shape=(len(cells), len(cells))).tocsr()
    si = idx[src]
    if si < 0:
        d = np.hypot(cells[:, 0] - src[0], cells[:, 1] - src[1]); si = int(np.argmin(d))
    dd = dijkstra(G, indices=si)
    out = np.full(walk.shape, np.inf); out[walk] = dd
    return out

walk_novault = walk_grid(solid)
walk_vault = walk_grid(tall | wallbump)            # low walls / barrels crossable by vaulting
low_zone = walk_vault & ~walk_novault
VAULT_PEN = 0.34 * SPRINT                         # a vault costs ~0.34 s: same as this many studs of sprint

D = {}
for s in ('SpawnA', 'SpawnB'):
    src = to_idx(spawns[s]['e'], spawns[s]['n'])
    D[s] = {'novault': dist_field(walk_novault, src), 'vault': dist_field(walk_vault, src, low_zone, VAULT_PEN)}

def t_at(field, e, n):
    i, j = to_idx(e, n)
    win = field[max(0, i - 6):i + 7, max(0, j - 6):j + 7]
    return float(np.min(win))

# ---------- visibility ----------
def los_grid(block, sub_step=4):
    sub = np.zeros(block.shape, bool); sub[::sub_step, ::sub_step] = True
    cells = np.argwhere(sub & free)
    return cells

def visible_from(block, src, targets, n=220):
    t = np.linspace(0, 1, n)[:, None]
    pz = src[0] + (targets[:, 0][None] - src[0]) * t; px = src[1] + (targets[:, 1][None] - src[1]) * t
    b = block[pz.round().astype(int), px.round().astype(int)].any(0)
    return ~b

block_stand = tall | wallbump
block_crouch = solid
samp = los_grid(block_stand)
expo = np.full(len(samp), np.nan)
for k, c in enumerate(samp):
    expo[k] = visible_from(block_stand, c, samp).mean() * 100

# spawn zones: free cells within 4 studs of each pad
def zone(s, r=4.0):
    m = (np.hypot(EE - spawns[s]['e'], NNg - spawns[s]['n']) <= r) & free
    return np.argwhere(m)
zA, zB = zone('SpawnA'), zone('SpawnB')
pairs = 0; tot = 0
for c in zA[::2]:
    v = visible_from(block_stand, c, zB[::2]); pairs += v.sum(); tot += len(v)
spawn_los = pairs / tot * 100
spawn_view = {}
for s in ('SpawnA', 'SpawnB'):
    c = np.array(to_idx(spawns[s]['e'], spawns[s]['n']))
    spawn_view[s] = {'stand_floor_pct': float(visible_from(block_stand, c, samp).mean() * 100),
                     'sees_centre_stand': bool(visible_from(block_stand, c, np.array([to_idx(0, 0)]))[0])}

# ---------- cover distance ----------
waist = solid.copy()
border = np.zeros_like(waist); border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
d_cover_walls = ndimage.distance_transform_edt(~(waist | border)) * RES
d_cover_pieces = ndimage.distance_transform_edt(~(tall | low)) * RES
d_tall = ndimage.distance_transform_edt(~tall) * RES
fm = free
cover_stats = dict(max_walls=float(d_cover_walls[fm].max()), mean_walls=float(d_cover_walls[fm].mean()),
                   p90_walls=float(np.percentile(d_cover_walls[fm], 90)),
                   max_pieces=float(d_cover_pieces[fm].max()), mean_pieces=float(d_cover_pieces[fm].mean()),
                   max_tall=float(d_tall[fm].max()), mean_tall=float(d_tall[fm].mean()))

# ---------- pairing: each low wall vs nearest tall piece (edge gap) ----------
def edge_gap(a, b):
    ge = max(0.0, abs(a['e'] - b['e']) - (a['w'] + b['w']) / 2)
    gn = max(0.0, abs(a['n'] - b['n']) - (a['d'] + b['d']) / 2)
    return math.hypot(ge, gn), ge, gn

pair_rows = []
for L in [q for q in pieces if q['kind'] == 'low']:
    best = min(((edge_gap(L, T), T) for T in pieces if T['kind'] != 'low'), key=lambda x: x[0][0])
    bestP = min(((edge_gap(L, T), T) for T in pieces if T['kind'] == 'pillar'), key=lambda x: x[0][0])
    (g, ge, gn), T = best
    side = 'beside' if gn == 0 and ge > 0 else ('in front/behind' if ge == 0 else 'diagonal')
    pair_rows.append(dict(low=L['id'], e=L['e'], n=L['n'], nearest_tall=T['id'], tall_kind=T['kind'], gap=round(g, 2),
                          how=side, nearest_pillar=bestP[1]['id'], pillar_gap=round(bestP[0][0], 2)))

pillar_rows = []
for P in [q for q in pieces if q['kind'] == 'pillar']:
    lows = sorted(((edge_gap(P, L)[0], L['id']) for L in pieces if L['kind'] == 'low'))
    pillar_rows.append(dict(pillar=P['id'], nearest_low=lows[0][1], gap=round(lows[0][0], 2), lows_within_3=[l for g, l in lows if g <= 3]))

# ---------- cover-to-cover hops ----------
allc = pieces + barrels
hop = []
for a in pieces:
    others = sorted(((edge_gap(a, b)[0], b['id']) for b in allc if b is not a))
    hop.append(dict(id=a['id'], kind=a['kind'], nearest=others[0][1], gap=round(others[0][0], 2),
                    second=others[1][1], gap2=round(others[1][0], 2)))

# gaps between neighbouring pieces (clear straight segment between facing edges), < 16 studs
gaps = []
for i, a in enumerate(allc):
    for b in allc[i + 1:]:
        g, ge, gn = edge_gap(a, b)
        if 0 < g < 16 and (ge == 0 or gn == 0):
            # midpoint of the gap must be free of other pieces
            me = (a['e'] + b['e']) / 2; mn = (a['n'] + b['n']) / 2
            ii, jj = to_idx(me, mn)
            if solid[ii, jj]: continue
            gaps.append(dict(a=a['id'], b=b['id'], gap=round(g, 2), axis='e' if gn == 0 else 'n'))
# gaps to the side walls (lanes along the walls)
wall_gaps = []
for a in allc:
    wall_gaps.append(dict(id=a['id'], west=round(a['e'] - a['w'] / 2 + HALF_W, 2), east=round(HALF_W - a['e'] - a['w'] / 2, 2),
                          south=round(a['n'] - a['d'] / 2 + HALF_L, 2), north=round(HALF_L - a['n'] - a['d'] / 2, 2)))

# ---------- timings ----------
def piece_time(field, q):
    m = rect_mask(q, pad=R_BODY + 1.2) & ~rect_mask(q, pad=R_BODY - 0.01)
    v = field[m]; v = v[np.isfinite(v)]
    return float(v.min()) if len(v) else float('inf')

times = []
for q in pieces + barrels:
    tA = piece_time(D['SpawnA']['vault'], q) / SPRINT; tB = piece_time(D['SpawnB']['vault'], q) / SPRINT
    times.append(dict(id=q['id'], kind=q['kind'], e=q['e'], n=q['n'], tA=round(tA, 2), tB=round(tB, 2), diff=round(tA - tB, 2)))
centre = {k: dict(novault_sprint=round(t_at(D[k]['novault'], 0, 0) / SPRINT, 2), vault_sprint=round(t_at(D[k]['vault'], 0, 0) / SPRINT, 2),
                  novault_walk=round(t_at(D[k]['novault'], 0, 0) / WALK, 2), path_len=round(t_at(D[k]['novault'], 0, 0), 1))
          for k in ('SpawnA', 'SpawnB')}
straight = math.hypot(spawns['SpawnA']['e'], spawns['SpawnA']['n'])
s2s = round(t_at(D['SpawnA']['novault'], spawns['SpawnB']['e'], spawns['SpawnB']['n']), 1)

# band exposure along the long axis (10-stud bands)
bands = []
sn = ns[samp[:, 0]]
for lo in range(-57, 57, 10):
    m = (sn >= lo) & (sn < lo + 10)
    if m.any(): bands.append((lo, round(float(np.nanmean(expo[m])), 1)))

# who first: contested area map
tAg = D['SpawnA']['vault'] / SPRINT; tBg = D['SpawnB']['vault'] / SPRINT

metrics = dict(
    room=dict(inside_e=2 * HALF_W, inside_n=2 * HALF_L, ceiling=CEIL, floor_area=2 * HALF_W * 2 * HALF_L),
    footprint_pct=dict(all=round(float((tall | low).mean() * 100), 1), tall=round(float(tall.mean() * 100), 1), low=round(float(low.mean() * 100), 1)),
    counts={k: sum(1 for q in pieces if q['kind'] == k) for k in ('pillar', 'block', 'wall', 'low')} | {'barrel': len(barrels)},
    spawns=spawns, spawn_view=spawn_view, spawn_to_spawn_los_pct=round(spawn_los, 2),
    spawn_straight_to_centre=round(straight, 1), spawn_to_spawn_path=s2s,
    centre=centre, cover=cover_stats,
    exposure=dict(min=round(float(np.nanmin(expo)), 1), mean=round(float(np.nanmean(expo)), 1), max=round(float(np.nanmax(expo)), 1),
                  p10=round(float(np.nanpercentile(expo, 10)), 1), p90=round(float(np.nanpercentile(expo, 90)), 1), bands=bands),
    pairing=dict(low_walls=pair_rows, pillars=pillar_rows), hops=hop, gaps=sorted(gaps, key=lambda g: g['gap']), wall_gaps=wall_gaps,
    times=sorted(times, key=lambda t: t['tA']),
)
import os
PFX = os.environ.get('WH_PREFIX', '')
json.dump(metrics, open(PFX + 'metrics.json', 'w'), indent=1)
np.savez_compressed(PFX + 'grids.npz', tall=tall, low=low, wallbump=wallbump, samp=samp, expo=expo, tA=tAg, tB=tBg,
                    dcov=d_cover_walls, es=es, ns=ns)
print(json.dumps({k: metrics[k] for k in ('room', 'footprint_pct', 'counts', 'spawn_view', 'spawn_to_spawn_los_pct', 'spawn_straight_to_centre',
                                         'spawn_to_spawn_path', 'centre', 'cover', 'exposure')}, indent=1))
