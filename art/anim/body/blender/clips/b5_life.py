"""Batch 5: deaths, idles / breathing / social, door, bot leans (targets sections 11-12).
Deaths own the whole body (Action4); the body lands on the floor (ground-clamped keys) and the last frame is the only
frozen frame. Markers: DropGun (the gun leaves the hand: code drops / ragdolls it), Ground (body contact: dust / sound),
Ragdoll (explosion: code switches to the ragdoll)."""
from bodyanim import *
from b1_cover import CROUCH_ROOT, CROUCH_FEET, crouch_legs, low_ready, DRIFT

E = "SineInOut"
f = lambda n: n / 60.0


def pose_keys(c, fr, root, feet=None, chest=(0, 0, 0), headr=(0, 0, 0), gun=None, off=None, ease=E, planted=None):
    """one full-body key. root = dict for c.root; feet = body-relative feet (root_and_feet) or planted = {side: kw}."""
    if feet is not None:
        root_and_feet(c, f(fr), feet=feet, ease=ease, **root)
    else:
        c.root(f(fr), ease=ease, **root)
        for side, kw in (planted or {"R": {}, "L": {}}).items():
            foot(c, side, f(fr), ease=ease, **kw)
    spine(c, f(fr), *chest, ease=ease)
    head(c, f(fr), *headr, ease=ease)
    if gun is not None:
        c.free("R", f(fr), 0.0 if gun != "free" else 1.0, ease=ease)
    if off is not None:
        c.free("L", f(fr), 1.0, ease=ease)
        c.hand_free("L", f(fr), off[0], off[1], ease=ease)


# ---------------------------------------------------------------------------------------------------- deaths
def death_forward():
    """shot from behind: f0-f3 Linear jolt forward, f3-f20 knees buckle (Quad In), f20-f40 Quad In fall face down,
    Ground f40, f40-f50 Cubic Out settle; DropGun f6. Last frame static."""
    c = Clip("DeathForward", 1.2, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), None, (0, 0, 0), (0, 0, 0), ((0.6, -0.4, -0.5), (0, 0, 0)), ((-0.6, -0.4, -0.5), (0, 0, 0)), "Linear"),
         (3, dict(y=-0.1, z=-0.1, pitch=-12), None, (-10, 0, 0), (-8, 0, 0), ((0.9, -0.2, -0.3), (30, 0, -20)), ((-0.9, -0.2, -0.3), (30, 0, 20)), "QuadIn"),
         (20, dict(y=-1.1, z=-0.2, pitch=-25, roll=4),
          {"R": ((0.0, -1.0, -0.9), (80, 0, 0)), "L": ((0.0, -1.0, -0.8), (85, 0, 0))}, (-15, 0, 4), (-10, 6, 0),
          ((1.1, -0.1, -0.6), (40, 0, -30)), ((-1.1, -0.3, -0.7), (40, 0, 30)), "QuadIn"),
         (40, dict(y=-1.7, z=-1.6, pitch=-88, roll=3),
          {"R": ((0.05, -1.85, 0.25), (-10, 0, 0)), "L": ((-0.1, -1.8, 0.3), (-15, 0, 0))}, (-4, 0, 3), (10, 30, 0),
          ((1.3, 0.6, -0.4), (80, 0, -40)), ((-1.2, 0.9, -0.6), (100, 0, 40)), "CubicOut"),
         (50, dict(y=-1.72, z=-1.62, pitch=-90, roll=3),
          {"R": ((0.05, -1.85, 0.3), (-12, 0, 0)), "L": ((-0.1, -1.8, 0.35), (-16, 0, 0))}, (-3, 0, 3), (12, 32, 0),
          ((1.35, 0.6, -0.4), (80, 0, -40)), ((-1.25, 0.95, -0.6), (100, 0, 40)), E)]
    death_from(c, K, ground=[40, 50])
    c.marker("DropGun", f(6)); c.marker("Ground", f(40))
    return c


