"""Batch 3: locomotion with a gun (targets section 10). Legs + hips (+ chest counter-rotation) so the weapon Hold keeps the
arms, except the sprints, which key the arms (gun low and canted). All directional cycles share length 0.70 and phase
(R contact f0, L contact at half) so 8-way blending stays in step. Code plays them at speed / authored speed."""
from bodyanim import *
import bpy
from b1_cover import DRIFT

E = "SineInOut"
f = lambda n: n / 60.0


def cycle(name, length, speed, heading, steps, root_y, pitch, lift, contact, bob, priority="Movement", spine_p=0.0,
          width=0.0, depth=None, hip_yaw=4.0, hip_roll=2.5, counter=True, joints=None, arms=None, foot_yaw=0.0,
          heel=0.0, plant_p=0.0, hip_open=0.0, lift_p=-22.0, lift_y=0.13):
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
            # hips keyed at contact / down / passing; the chest counters BOTH yaw and roll on the same frames so the
            # shoulders, head and muzzle stay on line (hip_open = a constant opening toward a side step)
            for tt, yy, ya, ro in ((t0, root_y, sd * hip_yaw, sd * hip_roll),
                                   (t0 + min(f(3), per * 0.3), root_y - bob, sd * hip_yaw * 0.7, sd * hip_roll),
                                   (t0 + per * 0.65, root_y + bob, 0.0, 0.0)):
                c.root(tt, y=yy, pitch=pitch, yaw=ya + hip_open, roll=ro, ease=E)
                if counter:
                    spine(c, tt, pitch=spine_p, yaw=-(ya + hip_open), roll=-ro, ease=E)
            if arms:
                arms(c, t0, sd)
        c.root(L, y=root_y, pitch=pitch, yaw=hip_yaw + hip_open, roll=hip_roll, ease=E)
        if counter:
            spine(c, L, pitch=spine_p, yaw=-(hip_yaw + hip_open), roll=-hip_roll, ease=E)
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
                k += [(t0 - e1, at(sweep / 2 + speed * e1, 0.1, heel), "Linear"),
                      (t0, at(sweep / 2, 0.0, heel + plant_p), "Linear"),
                      (t0 + tc, at(-sweep / 2, 0.0, plant_p), "Linear"),
                      (t0 + tc + e1, at(-sweep / 2 - speed * e1, lift_y, lift_p), "CubicInOut"),
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
    c.gun_at_wrist(t, (0.45, 0.6 + 0.03 * sd, -1.1), (-28, 30, -30 - 2 * sd), ease=E)
    c.hand_on("L", t, (0.0, -0.3, -0.5), (0, 0, 0), ease=E)  # support hand at the magwell (in reach on R15)


def sprint_arms_pistol(c, t, sd):
    c.gun_at_wrist(t, (0.55, 0.8, -1.2), (-55, 20, -10), ease=E)
    c.free("L", t, 1.0, ease=E)
    # off arm pumps opposite the left leg (sd = +1: right foot down -> left arm forward)
    c.hand_free("L", t, (-1.5, 0.45 + 0.15 * sd, -0.55 * sd - 0.1), (50 * sd, 0, 15), ease=E)


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
    """Slide on the hip (Slide.Time 0.75 = 1.5 cycles; fade in 0.08 / out 0.15): hips low (pivot ~0.75 over the floor),
    the lead (right) leg reaching forward almost flat along the floor (heel down, knee 10-15), the rear (left) knee folded
    under with the shin flat, torso leaning back 15, gun forward (arms from the Hold). Sine micro-bob 0.03 + 0.5 deg."""
    c = Clip("MoveSlide", 0.5, loop=True, priority="Action4", joints=LEGS + ["UpperTorso", "Head"])
    for t, s in ((0, 0), (0.25, 1), (0.5, 0)):
        c.root(t, y=-1.6 + 0.03 * s, z=0.15, pitch=10 + 0.5 * s, roll=-5, ease=E)
        foot(c, "R", t, x=0.05, z=-1.75, pitch=12, ease=E)       # heel on the floor, toe up
        foot(c, "L", t, x=-0.3, z=1.55, pitch=-80, roll=-10, ease=E)  # thigh down-back, shin flat, instep on the floor
        spine(c, t, pitch=5 - 0.5 * s, ease=E)   # chest ~15 back in the world
        head(c, t, pitch=-14, ease=E)
    c.finish()
    clamp_exact(c, 30, both=True)
    bpy.context.scene.frame_set(0)
    print("SLIDE_HIP", round(c.ob.pose.bones["Lowertorso"].head.z, 3))
    return c


CLIPS = {
    "MoveRun": cycle("MoveRun", 0.70, 10.0, 0, 2, -0.34, -6, 0.42, 0.46, 0.05, spine_p=4, width=0.05, hip_yaw=5, hip_roll=3.5, heel=0),
    "MoveWalkAim": cycle("MoveWalkAim", 1.0, 6.0, 0, 4, -0.17, -3, 0.22, 1.0, 0.025, spine_p=2, width=0.05, hip_yaw=4, hip_roll=2.5, heel=0),
    "MoveStrafeLeft": cycle("MoveStrafeLeft", 0.70, 10.0, 90, 2, -0.5, -4, 0.38, 0.42, 0.05, spine_p=3,
                            depth={"R": 0.5, "L": -0.5}, width=0.22, hip_yaw=3, hip_roll=2, foot_yaw=10, hip_open=12, lift_p=0),
    "MoveStrafeRight": cycle("MoveStrafeRight", 0.70, 10.0, -90, 2, -0.5, -4, 0.38, 0.42, 0.05, spine_p=3,
                             depth={"R": -0.5, "L": 0.5}, width=0.22, hip_yaw=3, hip_roll=2, foot_yaw=-10, hip_open=-12, lift_p=0),
    "MoveBackpedal": cycle("MoveBackpedal", 0.70, 7.5, 180, 2, -0.34, -6, 0.32, 0.55, 0.04, spine_p=6, width=0.08, hip_yaw=4, hip_roll=2.5),
    "MoveSprint": cycle("MoveSprint", 0.50, 20.0, 0, 2, -0.46, -12, 0.75, 0.24, 0.09, spine_p=4, width=0.04, hip_yaw=6, hip_roll=5,
                        joints=LEGS + ARMS_UP, arms=sprint_arms_rifle, heel=6),
    "MoveSprintPistol": cycle("MoveSprintPistol", 0.50, 20.0, 0, 2, -0.46, -12, 0.75, 0.24, 0.09, spine_p=4, width=0.04, hip_yaw=6,
                              hip_roll=5, joints=LEGS + ARMS_UP, arms=sprint_arms_pistol, heel=0),
    "MoveCrouchIdle": crouch_idle,
    "MoveCrouchWalk": cycle("MoveCrouchWalk", 1.2, 6.0, 0, 4, -1.0, -14, 0.4, 1.0, 0.02, lift_y=0.32, priority="Action", spine_p=6, width=0.2, heel=0, plant_p=-16),
    "MoveSlide": slide,
}
MIRROR = {}
