"""rbxanim.py: Blender <-> Roblox R15 animation pipeline for Tacticals (animator, 2026-10-30).

Used headless:  blender -b <rig.blend> --python <clip_script.py>   (clip scripts `import rbxanim`)
- setup_rig():   turns the copied Starter_Blocky_Rig into the animation rig: R15 bones moved onto the real R15 joint
                 pivots (r15.json, read from Studio), the starter rig's control bones replaced by a small clean set:
                   Gun          the held item (child of Uppertorso): key it, the gun hand follows by IK
                   IK_Hand.R/L  hand IK targets; each blends between <side>_Gun (on the item) and <side>_Free (chest
                                space) with the custom property "free" (0 = on the gun, 1 = free)
                   Pole_Arm.R/L elbow poles (chest space); IK_Foot.R/L + Pole_Leg.R/L keep the feet planted
                   gun parts    (Slide, Mag, Bolt, ...) children of Gun, keyed in the same action
- Authoring helpers take Roblox conventions (studs, degrees, X right / Y up / -Z forward, relative to the character).
- export_clip(): samples the evaluated rig at 60 fps and writes Roblox Motor6D Transforms per joint (exact:
                 Transform = C0^-1 * P0(t)^-1 * P1(t) * C1), reduces keys within a tolerance, and can mirror the clip
                 for the "...Left" version (gun in the left hand).
"""
import bpy, json, math, os, hashlib
from mathutils import Matrix, Vector, Quaternion, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
R15_JSON = os.path.join(HERE, "r15.json")
FPS = 60
# Gun-bone orientation that counts as "level, barrel forward": set_barrel() fixes it per gun (the Handle's own axes vary)
LEVEL = Matrix.Identity(3)


def set_barrel(barrel_r, up_r=(0, 1, 0)):
    """barrel / up directions in the Handle's Roblox frame -> LEVEL (so gun(rot=0) points the barrel forward)."""
    global LEVEL
    b = Vector((barrel_r[0], -barrel_r[2], barrel_r[1])).normalized()  # Handle-local, Blender-style axes
    u = Vector((up_r[0], -up_r[2], up_r[1]))
    u = (u - b * u.dot(b)).normalized()
    r = b.cross(u)
    F = Matrix((r, b, u)).transposed()  # columns: right, barrel, up (gun-bone local)
    LEVEL = F.transposed()

# Blender (x, y, z), character facing +Y  ->  Roblox (x, y, z) = (bx, bz, -by), character facing -Z
A = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
AI = A.inverted()

BONE = {  # R15 part -> deform bone
    "LowerTorso": "Lowertorso", "UpperTorso": "Uppertorso", "Head": "Head",
    "RightUpperArm": "Upperarm.R", "RightLowerArm": "Lowerarm.R", "RightHand": "Hand.R",
    "LeftUpperArm": "Upperarm.L", "LeftLowerArm": "Lowerarm.L", "LeftHand": "Hand.L",
    "RightUpperLeg": "Upperleg.R", "RightLowerLeg": "Lowerleg.R", "RightFoot": "Foot.R",
    "LeftUpperLeg": "Upperleg.L", "LeftLowerLeg": "Lowerleg.L", "LeftFoot": "Foot.L",
}
TREE = {
    "LowerTorso": "HumanoidRootPart", "UpperTorso": "LowerTorso", "Head": "UpperTorso",
    "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
    "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
    "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
    "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
}
ALL_BODY = list(TREE.keys())
ARMS_UP = ["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]


def cf2m(c):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def m2cf(m, nd=5):
    v = [m[0][3], m[1][3], m[2][3], m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]]
    return [round(x, nd) + 0.0 for x in v]


def r2b(m):  # Roblox-space matrix -> Blender-space
    return AI @ m @ A


def b2r(m):
    return A @ m @ AI


GUN_DIR = os.path.join(HERE, "..", "..", "..", "guns", "manifest")


def load_gun(name):
    """the modeler's manifest (art/guns/manifest/<Gun>.json): parts with parent, pivot (Handle space), bbox, motion"""
    with open(os.path.join(GUN_DIR, name + ".json")) as f:
        d = json.load(f)
    parts = {p["name"]: p for p in d["parts"]}
    return {"name": name, "parts": parts, "atts": d.get("attachments")}


def load_r15():
    with open(R15_JSON) as f:
        return json.load(f)


# ----------------------------------------------------------------------------------------------------------- rig setup
CARRY = ("Mag", "LoadShell", "Rounds")
KEEP = {"Master", "FlipBone", "Lowertorso", "Hips", "Uppertorso", "Head", "Head.001", "Head Stretcher", "TorsoXHandle",
        "TorsoBendy", "TorsoTHandle", "Upperarm.R", "Lowerarm.R", "Hand.R", "Upperarm.L", "Lowerarm.L", "Hand.L",
        "Upperleg.R", "Lowerleg.R", "Foot.R", "Upperleg.L", "Lowerleg.L", "Foot.L"}


def arm_obj():
    return bpy.data.objects["Blocky Rig"]


def part_rest_b(r15, part):
    """rest CFrame of an R15 part in Blender space (floor under the HRP = origin)"""
    return r2b(cf2m(r15["parts"][part]["cf"]))


def pivot_b(r15, part1):
    j = r15["joints"][part1]
    m = cf2m(r15["parts"][j["part0"]]["cf"]) @ cf2m(j["C0"])
    return r2b(m).translation.copy()


