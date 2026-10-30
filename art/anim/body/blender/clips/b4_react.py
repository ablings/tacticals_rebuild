"""Batch 4: locomotion transitions + hit reactions (targets sections 10 and 11).
Reactions own only UpperTorso + Head (+ arms where noted) so they layer over standing, crouched and cover poses without
moving the hips (a reaction that keys LowerTorso stands a crouched player up)."""
from bodyanim import *

E = "SineInOut"
f = lambda n: n / 60.0
REACT = ["UpperTorso", "Head"]


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


# ---------------------------------------------------------------------------------------------------- start / stop
def move_start():
    """from standing into the run, authored against the HRP really accelerating (0 -> 10 studs/s over 0.15 s, the
    humanoid's ramp): the hips lead (f0-f4), the planted left foot sweeps back at the root's speed, the right foot lifts f4
    and lands f8 a stride ahead (Footstep f8) and is then planted, sweeping back too; the left foot peels and swings at f11.
    Ends in MoveRun's phase at f7 (right foot just after contact): start MoveRun at TimePosition 0.12."""
    c = Clip("MoveStart", 0.25, loop=False, priority="Movement", joints=LEGS + ["UpperTorso"])
    c.travel = (0.0, 0.0)
    def d(t):  # studs the HRP has moved forward by clip time t
        a = 10.0 / 0.15
        return 0.5 * a * t * t if t <= 0.15 else 0.5 * a * 0.15 ** 2 + 10.0 * (t - 0.15)
    for fr, z, p, sp in ((0, 0.0, 0, 0), (4, -0.08, -6, -2), (8, -0.1, -7, -3), (15, -0.1, -6, -3)):
        c.root(f(fr), y=(-0.22 if fr else -0.04), z=z, pitch=p, ease=("CubicOut" if fr == 0 else E))
        spine(c, f(fr), pitch=sp, ease=E)
    # left foot planted from f0 to f11 (moves back against the travel), then peels and swings
    for fr in range(0, 10):
        foot(c, "L", f(fr), z=0.12 + d(f(fr)), yaw=8, ease="Linear")
    foot(c, "L", f(11), z=0.12 + d(f(9)) + 0.05, y=0.14, pitch=-22, ease="CubicInOut")
    foot(c, "L", f(15), z=0.6, y=0.35, pitch=-12, ease=E)
    # right foot: lifts f4, lands f8 ahead, then planted
    for fr in range(0, 4):
        foot(c, "R", f(fr), x=0.08, z=d(f(fr)), yaw=-8, ease="Linear")
    foot(c, "R", f(6), x=0.05, y=0.3, z=-0.3, pitch=-5, ease="QuadIn")
    land = -0.72
    for fr in range(8, 16):
        foot(c, "R", f(fr), x=0.05, z=land + (d(f(fr)) - d(f(8))), ease="Linear")
    c.marker("Footstep", f(8), "R")
    return c


def move_stop():
    """plant and settle: right foot down ahead at f0 (Footstep), the body carries 3% past over it (f0-f6 Cubic Out), the
    trail (left) foot comes up beside it f6-f10 (Footstep f10), f10-f21 settle to stance."""
    c = Clip("MoveStop", 0.35, loop=False, priority="Movement", joints=LEGS + ["UpperTorso"])
    for fr, y, z, p, sp, e in ((0, -0.25, 0.25, -6, -3, "CubicOut"), (6, -0.3, 0.12, -9, -4, "CubicOut"),
                               (10, -0.2, 0.06, -4, -2, "CubicOut"), (21, -0.05, 0.0, 0, 0, E)):
        c.root(f(fr), y=y, z=z, pitch=p, ease=e)
        spine(c, f(fr), pitch=sp, ease=e)
    foot(c, "R", f(0), z=-0.35, ease=E)
    foot(c, "R", f(10), z=-0.35, ease=E)
    foot(c, "R", f(13), x=0.04, y=0.08, z=-0.15, ease="CubicInOut")
    foot(c, "R", f(16), x=0.08, z=0.0, yaw=-8, ease="Linear")
    foot(c, "R", f(21), x=0.08, z=0.0, yaw=-8, ease=E)
    foot(c, "L", f(0), z=0.6, pitch=-15, y=0.05, ease="CubicInOut")
    foot(c, "L", f(6), z=0.55, y=0.08, pitch=-20, ease="CubicInOut")
    foot(c, "L", f(8), z=0.2, y=0.18, pitch=-5, ease="QuadIn")
    foot(c, "L", f(10), x=-0.08, z=0.12, yaw=8, ease="Linear")
    foot(c, "L", f(21), x=-0.08, z=0.12, yaw=8, ease=E)
    c.marker("Footstep", 0.0, "R")
    c.marker("Footstep", f(10), "L")
    return c


