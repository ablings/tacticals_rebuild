"""Pistol-prefix reload variants (Pistol 1.3 s = 78 f; Suppressed plays the same clips at AdjustSpeed 78/90, exact).
Design: notes/reload_variants_design.md "Pistol". Shared anchors: tilt f0-f6, MagOut f6, MagIn f42, settled (Ready) f62,
f62-f78 moving hold.
  Retain (7-11 left; Suppressed 6-9): strip the mag, stow it, new mag.
  Drop   (1-6 left; Suppressed 1-5): mag drops free, new mag with a look, press check on the slide.
  Dry    (0): slide locked back, mag drops free, new mag, thumb drops the slide stop."""
import pistol
from rbxanim import Clip, P, add, seq, fr
from pistol_gun import add_t

GUN = "Pistol"
TOOL = "Pistol"
BASE_NAME = "PistolReload"
BASE_LEN = 1.3
END = 78
READY = 62
UNDER = (0.0, -0.36, 0.29)       # off-hand wrist cupping the mag base (gun frame)
POUCH = (-0.62, -0.05, -0.62)    # off-hand wrist at the belt mag pouch (chest frame)
WELL_LOW = (0, -0.66, 0.36)      # new mag below the well
MOUTH = (0, -0.4, 0.3)           # mag tip at the well mouth
TOP = (0.0, 0.42, 0.15)          # off-hand wrist over the slide's rear serrations


def base(c):
    h, _, _ = pistol.poses(c)
    g = h["gun"][0]
    tilt = P(h, gun=((g[0] - 0.2, g[1] - 0.15, g[2] + 0.35), (8, 6, 20)), head=(-8, 0, 0), chest=(-1, 0, 0),
             poleR=(1.6, -0.9, 0.7))
    return h, tilt


def moving_hold(c, h):
    """f62-f78: chest and head drift 0.4 deg and back (the end pose = the hold)"""
    seq(c, [(READY, h, "SineInOut"), (70, add(h, chest=(0.4, 0, 0), head=(0.3, 0, 0))), (END, h)], only=("chest", "head"))


def mag_release(c):
    for f, d in ((0, 0), (5, 0), (6, 1), (8, 1), (10, 0)):
        c.part("MagRelease", fr(f), (-0.03 * d, 0, 0), ease="CubicOut")


def off_hand_drop(c, h):
    """f0 off hand leaves the grip; f6 cups the mag base as it releases; f6-f14 to the pouch (free); new mag f14-f40;
    seat f40-f42 Linear"""
    L = h["L"]
    c.hand_on("L", fr(0), L[1], L[2], ease="CubicOut"); c.free("L", fr(0), 0, ease="SineInOut")
    c.hand_free("L", fr(0), POUCH, (60, 0, 0)); c.hand_free("L", fr(END), POUCH, (60, 0, 0))
    c.free("L", fr(6), 0, ease="SineInOut"); c.hand_on("L", fr(6), UNDER, (0, 0, 0))
    c.free("L", fr(14), 1, ease="SineInOut")
    c.free("L", fr(16), 1, ease="SineInOut")
    c.hand_on("L", fr(16), WELL_LOW, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(38), MOUTH, (0, 0, 0), ease="Linear"); c.free("L", fr(38), 0, ease="Linear")
    c.hand_on("L", fr(40), MOUTH, (0, 0, 0), ease="Linear")
    c.hand_on("L", fr(42), UNDER, (0, 0, 0), ease="SineInOut")


def mag_drop(c):
    """mag falls free f6-f16 Quad In (MagHide f16), the hand's new mag shows f17, seated f42"""
    for f, y, e in ((0, 0, "Constant"), (6, 0, "QuadIn"), (16, -2.6, "Constant"), (17, 0, "Constant"), (END, 0, "Constant")):
        c.part("Mag", fr(f), (0, y, -0.23 * y), ease=e)
    for f in (0, END):
        c.held("Mag", fr(f), (0, 0, -0.36))
    c.inhand("Mag", fr(16), 0, ease="Constant"); c.inhand("Mag", fr(17), 1, ease="Constant")
    c.inhand("Mag", fr(41), 1, ease="Linear"); c.inhand("Mag", fr(42), 0, ease="Constant")
    c.marker("MagOut", fr(6)); c.marker("MagHide", fr(16)); c.marker("MagShow", fr(17)); c.marker("MagIn", fr(42))


