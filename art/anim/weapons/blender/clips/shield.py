"""Riot Shield set (targets section 7): Hold, Bash, Impact, Break. The shield tool is welded to the right hand (its face
spans the Handle's X/Y, facing along -Z), so the right hand holds it forward; the off hand braces the left edge."""
from rbxanim import Clip, P, add, seq, fr

TOOL = "RiotShield"
MIRROR = False
feet = dict(footL=((0.05, 0, -0.4), (0, 8, 0)), footR=((0.05, 0, 0.35), (0, -12, 0)))

HOLD = P(root=(0, -0.18, 0.05, -6, -4, 0), chest=(-6, -4, 0), head=(-4, 4, 0),
         gun=((0.08, 0.75, -0.95), (0, 0, 0)), R=("gun", (0, 0, 0), (0, 0, 0)), L=("gun", (-0.85, 0.3, 0.35), (0, 0, 90)),
         poleR=(1.6, -1.0, 0.3), poleL=(-1.6, -1.0, 0.3), **feet)


def hold():
    c = Clip("RiotShieldHold", 1.0, loop=True)
    seq(c, [(0, HOLD), (30, add(HOLD, chest=(0.3, 0, 0), root=(0, -0.01, 0, 0, 0, 0))), (60, HOLD)])
    return c


def bash():
    """shoulder drive: f0-f3 Cubic Out pull in 0.1; f3-f7 Expo In shove 0.6 forward, step; f7-f12 Cubic Out push; f12-f60
    Cubic Out recover. Hit f7 (0.12)"""
    c = Clip("RiotShieldBash", 1.0)
    pull = add(HOLD, gun=((0, 0, 0.1), (0, 0, 0)), chest=(1, -4, 0), root=(0, -0.02, 0.05, 1, -4, 0))
    shove = P(HOLD, gun=((0.3, 0.8, -1.35), (0, 0, 0)), chest=(-10, 6, 0), root=(0, -0.22, -0.4, -9, 6, 0),
              footL=((0.05, 0, -0.85), (0, 8, 0)), footR=((0.05, 0, -0.05), (0, -12, 0)))
    push = add(shove, gun=((0, 0, -0.08), (0, 0, 0)), root=(0, 0, -0.06, -1, 0, 0))
    seq(c, [(0, HOLD, "CubicOut"), (3, pull, "ExpoIn"), (7, shove, "CubicOut"), (12, push, "CubicOut"),
            (60, P(HOLD, footL=push["footL"], footR=push["footR"]))])
    c.marker("Hit", fr(7))
    return c


def impact():
    """a bullet hits the shield: f0-f2 Linear jolt 0.08 back, 2 deg; f2-f15 Cubic Out"""
    c = Clip("RiotShieldImpact", 0.25)
    j = add(HOLD, gun=((0, 0.01, 0.08), (2, 0, 0)), chest=(1, 0, 0))
    seq(c, [(0, HOLD, "Linear"), (2, j, "CubicOut"), (15, HOLD)])
    return c


def break_():
    """shield torn off the arm: f0-f4 arm thrown out; f4-f36 Cubic Out recover empty-handed. DropGun f4 (= the shield)"""
    c = Clip("RiotShieldBreak", 0.60)
    thrown = P(HOLD, gun=((0.9, 0.9, -0.4), (10, -40, 20)), chest=(4, -10, 0), head=(4, 10, 0),
               L=("free", (-0.9, 0.6, -0.6), (40, 0, 0)), root=(0, -0.2, 0.1, 2, -8, 0))
    after = P(HOLD, R=("free", (0.7, 0.6, -0.7), (60, 0, 0)), L=("free", (-0.6, 0.6, -0.7), (60, 0, 0)), gun=thrown["gun"])
    seq(c, [(0, HOLD, "Linear"), (4, thrown, "CubicOut"), (36, after)])
    c.marker("DropGun", fr(4))
    return c


CLIPS = {"RiotShieldHold": hold, "RiotShieldBash": bash, "RiotShieldImpact": impact, "RiotShieldBreak": break_}
