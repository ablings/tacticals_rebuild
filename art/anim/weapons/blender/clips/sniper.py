"""Sniper set: targets section 6, on the remodelled Sniper (Bolt + BoltHandle on the bore axis, Mag, Trigger, bipod).
The gun is welded to the gun hand in game, so the off hand works the bolt (reaches over the top to the knob)."""
from rbxanim import Clip, P, add, seq, fr
from longgun import Gun
from longgun_parts import mag_reload, gun_inspect, add_t

GUN = "Sniper"
TOOL = "Sniper"
G = Gun("Sniper", butt=(0, 0.07, 1.45), support=(0.0, -0.05, -0.95), blade=60, lean=6, knees=0.11, heavy=1.25,
        cheek=(-10, 6))
KNOB = (0.15, 0.22, -0.5)     # BoltKnob attachment (gun frame)
KW = (0.12, 0.45, -0.3)       # off-hand wrist on the bolt knob, from above / behind


def bolt_keys(c, f_up, f_back, f_hold, f_fwd, f_down, end):
    """bolt up 60 (Cubic Out) -> back 0.55 (Quart Out) -> hold -> forward (Cubic In, hard) -> down (Quart Out)"""
    for f, rz, z, e in ((0, 0, 0, "Constant"), (f_up - 4, 0, 0, "CubicOut"), (f_up, 60, 0, "QuartOut"), (f_back, 60, 0.55, "SineInOut"),
                        (f_hold, 60, 0.55, "CubicIn"), (f_fwd, 60, 0, "QuartOut"), (f_down, 0, 0, "Constant"), (end, 0, 0, "Constant")):
        c.part("Bolt", fr(f), (0, 0, z), (0, 0, rz), ease=e)


def bolt_hand(c, h, f_reach, f_up, f_back, f_hold, f_fwd, f_down, f_ret):
    L = h["L"]
    c.hand_on("L", fr(f_reach - 4), L[1], L[2], ease="SineInOut")
    c.hand_on("L", fr(f_up - 4), KW, (0, 0, 80), ease="CubicOut")
    c.hand_on("L", fr(f_up), add_t(KW, (0, 0.12, 0)), (0, 0, 80), ease="QuartOut")
    c.hand_on("L", fr(f_back), add_t(KW, (0, 0.12, 0.55)), (0, 0, 80), ease="SineInOut")
    c.hand_on("L", fr(f_hold), add_t(KW, (0, 0.12, 0.55)), (0, 0, 80), ease="CubicIn")
    c.hand_on("L", fr(f_fwd), add_t(KW, (0, 0.12, 0)), (0, 0, 80), ease="QuartOut")
    c.hand_on("L", fr(f_down), KW, (0, 0, 80), ease="CubicInOut")
    c.hand_on("L", fr(f_ret), L[1], L[2])


