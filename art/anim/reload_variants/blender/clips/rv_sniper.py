"""Sniper reload variants: 3.0 s = 180 f (design "Sniper"). Anchors: off the cheek f0-f10; off hand to the Mag f10-f16;
MagOut f18; MagIn f84 (seat f80-f84); Ready f160.
  TopUp (1-4 left, a round chambered): strip, stow, new mag, a thumb runs across the top round (count check), no bolt.
  Dry (0): drops free, new mag, the off hand cycles the bolt to chamber a round."""
import sniper
from rbxanim import P, seq, fr, add
from longgun_parts import mag_reload, tilt_pose, add_t
from rv_common import moving_hold

GUN = "Sniper"
TOOL = "Sniper"
BASE_NAME = "SniperReload"
BASE_LEN = 3.0
END, READY = 180, 160
G = sniper.G
UNDER = (0.0, -0.45, -0.95)
TOPR = (0.05, 0.3, -0.55)      # off-hand wrist over the ejection port (thumb on the top round)


def settle(c, f0, f1):
    """cheek weld settle: the head sinks onto the stock 1 deg and back"""
    h = G.hold(c)
    seq(c, [(f0, add(h, head=(1.0, 0, 0)), "SineInOut"), (f1, h)], only=("head",))


def topup():
    """strip f18-f26; stow f26-f50 (MagStowed); new mag f50-f80; seat f84; f84-f88 hold; head lead f86; the thumb runs
    across the top round f88-f100 (RoundCheck f94); off hand back f100-f120; remount f120-f144 Quart Out; cheek weld
    settle f144-f160; moving hold"""
    c = mag_reload(G, "SniperReload_TopUp", BASE_LEN, dict(tilt=10, release=18, out=26, stowed=50, seat=84, rewrap=120, shoulder=144, end=END),
                   under=UNDER, release="MagRelease")
    t = tilt_pose(G, c)
    tc = P(t, L=("gun", TOPR, (0, 0, 80)))
    seq(c, [(84, t, "SineInOut"), (86, add(t, head=(-6, 0, 0))), (100, add(t, head=(-6, 0, 0))), (120, t)], only=("head",))
    seq(c, [(88, tc, "SineInOut"), (100, tc)], only=("gun",))
    c.hand_on("L", fr(88), add_t(TOPR, (0, 0.04, -0.12)), (0, 0, 80), ease="SineInOut")
    c.hand_on("L", fr(94), TOPR, (0, 0, 80), ease="SineInOut")
    c.hand_on("L", fr(100), add_t(TOPR, (0, 0.04, 0.12)), (0, 0, 80), ease="CubicInOut")
    settle(c, 144, READY)
    moving_hold(c, G.hold(c), READY, END)
    c.marker("RoundCheck", fr(94)); c.marker("Ready", fr(READY))
    return c


def dry():
    """drops free f18-f30 (MagHide f30); new mag f31-f80; seat f84; f84-f88 hold; off hand to the bolt f88-f98; up f98-f102
    Cubic Out, back f102-f110 Quart Out, hold f110-f113, forward f113-f119 Cubic In, down f119-f122 Quart Out (BoltClosed
    f122); hand to the support f122-f134; remount f134-f154; settle f154-f160"""
    c = mag_reload(G, "SniperReload_Dry", BASE_LEN, dict(tilt=10, release=18, hide=30, show=31, seat=84, rewrap=134, shoulder=154, end=END),
                   under=UNDER, release="MagRelease", empty=True, drop=(0, -2.4, -0.6))
    h = G.hold(c)
    t = tilt_pose(G, c)
    tb = P(t, L=("gun", add_t(sniper.KW, (0, 0.12, 0.55)), (0, 0, 80)))
    seq(c, [(92, tb, "SineInOut"), (122, tb, "CubicInOut")], only=("gun",))
    sniper.bolt_hand(c, P(h, L=("gun", UNDER, (0, 0, 0))), 92, 98, 110, 113, 119, 122, 134)
    sniper.bolt_keys(c, 102, 110, 113, 119, 122, END)
    settle(c, 154, READY)
    moving_hold(c, h, READY, END)
    c.marker("BoltClosed", fr(122)); c.marker("Ready", fr(READY))
    return c


ROUNDS = {"SniperReload_TopUp": "1-4", "SniperReload_Dry": "0"}
CLIPS = {"SniperReload_TopUp": topup, "SniperReload_Dry": dry}
