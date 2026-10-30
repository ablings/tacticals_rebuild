"""QuickMeleeBash: gun-butt bash with the gun in hand (targets section 7). Authored on the pistol (grip-base strike), both
hands stay on the gun. Hit f8 (0.14)."""
import pistol
from rbxanim import Clip, P, add, seq, fr

GUN = "Pistol"
TOOL = "Pistol"
MIRROR = False


def bash():
    """f0-f3 Cubic Out pull the gun back 0.3 to the chest, muzzle up 40; f3-f8 Expo In drive the butt / grip base forward and
    down at head height, hips turn 15, rear heel lifts; f8-f11 Cubic Out 0.15 further; f11-f24 Cubic Out back to Hold"""
    c = Clip("QuickMeleeBash", 0.40)
    h, _, _ = pistol.poses(c)
    g = h["gun"][0]
    pull = P(h, gun=((g[0] + 0.1, g[1] - 0.05, g[2] + 0.45), (40, 0, 0)), chest=(1, -8, 0), root=(0, -0.09, 0.05, -2, -6, 0))
    hit = P(h, gun=((g[0] - 0.05, g[1] + 0.05, g[2] - 0.05), (70, 0, 0)), chest=(-6, 10, 0), root=(0, -0.12, -0.12, -5, 15, 0),
            footR=((0.0, 0.08, 0.2), (12, -14, 0)))
    thru = add(hit, gun=((0, -0.05, -0.12), (5, 0, 0)), chest=(-1, 2, 0))
    seq(c, [(0, h, "CubicOut"), (3, pull, "ExpoIn"), (8, hit, "CubicOut"), (11, thru, "CubicOut"), (24, h)])
    c.marker("Hit", fr(8))
    return c


CLIPS = {"QuickMeleeBash": bash}