def death_backward():
    """shot from the front: f0-f2 Linear chest thrown back, f2-f14 a step back, f14-f36 Quad In fall on the back, Ground f36,
    f36-f66 settle; DropGun f4."""
    c = Clip("DeathBackward", 1.1, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), None, (0, 0, 0), (0, 0, 0), ((0.6, -0.4, -0.5), (0, 0, 0)), ((-0.6, -0.4, -0.5), (0, 0, 0)), "Linear"),
         (2, dict(y=-0.08, z=0.05, pitch=6), None, (12, 0, 0), (10, 0, 0), ((0.9, 0.2, -0.2), (30, 0, -30)), ((-0.9, 0.1, -0.2), (30, 0, 30)), "CubicOut"),
         (14, dict(y=-0.45, z=0.5, pitch=16, roll=-4),
          {"R": ((0.05, -1.6, -0.6), (20, 0, 0)), "L": ((-0.05, -1.7, 0.3), (0, 0, 0))}, (14, 0, -3), (8, 0, 0),
          ((1.2, 0.5, 0.1), (60, 0, -40)), ((-1.2, 0.4, 0.0), (60, 0, 40)), "QuadIn"),
         (36, dict(y=-1.75, z=1.7, pitch=88, roll=-3),
          {"R": ((0.1, -1.8, -0.5), (20, 0, 0)), "L": ((-0.15, -1.75, -0.2), (10, 0, 0))}, (4, 0, 0), (-6, -25, 0),
          ((1.4, 0.8, 0.3), (90, 0, -50)), ((-1.4, 0.6, 0.4), (90, 0, 50)), "CubicOut"),
         (66, dict(y=-1.78, z=1.72, pitch=90, roll=-3),
          {"R": ((0.15, -1.82, -0.55), (22, 0, 0)), "L": ((-0.2, -1.78, -0.25), (12, 0, 0))}, (3, 0, 0), (-8, -28, 0),
          ((1.45, 0.8, 0.3), (90, 0, -50)), ((-1.45, 0.6, 0.4), (90, 0, 50)), E)]
    death_from(c, K, ground=[36, 66])
    c.marker("DropGun", f(4)); c.marker("Ground", f(36))
    return c


def death_crumple():
    """generic: knees give (f0-f20 Cubic In), Ground (knees) f20, f20-f50 Quad In topple sideways, Ground f50, settle f84;
    DropGun f12."""
    c = Clip("DeathCrumple", 1.4, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), None, (0, 0, 0), (0, 0, 0), ((0.6, -0.4, -0.5), (0, 0, 0)), ((-0.6, -0.4, -0.5), (0, 0, 0)), "CubicIn"),
         (20, dict(y=-1.15, z=0.2, pitch=-8, roll=3),
          {"R": ((0.05, -0.95, 0.95), (90, 0, 0)), "L": ((-0.05, -0.95, 0.95), (90, 0, 0))}, (-14, 0, 2), (-14, 0, 0),
          ((0.8, -0.6, -0.4), (0, 0, -10)), ((-0.8, -0.6, -0.4), (0, 0, 10)), "QuadIn"),
         (50, dict(y=-1.6, z=0.3, pitch=-10, roll=80),
          {"R": ((0.1, -0.95, 1.0), (90, 0, 0)), "L": ((-0.1, -1.0, 1.05), (90, 0, 0))}, (-10, 0, -4), (4, 0, -10),
          ((0.8, 0.2, -0.8), (40, 0, -20)), ((-1.0, 0.8, -0.4), (80, 0, 20)), "CubicOut"),
         (84, dict(y=-1.62, z=0.3, pitch=-10, roll=84),
          {"R": ((0.1, -0.95, 1.0), (90, 0, 0)), "L": ((-0.1, -1.0, 1.05), (90, 0, 0))}, (-9, 0, -4), (6, 0, -12),
          ((0.85, 0.2, -0.8), (40, 0, -20)), ((-1.05, 0.8, -0.4), (80, 0, 20)), E)]
    death_from(c, K, ground=[20, 50, 84])
    c.marker("DropGun", f(12)); c.marker("Ground", f(50))
    return c


