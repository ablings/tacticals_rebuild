"""Gadgets: targets section 8. Hands free (the grenade / kit is a hand prop shown by code); throws in the right hand.
Positions: wrist targets, studs from the Waist pivot (x right, y up, -z forward)."""
import rbxanim
from rbxanim import Clip, P, add, mix, seq, fr

NO_MIRROR = ("SmokeHold", "SmokeRoll", "FragPinPull", "FragCook", "LandminePlace", "MedkitUse")
feet = dict(footL=((0.05, 0, -0.25), (0, 10, 0)), footR=((0.0, 0, 0.2), (0, -15, 0)))

READY = P(root=(0, -0.08, 0.02, -2, 0, 0), chest=(-2, 0, 0), head=(-2, 0, 0),
          R=("free", (0.35, 0.95, -0.75), (70, 0, 0)), L=("free", (-0.3, 0.85, -0.8), (70, 0, 0)),
          poleR=(1.6, -0.5, 0.6), poleL=(-1.6, -0.5, 0.6), **feet)
# cocked overarm: hand behind and above the head, chest turned right, weight on the rear (right) foot, off arm at the target
COCK = P(READY, root=(0.05, -0.12, 0.12, 2, -14, 0), chest=(4, -18, 3), head=(-4, 16, 0),
         R=("free", (1.05, 2.05, 0.75), (-40, 0, 20)), L=("free", (-0.45, 1.45, -1.45), (80, 0, 0)),
         poleR=(1.9, 0.6, 1.4), poleL=(-1.4, -0.6, 0.2))
RELEASE = P(COCK, root=(-0.05, -0.12, -0.18, -6, 12, 0), chest=(-8, 16, -4), head=(-3, -6, 0),
            R=("free", (0.45, 1.9, -1.45), (30, 0, 0)), L=("free", (-0.75, 0.3, -0.45), (-0, 0, 0)),
            poleR=(1.8, 0.2, -0.2), poleL=(-1.6, -0.8, 0.8))
THROUGH = P(RELEASE, root=(-0.08, -0.16, -0.22, -9, 20, 0), chest=(-14, 22, -6), head=(-4, -10, 0),
            R=("free", (-0.45, -0.1, -0.85), (60, 0, 30)), L=("free", (-0.95, -0.2, 0.0), (-0, 0, 0)),
            poleR=(1.0, -1.0, 0.4))


def smoke_hold():
    c = Clip("SmokeHold", 1.0, loop=True)
    seq(c, [(0, READY), (30, add(READY, chest=(0.4, 0, 0), root=(0, -0.01, 0, 0, 0, 0))), (60, READY)])
    return c


def throw(name, length, wind=4, rel=9, through=15, end=24, hard=1.0, flash=False):
    c = Clip(name, length)
    thr = mix(RELEASE, THROUGH, 1.0 if hard >= 1 else 0.8)
    keys = [(0, READY, "CubicOut"), (wind, COCK, "ExpoIn"), (rel, RELEASE, "CubicOut"), (through, thr, "CubicOut"),
            (end, READY)]
    seq(c, keys, only=("root", "chest", "R", "L", "poles", "feet"))
    if flash:  # head turns away after the release (eyes off the flash)
        seq(c, [(0, READY), (wind, COCK), (rel, RELEASE), (12, RELEASE, "SineInOut"),
                (20, P(RELEASE, head=(-6, 22, 0)), "CubicOut"), (end, READY)], only=("head",))
    else:
        seq(c, [(0, READY), (max(1, wind - 1), COCK, "ExpoIn"), (rel, RELEASE, "CubicOut"), (end, READY)], only=("head",))
    c.marker("Release", fr(rel))
    return c


def smoke_throw():
    return throw("SmokeThrow", 0.40)


def frag_throw():
    c = throw("FragThrow", 0.40, through=17, hard=1.0)
    return c


def flash_throw():
    return throw("FlashThrow", 0.40, wind=3, through=14, flash=True)


def smoke_roll():
    """f0-f8 Cubic Out dip and arm back; f8-f16 Cubic In swing low; f16-f24 Cubic Out rise through; f24-f33 recover"""
    c = Clip("SmokeRoll", 0.55)
    dip = P(READY, root=(0, -0.55, 0.15, -12, -8, 0), chest=(-18, -10, 0), head=(6, 6, 0),
            R=("free", (0.85, -0.9, 0.55), (-60, 0, 0)), L=("free", (-0.7, 0.3, -0.9), (40, 0, 0)),
            footL=((0.05, 0, -0.55), (0, 10, 0)), poleR=(1.8, -0.4, 1.5))
    low = P(dip, root=(0, -0.6, -0.05, -16, 4, 0), chest=(-22, 6, 0), R=("free", (0.55, -1.35, -1.2), (20, 0, 0)),
            poleR=(1.8, -1.2, 0.0))
    up = P(low, root=(0, -0.35, -0.1, -10, 8, 0), chest=(-12, 8, 0), R=("free", (0.45, -0.2, -1.55), (80, 0, 0)))
    seq(c, [(0, READY, "CubicOut"), (8, dip, "CubicIn"), (16, low, "CubicOut"), (24, up, "CubicOut"), (33, READY)])
    c.marker("Release", fr(16))
    return c


