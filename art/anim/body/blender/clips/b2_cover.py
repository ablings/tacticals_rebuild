"""Batch 2: cover actions. Blind fire (tall corner, crouched corner, over low cover), Dash, Sneak, Roll, Vault, DiveAim.
Roblox axes: +x = character right, -z = forward. Root motion is never in a clip (code moves the HRP)."""
from bodyanim import *
from b1_cover import CROUCH_ROOT, CROUCH_FEET, crouch_legs, low_ready, DRIFT

E = "SineInOut"
f = lambda n: n / 60.0


# ---------------------------------------------------------------------------------------------------- blind fire
def blind_corner(name, crouched):
    """Blind fire round a tall edge. CoverController faces the character along the wall toward the edge; for the
    right-handed clip the wall is on the character's LEFT (worked out from the code's facing / shoulder maths). Stage
    geometry: wall face at x -0.85 (WallOffset), the edge 1.25 ahead (EdgeMargin), so the corner is at (-0.85, -1.25).
    The gun hand reaches past the corner and the barrel turns left round it (muzzle >= 0.2 past the edge); the body shifts
    right, away from the wall, and stays behind it; the off (wall-side) arm tucks in front of the chest."""
    def build():
        c = Clip(name, 1.0, loop=True, priority="Action4", joints=BODY)
        c.obstacle = ((-2.85, 0.0, -1.25), (-0.85, 8.0, 6.0), None)  # the wall on the left, ending 1.25 ahead
        c.free("L", 0, 1.0)
        for t, s in DRIFT:
            if crouched:
                c.root(t, x=0.95, y=CROUCH_ROOT["y"] - 0.01 * s, z=CROUCH_ROOT["z"], pitch=-18, yaw=30, roll=0.8, ease=E)
                foot(c, "R", t, x=1.1, z=-0.35, yaw=16, ease=E)
                foot(c, "L", t, x=0.55, z=0.2, yaw=42, ease=E)
                spine(c, t, pitch=8 - 0.3 * s, yaw=22, roll=-4, ease=E)
                head(c, t, pitch=8, yaw=-10, ease=E)
            else:
                c.root(t, x=0.95, y=-0.13 - 0.012 * s, yaw=30, roll=-2 - 0.3 * s, ease=E)
                foot(c, "R", t, x=0.95, z=0.25, yaw=24, ease=E)
                foot(c, "L", t, x=0.82, z=-0.3, yaw=36, ease=E)
                spine(c, t, pitch=-1 - 0.4 * s, yaw=22, roll=-4, ease=E)
                head(c, t, pitch=-2, yaw=-10, ease=E)
        c.finish()
        for t, s in DRIFT:
            wy = (2.75 if crouched else 3.95) + 0.01 * s
            gun_world(c, t, (0.4, wy, -1.75), (1 + 0.4 * s, 80 + 0.6 * s, 0), ease=E)
            hand_world(c, "L", t, (0.95, wy - 0.55, -1.25), (70, -40, 0), ease=E)
        c._finished = False
        return c
    return build


def blind_over():
    """Blind fire over low cover: the code turns the character to FACE the crate (face 0.85 ahead, top 3.0 on the stage,
    3.4 in the arena). Crouched low behind it, torso leaned left so the head stays low, the gun hand up over the top (wrist
    3.45, barrel level, muzzle well past the face), the off hand's palm flat on the top 1.0 ahead."""
    c = Clip("CoverBlindOver", 1.0, loop=True, priority="Action4", joints=BODY)
    c.obstacle = ((-4.0, 0.0, -2.85), (4.0, 3.4, -0.85), None)
    c.free("L", 0, 1.0)
    for t, s in DRIFT:
        c.root(t, x=0.1, y=-1.4 - 0.012 * s, z=0.4, pitch=-4 - 0.3 * s, roll=4, ease=E)
        foot(c, "R", t, x=0.25, z=0.3, yaw=-12, ease=E)
        foot(c, "L", t, x=-0.3, z=0.05, yaw=12, ease=E)
        spine(c, t, pitch=-6 - 0.3 * s, yaw=-4, roll=4, ease=E)
        head(c, t, pitch=-22, yaw=12, roll=4, ease=E)
    c.finish()
    for t, s in DRIFT:
        gun_world(c, t, (0.6, 3.85 + 0.01 * s, -1.05), (-4 + 0.4 * s, 0, 0), ease=E)
        hand_world(c, "L", t, (-1.0, 3.78, -1.2), (-80, 20, 0), ease=E)
    c._finished = False
    return c


