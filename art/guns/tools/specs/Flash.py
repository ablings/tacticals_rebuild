# Flash: flashbang: slim light grey steel body with 3 rows of 4 tall vent slots, dark base cap, steel fuze, spoon, pin.
import os
exec(open(os.path.join(os.path.dirname(__file__), "_grenade.py")).read())
NAME = "Flash"
ORIGIN = (0.0, 0.0)
R = 0.12
TOP = 0.22
ports = []
for z in (-0.30, -0.14, 0.04):
    for k in range(4):
        a = math.radians(45 + 90 * k)
        c, s_ = math.cos(a), math.sin(a)
        w = 0.022
        ports.append(PT([(0.08 * s_ - w * c, 0.08 * c + w * s_), (0.08 * s_ + w * c, 0.08 * c - w * s_),
                         (0.16 * s_ + w * c, 0.16 * c - w * s_), (0.16 * s_ - w * c, 0.16 * c + w * s_)], z, z + 0.12))
spoon = [(0.0, TOP + 0.10), (0.05, TOP + 0.10), (R + 0.01, TOP + 0.02), (R + 0.01, -0.33), (R - 0.02, -0.33), (R - 0.02, TOP),
         (0.04, TOP + 0.075), (0.0, TOP + 0.075)]
PARTS = [
    Part("Body", "White", [LZ([-0.38, -0.38, TOP, TOP], [0.0, R, R, 0.0], seg=12, cut=ports)], wrap="A", note="body with 12 tall vent slots"),
    Part("Band", "Polymer", [LZ([-0.38, -0.38, -0.32, -0.32], [0.0, R + 0.004, R + 0.004, 0.0], seg=12)], wrap="B", note="dark base cap"),
] + fuze(TOP, spoon, ring_f=-(R - 0.03))
ATTACH = {"Grip": ("Handle", ORIGIN), "PinRing": ("Pin", (-(R + 0.025), TOP - 0.01)), "Flash": ("Body", (0.0, 0.0))}