def death_headshot():
    """head snaps back (f1 Linear, 25 deg), the body drops straight down (f1-f30 Quad In, no step), Ground f30, settle f48;
    DropGun f2."""
    c = Clip("DeathHeadshot", 0.8, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), None, (0, 0, 0), (0, 0, 0), ((0.6, -0.4, -0.5), (0, 0, 0)), ((-0.6, -0.4, -0.5), (0, 0, 0)), "Linear"),
         (1, dict(y=-0.05), None, (4, 0, 0), (25, 0, 0), ((0.65, -0.35, -0.5), (0, 0, 0)), ((-0.65, -0.35, -0.5), (0, 0, 0)), "QuadIn"),
         (18, dict(y=-1.1, z=0.15, pitch=-6),
          {"R": ((0.05, -0.95, 0.9), (88, 0, 0)), "L": ((-0.05, -0.95, 0.9), (88, 0, 0))}, (-4, 0, 0), (20, 0, 0),
          ((0.7, -0.7, -0.2), (0, 0, -10)), ((-0.7, -0.7, -0.2), (0, 0, 10)), "QuadIn"),
         (30, dict(y=-1.7, z=0.9, pitch=70, roll=-6),
          {"R": ((0.1, -1.0, 0.95), (88, 0, 0)), "L": ((-0.1, -1.05, 0.9), (88, 0, 0))}, (4, 0, 0), (10, -15, 0),
          ((1.1, 0.2, 0.3), (60, 0, -30)), ((-1.1, 0.1, 0.3), (60, 0, 30)), "CubicOut"),
         (48, dict(y=-1.74, z=0.95, pitch=74, roll=-6),
          {"R": ((0.12, -1.05, 1.0), (85, 0, 0)), "L": ((-0.12, -1.1, 0.95), (85, 0, 0))}, (3, 0, 0), (8, -18, 0),
          ((1.15, 0.2, 0.3), (60, 0, -30)), ((-1.15, 0.1, 0.3), (60, 0, 30)), E)]
    death_from(c, K, ground=[30, 48])
    c.marker("DropGun", f(2)); c.marker("Ground", f(30))
    return c


def death_explosion():
    """thrown up and back by a blast (f0-f6 Linear), limbs out; the code switches to the ragdoll at Ragdoll f12, so the clip
    only has to sell the launch; f12-f54 a fallback fall if no ragdoll."""
    c = Clip("DeathExplosion", 0.9, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), None, (0, 0, 0), (0, 0, 0), ((0.6, -0.4, -0.5), (0, 0, 0)), ((-0.6, -0.4, -0.5), (0, 0, 0)), "Linear"),
         (6, dict(y=0.3, z=0.4, pitch=30, roll=-6),
          {"R": ((0.3, -1.4, -0.9), (30, 0, 0)), "L": ((-0.2, -1.6, -0.4), (20, 0, 0))}, (16, 0, -4), (14, 0, 0),
          ((1.4, 1.1, 0.2), (120, 0, -40)), ((-1.4, 1.0, 0.3), (120, 0, 40)), "CubicOut"),
         (12, dict(y=0.2, z=0.5, pitch=45, roll=-8),
          {"R": ((0.35, -1.3, -1.0), (35, 0, 0)), "L": ((-0.25, -1.5, -0.6), (25, 0, 0))}, (18, 0, -4), (16, 0, 0),
          ((1.45, 1.15, 0.3), (125, 0, -40)), ((-1.45, 1.05, 0.35), (125, 0, 40)), "QuadIn"),
         (30, dict(y=-1.75, z=1.7, pitch=88, roll=-4),
          {"R": ((0.2, -1.8, -0.4), (15, 0, 0)), "L": ((-0.2, -1.75, -0.2), (10, 0, 0))}, (4, 0, 0), (-6, -20, 0),
          ((1.4, 0.9, 0.3), (90, 0, -50)), ((-1.4, 0.7, 0.4), (90, 0, 50)), "CubicOut"),
         (54, dict(y=-1.78, z=1.72, pitch=90, roll=-4),
          {"R": ((0.22, -1.82, -0.45), (16, 0, 0)), "L": ((-0.22, -1.78, -0.25), (11, 0, 0))}, (3, 0, 0), (-8, -22, 0),
          ((1.45, 0.9, 0.3), (90, 0, -50)), ((-1.45, 0.7, 0.4), (90, 0, 50)), E)]
    death_from(c, K, ground=[30, 54])
    c.marker("DropGun", f(1)); c.marker("Ragdoll", f(12)); c.marker("Ground", f(30))
    return c


