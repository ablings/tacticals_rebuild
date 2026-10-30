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
# Feet: "plant" = world-planted at the given offset (the buckle: knees give while the feet stay put, the hips travel over
# them); a dict = body-relative (the fall, the ground pose). Ground poses lie FLAT: torso box on the floor, legs along
# the body (knees 10-20), arms beside / above the head or along the sides, nothing propping the body up.
FLAT_FRONT = {"R": ((0.2, -1.91, 0.15), (-15, 0, 0)), "L": ((-0.2, -1.9, 0.2), (-20, 0, 0))}     # face down, soles up
FLAT_BACK = {"R": ((0.3, -1.91, -0.1), (20, 0, 0)), "L": ((-0.25, -1.9, -0.15), (10, 0, 0))}  # on the back, toes up
SIDE = {"R": ((0.1, -1.45, -0.7), (40, 0, 0)), "L": ((-0.1, -1.55, -0.45), (30, 0, 0))}        # on the side, knees bent
ARMS_UP_FRONT = (((1.6, -0.45, 0.1), (0, 0, -25)), ((-1.6, -0.4, 0.1), (0, 0, 25)))  # arms along the sides (an overhead swing whipped the upper arms)    # hands beside the head
ARMS_OUT_BACK = (((1.75, 0.7, 0.0), (80, 0, -60)), ((-1.7, 0.9, 0.0), (80, 0, 60)))           # arms out to the sides
ARMS_SIDE = (((0.9, -0.55, -0.6), (0, 0, -10)), ((-0.6, 1.1, -1.35), (90, 0, 20)))  # under-arm forward, off the shoulder line
START = (((0.3, 0.75, -1.0), (0, 0, 0)), ((-0.42, 0.95, -0.9), (70, -60, 0)))  # the low ready the deaths start from


def death_from(c, K, ground=(), torso_rest=True, pole=(2.8, 0.0)):
    for fr, root, feet, chest, hd, arms, e in K:
        if feet == "plant" or isinstance(feet, tuple) and feet and feet[0] == "plant":
            off = feet[1] if isinstance(feet, tuple) else {}
            c.root(f(fr), ease=e, **root)
            for side in ("R", "L"):
                kw = dict(x=(0.08 if side == "R" else -0.08), z=(0.0 if side == "R" else 0.12))
                kw.update(off.get(side, {}))
                foot(c, side, f(fr), ease=e, **kw)
        else:
            root_and_feet(c, f(fr), feet=feet, ease=e, **root)
        spine(c, f(fr), *chest, ease=e)
        head(c, f(fr), *hd, ease=e)
        (rp, rr), (lp, lr) = arms
        c.hand_free("R", f(fr), rp, rr, ease=e)
        c.hand_free("L", f(fr), lp, lr, ease=e)
        # elbow poles: behind the body by default; lying on the back, in FRONT (= up) so the elbows don't dig into the floor
        # elbow poles out to the SIDES and never switched across the arm's plane (an up/behind switch flipped the
        # elbows 90 deg in a frame, and an 'up' pole held dead arms in the air)
        c.pole("R", f(fr), (pole[0], 0.67, pole[1]), ease=e)
        c.pole("L", f(fr), (-pole[0], 0.67, pole[1]), ease=e)
    c.finish()
    last = int(round(c.length * 60))
    clamp_exact(c, last, both=False)               # lift anything under the floor, every frame
    ground_clamp(c, list(ground) + [last])          # the ground keys rest exactly on it


def death_forward():
    """shot from behind: f0-f3 Linear jolt forward, f3-f20 the knees buckle with the feet planted (Quad In; the hips travel
    forward over the knees), f20-f40 Quad In fall face down, Ground f40, f40-f50 Cubic Out settle flat (hands beside the
    head); a slow 0.5 deg settle to the end; DropGun f6."""
    c = Clip("DeathForward", 1.2, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), "plant", (0, 0, 0), (0, 0, 0), START, "Linear"),
         (3, dict(y=-0.12, z=-0.12, pitch=-12), "plant", (-10, 0, 0), (-8, 0, 0),
          (((0.9, -0.2, -0.4), (30, 0, -20)), ((-0.9, -0.2, -0.4), (30, 0, 20))), "QuadIn"),
         (20, dict(y=-1.15, z=-0.5, pitch=-22, roll=4), ("plant", {"R": dict(pitch=-55), "L": dict(pitch=-60)}), (-15, 0, 4), (-10, 6, 0),
          (((1.1, -0.1, -0.7), (40, 0, -30)), ((-1.1, -0.3, -0.8), (40, 0, 30))), "QuadIn"),
         (40, dict(y=-1.72, z=-1.7, pitch=-88, roll=2), FLAT_FRONT, (-2, 0, 2), (32, 8, 0), ARMS_UP_FRONT, "CubicOut"),
         (50, dict(y=-1.74, z=-1.72, pitch=-90, roll=2), FLAT_FRONT, (-1, 0, 2), (32, 8, 0), ARMS_UP_FRONT, E),
         (72, dict(y=-1.74, z=-1.72, pitch=-90.5, roll=2), FLAT_FRONT, (-1, 0, 2), (32, 8, 0), ARMS_UP_FRONT, E)]
    death_from(c, K, ground=[40, 50], pole=(2.07, 1.5))  # face down: elbows to the back (= up), one side all clip
    c.marker("DropGun", f(6)); c.marker("Ground", f(40))
    return c