# ---------------------------------------------------------------------------------------------------- turn in place
def turn(name, sign):
    """90 deg turn in place (sign +1 = left). The code turns the root f4-f20 (Cubic InOut); in the clip the planted feet
    counter-rotate so they hold still in the world until they step: inside foot lifts f6, plants f14; outside foot f14-f24.
    Head leads (f0-f4 Cubic Out), chest follows 2 f behind, hips follow the root. Feet step, never spin."""
    def build():
        c = Clip(name, 0.5, loop=False, priority="Movement", joints=LEGS + ["UpperTorso", "Head"])
        A = 90.0 * sign
        def cubic_io(u):
            u = max(0.0, min(1.0, u))
            return 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2
        root_a = lambda fr: A * cubic_io((fr - 4) / 16.0)          # the code turns the HRP: Cubic InOut, f4-f20
        inside, outside = ("L", "R") if sign > 0 else ("R", "L")

        def foot_world(side, fr, world_yaw):
            """foot at its rest spot rotated by world_yaw about the HRP, expressed in the root's (turned) frame."""
            rel = math.radians(world_yaw - root_a(fr))
            wide = 1.0 + 0.6 * (abs(world_yaw) / abs(A) if side == inside else 0.0)  # the inside foot lands 0.3 wider
            ax, az = ANKLE[side][0] * wide, 0.0
            x = ax * math.cos(rel) + az * math.sin(rel)
            z = -ax * math.sin(rel) + az * math.cos(rel)
            return x - ANKLE[side][0], z, world_yaw - root_a(fr)
        frames = list(range(0, 31, 2))
        for fr in frames:
            # foot world yaw: 0 until it steps, then A (the inside foot f6-f14, the outside foot f14-f24)
            for side, a0, a1 in ((inside, 6, 14), (outside, 14, 24)):
                u = smooth((fr - a0) / float(a1 - a0))
                wy = A * u
                x, z, yaw = foot_world(side, fr, wy)
                lift = 0.22 * math.sin(math.pi * max(0.0, min(1.0, (fr - a0) / float(a1 - a0))))
                foot(c, side, f(fr), x=x, z=z, y=lift, yaw=yaw, pitch=(-8 if lift > 0.02 else 0), ease="Linear")
            # body: hips = root (counter nothing); chest leads by 2 f, head by 4 f (relative to the root's turn)
            lead_chest = root_a(fr + 2) - root_a(fr)
            lead_head = root_a(fr + 5) - root_a(fr + 2)
            if fr <= 4:
                lead_head = A * 0.28 * smooth(fr / 4.0)
                lead_chest = A * 0.08 * smooth(fr / 4.0)
            c.root(f(fr), y=-0.08 - 0.04 * math.sin(math.pi * min(1, fr / 24.0)), yaw=0, roll=-sign * 2 * math.sin(math.pi * min(1, fr / 24.0)), ease="Linear")
            spine(c, f(fr), yaw=lead_chest, ease="Linear")
            head(c, f(fr), yaw=min(abs(lead_head), 15) * sign, ease="Linear")
        c.marker("Footstep", f(14), inside)
        c.marker("Footstep", f(24), outside)
        return c
    return build


# ---------------------------------------------------------------------------------------------------- hard landing
def land_hard():
    """big fall: f0 contact (arrive at full speed), f0-f4 Quart Out compress (knees deep, hips -0.8, chest +15 forward),
    f4-f8 hold, f8-f22 Cubic InOut rise, f22-f27 settle. Land marker f0. Cancellable into movement from f10."""
    c = Clip("MoveLandHard", 0.45, loop=False, priority="Action", joints=LEGS + ["UpperTorso", "Head"])
    for fr, y, p, sp, hd, e in ((0, -0.15, -4, -3, 0, "QuartOut"), (4, -0.85, -16, -12, 10, E), (8, -0.8, -15, -11, 9, "CubicInOut"),
                                (22, -0.06, -2, -1, 0, "CubicOut"), (27, -0.04, -1, 0, 0, E)):
        c.root(f(fr), y=y, pitch=p, ease=e)
        spine(c, f(fr), pitch=sp, ease=e)
        head(c, f(fr), pitch=hd, ease=e)
    for side, x, z in (("R", 0.08, 0.0), ("L", -0.08, 0.12)):  # lands in the idle stance
        foot(c, side, f(0), x=x, z=z, yaw=(-8 if side == "R" else 8), ease=E)
        foot(c, side, f(27), x=x, z=z, yaw=(-8 if side == "R" else 8), ease=E)
    c.marker("Land", 0.0)
    return c


