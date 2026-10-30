from bodyanim import *
def idle_tall():
    c = Clip("CoverIdleTall", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in ((0, 0), (0.5, 1), (1.0, 0)):
        c.root(t, x=0.05, y=-0.12 - 0.015 * s, z=0, roll=1.5)
        foot(c, "R", t, x=0.12, yaw=-8)
        foot(c, "L", t, x=-0.12, z=-0.15, yaw=8)
        spine(c, t, pitch=-3 - 0.6 * s, roll=-1.5)
        head(c, t, pitch=-2)
        c.gun(t, (0.25, -0.45, -0.95), (-35 - 0.5 * s, 55, 0))
        c.hand_on("L", t, (-0.55, -0.3, 0.1), (0, 0, 0))
    return c
CLIPS = {"CoverIdleTall": idle_tall}
MIRROR = {"CoverIdleTall": "CoverIdleTallLeft"}