def pin_pull():
    """f0-f5 Cubic Out off hand to the pin; f5-f8 Quart Out pull 0.3; f8-f12 flick; f8-f18 Cubic Out into the cocked pose"""
    c = Clip("FragPinPull", 0.30)
    at_pin = P(READY, L=("free", (0.12, 1.0, -0.72), (70, 0, 0)))
    pulled = P(at_pin, L=("free", (-0.25, 1.05, -0.75), (70, 0, -10)))
    flick = P(pulled, L=("free", (-0.55, 1.15, -0.95), (60, 0, -25)))
    seq(c, [(0, READY, "CubicOut"), (5, at_pin, "QuartOut"), (8, pulled, "CubicOut"), (18, COCK)],
        only=("root", "chest", "head", "R", "poles", "feet"))
    seq(c, [(0, READY, "CubicOut"), (5, at_pin, "QuartOut"), (8, pulled, "CubicOut"), (12, flick, "CubicOut"),
            (18, COCK)], only=("L",))
    c.marker("Pin", fr(7))
    return c


def cook():
    c = Clip("FragCook", 1.0, loop=True)
    a = add(COCK, chest=(0.3, 0.2, 0), R=((0.01, -0.01, 0), (0, 0, 0)))
    seq(c, [(0, COCK), (30, a), (60, COCK)])
    return c


def landmine():
    """f0-f12 Cubic InOut kneel (hips -1.2); f12-f20 Sine InOut set it down; f20-f22 Linear press; f22-f30 thumb the
    switch; f30-f54 Cubic InOut rise"""
    c = Clip("LandminePlace", 0.90)
    kneel = P(READY, root=(0, -1.2, 0.1, -14, 0, 0), chest=(-20, 0, 0), head=(14, 0, 0),
              footL=((0.05, 0, -0.75), (0, 10, 0)), footR=((0.0, 0.0, 0.55), (0, -15, 0)),
              R=("free", (0.35, -0.6, -1.1), (110, 0, 0)), L=("free", (-0.5, 0.1, -0.7), (60, 0, 0)),
              poleR=(1.6, -0.2, 0.3))
    down = P(kneel, R=("free", (0.3, -1.05, -1.35), (150, 0, 0)), chest=(-26, 0, 0), head=(18, 0, 0))
    press = add(down, R=((0, -0.04, 0), (0, 0, 0)))
    thumb = P(press, R=("free", (0.32, -0.98, -1.3), (150, 0, 0)))
    seq(c, [(0, READY, "CubicInOut"), (12, kneel, "SineInOut"), (20, down, "Linear"), (22, press, "SineInOut"),
            (30, thumb, "CubicInOut"), (54, READY)])
    c.marker("Placed", fr(22))
    return c


def medkit():
    """f0-f12 Cubic Out off hand pulls the kit; f12-f22 Quart Out snap open; f24-f40 Sine InOut injector to the thigh;
    f40-f42 Linear press; f42-f48 hold; f48-f110 exhale; f110-f130 Sine InOut stow; f130-f150 Cubic Out back to ready"""
    c = Clip("MedkitUse", 2.5)
    low = P(READY, R=("free", (0.6, -0.4, -0.55), (50, 0, 0)), L=("free", (-0.75, -0.55, -0.1), (-0, 0, 0)))
    pulled = P(low, L=("free", (-0.25, 0.6, -0.75), (70, 0, 0)), head=(8, 0, 0))
    opened = P(pulled, R=("free", (0.2, 0.55, -0.75), (70, 0, 0)), L=("free", (-0.35, 0.55, -0.75), (70, 0, 20)))
    inject = P(opened, root=(0, -0.15, 0.05, -6, 0, 0), chest=(-12, 0, 0), head=(14, 0, 0),
               R=("free", (0.75, -0.55, -0.35), (120, 0, 0)), L=("free", (-0.3, 0.1, -0.7), (60, 0, 0)))
    press = add(inject, R=((-0.05, -0.04, 0.02), (0, 0, 0)))
    exhale = add(press, chest=(-1.5, 0, 0), root=(0, -0.04, 0, 0, 0, 0), head=(-4, 0, 0))
    stow = P(low, L=("free", (-0.75, -0.5, 0.0), (-0, 0, 0)))
    seq(c, [(0, READY, "CubicOut"), (12, pulled, "QuartOut"), (22, opened, "SineInOut"), (24, opened, "SineInOut"),
            (40, inject, "Linear"), (42, press, "SineInOut"), (48, press, "SineInOut"), (110, exhale, "SineInOut"),
            (130, stow, "CubicOut"), (150, READY)])
    c.marker("Open", fr(22))
    c.marker("Heal", fr(42))
    return c


CLIPS = {"SmokeHold": smoke_hold, "SmokeThrow": smoke_throw, "SmokeRoll": smoke_roll, "FragPinPull": pin_pull,
         "FragCook": cook, "FragThrow": frag_throw, "FlashThrow": flash_throw, "LandminePlace": landmine,
         "MedkitUse": medkit}
