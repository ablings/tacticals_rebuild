"""Melee: targets section 7 (knife, fists). The weapon is welded to the right hand by its Tool grip, so the hand leads.
Wrist targets: studs from the Waist pivot (x right, y up, -z forward). Hand rot (pitch, yaw, roll) from the hanging hand:
pitch +90 = fingers forward."""
import rbxanim
from rbxanim import Clip, P, add, mix, seq, fr

MIRROR = False  # melee is right-handed only (the code has no Left melee clips)
feet = dict(footL=((0.05, 0, -0.3), (0, 12, 0)), footR=((0.0, 0, 0.22), (0, -18, 0)))

GUARD_KNIFE = P(root=(0, -0.12, 0.03, -3, 0, 0), chest=(-3, 0, 0), head=(-2, 0, 0),
                R=("free", (0.5, 0.75, -0.75), (75, 0, -10)), L=("free", (-0.35, 0.95, -0.7), (80, 0, 10)),
                poleR=(1.7, -0.6, 0.5), poleL=(-1.7, -0.6, 0.5), **feet)
GUARD_FISTS = P(GUARD_KNIFE, R=("free", (0.38, 1.15, -0.6), (95, 0, 0)), L=("free", (-0.32, 1.25, -0.72), (95, 0, 0)))


def slash():
    """f0-f3 Cubic Out coil; f3-f7 Expo In slash on an arc at neck height; f7-f10 Cubic Out follow-through; f10-f27
    Cubic Out recover. Hit f7 (0.12)"""
    c = Clip("MeleeSlash", 0.45)
    g = GUARD_KNIFE
    coil = P(g, root=(0, -0.14, 0.05, -3, 10, 0), chest=(-2, 14, 0), R=("free", (-0.35, 1.35, -0.45), (120, 40, -60)),
             poleR=(1.8, 0.4, 0.8))
    arc = P(coil, root=(0, -0.15, -0.02, -4, 0, 0), chest=(-4, 0, 0), R=("free", (0.25, 1.45, -1.35), (95, 0, -80)))
    hit = P(coil, root=(0, -0.16, -0.08, -5, -12, 0), chest=(-5, -16, 0), R=("free", (1.15, 1.25, -0.95), (90, -50, -90)),
            poleR=(1.9, -0.2, 0.2))
    thru = P(hit, chest=(-5, -22, 0), root=(0, -0.16, -0.08, -5, -15, 0), R=("free", (1.45, 0.95, -0.35), (80, -80, -90)))
    seq(c, [(0, g, "CubicOut"), (3, coil, "ExpoIn"), (5, arc, "Linear"), (7, hit, "CubicOut"), (10, thru, "CubicOut"),
            (27, g)])
    c.marker("Hit", fr(7))
    return c


def punch():
    """f0-f2 Cubic Out hip load; f2-f6 Expo In punch (hips turn 20 first, shoulder +1 f, fist +1 f); f6-f9 hold-through;
    f9-f24 Cubic Out back to guard. Hit f6"""
    c = Clip("MeleePunch", 0.40)
    g = GUARD_FISTS
    load = P(g, root=(0.03, -0.14, 0.06, -3, -8, 0), chest=(-3, -6, 0))
    hips = P(load, root=(0, -0.14, -0.06, -4, 20, 0), chest=(-4, 4, 0))
    ext = P(hips, chest=(-5, 14, 0), R=("free", (0.12, 1.45, -1.75), (90, 0, 90)), L=("free", (-0.32, 1.3, -0.6), (95, 0, 0)),
            poleR=(1.6, 0.2, 0.0))
    seq(c, [(0, g, "CubicOut"), (2, load, "ExpoIn"), (4, hips, "ExpoIn"), (6, ext, "Linear"), (9, add(ext, chest=(-0.5, 0, 0))),
            (24, g)], only=("root", "feet", "head"))
    seq(c, [(0, g, "CubicOut"), (2, load, "ExpoIn"), (5, P(ext, chest=(-5, 10, 0)), "ExpoIn"), (6, ext), (9, ext, "CubicOut"),
            (24, g)], only=("chest",))
    seq(c, [(0, g, "CubicOut"), (3, load, "ExpoIn"), (6, ext, "Linear"), (9, add(ext, R=((0, 0, -0.03), (0, 0, 0))), "CubicOut"),
            (24, g)], only=("R", "L", "poles"))
    c.marker("Hit", fr(6))
    return c


