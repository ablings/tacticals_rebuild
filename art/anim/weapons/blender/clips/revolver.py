"""Revolver set: targets section 2, on the remodelled Revolver (Crane, Cylinder, EjectorRod, Rounds, Hammer, Trigger,
CylinderLatch). Body clips reuse the pistol set with the revolver's pose: elbows softer, gun slightly lower, heavier."""
import pistol
from rbxanim import Clip, P, add, seq, fr
from pistol_gun import add_t

GUN = "Revolver"
TOOL = "Revolver"
_base = pistol.poses


def poses(c):
    h, l, hs = _base(c)
    g = h["gun"][0]
    h = P(h, gun=((g[0], g[1] - 0.08, g[2] + 0.12), (0, 0, 0)), poleR=(1.7, -0.9, 0.7), poleL=(-1.7, -0.9, 0.7))
    l = P(l, gun=(l["gun"][0], (-50, 4, 0)))
    return h, l, hs


def renamed(builder, name, length=None):
    def b():
        pistol.poses = poses
        try:
            c = builder()
        finally:
            pistol.poses = _base
        c.name = name
        c.act.name = name
        if length:
            c.length = length
        return c
    return b


def fire():
    """heavy kick: Hammer falls f0 (1 f), Cylinder 1/6 turn f0-f2 Quad In; f2 peak (muzzle +18, elbows +10, shoulders 0.12
    back, chest +3, head +2 at f3) Linear; f2-f18 Quint Out return with one 0.5 deg dip under the line at f12"""
    c = Clip("RevolverFire", 0.30)
    h, _, _ = poses(c)
    pk = add(h, gun=((0, 0.1, 0.12), (18, 0.8, 0)), chest=(3, 0, 0))
    dip = add(h, gun=((0, -0.005, 0), (-0.5, 0, 0)))
    seq(c, [(0, h, "Linear"), (2, pk, "QuintOut"), (12, dip, "SineInOut"), (18, h)], only=("root", "chest", "gun", "R", "L", "poles", "feet"))
    seq(c, [(0, h, "Linear"), (3, add(h, head=(2, 0, 0)), "QuintOut"), (18, h)], only=("head",))
    for f, a, e in ((0, -35, "Linear"), (1, 0, "Constant"), (18, 0, "Constant")):
        c.part("Hammer", fr(f), (0, 0, 0), (a, 0, 0), ease=e)
    for f, a, e in ((0, 0, "QuadIn"), (2, -60, "Constant"), (18, -60, "Constant")):
        c.part("Cylinder", fr(f), (0, 0, 0), (0, 0, a), ease=e)
    for f, a, e in ((0, 20, "Constant"), (3, 20, "CubicOut"), (9, 0, "Constant"), (18, 0, "Constant")):
        c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
    return c


def crane(c, keys):
    for f, a, e in keys:
        c.part("Crane", fr(f), (0, 0, 0), (0, 0, a), ease=e)


