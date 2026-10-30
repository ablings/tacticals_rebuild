"""Katana set (targets section 7): Hold, Equip, Slash (the parry window is a held high guard). Two hands on the long
handle (left hand toward the pommel). Blade along the Handle's -Z."""
from rbxanim import Clip, P, add, seq, fr

TOOL = "Katana"
MIRROR = False
L_ON = ("gun", (0.0, 0.0, 0.62), (0, 0, 0))
feet = dict(footL=((0.05, 0, -0.35), (0, 10, 0)), footR=((0.0, 0, 0.3), (0, -15, 0)))

MID = P(root=(0, -0.15, 0.03, -3, -6, 0), chest=(-3, -4, 0), head=(-3, 4, 0),
        gun=((0.25, 0.55, -0.85), (45, 0, 0)), R=("gun", (0, 0, 0), (0, 0, 0)), L=L_ON,
        poleR=(1.6, -0.8, 0.4), poleL=(-1.6, -0.8, 0.4), **feet)
LOW = P(MID, gun=((0.5, 0.0, -0.6), (-40, 10, 0)))
RAISE = P(MID, gun=((0.55, 1.65, -0.35), (125, -15, -30)), chest=(0, -10, 2), root=(0.03, -0.15, 0.06, -1, -12, 0))
CUT = P(MID, gun=((-0.35, 0.45, -1.05), (-20, 35, 40)), chest=(-8, 18, -4), root=(-0.03, -0.2, -0.1, -5, 15, 0), head=(-2, -6, 0))
GUARD = P(MID, gun=((0.15, 1.35, -0.75), (10, 75, 80)), chest=(-3, 4, 0), root=(0, -0.17, -0.04, -3, 6, 0))


def hold():
    c = Clip("KatanaHold", 1.0, loop=True)
    seq(c, [(0, MID), (30, add(MID, chest=(0.4, 0, 0), root=(0, -0.01, 0, 0, 0, 0), gun=((0, 0.01, 0), (0.4, 0, 0)))), (60, MID)])
    return c


def equip():
    c = Clip("KatanaEquip", 0.40)
    seq(c, [(0, LOW, "QuartOut"), (12, add(MID, gun=((0, 0.015, 0), (1.5, 0, 0))), "BackOut:0.5"), (16, MID), (24, MID)])
    return c


def slash():
    """diagonal cut ending in a guard: f0-f3 Cubic Out raise; f3-f7 Expo In cut; f7-f28 = the parry window (Parry.Window
    0.35): blade held across the front in a high guard, moving hold; f28-f39 Cubic Out back to mid guard. Hit f7 (0.12)"""
    c = Clip("KatanaSlash", 0.65)
    seq(c, [(0, MID, "CubicOut"), (3, RAISE, "ExpoIn"), (7, CUT, "CubicOut"), (11, GUARD, "SineInOut"), (20, add(GUARD, chest=(0.5, 0, 0))),
            (28, GUARD, "CubicOut"), (39, MID)])
    c.marker("Hit", fr(7))
    return c


CLIPS = {"KatanaHold": hold, "KatanaEquip": equip, "KatanaSlash": slash}
