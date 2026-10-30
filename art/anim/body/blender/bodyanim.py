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


def root_and_feet(c, t, x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0, roll=0.0, feet=None, ease="SineInOut"):
    """Key the root and put the IK feet where the body carries them (rolls, vaults, dives, falls): feet = {side:
    (off_xyz, rot_pyr)} with off measured from the hip pivot in the BODY's frame (x right, y up, z back) and rot the foot
    rotation relative to the body. Feet keyed this way are not planted; they ride the hips."""
    from mathutils import Vector
    c.root(t, x=x, y=y, z=z, pitch=pitch, yaw=yaw, roll=roll, ease=ease)
    R = rb_rot(pitch, yaw, roll).to_3x3()
    rp = Vector((0.0, 2.192, 0.0))
    for side, (off, rot) in (feet or {}).items():
        hip = Vector((0.5 if side == "R" else -0.5, 0.0, 0.0))
        w = rp + Vector((x, y, z)) + R @ (hip + Vector(off))
        a = Vector(ANKLE[side])
        d = w - a
        # foot rotation = body rotation then the local foot rotation (Euler composition is close enough for keys)
        Rf = R @ rb_rot(*rot).to_3x3()
        e = Rf.to_euler("ZXY")  # matrix Ry @ Rx @ Rz (rb_rot order)
        c.foot(side, t, (d.x, d.y, d.z), (math.degrees(e.x), math.degrees(e.y), math.degrees(e.z)), ease=ease)


def lowest_point(c):
    """lowest body surface point (Roblox y) in the current evaluated pose: bone ends minus a 0.45 limb half-thickness,
    the head's crown (1.2 up the head bone) minus 0.5."""
    from mathutils import Vector
    pb = c.ob.pose.bones
    zs = []
    for n in ("Lowertorso", "Uppertorso", "Upperarm.R", "Lowerarm.R", "Hand.R", "Upperarm.L", "Lowerarm.L", "Hand.L",
              "Upperleg.R", "Lowerleg.R", "Upperleg.L", "Lowerleg.L"):
        zs += [pb[n].head.z - 0.45, pb[n].tail.z - 0.45]
    for s in ("R", "L"):
        zs.append(pb["Foot." + s].head.z - 0.262)
    zs.append((pb["Head"].matrix @ Vector((0, 1.0, 0))).z - 0.5)
    zs.append(pb["Head"].head.z - 0.4)
    return min(zs)


def ground_clamp(c, frames, target=0.0, passes=3):
    """at each frame, move the root (and IK feet keyed at that frame) up/down so the lowest body point sits at `target`."""
    from mathutils import Vector
    sc = bpy.context.scene
    pb = c.ob.pose.bones
    for _ in range(passes):
        for fr in frames:
            sc.frame_set(int(round(fr)))
            dz = target - lowest_point(c)
            if abs(dz) < 0.005:
                continue
            for bone in ("Lowertorso", "IK_Foot.R", "IK_Foot.L"):
                b = c.ob.data.bones[bone]
                fcs = [fc for fc in c.act.fcurves if fc.data_path == 'pose.bones["%s"].location' % bone]
                if not fcs or (bone != "Lowertorso" and not any(abs(k.co.x - fr) < 1e-3 for k in fcs[0].keyframe_points)):
                    continue
                rest = b.matrix_local.to_3x3()
                d = rest.inverted() @ Vector((0, 0, dz))
                for fc in fcs:
                    for k in fc.keyframe_points:
                        if abs(k.co.x - fr) < 1e-3:
                            k.co.y += d[fc.array_index]
                            k.handle_left.y += d[fc.array_index]
                            k.handle_right.y += d[fc.array_index]
                    fc.update()


# Quaternion keys are interpolated per component: q and -q are the same rotation but blending across a sign flip swings
# the bone the long way (a roll's body popped upright mid-spin). Keep each key in the previous key's hemisphere.
_orig_key_basis = Clip.key_basis


def _key_basis(self, bone, t, loc=None, quat=None, **kw):
    if quat is not None:
        last = getattr(self, "_lastq", {}).get(bone)
        if last is not None and quat.dot(last) < 0:
            quat = -quat
        if not hasattr(self, "_lastq"):
            self._lastq = {}
        self._lastq[bone] = quat.copy()
    return _orig_key_basis(self, bone, t, loc=loc, quat=quat, **kw)


Clip.key_basis = _key_basis
