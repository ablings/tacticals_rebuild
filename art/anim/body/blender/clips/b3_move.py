"""Batch 3: locomotion with a gun (targets section 10). Legs + hips (+ chest counter-rotation) so the weapon Hold keeps the
arms, except the sprints, which key the arms (gun low and canted). All directional cycles share length 0.70 and phase
(R contact f0, L contact at half) so 8-way blending stays in step. Code plays them at speed / authored speed."""
from bodyanim import *
from b1_cover import DRIFT

E = "SineInOut"
f = lambda n: n / 60.0


def cycle(name, length, speed, heading, steps, root_y, pitch, lift, contact, bob, priority="Movement", spine_p=0.0,
          width=0.0, depth=None, hip_yaw=4.0, hip_roll=2.5, counter=True, joints=None, arms=None, foot_yaw=0.0,
          heel=0.0, plant_p=0.0):
    """A stepping cycle travelling at `speed` toward `heading` (deg, 0 = forward, +90 = the character's left). R foot down
    at even steps. A planted foot moves under the body at exactly `speed` from 1.5 f before touch-down to 1.5 f after lift.
    depth = {"R": dz, "L": dz} stagger for side steps (feet pass in front of / behind each other, never through).
    arms(c, t, phase) keys the arms when the clip owns them. heel: toe-up degrees at contact (heel strike)."""
    def build():
        js = joints or (LEGS + ["UpperTorso"])
        c = Clip(name, length, loop=True, priority=priority, joints=js)
        h = math.radians(heading)
        dx, dz = -math.sin(h), -math.cos(h)          # travel direction (Roblox x, z)
        c.travel = (dx * speed, dz * speed)
        L = length
        per = L / steps
        tc = per * contact
        sweep = speed * tc
        e1 = 1.5 / 60.0
        for i in range(steps):
            t0 = i * per
            sd = 1 if i % 2 == 0 else -1
            c.root(t0, y=root_y, pitch=pitch, yaw=sd * hip_yaw, roll=sd * hip_roll, ease=E)
            c.root(t0 + min(f(3), per * 0.3), y=root_y - bob, pitch=pitch, yaw=sd * hip_yaw * 0.7, roll=sd * hip_roll * 1.2, ease=E)
            c.root(t0 + per * 0.65, y=root_y + bob, pitch=pitch, yaw=0, roll=0, ease=E)
            if counter:
                spine(c, t0, pitch=spine_p, yaw=-sd * hip_yaw, ease=E)
            if arms:
                arms(c, t0, sd)
        c.root(L, y=root_y, pitch=pitch, yaw=hip_yaw, roll=hip_roll, ease=E)
        if counter:
            spine(c, L, pitch=spine_p, yaw=-hip_yaw, ease=E)
        if arms:
            arms(c, L, 1)
        for side, first in (("R", 0), ("L", 1)):
            k = []
            sx = (width if side == "R" else -width)
            sz = (depth or {}).get(side, 0.0)
            for i in range(first, steps, 2):
                t0 = i * per
                def at(u, y, p):  # u = position along the travel axis relative to the foot's centre (+ = ahead)
                    return {"x": sx + dx * u, "z": sz + dz * u, "y": y, "p": p}
                k += [(t0 - e1, at(sweep / 2 + speed * e1, 0.05, heel + 4), "Linear"),
                      (t0, at(sweep / 2, 0.0, heel + plant_p), "Linear"),
                      (t0 + tc, at(-sweep / 2, 0.0, plant_p), "Linear"),
                      (t0 + tc + e1, at(-sweep / 2 - speed * e1, 0.07, -22), "CubicInOut"),
                      (t0 + tc + (2 * per - tc) * 0.45, at(0.0, lift, -8), "CubicInOut")]
            k = [((t % L) if (t < 0 or t >= L) else t, v, e) for t, v, e in k]
            cyclic(c, L, k, lambda t, v, e, side=side: foot(c, side, t, x=v["x"], y=v["y"], z=v["z"], pitch=v["p"],
                                                          yaw=(foot_yaw if side == "R" else -foot_yaw), ease=e))
        for i in range(steps):
            c.marker("Footstep", i * per, "R" if i % 2 == 0 else "L")
        return c
    return build


# arms for the sprints: gun low and canted 30 across the body, two hands (rifle-style) / pistol low at the chest
def sprint_arms_rifle(c, t, sd):
    c.gun_at_wrist(t, (0.35, 0.55 + 0.03 * sd, -0.95), (-28, 30, -30 - 2 * sd), ease=E)
    c.hand_on("L", t, (0.0, -0.05, -0.85), (0, 0, 0), ease=E)


