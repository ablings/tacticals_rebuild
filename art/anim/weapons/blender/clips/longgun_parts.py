"""Gun-part clips shared by the long guns: magazine reloads (tactical / empty + charge), inspect."""
from rbxanim import Clip, P, add, seq, fr

WRIST0 = (0.0, 0.0, 0.29)  # the gun hand's wrist in the gun frame (all tools: Grip identity)


def add_t(a, b):
    return tuple(x + y for x, y in zip(a, b))


def held_at(c, part, f, W, ease="SineInOut"):
    """the left hand carries `part` with its wrist at gun-frame point W when the part sits at its rest"""
    d = tuple(a - b for a, b in zip(WRIST0, W))
    c.held(part, fr(f), (d[0], d[2], -d[1]), ease=ease)


def tilt_pose(G, c, roll=-25, pitch=-10, well=(0, 0.235, -0.8), at=(-0.15, 1.12, -1.02)):
    """off the shoulder for the reload: the magwell in front of the left chest, gun across the body, rolled to the off hand"""
    h = G.hold(c)
    return P(h, gun=(well, at, (pitch, G.blade, roll)), head=(-12, 24, 0), poleR=(1.5, -0.9, 0.9))


def mag_reload(G, name, length, beats, mag="Mag", under=(0.0, -0.7, -0.85), pouch=(-0.25, 0.75, -0.6),
               empty=False, charge=None, release="MagRelease", drop=(0, -2.4, -0.3), extra_parts=None, tilt=None,
               charge_shift=(-1.0, 0.05, 0.75)):
    """beats (frames): tilt, release, out, stowed, seat, (empty: hide, show), rewrap, shoulder, end.
    charge = (part, travel, grab W, f_grab, f_back, f_hold, f_fwd) for the run-the-gun beat."""
    b = beats
    c = Clip(name, length)
    h = G.hold(c)
    t = tilt or tilt_pose(G, c)
    # the reach check of the tilted gun uses the lowest point the off hand works at (the strip), so it can always reach
    t = P(t, L=("gun", (under[0], under[1] - 0.35, under[2] + 0.05), (0, 0, 0)))
    seat = add(t, gun=((0, 0.02, 0), (1.5, 0, 0)))
    L = h["L"]
    keys = [(0, h, "CubicOut"), (b["tilt"], t), (b["seat"] - 2, t, "Linear"), (b["seat"], seat, "CubicOut"), (b["seat"] + 4, t)]
    if charge:
        cp, travel, cw, fg, fb, fh, ff = charge
        tc = add(t, gun=(charge_shift, (0, -8, 10)))  # gun brought across to the off hand for the charge
        keys += [(fg - 6, t, "CubicInOut"), (fg, tc, "CubicOut"), (fb, add(tc, gun=((0, 0, -0.04), (0, 0, 0))), "SineInOut"),
                 (fh, add(tc, gun=((0, 0, -0.04), (0, 0, 0))), "QuadIn"), (ff, tc, "CubicInOut")]
    keys += [(b["rewrap"], t, "QuartOut"), (b["shoulder"], h), (b["end"], h)]
    keys.sort(key=lambda k: k[0])
    seq(c, keys, only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    c.hand_free("L", 0, pouch, (70, 0, 0)); c.hand_free("L", fr(b["end"]), pouch, (70, 0, 0))
    c.free("L", 0, 0, ease="CubicOut"); c.hand_on("L", 0, L[1], L[2], ease="CubicOut")
    g0 = max(2, b["release"] - 10)
    c.hand_on("L", fr(g0), L[1], L[2], ease="CubicOut")
    c.hand_on("L", fr(b["release"]), under, (0, 0, 0), ease="CubicOut")
    low = (under[0], under[1] - 0.35, under[2] + 0.05)
    if not empty:
        c.hand_on("L", fr(b["out"]), low, (0, 0, 0), ease="SineInOut"); c.free("L", fr(b["out"]), 0, ease="SineInOut")
        c.free("L", fr(b["stowed"]), 1, ease="SineInOut"); c.free("L", fr(b["stowed"] + 2), 1, ease="SineInOut")
        c.hand_on("L", fr(b["stowed"] + 2), low, (0, 0, 0), ease="SineInOut")
    else:
        c.free("L", fr(b["release"]), 0, ease="SineInOut"); c.free("L", fr(b["show"]), 1, ease="SineInOut")
        c.hand_on("L", fr(b["show"]), low, (0, 0, 0), ease="SineInOut")
    mouth = (under[0], under[1] - 0.25, under[2] - 0.05)
    c.hand_on("L", fr(b["seat"] - 2), mouth, (0, 0, 0), ease="Linear"); c.free("L", fr(b["seat"] - 2), 0, ease="Linear")
    c.hand_on("L", fr(b["seat"]), under, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(b["seat"] + 4), under, (0, 0, 0), ease="SineInOut")
    if charge:
        cp, travel, cw, fg, fb, fh, ff = charge
        c.hand_on("L", fr(fg), cw, (0, 0, 90), ease="CubicOut")
        c.hand_on("L", fr(fb), add_t(cw, (0, 0, travel)), (0, 0, 90), ease="SineInOut")
        c.hand_on("L", fr(fh), add_t(cw, (0, 0, travel)), (0, 0, 90), ease="CubicOut")
        c.hand_on("L", fr(ff + 4), add_t(cw, (0, 0.15, travel)), (0, 0, 90), ease="CubicInOut")
        for ppart in (cp,) + tuple(extra_parts or ()):
            for f, z, e in ((0, 0, "Constant"), (fg, 0, "CubicOut"), (fb, travel, "SineInOut"), (fh, travel, "QuadIn"),
                            (ff, 0, "Constant"), (b["end"], 0, "Constant")):
                c.part(ppart, fr(f), (0, 0, z), ease=e)
        c.marker("SlideRack", fr(ff))
    c.hand_on("L", fr(b["rewrap"]), L[1], L[2], ease="CubicInOut"); c.hand_on("L", fr(b["end"]), L[1], L[2])
    held_at(c, mag, 0, under); held_at(c, mag, b["end"], under)
    if not empty:
        c.inhand(mag, fr(b["release"] - 1), 0, ease="Linear"); c.inhand(mag, fr(b["release"]), 1, ease="Constant")
    else:
        for f, k, e in ((0, 0, "Constant"), (b["release"], 0, "QuadIn"), (b["hide"], 1, "Constant"), (b["show"], 0, "Constant")):
            c.part(mag, fr(f), tuple(x * k for x in drop), ease=e)
        c.inhand(mag, fr(b["hide"]), 0, ease="Constant"); c.inhand(mag, fr(b["show"]), 1, ease="Constant")
        c.marker("MagHide", fr(b["hide"])); c.marker("MagShow", fr(b["show"]))
    c.inhand(mag, fr(b["seat"] - 1), 1, ease="Linear"); c.inhand(mag, fr(b["seat"]), 0, ease="Constant")
    if release:
        for f, d in ((0, 0), (b["release"] - 1, 0), (b["release"], 1), (b["release"] + 2, 1), (b["release"] + 4, 0)):
            c.part(release, fr(f), (-0.03 * d, 0, 0), ease="CubicOut")
    c.marker("MagOut", fr(b["release"]))
    if not empty:
        c.marker("MagStowed", fr(b["stowed"]))
    c.marker("MagIn", fr(b["seat"]))
    return c


def gun_inspect(G, name, roll=45, parts_fn=None, marker=None, length=3.0):
    """f0-f24 Cubic InOut lift and roll; f24-f60 hold; part checks (parts_fn); f150-f180 Cubic Out back to Hold"""
    c = Clip(name, length)
    h = G.hold(c)
    gp, tgt, rot = h["gun"]
    show = P(h, gun=((0, 0.3, -0.6), (0.1, 1.55, -1.0), (8, rot[1] + 10, roll)), head=(-12, 22, 0))
    show2 = add(show, gun=((0, 0.02, 0), (1.5, 1, 2)), head=(1, 0, 0))
    show3 = add(show, gun=((0, -0.02, 0), (-1, -2, -roll * 0.6)), head=(-2, 0, 0))
    seq(c, [(0, h, "CubicInOut"), (24, show, "SineInOut"), (60, show2, "SineInOut"), (100, show3, "SineInOut"), (150, show2, "CubicOut"),
            (180, h)])
    if parts_fn:
        parts_fn(c)
    if marker:
        c.marker(*marker)
    return c
