"""Batch 1: cover core. Character faces OUT from the wall (back to it); +x = its right, -z = forward.
Layering (CoverController): IdleTall / Crouch / CrouchPeek (Action3) + LookPos / LookNeg (Action4, Head + UpperTorso)
+ ShuffleTall / ShuffleCrouch (Action4, legs) + leans (Action4). So the crouch's forward lean lives in the hips
(LowerTorso), the chest stays near upright, and the Look clips own the chest turn + breath."""
from bodyanim import *

E = "SineInOut"
DRIFT = ((0.0, 0), (0.5, 1), (1.0, 0))  # (time, phase 0..1) of a 1 s seamless moving hold


def low_ready(c, t, s=0.0, wrist=(0.3, 0.75, -1.0), ease=E):
    """pistol held low across the body, muzzle down-left (finger off the trigger); the off hand relaxed at the chest, clear
    of the gun (style 8: pistol lowered = off hand free)."""
    c.gun_at_wrist(t, wrist, (-42 - 0.6 * s, 52, -18), ease=ease)
    c.pole("R", t, (1.9, 0.9, -0.6), ease=ease)  # elbow out to the side: the forearm crosses in front of the belly
    c.free("L", t, 1.0, ease=ease)
    c.hand_free("L", t, (-0.42, 0.95 - 0.012 * s, -0.9), (70, -60, 0), ease=ease)