def sprint_arms_pistol(c, t, sd):
    c.gun_at_wrist(t, (0.3, 0.75, -0.85), (-55, 20, -10), ease=E)
    c.free("L", t, 1.0, ease=E)
    # off arm pumps opposite the left leg (sd = +1: right foot down -> left arm forward)
    c.hand_free("L", t, (-0.75, 0.55 + 0.15 * sd, -0.55 * sd - 0.1), (50 * sd, 0, 0), ease=E)


ARMS_UP = ARMS + ["UpperTorso"]


# ---------------------------------------------------------------------------------------------------- crouch idle / slide
def crouch_idle():
    c = Clip("MoveCrouchIdle", 1.0, loop=True, priority="Action", joints=LEGS + ["UpperTorso"])
    for t, s in DRIFT:
        c.root(t, y=-1.05 - 0.015 * s, z=0.12, pitch=-14 - 0.5 * s, roll=0.6, ease=E)
        foot(c, "R", t, x=0.22, z=-0.35, yaw=-12, ease=E)
        foot(c, "L", t, x=-0.22, z=0.3, yaw=14, ease=E)
        spine(c, t, pitch=6 - 0.5 * s, ease=E)
    return c


def slide():
    """Slide on the hip (Slide.Time 0.75 = 1.5 cycles; fade in 0.08 / out 0.15): lead (right) leg out straight, rear (left)
    knee tucked under, hips low, torso back 15, gun forward (arms from the Hold). Sine micro-bob as the floor rattles."""
    c = Clip("MoveSlide", 0.5, loop=True, priority="Action4", joints=LEGS + ["UpperTorso", "Head"])
    for t, s in ((0, 0), (0.25, 1), (0.5, 0)):
        root_and_feet(c, t, y=-1.55 + 0.03 * s, z=0.25, pitch=12 + 0.5 * s, roll=-6,
                      feet={"R": ((0.15, -1.45, -1.25), (-70, 0, 0)), "L": ((-0.1, -0.55, 0.55), (75, 0, -5))}, ease=E)
        spine(c, t, pitch=-22 - 0.5 * s, ease=E)
        head(c, t, pitch=-8, ease=E)
    c.finish()
    ground_clamp(c, [0, 15, 30])
    return c


CLIPS = {
    "MoveRun": cycle("MoveRun", 0.70, 10.0, 0, 2, -0.34, -6, 0.42, 0.46, 0.05, spine_p=4, width=0.05, hip_yaw=5, hip_roll=3.5, heel=8),
    "MoveWalkAim": cycle("MoveWalkAim", 1.0, 6.0, 0, 4, -0.32, -3, 0.22, 1.0, 0.025, spine_p=2, width=0.05, hip_yaw=4, hip_roll=2.5, heel=12),
    "MoveStrafeLeft": cycle("MoveStrafeLeft", 0.70, 10.0, 90, 2, -0.36, -4, 0.38, 0.46, 0.05, spine_p=3,
                            depth={"R": 0.32, "L": -0.32}, hip_yaw=12, hip_roll=3, foot_yaw=-12),
    "MoveStrafeRight": cycle("MoveStrafeRight", 0.70, 10.0, -90, 2, -0.36, -4, 0.38, 0.46, 0.05, spine_p=3,
                             depth={"R": -0.32, "L": 0.32}, hip_yaw=-12, hip_roll=3, foot_yaw=12),
    "MoveBackpedal": cycle("MoveBackpedal", 0.70, 7.5, 180, 2, -0.34, -6, 0.32, 0.55, 0.04, spine_p=6, width=0.08, hip_yaw=4, hip_roll=2.5),
    "MoveSprint": cycle("MoveSprint", 0.50, 20.0, 0, 2, -0.46, -12, 0.75, 0.24, 0.09, spine_p=4, width=0.04, hip_yaw=6, hip_roll=5,
                        joints=LEGS + ARMS_UP, arms=sprint_arms_rifle, heel=6),
    "MoveSprintPistol": cycle("MoveSprintPistol", 0.50, 20.0, 0, 2, -0.46, -12, 0.75, 0.24, 0.09, spine_p=4, width=0.04, hip_yaw=6,
                              hip_roll=5, joints=LEGS + ARMS_UP, arms=sprint_arms_pistol, heel=6),
    "MoveCrouchIdle": crouch_idle,
    "MoveCrouchWalk": cycle("MoveCrouchWalk", 1.2, 6.0, 0, 4, -1.0, -14, 0.24, 1.0, 0.02, priority="Action", spine_p=6, width=0.2, heel=0, plant_p=-16),
    "MoveSlide": slide,
}
MIRROR = {}
