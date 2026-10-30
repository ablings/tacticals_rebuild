"""Revolver reload variants: 2.0 s = 120 f, 6 rounds (notes/reload_variants_design.md "Revolver").

Shared anchors: f0-f6 Cubic Out tilt 30 left, off hand under the frame; f6-f8 thumb latch; Crane out f8-f13 Cubic Out 90
(CylinderOpen f13); f13-f20 the cylinder face turns up to the eye with a head lead; ShellIn f80 (last round in);
CylinderClosed f96 (wrist flick, Quart Out 3 f, no Back); f96-f99 hold; f99-f110 Quart Out up; f110-f120 moving hold.
  Pluck1 (5 left / 1 spent): thumbnail plucks Round1, flicks it away; a single round from the belt; spin; close.
  Pluck2 (4 left / 2 spent): pluck Round1, index, pluck Round2; load Round2, index back, load Round1; spin; close.
  Dump (1-3 left): muzzle up, ejector stroke, all six fall (the code shows live vs spent per round); speed loader.
  Dry (0): faster muzzle up, palm slap, six casings spray; unhurried speed loader; half-turn spin before the close.

Rig: this module adds the split the modeler still has to make (art/guns/manifest/Revolver.json has one `Rounds` piece):
`Round1`..`Round6` (one per chamber; Motor6D parent EjectorRod so the extractor stroke pushes them; Round1 = the top
chamber, Round2 the next one the cylinder turns up on a +60 index, ... ) and an optional `SpeedLoader` hand prop. The old
one-piece `Rounds` is keyed too (Dump / Dry), so the current model still shows a dump.
Markers for the code: RoundHide / RoundShow (value = the round's name) for plucked singles, MagHide / MagShow (value
"Rounds") for the dump and the loader set, LoaderShow / LoaderHide for the SpeedLoader prop."""
import copy
import math
import rbxanim
import revolver
from rbxanim import Clip, P, add, seq, fr
from pistol_gun import add_t
from longgun_parts import held_at

GUN = "Revolver"
TOOL = "Revolver"
BASE_NAME = "RevolverReload"
BASE_LEN = 2.0
END = 120
ROUND_NAMES = ["Round%d" % k for k in range(1, 7)]
rbxanim.CARRY = tuple(rbxanim.CARRY) + tuple(ROUND_NAMES) + ("SpeedLoader",)
POP_CHECK = ["Round1", "Round2", "Round4"]

CYL_AXIS = (0.0, 0.37)        # cylinder axis (x, y) at rest, Handle space
CH_R = 0.09                   # chamber circle radius
ROUND_Z = -0.4685             # round centre (z) at rest
CRANE_PIV = (-0.04, 0.265)


def round_rest(k):
    """Round k (1..6) centre at rest: Round1 at the top (90 deg), then every 60 deg clockwise seen from the rear"""
    a = math.radians(90 - 60 * (k - 1))
    return (CYL_AXIS[0] + CH_R * math.cos(a), CYL_AXIS[1] + CH_R * math.sin(a), ROUND_Z)


def _rot(p, c, deg):
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a), p[2])


def opened(p, cyl_deg=0.0):
    """a rest point of the cylinder group after the cylinder turns cyl_deg about its axis and the crane swings 90 out"""
    return _rot(_rot(p, CYL_AXIS, cyl_deg), CRANE_PIV, 90)


def gun_def():
    g = rbxanim.load_gun(GUN)
    g = copy.deepcopy(g)
    for k, n in enumerate(ROUND_NAMES, 1):
        c = round_rest(k)
        g["parts"][n] = {"name": n, "parent": "EjectorRod", "pivot": list(c), "bbox_centre": list(c), "size": [0.062, 0.062, 0.243],
                         "motion": "one round per chamber"}
    loader = (CYL_AXIS[0], CYL_AXIS[1], -0.30)
    g["parts"]["SpeedLoader"] = {"name": "SpeedLoader", "parent": "Handle", "pivot": list(loader), "bbox_centre": list(loader),
                                 "size": [0.26, 0.26, 0.08], "motion": "hand prop: shown LoaderShow..LoaderHide"}
    return g


