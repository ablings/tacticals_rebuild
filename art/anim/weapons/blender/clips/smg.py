"""SMG set (Mini Uzi): targets section 3, on the remodelled MiniUzi (Mag in the grip, CockingKnob on top, Stock folds).
Compact two-hand hold: gun hand on the grip, off hand under the receiver front, elbows tucked, gun at chin height."""
from rbxanim import Clip, P, add, mix, seq, fr
from longgun_parts import mag_reload, held_at, add_t

GUN = "MiniUzi"
TOOL = "MiniUzi"


class SMG:
    blade = 20

    def hold(self, c):
        a = c.anchor
        feet = dict(footL=((0.05, 0, -0.25), (0, 12, 0)), footR=((0.0, 0, 0.2), (0, -15, 0)))
        return P(root=(0, -0.09, 0.02, -2, -6, 0), chest=(-3, -6, 0), head=(-4, 8, 0),
                 gun=((0.22, a["shoulderR"][1] - 0.12, -0.72), (0, 10, 0)),
                 R=("gun", (0, 0, 0), (0, 0, 0)), L=("gun", (0.0, 0.08, -0.32), (0, 0, -70)),
                 poleR=(1.5, -1.0, 0.4), poleL=(-1.5, -1.0, 0.2), **feet)

    def lowered(self, c):
        h = self.hold(c)
        return P(h, gun=((0.25, 0.5, -0.78), (-38, 14, 0)), head=(-2, 6, 0), poleR=(1.6, -1.2, 0.6))


G = SMG()


def breathe(c, p, amp=0.4, sink=0.012):
    seq(c, [(0, p), (30, add(p, chest=(amp, 0, 0), root=(0, -sink, 0, 0, 0, 0))), (60, p)])


def hold():
    c = Clip("SMGHold", 1.0, loop=True); breathe(c, G.hold(c)); return c


def lowered():
    c = Clip("SMGLowered", 1.0, loop=True); breathe(c, G.lowered(c)); return c


def equip():
    """f0-f9 Quart Out, f9-f13 Back Out 4%, f13-f21 hold"""
    c = Clip("SMGEquip", 0.35)
    h, l = G.hold(c), G.lowered(c)
    seq(c, [(0, l, "QuartOut"), (9, add(h, gun=((0, 0.012, -0.015), (0.6, 0, 0))), "BackOut:0.5"), (13, h), (21, add(h, chest=(0.15, 0, 0)))])
    return c


def fire():
    """restarts each shot (fade 0.03): f1 peak (muzzle +2.5, shoulders 0.04 back, chest +0.5) Linear, f1-f6 Cubic Out;
    yaw 0.3 toward the gun hand. Open bolt: the knob stays put."""
    c = Clip("SMGFire", 0.10)
    h = G.hold(c)
    pk = add(h, gun=((0, 0.01, 0.04), (2.5, -0.3, 0)), chest=(0.5, 0, 0))
    seq(c, [(0, h, "Linear"), (1, pk, "CubicOut"), (6, h)])
    for f, a, e in ((0, 15, "Constant"), (2, 15, "CubicOut"), (5, 0, "Constant"), (6, 0, "Constant")):
        c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
    c.marker("ShellEject", fr(1))
    return c


def tilt(c):
    h = G.hold(c)
    return P(h, gun=((-0.12, 1.2, -0.72), (5, 25, 25)), head=(-12, 10, 0), poleR=(1.5, -1.2, 0.6))


UNDER = (0.0, -0.78, 0.3)   # off-hand wrist under the grip, cupping the mag base


def reload():
    """f0-f6 tilt 25; f6-f10 off hand to the grip base; f10 release, Mag out the bottom f10-f16; f16-f34 stow; f34-f54 new
    mag; f54-f56 Linear seat + heel slap; f56-f60 hold; f60-f80 off hand to the front; f80-f94 Quart Out up; hold"""
    return mag_reload(G, "SMGReload", 1.9, dict(tilt=6, release=10, out=16, stowed=34, seat=56, rewrap=80, shoulder=94, end=114),
                      under=UNDER, pouch=(-0.6, -0.05, -0.6), release=None, tilt=tilt(Clip("_t", 1.0)))


def reload_empty():
    """mag drops free f10-f22 (MagHide); new mag; seat f56; f60-f72 off hand over the top; CockingKnob back f72-f76 Cubic Out,
    hold f76-f78, forward f78-f80 Quad In; f80-f104 off hand to the front; f104-f118 up; hold to f138"""
    return mag_reload(G, "SMGReloadEmpty", 2.3, dict(tilt=6, release=10, hide=22, show=23, seat=56, rewrap=104, shoulder=118, end=138),
                      under=UNDER, pouch=(-0.6, -0.05, -0.6), release=None, empty=True, drop=(0, -2.4, 0),
                      charge=("CockingKnob", 0.35, (0.0, 0.62, 0.05), 72, 76, 78, 80), charge_shift=(-0.3, 0.05, 0.1),
                      tilt=tilt(Clip("_t", 1.0)))


