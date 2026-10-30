"""Batch 1: cover core. Character faces OUT from the wall (back to it); +x = its right, -z = forward.
Layering (CoverController): IdleTall / Crouch / CrouchPeek (Action3) + LookPos / LookNeg (Action4, Head + UpperTorso)
+ ShuffleTall / ShuffleCrouch (Action4, legs) + leans (Action4). So the crouch's forward lean lives in the hips
(LowerTorso), the chest stays near upright, and the Look clips own the chest turn + breath."""
from bodyanim import *

E = "SineInOut"
DRIFT = ((0.0, 0), (0.5, 1), (1.0, 0))  # (time, phase 0..1) of a 1 s seamless moving hold


def low_ready(c, t, s=0.0, wrist=(0.14, 0.40, -0.98), ease=E):
    """pistol held low across the body, muzzle down-left (finger off the trigger); the off hand relaxed at the chest, clear
    of the gun (style 8: pistol lowered = off hand free)."""
    c.gun_at_wrist(t, wrist, (-42 - 0.6 * s, 52, -18), ease=ease)
    c.free("L", t, 1.0, ease=ease)
    c.hand_free("L", t, (-0.42, 0.95 - 0.012 * s, -0.9), (70, -60, 0), ease=ease)


# ---------------------------------------------------------------------------------------------------- tall cover
def idle_tall():
    c = Clip("CoverIdleTall", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        c.root(t, x=0.05, y=-0.035 - 0.012 * s, z=0.28, roll=1.5 + 0.3 * s, ease=E)
        foot(c, "R", t, x=0.10, z=0.12, yaw=-8, ease=E)
        foot(c, "L", t, x=-0.12, z=0.0, yaw=8, ease=E)
        spine(c, t, pitch=-0.6 * s, roll=-1.5, ease=E)
        head(c, t, pitch=-3 + 0.4 * s, ease=E)
        low_ready(c, t, s)
    return c


def look(name, sign, crouched=False):
    """head + shoulders toward the edge: sign +1 = the edge on the character's left (yaw +). The crouched variant keeps
    the crouch's chest / head pitch under the turn (Look owns UpperTorso + Head and replaces the base's values)."""
    def build():
        c = Clip(name, 1.0, loop=True, priority="Action4", joints=["UpperTorso", "Head"])
        sp, hp = ((-4, 16) if crouched else (0, -2))
        for t, s in DRIFT:
            spine(c, t, pitch=sp - 0.7 * s, yaw=sign * (7 + 0.6 * s), roll=-sign * 1.0, ease=E)
            head(c, t, pitch=hp + 0.5 * s, yaw=sign * (15 + 0.6 * s), roll=0, ease=E)
        return c
    return build


# ---------------------------------------------------------------------------------------------------- low cover
CROUCH_ROOT = dict(x=0.0, y=-1.58, z=0.26)
CROUCH_FEET = {"R": dict(x=0.2, z=-0.6, yaw=-14), "L": dict(x=-0.2, z=0.2, yaw=12, pitch=0)}


def crouch_legs(c, t, s=0.0, pitch=-30, ease=E):
    c.root(t, x=CROUCH_ROOT["x"], y=CROUCH_ROOT["y"] - 0.02 * s, z=CROUCH_ROOT["z"], pitch=pitch - 0.6 * s, roll=0.8, ease=ease)
    for side in ("R", "L"):
        foot(c, side, t, ease=ease, **CROUCH_FEET[side])


def crouch():
    c = Clip("CoverCrouch", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        crouch_legs(c, t, s)
        spine(c, t, pitch=-4 - 0.6 * s, ease=E)
        head(c, t, pitch=16 + 0.4 * s, ease=E)  # counters the hip lean: eyes level, just under the top
        low_ready(c, t, s, wrist=(0.2, 0.5, -1.15))
    return c


def crouch_peek():
    """crouched, shoulders out past the edge; arms come from the weapon Hold (not keyed)."""
    c = Clip("CoverCrouchPeek", 1.0, loop=True, priority="Action3",
             joints=LEGS + ["UpperTorso"])
    for t, s in DRIFT:
        crouch_legs(c, t, 0.5 * s, pitch=-10)
        spine(c, t, pitch=6 - 0.3 * s, ease=E)  # chest back up to level aim over the hip lean
    return c


# ---------------------------------------------------------------------------------------------------- shuffles
def shuffle(name, length, crouched):
    """side-shuffle toward the character's LEFT (-x) at CoverWalkSpeed 8: four quick steps per cycle (L, R, L, R), each
    contact a quarter cycle, so one foot is always planted. A planted foot moves under the body at exactly 8 studs/s,
    including the frames either side of touch-down / lift. Feet are staggered in depth (~0.9-1.0 apart) so the 1-stud
    blocky feet never meet."""
    def build():
        c = Clip(name, length, loop=True, priority="Action4", joints=LEGS)
        c.travel = (-8.0, 0.0)
        L = length
        speed = 8.0
        q = L / 4.0
        sweep = speed * q
        e1 = 1.5 / 60.0
        lift = 0.2 if crouched else 0.26
        base_y = CROUCH_ROOT["y"] if crouched else -0.3
        pitch = -30 if crouched else 0
        z = CROUCH_ROOT["z"] if crouched else 0.28
        for t, dy, roll in ((0, 0, 0.8), (q * 0.5, -0.02, 0.0), (q, 0, -0.8), (q * 1.5, -0.02, 0.0), (2 * q, 0, 0.8),
                            (2.5 * q, -0.02, 0.0), (3 * q, 0, -0.8), (3.5 * q, -0.02, 0.0), (L, 0, 0.8)):
            c.root(t, y=base_y + dy, z=z, pitch=pitch, roll=roll, ease=E)
        depth = ({"L": 0.2, "R": -0.7} if crouched else {"L": -0.5, "R": 0.4})
        for side, starts in (("L", (0.0, 2 * q)), ("R", (q, 3 * q))):
            yaw = (CROUCH_FEET[side]["yaw"] if crouched else (6 if side == "L" else -6))
            xo = (CROUCH_FEET[side]["x"] if crouched else 0.0)
            x0 = -sweep / 2
            keys = []
            for t0 in starts:
                keys += [(t0 - e1, {"x": x0 - speed * e1, "y": 0.06}, "Linear"),
                         (t0, {"x": x0, "y": 0.0}, "Linear"),
                         (t0 + q, {"x": x0 + sweep, "y": 0.0}, "Linear"),
                         (t0 + q + e1, {"x": x0 + sweep + speed * e1, "y": 0.06}, "CubicInOut"),
                         (t0 + q + (q - 2 * e1) * 0.5 + e1, {"x": 0.0, "y": lift}, "CubicInOut")]
            keys = [((t % L) if (t < 0 or t >= L) else t, v, e) for t, v, e in keys]
            cyclic(c, L, keys, lambda t, v, e, side=side, xo=xo, yaw=yaw:
                   foot(c, side, t, x=xo + v["x"], y=v["y"], z=depth[side], yaw=yaw, pitch=8 * v["y"] / lift, ease=e))
        for i, side in enumerate("LRLR"):
            c.marker("Footstep", i * q, side)
        return c
    return build


# ---------------------------------------------------------------------------------------------------- brace
def brace():
    """near miss: tuck in 3 f (Quart Out), moving hold, back by 0.75. Upper body only (works tall and crouched)."""
    c = Clip("CoverBrace", 0.75, loop=False, priority="Action4", joints=["UpperTorso", "Head"] + ARMS)
    f = lambda n: n / 60.0
    spine(c, 0, pitch=0, ease="QuartOut")
    head(c, 0, pitch=-3, ease="QuartOut")
    low_ready(c, 0, 0, ease="QuartOut")
    # f3: flinch peak
    spine(c, f(3), pitch=-11, yaw=4, roll=-3, ease=E)
    head(c, f(4), pitch=-15, yaw=-6, roll=4, ease=E)
    c.gun_at_wrist(f(3), (0.15, 0.62, -0.78), (-50, 60, -25), ease=E)
    c.hand_free("L", f(3), (-0.75, 1.3, -0.75), (60, -20, 30), ease=E)  # off forearm up, shielding the head
    # f20: moving hold
    spine(c, f(20), pitch=-12, yaw=4.5, roll=-3.4, ease="CubicOut")
    head(c, f(21), pitch=-16, yaw=-6, roll=4, ease="CubicOut")
    c.gun_at_wrist(f(20), (0.16, 0.6, -0.8), (-49, 60, -25), ease="CubicOut")
    c.hand_free("L", f(20), (-0.75, 1.27, -0.77), (58, -20, 30), ease="CubicOut")
    # f45: back to the low ready
    spine(c, f(45), pitch=0, ease=E)
    head(c, f(45), pitch=-3, ease=E)
    low_ready(c, f(45), 0)
    for side in ("L",):
        c.free(side, 0, 1.0)
    return c


CLIPS = {
    "CoverIdleTall": idle_tall,
    "CoverCrouch": crouch,
    "CoverCrouchPeek": crouch_peek,
    "CoverLookPos": look("CoverLookPos", +1),
    "CoverLookNeg": look("CoverLookNeg", -1),
    "CoverLookPosCrouch": look("CoverLookPosCrouch", +1, True),
    "CoverLookNegCrouch": look("CoverLookNegCrouch", -1, True),
    "CoverShuffleTall": shuffle("CoverShuffleTall", 0.60, False),
    "CoverShuffleCrouch": shuffle("CoverShuffleCrouch", 0.72, True),
    "CoverBrace": brace,
}
MIRROR = {"CoverIdleTall": "CoverIdleTallLeft", "CoverCrouch": "CoverCrouchLeft", "CoverCrouchPeek": "CoverCrouchPeekLeft",
          "CoverShuffleTall": "CoverShuffleTallRight", "CoverShuffleCrouch": "CoverShuffleCrouchRight"}