def death_backward():
    """shot from the front: f0-f2 Linear chest thrown back, f2-f14 one step back, f14-f36 Quad In fall on the back,
    Ground f36, f36-f66 settle flat, arms out; DropGun f4."""
    c = Clip("DeathBackward", 1.1, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), "plant", (0, 0, 0), (0, 0, 0), START, "Linear"),
         (2, dict(y=-0.08, z=0.05, pitch=6), "plant", (12, 0, 0), (10, 0, 0),
          (((0.9, 0.2, -0.2), (30, 0, -30)), ((-0.9, 0.1, -0.2), (30, 0, 30))), "CubicOut"),
         (14, dict(y=-0.45, z=0.55, pitch=16, roll=-4), ("plant", {"L": dict(z=0.9)}), (14, 0, -3), (8, 0, 0),
          (((1.2, 0.5, 0.1), (60, 0, -40)), ((-1.2, 0.4, 0.0), (60, 0, 40))), "QuadIn"),
         (36, dict(y=-1.72, z=1.75, pitch=88, roll=-3), FLAT_BACK, (2, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, "CubicOut"),
         (66, dict(y=-1.74, z=1.77, pitch=90, roll=-3), FLAT_BACK, (1.5, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, E)]
    death_from(c, K, ground=[36, 66])
    c.marker("DropGun", f(4)); c.marker("Ground", f(36))
    return c


def death_crumple():
    """generic: f0-f2 Linear jolt, the knees give with the feet planted (f2-f20 Cubic In), knees on the floor f20, f20-f50
    Quad In topple onto the side, Ground f50, settle to f84; DropGun f12."""
    c = Clip("DeathCrumple", 1.4, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), "plant", (0, 0, 0), (0, 0, 0), START, "Linear"),
         (2, dict(y=-0.1, z=0.05, pitch=-4), "plant", (-6, 0, 0), (-6, 0, 0), START, "CubicIn"),
         (20, dict(y=-1.15, z=-0.45, pitch=-8, roll=3), ("plant", {"R": dict(pitch=-60), "L": dict(pitch=-60)}), (-14, 0, 2), (-14, 0, 0),
          (((0.8, -0.6, -0.5), (0, 0, -10)), ((-0.8, -0.6, -0.5), (0, 0, 10))), "QuadIn"),
         (50, dict(y=-2.0, z=-0.3, pitch=-12, roll=66), SIDE, (-8, 0, -4), (4, 0, -10), ARMS_SIDE, "CubicOut"),
         (84, dict(y=-2.05, z=-0.3, pitch=-12, roll=68), SIDE, (-7, 0, -4), (6, 0, -12), ARMS_SIDE, E)]
    death_from(c, K, ground=[50, 84])
    c.marker("DropGun", f(12)); c.marker("Ground", f(50))
    return c


