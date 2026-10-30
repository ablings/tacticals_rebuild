"""Bat set (targets section 7): Hold, Equip, Swing, ChargeWindup, ChargeHold, SwingCharged. Two hands on the handle (left
hand below the right, toward the knob). The tool is welded to the right hand; the barrel runs along the Handle's -Z."""
from rbxanim import Clip, P, add, seq, fr

TOOL = "Bat"
MIRROR = False
L_ON = ("gun", (0.0, 0.0, 0.58), (0, 0, 0))
feet = dict(footL=((0.1, 0, -0.35), (0, 25, 0)), footR=((0.0, 0, 0.3), (0, -25, 0)))

HOLD = P(root=(0, -0.12, 0.03, -3, -10, 0), chest=(-2, -8, 0), head=(-2, 12, 0),
         gun=((0.45, 1.05, -0.45), (115, -25, 10)), R=("gun", (0, 0, 0), (0, 0, 0)), L=L_ON,
         poleR=(1.6, -0.8, 0.2), poleL=(-1.3, -0.9, -0.2), **feet)
LOW = P(HOLD, gun=((0.6, 0.0, -0.6), (-60, -10, 0)), head=(-3, 8, 0))
LOAD = P(HOLD, root=(0.06, -0.16, 0.08, -2, -28, 0), chest=(-1, -24, 3), head=(-2, 30, 0), gun=((0.7, 1.25, 0.05), (95, -60, 30)))
HIT = P(HOLD, root=(-0.06, -0.16, -0.08, -4, 24, 0), chest=(-4, 26, -4), head=(-2, -4, 0), gun=((0.05, 0.85, -0.85), (5, 100, 0)),
        footR=((0.0, 0.1, 0.25), (15, -5, 0)))
WRAP = P(HIT, chest=(-2, 40, -6), root=(-0.06, -0.15, -0.06, -3, 34, 0), gun=((-0.6, 1.25, -0.3), (60, 170, 20)))
WOUND = P(LOAD, root=(0.08, -0.3, 0.12, 0, -34, 0), chest=(0, -30, 4), gun=((0.75, 1.35, 0.2), (100, -70, 35)),
          footR=((0.0, 0, 0.3), (0, -30, 0)))


def hold():
    c = Clip("BatHold", 1.0, loop=True, priority="Action")
    seq(c, [(0, HOLD), (30, add(HOLD, chest=(0.4, 0, 0), root=(0, -0.01, 0, 0, 0, 0))), (60, HOLD)])
    return c


def equip():
    c = Clip("BatEquip", 0.35)
    seq(c, [(0, LOW, "QuartOut"), (10, add(HOLD, gun=((0, 0.02, 0), (2, 0, 0))), "BackOut:0.5"), (14, HOLD), (21, HOLD)])
    return c


def swing():
    """f0-f5 Cubic Out load (hips coil back, bat back); f5-f10 Expo In swing (hips -> chest +1 f -> arms +1 f -> bat);
    f10-f16 Cubic Out wrap over the left shoulder; f16-f45 Cubic Out recover. Hit f10 (0.16)"""
    c = Clip("BatSwing", 0.75)
    seq(c, [(0, HOLD, "CubicOut"), (5, LOAD, "ExpoIn"), (8, P(LOAD, root=HIT["root"]), "ExpoIn"), (10, HIT, "CubicOut"), (16, WRAP, "CubicOut"),
            (45, HOLD)], only=("root", "feet"))
    seq(c, [(0, HOLD, "CubicOut"), (5, LOAD, "ExpoIn"), (9, P(LOAD, chest=HIT["chest"]), "ExpoIn"), (10, HIT, "CubicOut"), (16, WRAP, "CubicOut"),
            (45, HOLD)], only=("chest", "head"))
    seq(c, [(0, HOLD, "CubicOut"), (5, LOAD, "ExpoIn"), (10, HIT, "CubicOut"), (16, WRAP, "CubicOut"), (45, HOLD)], only=("gun", "R", "L", "poles"))
    c.marker("Hit", fr(10))
    return c


def windup():
    """= Charge.Time 0.8: f0-f30 Cubic Out deep coil, rear knee 25; f30-f48 hold with a 0.3 deg strain tremble (Sine)"""
    c = Clip("BatChargeWindup", 0.80)
    seq(c, [(0, HOLD, "CubicOut"), (30, WOUND, "SineInOut"), (36, add(WOUND, chest=(0.3, 0.2, 0))), (42, WOUND), (48, add(WOUND, chest=(0.3, -0.2, 0)))])
    return c


def charge_hold():
    c = Clip("BatChargeHold", 1.0, loop=True)
    seq(c, [(0, WOUND), (15, add(WOUND, chest=(0.3, 0.2, 0))), (30, WOUND), (45, add(WOUND, chest=(0.3, -0.2, 0))), (60, WOUND)])
    return c


def swing_charged():
    """released from the wound pose: f0-f6 Expo In; f6-f14 through and around; f14-f36 recover. Hit f6 (0.1)"""
    c = Clip("BatSwingCharged", 0.60)
    seq(c, [(0, WOUND, "ExpoIn"), (6, add(HIT, chest=(0, 4, 0)), "CubicOut"), (14, add(WRAP, chest=(0, 6, 0)), "CubicOut"), (36, HOLD)])
    c.marker("Hit", fr(6))
    return c


CLIPS = {"BatHold": hold, "BatEquip": equip, "BatSwing": swing, "BatChargeWindup": windup, "BatChargeHold": charge_hold,
         "BatSwingCharged": swing_charged}
