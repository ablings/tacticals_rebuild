"""Batch 2: cover actions. Blind fire (tall corner, crouched corner, over low cover), Dash, Sneak, Roll, Vault, DiveAim.
Roblox axes: +x = character right, -z = forward. Root motion is never in a clip (code moves the HRP)."""
from bodyanim import *
from b1_cover import CROUCH_ROOT, CROUCH_FEET, crouch_legs, low_ready, DRIFT

E = "SineInOut"
f = lambda n: n / 60.0


# ---------------------------------------------------------------------------------------------------- blind fire
def blind_corner(name, crouched):
    """Blind fire round a tall edge. The code turns the character to face the edge (CoverController: wantRotation =
    facing along the wall); the wall is on the character's RIGHT here (as the placeholder), so the gun arm reaches past the
    edge and curls right round the corner; the body stays tucked behind it (leaning away), head turned away 10."""
    def build():
        joints = BODY
        c = Clip(name, 1.0, loop=True, priority="Action4", joints=joints)
        for t, s in DRIFT:
            if crouched:
                crouch_legs(c, t, s, pitch=-18)
                spine(c, t, pitch=8 - 0.5 * s, yaw=-6, roll=4, ease=E)
                head(c, t, pitch=6, yaw=10, roll=0, ease=E)
                wrist = (0.95, 0.95, -1.05)
            else:
                c.root(t, x=-0.12, y=-0.06 - 0.012 * s, roll=3 + 0.3 * s, ease=E)
                foot(c, "R", t, x=0.05, z=0.1, yaw=-10, ease=E)
                foot(c, "L", t, x=-0.15, z=-0.1, yaw=10, ease=E)
                spine(c, t, pitch=-2 - 0.5 * s, yaw=-6, roll=5, ease=E)
                head(c, t, pitch=-2, yaw=10, roll=-2, ease=E)
                wrist = (1.05, 1.15, -1.0)
            # gun arm out past the edge, wrist cocked so the barrel points round the corner (yaw -70 = to the right)
            c.gun_at_wrist(t, wrist, (2 + 0.4 * s, -70 - 0.8 * s, 0), ease=E)
            c.free("L", t, 1.0, ease=E)
            c.hand_free("L", t, (-0.35, 0.95 - 0.01 * s, -0.75), (70, -60, 0), ease=E)  # off hand tucked at the chest
        return c
    return build


def blind_over():
    """Blind fire over low cover: the code turns the character to FACE the crate. Crouched behind it, the gun hand up over
    the top (barrel level, a little down), the off hand flat on the top (authored for a 3.0-stud cover top 0.85 ahead of the
    HRP, the stage's lowest low cover); head down behind the cover."""
    c = Clip("CoverBlindOver", 1.0, loop=True, priority="Action4", joints=BODY)
    for t, s in DRIFT:
        c.root(t, x=0.0, y=-1.42 - 0.015 * s, z=0.18, pitch=-14 - 0.5 * s, roll=0.5, ease=E)
        foot(c, "R", t, x=0.2, z=0.25, yaw=-12, ease=E)
        foot(c, "L", t, x=-0.2, z=-0.35, yaw=12, ease=E)
        spine(c, t, pitch=6 - 0.4 * s, ease=E)
        head(c, t, pitch=-6, yaw=-8, ease=E)
        c.gun_at_wrist(t, (0.45, 1.75, -1.15), (-6 + 0.5 * s, 0, 0), ease=E)
        c.free("L", t, 1.0, ease=E)
        c.hand_free("L", t, (-0.55, 1.12, -1.15), (-80, 0, 0), ease=E)
    return c