def knife_heavy():
    """f0-f10 Cubic Out big coil; f10-f17 Expo In drive down and across, step-in 0.4; f17-f22 Cubic Out through; f22-f42
    Cubic Out recover. Hit f17 (0.28)"""
    c = Clip("MeleeKnifeHeavy", 0.70)
    g = GUARD_KNIFE
    coil = P(g, root=(0.04, -0.1, 0.18, 4, -10, 0), chest=(6, -14, 2), head=(-4, 10, 0),
             R=("free", (0.95, 2.1, 0.35), (170, 0, 0)), L=("free", (-0.4, 1.0, -0.95), (80, 0, 0)),
             poleR=(1.9, 1.0, 1.0), footR=((0.0, 0, 0.3), (0, -18, 0)))
    hit = P(coil, root=(-0.02, -0.32, -0.4, -12, 12, 0), chest=(-16, 14, -4), head=(4, -6, 0),
            R=("free", (-0.15, 0.55, -1.75), (60, 0, 0)), L=("free", (-0.75, 0.4, -0.25), (30, 0, 0)),
            footL=((0.05, 0, -0.7), (0, 12, 0)), footR=((0.0, 0, -0.1), (0, -18, 0)), poleR=(1.6, -0.2, 0.2))
    thru = P(hit, R=("free", (-0.5, 0.15, -1.45), (40, 0, 0)), chest=(-19, 18, -5))
    seq(c, [(0, g, "CubicOut"), (10, coil, "ExpoIn"), (17, hit, "CubicOut"), (22, thru, "CubicOut"), (42, P(g, **{
        "footL": hit["footL"], "footR": hit["footR"]}))])
    c.marker("Hit", fr(17))
    return c


def backstab():
    """f0-f6 Cubic Out off hand reaches the target's shoulder height, knife low; f6-f10 Expo In stab forward-up; f10-f16
    hold-push; f16-f22 Cubic Out pull out; f22-f36 Cubic Out recover. Hit f10"""
    c = Clip("MeleeKnifeBackstab", 0.60)
    g = GUARD_KNIFE
    reach = P(g, root=(0, -0.2, -0.1, -8, 6, 0), chest=(-8, 6, 0), L=("free", (-0.2, 1.45, -1.55), (90, 0, 0)),
              R=("free", (0.6, 0.15, -0.45), (70, 0, -10)), poleL=(-1.6, -0.2, 0.2))
    stab = P(reach, root=(0, -0.22, -0.25, -10, 0, 0), chest=(-10, -4, 0), R=("free", (0.25, 0.95, -1.6), (110, 0, -10)),
             L=("free", (-0.2, 1.35, -1.45), (90, 0, 0)), poleR=(1.6, -0.4, 0.2))
    push = add(stab, R=((0, 0.05, -0.08), (5, 0, 0)), root=(0, 0, -0.04, -1, 0, 0))
    out = P(push, R=("free", (0.5, 0.6, -0.95), (80, 0, -10)))
    seq(c, [(0, g, "CubicOut"), (6, reach, "ExpoIn"), (10, stab, "SineInOut"), (16, push, "CubicOut"), (22, out, "CubicOut"),
            (36, g)])
    c.marker("Hit", fr(10))
    return c


CLIPS = {"MeleeSlash": slash, "MeleePunch": punch, "MeleeKnifeHeavy": knife_heavy, "MeleeKnifeBackstab": backstab}
