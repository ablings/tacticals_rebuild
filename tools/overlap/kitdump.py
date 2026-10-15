"""Run the kit generators without Blender: record every primitive (studio coords) to kitprims.json."""
import sys, types, math, json
from unittest.mock import MagicMock

class Vector:
    def __init__(self, v=(0, 0, 0)):
        v = list(v); self.v = [float(a) for a in v]
    x = property(lambda s: s.v[0]); y = property(lambda s: s.v[1]); z = property(lambda s: s.v[2])
    def __iter__(self): return iter(self.v)
    def __len__(self): return len(self.v)
    def __getitem__(self, i): return self.v[i]
    def __add__(self, o): return Vector([a + b for a, b in zip(self.v, o)])
    __radd__ = __add__
    def __sub__(self, o): return Vector([a - b for a, b in zip(self.v, o)])
    def __rsub__(self, o): return Vector([b - a for a, b in zip(self.v, o)])
    def __mul__(self, k):
        if isinstance(k, Vector): return sum(a * b for a, b in zip(self.v, k.v))
        return Vector([a * k for a in self.v])
    __rmul__ = __mul__
    def __truediv__(self, k): return Vector([a / k for a in self.v])
    def __neg__(self): return Vector([-a for a in self.v])
    @property
    def length(self): return math.sqrt(sum(a * a for a in self.v))
    def normalized(self):
        l = self.length or 1; return self / l
    def dot(self, o): return sum(a * b for a, b in zip(self.v, o))
    def cross(self, o):
        a, b = self.v, list(o)
        return Vector((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))
    def copy(self): return Vector(self.v)
    def rotation_difference(self, o): return MagicMock()

mu = types.ModuleType("mathutils"); mu.Vector = Vector; mu.Matrix = MagicMock()
sys.modules["mathutils"] = mu
sys.modules["bpy"] = MagicMock(); sys.modules["bmesh"] = MagicMock()

PR = []
def mk(ns, area):
    def box(piece, mat, x0, x1, y0, y1, z0, z1, bev=0.1, seg=1):
        x0, x1 = sorted((x0, x1)); y0, y1 = sorted((y0, y1)); z0, z1 = sorted((z0, z1))
        if min(x1 - x0, y1 - y0, z1 - z0) <= 1e-4: return
        PR.append(dict(t="box", a=area, p=piece, m=mat, lo=[x0, y0, z0], hi=[x1, y1, z1], bev=bev))
    def prism(piece, mat, pts, ext):
        P = [list(p) for p in pts] + [[p[i] + list(ext)[i] for i in range(3)] for p in pts]
        PR.append(dict(t="prism", a=area, p=piece, m=mat, lo=[min(q[i] for q in P) for i in range(3)],
                       hi=[max(q[i] for q in P) for i in range(3)], pts=[list(p) for p in pts], ext=list(ext)))
    def lathe(piece, mat, prof, cx=0.0, cz=0.0, seg=64, a0=0.0, a1=2 * math.pi, y0=0.0):
        r = max(p[0] for p in prof); ys = [p[1] for p in prof]
        PR.append(dict(t="lathe", a=area, p=piece, m=mat, lo=[cx - r, y0 + min(ys), cz - r], hi=[cx + r, y0 + max(ys), cz + r],
                       prof=[list(p) for p in prof], c=[cx, cz], a0=a0, a1=a1))
    def cyl(piece, mat, cx, cz, r, y0, y1, seg=32, bev=0.08):
        PR.append(dict(t="cyl", a=area, p=piece, m=mat, lo=[cx - r, y0, cz - r], hi=[cx + r, y1, cz + r]))
    def rod(piece, mat, p0, p1, r, seg=8):
        PR.append(dict(t="rod", a=area, p=piece, m=mat, lo=[min(p0[i], p1[i]) - r for i in range(3)], hi=[max(p0[i], p1[i]) + r for i in range(3)]))
    ns.update(box=box, prism=prism, lathe=lathe, cyl=cyl, rod=rod)

ROOT = "C:/Users/aroki/Documents/tacticals_rebuild/tools/"
def load(fn, area, calls):
    src = open(ROOT + fn, encoding="utf-8").read().rsplit('if __name__ == "__main__" or True:', 1)[0]
    ns = {"__name__": "kd"}
    exec(src, ns)
    mk(ns, area)
    if area == "R4":
        def shifted(dy, fn_, piece, *a, **k):
            n0 = len(PR); fn_(a[0], piece, *a[1:], **k)
            for q in PR[n0:]:
                q["lo"][1] += dy; q["hi"][1] += dy
                if "pts" in q:
                    for p in q["pts"]: p[1] += dy
        ns["shifted"] = shifted
    for c in calls:
        ns[c]()

load("hub_kit.py", "Hub1", ["build_long_wall_N", ] if False else [])
# hub: build_all without clear/finalize
src = open(ROOT + "hub_kit.py", encoding="utf-8").read().split('if __name__ == "__main__" or True:')[0]
ns = {"__name__": "kd"}; exec(src, ns); mk(ns, "Hub1")
ns["build_long_wall"](ns["WN"], "N"); ns["build_long_wall"](ns["WS"], "S")
ns["build_gate"](ns["WN"], "N"); ns["build_gate"](ns["WS"], "S")
for f in ["build_east", "build_west", "build_floor", "build_spawn", "build_roof", "build_catwalks", "build_props"]:
    ns[f]()
load("rooms2_kit.py", "Rooms2", ["build_shop", "build_armory"])
load("rooms3_kit.py", "Rooms3", ["build_duels_walls", "build_duels_west", "build_duels_floor", "build_pads", "build_duels_roof",
                                  "build_duels_base", "build_deck", "build_hangar", "build_exfil_floor", "build_pad_walls", "build_exfil_props"])
load("rooms4_kit.py", "R4", ["build_showroom"])
json.dump(PR, open(sys.argv[1], "w"))
from collections import Counter
print(len(PR), Counter((q["a"], q["t"]) for q in PR))
