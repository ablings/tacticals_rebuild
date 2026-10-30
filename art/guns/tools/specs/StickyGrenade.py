# StickyGrenade: ball grenade in a dark adhesive cover with a sage band and a peel-off backing tab on the front.
import os
exec(open(os.path.join(os.path.dirname(__file__), "_grenade.py")).read())
NAME = "StickyGrenade"
ORIGIN = (0.0, 0.0)
TOP = 0.20
BZ = [-0.21, -0.20, -0.15, -0.075, 0.0, 0.075, 0.15, 0.20, 0.21]
BR = [0.0, 0.065, 0.145, 0.195, 0.21, 0.195, 0.145, 0.065, 0.0]
spoon = [(0.0, TOP + 0.10), (0.05, TOP + 0.10), (0.11, TOP + 0.02), (0.19, 0.10), (0.205, -0.05), (0.185, -0.05), (0.17, 0.10), (0.09, TOP + 0.005),
         (0.04, TOP + 0.075), (0.0, TOP + 0.075)]
PARTS = [
    Part("Body", "Polymer", [LZ(BZ, BR, seg=12)], wrap="A", note="ball body in its adhesive cover"),
    Part("Band", "Sage", [LZ([-0.10, -0.04], [0.20, 0.20], seg=12)], wrap="B", note="adhesive band"),
    Part("Backing", "Cream", [P([(0.17, -0.11), (0.215, -0.11), (0.225, 0.03), (0.18, 0.03)], 0.17),
                              B(0.20, 0.24, -0.17, -0.10, 0.05)], pivot=(0.22, 0.03),
         motion="rotate about x, peel down and off before the throw", explode=(0.15, -0.05, 0), note="peel-off backing + pull tab"),
] + fuze(TOP, spoon, ring_f=-0.12)
ATTACH = {"Grip": ("Handle", ORIGIN), "PinRing": ("Pin", (-0.20, TOP + 0.05)), "StickFace": ("Body", (0.21, 0.0))}
