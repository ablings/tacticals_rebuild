# Frag: fragmentation grenade: tall egg body, cream band, steel fuze with spoon and pull ring.
import os
exec(open(os.path.join(os.path.dirname(__file__), "_grenade.py")).read())
NAME = "Frag"
ORIGIN = (0.0, 0.0)
EGG_Z = [-0.23, -0.22, -0.17, -0.08, 0.02, 0.10, 0.15, 0.18]
EGG_R = [0.0, 0.06, 0.12, 0.15, 0.15, 0.125, 0.085, 0.055]
TOP = 0.18
spoon = [(0.0, TOP + 0.10), (0.05, TOP + 0.10), (0.10, TOP + 0.02), (0.15, 0.06), (0.16, -0.04), (0.15, -0.14),
         (0.12, -0.14), (0.13, -0.04), (0.12, 0.06), (0.08, TOP + 0.01), (0.04, TOP + 0.075), (0.0, TOP + 0.075)]
PARTS = [
    Part("Body", "Olive", [LZ(EGG_Z, EGG_R, seg=12)], wrap="A", note="egg body"),
    Part("Band", "Cream", [LZ([-0.035, -0.005], [0.153, 0.153], seg=12)], wrap="B", note="cream ID band (overlay ring)"),
] + fuze(TOP, spoon, ring_f=-0.10)
ATTACH = {"Grip": ("Handle", ORIGIN), "PinRing": ("Pin", (-0.155, TOP - 0.01)), "Throw": ("Body", (0.0, 0.0))}