def death_cover():
    """killed in cover, back to the wall: f0-f3 Linear jolt, the knees give and the body slides down the wall
    (f3-f30 Quad In) to sit against it, head drops to the side (f30-f45), Ground f30; DropGun f5."""
    c = Clip("DeathCover", 1.2, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    SIT = {"R": ((0.25, -0.35, -1.75), (10, -10, 0)), "L": ((-0.2, -0.45, -1.6), (5, 15, 0))}
    K = [(0, dict(y=-0.04, z=0.15), None, (0, 0, 0), (0, 0, 0), ((0.4, 0.6, -0.9), (0, 0, 0)), ((-0.42, 0.9, -0.9), (70, -60, 0)), "Linear"),
         (3, dict(y=-0.1, z=0.18, pitch=4), None, (6, 0, 0), (8, 0, 0), ((0.6, 0.3, -0.8), (0, 0, 0)), ((-0.6, 0.6, -0.8), (40, 0, 0)), "QuadIn"),
         (30, dict(y=-1.6, z=0.35, pitch=8, roll=3), SIT, (-8, 0, 4), (-14, 10, 8),
          ((0.95, -0.7, -0.6), (0, 0, -10)), ((-0.9, -0.6, -0.7), (0, 0, 10)), "CubicOut"),
         (45, dict(y=-1.62, z=0.36, pitch=8, roll=4), SIT, (-12, 0, 6), (-22, 14, 14),
          ((1.0, -0.75, -0.55), (0, 0, -10)), ((-0.95, -0.65, -0.65), (0, 0, 10)), E),
         (72, dict(y=-1.62, z=0.36, pitch=8, roll=4), SIT, (-13, 0, 6), (-24, 15, 15),
          ((1.0, -0.76, -0.55), (0, 0, -10)), ((-0.95, -0.66, -0.65), (0, 0, 10)), E)]
    death_from(c, K, ground=[30, 45, 72], floor_only=True)
    c.marker("DropGun", f(5)); c.marker("Ground", f(30))
    return c


def death_from(c, K, ground=(), floor_only=False):
    for fr, root, feet, chest, hd, rh, lh, e in K:
        if feet is None:
            c.root(f(fr), ease=e, **root)
            for side in ("R", "L"):
                foot(c, side, f(fr), x=(0.05 if side == "R" else -0.05), ease=e)
        else:
            root_and_feet(c, f(fr), feet=feet, ease=e, **root)
        spine(c, f(fr), *chest, ease=e)
        head(c, f(fr), *hd, ease=e)
        c.hand_free("R", f(fr), rh[0], rh[1], ease=e)
        c.hand_free("L", f(fr), lh[0], lh[1], ease=e)
    c.finish()
    ground_clamp(c, list(ground))
    clamp_dense(c, max(ground) + 6)


# ---------------------------------------------------------------------------------------------------- idles
STAND = {"R": dict(x=0.08, yaw=-8), "L": dict(x=-0.08, z=0.12, yaw=8)}


def stand(c, fr, y=-0.04, x=0.0, roll=0.0, chest=(0, 0, 0), hd=(0, 0, 0), e=E, feet=STAND):
    c.root(f(fr), x=x, y=y, roll=roll, ease=e)
    for side, kw in feet.items():
        foot(c, side, f(fr), ease=e, **kw)
    spine(c, f(fr), *chest, ease=e)
    head(c, f(fr), *hd, ease=e)


def fidget_shift():
    c = Clip("IdleFidgetShift", 2.5, loop=False, priority="Idle", joints=LEGS + ["UpperTorso", "Head"])
    for fr, x, roll, ch, hd in ((0, 0, 0, (0, 0, 0), (0, 0, 0)), (40, 0.08, 2.5, (0, 0, -1.5), (0, 0, 1)),
                                (65, 0.08, 2.5, (-2, 3, -3), (2, -3, 1)), (90, 0.08, 2.5, (0, -2, -1.5), (0, 2, 1)),
                                (150, 0, 0, (0, 0, 0), (0, 0, 0))):
        stand(c, fr, x=x, roll=roll, chest=ch, hd=hd)
    return c


def fidget_gun_check():
    """glance at the gun: head leads f0-f8, gun tilts to show the mag f8-f30 (Cubic InOut), moving hold, back f120-f180."""
    c = Clip("IdleFidgetGunCheck", 3.0, loop=False, priority="Action", joints=["UpperTorso", "Head"] + ARMS)
    for fr, hd, wr, rot, e in ((0, (0, 0, 0), (0.35, 1.0, -1.25), (0, 0, 0), "CubicOut"), (8, (-14, -6, 0), (0.35, 1.0, -1.25), (0, 0, 0), "CubicInOut"),
                               (30, (-18, -8, 0), (0.15, 1.05, -1.0), (10, 30, 60), E), (120, (-17, -9, 0), (0.15, 1.04, -1.0), (11, 31, 62), "CubicInOut"),
                               (180, (0, 0, 0), (0.35, 1.0, -1.25), (0, 0, 0), E)):
        head(c, f(fr), *hd, ease=e)
        spine(c, f(fr), pitch=(-3 if 8 <= fr <= 120 else 0), ease=e)
        c.gun_at_wrist(f(fr), wr, rot, ease=e)
        c.hand_on("L", f(fr), (-0.15, -0.35, -0.55), (0, 0, 0), ease=e)
    return c


def fidget_look():
    c = Clip("IdleFidgetLook", 3.0, loop=False, priority="Idle", joints=["UpperTorso", "Head"])
    for fr, ch, hd in ((0, 0, 0), (30, 10, 14), (80, 10.5, 14.5), (120, -10, -14), (150, -10.5, -14.5), (180, 0, 0)):
        spine(c, f(fr), yaw=ch, ease=E)
        head(c, f(fr), yaw=hd, ease=E)
    return c


def breathe(name, L, inhale, chest, head_c):
    """UpperTorso + Head only. Breathing over a weapon Hold should be a code layer on the Waist (the Hold keys the torso);
    these clips are for unarmed / lobby use and as the reference curve."""
    def build():
        c = Clip(name, L, loop=True, priority="Core", joints=["UpperTorso", "Head"])
        spine(c, 0, ease=E); head(c, 0, ease=E)
        spine(c, inhale, pitch=chest, ease=E); head(c, inhale, pitch=-head_c, ease=E)
        spine(c, L, ease=E); head(c, L, ease=E)
        return c
    return build


def round_ready():
    """low ready -> head up first (f0-f12) -> gun up to the chest (f6-f22 Quart Out) -> off hand taps the mag base (f22-f30
    Linear, Tap f30) -> Back Out 4% settle (f34-f50) -> hold."""
    c = Clip("RoundReady", 1.2, loop=False, priority="Action", joints=["UpperTorso", "Head"] + ARMS)
    for fr, hd, wr, rot, off, e in ((0, (-10, 0, 0), (0.3, 0.75, -1.0), (-42, 52, -18), ((-0.42, 0.95, -0.9), (70, -60, 0)), "CubicOut"),
                                    (12, (0, 0, 0), (0.3, 0.85, -1.0), (-30, 40, -12), ((-0.42, 0.95, -0.9), (70, -60, 0)), "QuartOut"),
                                    (22, (-2, 0, 0), (0.3, 1.25, -1.15), (-5, 5, 0), ((-0.3, 0.6, -1.15), (-30, 0, 0)), "Linear"),
                                    (30, (-4, 0, 0), (0.3, 1.24, -1.15), (-4, 5, 0), ((-0.05, 0.75, -1.15), (-40, 0, 0)), "CubicOut"),
                                    (34, (-3, 0, 0), (0.3, 1.25, -1.15), (-5, 5, 0), ((-0.3, 1.0, -1.25), (0, 0, 0)), "BackOut:0.6"),
                                    (50, (0, 0, 0), (0.3, 1.25, -1.2), (-6, 4, 0), ((-0.42, 1.05, -1.2), (0, 0, 0)), E),
                                    (72, (0, 0, 0), (0.3, 1.24, -1.2), (-6.5, 4, 0), ((-0.42, 1.04, -1.2), (0, 0, 0)), E)):
        head(c, f(fr), *hd, ease=e)
        spine(c, f(fr), pitch=-2, ease=e)
        c.gun_at_wrist(f(fr), wr, rot, ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), off[0], off[1], ease=e)
    c.marker("Tap", f(30))
    return c