# ---------------------------------------------------------------------------------------------------- dash / sneak
def run_cycle(name, length, speed, steps, root_y, pitch, lift, contact, bob, priority="Action4", gun=False, spine_p=0.0,
              stride_z=0.0, width=0.0, plant_p=0.0):
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
                k += [(t0 - e1, {"z": -sweep / 2 - speed * e1, "y": 0.1, "p": 8}, "Linear"),
                      (t0, {"z": -sweep / 2, "y": 0.0, "p": plant_p}, "Linear"),
                      (t0 + tc, {"z": sweep / 2, "y": 0.0, "p": plant_p}, "Linear"),
                      (t0 + tc + e1, {"z": sweep / 2 + speed * e1, "y": 0.13, "p": -25}, "CubicInOut"),
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
            root_and_feet(c, f(fr), y=y, z=z, pitch=p, roll=(50 if 6 <= fr <= 16 else 22), yaw=(-18 if 6 <= fr <= 16 else -8), feet=ft, ease=e)
        tuck = fr not in (0, 30)
        spine(c, f(fr), pitch=(-35 if tuck else -10), ease=e)
        head(c, f(fr), pitch=(-35 if tuck else 0), yaw=(-15 if tuck else 0), roll=(-28 if tuck else 0), ease=e)  # tucked aside: the right shoulder and the back take the floor
        c.gun_at_wrist(f(fr), (0.25, 0.55, -0.7) if tuck else (0.2, 0.5, -1.0), (-45, 50, -15), ease=e)
        c.free("L", f(fr), 1.0, ease=e)
        c.hand_free("L", f(fr), (-0.45, 0.9, -0.7), (70, -60, 0), ease=e)
    c.marker("Land", f(20))
    c.finish()  # easing in place before the clamp evaluates the curves
    clamp_exact(c, 30, both=True)
    return c


# ---------------------------------------------------------------------------------------------------- vault
VAULT_TOP, VAULT_DEPTH, VAULT_OFF = 3.0, 2.0, 0.85


def vault_path(fr, L=0.55):
    """the code's HRP path (startVault + updateMovement): quadratic Bezier from the start, through `over` (top + 1.8,
    middle of the crate) to the landing (WallOffset + 0.4 past the far face), alpha = clip time / length (played in
    VaultTime). Returns (dy, dz) of the HRP from its start, for a 3.0 top, 2.0-deep crate, start 0.85 from the face."""
    a = min(1.0, max(0.0, fr / 60.0 / L))
    y0 = 3.19
    over_y, over_z = VAULT_TOP + 1.8, -(VAULT_OFF + VAULT_DEPTH / 2)
    land_z = -(VAULT_OFF + VAULT_DEPTH + VAULT_OFF + 0.4)
    cy, cz = 2 * over_y - y0, 2 * over_z - land_z / 2
    y = (1 - a) ** 2 * y0 + 2 * a * (1 - a) * cy + a * a * y0
    z = 2 * a * (1 - a) * cz + a * a * land_z
    return y - y0, z


def vault():
    """One fast speed-vault on the code's real path (VaultTime 0.344 s: the clip's 0.55 s map to alpha 0..1). f0-f4 reach,
    EdgeGrab f6: the off (left) hand plants on the top and stays still in the world to f14 while the body passes over it;
    the legs tuck up and swing to the right, every part box above the crate (checked against the path); f22-f31 the legs
    reach down; Land f32 at the code's touchdown (alpha ~0.97); f33 light crouch. Gun arm left to the weapon Hold."""
    joints = LEGS + ["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
    c = Clip("CoverVault", 0.55, loop=False, priority="Action4", joints=joints)
    c.obstacle = ((-4.0, 0.0, -(VAULT_OFF + VAULT_DEPTH)), (4.0, VAULT_TOP, -VAULT_OFF), vault_path)
    TUCK = {"R": ((1.15, -0.2, -0.1), (30, -50, 75)), "L": ((1.0, -0.2, 0.15), (30, -50, 75))}
    BACK = {"R": ((0.45, -0.75, 0.95), (-45, -15, 20)), "L": ((0.3, -0.85, 1.05), (-45, -15, 20))}
    HALF = {"R": ((0.75, -0.55, -0.5), (20, -25, 40)), "L": ((0.75, -0.5, -0.25), (20, -25, 40))}
    REACH = {"R": ((0.15, -1.6, -0.35), (10, -5, 10)), "L": ((0.0, -1.7, 0.1), (5, -5, 10))}
    c.root(f(0), y=-0.12, z=0.2, pitch=-8, ease="CubicOut")
    for side in ("R", "L"):
        foot(c, side, f(0), x=(0.1 if side == "R" else -0.1), z=(0.15 if side == "R" else 0.35), ease="CubicOut")
    root_and_feet(c, f(3), y=-0.15, z=0.15, pitch=-14, roll=0, feet=BACK, ease=E)
    root_and_feet(c, f(6), y=-0.12, z=0.1, pitch=-18, roll=0, feet=BACK, ease=E)
    root_and_feet(c, f(9), y=-0.1, pitch=-22, roll=14, feet=TUCK, ease=E)
    root_and_feet(c, f(14), y=-0.1, pitch=-22, roll=34, feet=TUCK, ease=E)
    root_and_feet(c, f(23), y=-0.1, pitch=-16, roll=30, feet=TUCK, ease=E)
    root_and_feet(c, f(27), y=-0.15, pitch=-12, roll=18, feet=HALF, ease=E)
    root_and_feet(c, f(30), y=-0.25, pitch=-8, roll=6, feet=REACH, ease="QuadIn")
    c.root(f(32), y=-0.45, pitch=-10, roll=-2, ease="CubicOut")
    c.root(f(33), y=-0.5, pitch=-10, roll=-2, ease=E)
    for fr in (32, 33):
        dy, dz = vault_path(fr)
        for side in ("R", "L"):  # planted on the landing floor (world y 0 => clip y -dy)
            foot(c, side, f(fr), x=(0.15 if side == "R" else -0.15), y=-dy, z=(-0.1 if side == "R" else 0.25), ease=E)
    for fr, sp, hd in ((0, -10, 0), (3, -18, 10), (7, -20, 14), (14, -16, 12), (21, -12, 8), (26, -8, 5), (30, -6, 3), (33, -8, 2)):
        spine(c, f(fr), pitch=sp, ease=E)
        head(c, f(fr), pitch=hd, ease=E)
    c.free("L", 0, 1.0)
    c.finish()
    plant_w = (-0.55, VAULT_TOP + 0.45, -(VAULT_OFF + 0.5))
    for fr, kind, e in ((0, "rest", "CubicOut"), (4, "reach", "QuartOut"), (6, "plant", "Linear"), (10, "plant", "Linear"),
                        (14, "plant", "CubicOut"), (22, "up", E), (33, "rest", E)):
        dy, dz = vault_path(fr)
        if kind == "plant":
            hand_world(c, "L", f(fr), (plant_w[0], plant_w[1] - dy, plant_w[2] - dz), (-90, 0, 0), ease=e)
        elif kind == "reach":
            hand_world(c, "L", f(fr), (plant_w[0], plant_w[1] - dy + 0.25, plant_w[2] - dz + 0.15), (-70, 0, 0), ease=e)
        elif kind == "up":
            c.hand_free("L", f(fr), (-0.9, 0.5, -0.4), (20, 0, 0), ease=e)
        else:
            c.hand_free("L", f(fr), (-0.5, 0.95, -0.45), (70, -60, 0), ease=e)
    c._finished = False
    c.marker("EdgeGrab", f(6))
    c.marker("Land", f(33))
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
        root_and_feet(c, t, y=0.1, pitch=-22 - 0.5 * s, feet=legs, ease=E)
        spine(c, t, pitch=12 + 0.5 * s, ease=E)
        head(c, t, pitch=14, ease=E)
    return c


CLIPS = {
    "CoverBlindCorner": blind_corner("CoverBlindCorner", False),
    "CoverBlindCornerCrouch": blind_corner("CoverBlindCornerCrouch", True),
    "CoverBlindOver": blind_over,
    "CoverDash": run_cycle("CoverDash", 0.48, 24.0, 2, -0.8, -22, 0.75, 0.2, 0.07, priority="Action3", spine_p=8, stride_z=0.2, width=0.12, plant_p=-12),
    "CoverSneak": run_cycle("CoverSneak", 1.2, 8.0, 4, -0.95, -16, 0.28, 1.0, 0.03, priority="Action", spine_p=6, width=0.18, plant_p=-16),
    "CoverRoll": roll,
    "CoverVault": vault,
    "CoverDiveAim": dive_aim,
}
MIRROR = {"CoverBlindCorner": "CoverBlindCornerLeft", "CoverBlindCornerCrouch": "CoverBlindCornerCrouchLeft",
          "CoverBlindOver": "CoverBlindOverLeft"}