# ---------------------------------------------------------------------------------------------------- dash / sneak
def run_cycle(name, length, speed, steps, root_y, pitch, lift, contact, bob, priority="Action4", gun=False, spine_p=0.0,
              stride_z=0.0, width=0.0):
    """Forward locomotion cycle at `speed` studs/s with `steps` footfalls per cycle (R first). A planted foot moves back
    under the body at exactly `speed` from 1.5 f before touch-down to 1.5 f after lift. contact = fraction of a step's time
    the foot is planted (1.0 = walk: one foot always down; < 1 = flight)."""
    def build():
        joints = LEGS + ["UpperTorso"]
        c = Clip(name, length, loop=True, priority=priority, joints=joints)
        c.travel = (0.0, -speed)
        L = length
        per = L / steps                  # time between footfalls
        tc = per * contact               # planted time
        sweep = speed * tc
        e1 = 1.5 / 60.0
        # root: lowest 2 f after each touch-down, highest mid-swing; hips yaw toward the stepping leg, roll over the stance leg
        keys = []
        for i in range(steps + 1):
            t0 = i * per
            side = 1 if i % 2 == 0 else -1     # R foot down at even steps
            keys.append((t0, 0.0, side))
        for i in range(steps):
            t0 = i * per
            side = 1 if i % 2 == 0 else -1
            c.root(t0, y=root_y, pitch=pitch, yaw=side * 4, roll=side * 2.5, ease=E)
            c.root(t0 + min(f(3), per * 0.3), y=root_y - bob, pitch=pitch, yaw=side * 3, roll=side * 3, ease=E)
            c.root(t0 + per * 0.7, y=root_y + bob, pitch=pitch, yaw=0, roll=0, ease=E)
            spine(c, t0, pitch=spine_p, yaw=-side * 4, ease=E)
        c.root(L, y=root_y, pitch=pitch, yaw=4, roll=2.5, ease=E)
        spine(c, L, pitch=spine_p, yaw=-4, ease=E)
        for side, first in (("R", 0), ("L", 1)):
            k = []
            for i in range(first, steps, 2):
                t0 = i * per
                x = width if side == "R" else -width
                k += [(t0 - e1, {"z": -sweep / 2 - speed * e1, "y": 0.05, "p": 8}, "Linear"),
                      (t0, {"z": -sweep / 2, "y": 0.0, "p": 0}, "Linear"),
                      (t0 + tc, {"z": sweep / 2, "y": 0.0, "p": 0}, "Linear"),
                      (t0 + tc + e1, {"z": sweep / 2 + speed * e1, "y": 0.07, "p": -25}, "CubicInOut"),
                      (t0 + tc + (2 * per - tc) * 0.45, {"z": stride_z, "y": lift, "p": -10}, "CubicInOut")]
            k = [((t % L) if (t < 0 or t >= L) else t, v, e) for t, v, e in k]
            cyclic(c, L, k, lambda t, v, e, side=side: foot(c, side, t, x=(width if side == "R" else -width), y=v["y"],
                                                          z=v["z"], pitch=v["p"], ease=e))
        for i in range(steps):
            c.marker("Footstep", i * per, "R" if i % 2 == 0 else "L")
        return c
    return build


