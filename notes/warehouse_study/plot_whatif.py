"""Current pairing vs the proposed pairing rule (analysis only; the Warehouse map itself is not changed)."""
import json, os, sys, copy, importlib, numpy as np, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
OUT = sys.argv[1]
os.environ.pop('WH_WHATIF', None)
import geom; cur = copy.deepcopy(geom.pieces)
mv = json.load(open('whatif_pairing2.json'))
new = copy.deepcopy(cur)
for q in new:
    if q['id'] in mv: q['e'], q['n'] = mv[q['id']]
COL = {'pillar': '#3b3f8f', 'block': '#2f7d6d', 'wall': '#8a5a2b', 'low': '#e0a526'}
mc = json.load(open('metrics.json'))['cover']; mw = json.load(open('whatif2_metrics.json'))['cover']
fig, axs = plt.subplots(1, 2, figsize=(12, 9))
for ax, P, title in ((axs[0], cur, f"Now: 6 of 6 pillars have a low wall within 2.5\nfarthest spot from cover {mc['max_walls']:.1f}, mean {mc['mean_walls']:.2f}"),
                     (axs[1], new, f"Rule applied (what-if): 2 of 6 pillars paired, 8 of 12 low walls alone\nfarthest spot from cover {mw['max_walls']:.1f}, mean {mw['mean_walls']:.2f}")):
    ax.add_patch(Rectangle((-40.5, -57), 81, 114, fill=False, lw=2))
    for q in P:
        moved = q['id'] in mv and P is new
        ax.add_patch(Rectangle((q['e'] - q['w'] / 2, q['n'] - q['d'] / 2), q['w'], q['d'], fc=COL[q['kind']], ec='r' if moved else 'k', lw=2 if moved else .6))
        ax.text(q['e'], q['n'] + q['d'] / 2 + .5, q['id'], ha='center', va='bottom', fontsize=6)
    if P is new:
        for q0, q1 in zip(cur, new):
            if q0['id'] in mv: ax.annotate('', xy=(q1['e'], q1['n']), xytext=(q0['e'], q0['n']), arrowprops=dict(arrowstyle='->', color='r', lw=.8, alpha=.6))
    for s, c in (('SpawnA', '#1f6feb'), ('SpawnB', '#e5534b')):
        p = geom.spawns[s]; ax.plot(p['e'], p['n'], 'o', ms=11, mfc=c, mec='k'); ax.text(p['e'], p['n'], s[-1], ha='center', va='center', color='w', fontsize=8, weight='bold')
    ax.set_xlim(-43, 43); ax.set_ylim(-60, 60); ax.set_aspect('equal'); ax.grid(alpha=.2); ax.set_title(title, fontsize=9)
fig.suptitle('Pillar / low-wall pairing (plan, north up, east right). Red outline = low wall moved to an open pocket. Both layouts: 180° turn, spawns hidden, centre 3.0 s from each spawn', fontsize=9)
fig.tight_layout(); fig.savefig(f'{OUT}/warehouse_pairing_whatif.png', dpi=120); print('ok')