SPOT = opened(round_rest(1))           # where a single round is plucked / loaded (the outer chamber of the open cylinder)
PLUCK_W = (-0.31, 0.33, 0.07)          # off-hand wrist with the thumbnail under the rim of the round at SPOT
LOAD_W = (-0.30, 0.31, 0.10)           # off-hand wrist pressing a single round home at SPOT
LOADER_W = (-0.25, 0.3, 0.1)           # off-hand wrist holding the speed loader to the open cylinder's rear (base clip)
UNDER = (0.05, -0.05, -0.35)           # off-hand wrist under the frame, thumb on the cylinder
EJECTOR = (0.0, 0.15, -1.0)            # palm on the ejector rod tip (muzzle up)
BELT = (-0.6, -0.05, -0.6)             # belt loops / loader pouch (chest frame)


def held_open(c, part, f, W, k, cyl_deg=0.0):
    """(f in frames) twin offset so `part` (round k) sits in its chamber of the open cylinder (turned cyl_deg) when the wrist is at W"""
    r = round_rest(k)
    o = opened(r, cyl_deg)
    held_at(c, part, f, tuple(w - (oo - rr) for w, oo, rr in zip(W, o, r)))


def poses(c):
    h, _, _ = revolver.poses(c)
    g = h["gun"][0]
    base = (g[0] - 0.25, g[1] - 0.25, g[2] + 0.45)
    tilt = P(h, gun=(base, (5, 10, 30)), head=(-10, 0, 0), poleR=(1.6, -0.9, 0.7))
    face = P(tilt, gun=(add_t(base, (0, 0.05, 0.02)), (22, 10, 34)), head=(-15, 4, 0))
    up = P(tilt, gun=(add_t(base, (0, 0.15, 0.05)), (60, 10, 30)))
    down = P(tilt, gun=(add_t(base, (0, -0.05, 0)), (-35, 10, 30)), head=(-14, 0, 0))
    flick = P(face, gun=(add_t(base, (0.05, 0.05, 0)), (-10, 5, -5)))
    return h, base, tilt, face, up, down, flick


def crane_keys(c, close0=93, close1=96):
    for f, a, e in ((0, 0, "Constant"), (8, 0, "CubicOut"), (13, 90, "Constant"), (close0, 90, "QuartOut"), (close1, 0, "Constant"),
                    (END, 0, "Constant")):
        c.part("Crane", fr(f), (0, 0, 0), (0, 0, a), ease=e)
    for f, z, e in ((0, 0, "Constant"), (6, 0, "CubicOut"), (8, -0.04, "SineInOut"), (12, 0, "Constant"), (END, 0, "Constant")):
        c.part("CylinderLatch", fr(f), (0, 0, z), ease=e)
    c.marker("CylinderOpen", fr(13)); c.marker("CylinderClosed", fr(close1))


def cylinder_curve(c, keys):
    """Cylinder turn about its own axis: keys [(frame, deg, shape)], shape "QuadIn" / "QuadOut" / "Hold"; sampled every
    frame (Linear) so turns past 180 deg stay correct (quaternion keys can't carry a full turn)"""
    out = []
    for (f0, a0, shape), (f1, a1, _) in zip(keys, keys[1:]):
        for f in range(f0, f1):
            u = (f - f0) / (f1 - f0)
            if shape == "QuadOut":
                u = 1 - (1 - u) ** 2
            elif shape == "QuadIn":
                u = u * u
            elif shape == "Hold":
                u = 0.0
            out.append((f, a0 + (a1 - a0) * u))
    out.append((keys[-1][0], keys[-1][1]))
    if keys[-1][0] < END:
        out.append((END, keys[-1][1]))
    for f, a in out:
        c.part("Cylinder", fr(f), (0, 0, 0), (0, 0, a), ease="Linear")