def victory():
    """gun to low ready, exhale, look round, rest (hold the last pose)."""
    c = Clip("Victory", 3.0, loop=False, priority="Action", joints=BODY)
    for fr, ch, hd, wr, rot, e in ((0, (0, 0, 0), (0, 0, 0), (0.3, 1.25, -1.2), (-6, 4, 0), "CubicOut"),
                                   (24, (-3, 0, 0), (-4, 0, 0), (0.3, 0.75, -1.0), (-42, 52, -18), E),
                                   (60, (-5, 0, 0), (-6, 0, 0), (0.3, 0.73, -1.0), (-43, 52, -18), E),
                                   (90, (-2, 8, 0), (2, 14, 0), (0.3, 0.75, -1.0), (-42, 52, -18), E),
                                   (120, (-2, -8, 0), (2, -14, 0), (0.3, 0.75, -1.0), (-42, 52, -18), E),
                                   (180, (-1, 0, 0), (0, 0, 0), (0.2, 0.95, -0.9), (-20, 80, -10), E)):
        stand(c, fr, y=(-0.07 if 24 <= fr <= 60 else -0.04), chest=ch, hd=hd, e=e)
        c.gun_at_wrist(f(fr), wr, rot, ease=e)
        c.pole("R", f(fr), (1.9, 0.9, -0.6), ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), (-0.42, 0.95, -0.9), (70, -60, 0), ease=e)
    return c