# ---------------------------------------------------------------------------------------------------- limp
def limp():
    """low-health limp, injured LEFT leg: the good (right) foot is planted long (f0-f30), the injured foot only briefly
    (f28-f37) while the hips drop on that side and the chest leans over the good leg. Authored at 4 studs/s (code:
    AdjustSpeed(speed / 4)); planted feet move at exactly that speed."""
    L = 0.84
    speed = 4.0
    c = Clip("MoveLimp", L, loop=True, priority="Movement", joints=LEGS + ["UpperTorso", "Head"])
    c.travel = (0.0, -speed)
    plan = {"R": (0.0, 0.5, 0.2), "L": (0.467, 0.84, 0.12)}   # touch-down, lift, swing height
    for side, (td, lo, lift) in plan.items():
        tc = lo - td
        sweep = speed * tc
        e1 = 1.0 / 60
        keys = [(td - e1, {"z": -sweep / 2 - speed * e1, "y": 0.1, "p": 0}, "Linear"),
                (td, {"z": -sweep / 2, "y": 0.0, "p": 0}, "Linear"),
                (lo, {"z": sweep / 2, "y": 0.0, "p": 0}, "Linear"),
                (lo + e1, {"z": sweep / 2 + speed * e1, "y": 0.12, "p": -15}, "CubicInOut"),
                (lo + (L - tc) * 0.5, {"z": 0.0, "y": lift, "p": -6}, "CubicInOut")]
        keys = [((t % L) if (t < 0 or t >= L) else t, v, e) for t, v, e in keys]
        x = 0.1 if side == "R" else -0.06
        cyclic(c, L, keys, lambda t, v, e, side=side, x=x: foot(c, side, t, x=x, y=v["y"], z=v["z"], pitch=v["p"], ease=e))
    # body: over the good leg most of the cycle; drops and dips toward the injured side when it takes weight
    for t, y, roll, sp, sroll, hd in ((0, -0.3, 2, -5, -4, 3), (0.25, -0.26, 3, -5, -5, 3), (0.467, -0.32, -1, -6, -2, 2),
                                      (0.52, -0.42, -5, -9, 3, 6), (0.65, -0.38, -3, -7, 1, 4), (L, -0.3, 2, -5, -4, 3)):
        c.root(t, y=y, roll=roll, pitch=-4, ease=E)
        spine(c, t, pitch=sp, roll=sroll, ease=E)
        head(c, t, pitch=hd, roll=-sroll * 0.5, ease=E)
    c.marker("Footstep", 0.0, "R")
    c.marker("Footstep", 0.467, "L")
    return c


# ---------------------------------------------------------------------------------------------------- hit reactions
def flinch(name, chest, headr, length=0.30):
    """f0 = rest, f2 peak (Linear in: the hit arrives at full speed), head lags 1 f, f2-f18 Cubic Out back."""
    def build():
        c = Clip(name, length, loop=False, priority="Action4", joints=REACT)
        spine(c, 0, ease="Linear")
        head(c, 0, ease="Linear")
        spine(c, f(2), *chest, ease="CubicOut")
        head(c, f(3), *headr, ease="CubicOut")
        spine(c, f(18), ease=E)
        head(c, f(19), ease=E)
        spine(c, length, ease=E)
        head(c, length, ease=E)
        return c
    return build


def headshot():
    c = Clip("HitHeadshot", 0.25, loop=False, priority="Action4", joints=REACT)
    spine(c, 0, ease="Linear"); head(c, 0, ease="Linear")
    head(c, f(1), pitch=18, roll=3, ease="QuintOut")
    spine(c, f(2), pitch=6, ease="QuintOut")
    head(c, f(15), ease=E); spine(c, f(15), ease=E)
    head(c, 0.25, ease=E); spine(c, 0.25, ease=E)
    return c