def setup_rig(gun_parts=None, tool="Pistol", gun=None):
    """Build the animation rig in the open (copied) starter file. gun_parts: {name: rest matrix in Gun-bone space}."""
    r15 = load_r15()
    ob = arm_obj()
    bpy.context.view_layer.objects.active = ob
    ob.animation_data_clear()
    if ob.data.animation_data:
        ob.data.animation_data_clear()
    for pb in ob.pose.bones:
        for c in list(pb.constraints):
            if not (pb.name in ("TorsoBendy", "Head.001") and c.type == "STRETCH_TO"):
                pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ob.data.edit_bones
    for b in list(eb):
        if b.name not in KEEP:
            eb.remove(b)
    piv = {p: pivot_b(r15, p) for p in r15["joints"] if p in BONE}
    # R15 chain onto the R15 pivots. Bones point down the limb; roll keeps local Z toward the character's front.
    def place(name, head, tail):
        b = eb[name]
        b.use_connect = False
        b.head = head
        b.tail = tail
        b.align_roll(Vector((0, 1, 0)))
    up = Vector((0, 0, 1))
    place("Lowertorso", piv["LowerTorso"], piv["UpperTorso"])
    place("Hips", piv["LowerTorso"], piv["LowerTorso"] - up * 0.4)
    place("Uppertorso", piv["UpperTorso"], piv["Head"])
    place("Head", piv["Head"], piv["Head"] + up * 1.1)
    for s, S in (("R", "Right"), ("L", "Left")):
        place("Upperarm." + s, piv[S + "UpperArm"], piv[S + "LowerArm"])
        place("Lowerarm." + s, piv[S + "LowerArm"], piv[S + "Hand"])
        place("Hand." + s, piv[S + "Hand"], piv[S + "Hand"] - up * 0.3)
        place("Upperleg." + s, piv[S + "UpperLeg"], piv[S + "LowerLeg"])
        place("Lowerleg." + s, piv[S + "LowerLeg"], piv[S + "Foot"])
        place("Foot." + s, piv[S + "Foot"], piv[S + "Foot"] - up * 0.2)
    # torso / head helper bones (TorsoBendy skin, Head.001 head mesh) stay where the rig author put them: they ride on
    # their parents, so they turn about the new pivots

    def new(name, head, tail, parent, roll_to=Vector((0, 1, 0))):
        b = eb.new(name)
        b.head, b.tail = head, tail
        b.align_roll(roll_to)
        b.parent = eb[parent] if parent else None
        b.use_deform = False
        return b
    # the held item: the Handle's rest pose = RightHand rest * grip (r15.json "grip": RightHand -> Handle)
    hand_r = cf2m(r15["parts"]["RightHand"]["cf"])
    handle_r = hand_r @ cf2m(r15["tools"][tool]["grip"])
    hb = r2b(handle_r)
    # Gun bone: head at the Handle origin; Y axis = the Handle's -Z (barrel forward), Z axis = Handle's Y (up)
    g = new("Gun", hb.translation, hb.translation + (hb.to_3x3() @ Vector((0, 1, 0))) * 0.6, "Uppertorso",
            hb.to_3x3() @ Vector((0, 0, 1)))
    for s, S in (("R", "Right"), ("L", "Left")):
        w = piv[S + "Hand"]
        hand = eb["Hand." + s]
        for space, par in (("Gun", "Gun"), ("Free", "Uppertorso")):
            b = new(s + "_" + space, w, w + (hand.tail - hand.head), par, hand.z_axis.copy())
        new("IK_Hand." + s, w, w + (hand.tail - hand.head), None, hand.z_axis.copy())
        e = piv[S + "LowerArm"]
        new("Pole_Arm." + s, e + Vector((0, -1.5, 0)) + Vector((0.6 if s == "R" else -0.6, 0, 0)),
            e + Vector((0, -1.5, 0.3)) + Vector((0.6 if s == "R" else -0.6, 0, 0)), "Uppertorso")
        a = piv[S + "Foot"]
        new("IK_Foot." + s, a, a - up * 0.2, None, eb["Foot." + s].z_axis.copy())
        k = piv[S + "LowerLeg"]
        new("Pole_Leg." + s, k + Vector((0, 2.0, 0)), k + Vector((0, 2.0, 0.3)), "IK_Foot." + s)
    if gun:
        hb3 = hb.to_3x3()
        def mk(pn):
            if pn in eb:
                return
            pd = gun["parts"][pn]
            par = pd["parent"]
            if par != "Handle":
                mk(par)
            head = hb @ r2b(Matrix.Translation(pd["pivot"])).translation if False else                 (hb @ Matrix.Translation(Vector((pd["pivot"][0], -pd["pivot"][2], pd["pivot"][1])))).translation
            new("P_" + pn, head, head + (hb3 @ Vector((0, 1, 0))) * 0.15, "Gun" if par == "Handle" else "P_" + par,
                hb3 @ Vector((0, 0, 1)))
        for pn in gun["parts"]:
            mk(pn)
        # hand-held twins for carried parts: H_<part> under Hand.L, rest = the part as if the gun sat in the left hand
        lh = cf2m(r15["parts"]["LeftHand"]["cf"])
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = r15["tools"][tool]["grip"]
        gripL = cf2m([-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22])
        for pn in CARRY:
            if pn in gun["parts"]:
                w = r2b(lh @ gripL @ Matrix.Translation(gun["parts"][pn]["pivot"]))
                new("H_" + pn, w.translation, w.translation + w.to_3x3() @ Vector((0, 1, 0)) * 0.15, "Hand.L",
                    w.to_3x3() @ Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="POSE")
    pbs = ob.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.use_ik_limit_x = pb.use_ik_limit_y = pb.use_ik_limit_z = False
        pb.lock_ik_x = pb.lock_ik_y = pb.lock_ik_z = False
    for s in ("R", "L"):
        ik = pbs["IK_Hand." + s]
        c1 = ik.constraints.new("COPY_TRANSFORMS"); c1.name = "OnGun"; c1.target = ob; c1.subtarget = s + "_Gun"
        c2 = ik.constraints.new("COPY_TRANSFORMS"); c2.name = "Free"; c2.target = ob; c2.subtarget = s + "_Free"
        ik["free"] = 0.0 if s == "R" else 0.0
        d = c2.driver_add("influence").driver
        d.type = "SCRIPTED"; d.expression = "free"
        v = d.variables.new(); v.name = "free"; v.type = "SINGLE_PROP"
        v.targets[0].id = ob; v.targets[0].data_path = 'pose.bones["IK_Hand.%s"]["free"]' % s
        c = pbs["Lowerarm." + s].constraints.new("IK")
        c.target = ob; c.subtarget = "IK_Hand." + s; c.pole_target = ob; c.pole_subtarget = "Pole_Arm." + s
        c.chain_count = 2; c.use_tail = True
        c = pbs["Hand." + s].constraints.new("COPY_ROTATION"); c.target = ob; c.subtarget = "IK_Hand." + s
        c = pbs["Lowerleg." + s].constraints.new("IK")
        c.target = ob; c.subtarget = "IK_Foot." + s; c.pole_target = ob; c.pole_subtarget = "Pole_Leg." + s
        c.chain_count = 2; c.use_tail = True
        c = pbs["Foot." + s].constraints.new("COPY_ROTATION"); c.target = ob; c.subtarget = "IK_Foot." + s
    for pn in CARRY:
        if gun and pn in gun["parts"]:
            pb = pbs["P_" + pn]
            c = pb.constraints.new("COPY_TRANSFORMS"); c.name = "InHand"; c.target = ob; c.subtarget = "H_" + pn
            pb["inhand"] = 0.0
            d = c.driver_add("influence").driver
            d.type = "SCRIPTED"; d.expression = "v"
            v = d.variables.new(); v.name = "v"; v.type = "SINGLE_PROP"
            v.targets[0].id = ob; v.targets[0].data_path = 'pose.bones["P_%s"]["inhand"]' % pn
    # pole angles: pick the one that leaves the rest pose untouched
    bpy.context.view_layer.update()
    for s in ("R", "L"):
        for chain, upper in (("Lowerarm." + s, "Upperarm." + s), ("Lowerleg." + s, "Upperleg." + s)):
            best = None
            for deg in range(-180, 181, 5):
                pbs[chain].constraints["IK"].pole_angle = math.radians(deg)
                bpy.context.view_layer.update()
                m = pbs[upper].matrix
                rest = ob.data.bones[upper].matrix_local
                err = (m.to_3x3() - rest.to_3x3()).to_quaternion().angle if False else sum(
                    (m.to_3x3()[i][j] - rest.to_3x3()[i][j]) ** 2 for i in range(3) for j in range(3))
                if best is None or err < best[0]:
                    best = (err, deg)
            pbs[chain].constraints["IK"].pole_angle = math.radians(best[1])
    bpy.context.view_layer.update()
    scn = bpy.context.scene
    scn.render.fps = FPS
    build_preview(ob, r15, tool, gun)
    global GUNDEF, TOOLNAME
    GUNDEF = gun
    TOOLNAME = tool
    return ob


