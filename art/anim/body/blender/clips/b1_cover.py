"""Batch 1: cover core. Character faces OUT from the wall (back to it); +x = its right, -z = forward.
Layering (CoverController): IdleTall / Crouch / CrouchPeek (Action3) + LookPos / LookNeg (Action4, Head + UpperTorso)
+ ShuffleTall / ShuffleCrouch (Action4, legs) + leans (Action4). So the crouch's forward lean lives in the hips
(LowerTorso), the chest stays near upright, and the Look clips own the chest turn + breath."""
from bodyanim import *

E = "SineInOut"
DRIFT = ((0.0, 0), (0.5, 1), (1.0, 0))  # (time, phase 0..1) of a 1 s seamless moving hold


def low_ready(c, t, s=0.0, wrist=(0.12, 0.42, -0.72), ease=E):
    """pistol held low across the body, muzzle down-left; off hand resting under the gun hand's wrist."""
    c.gun_at_wrist(t, wrist, (-42 - 0.6 * s, 52, -18), ease=ease)
    c.free("L", t, 1.0, ease=ease)
    c.hand_free("L", t, (-0.42, 0.30 - 0.01 * s, -0.78), (10, -30, 0), ease=ease)


# ---------------------------------------------------------------------------------------------------- tall cover
def idle_tall():
    c = Clip("CoverIdleTall", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        c.root(t, x=0.05, y=-0.10 - 0.018 * s, roll=1.5 + 0.3 * s, ease=E)
        foot(c, "R", t, x=0.10, yaw=-8, ease=E)
        foot(c, "L", t, x=-0.12, z=-0.12, yaw=8, ease=E)
        spine(c, t, pitch=-0.6 * s, roll=-1.5, ease=E)
        head(c, t, pitch=-3 + 0.4 * s, ease=E)
        low_ready(c, t, s)
    return c


def look(name, sign):
    """head + shoulders toward the edge: sign +1 = the edge on the character's left (yaw +)."""
    def build():
        c = Clip(name, 1.0, loop=True, priority="Action4", joints=["UpperTorso", "Head"])
        for t, s in DRIFT:
            spine(c, t, pitch=-0.7 * s, yaw=sign * (9 + 0.6 * s), roll=-sign * 1.0, ease=E)
            head(c, t, pitch=-2 + 0.5 * s, yaw=sign * (14 + 0.8 * s), roll=0, ease=E)
        return c
    return build


# ---------------------------------------------------------------------------------------------------- low cover
CROUCH_ROOT = dict(x=0.0, y=-1.42, z=0.30)
CROUCH_FEET = {"R": dict(x=0.16, z=-0.42, yaw=-14), "L": dict(x=-0.16, z=0.12, yaw=12, pitch=0)}


def crouch_legs(c, t, s=0.0, pitch=24, ease=E):
    c.root(t, x=CROUCH_ROOT["x"], y=CROUCH_ROOT["y"] - 0.02 * s, z=CROUCH_ROOT["z"], pitch=pitch - 0.6 * s, roll=0.8, ease=ease)
    for side in ("R", "L"):
        foot(c, side, t, ease=ease, **CROUCH_FEET[side])


def crouch():
    c = Clip("CoverCrouch", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        crouch_legs(c, t, s)
        spine(c, t, pitch=-4 - 0.6 * s, ease=E)
        head(c, t, pitch=-12 + 0.4 * s, ease=E)  # counters the hip lean: eyes level, just under the top
        low_ready(c, t, s, wrist=(0.1, 0.35, -0.82))
    return c


def crouch_peek():
    """crouched, shoulders out past the edge; arms come from the weapon Hold (not keyed)."""
    c = Clip("CoverCrouchPeek", 1.0, loop=True, priority="Action3",
             joints=LEGS + ["UpperTorso"])
    for t, s in DRIFT:
        crouch_legs(c, t, 0.5 * s, pitch=10)
        spine(c, t, pitch=-6 - 0.3 * s, ease=E)  # chest back up to level aim over the hip lean
    return c


# ---------------------------------------------------------------------------------------------------- shuffles
def shuffle(name, length, crouched):
    """side-shuffle toward the character's LEFT (-x) at CoverWalkSpeed 8 (length x 8 studs per cycle). Lead = left foot
    contact at 0, trail = right foot at half. Feet never closer than 0.9 (blocky feet are 1 wide)."""
    def build():
        c = Clip(name, length, loop=True, priority="Action4", joints=LEGS)
        L = length
        speed = 8.0
        sweep = 1.0  # studs a planted foot travels under the body
        tc = sweep / speed  # contact time
        lift = 0.3 if crouched else 0.42
        base_y = CROUCH_ROOT["y"] if crouched else -0.12
        pitch = 24 if crouched else 0
        z = CROUCH_ROOT["z"] if crouched else 0.0
        # root: low at each contact, high mid-flight; tiny roll toward the planted foot
        for t, dy, roll in ((0, 0, 1.2), (tc, -0.03, 0.6), (L * 0.5 - (L * 0.5 - tc) * 0.5, 0.06, 0),
                            (L * 0.5, 0, -1.2), (L * 0.5 + tc, -0.03, -0.6), (L - (L * 0.5 - tc) * 0.5, 0.06, 0), (L, 0, 1.2)):
            c.root(t, y=base_y + dy, z=z, pitch=pitch, roll=roll, ease=E)
        for side, t0, x0 in (("L", 0.0, -0.95), ("R", L * 0.5, -0.05)):
            zf = (CROUCH_FEET[side]["z"] if crouched else (-0.06 if side == "L" else 0.04))
            yaw = (CROUCH_FEET[side]["yaw"] if crouched else (6 if side == "L" else -6))
            xo = (CROUCH_FEET[side]["x"] if crouched else 0.0)
            keys = [(t0, {"x": x0, "y": 0.0}, "Linear"), (t0 + tc, {"x": x0 + sweep, "y": 0.0}, "CubicInOut"),
                    (t0 + tc + (L - tc) * 0.5, {"x": x0 + sweep * 0.5, "y": lift}, "CubicInOut")]
            cyclic(c, L, keys, lambda t, v, e, side=side, xo=xo, zf=zf, yaw=yaw:
                   foot(c, side, t, x=xo + v["x"], y=v["y"], z=zf, yaw=yaw, pitch=8 * v["y"] / lift, ease=e))
        c.marker("Footstep", 0.0, "L")
        c.marker("Footstep", L * 0.5, "R")
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
    c.gun_at_wrist(f(3), (0.05, 0.62, -0.42), (-55, 60, -25), ease=E)
    c.hand_free("L", f(3), (-0.55, 1.15, -0.55), (60, -20, 30), ease=E)  # off forearm up, shielding the head
    # f20: moving hold
    spine(c, f(20), pitch=-12, yaw=4.5, roll=-3.4, ease="CubicOut")
    head(c, f(21), pitch=-16, yaw=-6, roll=4, ease="CubicOut")
    c.gun_at_wrist(f(20), (0.06, 0.6, -0.44), (-54, 60, -25), ease="CubicOut")
    c.hand_free("L", f(20), (-0.55, 1.12, -0.57), (58, -20, 30), ease="CubicOut")
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
    "CoverShuffleTall": shuffle("CoverShuffleTall", 0.60, False),
    "CoverShuffleCrouch": shuffle("CoverShuffleCrouch", 0.72, True),
    "CoverBrace": brace,
}
MIRROR = {"CoverIdleTall": "CoverIdleTallLeft", "CoverCrouch": "CoverCrouchLeft", "CoverCrouchPeek": "CoverCrouchPeekLeft",
          "CoverShuffleTall": "CoverShuffleTallRight", "CoverShuffleCrouch": "CoverShuffleCrouchRight"}