def body(c, mid, close0=93, close1=96):
    """gun / body keys: anchors + the variant's middle keys [(frame, pose, ease)]"""
    h, base, tilt, face, up, down, flick = poses(c)
    keys = [(0, h, "CubicOut"), (6, tilt, "CubicOut"), (13, tilt, "CubicOut"), (20, face)] + list(mid) + \
           [(close0, face, "QuartOut"), (close1, flick, "SineInOut"), (99, flick, "QuartOut"), (110, h, "SineInOut"),
            (115, add(h, chest=(0.4, 0, 0), head=(0.3, 0, 0))), (END, h)]
    seq(c, keys, only=("root", "chest", "head", "gun", "R", "poles", "feet"))


def hand_start(c, h):
    L = h["L"]
    c.hand_free("L", 0, BELT, (70, 0, 0)); c.hand_free("L", fr(END), BELT, (70, 0, 0))
    c.free("L", 0, 0, ease="CubicOut"); c.hand_on("L", 0, L[1], L[2], ease="CubicOut")
    c.hand_on("L", fr(6), UNDER, (0, 0, -30), ease="SineInOut")
    c.hand_on("L", fr(13), UNDER, (0, 0, -30), ease="CubicOut")


def hand_close(c, h, f_from, close0=93, close1=96):
    """after the last round: hand back under the frame, it pushes / flicks the cylinder shut, then rewraps"""
    L = h["L"]
    c.hand_on("L", fr(close0), UNDER, (0, 0, -30), ease="QuartOut")
    c.hand_on("L", fr(close1), UNDER, (0, 0, -30), ease="SineInOut")
    c.hand_on("L", fr(98), UNDER, (0, 0, -30), ease="CubicInOut")
    c.hand_on("L", fr(104), L[1], L[2]); c.hand_on("L", fr(END), L[1], L[2])


def pluck(c, name, f_in, f_out, f_flick, cyl_deg=0.0):
    """thumbnail under the rim f_in, round drawn back to f_out (Cubic Out, ShellEject), flicked away to f_flick (hidden)"""
    for f, pos, e in ((0, (0, 0, 0), "Constant"), (f_in, (0, 0, 0), "CubicOut"), (f_out, (0, 0, 0.14), "QuadIn"),
                      (f_flick, (-0.9, 0.55, 0.7), "Constant"), (f_flick + 1, (0, 0, 0), "Constant"), (END, (0, 0, 0), "Constant")):
        c.part(name, fr(f), pos, ease=e)
    c.hand_on("L", fr(f_in), PLUCK_W, (0, 0, 0), ease="CubicOut")
    c.hand_on("L", fr(f_out), add_t(PLUCK_W, (0, 0, 0.14)), (0, 0, 0), ease="QuadIn")
    c.hand_on("L", fr(f_flick), add_t(PLUCK_W, (-0.12, 0.05, 0.2)), (0, 0, -25), ease="SineInOut")
    c.marker("ShellEject", fr(f_out), name); c.marker("RoundHide", fr(f_flick), name)