def retain():
    """f0-f6 tilt; f6 release, off hand strips the mag f6-f12 Cubic Out; to the hip pouch f12-f24 Sine InOut (MagStowed
    f24); new mag f24-f40; seat f40-f42 Linear (MagIn); f42-f44 hold; f44-f62 Quart Out up, rewrap f50-f58; f62-f78 moving hold"""
    c = Clip("PistolReload_Retain", BASE_LEN)
    h, tilt = base(c)
    seated = add(tilt, gun=((0, -0.03, 0), (0, 0, 0)))
    seq(c, [(0, h, "CubicOut"), (6, tilt), (40, tilt, "Linear"), (42, seated, "SineInOut"), (44, tilt, "QuartOut"), (READY, h), (END, h)],
        only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    moving_hold(c, h)
    L = h["L"]
    c.hand_on("L", fr(0), L[1], L[2], ease="CubicOut"); c.free("L", fr(0), 0)
    c.hand_free("L", fr(0), POUCH, (60, 0, 0)); c.hand_free("L", fr(END), POUCH, (60, 0, 0))
    c.hand_on("L", fr(6), UNDER, (0, 0, 0), ease="CubicOut")
    c.hand_on("L", fr(12), WELL_LOW, (0, 0, 0), ease="SineInOut"); c.free("L", fr(12), 0, ease="SineInOut")
    c.free("L", fr(24), 1, ease="SineInOut"); c.free("L", fr(26), 1, ease="SineInOut")
    c.hand_on("L", fr(26), WELL_LOW, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(40), MOUTH, (0, 0, 0), ease="Linear"); c.free("L", fr(40), 0, ease="Linear")
    c.hand_on("L", fr(42), UNDER, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(50), UNDER, (0, 0, 0), ease="CubicInOut")
    c.hand_on("L", fr(58), L[1], L[2]); c.hand_on("L", fr(END), L[1], L[2])
    for f in (0, END):
        c.held("Mag", fr(f), (0, 0, -0.36))
    c.inhand("Mag", fr(5), 0, ease="Linear"); c.inhand("Mag", fr(6), 1, ease="Constant")
    c.inhand("Mag", fr(41), 1, ease="Linear"); c.inhand("Mag", fr(42), 0, ease="Constant")
    mag_release(c)
    c.marker("MagOut", fr(6)); c.marker("MagStowed", fr(24)); c.marker("MagIn", fr(42)); c.marker("Ready", fr(READY))
    return c


def drop():
    """f0-f6 tilt; mag drops free f6-f16; off hand to the pouch f6-f14; new mag f16-f40 with a head lead to the well (f28);
    seat f40-f42 (MagIn); off hand over the top f42-f45; press check: Slide back 0.12 f45-f47 Cubic Out, hold f47-f50,
    forward f50-f52 Quad In; f52-f62 Quart Out up, rewrap f52-f60; moving hold"""
    c = Clip("PistolReload_Drop", BASE_LEN)
    h, tilt = base(c)
    look = add(tilt, head=(-5, 0, 0))
    seated = add(look, gun=((0, -0.03, 0), (0, 0, 0)))
    check = add(tilt, gun=((0.02, 0.02, 0), (3, 0, -4)))
    seq(c, [(0, h, "CubicOut"), (6, tilt, "SineInOut"), (28, look), (40, look, "Linear"), (42, seated, "SineInOut"), (45, check),
            (50, check, "SineInOut"), (52, check, "QuartOut"), (READY, h), (END, h)],
        only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    moving_hold(c, h)
    off_hand_drop(c, h)
    L = h["L"]
    c.hand_on("L", fr(45), TOP, (0, 0, 90), ease="CubicOut")
    c.hand_on("L", fr(47), add_t(TOP, (0, 0, 0.12)), (0, 0, 90), ease="SineInOut")
    c.hand_on("L", fr(50), add_t(TOP, (0, 0, 0.12)), (0, 0, 90), ease="QuadIn")
    c.hand_on("L", fr(52), TOP, (0, 0, 90), ease="CubicInOut")
    c.hand_on("L", fr(60), L[1], L[2]); c.hand_on("L", fr(END), L[1], L[2])
    for f, z, e in ((0, 0, "Constant"), (45, 0, "CubicOut"), (47, 0.12, "SineInOut"), (50, 0.12, "QuadIn"), (52, 0, "Constant"),
                    (END, 0, "Constant")):
        c.part("Slide", fr(f), (0, 0, z), ease=e)
    mag_drop(c); mag_release(c)
    c.marker("PressCheck", fr(47)); c.marker("Ready", fr(READY))
    return c


def dry():
    """Slide locked back from f0 (0.3 back, SlideStop up 12). f0-f6 tilt; mag drops free f6-f16; new mag; seat f40-f42
    (MagIn); f42-f46 hold, gun rolls a touch toward the thumb; f46 SlideStop down, Slide forward f46-f48 Quad In hard stop
    (SlideRack f48) with a 1 deg kick; f48-f62 Quart Out up, rewrap f52-f60; moving hold"""
    c = Clip("PistolReload_Dry", BASE_LEN)
    h, tilt = base(c)
    look = add(tilt, head=(-4, 0, 0))
    seated = add(look, gun=((0, -0.03, 0), (0, 0, 0)))
    thumb = add(tilt, gun=((0.03, 0.02, 0), (2, 0, -6)))
    kick = add(thumb, gun=((0, 0.02, 0.03), (1, 0, 0)))
    seq(c, [(0, h, "CubicOut"), (6, tilt, "SineInOut"), (28, look), (40, look, "Linear"), (42, seated, "SineInOut"), (44, thumb, "Linear"),
            (46, thumb, "Linear"), (48, kick, "CubicOut"), (51, thumb, "QuartOut"), (READY, h), (END, h)],
        only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    moving_hold(c, h)
    off_hand_drop(c, h)
    L = h["L"]
    c.hand_on("L", fr(46), UNDER, (0, 0, 0), ease="CubicInOut")
    c.hand_on("L", fr(60), L[1], L[2]); c.hand_on("L", fr(END), L[1], L[2])
    for f, z, e in ((0, 0.3, "Constant"), (46, 0.3, "QuadIn"), (48, 0.0, "Constant"), (END, 0.0, "Constant")):
        c.part("Slide", fr(f), (0, 0, z), ease=e)
    for f, a, e in ((0, 12, "Constant"), (45, 12, "Linear"), (46, 0, "Constant"), (END, 0, "Constant")):
        c.part("SlideStop", fr(f), (0, 0, 0), (a, 0, 0), ease=e)
    mag_drop(c); mag_release(c)
    c.marker("SlideRack", fr(48)); c.marker("Ready", fr(READY))
    return c


ROUNDS = {"PistolReload_Retain": "Pistol 7-11, Suppressed 6-9", "PistolReload_Drop": "Pistol 1-6, Suppressed 1-5",
          "PistolReload_Dry": "0"}
CLIPS = {"PistolReload_Retain": retain, "PistolReload_Drop": drop, "PistolReload_Dry": dry}
