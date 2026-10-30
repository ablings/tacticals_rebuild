# Smoke: cylindrical smoke grenade: olive can, cream band, two rows of side emission holes, steel fuze, spoon, pin.
import os
exec(open(os.path.join(os.path.dirname(__file__), "_grenade.py")).read())
NAME = "Smoke"
ORIGIN = (0.0, 0.0)
R = 0.14
TOP = 0.20
holes = []
for z in (0.13, -0.30):
    for k in range(6):
        a = math.radians(30 + 60 * k)
        holes.append(CA((0.09 * math.sin(a), 0.09 * math.cos(a), z), (0.2 * math.sin(a), 0.2 * math.cos(a), z), 0.018, seg=6, rot=0))
spoon = [(0.0, TOP + 0.10), (0.05, TOP + 0.10), (R + 0.01, TOP + 0.02), (R + 0.01, -0.22), (R - 0.02, -0.22), (R - 0.02, TOP),
         (0.04, TOP + 0.075), (0.0, TOP + 0.075)]
PARTS = [
    Part("Body", "Olive", [LZ([-0.37, -0.37, TOP, TOP], [0.0, R, R, 0.0], seg=12, cut=holes)], wrap="A", note="can with 6 side holes top and bottom"),
    Part("Band", "Cream", [LZ([-0.12, -0.04], [R + 0.004, R + 0.004], seg=12)], wrap="B"),
] + fuze(TOP, spoon, ring_f=-(R - 0.03))
ATTACH = {"Grip": ("Handle", ORIGIN), "PinRing": ("Pin", (-(R + 0.025), TOP - 0.01)), "SmokeTop": ("Body", (0.0, 0.13)), "SmokeBottom": ("Body", (0.0, -0.30))}