def explosion():
    """thrown by a blast in front: f0-f3 Linear thrown back (chest 15, hips back), the right foot steps back (lifts f3,
    plants f14), recovers forward and steps back in place (f30-f44), settles by f54. In place: the code turns the root to the
    blast side and doesn't move it. Owns hips + legs (a stagger stands a crouched player up on purpose)."""
    c = Clip("HitExplosionStagger", 0.9, loop=False, priority="Action4", joints=LEGS + REACT)
    for fr, z, y, p, sp, hd, e in ((0, 0, -0.04, 0, 0, 0, "Linear"), (3, 0.25, -0.1, 10, 12, 8, "CubicOut"),
                                   (14, 0.32, -0.3, 6, 8, 5, "CubicOut"), (30, 0.12, -0.2, -2, 2, 1, "CubicInOut"),
                                   (44, 0.0, -0.1, -1, 0, 0, "CubicOut"), (54, 0.0, -0.05, 0, 0, 0, E)):
        c.root(f(fr), z=z, y=y, pitch=p, roll=(3 if 3 <= fr <= 30 else 0), ease=e)
        spine(c, f(fr), pitch=sp, ease=e)
        head(c, f(fr + (1 if fr else 0)), pitch=hd, ease=e)
    foot(c, "L", 0, ease=E); foot(c, "L", f(54), ease=E)
    for fr, z, y, p, e in ((0, 0, 0, 0, "Linear"), (3, 0, 0.02, 0, "CubicOut"), (8, 0.45, 0.25, -10, "QuadIn"),
                           (14, 0.75, 0, 0, "Linear"), (30, 0.75, 0, 0, "CubicInOut"), (37, 0.35, 0.2, -6, "QuadIn"),
                           (44, 0.0, 0, 0, E), (54, 0.0, 0, 0, E)):
        foot(c, "R", f(fr), z=z, y=y, pitch=p, ease=e)
    c.marker("Footstep", f(14), "R")
    c.marker("Footstep", f(44), "R")
    return c


def burning():
    """on fire: shoulders hunched, head turned away, the off hand swats the left shoulder twice per loop (f10-f16,
    f46-f52 Cubic Out), gun arm left to the Hold. Moving hold between."""
    L = 1.2
    c = Clip("HitBurning", L, loop=True, priority="Action4", joints=REACT + ["LeftUpperArm", "LeftLowerArm", "LeftHand"])
    c.free("L", 0, 1.0)
    for fr, sp, hd in ((0, -8, -6), (36, -9, -7), (72, -8, -6)):
        spine(c, f(fr), pitch=sp, yaw=6, roll=3, ease=E)
        head(c, f(fr), pitch=hd, yaw=-14, roll=4, ease=E)
    rest = ((-1.05, 0.35, -0.6), (40, -20, 10))
    swat = ((-1.15, -0.55, -0.35), (-10, 0, 15))   # slaps at the burning trouser leg
    for fr, (pos, rot), e in ((0, rest, E), (8, rest, "CubicOut"), (12, swat, "CubicOut"), (16, rest, E), (44, rest, "CubicOut"),
                              (48, swat, "CubicOut"), (52, rest, E), (72, rest, E)):
        c.hand_free("L", f(fr), pos, rot, ease=e)
    return c


CLIPS = {
    "MoveStart": move_start,
    "MoveStop": move_stop,
    "TurnInPlaceLeft": turn("TurnInPlaceLeft", +1),
    "TurnInPlaceRight": turn("TurnInPlaceRight", -1),
    "MoveLandHard": land_hard,
    "MoveLimp": limp,
    "HitFlinch": flinch("HitFlinch", (6, 0, 0), (4, 0, 0)),
    "HitFlinchF": flinch("HitFlinchF", (6, 0, 0), (4, 0, 0)),
    "HitFlinchB": flinch("HitFlinchB", (-5, 0, 0), (-4, 0, 0)),
    "HitFlinchL": flinch("HitFlinchL", (0, -8, -6), (0, -4, -3)),
    "HitFlinchR": flinch("HitFlinchR", (0, 8, 6), (0, 4, 3)),
    "HitHeadshot": headshot,
    "HitExplosionStagger": explosion,
    "HitBurning": burning,
}
MIRROR = {}
