"""Plan images for the Warehouse study. View = Studio top view with +Z (north) up, east to the right."""
import json, sys, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyArrow
from geom import pieces, barrels, camskin, spawns, HALF_W, HALF_L
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
g = np.load('grids.npz'); m = json.load(open('metrics.json'))
COL = {'pillar': '#3b3f8f', 'block': '#2f7d6d', 'wall': '#8a5a2b', 'low': '#e0a526', 'barrel': '#c0392b'}
LBL = {'pillar': 'Pillar 5×5, 10 high (×6)', 'block': 'Head-high block 5×4, 7 high (×10)', 'wall': 'Wall 10×3, 7 high (×4)',
       'low': 'Low wall 6×2, 3.4 high (×12)', 'barrel': 'Fire barrel ⌀2.1, 2.5 high, shootable (×4)'}
pair = {r['low']: r for r in m['pairing']['low_walls']}

def room(ax):
    ax.add_patch(Rectangle((-HALF_W, -HALF_L), 2 * HALF_W, 2 * HALF_L, fill=False, lw=2, ec='k'))
    for c in camskin:
        ax.add_patch(Rectangle((c['e'] - c['w'] / 2, c['n'] - c['d'] / 2), c['w'], c['d'], fc='#777', ec='none'))
    for n0 in (-HALF_L, HALF_L):   # closed shutter doors (decor, not usable)
        ax.plot([-8, 8], [n0, n0], color='#c0392b', lw=4, solid_capstyle='butt')
    ax.set_xlim(-HALF_W - 3, HALF_W + 3); ax.set_ylim(-HALF_L - 3, HALF_L + 3); ax.set_aspect('equal')
    ax.set_xticks(range(-40, 41, 10)); ax.set_yticks(range(-50, 51, 10)); ax.grid(alpha=.25, lw=.5)

def draw_pieces(ax, labels=True, alpha=1):
    seen = set()
    for q in pieces + barrels:
        k = q['kind']
        ax.add_patch(Rectangle((q['e'] - q['w'] / 2, q['n'] - q['d'] / 2), q['w'], q['d'], fc=COL[k], ec='k', lw=.6, alpha=alpha,
                               label=LBL[k] if k not in seen else None))
        seen.add(k)
        if labels:
            ax.text(q['e'], q['n'] + q['d'] / 2 + 0.6, q['id'].replace('FireBarrel_', ''), ha='center', va='bottom', fontsize=6.5)

def draw_spawns(ax):
    for s, c in (('SpawnA', '#1f6feb'), ('SpawnB', '#e5534b')):
        p = spawns[s]; ax.plot(p['e'], p['n'], 'o', ms=13, mfc=c, mec='k')
        ax.text(p['e'], p['n'], s[-1], ha='center', va='center', color='w', fontsize=9, weight='bold')
        yaw = np.radians(p['yaw']); de, dn = np.sin(yaw), -np.cos(yaw)   # Roblox look (-sin, -cos) in x,z; e = -x
        ax.annotate('', xy=(p['e'] + 6 * de, p['n'] + 6 * dn), xytext=(p['e'] + 1.8 * de, p['n'] + 1.8 * dn), arrowprops=dict(arrowstyle='->', color=c, lw=1.6))

# ---------- 1: plan ----------
fig, ax = plt.subplots(figsize=(8.6, 11))
room(ax); draw_pieces(ax); draw_spawns(ax)
for L in [q for q in pieces if q['kind'] == 'low']:
    r = pair[L['id']]
    tag = 'flush' if r['gap'] <= 1.5 else ('near' if r['gap'] <= 5 else 'alone')
    below = any(abs(q['e'] - L['e']) < (q['w'] + L['w']) / 2 and 0 < L['n'] - q['n'] < 7 for q in pieces if q is not L)
    tx, ty, ha, va = (L['e'] + L['w'] / 2 + 0.6, L['n'], 'left', 'center') if below else (L['e'], L['n'] - 1.9, 'center', 'top')
    ax.text(tx, ty, tag, ha=ha, va=va, fontsize=6, color={'flush': '#b03a2e', 'near': '#9a7d0a', 'alone': '#1e8449'}[tag], style='italic')
ax.plot(0, 0, 'k+', ms=12, mew=1.5); ax.text(1, 1, 'centre', fontsize=7)
ax.set_title('Warehouse (Tacticals tutorial map): cover plan\n81 × 114 inside, ceiling 18, floor 0. Spawns A and B in opposite corners. '
             '180° turn about the centre', fontsize=9.5)
ax.set_xlabel('studs east of centre  (east = -X in Roblox)'); ax.set_ylabel('studs north of centre (+Z)')
ax.legend(loc='upper left', fontsize=6.6, bbox_to_anchor=(0, -0.06), ncol=2, frameon=False)
fig.text(0.5, 0.012, 'Low-wall tags: flush = ≤1.5 from tall cover (one cover unit), near = 1.5-5, alone = >5.  '
         'Grey = wall pilasters (12 high). Red bars = closed shutter doors (decor).', ha='center', fontsize=6.5)
fig.tight_layout(rect=(0, 0.03, 1, 1)); fig.savefig(f'{OUT}/warehouse_plan.png', dpi=140); plt.close(fig)

# ---------- 2: exposure + who-gets-there-first ----------
fig, axs = plt.subplots(1, 3, figsize=(16, 8.4))
es, ns, samp = g['es'], g['ns'], g['samp']
for ax, vals, title, cm, vr in ((axs[0], g['expo'], 'Standing exposure: % of the floor a standing eye (4.6) sees\n(only pillars, blocks and walls block it)', 'magma', (0, 65)),
                                (axs[1], np.load('cexp.npy'), 'Crouched exposure: % of the floor seen at crouch eye (2.6)\n(low walls and barrels block too)', 'magma', (0, 65))):
    room(ax)
    sc = ax.scatter(es[samp[:, 1]], ns[samp[:, 0]], c=vals, s=9, marker='s', cmap=cm, vmin=vr[0], vmax=vr[1], lw=0)
    draw_pieces(ax, labels=False); draw_spawns(ax); ax.set_title(title, fontsize=8.5); plt.colorbar(sc, ax=ax, fraction=.04)
ax = axs[2]; room(ax)
d = g['tA'] - g['tB']; d[~np.isfinite(d)] = np.nan
im = ax.imshow(np.clip(d, -3, 3), origin='lower', extent=(-HALF_W, HALF_W, -HALF_L, HALF_L), cmap='coolwarm', vmin=-3, vmax=3)
cs = ax.contour(es, ns, np.nan_to_num(d, nan=99), levels=[-1, 0, 1], colors=['k', 'k', 'k'], linewidths=[.6, 1.4, .6], linestyles=['--', '-', '--'])
draw_pieces(ax, labels=False); draw_spawns(ax)
ax.set_title('Who gets there first (sprint 20 studs/s, vaulting allowed)\nblue = A first, red = B first; solid line = tie, dashed = ±1 s', fontsize=8.5)
plt.colorbar(im, ax=ax, fraction=.04, label='seconds: t(A) − t(B)')
fig.tight_layout(); fig.savefig(f'{OUT}/warehouse_exposure_timing.png', dpi=120); plt.close(fig)
print('ok')