def load_single(c, name, k, f_grab, f_show, f_at, f_in, cyl_deg=0.0, last=False):
    """the hand takes a round at the belt (f_grab, RoundShow f_show), brings it behind the chamber (f_at), presses it home
    (f_at..f_in Cubic Out, ShellIn); the round rides the hand from the moment it was hidden"""
    c.free("L", fr(f_grab - 8), 1, ease="SineInOut"); c.free("L", fr(f_at - 12), 1, ease="Linear")
    c.free("L", fr(f_at - 4), 0, ease="SineInOut")
    c.hand_on("L", fr(f_at - 4), add_t(LOAD_W, (-0.05, 0.05, 0.3)), (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(f_at), add_t(LOAD_W, (0, 0, 0.16)), (0, 0, 0), ease="CubicOut")
    c.hand_on("L", fr(f_in), LOAD_W, (0, 0, 0), ease="SineInOut")
    held_open(c, name, f_in, LOAD_W, k, cyl_deg)
    c.inhand(name, fr(f_in - 1), 1, ease="Linear"); c.inhand(name, fr(f_in), 0, ease="Constant")
    c.marker("RoundShow", fr(f_show), name)
    c.marker("ShellIn", fr(f_in), name if not last else "")


def pluck1():
    """1 spent: pluck f20-f25 (ShellEject f25), flick f25-f30 (RoundHide); belt f30-f56 (slow, head follows, RoundShow
    f44); round to the chamber f56-f74; press f74-f80 (ShellIn f80); thumb spins the cylinder two turns f80-f90 Quad Out;
    close f93-f96"""
    c = Clip("RevolverReload_Pluck1", BASE_LEN)
    h, base, tilt, face, up, down, flick = poses(c)
    body(c, [(25, add(face, gun=((0, 0.01, 0), (2, 0, 0))), "SineInOut"), (30, face, "SineInOut"),
             (44, add(face, head=(-4, -10, 0)), "SineInOut"), (60, add(face, head=(2, 4, 0)), "SineInOut"), (80, face, "SineInOut")])
    hand_start(c, h)
    pluck(c, "Round1", 20, 25, 30)
    c.inhand("Round1", fr(30), 0, ease="Constant"); c.inhand("Round1", fr(31), 1, ease="Constant")
    load_single(c, "Round1", 1, 44, 44, 74, 80, last=True)
    c.hand_on("L", fr(86), add_t(LOAD_W, (0.05, -0.15, 0.0)), (0, 0, -15), ease="SineInOut")
    hand_close(c, h, 86)
    cylinder_curve(c, [(0, 0, "Hold"), (80, 0, "QuadOut"), (90, 720, "Hold"), (END, 720, "Hold")])
    crane_keys(c)
    return c


def pluck2():
    """2 spent: pluck Round1 f20-f28 (ShellEject f24); index +60 f28-f31 Quad In; pluck Round2 f31-f39 (ShellEject f35);
    belt f39-f52; Round2 in f52-f62 (ShellIn f62); index back f62-f65; Round1 in f65-f80 (ShellIn f80); spin f80-f90; close"""
    c = Clip("RevolverReload_Pluck2", BASE_LEN)
    h, base, tilt, face, up, down, flick = poses(c)
    body(c, [(24, add(face, gun=((0, 0.01, 0), (2, 0, 0))), "SineInOut"), (31, face, "SineInOut"),
             (35, add(face, gun=((0, 0.01, 0), (2, 0, 0))), "SineInOut"), (39, face, "SineInOut"),
             (46, add(face, head=(-4, -10, 0)), "SineInOut"), (56, face, "SineInOut"), (80, face, "SineInOut")])
    hand_start(c, h)
    pluck(c, "Round1", 20, 24, 28)
    c.hand_on("L", fr(31), PLUCK_W, (0, 0, 0), ease="CubicOut")
    pluck(c, "Round2", 31, 35, 39)
    c.inhand("Round1", fr(28), 0, ease="Constant"); c.inhand("Round1", fr(29), 1, ease="Constant")
    c.inhand("Round2", fr(39), 0, ease="Constant"); c.inhand("Round2", fr(40), 1, ease="Constant")
    load_single(c, "Round2", 2, 46, 46, 58, 62, cyl_deg=60)
    c.hand_on("L", fr(65), add_t(LOAD_W, (0, 0, 0.16)), (0, 0, 0), ease="SineInOut")
    # Round1 rides the hand (shown at f62: both rounds were picked from the loops together) to the chamber at SPOT
    c.free("L", fr(65), 0, ease="SineInOut")
    c.hand_on("L", fr(74), add_t(LOAD_W, (0, 0, 0.16)), (0, 0, 0), ease="CubicOut")
    c.hand_on("L", fr(80), LOAD_W, (0, 0, 0), ease="SineInOut")
    held_open(c, "Round1", 80, LOAD_W, 1, 0)
    c.inhand("Round1", fr(79), 1, ease="Linear"); c.inhand("Round1", fr(80), 0, ease="Constant")
    c.marker("RoundShow", fr(46), "Round1"); c.marker("ShellIn", fr(80))
    c.hand_on("L", fr(86), add_t(LOAD_W, (0.05, -0.15, 0.0)), (0, 0, -15), ease="SineInOut")
    hand_close(c, h, 86)
    cylinder_curve(c, [(0, 0, "Hold"), (28, 0, "QuadIn"), (31, 60, "Hold"), (62, 60, "QuadIn"), (65, 0, "Hold"),
                       (80, 0, "QuadOut"), (90, 720, "Hold"), (END, 720, "Hold")])
    crane_keys(c)
    return c


def dump_rounds(c, f_push0, f_push1, f_fall, fall=(-0.7, 0.1, 1.6)):
    """the ejector pushes all rounds back f_push0-f_push1 (Linear), they fall free to f_fall (Quad In, MagHide)"""
    for f, z, e in ((0, 0, "Constant"), (f_push0, 0, "Linear"), (f_push1, 0.2, "CubicOut"), (f_push1 + 6, 0, "Constant"), (END, 0, "Constant")):
        c.part("EjectorRod", fr(f), (0, 0, z), ease=e)
    for k, n in enumerate(ROUND_NAMES + ["Rounds"], 1):
        s = 1.0 + 0.12 * ((k * 37) % 5 - 2)    # each round falls a little differently
        drift = (0.08 * ((k * 13) % 3 - 1), 0.08 * ((k * 7) % 3 - 1), 0)
        tgt = tuple(a * s + b for a, b in zip(fall, drift))
        for f, pos, e in ((0, (0, 0, 0), "Constant"), (f_push1, (0, 0, 0), "QuadIn"), (f_fall + (k % 3), tgt, "Constant"),
                          (f_fall + 4, (0, 0, 0), "Constant"), (END, (0, 0, 0), "Constant")):
            c.part(n, fr(f), pos, ease=e)
    c.marker("ShellEject", fr((f_push0 + f_push1) // 2)); c.marker("MagHide", fr(f_fall + 3), "Rounds")


def speed_loader(c, h, f_belt, f_show, f_at, f_in, f_twist, f_hide):
    """off hand to the pouch (free) by f_belt; the loader with six rounds shows f_show; to the cylinder's rear f_at; insert
    f_at..f_in Linear (the rounds drop into the chambers: inhand off at f_in); twist f_in..f_twist; loader hidden f_hide"""
    c.free("L", fr(f_belt - 14), 0, ease="SineInOut"); c.free("L", fr(f_belt), 1, ease="SineInOut")
    c.free("L", fr(f_at - 16), 1, ease="SineInOut"); c.free("L", fr(f_at - 4), 0, ease="Linear")
    c.hand_on("L", fr(f_at - 4), add_t(LOADER_W, (0, -0.1, 0.3)), (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(f_at), add_t(LOADER_W, (0, 0, 0.12)), (0, 0, 0), ease="Linear")
    c.hand_on("L", fr(f_in), LOADER_W, (0, 0, 0), ease="SineInOut")
    c.hand_on("L", fr(f_twist), LOADER_W, (0, 0, 25), ease="SineInOut")
    c.hand_on("L", fr(f_hide), add_t(LOADER_W, (0, 0, 0.1)), (0, 0, 25), ease="CubicInOut")
    for k, n in enumerate(ROUND_NAMES, 1):
        held_open(c, n, f_in, LOADER_W, k)
        c.inhand(n, fr(f_show - 3), 0, ease="Constant"); c.inhand(n, fr(f_show - 2), 1, ease="Constant")
        c.inhand(n, fr(f_in - 1), 1, ease="Linear"); c.inhand(n, fr(f_in), 0, ease="Constant")
    lr = (CYL_AXIS[0], CYL_AXIS[1], -0.30)
    held_at(c, "SpeedLoader", f_in, tuple(w - (o - r) for w, o, r in zip(LOADER_W, opened(lr), lr)))
    c.inhand("SpeedLoader", 0, 1, ease="Constant")
    c.marker("MagShow", fr(f_show), "Rounds"); c.marker("LoaderShow", fr(f_show))
    c.marker("ShellIn", fr(f_twist)); c.marker("LoaderHide", fr(f_hide))


def dump():
    """1-3 left: muzzle up 60 f20-f26 Cubic Out; palm on the ejector f23-f26; stroke f26-f30 Linear (ShellEject f28): the
    live rounds and the casings fall (MagHide f36); muzzle down f30-f40; off hand to the pouch f40-f54; loader to the
    cylinder f54-f74 Sine InOut; insert f74-f78 Linear; twist f78-f80 (ShellIn f80); loader hidden f82; close f93-f96"""
    c = Clip("RevolverReload_Dump", BASE_LEN)
    h, base, tilt, face, up, down, flick = poses(c)
    body(c, [(26, up, "Linear"), (30, add(up, gun=((0, 0, 0.03), (2, 0, 0))), "CubicInOut"), (40, down, "SineInOut"),
             (54, add(down, head=(2, -8, 0)), "SineInOut"), (74, down, "Linear"), (78, add(down, gun=((0, 0, 0.03), (0, 0, 0))), "SineInOut"),
             (84, face, "SineInOut")])
    hand_start(c, h)
    c.hand_on("L", fr(20), UNDER, (0, 0, -30), ease="SineInOut")
    c.hand_on("L", fr(24), add_t(EJECTOR, (0, 0, 0.05)), (0, 0, 90), ease="Linear")
    c.hand_on("L", fr(26), add_t(EJECTOR, (0, 0, 0.05)), (0, 0, 90), ease="Linear")
    c.hand_on("L", fr(30), add_t(EJECTOR, (0, 0, 0.25)), (0, 0, 90), ease="SineInOut")
    c.hand_on("L", fr(40), UNDER, (0, 0, -30), ease="SineInOut")
    dump_rounds(c, 26, 30, 36)
    speed_loader(c, h, 54, 48, 74, 78, 80, 82)
    hand_close(c, h, 84)
    crane_keys(c)
    return c


def dry():
    """0 left: muzzle up f20-f24 Cubic Out (faster); palm slams the ejector f24-f26 (ShellEject f25), six casings spray
    (MagHide f34); off hand to the pouch f26-f44 (unhurried, head lead to the loader); loader to the cylinder f44-f74;
    insert f74-f78; twist f78-f80 (ShellIn f80); loader hidden f82; half-turn spin f86-f92, close f93-f96"""
    c = Clip("RevolverReload_Dry", BASE_LEN)
    h, base, tilt, face, up, down, flick = poses(c)
    body(c, [(24, up, "Linear"), (26, add(up, gun=((0, -0.02, 0.04), (4, 0, 0))), "CubicOut"), (34, down, "SineInOut"),
             (44, add(down, head=(3, -10, 0)), "SineInOut"), (74, down, "Linear"), (78, add(down, gun=((0, 0, 0.03), (0, 0, 0))), "SineInOut"),
             (84, face, "SineInOut")])
    hand_start(c, h)
    c.hand_on("L", fr(20), UNDER, (0, 0, -30), ease="SineInOut")
    c.hand_on("L", fr(23), add_t(EJECTOR, (0, 0, -0.1)), (0, 0, 90), ease="QuadIn")
    c.hand_on("L", fr(24), add_t(EJECTOR, (0, 0, 0.05)), (0, 0, 90), ease="Linear")
    c.hand_on("L", fr(26), add_t(EJECTOR, (0, 0, 0.25)), (0, 0, 90), ease="CubicOut")
    c.hand_on("L", fr(32), add_t(EJECTOR, (0, -0.1, 0.4)), (0, 0, 90), ease="SineInOut")
    dump_rounds(c, 24, 26, 33, fall=(-1.1, 0.35, 1.9))
    speed_loader(c, h, 44, 40, 74, 78, 80, 82)
    hand_close(c, h, 84)
    cylinder_curve(c, [(0, 0, "Hold"), (86, 0, "QuadOut"), (92, 180, "Hold"), (END, 180, "Hold")])
    crane_keys(c)
    return c


ROUNDS = {"RevolverReload_Pluck1": "5 (1 spent)", "RevolverReload_Pluck2": "4 (2 spent)",
          "RevolverReload_Dump": "1-3 (the live count shows in the props)", "RevolverReload_Dry": "0 (6 spent)"}
CLIPS = {"RevolverReload_Pluck1": pluck1, "RevolverReload_Pluck2": pluck2, "RevolverReload_Dump": dump, "RevolverReload_Dry": dry}
