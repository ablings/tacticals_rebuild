"""Mini Uzi reload variants: 1.7 s = 102 f (notes/reload_variants_design.md "Mini Uzi").
Anchors: tilt f0-f6; off hand to the grip base f6-f10; MagOut f10; MagIn f56 (seat + heel slap f54-f56); Ready f92.
  Retain (16-29 left): strip, stow, new mag.   Drop (1-15): drops free, new mag with a look, tug check.
  Dry (0): as Drop + the off hand runs the CockingKnob."""
import smg
from rbxanim import Clip, add, seq, fr
from longgun_parts import mag_reload
from rv_common import moving_hold, tug

GUN = "MiniUzi"
TOOL = "MiniUzi"
BASE_NAME = "SMGReload"
BASE_LEN = 1.7
END, READY = 102, 92
KW = dict(under=smg.UNDER, pouch=(-0.6, -0.05, -0.6), release=None)
DROPKEYS = ()  # mag_reload already keys the drop (release, hide, show)


def _t():
    return smg.tilt(Clip("_t", 1.0))


def _look(c, t):
    seq(c, [(23, t), (40, add(t, head=(-6, 0, 0))), (54, t)], only=("head",))


def retain():
    """strip f10-f16; stow f16-f34 (MagStowed); new mag f34-f54; seat f56; f56-f60 hold; off hand to the front f60-f78;
    up f78-f92 Quart Out; moving hold"""
    t = _t()
    c = mag_reload(smg.G, "SMGReload_Retain", BASE_LEN, dict(tilt=6, release=10, out=16, stowed=34, seat=56, rewrap=78, shoulder=READY, end=END),
                   tilt=t, **KW)
    moving_hold(c, smg.G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


def drop():
    """drops free f10-f22 (MagHide f22); off hand to the pouch; new mag f23-f54 with a look at the grip (f40); seat f56;
    tug f60-f66; off hand to the front f66-f80; up f80-f92"""
    t = _t()
    c = mag_reload(smg.G, "SMGReload_Drop", BASE_LEN, dict(tilt=6, release=10, hide=22, show=23, seat=56, rewrap=80, shoulder=READY, end=END),
                   empty=True, drop=(0, -2.4, 0), tilt=t, **KW)
    _look(c, t)
    tug(c, "Mag", 60, 66, END, keys_before=DROPKEYS)
    moving_hold(c, smg.G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


def dry():
    """as Drop to f56; off hand over the top f58-f66; CockingKnob back f66-f70 Cubic Out, hold f70-f72, forward f72-f74
    Quad In (SlideRack f74); off hand to the front f74-f82; up f82-f92"""
    t = _t()
    c = mag_reload(smg.G, "SMGReload_Dry", BASE_LEN, dict(tilt=6, release=10, hide=22, show=23, seat=56, rewrap=82, shoulder=READY, end=END),
                   empty=True, drop=(0, -2.4, 0), tilt=t,
                   charge=("CockingKnob", 0.35, (0.0, 0.62, 0.05), 66, 70, 72, 74), charge_shift=(-0.3, 0.05, 0.1), **KW)
    _look(c, t)
    moving_hold(c, smg.G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


ROUNDS = {"SMGReload_Retain": "16-29", "SMGReload_Drop": "1-15", "SMGReload_Dry": "0"}
CLIPS = {"SMGReload_Retain": retain, "SMGReload_Drop": drop, "SMGReload_Dry": dry}