def death_headshot():
    """head snaps back (f1 Linear, 25 deg), the body drops straight down with the feet planted (f1-f18 Quad In, knees give),
    then tips back flat (f18-f30), Ground f30, settle to f48; DropGun f2."""
    c = Clip("DeathHeadshot", 0.8, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), "plant", (0, 0, 0), (0, 0, 0), START, "Linear"),
         (1, dict(y=-0.05), "plant", (4, 0, 0), (25, 0, 0), START, "QuadIn"),
         (18, dict(y=-1.35, z=0.25, pitch=-6), ("plant", {"R": dict(pitch=-50), "L": dict(pitch=-50)}), (-4, 0, 0), (12, 0, 0),
          (((0.75, -0.7, -0.2), (0, 0, -10)), ((-0.75, -0.7, -0.2), (0, 0, 10))), "QuadIn"),
         (30, dict(y=-1.72, z=1.6, pitch=86, roll=-6), FLAT_BACK, (3, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, "CubicOut"),
         (48, dict(y=-1.74, z=1.62, pitch=89, roll=-6), FLAT_BACK, (2, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, E)]
    death_from(c, K, ground=[30, 48])
    c.marker("DropGun", f(2)); c.marker("Ground", f(30))
    return c


def death_explosion():
    """thrown up and back by a blast (f0-f6 Linear), limbs out; the code switches to the ragdoll at Ragdoll f12; f12-f54 a
    fallback fall flat on the back if no ragdoll."""
    c = Clip("DeathExplosion", 0.9, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    K = [(0, dict(y=-0.04), "plant", (0, 0, 0), (0, 0, 0), START, "Linear"),
         (6, dict(y=0.3, z=0.4, pitch=30, roll=-6), {"R": ((0.3, -1.4, -0.9), (30, 0, 0)), "L": ((-0.2, -1.6, -0.4), (20, 0, 0))},
          (16, 0, -4), (14, 0, 0), (((1.4, 1.1, 0.2), (120, 0, -40)), ((-1.4, 1.0, 0.3), (120, 0, 40))), "CubicOut"),
         (12, dict(y=0.2, z=0.5, pitch=45, roll=-8), {"R": ((0.35, -1.3, -1.0), (35, 0, 0)), "L": ((-0.25, -1.5, -0.6), (25, 0, 0))},
          (18, 0, -4), (16, 0, 0), (((1.45, 1.15, 0.3), (125, 0, -40)), ((-1.45, 1.05, 0.35), (125, 0, 40))), "QuadIn"),
         (30, dict(y=-1.72, z=1.75, pitch=88, roll=-4), FLAT_BACK, (3, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, "CubicOut"),
         (54, dict(y=-1.74, z=1.77, pitch=90, roll=-4), FLAT_BACK, (2, 0, 0), (-12, -8, 0), ARMS_OUT_BACK, E)]
    death_from(c, K, ground=[30, 54])
    c.marker("DropGun", f(1)); c.marker("Ragdoll", f(12)); c.marker("Ground", f(30))
    return c


def death_cover():
    """killed in cover, back to the wall (face 0.85 behind the HRP): f0-f3 Linear jolt (chest forward, off the wall), the
    knees give and the back slides down the wall (f3-f30 Quad In) until the hips sit on the floor 0.05 off the face, legs
    out in front, heels on the floor, hands beside the thighs; head drops to the side (f30-f45); Ground f30; DropGun f5."""
    c = Clip("DeathCover", 1.2, loop=False, priority="Action4", joints=BODY)
    c.free("L", 0, 1.0); c.free("R", 0, 1.0)
    SIT = ("plant", {"R": dict(x=0.25, z=-1.75, pitch=15), "L": dict(x=-0.25, z=-1.65, yaw=12, pitch=12)})
    HANDS = (((1.35, -0.95, -0.7), (0, 0, -10)), ((-1.35, -0.95, -0.7), (0, 0, 10)))
    K = [(0, dict(y=-0.04, z=0.15), ("plant", {"L": dict(z=0.12)}), (0, 0, 0), (0, 0, 0), START, "Linear"),
         (3, dict(y=-0.1, z=0.18, pitch=-6), ("plant", {"L": dict(z=0.12)}), (-8, 0, 0), (-8, 0, 0),
          (((0.6, 0.3, -0.9), (0, 0, 0)), ((-0.6, 0.6, -0.9), (40, 0, 0))), "QuadIn"),
         (30, dict(y=-1.95, z=0.3, pitch=6, roll=3), SIT, (-10, 0, 4), (-14, 10, 8), HANDS, "CubicOut"),
         (45, dict(y=-1.97, z=0.3, pitch=6, roll=4), SIT, (-14, 0, 6), (-15, 14, 12), HANDS, E),
         (72, dict(y=-1.97, z=0.3, pitch=6, roll=4), SIT, (-14.5, 0, 6), (-15, 14.5, 12.5), HANDS, E)]
    death_from(c, K, ground=[30, 45])
    c.marker("DropGun", f(5)); c.marker("Ground", f(30))
    return c


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
    c = Clip("IdleFidgetGunCheck", 3.0, loop=False, priority="Action2", joints=["UpperTorso", "Head"] + ARMS)
    for fr, hd, wr, rot, e in ((0, (0, 0, 0), (0.35, 1.0, -1.25), (0, 0, 0), "CubicOut"), (8, (-14, -6, 0), (0.35, 1.0, -1.25), (0, 0, 0), "CubicInOut"),
                               (30, (-18, -8, 0), (0.15, 1.05, -1.0), (10, 30, 60), E), (120, (-17, -9, 0), (0.15, 1.04, -1.0), (11, 31, 62), "CubicInOut"),
                               (180, (0, 0, 0), (0.35, 1.0, -1.25), (0, 0, 0), E)):
        head(c, f(fr), *hd, ease=e)
        spine(c, f(fr), pitch=(-3 if 8 <= fr <= 120 else 0), ease=e)
        c.gun_at_wrist(f(fr), wr, rot, ease=e)
        c.hand_on("L", f(fr), (0.0, -0.95, 0.15), (0, 0, 0), ease=e)
        c.pole("L", f(fr), (-1.6, -0.6, -0.6), ease=e)  # off elbow dropped: the forearm runs under the gun
    return c


def fidget_look():
    c = Clip("IdleFidgetLook", 3.0, loop=False, priority="Idle", joints=["UpperTorso", "Head"])
    for fr, ch, hd in ((0, 0, 0), (30, 10, 14), (80, 10.5, 14.5), (120, -10, -14), (150, -10.5, -14.5), (180, 0, 0)):
        spine(c, f(min(180, fr + (3 if 0 < fr < 180 else 0))), yaw=ch, ease=E)   # chest follows 3 f behind the head
        head(c, f(max(0, fr - (2 if 0 < fr < 180 else 0))), yaw=hd, ease=E)
    return c


def breathe(name, L, inhale, chest, head_c):
    """UpperTorso + Head only. Breathing over a weapon Hold should be a code layer on the Waist (the Hold keys the torso);
    these clips are for unarmed / lobby use and as the reference curve."""
    def build():
        c = Clip(name, L, loop=True, priority="Idle", joints=["UpperTorso", "Head"])
        spine(c, 0, ease=E); head(c, 0, ease=E)
        spine(c, inhale, pitch=chest, ease=E); head(c, inhale, pitch=-head_c, ease=E)
        spine(c, L, ease=E); head(c, L, ease=E)
        return c
    return build


def round_ready():
    """low ready -> head up first (f0-f12) -> gun up to the chest (f6-f22 Quart Out) -> off hand taps the mag base (f22-f30
    Linear, Tap f30) -> Back Out 4% settle (f34-f50) -> hold."""
    c = Clip("RoundReady", 1.2, loop=False, priority="Action2", joints=["UpperTorso", "Head"] + ARMS)
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
    c.marker("Tap", f(32))
    return c


def victory():
    """gun to low ready, exhale, look round, rest (hold the last pose)."""
    c = Clip("Victory", 3.0, loop=False, priority="Action2", joints=BODY)
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
        c.hand_free("L", f(fr), (-0.6, 0.4, -0.85), (40, -40, 0), ease=e)  # off hand low, clear of the gun across the chest
    return c


def defeat():
    """head drops, shoulders slump, the gun hangs in one hand, the off hand drops off it, a slow weight shift."""
    c = Clip("Defeat", 2.5, loop=False, priority="Action2", joints=BODY)
    for fr, ch, hd, x, roll, e in ((0, (0, 0, 0), (0, 0, 0), 0, 0, "CubicOut"), (20, (-6, 0, 0), (-22, 0, 0), 0, 0, E),
                                   (60, (-10, 0, 2), (-24, 4, 0), 0.04, 1.5, E), (150, (-10, 0, 2), (-25, -3, 0), 0.08, 2.5, E)):
        stand(c, fr, y=-0.06, x=x, roll=roll, chest=ch, hd=hd, e=e)
        c.gun_at_wrist(f(fr), (1.6, -0.35, -0.3) if fr >= 20 else (0.3, 0.75, -1.0), (-80, 0, 0) if fr >= 20 else (-42, 52, -18), ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), (-1.6, -0.3, -0.25) if fr >= 60 else (-0.42, 0.95, -0.9), (0, 0, 10) if fr >= 60 else (70, -60, 0), ease=e)
    return c


def door_open():
    """off hand pushes the door (contact f12, Push marker: the door starts), gun hand keeps the gun on line at the chest,
    a short step in (hips 0.3 forward, Footstep f20), f30-f48 back to the gun."""
    c = Clip("DoorOpen", 0.8, loop=False, priority="Action2", joints=["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand"])
    c.free("L", 0, 1.0)
    for fr, pos, rot, ch, e in ((0, (-0.42, 1.0, -1.2), (0, 0, 0), (0, 0, 0), "CubicOut"), (10, (-0.6, 1.25, -1.65), (-75, 0, 0), (-2, 2, 0), "Linear"),
                                (12, (-0.6, 1.25, -1.72), (-78, 0, 0), (-3, 2, 0), "CubicOut"), (24, (-0.6, 1.2, -1.85), (-80, 0, 0), (-4, 2, 0), E),
                                (30, (-0.62, 1.21, -1.88), (-81, 0, 0), (-4.5, 2, 0), "CubicInOut"), (48, (-0.42, 1.0, -1.2), (0, 0, 0), (0, 0, 0), E)):
        c.hand_free("L", f(fr), pos, rot, ease=e)
        spine(c, f(fr), *ch, ease=e)
        head(c, f(fr), yaw=-ch[1] * 0.5, ease=e)
    c.marker("Push", f(12))
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
    "BotLeanLeft": bot_lean("BotLeanLeft", +1),
}
MIRROR = {"BotLeanLeft": "BotLeanRight"}
