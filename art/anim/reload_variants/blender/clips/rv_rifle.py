"""Rifle-prefix reload variants: Automatic Rifle 2.2 s = 132 f; Semi-Auto plays them at AdjustSpeed 132/150 (exact).
Design "Automatic Rifle". Anchors: roll f0-f8; off hand to the mag f4-f14; MagOut f16; MagIn f70 (rock in f66-f70);
Ready f120.
  Retain (AR 16-29, Semi 7-11): strip, chest pouch, new mag front lip first, tug.
  Drop (AR 1-15, Semi 1-6): drops free, new mag with a look, tug, heel tap on the base.
  Dry (0): as Drop + the ChargingHandle (BoltCarrier rides with it)."""
import rifle
from rbxanim import fr, add, seq
from longgun_parts import mag_reload, tilt_pose
from rv_common import moving_hold, tug, gun_bump

GUN = "AutoRifle"
TOOL = "AutoRifle"
BASE_NAME = "RifleReload"
BASE_LEN = 2.2
END, READY = 132, 120
G = rifle.G
DROPKEYS = ()  # mag_reload already keys the drop (release, hide, show)


def _look(c):
    t = tilt_pose(G, c)
    seq(c, [(31, t), (46, add(t, head=(-6, 0, 0))), (64, t)], only=("head",))


def retain():
    """strip f16-f24; chest pouch f24-f44 (MagStowed); new mag f44-f66; seat f70; f70-f74 hold; tug f74-f80; off hand to
    the handguard f80-f96; shoulder f96-f120 Quart Out; moving hold"""
    c = mag_reload(G, "RifleReload_Retain", BASE_LEN, dict(tilt=8, release=16, out=24, stowed=44, seat=70, rewrap=96, shoulder=READY, end=END))
    tug(c, "Mag", 74, 80, END, keys_before=((0, 0, "Constant"),))
    moving_hold(c, G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


def drop():
    """drops free f16-f30 (MagHide f30); off hand to the pouch; new mag f31-f66 (look f46); seat f70; tug f74-f80; heel
    tap on the base f80-f86 (MagTap); to the handguard f86-f100; shoulder f100-f120"""
    c = mag_reload(G, "RifleReload_Drop", BASE_LEN, dict(tilt=8, release=16, hide=30, show=31, seat=70, rewrap=100, shoulder=READY, end=END),
                   empty=True, drop=(0, -2.4, -0.6))
    _look(c)
    tug(c, "Mag", 74, 80, END, keys_before=DROPKEYS)
    gun_bump(c, tilt_pose(G, c), 80, 86)
    c.marker("MagTap", fr(82))
    moving_hold(c, G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


def dry():
    """as Drop to f74; off hand to the ChargingHandle f74-f86; back f86-f90 Cubic Out, hold f90-f92, forward f92-f94 Quad In
    (SlideRack f94); to the handguard f94-f106; shoulder f106-f120"""
    c = mag_reload(G, "RifleReload_Dry", BASE_LEN, dict(tilt=8, release=16, hide=30, show=31, seat=70, rewrap=106, shoulder=READY, end=END),
                   empty=True, drop=(0, -2.4, -0.6),
                   charge=("ChargingHandle", 0.45, (0.0, 0.55, 0.45), 86, 90, 92, 94), extra_parts=("BoltCarrier",))
    _look(c)
    moving_hold(c, G.hold(c), READY, END)
    c.marker("Ready", fr(READY))
    return c


ROUNDS = {"RifleReload_Retain": "Auto Rifle 16-29, Semi-Auto 7-11", "RifleReload_Drop": "Auto Rifle 1-15, Semi-Auto 1-6",
          "RifleReload_Dry": "0"}
CLIPS = {"RifleReload_Retain": retain, "RifleReload_Drop": drop, "RifleReload_Dry": dry}
