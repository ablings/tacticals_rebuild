"""Eye-height sweep behind ramp rule 1 (notes/arena_v2_plan.md): raise the eye in place at four floor spots and count how much of the
floor shows a crouched head (z 2.6) / a standing chest (z 4.0).
    python -I tools/arena_v2_height_sweep.py      (needs notes/maps/arena_v2_layout.json; runs the checker in fast mode first)
"""
import os, runpy, io, contextlib
import numpy as np

os.environ.setdefault("ARENA_FAST", "1")
os.environ.setdefault("ARENA_G", "5")
HERE = os.path.dirname(os.path.abspath(__file__))
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path(os.path.join(HERE, "arena_v2_check.py"))
S, los_many = g["S"], g["los_many"]
FLOOR = S[:, 2] == 0


def cov(x, y, eye, tz):
    Q = np.column_stack([S[FLOOR, 0], S[FLOOR, 1], np.full(FLOOR.sum(), tz)])
    return los_many(np.array([x, y, eye]), Q).mean() * 100


SPOTS = {"in front of A's perch": (-34, 41), "in front of B's ledge": (29, -43), "centre band": (-27, 0), "north island": (-3, 30)}
HEIGHTS = (0, 2, 3.4, 4, 5, 5.4, 6, 8)
print("deck height -> % floor seen (crouched head / standing chest)")
for name, (x, y) in SPOTS.items():
    print(f"{name:24s}", " | ".join(f"{h:g}: {cov(x, y, h + 4.6, 2.6):.0f}/{cov(x, y, h + 4.6, 4.0):.0f}" for h in HEIGHTS))