def defeat():
    """head drops, shoulders slump, the gun hangs in one hand, the off hand drops off it, a slow weight shift."""
    c = Clip("Defeat", 2.5, loop=False, priority="Action", joints=BODY)
    for fr, ch, hd, x, roll, e in ((0, (0, 0, 0), (0, 0, 0), 0, 0, "CubicOut"), (20, (-6, 0, 0), (-22, 0, 0), 0, 0, E),
                                   (60, (-10, 0, 2), (-24, 4, 0), 0.04, 1.5, E), (150, (-10, 0, 2), (-25, -3, 0), 0.08, 2.5, E)):
        stand(c, fr, y=-0.06, x=x, roll=roll, chest=ch, hd=hd, e=e)
        c.gun_at_wrist(f(fr), (0.75, -0.4, -0.45) if fr >= 20 else (0.3, 0.75, -1.0), (-80, 0, 0) if fr >= 20 else (-42, 52, -18), ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), (-0.85, -0.3, -0.3) if fr >= 60 else (-0.42, 0.95, -0.9), (0, 0, 10) if fr >= 60 else (70, -60, 0), ease=e)
    return c


def door_open():
    """off hand pushes the door (contact f12, Push marker: the door starts), gun hand keeps the gun on line at the chest,
    a short step in (hips 0.3 forward, Footstep f20), f30-f48 back to the gun."""
    c = Clip("DoorOpen", 0.8, loop=False, priority="Action", joints=["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand"])
    c.free("L", 0, 1.0)
    for fr, pos, rot, ch, e in ((0, (-0.42, 1.0, -1.2), (0, 0, 0), (0, 0, 0), "CubicOut"), (10, (-0.6, 1.25, -1.65), (-75, 0, 0), (-2, 6, 0), "Linear"),
                                (12, (-0.6, 1.25, -1.72), (-78, 0, 0), (-3, 7, 0), "CubicOut"), (24, (-0.6, 1.2, -1.85), (-80, 0, 0), (-4, 8, 0), E),
                                (30, (-0.6, 1.2, -1.85), (-80, 0, 0), (-4, 8, 0), "CubicInOut"), (48, (-0.42, 1.0, -1.2), (0, 0, 0), (0, 0, 0), E)):
        c.hand_free("L", f(fr), pos, rot, ease=e)
        spine(c, f(fr), *ch, ease=e)
        head(c, f(fr), yaw=-ch[1] * 0.5, ease=e)
    c.marker("Push", f(12))
    c.marker("Footstep", f(20))
    return c


# ---------------------------------------------------------------------------------------------------- bot leans
def bot_lean(name, sign):
    """training bots leaning out of cover (Action2 over their weapon hold): hips slide 0.14 toward the lean, the torso rolls
    16 out over the hip (7 hips + 9 chest), head counter-rolls to stay near level, feet planted, knees soft; moving hold.
    sign +1 = lean to the character's left."""
    def build():
        c = Clip(name, 1.0, loop=True, priority="Action2", joints=LEGS + ["UpperTorso", "Head"])
        for t, s in DRIFT:
            c.root(t, x=-sign * 0.14, y=-0.08 - 0.015 * s, roll=sign * (7 + 0.4 * s), ease=E)
            foot(c, "R", t, x=0.12, yaw=-8, ease=E)
            foot(c, "L", t, x=-0.12, z=0.1, yaw=8, ease=E)
            spine(c, t, roll=sign * (9 + 0.4 * s), pitch=-0.5 * s, ease=E)
            head(c, t, roll=-sign * 10, ease=E)
        return c
    return build


CLIPS = {
    "DeathForward": death_forward, "DeathBackward": death_backward, "DeathCrumple": death_crumple,
    "DeathHeadshot": death_headshot, "DeathExplosion": death_explosion, "DeathCover": death_cover,
    "IdleFidgetShift": fidget_shift, "IdleFidgetGunCheck": fidget_gun_check, "IdleFidgetLook": fidget_look,
    "BreatheCalm": breathe("BreatheCalm", 4.0, 100 / 60.0, 1.2, 0.6),
    "BreatheHeavy": breathe("BreatheHeavy", 1.5, 35 / 60.0, 3.0, 1.5),
    "RoundReady": round_ready, "Victory": victory, "Defeat": defeat, "DoorOpen": door_open,
    "BotLeanLeft": bot_lean("BotLeanLeft", +1), "BotLeanRight": bot_lean("BotLeanRight", -1),
}
MIRROR = {}