def reload():
    """always a full dump (2.4 s): f0-f6 tilt 30 left, off hand under the frame; f6-f8 thumb latch; Cylinder out f8-f13 Cubic
    Out 90; f13-f16 hold; f16-f22 muzzle up 60, f19-f22 Linear thumb on the ejector; f22-f34 muzzle down; f34-f50 off hand to
    the belt (speedloader); f50-f70 loader to the cylinder; f70-f72 Linear insert; f72-f78 twist; f80-f96 hand back;
    f96-f99 Quart Out wrist flick, Cylinder closes (hard stop); f99-f102 hold; f102-f120 Quart Out up; hold to f144"""
    c = Clip("RevolverReload", 2.4)
    h, _, _ = poses(c)
    g = h["gun"][0]
    base = (g[0] - 0.25, g[1] - 0.25, g[2] + 0.45)
    tilt = P(h, gun=(base, (5, 10, 30)), head=(-10, 0, 0), poleR=(1.6, -0.9, 0.7))
    up = P(tilt, gun=(add_t(base, (0, 0.15, 0.05)), (60, 10, 30)))
    down = P(tilt, gun=(add_t(base, (0, -0.05, 0)), (-35, 10, 30)), head=(-14, 0, 0))
    flick = P(down, gun=(add_t(base, (0.05, 0.05, 0)), (-10, 5, -5)))
    seq(c, [(0, h, "CubicOut"), (6, tilt), (16, tilt, "CubicOut"), (22, up, "CubicInOut"), (34, down), (70, down, "Linear"),
            (72, add(down, gun=((0, 0, 0.03), (0, 0, 0)))), (96, down, "QuartOut"), (99, flick), (102, flick, "QuartOut"), (120, h),
            (144, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    L = h["L"]
    under = (0.05, -0.05, -0.35)     # off-hand wrist under the frame, thumb on the cylinder
    ejector = (0.0, 0.15, -1.0)      # palm on the ejector rod tip (muzzle up)
    loader = (-0.25, 0.3, 0.1)       # speed loader held to the open cylinder's rear
    belt = (-0.6, -0.05, -0.6)
    c.hand_free("L", 0, belt, (70, 0, 0)); c.hand_free("L", fr(144), belt, (70, 0, 0))
    c.free("L", 0, 0, ease="CubicOut"); c.hand_on("L", 0, L[1], L[2], ease="CubicOut")
    c.hand_on("L", fr(6), under, (0, 0, -30), ease="SineInOut")
    c.hand_on("L", fr(16), under, (0, 0, -30), ease="CubicOut")
    c.hand_on("L", fr(19), add_t(ejector, (0, 0, 0.05)), (0, 0, 90), ease="Linear")
    c.hand_on("L", fr(22), add_t(ejector, (0, 0, 0.25)), (0, 0, 90), ease="SineInOut")
    c.hand_on("L", fr(34), under, (0, 0, -30), ease="SineInOut")
    c.free("L", fr(34), 0, ease="SineInOut"); c.free("L", fr(50), 1, ease="SineInOut")
    c.hand_on("L", fr(50), add_t(loader, (0, -0.1, 0.3)), (0, 0, 0), ease="SineInOut")
    c.free("L", fr(66), 1, ease="SineInOut"); c.free("L", fr(70), 0, ease="Linear")
    c.hand_on("L", fr(70), add_t(loader, (0, 0, 0.12)), (0, 0, 0), ease="Linear")
    c.hand_on("L", fr(72), loader, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(78), loader, (0, 0, 25), ease="SineInOut")
    c.hand_on("L", fr(80), loader, (0, 0, 25), ease="SineInOut")
    c.hand_on("L", fr(96), under, (0, 0, -30), ease="CubicInOut")
    c.hand_on("L", fr(112), L[1], L[2]); c.hand_on("L", fr(144), L[1], L[2])
    crane(c, ((0, 0, "Constant"), (8, 0, "CubicOut"), (13, 90, "Constant"), (96, 90, "QuartOut"), (99, 0, "Constant"), (144, 0, "Constant")))
    for f, z, e in ((0, 0, "Constant"), (6, 0, "CubicOut"), (8, -0.04, "SineInOut"), (12, 0, "Constant"), (144, 0, "Constant")):
        c.part("CylinderLatch", fr(f), (0, 0, z), ease=e)
    for f, z, e in ((0, 0, "Constant"), (19, 0, "Linear"), (22, 0.2, "CubicOut"), (28, 0, "Constant"), (144, 0, "Constant")):
        c.part("EjectorRod", fr(f), (0, 0, z), ease=e)
    # the spent rounds drop out (MagHide), the new ones go in with the loader (ShellIn)
    for f, y, e in ((0, 0, "Constant"), (22, 0, "QuadIn"), (32, -2.5, "Constant"), (71, -2.5, "Constant"), (72, 0, "Constant"),
                    (144, 0, "Constant")):
        c.part("Rounds", fr(f), (0, y, 0.2 if 22 < f < 72 else 0), ease=e)
    c.marker("CylinderOpen", fr(13)); c.marker("ShellEject", fr(22)); c.marker("MagHide", fr(32))
    c.marker("ShellIn", fr(72)); c.marker("CylinderClosed", fr(99))
    return c


def inspect():
    """roll to show the side, open the cylinder, check the chambers, close by hand (no flick, no spin)"""
    c = Clip("RevolverInspect", 3.0)
    h, _, _ = poses(c)
    near = (0.2, h["gun"][0][1] - 0.15, -0.85)
    show = P(h, gun=(near, (10, 25, 60)), head=(-10, 8, 0), L=("gun", (0.05, -0.05, -0.35), (0, 0, -30)))
    openp = P(show, gun=(near, (25, 15, 35)), head=(-14, 4, 0), L=("gun", (-0.2, 0.1, -0.4), (0, 0, -30)))
    seq(c, [(0, h, "CubicInOut"), (20, show, "SineInOut"), (50, add(show, gun=((0, 0.02, 0), (1.5, 1, 2))), "SineInOut"), (56, openp, "SineInOut"),
            (100, add(openp, gun=((0, 0.02, 0), (1, 0, 2))), "SineInOut"), (140, show, "CubicOut"), (180, h)],
        only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    L = h["L"]
    under = (0.05, -0.05, -0.35)
    c.free("L", 0, 0); c.hand_on("L", 0, L[1], L[2], ease="CubicInOut")
    c.hand_on("L", fr(20), under, (0, 0, -30), ease="SineInOut"); c.hand_on("L", fr(50), under, (0, 0, -30), ease="CubicOut")
    c.hand_on("L", fr(56), (-0.2, 0.1, -0.4), (0, 0, -30), ease="SineInOut"); c.hand_on("L", fr(100), (-0.2, 0.1, -0.4), (0, 0, -30), ease="CubicOut")
    c.hand_on("L", fr(106), under, (0, 0, -30), ease="SineInOut"); c.hand_on("L", fr(140), under, (0, 0, -30), ease="CubicOut")
    c.hand_on("L", fr(180), L[1], L[2])
    crane(c, ((0, 0, "Constant"), (50, 0, "CubicOut"), (56, 90, "SineInOut"), (100, 90, "CubicOut"), (106, 0, "Constant"), (180, 0, "Constant")))
    c.marker("CylinderOpen", fr(56)); c.marker("CylinderClosed", fr(106))
    return c


CLIPS = {"RevolverHold": renamed(pistol.hold, "RevolverHold"), "RevolverLowered": renamed(pistol.lowered, "RevolverLowered"),
         "RevolverEquip": renamed(pistol.equip, "RevolverEquip"), "RevolverFire": fire, "RevolverReload": reload,
         "RevolverDraw": renamed(pistol.draw, "RevolverDraw", 0.55), "RevolverHolster": renamed(pistol.holster, "RevolverHolster"),
         "RevolverInspect": inspect}
