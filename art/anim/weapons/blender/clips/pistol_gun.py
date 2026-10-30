"""Pistol gun-part clips on the remodel (art/guns/manifest/Pistol.json: Slide, Mag, MagRelease, SlideStop, Trigger, Round):
Fire, Reload (tactical), ReloadEmpty, Inspect. Beats: notes/anim_style_targets.md section 1."""
from rbxanim import Clip, P, add, seq, fr

SLIDE = lambda z: ((0, 0, z), (0, 0, 0))
TRIG = lambda a: ((0, 0, 0), (-a, 0, 0))
WRIST = (0.0, 0.0, 0.29)  # the gun hand's wrist in the gun frame (Tool.Grip identity): the off hand mirrors it


def add_t(a, b):
    return tuple(x + y for x, y in zip(a, b))


def make(poses, prefix="Pistol"):
    """returns the four builders for a pistol-type gun (poses = the set's poses(c) function)"""

    def fire():
        """f0 = Hold, f1 peak (wrist +8, elbows +4, shoulders 0.06 back, chest +1) Linear, f1-f9 Cubic Out return.
        Slide f0-f1 back, f1-f3 Quad In forward (hard stop); trigger pulled at f0, resets f2-f6."""
        c = Clip(prefix + "Fire", 0.15)
        h, _, _ = poses(c)
        peak = add(h, gun=((0, 0.05, 0.08), (8, 0.5, 0)), chest=(1, 0, 0), head=(0.5, 0, 0))
        seq(c, [(0, h, "Linear"), (1, peak, "CubicOut"), (9, h)], only=("root", "chest", "head", "gun", "R", "L", "poles", "feet"))
        for f, z, e in ((0, 0, "Linear"), (1, 0.3, "QuadIn"), (3, 0, "Constant"), (9, 0, "Constant")):
            c.part("Slide", fr(f), (0, 0, z), ease=e)
        for f, a, e in ((0, 15, "Constant"), (2, 15, "CubicOut"), (6, 0, "Constant"), (9, 0, "Constant")):
            c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
        c.marker("ShellEject", fr(1))
        return c

    def reload_poses(c):
        h, _, _ = poses(c)
        g = h["gun"][0]
        tilt = P(h, gun=((g[0] - 0.2, g[1] - 0.15, g[2] + 0.35), (8, 6, 20)), head=(-8, 0, 0), chest=(-1, 0, 0),
                 poleR=(1.6, -0.9, 0.7))
        under = (0.0, -0.36, 0.29)       # off-hand wrist cupping the mag base (gun frame)
        pouch = (-0.62, -0.05, -0.62)    # off-hand wrist at the belt mag pouch (chest frame)
        return h, tilt, under, pouch

    def mag_release(c, f0):
        for f, d in ((0, 0), (f0 - 1, 0), (f0, 1), (f0 + 2, 1), (f0 + 4, 0)):
            c.part("MagRelease", fr(f), (-0.03 * d, 0, 0), ease="CubicOut")

    def reload():
        """tactical: f0-f6 Cubic Out tilt; f6 release; mag out f6-f12 Cubic Out (off hand strips it); f12-f28 Sine InOut to
        the pouch; f28-f44 Sine InOut new mag to the well; f44-f46 Linear seat + heel push; f46-f50 hold; f50-f62 Quart Out
        gun back up; off hand rewraps f56-f64; f64-f90 hold. Cancel before f46"""
        c = Clip(prefix + "Reload", 1.5)
        h, tilt, under, pouch = reload_poses(c)
        seated = add(tilt, gun=((0, -0.03, 0), (0, 0, 0)))
        seq(c, [(0, h, "CubicOut"), (6, tilt), (44, tilt, "Linear"), (46, seated, "SineInOut"), (50, tilt, "QuartOut"), (62, h),
                (90, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
        L = h["L"]
        c.hand_on("L", fr(0), L[1], L[2], ease="CubicOut"); c.free("L", fr(0), 0)
        c.hand_on("L", fr(6), under, (0, 0, 0), ease="CubicOut")
        c.hand_on("L", fr(12), (0, -0.66, 0.36), (0, 0, 0), ease="SineInOut"); c.free("L", fr(12), 0, ease="SineInOut")
        c.hand_free("L", fr(0), pouch, (60, 0, 0)); c.hand_free("L", fr(90), pouch, (60, 0, 0))
        c.free("L", fr(28), 1, ease="SineInOut"); c.free("L", fr(30), 1, ease="SineInOut")
        c.hand_on("L", fr(30), (0, -0.66, 0.36), (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(44), (0, -0.4, 0.3), (0, 0, 0), ease="Linear"); c.free("L", fr(44), 0, ease="Linear")
        c.hand_on("L", fr(46), under, (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(52), under, (0, 0, 0), ease="CubicInOut")
        c.hand_on("L", fr(64), L[1], L[2]); c.hand_on("L", fr(90), L[1], L[2])
        for f in (0, 90):
            c.held("Mag", fr(f), (0, 0, -0.36))
        c.inhand("Mag", fr(5), 0, ease="Linear"); c.inhand("Mag", fr(6), 1, ease="Constant")
        c.inhand("Mag", fr(45), 1, ease="Linear"); c.inhand("Mag", fr(46), 0, ease="Constant")
        mag_release(c, 6)
        c.marker("MagOut", fr(6)); c.marker("MagStowed", fr(28)); c.marker("MagIn", fr(46))
        return c

    def reload_empty():
        """slide locked back from f0. f0-f6 tilt; f6 release, mag drops free f6-f18 Quad In (MagHide f18) while the off hand
        goes to the pouch f6-f16; f16-f36 new mag; f36-f38 Linear seat; f38-f41 hold; f41-f52 off hand over the top; Slide
        back f52-f55 Cubic Out, hold f55-f57, forward f57-f59 Quad In hard stop; f59-f74 Quart Out up, rewrap f62-f72"""
        c = Clip(prefix + "ReloadEmpty", 1.9)
        h, tilt, under, pouch = reload_poses(c)
        seated = add(tilt, gun=((0, -0.03, 0), (0, 0, 0)))
        rack = add(tilt, gun=((0, 0, -0.05), (0, 0, 0)))
        seq(c, [(0, h, "CubicOut"), (6, tilt), (36, tilt, "Linear"), (38, seated, "SineInOut"), (41, tilt), (52, tilt, "CubicOut"),
                (55, rack), (57, rack, "QuadIn"), (59, tilt, "QuartOut"), (74, h), (114, h)],
            only=("root", "chest", "head", "gun", "R", "poles", "feet"))
        L = h["L"]
        top = (0.0, 0.42, 0.15)  # off-hand wrist over the slide's rear serrations
        c.hand_on("L", fr(0), L[1], L[2], ease="CubicOut"); c.free("L", fr(0), 0, ease="SineInOut")
        c.hand_free("L", fr(0), pouch, (60, 0, 0)); c.hand_free("L", fr(114), pouch, (60, 0, 0))
        c.free("L", fr(6), 0, ease="SineInOut"); c.hand_on("L", fr(6), under, (0, 0, 0))
        c.free("L", fr(16), 1, ease="SineInOut")
        c.hand_on("L", fr(16), (0, -0.66, 0.36), (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(34), (0, -0.4, 0.3), (0, 0, 0), ease="Linear"); c.free("L", fr(34), 0, ease="Linear")
        c.hand_on("L", fr(36), (0, -0.4, 0.3), (0, 0, 0), ease="Linear")
        c.hand_on("L", fr(38), under, (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(41), under, (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(52), top, (0, 0, 90), ease="CubicOut")
        c.hand_on("L", fr(55), add_t(top, (0, 0, 0.33)), (0, 0, 90), ease="SineInOut")
        c.hand_on("L", fr(57), add_t(top, (0, 0, 0.33)), (0, 0, 90), ease="CubicOut")
        c.hand_on("L", fr(62), add_t(top, (0, 0.1, 0.45)), (0, 0, 90), ease="CubicInOut")
        c.hand_on("L", fr(72), L[1], L[2]); c.hand_on("L", fr(114), L[1], L[2])
        for f, z, e in ((0, 0.3, "Constant"), (52, 0.3, "CubicOut"), (55, 0.33, "SineInOut"), (57, 0.33, "QuadIn"),
                        (59, 0.0, "Constant"), (114, 0.0, "Constant")):
            c.part("Slide", fr(f), (0, 0, z), ease=e)
        for f, a in ((0, 12), (56, 12), (58, 0), (114, 0)):
            c.part("SlideStop", fr(f), (0, 0, 0), (a, 0, 0), ease="CubicOut")
        for f, y, e in ((0, 0, "Constant"), (6, 0, "QuadIn"), (18, -2.6, "Constant"), (19, 0, "Constant")):
            c.part("Mag", fr(f), (0, y, -0.23 * y), ease=e)
        for f in (0, 114):
            c.held("Mag", fr(f), (0, 0, -0.36))
        c.inhand("Mag", fr(18), 0, ease="Constant"); c.inhand("Mag", fr(19), 1, ease="Constant")
        c.inhand("Mag", fr(37), 1, ease="Linear"); c.inhand("Mag", fr(38), 0, ease="Constant")
        mag_release(c, 6)
        c.marker("MagOut", fr(6)); c.marker("MagHide", fr(18)); c.marker("MagShow", fr(19)); c.marker("MagIn", fr(38))
        c.marker("SlideRack", fr(59))
        return c

    def inspect():
        """f0-f20 Cubic InOut closer (0.6), roll 70; f20-f60 hold; f60-f80 roll over; f80-f100 hold; off hand pinches the
        Slide f100-f106 back 0.15 Cubic Out, f106-f118 hold (look), f118-f120 Quad In forward; f120-f150 thumb taps the mag
        base; f150-f180 Cubic Out back to Hold"""
        c = Clip(prefix + "Inspect", 3.0)
        h, _, _ = poses(c)
        near = (0.25, h["gun"][0][1] - 0.1, -0.85)
        showL = P(h, gun=(near, (10, 25, 70)), head=(-10, 8, 0), poleR=(1.6, -0.8, 0.8))
        showL2 = add(showL, gun=((0, 0.02, 0), (1.5, 1, 2)), head=(1, 0, 0))
        showR = P(showL, gun=(near, (10, -10, -60)), head=(-12, 0, 0), L=("gun", (0.0, 0.42, 0.27), (0, 0, 90)))
        showR2 = add(showR, gun=((0, 0.02, 0), (1.5, -1, -2)))
        check = P(showR, gun=(add_t(near, (0, 0.05, 0.05)), (5, 0, -25)), head=(-14, 4, 0),
                  L=("gun", (0.0, 0.42, 0.27), (0, 0, 90)))  # reach check at the pinch's rear point
        seq(c, [(0, h, "CubicInOut"), (20, showL, "SineInOut"), (60, showL2, "CubicInOut"), (80, showR, "SineInOut"),
                (98, showR2, "SineInOut"), (100, check, "SineInOut"), (118, check, "SineInOut"),
                (150, add(check, gun=((0, 0.03, 0), (2, 0, 3))), "CubicOut"), (180, h)],
            only=("root", "chest", "head", "gun", "R", "poles", "feet"))
        L = h["L"]
        pinch = (0.0, 0.42, 0.12)
        rest = (-0.55, 0.55, -0.7)
        c.hand_free("L", fr(0), rest, (70, 0, 0)); c.hand_free("L", fr(180), rest, (70, 0, 0))
        c.free("L", fr(0), 0, ease="CubicInOut"); c.hand_on("L", fr(0), L[1], L[2], ease="CubicInOut")
        c.free("L", fr(20), 1, ease="SineInOut")
        c.free("L", fr(92), 1, ease="CubicOut"); c.hand_on("L", fr(92), pinch, (0, 0, 90), ease="CubicOut")
        c.free("L", fr(100), 0, ease="CubicOut"); c.hand_on("L", fr(100), pinch, (0, 0, 90), ease="CubicOut")
        c.hand_on("L", fr(106), add_t(pinch, (0, 0, 0.15)), (0, 0, 90), ease="SineInOut")
        c.hand_on("L", fr(118), add_t(pinch, (0, 0, 0.15)), (0, 0, 90), ease="QuadIn")
        c.hand_on("L", fr(120), (0.0, -0.3, 0.3), (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(135), (0.0, -0.42, 0.32), (0, 0, 0), ease="SineInOut")
        c.hand_on("L", fr(150), (0.0, -0.36, 0.3), (0, 0, 0), ease="CubicOut")
        c.hand_on("L", fr(180), L[1], L[2])
        for f, z, e in ((0, 0, "Constant"), (100, 0, "CubicOut"), (106, 0.15, "SineInOut"), (118, 0.15, "QuadIn"),
                        (120, 0, "Constant"), (180, 0, "Constant")):
            c.part("Slide", fr(f), (0, 0, z), ease=e)
        c.marker("SlideRack", fr(120))
        return c

    return {prefix + "Fire": fire, prefix + "Reload": reload, prefix + "ReloadEmpty": reload_empty, prefix + "Inspect": inspect}