# ---------------------------------------------------------------------------------------------------- roll
def roll():
    """Tactical forward shoulder roll, played over the distance by AdjustSpeed (code moves the HRP). f0-f4 dip and tuck,
    f4-f20 roll (Linear spin: momentum), Land f20, f20-f30 up to a crouch. The tucked body rolls round a ball centre about
    0.55 above the hips along the spine, kept at a constant height so the back runs along the floor."""
    c = Clip("CoverRoll", 0.5, loop=False, priority="Action4", joints=BODY)
    TUCK = {"R": ((0.05, -0.35, -1.05), (60, 0, 0)), "L": ((-0.05, -0.45, -0.95), (55, 0, 0))}
    STAND = {"R": ((0.0, -1.93, -0.1), (0, 0, 0)), "L": ((0.0, -1.93, 0.15), (0, 0, 0))}
    # (frame, root pitch, ease, feet) ; pitch negative = pitched forward
    beats = [(0, -20, "CubicOut", None), (4, -50, "Linear", TUCK), (8, -130, "Linear", TUCK), (12, -220, "Linear", TUCK),
             (16, -300, "Linear", TUCK), (20, -360, "CubicOut", None), (30, -380, E, None)]
    center = 0.55
    for fr, p, e, ft in beats:
        th = math.radians(-p)  # forward angle
        if fr == 0:
            y, z = -0.55, 0.0
        elif fr >= 20:
            y, z = (-1.45 if fr == 20 else -1.15), 0.15
        else:
            hip_h = 1.25 - center * math.cos(th)
            y, z = hip_h - 2.192, center * math.sin(th) * -1.0 * -1.0
        if ft is None:
            # feet on the floor (planted crouch at the start / landing)
            root_and_feet(c, f(fr), y=y, z=z, pitch=p if fr < 20 else p + 360, ease=e)
            for side in ("R", "L"):
                foot(c, side, f(fr), x=(0.2 if side == "R" else -0.2), z=(-0.45 if side == "R" else 0.3) if fr >= 20 else (-0.2 if side == "R" else 0.2),
                     yaw=0, ease=e)
        else:
            root_and_feet(c, f(fr), y=y, z=z, pitch=p, feet=ft, ease=e)
        tuck = fr not in (0, 30)
        spine(c, f(fr), pitch=(-35 if tuck else -10), ease=e)
        head(c, f(fr), pitch=(-30 if tuck else 0), ease=e)
        c.gun_at_wrist(f(fr), (0.25, 0.55, -0.7) if tuck else (0.2, 0.5, -1.0), (-45, 50, -15), ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), (-0.45, 0.9, -0.7), (70, -60, 0), ease=e)
    c.marker("Land", f(20))
    c.finish()  # easing in place before the clamp evaluates the curves
    ground_clamp(c, [4 * 1, 8, 12, 16])
    return c