GUNDEF = None
TOOLNAME = "Pistol"


def build_preview(ob, r15, tool, gun=None):
    """Exact R15 part boxes (and the tool's parts) parented to the bones: the Blender view then matches Roblox. The
    starter rig's own skinned meshes are hidden (their helper-bone skinning was made for the starter pivots)."""
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name not in ("GunProxy",) and not o.name.startswith("R15_"):
            o.hide_render = True
            o.hide_viewport = True
    col = bpy.data.collections.get("R15 preview") or bpy.data.collections.new("R15 preview")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    mat = bpy.data.materials.get("R15Grey") or bpy.data.materials.new("R15Grey")
    mat.diffuse_color = (0.62, 0.6, 0.56, 1)
    gmat = bpy.data.materials.get("GunDark") or bpy.data.materials.new("GunDark")
    gmat.diffuse_color = (0.08, 0.08, 0.09, 1)
    import bmesh

    def box(name, size, world_b, bone, m):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[2], v.co.z * size[1]))  # Roblox (x, y, z) size -> Blender
        bm.to_mesh(me); bm.free()
        me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        col.objects.link(o)
        o.parent = ob; o.parent_type = "BONE"; o.parent_bone = bone
        bpy.context.view_layer.update()
        o.matrix_world = world_b
        return o
    for part, bn in BONE.items():
        box("R15_" + part, r15["parts"][part]["size"], part_rest_b(r15, part), bn, mat)
    hand = cf2m(r15["parts"]["RightHand"]["cf"])
    handle = hand @ cf2m(r15["tools"][tool]["grip"])
    if gun:
        for pn, pd in gun["parts"].items():
            c = pd["bbox_centre"]
            box("R15_gun_" + pn, pd["size"], r2b(handle @ Matrix.Translation(c)), "P_" + pn, gmat)
    else:
        for pn, pd in r15["tools"][tool]["parts"].items():
            box("R15_gun_" + pn, pd["size"], r2b(handle @ cf2m(pd["cf"])), "Gun", gmat)


# ----------------------------------------------------------------------------------------------------------- authoring
def rb_rot(pitch=0, yaw=0, roll=0):
    """Roblox-convention rotation (degrees): pitch about X (up = +), yaw about Y (left = +), roll about Z."""
    return Matrix.Rotation(math.radians(yaw), 4, "Y") @ Matrix.Rotation(math.radians(pitch), 4, "X") @ \
        Matrix.Rotation(math.radians(roll), 4, "Z")