def fire():
    """shot + bolt (FireInterval 1.3): f1-f2 peak (muzzle +9, shoulder 0.2 back, chest +3, head +2) Linear; f2-f14 Quint Out;
    f14-f18 off hand to the knob; bolt up f18-f22, back f22-f30, hold f30-f32, forward f32-f38 Cubic In, down f38-f41;
    f41-f52 hand back; f52-f78 Cubic Out reacquire (cheek back on the stock f50). Cancellable from f54"""
    c = Clip("SniperFire", 1.30)
    h = G.hold(c)
    gp, tgt, rot = h["gun"]
    pk = add(P(h, gun=(gp, add_t(tgt, (0, 0.02, 0.2)), add_t(rot, (9, 0.5, 0)))), chest=(3, 0, 0), head=(2, 0, 0))
    work = P(h, gun=(gp, add_t(tgt, (-0.12, -0.04, 0.05)), add_t(rot, (-2, 0, 18))), head=(-6, 20, 0), L=("gun", add_t(KW, (0, 0.12, 0.55)), (0, 0, 80)))
    seq(c, [(0, h, "Linear"), (2, pk, "QuintOut"), (14, h, "SineInOut"), (18, work, "SineInOut"), (41, work, "CubicInOut"),
            (52, add(h, head=(4, 0, 0)), "CubicOut"), (78, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    bolt_hand(c, h, 14, 18, 30, 32, 38, 41, 52)
    bolt_keys(c, 22, 30, 32, 38, 41, 78)
    for f, a, e in ((0, 8, "Constant"), (3, 8, "CubicOut"), (8, 0, "Constant"), (78, 0, "Constant")):
        c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
    c.marker("ShellEject", fr(26)); c.marker("BoltClosed", fr(41))
    return c


def reload():
    """mag + bolt (3.0 s): f0-f10 off the cheek, roll 15; f10-f16 off hand to the Mag; f18 release, out f18-f26; stow
    f26-f50; new mag f50-f80; f80-f84 Linear seat; f84-f88 hold; bolt with the off hand f88-f122; remount f134-f154; hold"""
    c = mag_reload(G, "SniperReload", 3.0, dict(tilt=10, release=18, out=26, stowed=50, seat=84, rewrap=134, shoulder=154, end=180),
                   under=(0.0, -0.45, -0.95), release="MagRelease")
    h = G.hold(c)
    from longgun_parts import tilt_pose
    t = tilt_pose(G, c)
    tb = P(t, L=("gun", add_t(KW, (0, 0.12, 0.55)), (0, 0, 80)))   # the tilted gun, placed so the off hand reaches the bolt knob
    seq(c, [(92, tb, "SineInOut"), (122, tb, "CubicInOut")], only=("gun",))
    bolt_hand(c, P(h, L=("gun", (0.0, -0.45, -0.95), (0, 0, 0))), 92, 98, 110, 113, 119, 122, 134)
    bolt_keys(c, 102, 110, 113, 119, 122, 180)
    c.marker("BoltClosed", fr(122))
    return c


def reload_tactical():
    """a round still chambered: no bolt (2.5 s)"""
    return mag_reload(G, "SniperReloadTactical", 2.5, dict(tilt=10, release=18, out=26, stowed=50, seat=84, rewrap=108, shoulder=128,
                                                           end=150), under=(0.0, -0.45, -0.95), release="MagRelease")


def inspect():
    def parts(c):
        bolt_keys(c, 64, 76, 100, 106, 110, 180)
    c = gun_inspect(G, "SniperInspect", 30, parts, ("BoltClosed", fr(110)))
    h = G.hold(c)
    gp, tgt, rot = h["gun"]
    work = P(h, gun=(gp, add_t(tgt, (-0.12, -0.04, 0.05)), add_t(rot, (-2, 0, 18))), head=(-6, 20, 0), L=("gun", add_t(KW, (0, 0.12, 0.55)), (0, 0, 80)))
    seq(c, [(56, work, "SineInOut"), (60, work, "SineInOut"), (100, add(work, gun=((0, 0.02, 0), (1, 0, 2))), "SineInOut"), (110, work, "CubicInOut")], only=("gun", "head"))
    bolt_hand(c, P(h), 56, 60, 76, 100, 106, 110, 124)
    return c


CLIPS = {"SniperHold": G.c_hold, "SniperLowered": lambda: _lowered(), "SniperEquip": lambda: G.c_equip(up=13, settle=3),
         "SniperFire": fire, "SniperReload": reload, "SniperReloadTactical": reload_tactical,
         "SniperDraw": lambda: G.c_draw(length=0.75, grip=7, swing=22, mount=36, back=40),
         "SniperHolster": lambda: G.c_holster(length=0.65, release=26), "SniperInspect": inspect}


def _lowered():
    from rbxanim import Clip as _C
    c = _C("SniperLowered", 1.0, loop=True)
    G.breathe(c, G.lowered(c, down=40), amp=0.4)
    return c