# ---------------------------------------------------------------------------------------------------- vault
def vault():
    """One fast speed-vault (played in VaultTime 0.344 s; the code flies the HRP over a Bezier whose top is 1.8 above the
    cover top). f0-f4 reach, f6 EdgeGrab: the off (left) hand plants on the top, f6-f20 the legs swing over to the right
    side, tucked, f22 Land, f22-f33 rise. The gun arm is left to the weapon Hold (aiming / firing works mid-vault)."""
    joints = LEGS + ["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
    c = Clip("CoverVault", 0.55, loop=False, priority="Action4", joints=joints)
    TUCKR = {"R": ((0.9, -0.55, -0.7), (20, -40, 70)), "L": ((0.8, -0.9, -0.5), (20, -40, 70))}
    MIDR = {"R": ((0.45, -1.2, -0.6), (10, -20, 35)), "L": ((0.3, -1.4, -0.3), (10, -20, 35))}
    # f0 take-off crouch (feet planted)
    c.root(f(0), y=-0.45, pitch=-18, ease="CubicOut")
    for side in ("R", "L"):
        foot(c, side, f(0), x=(0.1 if side == "R" else -0.1), z=(-0.15 if side == "R" else 0.2), ease="CubicOut")
    root_and_feet(c, f(4), y=-0.2, pitch=-25, roll=-8, feet=MIDR, ease=E)
    root_and_feet(c, f(6), y=-0.1, pitch=-28, roll=-15, feet=MIDR, ease=E)
    root_and_feet(c, f(12), y=0.05, pitch=-22, roll=-30, feet=TUCKR, ease=E)
    root_and_feet(c, f(17), y=-0.05, pitch=-12, roll=-20, feet=MIDR, ease="QuadIn")
    # land: feet down, compress
    c.root(f(22), y=-0.55, pitch=-14, roll=-4, ease="CubicOut")
    for side in ("R", "L"):
        foot(c, side, f(22), x=(0.15 if side == "R" else -0.15), z=(-0.1 if side == "R" else 0.25), ease="CubicOut")
    c.root(f(33), y=-0.08, pitch=-4, ease=E)
    for side in ("R", "L"):
        foot(c, side, f(33), x=(0.15 if side == "R" else -0.15), z=(-0.1 if side == "R" else 0.25), ease=E)
    for fr, sp, hd in ((0, -10, 0), (4, -18, 10), (6, -20, 14), (12, -15, 12), (17, -8, 6), (22, -10, 4), (33, -3, 0)):
        spine(c, f(fr), pitch=sp, ease=E)
        head(c, f(fr), pitch=hd, ease=E)
    # off hand: reach f0-f4, plant f6 (wrist under the chest, forward), stays on the top while the body passes, releases f14
    c.free("L", 0, 1.0)
    for fr, pos, rot in ((0, (-0.5, 0.9, -0.8), (70, -60, 0)), (4, (-0.55, -0.2, -1.25), (-60, 0, 0)),
                         (6, (-0.5, -0.65, -1.1), (-80, 0, 0)), (10, (-0.45, -0.8, -0.5), (-85, 0, 0)),
                         (14, (-0.5, -0.6, 0.1), (-70, 0, 0)), (22, (-0.8, 0.3, -0.6), (20, 0, 0)), (33, (-0.5, 0.9, -0.8), (70, -60, 0))):
        c.hand_free("L", f(fr), pos, rot, ease=("QuartOut" if fr == 4 else E))
    c.marker("EdgeGrab", f(6))
    c.marker("Land", f(22))
    return c


# ---------------------------------------------------------------------------------------------------- dive aim
def dive_aim():
    """Aiming mid jump-dive. The code pitches the root by DivePitch x 0.25 (about 15 deg) while aiming and turns it to the
    camera; this clip adds the rest of the lunge: hips and legs stretched back and up behind, legs together, knees 20,
    chest counter-pitched so the shoulders and head stay at level aim (arms come from the weapon Hold + procedural aim).
    Authored for that 15 deg root pitch (systems: keep the 0.25 factor while DiveAim plays). Moving hold."""
    c = Clip("CoverDiveAim", 1.0, loop=True, priority="Action4", joints=LEGS + ["UpperTorso", "Head"])
    LEGS_BACK = {"R": ((0.05, -1.55, 1.05), (-55, 0, 0)), "L": ((-0.05, -1.45, 1.2), (-60, 0, 0))}
    for t, s in DRIFT:
        legs = {k: ((v[0][0], v[0][1] + 0.04 * s, v[0][2] + 0.03 * s), v[1]) for k, v in LEGS_BACK.items()}
        root_and_feet(c, t, y=0.15, pitch=-42 - 1.0 * s, feet=legs, ease=E)
        spine(c, t, pitch=26 + 0.6 * s, ease=E)
        head(c, t, pitch=14, ease=E)
    return c


CLIPS = {
    "CoverBlindCorner": blind_corner("CoverBlindCorner", False),
    "CoverBlindCornerCrouch": blind_corner("CoverBlindCornerCrouch", True),
    "CoverBlindOver": blind_over,
    "CoverDash": run_cycle("CoverDash", 0.48, 24.0, 2, -0.75, -22, 0.75, 0.32, 0.07, priority="Action3", spine_p=8, stride_z=0.2, width=0.12),
    "CoverSneak": run_cycle("CoverSneak", 1.2, 8.0, 4, -0.95, -16, 0.28, 1.0, 0.03, priority="Action", spine_p=6, width=0.18),
    "CoverRoll": roll,
    "CoverVault": vault,
    "CoverDiveAim": dive_aim,
}
MIRROR = {"CoverBlindCorner": "CoverBlindCornerLeft", "CoverBlindCornerCrouch": "CoverBlindCornerCrouchLeft",
          "CoverBlindOver": "CoverBlindOverLeft"}