class Clip:
    """One action. Key times in seconds. All poses are set in Roblox conventions and keyed on Blender bones."""

    def __init__(self, name, length, loop=False, priority="Action", joints=None, mirror_of=None):
        self.name, self.length, self.loop, self.priority = name, length, loop, priority
        self.joints = joints or ALL_BODY
        self.markers = []
        self.ob = arm_obj()
        self.r15 = load_r15()
        ob = self.ob
        act = bpy.data.actions.get(name) or bpy.data.actions.new(name)
        if act.fcurves:
            for fc in list(act.fcurves):
                act.fcurves.remove(fc)
        ob.animation_data_create()
        ob.animation_data.action = act
        self.act = act
        for pb in ob.pose.bones:
            pb.matrix_basis = Matrix()
            if "free" in pb.keys():
                pb["free"] = 0.0
            if "inhand" in pb.keys():
                pb["inhand"] = 0.0
        self.interp = {}  # (bone, frame) -> interpolation for the segment starting there
        # anchors in Roblox axes relative to the Waist pivot (where chest-space positions are measured from)
        r15 = self.r15
        def piv_r(p):
            j = r15["joints"][p]
            return (cf2m(r15["parts"][j["part0"]]["cf"]) @ cf2m(j["C0"])).translation
        w = piv_r("UpperTorso")
        self.anchor = {k: tuple(round(x, 3) for x in (piv_r(p) - w)) for k, p in
                       (("shoulderR", "RightUpperArm"), ("shoulderL", "LeftUpperArm"), ("neck", "Head"),
                        ("elbowR", "RightLowerArm"), ("wristR", "RightHand"), ("hipR", "RightUpperLeg"),
                        ("root", "LowerTorso"))}
        self.anchor["eye"] = (0.0, self.anchor["neck"][1] + 0.5, -0.4)

    def f(self, t):
        return t * FPS

    # -- low-level keys --------------------------------------------------------------------------------------------
    def key_basis(self, bone, t, loc=None, quat=None, ease="SineInOut"):
        pb = self.ob.pose.bones[bone]
        fr = self.f(t)
        if loc is not None:
            pb.location = loc
            pb.keyframe_insert("location", frame=fr, group=bone)
        if quat is not None:
            pb.rotation_quaternion = quat
            pb.keyframe_insert("rotation_quaternion", frame=fr, group=bone)
        self.interp[(bone, round(fr, 3))] = (ease,)

    def key_prop(self, bone, prop, t, value, ease="SineInOut"):
        pb = self.ob.pose.bones[bone]
        pb[prop] = value
        pb.keyframe_insert('["%s"]' % prop, frame=self.f(t), group=bone)
        self.interp[(bone + "|" + prop, round(self.f(t), 3))] = (ease,)

    def joint_rot(self, bone, t, pitch=0, yaw=0, roll=0, **kw):
        """FK rotation of a bone about its own pivot in the character's (rest) axes, Roblox conventions."""
        rest = self.ob.data.bones[bone].matrix_local.to_3x3()
        R = r2b(rb_rot(pitch, yaw, roll)).to_3x3()
        q = (rest.inverted() @ R @ rest).to_quaternion()
        self.key_basis(bone, t, quat=q, **kw)

    def root(self, t, x=0, y=0, z=0, pitch=0, yaw=0, roll=0, **kw):
        """LowerTorso (Root joint): offset in studs (Roblox axes) and rotation about the root pivot."""
        rest = self.ob.data.bones["Lowertorso"].matrix_local.to_3x3()
        d = r2b(Matrix.Translation((x, y, z))).translation
        R = r2b(rb_rot(pitch, yaw, roll)).to_3x3()
        q = (rest.inverted() @ R @ rest).to_quaternion()
        self.key_basis("Lowertorso", t, loc=rest.inverted() @ d, quat=q, **kw)

    def chest_space_key(self, bone, t, pos, rot, **kw):
        """Key a bone whose parent is Uppertorso at a pose given in UpperTorso-rest-relative Roblox coordinates:
        pos = studs from the Waist pivot (x right, y up, z back), rot = (pitch, yaw, roll) of its rest orientation."""
        ob = self.ob
        b = ob.data.bones[bone]
        ut = ob.data.bones["Uppertorso"]
        # target in the Uppertorso rest frame (world-rest), then expressed as the bone's basis relative to its rest
        piv = ut.matrix_local.translation
        tgt_rot = r2b(rb_rot(*rot)).to_3x3() @ b.matrix_local.to_3x3()
        tgt = Matrix.Translation(piv + r2b(Matrix.Translation(pos)).translation) @ tgt_rot.to_4x4()
        # rest-relative basis: parent rest -> bone; basis = rest_rel^-1 * parent_rest^-1 * tgt (parent pose excluded:
        # the bone rides on the chest, so its pose is in chest space)
        rest_rel = ut.matrix_local.inverted() @ b.matrix_local
        basis = rest_rel.inverted() @ ut.matrix_local.inverted() @ tgt
        loc, q, _ = basis.decompose()
        self.key_basis(bone, t, loc=loc, quat=q, **kw)

    def gun(self, t, pos, rot=(0, 0, 0), **kw):
        """Key the held item: Handle origin `pos` from the Waist pivot (studs, Roblox axes at rest), `rot` =
        (pitch, yaw, roll) of the barrel: (0,0,0) = barrel straight forward, top up."""
        ob = self.ob
        b = ob.data.bones["Gun"]
        ut = ob.data.bones["Uppertorso"]
        piv = ut.matrix_local.translation
        # the Gun bone's axes: Y = barrel, Z = up (Blender); "level" = Y along +Y world, Z up
        R = r2b(rb_rot(*rot)).to_3x3() @ LEVEL
        tgt = Matrix.Translation(piv + r2b(Matrix.Translation(pos)).translation) @ R.to_4x4()
        rest_rel = ut.matrix_local.inverted() @ b.matrix_local
        basis = rest_rel.inverted() @ ut.matrix_local.inverted() @ tgt
        loc, q, _ = basis.decompose()
        self.key_basis("Gun", t, loc=loc, quat=q, **kw)

    def gun_at_wrist(self, t, wrist, rot=(0, 0, 0), **kw):
        """Key the gun so the gun hand's wrist lands on `wrist` (studs from the Waist pivot, Roblox axes) with the
        barrel at `rot` (pitch, yaw, roll). The hand keeps the real Tool grip."""
        ob = self.ob
        g = ob.data.bones["Gun"]
        v = (g.matrix_local.inverted() @ ob.data.bones["R_Gun"].matrix_local).translation
        R = r2b(rb_rot(*rot)).to_3x3() @ LEVEL
        w_b = r2b(Matrix.Translation(wrist)).translation
        h_b = w_b - R @ v
        self.gun(t, tuple(b2r(Matrix.Translation(h_b)).translation), rot, **kw)

    def gun_by_point(self, t, gun_pt, target, rot=(0, 0, 0), **kw):
        """Key the gun so its point gun_pt (Handle space, Roblox axes) lands on target (chest space, studs from the Waist)."""
        R = rb_rot(*rot)
        h = Vector(target) - (R @ Matrix.Translation(gun_pt)).translation
        self.gun(t, tuple(h), rot, **kw)

    def world_key(self, bone, t, pos=(0, 0, 0), rot=(0, 0, 0), **kw):
        """Key a parentless bone (IK_Foot.*) by a world offset from its rest (studs, Roblox axes) and rotation."""
        rest = self.ob.data.bones[bone].matrix_local.to_3x3()
        d = r2b(Matrix.Translation(pos)).translation
        R = r2b(rb_rot(*rot)).to_3x3()
        self.key_basis(bone, t, loc=rest.inverted() @ d, quat=(rest.inverted() @ R @ rest).to_quaternion(), **kw)

    def foot(self, side, t, pos=(0, 0, 0), rot=(0, 0, 0), **kw):
        self.world_key("IK_Foot." + side, t, pos, rot, **kw)

    def hand_on(self, side, t, pos, rot=(0, 0, 0), **kw):
        """Hand grip on the item: wrist at `pos` in the gun's frame (studs; x right, y up, z back along the barrel,
        origin = Handle). rot (pitch, yaw, roll in the gun frame) on top of the mirror of the gun hand's grip, so
        (0,0,0) = the support hand mirrors the gun hand."""
        ob = self.ob
        g = ob.data.bones["Gun"].matrix_local
        rr = (g.inverted() @ ob.data.bones["R_Gun"].matrix_local).to_3x3()
        Mx = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, 1)))
        LT = LEVEL.transposed()
        Mb = LT @ Mx @ LEVEL  # mirror across the gun's own left/right plane, in gun-bone coordinates
        base = rr if side == "R" else Mb @ rr @ Mb
        R = LT @ r2b(rb_rot(*rot)).to_3x3() @ LEVEL @ base
        local = R.to_4x4()
        local.translation = LT @ r2b(Matrix.Translation(pos)).translation
        b = ob.data.bones[side + "_Gun"].matrix_local
        rest_rel = g.inverted() @ b
        basis = rest_rel.inverted() @ local
        loc, q, _ = basis.decompose()
        self.key_basis(side + "_Gun", t, loc=loc, quat=q, **kw)

    def hand_free(self, side, t, pos, rot=(0, 0, 0), **kw):
        # keep the wrist within 98% of the arm's reach from the shoulder (chest frame): what is keyed is what plays
        sh = Vector(self.anchor["shoulderR"]) if side == "R" else Vector(self.anchor["shoulderL"])
        reach = 0.98 * (self.ob.data.bones["Upperarm." + side].length + self.ob.data.bones["Lowerarm." + side].length)
        v = Vector(pos) - sh
        if v.length > reach:
            self.clamped = max(getattr(self, "clamped", 0.0), v.length - reach)
            pos = tuple(sh + v.normalized() * reach)
        """Free hand (IK target) in chest space: wrist position from the Waist pivot, rot relative to the rest hand."""
        self.chest_space_key(side + "_Free", t, pos, rot, **kw)

    def free(self, side, t, value, **kw):
        self.key_prop("IK_Hand." + side, "free", t, value, **kw)

    def pole(self, side, t, pos, **kw):
        self.chest_space_key("Pole_Arm." + side, t, pos, (0, 0, 0), **kw)

    def part(self, name, t, pos=(0, 0, 0), rot=(0, 0, 0), **kw):
        """A gun part relative to its rest, in the Gun bone's frame (studs, degrees, Roblox axes of the Handle)."""
        b = self.ob.data.bones["P_" + name]
        g = self.ob.data.bones["Gun"]
        rr = g.matrix_local.inverted() @ b.matrix_local
        d = rr.to_3x3().inverted() @ r2b(Matrix.Translation(pos)).translation
        R = rr.to_3x3().inverted() @ r2b(rb_rot(*rot)).to_3x3() @ rr.to_3x3()
        self.key_basis("P_" + name, t, loc=d, quat=R.to_quaternion(), **kw)

    def inhand(self, part, t, value, **kw):
        """0 = the part rides the gun, 1 = it rides the left hand (its H_ twin)"""
        self.key_prop("P_" + part, "inhand", t, value, **kw)

    def held(self, part, t, pos=(0, 0, 0), rot=(0, 0, 0), **kw):
        """where the left hand holds a carried part: offset from 'as if the gun sat in the left hand', in the left
        hand's own frame (studs; x right, y up the arm, z back; rot pitch/yaw/roll)"""
        r15 = self.r15
        lh = r2b(cf2m(r15["parts"]["LeftHand"]["cf"]))
        Q = lh @ r2b(Matrix.Translation(pos) @ rb_rot(*rot)) @ lh.inverted()
        rest = self.ob.data.bones["H_" + part].matrix_local
        basis = rest.inverted() @ Q @ rest
        loc, q, _ = basis.decompose()
        self.key_basis("H_" + part, t, loc=loc, quat=q, **kw)

    def marker(self, name, t, value=""):
        self.markers.append({"name": name, "t": round(t, 4), "value": value})

    # -- finishing -------------------------------------------------------------------------------------------------
    def finish(self):
        """Apply each key's easing to the segment that starts at it, and make loops cyclic. Easing names follow the
        style card (= Roblox EasingStyle names): "QuartOut", "SineInOut", "CubicIn", "Linear", "Constant", "BackOut:0.8"
        (Back with that overshoot), "Bezier" (auto-clamped smooth). Default: "SineInOut"."""
        for fc in self.act.fcurves:
            dp = fc.data_path
            bone = dp.split('"')[1]
            is_prop = dp.endswith('"]') and dp.count('"') >= 4 and not dp.startswith('pose.bones["%s"].' % bone)
            keyname = bone + "|" + dp.split('"')[3] if dp.count('"') >= 4 and '"]["' in dp else bone
            for kp in fc.keyframe_points:
                it = self.interp.get((keyname, round(kp.co.x, 3))) or self.interp.get((bone, round(kp.co.x, 3)))
                e = it[0] if it else "SineInOut"
                apply_ease(kp, e)
                kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
            if self.loop:
                fc.modifiers.new("CYCLES")
            fc.update()
        sc = bpy.context.scene
        sc.frame_start = 0
        sc.frame_end = int(round(self.length * FPS))