def draw():
    """from the hip sling: f0-f5 Cubic Out hand to grip (Grip f5); f5-f18 Quart Out up and out, off hand catches the front
    f14; f18-f22 Back 4%; f22-f30 hold"""
    c = Clip("SMGDraw", 0.50)
    h = G.hold(c)
    slung = P(h, gun=((1.02, -0.18, 0.0), (-80, 0, 10)), L=("free", (-1.0, -0.2, -0.05), (0, 0, 0)), head=(-4, 0, 0))
    start = P(slung, R=("free", (1.0, -0.15, -0.1), (0, 0, 0)))
    seq(c, [(0, start, "CubicOut"), (5, slung, "QuartOut"), (18, add(h, gun=((0, 0.012, -0.015), (0.5, 0, 0))), "BackOut:0.5"),
            (22, h), (30, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    seq(c, [(0, start, "SineInOut"), (8, P(slung, L=("free", (-0.5, 0.6, -0.8), (70, 0, 0))), "QuartOut"), (14, h), (30, h)], only=("L",))
    c.marker("Grip", fr(5))
    return c


def holster():
    """f0-f10 Cubic InOut down and in; f10-f18 Sine InOut to the sling; f18 release; f18-f27 Cubic Out off"""
    c = Clip("SMGHolster", 0.45)
    h = G.hold(c)
    slung = P(h, gun=((1.02, -0.18, 0.0), (-80, 0, 10)), L=("free", (-1.0, -0.2, -0.05), (0, 0, 0)), head=(-4, 0, 0))
    mid = P(h, gun=((0.6, 0.3, -0.5), (-50, 10, 0)), L=("free", (-0.55, 0.4, -0.7), (60, 0, 0)))
    after = P(slung, R=("free", (1.0, -0.15, -0.1), (0, 0, 0)))
    seq(c, [(0, h, "CubicInOut"), (10, mid, "SineInOut"), (18, slung, "CubicOut"), (27, after)])
    c.marker("Holstered", fr(18))
    return c


def inspect():
    """f0-f20 roll 60; f20-f60 hold; knob back 0.1 f70-f74, look f70-f100, forward f100-f102 Quad In; f110-f140 mag tap;
    f140-f180 back"""
    c = Clip("SMGInspect", 3.0)
    h = G.hold(c)
    show = P(h, gun=((0.2, 1.05, -0.65), (8, 25, 60)), head=(-12, 12, 0), L=("free", (-0.5, 0.6, -0.7), (70, 0, 0)))
    show2 = add(show, gun=((0, 0.02, 0), (1.5, 1, 2)))
    look = P(show, gun=((0.1, 1.1, -0.6), (10, 5, 15)), head=(-14, 4, 0), L=("gun", (0.0, -0.84, 0.3), (0, 0, 0)))
    seq(c, [(0, h, "CubicInOut"), (20, show, "SineInOut"), (60, show2, "SineInOut"), (68, look, "SineInOut"), (140, add(look, gun=((0, 0.02, 0), (1, 0, 2))), "CubicOut"),
            (180, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    knob = (0.0, 0.62, 0.05)
    c.free("L", 0, 0, ease="CubicInOut"); c.hand_on("L", 0, h["L"][1], h["L"][2], ease="CubicInOut")
    c.hand_free("L", 0, (-0.5, 0.6, -0.7), (70, 0, 0)); c.hand_free("L", fr(180), (-0.5, 0.6, -0.7), (70, 0, 0))
    c.free("L", fr(20), 1, ease="SineInOut"); c.free("L", fr(64), 1, ease="CubicOut")
    c.hand_on("L", fr(64), knob, (0, 0, 90), ease="CubicOut"); c.free("L", fr(70), 0, ease="CubicOut")
    c.hand_on("L", fr(70), knob, (0, 0, 90), ease="CubicOut"); c.hand_on("L", fr(74), add_t(knob, (0, 0, 0.1)), (0, 0, 90), ease="SineInOut")
    c.hand_on("L", fr(100), add_t(knob, (0, 0, 0.1)), (0, 0, 90), ease="QuadIn"); c.hand_on("L", fr(102), knob, (0, 0, 90), ease="SineInOut")
    c.hand_on("L", fr(110), UNDER, (0, 0, 0), ease="SineInOut"); c.hand_on("L", fr(125), add_t(UNDER, (0, -0.06, 0)), (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(140), UNDER, (0, 0, 0), ease="CubicOut"); c.hand_on("L", fr(180), h["L"][1], h["L"][2])
    for f, z, e in ((0, 0, "Constant"), (70, 0, "CubicOut"), (74, 0.1, "SineInOut"), (100, 0.1, "QuadIn"), (102, 0, "Constant"), (180, 0, "Constant")):
        c.part("CockingKnob", fr(f), (0, 0, z), ease=e)
    c.marker("SlideRack", fr(102))
    return c


CLIPS = {"SMGHold": hold, "SMGLowered": lowered, "SMGEquip": equip, "SMGFire": fire, "SMGReload": reload,
         "SMGReloadEmpty": reload_empty, "SMGDraw": draw, "SMGHolster": holster, "SMGInspect": inspect}
