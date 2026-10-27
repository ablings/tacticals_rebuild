"""Second pass: crouched exposure, sightline lengths, what each spawn sees, peek checks. Reads grids.npz + geom."""
import json, math, numpy as np
from geom import pieces, barrels, spawns, HALF_W, HALF_L
g = np.load('grids.npz'); tall, low, wb, samp, expo = g['tall'], g['low'], g['wallbump'], g['samp'], g['expo']
es, ns = g['es'], g['ns']; RES = 0.5
solid = tall | low | wb; free = ~solid
EE, NNg = np.meshgrid(es, ns)

def to_idx(e, n):
    return int(round((n + HALF_L) / RES - 0.5)), int(round((e + HALF_W) / RES - 0.5))
def vis(block, src, T, n=240):
    t = np.linspace(0, 1, n)[:, None]
    pz = src[0] + (T[:, 0][None] - src[0]) * t; px = src[1] + (T[:, 1][None] - src[1]) * t
    return ~block[pz.round().astype(int).clip(0, len(ns) - 1), px.round().astype(int).clip(0, len(es) - 1)].any(0)

# crouched exposure (both eyes 2.6: everything blocks)
cexp = np.array([vis(solid, c, samp).mean() * 100 for c in samp])
# sightline lengths (standing)
L = []
for c in samp[::3]:
    v = vis(tall | wb, c, samp); d = np.hypot(samp[v, 0] - c[0], samp[v, 1] - c[1]) * RES; L.append(d)
L = np.concatenate(L)

def rect(q, pad):
    return (np.abs(EE - q['e']) <= q['w'] / 2 + pad) & (np.abs(NNg - q['n']) <= q['d'] / 2 + pad)

# What each spawn sees: for every piece, can a standing spawn eye see a standing body at ANY spot hugging that piece?
# (spot = free cells 1.2-2.2 studs from the piece's edge)
spawn_sees = {}
for s in ('SpawnA', 'SpawnB'):
    src = np.array(to_idx(spawns[s]['e'], spawns[s]['n']))
    rows = []
    for q in pieces + barrels:
        ring = np.argwhere(rect(q, 2.2) & ~rect(q, 1.0) & free)
        v = vis(tall | wb, src, ring)
        rows.append((q.get('id'), round(float(v.mean() * 100))))
    spawn_sees[s] = rows
    # share of the enemy half seen
    half = samp[:, 0] > len(ns) / 2 if s == 'SpawnA' else samp[:, 0] < len(ns) / 2
    v = vis(tall | wb, src, samp)
    spawn_sees[s + '_enemy_half_pct'] = round(float(v[half].mean() * 100), 1)
    spawn_sees[s + '_own_half_pct'] = round(float(v[~half].mean() * 100), 1)
    # how far forward can a spawn see along its own long axis
    spawn_sees[s + '_crouch_floor_pct'] = round(float(vis(solid, src, samp).mean() * 100), 1)

# Peek check for pillars: from the two side spots of each pillar (1.6 out past each side edge, on the enemy-facing side),
# how much floor in the enemy direction does each side see?  Equal sides = a two-way peek.
peek = []
for q in [p for p in pieces if p['kind'] in ('pillar', 'block', 'wall')]:
    out = {}
    for side, sgn in (('west', -1), ('east', 1)):
        for face, fs in (('southface', -1), ('northface', 1)):
            e = q['e'] + sgn * (q['w'] / 2 + 0.4); n = q['n'] + fs * (q['d'] / 2 + 1.0)   # peeking: centre 0.4 past the edge
            i, j = to_idx(e, n)
            if solid[i, j]: out[side + '_' + face] = None; continue
            v = vis(tall | wb, np.array([i, j]), samp)
            ahead = (samp[:, 0] - i) * fs > 0     # the half beyond the piece
            out[side + '_' + face] = round(float(v[ahead].mean() * 100))
    # is a low wall blocking a side?
    peek.append(dict(id=q['id'], kind=q['kind'], **out))

res = dict(crouch_exposure=dict(min=round(float(cexp.min()), 1), mean=round(float(cexp.mean()), 1), max=round(float(cexp.max()), 1)),
           sightline=dict(median=round(float(np.median(L)), 1), p90=round(float(np.percentile(L, 90)), 1), max=round(float(L.max()), 1),
                          over60_pct=round(float((L > 60).mean() * 100), 1)),
           spawn_sees=spawn_sees, peek=peek)
json.dump(res, open('metrics2.json', 'w'), indent=1)
np.save('cexp.npy', cexp)
print(json.dumps({k: res[k] for k in ('crouch_exposure', 'sightline')}, indent=1))
for s in ('SpawnA', 'SpawnB'):
    print(s, 'enemy half', spawn_sees[s + '_enemy_half_pct'], 'own half', spawn_sees[s + '_own_half_pct'], 'crouch', spawn_sees[s + '_crouch_floor_pct'])
    print('  pieces seen (% of hug ring):', [r for r in spawn_sees[s] if r[1] > 0])
for p in peek: print(p)