def apply_ease(kp, e):
    e = e or "SineInOut"
    back = None
    if ":" in e:
        e, back = e.split(":")
    if e in ("Bezier", "BEZIER"):
        kp.interpolation = "BEZIER"; return
    if e in ("Linear", "LINEAR"):
        kp.interpolation = "LINEAR"; return
    if e in ("Constant", "CONSTANT"):
        kp.interpolation = "CONSTANT"; return
    for d, bd in (("InOut", "EASE_IN_OUT"), ("In", "EASE_IN"), ("Out", "EASE_OUT")):
        if e.endswith(d):
            style = e[: -len(d)].upper()
            kp.interpolation = style
            kp.easing = bd
            if back is not None and style == "BACK":
                kp.back = float(back)
            return
    raise ValueError("unknown easing " + e)


# ----------------------------------------------------------------------------------------------------------- export
MIRROR = Matrix(((-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def mirror_name(n):
    if n.startswith("Left"):
        return "Right" + n[4:]
    if n.startswith("Right"):
        return "Left" + n[5:]
    return n


def sample(clip, gun_joints=None):
    """Evaluate the rig every frame -> {frame time: {part: Roblox Transform matrix}} plus quality numbers."""
    ob, r15 = clip.ob, clip.r15
    sc = bpy.context.scene
    n = int(round(clip.length * FPS))
    rest_b = {p: ob.data.bones[BONE[p]].matrix_local.copy() for p in BONE}
    P0 = {p: cf2m(r15["parts"][p]["cf"]) for p in r15["parts"]}
    frames = []
    worst = {"ik_gap": 0.0, "pivot_slide": 0.0}
    for i in range(n + 1):
        t = i / FPS
        sc.frame_set(i)
        bpy.context.view_layer.update()
        Pt = {"HumanoidRootPart": P0["HumanoidRootPart"]}
        for p, bn in BONE.items():
            D = b2r(ob.pose.bones[bn].matrix @ rest_b[p].inverted())
            Pt[p] = D @ P0[p]
        tr = {}
        for p in ALL_BODY:
            j = r15["joints"][p]
            T = cf2m(j["C0"]).inverted() @ Pt[j["part0"]].inverted() @ Pt[p] @ cf2m(j["C1"])
            if p != "LowerTorso":
                worst["pivot_slide"] = max(worst["pivot_slide"], T.translation.length)
                T = T.to_3x3().to_4x4()  # rotation only: real avatars keep their own proportions
            tr[p] = T
        # gun parts: Motor6D parent part -> part, C0/C1 at the pivot with no rotation: T = C0^-1 * Wparent^-1 * Wpart
        if gun_joints:
            hrest_r = cf2m(r15["parts"]["RightHand"]["cf"]) @ cf2m(r15["tools"][TOOLNAME]["grip"])
            def W(pn):
                bn = "Gun" if pn == "Handle" else "P_" + pn
                D = b2r(ob.pose.bones[bn].matrix @ ob.data.bones[bn].matrix_local.inverted())
                piv = Vector((0, 0, 0)) if pn == "Handle" else Vector(GUNDEF["parts"][pn]["pivot"])
                return D @ hrest_r @ Matrix.Translation(piv)
            for pn in gun_joints:
                par = GUNDEF["parts"][pn]["parent"]
                T = W(par).inverted() @ W(pn)
                pp = Vector((0, 0, 0)) if par == "Handle" else Vector(GUNDEF["parts"][par]["pivot"])
                # W already includes the pivot frames, so C0 (= pivot - parent pivot) is inside: T is the joint motion
                tr[pn] = Matrix.Translation(-(Vector(GUNDEF["parts"][pn]["pivot"]) - pp)) @ T
        # IK reach check: the gun hand's wrist vs its target
        for s in ("R", "L"):
            ik = ob.pose.bones["IK_Hand." + s].matrix.translation
            wrist = ob.pose.bones["Hand." + s].matrix.translation
            gap = (ik - wrist).length
            if gap > worst.get("ik_gap_" + s, 0.0):
                worst["ik_gap_" + s] = gap
                worst["at_f_" + s] = i
        frames.append((t, tr))
    return frames, worst


def reduce_keys(frames, joints, tol_deg=0.12, tol_pos=0.004):
    """Keep the fewest frames such that linear interpolation between kept frames stays within tolerance."""
    def err(a, b):
        e = 0.0
        for j in joints:
            qa, qb = a[j].to_quaternion(), b[j].to_quaternion()
            e = max(e, math.degrees(qa.rotation_difference(qb).angle) / tol_deg,
                    (a[j].translation - b[j].translation).length / tol_pos)
        return e

    def lerp(a, b, u):
        out = {}
        for j in joints:
            q = a[j].to_quaternion().slerp(b[j].to_quaternion(), u)
            m = q.to_matrix().to_4x4()
            m.translation = a[j].translation.lerp(b[j].translation, u)
            out[j] = m
        return out
    keep = [0]
    i = 0
    n = len(frames)
    while i < n - 1:
        j = i + 2
        while j < n:
            ok = True
            for k in range(i + 1, j):
                u = (frames[k][0] - frames[i][0]) / (frames[j][0] - frames[i][0])
                if err(lerp(frames[i][1], frames[j][1], u), frames[k][1]) > 1.0:
                    ok = False
                    break
            if not ok:
                break
            j += 1
        i = j - 1
        keep.append(i)
    return [frames[k] for k in keep]


def keyed_parts(clip):
    if not GUNDEF:
        return []
    names = set()
    for fc in clip.act.fcurves:
        bn = fc.data_path.split('"')[1]
        if bn.startswith("P_"):
            pn = bn[2:]
            while pn != "Handle":
                names.add(pn)
                pn = GUNDEF["parts"][pn]["parent"]
    return sorted(names, key=lambda n: (n.count("/"), n))


def export_clip(clip, out_dir, gun_joints=None, mirror=False, name=None, extra_keep_times=()):
    gun_joints = keyed_parts(clip) or None
    frames, worst = sample(clip, gun_joints)
    joints = [j for j in clip.joints]
    for j in list(joints):  # parents up to the root
        p = TREE.get(j)
        while p and p != "HumanoidRootPart":
            if p not in joints:
                joints.append(p)
            p = TREE.get(p)
    gun_names = list(gun_joints or [])
    tree = dict(TREE)
    tree["HumanoidRootPart"] = None
    for g in gun_names:
        tree[g] = GUNDEF["parts"][g]["parent"] if GUNDEF else "Handle"
    if gun_names:
        tree["Handle"] = "RightHand"
    all_j = joints + gun_names
    if mirror:
        mf = []
        for t, tr in frames:
            o = {}
            for j, T in tr.items():
                o[mirror_name(j) if j in TREE else j] = (MIRROR @ T @ MIRROR) if j in TREE else T
            mf.append((t, o))
        frames = mf
        joints = [mirror_name(j) for j in joints]
        if gun_names:
            tree["Handle"] = "LeftHand"
        all_j = joints + gun_names
    kept = reduce_keys(frames, all_j)
    times = {round(t, 4) for t, _ in kept}
    for m in clip.markers:  # a key on every marker
        best = min(frames, key=lambda f: abs(f[0] - m["t"]))
        if round(best[0], 4) not in times:
            kept.append(best)
            times.add(round(best[0], 4))
    kept.sort(key=lambda f: f[0])
    keys = []
    for t, tr in kept:
        tt = round(t, 4)
        if gun_names:
            keys.append({"t": tt, "part": "Handle", "cf": m2cf(Matrix())})
        for j in all_j:
            keys.append({"t": tt, "part": j, "cf": m2cf(tr[j])})
    nm = name or (clip.name + ("Left" if mirror else ""))
    body = json.dumps(keys, sort_keys=True)
    h = hashlib.sha1((body + json.dumps(clip.markers, sort_keys=True)).encode()).hexdigest()[:12]
    out = {"name": nm, "length": clip.length, "loop": clip.loop, "priority": clip.priority, "tree": tree,
           "keys": keys, "markers": [{"name": m["name"], "t": min((round(f[0], 4) for f in kept),
                                                                   key=lambda x: abs(x - m["t"])), "value": m["value"]}
                                     for m in clip.markers],
           "attrs": {"SourceHash": h, "Source": "art/anim/weapons/blender (" + clip.name + ")", "Mirrored": mirror},
           "quality": {k: round(v, 4) for k, v in worst.items()}, "nkeys": len(kept)}
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, nm + ".json"), "w") as f:
        json.dump(out, f)
    for k, v in worst.items():
        if k.startswith("ik_gap_") and v > 0.02:
            print("WARN", nm, k, round(v, 3), "at frame", worst.get("at_f_" + k[-1]), "(a hand target is out of reach)")
    if getattr(clip, "reach_moves", 0) > 0.05:
        print("INFO", nm, "gun slid into both hands' reach by up to", round(clip.reach_moves, 2))
    if getattr(clip, "clamped", 0) > 0.05:
        print("INFO", nm, "free-hand targets pulled into reach by up to", round(clip.clamped, 2))
    print("EXPORTED", nm, "frames", len(frames), "keys", len(kept), "quality", out["quality"])
    return out


# ----------------------------------------------------------------------------------------------------------- poses
def fr(n):
    """frame number at 60 fps -> seconds"""
    return n / FPS


BASE_POSE = {
    "root": (0, 0, 0, 0, 0, 0),        # x, y, z, pitch, yaw, roll (LowerTorso)
    "chest": (0, 0, 0),                # Waist: pitch, yaw, roll
    "head": (0, 0, 0),                 # Neck
    "gun": None,                       # (wrist_pos, (pitch, yaw, roll)) of the gun hand; None = not keyed
    "R": ("gun", (0, 0, 0), (0, 0, 0)),  # ("gun", pos, rot) on the item, or ("free", wrist_pos, rot) in chest space
    "L": ("free", (-1.0, -0.6, -0.3), (0, 0, 0)),
    "poleR": (1.6, -0.4, 0.6),
    "poleL": (-1.6, -0.4, 0.6),
    "footR": ((0, 0, 0), (0, 0, 0)),
    "footL": ((0, 0, 0), (0, 0, 0)),
    "parts": {},                       # gun part name -> (pos, rot) relative to its rest in the gun frame
}


def P(base=None, **kw):
    """a pose: a copy of `base` (or BASE_POSE) with the given fields replaced. parts merge."""
    p = dict(BASE_POSE if base is None else base)
    for k, v in kw.items():
        if k == "parts" and base is not None:
            q = dict(base.get("parts", {}))
            q.update(v)
            p[k] = q
        else:
            p[k] = v
    return p


def _lerp(a, b, u):
    if a is None or b is None:
        return b if u >= 0.5 else a
    if isinstance(a, str):
        return a if u < 0.5 else b
    if isinstance(a, (int, float)):
        return a + (b - a) * u
    if isinstance(a, dict):
        return {k: _lerp(a.get(k, ((0, 0, 0), (0, 0, 0))), b.get(k, ((0, 0, 0), (0, 0, 0))), u) for k in set(a) | set(b)}
    return type(a)(_lerp(x, y, u) for x, y in zip(a, b))


def mix(a, b, u):
    """in-between of two poses (hand spaces must match)"""
    return {k: _lerp(a.get(k), b.get(k), u) for k in BASE_POSE}


def add(p, **d):
    """offset numeric fields: add(p, root=(0,-0.05,0,0,0,0), chest=(1,0,0)), gun=((dx,dy,dz),(dp,dyaw,droll))"""
    q = dict(p)
    for k, v in d.items():
        if k == "gun":
            if len(p["gun"]) == 3:
                gp, w, r = p["gun"]
                (dw, dr) = v
                q["gun"] = (gp, tuple(a + b for a, b in zip(w, dw)), tuple(a + b for a, b in zip(r, dr)))
            else:
                (w, r), (dw, dr) = p["gun"], v
                q["gun"] = (tuple(a + b for a, b in zip(w, dw)), tuple(a + b for a, b in zip(r, dr)))
        elif k in ("R", "L"):
            sp, w, r = p[k]
            dw, dr = v
            q[k] = (sp, tuple(a + b for a, b in zip(w, dw)), tuple(a + b for a, b in zip(r, dr)))
        elif k in ("footR", "footL"):
            (w, r), (dw, dr) = p[k], v
            q[k] = (tuple(a + b for a, b in zip(w, dw)), tuple(a + b for a, b in zip(r, dr)))
        else:
            q[k] = tuple(a + b for a, b in zip(p[k], v))
    return q


GROUPS = ("root", "chest", "head", "gun", "R", "L", "poles", "feet", "parts")


def key_pose(c, t, p, ease="SineInOut", only=None):
    """Key every control of pose p at time t (seconds). only = subset of GROUPS (for overlap offsets)."""
    g = set(only or GROUPS)
    kw = {"ease": ease}
    if "root" in g:
        x, y, z, pi, ya, ro = p["root"]
        c.root(t, x=x, y=y, z=z, pitch=pi, yaw=ya, roll=ro, **kw)
    if "chest" in g:
        c.joint_rot("Uppertorso", t, *p["chest"], **kw)
    if "head" in g:
        c.joint_rot("Head", t, *p["head"], **kw)
    if "gun" in g and p["gun"] is not None:
        rot = p["gun"][-1]
        R = (rb_rot(*rot).to_3x3() @ (A.to_3x3() @ LEVEL @ AI.to_3x3()))  # gun frame (Roblox) -> chest (Roblox)
        if len(p["gun"]) == 3:
            H = Vector(p["gun"][1]) - R @ Vector(p["gun"][0])
        else:
            H = Vector(p["gun"][0]) - R @ Vector((0, 0, 0.29))
        H = reach_fix(c, H, R, p)
        c.gun(t, tuple(H), rot, **kw)
    for s in ("R", "L"):
        if s in g:
            space, pos, rot = p[s]
            if space == "gun":
                if s == "L":
                    c.hand_on("L", t, pos, rot, **kw)
                c.free(s, t, 0.0, **kw)
            else:
                c.hand_free(s, t, pos, rot, **kw)
                c.free(s, t, 1.0, **kw)
    if "poles" in g:
        c.pole("R", t, p["poleR"], **kw)
        c.pole("L", t, p["poleL"], **kw)
    if "feet" in g:
        c.foot("R", t, *p["footR"], **kw)
        c.foot("L", t, *p["footL"], **kw)
    if "parts" in g:
        for name, (pos, rot) in p.get("parts", {}).items():
            c.part(name, t, pos, rot, **kw)


def reach_fix(c, H, R, p):
    """slide the gun (Handle position H, chest frame) so both on-gun hands are within 97% reach of their shoulders"""
    reach = 0.97 * (c.ob.data.bones["Upperarm.R"].length + c.ob.data.bones["Lowerarm.R"].length)
    pts = []
    if p["R"][0] == "gun":
        pts.append((Vector(c.anchor["shoulderR"]), Vector((0, 0, 0.29))))
    if p["L"][0] == "gun":
        pts.append((Vector(c.anchor["shoulderL"]), Vector(p["L"][1])))
    moved = 0.0
    for _ in range(40):
        worst = None
        for sh, loc in pts:
            w = H + R @ loc
            over = (w - sh).length - reach
            if over > 0.002 and (worst is None or over > worst[0]):
                worst = (over, (sh - w).normalized())
        if not worst:
            break
        step = worst[1] * (worst[0] + 0.005)
        H = H + step
        moved += step.length
    if moved > 0.01:
        c.reach_moves = max(getattr(c, "reach_moves", 0.0), moved)
    return H


def seq(c, keys, only=None):
    """keys = [(frame, pose, ease_of_the_segment_that_starts_here), ...]"""
    for k in keys:
        f, p = k[0], k[1]
        e = k[2] if len(k) > 2 else "SineInOut"
        key_pose(c, fr(f), p, e, only)
