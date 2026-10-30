"""bodyanim.py: body / movement helpers on top of the shared rbxanim pipeline (art/anim/weapons/blender/rbxanim.py).

Roblox conventions everywhere: studs, degrees, x = character right, y = up, z = back (-z = forward).
Pitch + = nose up / lean back, yaw + = turn left, roll + = tilt toward the character's left? (Roblox Z-axis roll: + rolls
the top toward -X = character LEFT).

Leg control: feet are IK targets in world (root) space, keyed as offsets from the rest ankle pivot. The root
(LowerTorso) moves the hips; knees solve by IK toward a pole in front of each foot.
Arm control: either the held gun (`gun`) with both hands on it, or free hands (`free(side, t, 1)` + `hand_free`).
"""
import math, os, sys
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbxanim  # noqa: E402  (snapshot of the shared pipeline library, beside this file)
rbxanim.R15_JSON = os.path.join(HERE, "r15.json")  # this rig file has AnimationConstraint pivots + the pistol grip
rbxanim.set_barrel((0, 0, -1), (0, 1, 0))  # every Tacticals gun: Tool.Grip = identity, barrel = Handle -Z, top = +Y

Clip = rbxanim.Clip
r2b, rb_rot = rbxanim.r2b, rbxanim.rb_rot

LEGS = ["LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
ARMS = ["LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]
TORSO = ["LowerTorso", "UpperTorso"]
HEAD = ["Head"]
BODY = rbxanim.ALL_BODY

# rest pivots (Roblox, floor under HRP = 0)
WAIST_Y = 2.592
SHOULDER = (0.972, 4.039)
ANKLE = {"R": (0.5, 0.262, 0.0), "L": (-0.5, 0.262, 0.0)}


def foot(c, side, t, x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0, roll=0.0, **kw):
    """IK foot target `side` ('R'/'L') offset from its rest ankle pivot (studs, character axes) + rotation."""
    c.foot(side, t, (x, y, z), (pitch, yaw, roll), **kw)


def feet_rest(c, t, **kw):
    foot(c, "R", t, **kw)
    foot(c, "L", t, **kw)


def spine(c, t, pitch=0, yaw=0, roll=0, **kw):
    """UpperTorso about the waist (Roblox axes)."""
    c.joint_rot("Uppertorso", t, pitch, yaw, roll, **kw)


def head(c, t, pitch=0, yaw=0, roll=0, **kw):
    c.joint_rot("Head", t, pitch, yaw, roll, **kw)


def hands_free(c, t, **kw):
    c.free("R", t, 1.0, **kw)
    c.free("L", t, 1.0, **kw)


def hold_pose(c, t, ease=None):
    """the neutral authored arm stance: nothing; placeholder so clips read well"""
    pass




def _ease(e, u):
    if e == "Linear":
        return u
    if e in ("CubicInOut",):
        return 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2
    if e in ("SineInOut",):
        return -(math.cos(math.pi * u) - 1) / 2
    if e == "QuadIn":
        return u * u
    if e == "QuadOut":
        return 1 - (1 - u) ** 2
    return u


def cyclic(c, length, keys, setter):
    """keys: [(t, values_dict, ease)] for one cycle starting at any t (may run past `length`); wraps them into
    [0, length], adds seam keys at 0 and length with the interpolated value, and calls setter(t, values, ease)."""
    ks = sorted(keys, key=lambda k: k[0])
    t0 = ks[0][0]
    ks = ks + [(t0 + length, ks[0][1], ks[0][2])]
    seam = None
    for (ta, va, ea), (tb, vb, eb) in zip(ks, ks[1:]):
        for edge in (length, 2 * length):
            if ta < edge - 1e-6 < tb or abs(ta - edge) < 1e-6:
                u = 0 if abs(ta - edge) < 1e-6 else (edge - ta) / (tb - ta)
                w = _ease(ea, u)
                seam = ({k: va[k] + (vb[k] - va[k]) * w for k in va}, ea)
    out = []
    for t, v, e in ks[:-1]:
        tt = t % length
        out.append((tt, v, e))
    if seam is None:  # starts at 0
        seam = (ks[0][1], ks[0][2])
    if not any(abs(t) < 1e-6 for t, _, _ in out):
        out.append((0.0, seam[0], seam[1]))
    out = [o for o in out if abs(o[0] - length) > 1e-6]
    out.append((length, [o for o in out if abs(o[0]) < 1e-6][0][1], "Linear"))
    for t, v, e in sorted(out, key=lambda o: o[0]):
        setter(t, v, e)


# The rest legs/arms are perfectly straight: Blender's IK can't choose a bend direction from a straight chain, so the
# chain just translates (knees 0 deg, feet through the floor). Start every clip with a small bend in the solver's
# initial pose (unkeyed basis rotation; the IK result replaces it). Knees bend forward, elbows backward.
_orig_init = Clip.__init__


def _init(self, *a, **kw):
    _orig_init(self, *a, **kw)
    from mathutils import Quaternion
    for s in ("R", "L"):
        self.ob.pose.bones["Lowerleg." + s].rotation_quaternion = Quaternion((1, 0, 0), math.radians(PREBEND_LEG))
        self.ob.pose.bones["Lowerarm." + s].rotation_quaternion = Quaternion((1, 0, 0), math.radians(PREBEND_ARM))


PREBEND_LEG = -8.0
PREBEND_ARM = 8.0
Clip.__init__ = _init