# ---------------------------------------------------------------------------------------------------- tall cover
def idle_tall():
    c = Clip("CoverIdleTall", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        c.root(t, x=0.05, y=-0.035 - 0.012 * s, z=0.15, roll=1.5 + 0.3 * s, ease=E)
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
        sp, hp = ((CROUCH_CHEST, CROUCH_HEAD) if crouched else (0, -2))
        for t, s in DRIFT:
            spine(c, t, pitch=sp - 0.7 * s, yaw=sign * (7 + 0.6 * s), roll=-sign * 1.0, ease=E)
            head(c, t, pitch=hp + 0.5 * s, yaw=sign * (15 + 0.6 * s), roll=0, ease=E)
        return c
    return build


# ---------------------------------------------------------------------------------------------------- low cover
CROUCH_ROOT = dict(x=0.0, y=-1.72, z=0.26)
CROUCH_PITCH = -30
CROUCH_CHEST, CROUCH_HEAD = -18, 25
CROUCH_FEET = {"R": dict(x=0.2, z=-0.6, yaw=-14, pitch=-14), "L": dict(x=-0.2, z=0.2, yaw=12, pitch=-24)}


def crouch_legs(c, t, s=0.0, pitch=-30, ease=E):
    c.root(t, x=CROUCH_ROOT["x"], y=CROUCH_ROOT["y"] - 0.02 * s, z=CROUCH_ROOT["z"], pitch=pitch - 0.6 * s, roll=0.8, ease=ease)
    for side in ("R", "L"):
        foot(c, side, t, ease=ease, **CROUCH_FEET[side])


def crouch():
    c = Clip("CoverCrouch", 1.0, loop=True, priority="Action3", joints=BODY)
    for t, s in DRIFT:
        crouch_legs(c, t, s)
        spine(c, t, pitch=CROUCH_CHEST - 0.6 * s, ease=E)
        head(c, t, pitch=CROUCH_HEAD + 0.4 * s, ease=E)  # counters the hip lean: eyes level, just under the top
        low_ready(c, t, s, wrist=(0.3, 0.85, -1.05))
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
    """side-shuffle toward the character's LEFT (-x) at CoverWalkSpeed 8, step-close in lanes: six quick steps per cycle
    (L, R, L, R, L, R), each contact a sixth of the cycle, so one foot is always planted. Each foot keeps its own lane
    (left foot always left of x -0.5, right foot right of +0.5) so the legs never cross. A planted foot moves under the
    body at exactly 8 studs/s, including the frames either side of touch-down / lift."""
    def build():
        c = Clip(name, length, loop=True, priority="Action4", joints=LEGS)
        c.travel = (-8.0, 0.0)
        L = length
        speed = 8.0
        n = 6
        q = L / n
        sweep = speed * q                 # 0.8 (tall) / 0.96 (crouch)
        e1 = 1.0 / 60.0
        lift = 0.16 if crouched else 0.2
        base_y = CROUCH_ROOT["y"] if crouched else -0.3
        pitch = CROUCH_PITCH if crouched else 0
        z = CROUCH_ROOT["z"] if crouched else 0.15
        for i in range(n):
            t0 = i * q
            sd = 1 if i % 2 == 0 else -1
            c.root(t0, y=base_y, z=z, pitch=pitch, roll=sd * 0.8, ease=E)
            c.root(t0 + q * 0.5, y=base_y + (0.02 if crouched else 0.05), z=z, pitch=pitch, roll=0, ease=E)
        c.root(L, y=base_y, z=z, pitch=pitch, roll=0.8, ease=E)
        for side, starts in (("L", [i * q for i in range(0, n, 2)]), ("R", [i * q for i in range(1, n, 2)])):
            yaw = (CROUCH_FEET[side]["yaw"] if crouched else 0)
            dz = (CROUCH_FEET[side]["z"] if crouched else (-0.08 if side == "L" else 0.08))
            # lane: the planted foot travels +x from its outer edge to its inner edge (x relative to its rest ankle)
            x_in = (-0.05 if side == "L" else sweep + 0.05) + (CROUCH_FEET[side]["x"] if crouched else 0.0)
            x_out = x_in - sweep
            keys = []
            for t0 in starts:
                keys += [(t0 - e1, {"x": x_out - speed * e1, "y": 0.1}, "Linear"),
                         (t0, {"x": x_out, "y": 0.0}, "Linear"),
                         (t0 + q, {"x": x_in, "y": 0.0}, "Linear"),
                         (t0 + q + e1, {"x": x_in + speed * e1 * 0.5, "y": 0.11}, "CubicInOut"),
                         (t0 + q + (q - 2 * e1) * 0.5 + e1, {"x": (x_in + x_out) / 2, "y": lift}, "CubicInOut")]
            keys = [((t % L) if (t < 0 or t >= L) else t, v, e) for t, v, e in keys]
            cyclic(c, L, keys, lambda t, v, e, side=side, yaw=yaw, dz=dz:
                   foot(c, side, t, x=v["x"], y=v["y"], z=dz, yaw=yaw, pitch=8 * v["y"] / lift, ease=e))
        for i in range(n):
            c.marker("Footstep", i * q, "L" if i % 2 == 0 else "R")
        return c
    return build


# ---------------------------------------------------------------------------------------------------- brace
def brace(name="CoverBrace", crouched=False):
    """near miss: tuck in 3 f (Quart Out), moving hold, back by 0.75. Upper body only. Starts and ends on its stance's own
    chest / head / arm values (CoverBraceCrouch for low cover: the crouch chest -18 / head +25 under the flinch), so it
    never pops the base pose."""
    def build():
        c = Clip(name, 0.75, loop=False, priority="Action4", joints=["UpperTorso", "Head"] + ARMS)
        f = lambda n: n / 60.0
        sp0, hd0 = (CROUCH_CHEST, CROUCH_HEAD) if crouched else (0, -3)
        wr = (0.3, 0.85, -1.05) if crouched else (0.3, 0.75, -1.0)
        spine(c, 0, pitch=sp0, ease="QuartOut")
        head(c, 0, pitch=hd0, ease="QuartOut")
        low_ready(c, 0, 0, wrist=wr, ease="QuartOut")
        spine(c, f(3), pitch=sp0 - 11, yaw=4, roll=-3, ease=E)
        head(c, f(4), pitch=hd0 - 12, yaw=-6, roll=4, ease=E)
        c.gun_at_wrist(f(3), (wr[0], wr[1] - 0.15, wr[2] + 0.05), (-50, 60, -25), ease=E)
        c.pole("R", f(3), (1.9, 0.6, -0.4), ease=E)
        c.hand_free("L", f(3), (-0.75, 1.3, -0.75), (60, -20, 30), ease=E)  # off forearm up, shielding the head
        spine(c, f(20), pitch=sp0 - 12, yaw=4.5, roll=-3.4, ease="CubicOut")
        head(c, f(21), pitch=hd0 - 13, yaw=-6, roll=4, ease="CubicOut")
        c.gun_at_wrist(f(20), (wr[0] + 0.01, wr[1] - 0.15, wr[2] + 0.03), (-49, 60, -25), ease="CubicOut")
        c.pole("R", f(20), (1.9, 0.6, -0.4), ease="CubicOut")
        c.hand_free("L", f(20), (-0.75, 1.27, -0.77), (58, -20, 30), ease="CubicOut")
        spine(c, f(45), pitch=sp0, ease=E)
        head(c, f(45), pitch=hd0, ease=E)
        low_ready(c, f(45), 0, wrist=wr)
        c.free("L", 0, 1.0)
        return c
    return build


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
    "CoverBrace": brace("CoverBrace", False),
    "CoverBraceCrouch": brace("CoverBraceCrouch", True),
}
MIRROR = {"CoverIdleTall": "CoverIdleTallLeft", "CoverCrouch": "CoverCrouchLeft", "CoverCrouchPeek": "CoverCrouchPeekLeft",
          "CoverShuffleTall": "CoverShuffleTallRight", "CoverShuffleCrouch": "CoverShuffleCrouchRight"}
