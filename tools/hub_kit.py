"""Tacticals hub shell kit, pass hub1 (RIVALS style, Tacticals palette). Own geometry only.

Run inside Blender 5.2 (via the Blender MCP):  exec(open(r"C:/Users/aroki/Documents/tacticals_rebuild/tools/hub_kit.py").read())
Everything is authored in STUDIO coordinates (x east, y up, z north, 1 unit = 1 stud) and converted to Blender Z-up with
S2B: Blender (x, y, z) = (-Xs, Zs, Ys), the convention measured in the RIVALS practice (Import 3D maps it back).
Each mesh = <piece>__<material>, one material per mesh, so each MeshPart can be tinted / given its MaterialVariant in Studio.
Never calls read_homefile.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
TEX = ROOT + "/tex/"
S2B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
UV_STUDS = 10.0  # 1 UV unit = 10 studs (box projected, world scale)

# ------------------------------------------------------------------ materials
# name: (sRGB 0-255, colour tex, normal tex, rough tex, studs per tile, metallic, roughness, emissive, studio material / variant)
MATS = {
    "floor_field":   ((62, 62, 60),    "hub_floor_concrete", 20, 0.0, 0.55, False, "Concrete + TacFloorConcrete"),
    "floor_border":  ((36, 36, 34),    "hub_floor_concrete", 20, 0.0, 0.6, False, "Concrete + TacFloorConcrete"),
    "floor_insert":  ((80, 79, 76),    "hub_corrugated_metal", 16, 0.8, 0.5, False, "Metal + TacCorrugatedMetal"),
    "plate_metal":   ((108, 107, 104), "hub_metal_floorplate", 20, 0.8, 0.5, False, "Metal + TacFloorPlate"),
    "disc_plate":    ((75, 75, 72),    "hub_metal_floorplate", 10, 0.8, 0.5, False, "Metal + TacFloorPlate"),
    "disc_center":   ((107, 122, 58),  "hub_metal_satin", 10, 0.3, 0.5, False, "SmoothPlastic (dark olive paint)"),
    "wall_body":     ((107, 106, 102), "hub_concrete_panels", 20, 0.0, 0.8, False, "Concrete + TacConcretePanels"),
    "wall_light":    ((120, 119, 115), "hub_concrete_smooth", 12, 0.0, 0.8, False, "Concrete + TacConcrete"),
    "wall_plate":    ((102, 101, 97),  "hub_concrete_panels", 20, 0.0, 0.78, False, "Concrete + TacConcretePanels"),
    "wall_kick":     ((88, 87, 83),    "hub_concrete_smooth", 12, 0.0, 0.8, False, "Concrete + TacConcrete"),
    "wall_dark":     ((79, 78, 74),    "hub_concrete_smooth", 12, 0.0, 0.8, False, "Concrete + TacConcrete"),
    "wall_upper":    ((141, 140, 134), "hub_corrugated_fine", 10, 0.0, 0.72, False, "Concrete + TacRibbed"),
    "band_olive":    ((138, 156, 74),  "hub_concrete_smooth", 12, 0.0, 0.7, False, "Concrete + TacConcrete (olive paint)"),
    "trim_metal":    ((108, 107, 104), "hub_metal_satin", 10, 0.85, 0.42, False, "Metal + TacMetal"),
    "trim_light":    ((124, 123, 119), "hub_metal_satin", 10, 0.85, 0.42, False, "Metal + TacMetal"),
    "beam_metal":    ((67, 67, 65),    "hub_metal_satin", 10, 0.85, 0.45, False, "Metal + TacMetal"),
    "dark_metal":    ((48, 48, 46),    "hub_metal_satin", 10, 0.85, 0.5, False, "Metal + TacMetal"),
    "door_leaf":     ((72, 72, 70),    "hub_corrugated_metal", 16, 0.35, 0.5, False, "Metal + TacCorrugatedMetal"),
    "stair":         ((94, 93, 89),    "hub_concrete_smooth", 12, 0.0, 0.8, False, "Concrete + TacConcrete"),
    "ceiling":       ((112, 111, 107), "hub_concrete_smooth", 12, 0.0, 0.85, False, "Concrete + TacConcrete"),
    "ceiling_gloss": ((66, 68, 62),    None, 10, 0.2, 0.25, False, "SmoothPlastic / Pearlescent-style variant"),
    "glass":         ((150, 190, 215), None, 10, 0.0, 0.05, False, "Glass, Transparency 0.6"),
    "void":          ((10, 12, 10),    None, 10, 0.0, 1.0, False, "Neon 10,12,10 (black void)"),
    "neon_lamp":     ((161, 157, 145), None, 10, 0.0, 0.5, True, "Neon"),
    "neon_cream":    ((180, 177, 166), None, 10, 0.0, 0.5, True, "Neon"),
    "neon_olive":    ((107, 122, 58),  None, 10, 0.0, 0.5, True, "Neon"),
    "label_cream":   ((236, 232, 218), None, 10, 0.0, 0.6, False, "SmoothPlastic (SurfaceGui text later)"),
    "sign_board":    ((39, 40, 37),    None, 10, 0.0, 0.6, False, "SmoothPlastic"),
    "hazard":        ((255, 255, 255), "hub_hazard_stripe", 4, 0.0, 0.7, False, "SmoothPlastic + Texture hub_hazard_stripe"),
    "grate":         ((22, 23, 21),    None, 10, 0.5, 0.7, False, "SmoothPlastic near-black + Texture hub_grate_alpha"),
    "crate_green":   ((65, 94, 56),    "hub_concrete_smooth", 6, 0.0, 0.65, False, "SmoothPlastic (military green)"),
    "case_dark":     ((48, 49, 46),    None, 10, 0.0, 0.55, False, "SmoothPlastic"),
    "screen":        ((18, 22, 20),    None, 10, 0.0, 0.15, False, "Glass / SurfaceGui screen"),
    "drum_olive":    ((107, 122, 58),  "hub_metal_satin", 10, 0.5, 0.5, False, "Metal (dark olive paint)"),
}
TILED = {  # which tex use colour/normal/rough triplets
    "hub_floor_concrete": ("color", "normal", "rough"), "hub_corrugated_metal": ("color", "normal", "rough"),
    "hub_metal_floorplate": ("color", "normal", "rough"), "hub_metal_satin": ("color", "normal", "rough"),
    "hub_concrete_panels": ("color", "normal", "rough"), "hub_concrete_smooth": ("color", "normal", "rough"),
    "hub_corrugated_fine": ("color", "normal", "rough"),
}

def srgb2lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def get_img(path, noncolor=False):
    name = os.path.basename(path)
    im = bpy.data.images.get(name)
    if im is None:
        im = bpy.data.images.load(path)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    return im

def make_material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    rgb, tex, spt, metal, rough, emis, studio = MATS[name]
    lin = [srgb2lin(v) for v in rgb]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; N = nt.nodes; L = nt.links
    bsdf = N.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*lin, 1)
    if emis:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = 6.0
    if name == "glass":
        bsdf.inputs["Alpha"].default_value = 0.35
        bsdf.inputs["Transmission Weight"].default_value = 0.6
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    if tex:
        uv = N.new("ShaderNodeTexCoord"); mp = N.new("ShaderNodeMapping")
        s = UV_STUDS / spt
        mp.inputs["Scale"].default_value = (s, s, s)
        L.new(uv.outputs["UV"], mp.inputs["Vector"])
        if tex == "hub_hazard_stripe":
            ic = N.new("ShaderNodeTexImage"); ic.image = get_img(TEX + "hub_hazard_stripe.png")
            mp.inputs["Scale"].default_value = (s, s * 4, s)
            L.new(mp.outputs["Vector"], ic.inputs["Vector"]); L.new(ic.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            ic = N.new("ShaderNodeTexImage"); ic.image = get_img(TEX + tex + "_color.png")
            mix = N.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs[6].default_value = (*lin, 1)
            L.new(mp.outputs["Vector"], ic.inputs["Vector"])
            L.new(ic.outputs["Color"], mix.inputs[7]); L.new(mix.outputs[2], bsdf.inputs["Base Color"])
            inn = N.new("ShaderNodeTexImage"); inn.image = get_img(TEX + tex + "_normal.png", True)
            nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.0
            L.new(mp.outputs["Vector"], inn.inputs["Vector"]); L.new(inn.outputs["Color"], nm.inputs["Color"])
            L.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
            rp = TEX + tex + "_rough.png"
            if os.path.exists(rp):
                ir = N.new("ShaderNodeTexImage"); ir.image = get_img(rp, True)
                L.new(mp.outputs["Vector"], ir.inputs["Vector"]); L.new(ir.outputs["Color"], bsdf.inputs["Roughness"])
    m["studio"] = studio
    m["rgb"] = list(rgb)
    return m

# ------------------------------------------------------------------ geometry accumulators
ACC = {}
def acc(piece, mat):
    k = (piece, mat)
    if k not in ACC:
        ACC[k] = bmesh.new()
    return ACC[k]

def box(piece, mat, x0, x1, y0, y1, z0, z1, bev=0.1, seg=1):
    x0, x1 = sorted((x0, x1)); y0, y1 = sorted((y0, y1)); z0, z1 = sorted((z0, z1))
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    if min(sx, sy, sz) <= 1e-4:
        return
    bm = acc(piece, mat)
    M = Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) @ Matrix.Diagonal((sx, sy, sz, 1))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    b = min(bev, min(sx, sy, sz) * 0.45)
    if b > 0.005:
        edges = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=b, offset_type="OFFSET", segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)

def prism(piece, mat, pts, ext):
    """pts: planar closed polygon (list of 3-tuples, studio coords); ext: extrusion vector."""
    bm = acc(piece, mat)
    ext = Vector(ext)
    a = [bm.verts.new(Vector(p)) for p in pts]
    b = [bm.verts.new(Vector(p) + ext) for p in pts]
    n = len(pts)
    bm.faces.new(a[::-1]); bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))

def chamfer_poly(poly, c):
    out = []
    n = len(poly)
    for i in range(n):
        p = Vector(poly[i]); pp = Vector(poly[i - 1]); pn = Vector(poly[(i + 1) % n])
        d1 = (pp - p); d2 = (pn - p)
        cc = min(c, d1.length * 0.45, d2.length * 0.45)
        out.append(tuple(p + d1.normalized() * cc)); out.append(tuple(p + d2.normalized() * cc))
    return out

def lathe(piece, mat, prof, cx=0.0, cz=0.0, seg=64, a0=0.0, a1=2 * math.pi, y0=0.0):
    """Revolve a closed (r, y) profile about the vertical axis at (cx, cz). Partial sweeps get end caps."""
    bm = acc(piece, mat)
    full = abs((a1 - a0) - 2 * math.pi) < 1e-6
    steps = seg if full else max(2, int(seg * (a1 - a0) / (2 * math.pi)) + 1)
    rings = []
    count = steps if full else steps + 1
    for i in range(count):
        a = a0 + (a1 - a0) * i / steps
        ca, sa = math.cos(a), math.sin(a)
        rings.append([bm.verts.new((cx + r * ca, y0 + y, cz + r * sa)) for (r, y) in prof])
    n = len(prof)
    for i in range(steps):
        A = rings[i]; B = rings[(i + 1) % count] if full else rings[i + 1]
        for k in range(n):
            l = (k + 1) % n
            bm.faces.new((A[k], A[l], B[l], B[k]))
    if not full:
        bm.faces.new(rings[0]); bm.faces.new(rings[-1][::-1])

def cyl(piece, mat, cx, cz, r, y0, y1, seg=32, bev=0.08):
    bm = acc(piece, mat)
    M = Matrix.Translation((cx, (y0 + y1) / 2, cz)) @ Matrix.Rotation(math.radians(90), 4, "X")
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=y1 - y0, matrix=M)
    if bev > 0:
        vs = ret["verts"]
        edges = [e for e in {e for v in vs for e in v.link_edges} if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-5]
        bmesh.ops.bevel(bm, geom=edges, offset=min(bev, r * 0.3, (y1 - y0) * 0.3), offset_type="OFFSET", segments=1,
                        profile=0.5, affect="EDGES", clamp_overlap=True)

def rod(piece, mat, p0, p1, r, seg=8):
    bm = acc(piece, mat)
    p0 = Vector(p0); p1 = Vector(p1); d = p1 - p0
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    M = Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length, matrix=M)

# ------------------------------------------------------------------ wall frames
class Wall:
    """along: 'x' or 'z'; face: coordinate of the inner wall face; inw: +1/-1 direction into the room."""
    def __init__(self, along, face, inw):
        self.along, self.face, self.inw = along, face, inw
    def p(self, s, y, d):
        n = self.face + self.inw * d
        return (s, y, n) if self.along == "x" else (n, y, s)
    def box(self, piece, mat, s0, s1, y0, y1, d0, d1, bev=0.1, seg=1):
        a = self.p(s0, y0, d0); b = self.p(s1, y1, d1)
        box(piece, mat, a[0], b[0], a[1], b[1], a[2], b[2], bev, seg)
    def prism(self, piece, mat, poly_dy, s0, s1):
        pts = [self.p(s0, y, d) for (d, y) in poly_dy]
        e = Vector(self.p(s1, 0, 0)) - Vector(self.p(s0, 0, 0))
        prism(piece, mat, pts, e)

WN = Wall("x", 44.0, -1); WS = Wall("x", -44.0, +1)
WE = Wall("z", 88.0, -1); WW = Wall("z", -90.0, +1)
BAY = 13.75
PIL = [0.5 * BAY + BAY * k for k in range(6)]          # 6.875 ... 75.625
PIL = sorted([-p for p in PIL] + PIL)

# ------------------------------------------------------------------ long wall run (zones)
def wall_zones(W, piece, s0, s1, ymin=0.0, skip_low=None):
    """Horizontal zone strips between s0..s1. skip_low=(a,b): leave the y<ymin_cut zones open there."""
    T = 5.0
    if ymin < 7:
        W.box(piece, "wall_kick", s0, s1, max(0, ymin), 7.0, -T, 0.4, 0.12)
        W.box(piece, "trim_metal", s0, s1, 0.0, 0.8, 0.3, 0.75, 0.12) if ymin <= 0 else None
    if ymin < 10:
        W.box(piece, "band_olive", s0, s1, 7.1, 9.9, -T, 0.55, 0.12)
        W.box(piece, "trim_metal", s0, s1, 6.85, 7.15, -T, 0.68, 0.06)
        W.box(piece, "trim_metal", s0, s1, 9.85, 10.15, -T, 0.68, 0.06)
    W.box(piece, "wall_body", s0, s1, max(10.0, ymin), 30.0, -T, 0.0, 0.1)
    W.box(piece, "wall_dark", s0, s1, 30.0, 36.0, -T, 0.25, 0.12)
    W.box(piece, "trim_light", s0, s1, 35.8, 36.3, -T, 0.45, 0.08)
    W.box(piece, "wall_upper", s0, s1, 36.0, 52.0, -T, 0.0, 0.1)
    # canted cornice 52..58 (chamfered curve toward the room), then top fill to the roof
    prof = [(-T, 52.0), (0.0, 52.0), (0.9, 54.6), (2.2, 56.6), (3.6, 57.6), (3.6, 58.4), (-T, 58.4)]
    W.prism(piece, "wall_light", prof, s0, s1)
    W.box(piece, "trim_metal", s0, s1, 58.4, 59.0, -T, 3.9, 0.1)
    W.box(piece, "wall_dark", s0, s1, 59.0, 68.0, -T, 3.4, 0.1)

def wall_plates(W, piece, s0, s1, y0=10.6, y1=29.4):
    """2 x 2 proud concrete plates per bay on the body zone."""
    w = s1 - s0
    if w < 3:
        return
    sm = (s0 + s1) / 2; ym = (y0 + y1) / 2
    for (a, b) in ((s0 + 1.55, sm - 0.15), (sm + 0.15, s1 - 1.55)):
        for (c, d) in ((y0, ym - 0.15), (ym + 0.15, y1)):
            W.box(piece, "wall_plate", a, b, c, d, -0.5, 0.25, 0.12)

def window_upper(W, piece, s0, s1):
    """Recessed sky slot window in the ribbed upper band (frame + glass + mullions), proud frame, no booleans."""
    sm = (s0 + s1) / 2; hw = min(4.2, (s1 - s0) / 2 - 2.0)
    y0, y1 = 40.0, 47.0
    W.box(piece, "trim_metal", sm - hw - 0.6, sm + hw + 0.6, y0 - 0.6, y0, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - hw - 0.6, sm + hw + 0.6, y1, y1 + 0.6, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - hw - 0.6, sm - hw, y0, y1, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm + hw, sm + hw + 0.6, y0, y1, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - 0.2, sm + 0.2, y0, y1, -0.1, 0.3, 0.06)
    W.box(piece, "glass", sm - hw, sm + hw, y0, y1, 0.02, 0.12, 0.0)

def pilaster(W, piece, s, ytop=58.0, ybase=0.0, light=True, band=True):
    W.box(piece, "wall_light", s - 1.3, s + 1.3, ybase, ytop, -1.0, 1.8, 0.3, 2)
    if ybase <= 0:
        W.box(piece, "trim_metal", s - 1.55, s + 1.55, 0.0, 2.2, -1.0, 2.1, 0.15, 1)
    if band:
        W.box(piece, "band_olive", s - 1.45, s + 1.45, 7.1, 9.9, -1.0, 1.95, 0.12)
    # corbel under the catwalk
    W.box(piece, "trim_metal", s - 1.6, s + 1.6, 28.8, 30.4, -1.0, 2.4, 0.15)
    # knee brace (triangular, metal) from the pilaster up to the deck edge
    W.prism(piece, "beam_metal", [(1.8, 23.0), (1.8, 30.4), (3.9, 30.4), (3.9, 29.6)], s - 0.35, s + 0.35)
    # upper capital where the roof beam lands
    W.box(piece, "trim_metal", s - 1.7, s + 1.7, 57.0, 58.6, -1.0, 2.4, 0.15)
    if light:
        wall_light(W, s, 1.8, 14.2)

def wall_light(W, s, d, yc, piece="H_WallLights"):
    """RIVALS-manner capsule: metal housing, Neon capsule split by two dark straps."""
    W.box(piece, "trim_metal", s - 0.85, s + 0.85, yc - 3.2, yc + 3.2, d - 0.1, d + 0.45, 0.18, 2)
    W.box(piece, "neon_lamp", s - 0.5, s + 0.5, yc - 2.8, yc + 2.8, d + 0.3, d + 0.75, 0.24, 3)
    for yy in (yc - 0.9, yc + 0.9):
        W.box(piece, "dark_metal", s - 0.62, s + 0.62, yy - 0.16, yy + 0.16, d + 0.25, d + 0.85, 0.05)

def service_door(W, piece, sc):
    """Shop-front style service door in a ground bay: frame, slatted leaf, olive datum stripe, label plate."""
    W.box(piece, "wall_light", sc - 5.8, sc - 4.6, 0, 11.8, 0.3, 1.4, 0.18, 2)
    W.box(piece, "wall_light", sc + 4.6, sc + 5.8, 0, 11.8, 0.3, 1.4, 0.18, 2)
    W.box(piece, "wall_light", sc - 5.8, sc + 5.8, 10.4, 11.8, 0.3, 1.4, 0.18, 2)
    W.box(piece, "trim_metal", sc - 4.6, sc - 4.3, 0, 10.4, 0.3, 1.1, 0.05)
    W.box(piece, "trim_metal", sc + 4.3, sc + 4.6, 0, 10.4, 0.3, 1.1, 0.05)
    W.box(piece, "trim_metal", sc - 4.6, sc + 4.6, 10.1, 10.4, 0.3, 1.1, 0.05)
    for i in range(4):
        y0 = 0.05 + i * 2.5
        W.box(piece, "door_leaf", sc - 4.3, sc + 4.3, y0, y0 + 2.4, 0.4, 0.75, 0.1)
    W.box(piece, "band_olive", sc - 4.3, sc + 4.3, 7.1, 9.9, 0.4, 0.85, 0.08)
    W.box(piece, "dark_metal", sc - 1.3, sc + 1.3, 3.6, 4.3, 0.7, 1.0, 0.08)  # handle bar
    W.box(piece, "label_cream", sc - 2.0, sc + 2.0, 12.4, 13.4, 0.0, 0.25, 0.06)
    W.box(piece, "neon_olive", sc - 3.0, sc + 3.0, 11.8, 12.0, 0.9, 1.2, 0.0)  # status strip under the label
    # hazard kerb on the floor in front of the door
    W.box("H_Floor", "hazard", sc - 4.3, sc + 4.3, 0.0, 0.06, 1.4, 2.4, 0.0)

def vent_bay(W, piece, sc):
    W.box(piece, "trim_metal", sc - 4.8, sc + 4.8, 1.0, 5.8, 0.3, 0.9, 0.15)
    W.box(piece, "void", sc - 4.3, sc + 4.3, 1.4, 5.4, 0.85, 0.95, 0.0)
    for i in range(7):
        y = 1.6 + i * 0.55
        W.box(piece, "dark_metal", sc - 4.3, sc + 4.3, y, y + 0.28, 0.9, 1.25, 0.04)
    W.box(piece, "trim_metal", sc - 0.15, sc + 0.15, 1.4, 5.4, 0.9, 1.3, 0.03)
    # pipe run above the vent (two pipes with brackets) for depth
    for k, yy in enumerate((24.5, 26.0)):
        a = W.p(sc - 6.2, yy, 1.2 + 0.0 * k); b = W.p(sc + 6.2, yy, 1.2)
        rod(piece, "trim_light", a, b, 0.42, 12)
    for ss in (sc - 4.0, sc + 4.0):
        W.box(piece, "dark_metal", ss - 0.25, ss + 0.25, 23.6, 26.8, 0.0, 1.9, 0.05)

# ------------------------------------------------------------------ build: long walls
def build_long_wall(W, tag):
    piece = "H_Wall" + tag
    X0, X1 = -90.0, 88.0
    # zones left and right of the gate bay, then the gate bay above the portal
    wall_zones(W, piece, X0, -5.7)
    wall_zones(W, piece, 5.7, X1)
    W.box(piece, "wall_body", -5.7, 5.7, 17.0, 30.0, -5.0, 0.0, 0.1)
    # top zones over the gate bay are covered by the two runs? no: runs stop at +-5.7, fill the middle
    W.box(piece, "wall_dark", -5.7, 5.7, 30.0, 36.0, -5.0, 0.25, 0.12)
    W.box(piece, "wall_upper", -5.7, 5.7, 36.0, 52.0, -5.0, 0.0, 0.1)
    edges = [X0] + PIL + [X1]
    for i in range(len(edges) - 1):
        s0, s1 = edges[i], edges[i + 1]
        sc = (s0 + s1) / 2
        if abs(sc) < 1:
            continue  # gate bay
        wall_plates(W, piece, s0, s1)
        if (i % 2) == 0:
            window_upper(W, piece, s0, s1)
        else:
            # ribbed upper band gets a slim horizontal Neon line at 50 instead of a window
            W.box("H_WallLights", "neon_lamp", s0 + 2.2, s1 - 2.2, 49.2, 49.5, 0.0, 0.3, 0.0)
        a = abs(sc)
        if sc < -82:  # west-end bay is behind the landing/stairs
            continue
        if abs(a - 13.75) < 1 or abs(a - 41.25) < 1 or abs(a - 68.75) < 1:
            service_door(W, "H_Bays" + tag, sc)
        else:
            vent_bay(W, "H_Bays" + tag, sc)
    for s in PIL:
        if abs(s) < 7:
            continue  # gate cheeks replace these
        pilaster(W, "H_Pilasters", s)
    # corner columns
    pilaster(W, "H_Pilasters", 86.4, light=False)

# ------------------------------------------------------------------ gates N / S (10.8 x 12.2 opening, band crosses the head)
def build_gate(W, tag):
    piece = "H_Gate" + tag
    T = 5.0
    # cheeks and head (light concrete), proud 2.6
    for sg in (-1, 1):
        a, b = sorted((sg * 5.7, sg * 9.8))
        W.box(piece, "wall_light", a, b, 0.0, 17.6, -T, 2.6, 0.35, 2)
        W.box(piece, "trim_metal", a - 0.1, b + 0.1, 0.0, 2.4, -T, 2.9, 0.15)  # plinth
        W.box(piece, "band_olive", a, b, 7.1, 9.9, -T, 2.75, 0.12)            # wall datum wraps the cheek
    W.box(piece, "wall_light", -9.8, 9.8, 12.2, 17.6, -T, 2.6, 0.35, 2)
    # band across the door head (the datum steps over the opening)
    W.box(piece, "band_olive", -9.8, 9.8, 13.2, 16.2, -T, 2.8, 0.12)
    W.box(piece, "trim_metal", -9.9, 9.9, 12.95, 13.25, -T, 2.9, 0.05)
    W.box(piece, "trim_metal", -9.9, 9.9, 16.15, 16.45, -T, 2.9, 0.05)
    # metal reveal lining through the opening (clear width 10.8)
    for sg in (-1, 1):
        a, b = sorted((sg * 5.4, sg * 5.7))
        W.box(piece, "trim_metal", a, b, 0.0, 12.2, -T, 2.6, 0.05)
        # chamfer haunch at the top corners
        s_in = sg * 5.4
        poly = [(s_in, 12.2), (s_in - sg * 1.4, 12.2), (s_in, 10.8)]
        pts = [W.p(sv, yv, 2.6) for (sv, yv) in poly]
        prism(piece, "trim_metal", pts, Vector(W.p(0, 0, -T)) - Vector(W.p(0, 0, 2.6)))
    W.box(piece, "trim_metal", -5.7, 5.7, 12.2, 12.5, -T, 2.6, 0.05)
    # threshold plate + hazard strips
    W.box(piece, "plate_metal", -5.4, 5.4, -0.1, 0.05, -T, 2.6, 0.03)
    W.box(piece, "hazard", -5.4, 5.4, 0.0, 0.08, 2.0, 2.6, 0.0)
    # sign board above (text by SurfaceGui later), dark-olive Neon outline, cream label plate
    W.box("H_Signs", "sign_board", -8.0, 8.0, 18.6, 23.0, -0.5, 0.9, 0.2, 2)
    for (a, b, c, d) in ((-8.0, 8.0, 18.6, 18.85), (-8.0, 8.0, 22.75, 23.0), (-8.0, -7.75, 18.6, 23.0), (7.75, 8.0, 18.6, 23.0)):
        W.box("H_Signs", "neon_olive", a, b, c, d, 0.9, 1.05, 0.0)
    W.box("H_Signs", "label_cream", -3.2, 3.2, 17.7, 18.4, 2.0, 2.2, 0.05)
    # wall lights flanking the gate
    for sg in (-1, 1):
        wall_light(W, sg * 11.6, 0.0, 14.2)

# ------------------------------------------------------------------ east end: tunnel portal 22 x 18 + tunnel lining
def build_east():
    W = WE; piece = "H_WallE"
    wall_zones(W, piece, -44.0, -11.0)
    wall_zones(W, piece, 11.0, 44.0)
    W.box(piece, "wall_body", -11.0, 11.0, 24.0, 30.0, -5.0, 0.0, 0.1)
    W.box(piece, "wall_dark", -11.0, 11.0, 30.0, 36.0, -5.0, 0.25, 0.12)
    W.box(piece, "wall_upper", -11.0, 11.0, 36.0, 52.0, -5.0, 0.0, 0.1)
    for (s0, s1) in ((-44.0, -27.5), (-27.5, -15.6), (15.6, 27.5), (27.5, 44.0)):
        wall_plates(W, piece, s0, s1)
    for s in (-27.5, 27.5):
        pilaster(W, "H_Pilasters", s)
    P = "H_TunnelPortal"
    for sg in (-1, 1):
        a, b = sorted((sg * 11.0, sg * 15.6))
        W.box(P, "wall_light", a, b, 0.0, 24.6, -5.0, 3.0, 0.4, 2)
        W.box(P, "trim_metal", a - 0.1, b + 0.1, 0.0, 2.4, -5.0, 3.3, 0.15)
        W.box(P, "band_olive", a, b, 7.1, 9.9, -5.0, 3.15, 0.12)
        poly = [(sg * 11.0, 18.0), (sg * 8.4, 18.0), (sg * 11.0, 15.4)]
        prism(P, "trim_metal", [W.p(sv, yv, 3.0) for (sv, yv) in poly], Vector(W.p(0, 0, -5.0)) - Vector(W.p(0, 0, 3.0)))
    W.box(P, "wall_light", -15.6, 15.6, 18.3, 24.6, -5.0, 3.0, 0.4, 2)
    W.box(P, "band_olive", -15.6, 15.6, 19.6, 22.6, -5.0, 3.2, 0.12)
    W.box(P, "trim_metal", -15.7, 15.7, 19.35, 19.65, -5.0, 3.3, 0.05)
    W.box(P, "trim_metal", -15.7, 15.7, 22.55, 22.85, -5.0, 3.3, 0.05)
    W.box(P, "trim_metal", -11.0, 11.0, 18.0, 18.3, -5.0, 3.0, 0.05)
    W.box("H_Signs", "sign_board", -9.0, 9.0, 25.2, 29.6, -0.5, 3.4, 0.2, 2)
    for (a, b, c, d) in ((-9.0, 9.0, 25.2, 25.45), (-9.0, 9.0, 29.35, 29.6), (-9.0, -8.75, 25.2, 29.6), (8.75, 9.0, 25.2, 29.6)):
        W.box("H_Signs", "neon_olive", a, b, c, d, 3.4, 3.55, 0.0)
    # tunnel lining x 88..104 (clear 22.4 wide x 18 high)
    T = "H_Tunnel"
    box(T, "plate_metal", 88.0, 104.0, -0.2, 0.0, -11.2, 11.2, 0.03)
    box(T, "floor_border", 88.0, 104.0, -0.2, 0.02, -11.2, -9.6, 0.0)
    box(T, "floor_border", 88.0, 104.0, -0.2, 0.02, 9.6, 11.2, 0.0)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 11.2, sg * 13.0))
        box(T, "door_leaf", 88.0, 104.0, 0.0, 19.6, z0, z1, 0.05)               # corrugated cladding (TacCorrugatedMetal)
        za, zb = sorted((sg * 11.0, sg * 11.6))
        box(T, "band_olive", 88.0, 104.0, 7.1, 9.9, za, zb, 0.08)
        box(T, "trim_metal", 88.0, 104.0, 0.0, 1.0, za, zb, 0.08)
        box(T, "neon_cream", 88.0, 104.0, 0.0, 0.06, sg * 8.4 - 0.19, sg * 8.4 + 0.19, 0.0)
    box(T, "door_leaf", 88.0, 104.0, 19.2, 20.4, -13.0, 13.0, 0.05)
    for x in (90.0, 94.0, 98.0, 102.0):  # ring frames (posts + header)
        for sg in (-1, 1):
            z0, z1 = sorted((sg * 11.2, sg * 10.9))
            box(T, "beam_metal", x - 0.5, x + 0.5, 0.0, 19.2, z0, z1, 0.08)
        box(T, "beam_metal", x - 0.5, x + 0.5, 18.4, 19.2, -11.2, 11.2, 0.08)
        for sg in (-1, 1):  # corner gussets (outside the 22 x 18 clear box)
            prism(T, "beam_metal", [(x - 0.4, 18.4, sg * 10.9), (x - 0.4, 17.0, sg * 10.9), (x - 0.4, 18.4, sg * 9.5)], (0.8, 0, 0))
    for zz in (-4.0, 4.0):
        box(T, "trim_metal", 88.5, 103.5, 18.25, 18.45, zz - 0.8, zz + 0.8, 0.05)
        box(T, "neon_lamp", 88.7, 103.3, 18.05, 18.25, zz - 0.5, zz + 0.5, 0.0)
    # outer end frame at the hangar side
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 11.2, sg * 14.0))
        box(T, "wall_light", 103.0, 105.0, 0.0, 21.0, z0, z1, 0.3, 2)
    box(T, "wall_light", 103.0, 105.0, 18.0, 21.0, -14.0, 14.0, 0.3, 2)

# ------------------------------------------------------------------ west end: riser, landing, twin stairs, top landing, Duels door
def build_west():
    W = WW
    # west wall above the landing (stairs sit in front of it)
    piece = "H_WallW"
    for (s0, s1) in ((-44.0, -5.5), (5.5, 44.0)):
        W.box(piece, "wall_kick", s0, s1, 0.0, 16.0, -5.0, 0.0, 0.1)
        W.box(piece, "band_olive", s0, s1, 19.1, 21.9, -5.0, 0.5, 0.12)   # datum re-based to the y16 deck (7..10 above it is 23..26 -> keep at door head)
        W.box(piece, "wall_body", s0, s1, 16.0, 30.0, -5.0, 0.0, 0.1)
    W.box(piece, "wall_body", -5.5, 5.5, 24.0, 30.0, -5.0, 0.0, 0.1)
    W.box(piece, "wall_dark", -44.0, 44.0, 30.0, 36.0, -5.0, 0.25, 0.12)
    W.box(piece, "wall_upper", -44.0, 44.0, 36.0, 52.0, -5.0, 0.0, 0.1)
    prof = [(-5.0, 52.0), (0.0, 52.0), (0.9, 54.6), (2.2, 56.6), (3.6, 57.6), (3.6, 58.4), (-5.0, 58.4)]
    W.prism(piece, "wall_light", prof, -44.0, 44.0)
    W.box(piece, "trim_metal", -44.0, 44.0, 58.4, 59.0, -5.0, 3.9, 0.1)
    W.box(piece, "wall_dark", -44.0, 44.0, 59.0, 68.0, -5.0, 3.4, 0.1)
    for (s0, s1) in ((-44.0, -27.5), (-27.5, -12.0), (12.0, 27.5), (27.5, 44.0)):
        wall_plates(W, piece, s0, s1, 22.6, 29.4)
        window_upper(W, piece, s0, s1)
    for s in (-27.5, 27.5):
        pilaster(W, "H_Pilasters", s, ybase=16.0, light=False, band=False)
        wall_light(W, s, 1.8, 26.0)
    # Duels door portal (11 wide x 8 clear, y 16..24)
    P = "H_DuelsDoor"
    for sg in (-1, 1):
        a, b = sorted((sg * 5.8, sg * 8.8))
        W.box(P, "wall_light", a, b, 16.0, 28.4, -5.0, 2.2, 0.3, 2)
    W.box(P, "wall_light", -8.8, 8.8, 24.3, 28.4, -5.0, 2.2, 0.3, 2)
    W.box(P, "band_olive", -8.8, 8.8, 24.8, 27.6, -5.0, 2.4, 0.12)
    W.box(P, "trim_metal", -5.8, 5.8, 24.0, 24.3, -5.0, 2.2, 0.05)
    for sg in (-1, 1):
        a, b = sorted((sg * 5.5, sg * 5.8))
        W.box(P, "trim_metal", a, b, 16.0, 24.0, -5.0, 2.2, 0.05)
    W.box(P, "hazard", -5.5, 5.5, 16.0, 16.08, 0.6, 1.6, 0.0)
    W.box("H_Signs", "label_cream", -3.0, 3.0, 28.8, 29.6, 0.0, 0.3, 0.05)

    # landing block y 0..4, x -90..-78, full length
    L = "H_Landing"
    box(L, "stair", -90.0, -78.0, 0.0, 3.8, -44.0, -8.0, 0.1)
    box(L, "stair", -90.0, -78.0, 0.0, 3.8, 8.0, 44.0, 0.1)
    box(L, "stair", -90.0, -78.0, 0.0, 3.8, -8.0, 8.0, 0.1)
    box(L, "plate_metal", -90.0, -78.4, 3.8, 4.0, -44.0, 44.0, 0.04)
    box(L, "trim_metal", -78.6, -77.9, 3.4, 4.05, -44.0, -8.0, 0.08)
    box(L, "trim_metal", -78.6, -77.9, 3.4, 4.05, 8.0, 44.0, 0.08)
    # landing front: olive band would sit 7..10 above hub floor = on the guard; use a kick split instead
    box(L, "wall_kick", -78.2, -77.7, 0.0, 3.4, -44.0, -8.0, 0.08)
    box(L, "wall_kick", -78.2, -77.7, 0.0, 3.4, 8.0, 44.0, 0.08)
    box(L, "neon_cream", -77.75, -77.6, 2.2, 2.45, -44.0, -9.0, 0.0)
    box(L, "neon_cream", -77.75, -77.6, 2.2, 2.45, 9.0, 44.0, 0.0)
    # guard rail along the landing edge (except the riser)
    for (z0, z1) in ((-44.0, -8.6), (8.6, 44.0)):
        railing("H_Landing", (-78.4, 4.0, z0), (-78.4, 4.0, z1), 3.4)

    # riser: 3 steps 0 -> 4 at x -78..-72, z -8..8, metal nosings, side kerbs
    R = "H_Riser"
    for k in range(3):
        top = 4.0 * (k + 1) / 3.0
        xa = -72.0 - 2.0 * (k + 1); xb = -72.0 - 2.0 * k
        box(R, "stair", -78.0, xb, 0.0, top - 0.12, -8.0, 8.0, 0.08)
        box(R, "trim_metal", xb - 0.45, xb + 0.05, top - 0.25, top, -8.0, 8.0, 0.06)
        box(R, "dark_metal", xb - 0.42, xb, top - 0.02, top + 0.02, -7.6, 7.6, 0.0)
        box(R, "plate_metal", -78.0, xb - 0.45, top - 0.12, top, -8.0, 8.0, 0.03)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 8.0, sg * 8.8))
        prism(R, "wall_kick", [(-72.0, 0.0, z0), (-78.0, 0.0, z0), (-78.0, 4.6, z0), (-71.6, 0.6, z0)], (0, 0, z1 - z0))
        box(R, "neon_cream", -77.6, -72.2, 0.0, 0.06, sg * 7.5 - 0.19, sg * 7.5 + 0.19, 0.0)

    # twin stairs x -90..-86: y4 at z +-40 up to y16 at z +-10 (12 x 1-stud risers, 2.5 going)
    S = "H_Stairs"
    for sg in (-1, 1):
        for k in range(1, 13):
            za = sg * (40.0 - 2.5 * k); zb = sg * (40.0 - 2.5 * (k - 1))
            top = 4.0 + k
            z0, z1 = sorted((za, zb))
            box(S, "stair", -90.0, -86.0, 4.0, top - 0.1, z0, z1, 0.06)
            box(S, "plate_metal", -90.0, -86.0, top - 0.1, top, z0, z1, 0.02)
            nz = zb  # nosing at the lower (outer) edge of each tread
            n0, n1 = sorted((nz, nz - sg * 0.45))
            box(S, "trim_metal", -90.0, -86.0, top - 0.22, top + 0.02, n0, n1, 0.05)
        # open-side stringer (sloped metal plate) + handrail
        pts = [(-85.6, 4.0, sg * 40.5), (-85.6, 5.6, sg * 40.5), (-85.6, 17.0, sg * 10.0), (-85.6, 15.4, sg * 10.0)]
        prism(S, "beam_metal", pts, (-0.5, 0, 0))
        railing(S, (-85.8, 5.0, sg * 40.0), (-85.8, 16.0, sg * 10.0), 3.2, posts=6)
    # top landing y16 x -90..-84, z -10..10 + plinth face with the DUELS sign
    box(S, "stair", -90.0, -84.0, 4.0, 15.8, -10.0, 10.0, 0.12)
    box(S, "plate_metal", -90.0, -84.2, 15.8, 16.0, -10.0, 10.0, 0.03)
    box(S, "trim_metal", -84.4, -83.8, 15.4, 16.05, -10.0, 10.0, 0.08)
    box(S, "band_olive", -84.1, -83.85, 7.1, 9.9, -10.0, 10.0, 0.08)  # hub datum on the plinth face
    railing(S, (-84.2, 16.0, -9.6), (-84.2, 16.0, 9.6), 3.4)
    for sg in (-1, 1):
        railing(S, (-85.9, 16.0, sg * 10.0), (-84.2, 16.0, sg * 10.0), 3.4, posts=2)
    box("H_Signs", "sign_board", -83.85, -83.2, 10.6, 14.6, -7.0, 7.0, 0.2, 2)
    for (y0, y1, z0, z1) in ((10.6, 10.85, -7.0, 7.0), (14.35, 14.6, -7.0, 7.0), (10.6, 14.6, -7.0, -6.75), (10.6, 14.6, 6.75, 7.0)):
        box("H_Signs", "neon_olive", -83.25, -83.1, y0, y1, z0, z1, 0.0)
    for sg in (-1, 1):
        wall_light(Wall("z", -84.0, +1), sg * 8.6, 0.0, 12.4, piece="H_WallLights")

def railing(piece, p0, p1, h, posts=None, mat="trim_light"):
    """Posts + top rail + mid rail + kick plate between two base points (studio coords)."""
    p0 = Vector(p0); p1 = Vector(p1)
    d = p1 - p0
    L = d.length
    n = posts if posts else max(2, int(L / 3.4) + 1)
    for i in range(n):
        t = i / (n - 1)
        b = p0 + d * t
        box(piece, mat, b.x - 0.13, b.x + 0.13, b.y, b.y + h, b.z - 0.13, b.z + 0.13, 0.05)
    up = Vector((0, h, 0))
    rod(piece, mat, p0 + up, p1 + up, 0.15, 8)
    rod(piece, mat, p0 + up * 0.5, p1 + up * 0.5, 0.09, 6)

# ------------------------------------------------------------------ floor + floor lines
def build_floor():
    F = "H_Floor"
    xs = [-78.0] + [p for p in PIL if p > -72] + [88.0]
    zs = [-41.0, -13.75, 13.75, 41.0]
    g = 0.15
    for i in range(len(xs) - 1):
        for j in range(3):
            box(F, "floor_field", xs[i] + g, xs[i + 1] - g, -1.0, 0.0, zs[j] + g, zs[j + 1] - g, 0.06)
    box(F, "floor_border", -78.0, 88.0, -1.0, -0.06, -41.0, 41.0, 0.0)  # joint fill under the slab gaps
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 41.0, sg * 44.0))
        box(F, "floor_border", -78.0, 88.0, -1.0, 0.02, z0, z1, 0.05)
        za, zb = sorted((sg * 40.7, sg * 41.1))
        box(F, "trim_metal", -77.6, 85.0, -0.2, 0.07, za, zb, 0.04)
    box(F, "floor_border", 85.0, 88.0, -1.0, 0.02, -41.0, 41.0, 0.05)
    box(F, "trim_metal", 84.7, 85.1, -0.2, 0.07, -40.7, 40.7, 0.04)
    # lane inserts (corrugated metal) + cream Neon runway lines
    Ln = "H_FloorLines"
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 16.0, sg * 40.7))
        box(F, "floor_insert", -5.4, 5.4, -0.2, 0.03, z0, z1, 0.03)
        for xx in (-5.85, 5.85):
            box(Ln, "neon_cream", xx - 0.19, xx + 0.19, -0.4, 0.07, z0, z1, 0.0)
    box(F, "floor_insert", 16.0, 84.7, -0.2, 0.03, -6.0, 6.0, 0.03)
    box(F, "floor_insert", -71.8, -16.0, -0.2, 0.03, -6.0, 6.0, 0.03)
    for zz in (-6.45, 6.45):
        box(Ln, "neon_cream", 16.0, 84.7, -0.4, 0.07, zz - 0.19, zz + 0.19, 0.0)
        box(Ln, "neon_cream", -71.8, -16.0, -0.4, 0.07, zz - 0.19, zz + 0.19, 0.0)
    # dark-olive Neon ring segments round the centre (RIVALS gold ring role)
    for q in range(4):
        a = math.radians(45 + 90 * q)
        lathe(Ln, "neon_olive", [(15.6, -0.4), (16.0, -0.4), (16.0, 0.07), (15.6, 0.07)], seg=128, a0=a - math.radians(28), a1=a + math.radians(28))
        lathe(Ln, "neon_olive", [(17.0, -0.4), (17.25, -0.4), (17.25, 0.07), (17.0, 0.07)], seg=128, a0=a - math.radians(10), a1=a + math.radians(10))
    # drain grates on the diagonals (metal frame + near-black grate host)
    for q in range(4):
        a = math.radians(45 + 90 * q)
        cx, cz = 21.5 * math.cos(a), 21.5 * math.sin(a)
        box(F, "trim_metal", cx - 2.2, cx + 2.2, -0.3, 0.05, cz - 2.2, cz + 2.2, 0.06)
        box(F, "grate", cx - 1.8, cx + 1.8, -0.3, 0.07, cz - 1.8, cz + 1.8, 0.0)

# ------------------------------------------------------------------ spawn disc hero (r 12)
def build_spawn():
    D = "H_SpawnDisc"
    lathe(D, "floor_border", [(12.0, -0.2), (13.7, -0.2), (13.7, 0.12), (13.45, 0.3), (12.0, 0.3)], seg=128)
    lathe(D, "plate_metal", [(10.9, -0.2), (12.15, -0.2), (12.15, 0.48), (12.0, 0.6), (11.05, 0.6), (10.9, 0.48)], seg=128)
    lathe(D, "neon_olive", [(10.55, -0.2), (10.9, -0.2), (10.9, 0.5), (10.55, 0.5)], seg=128)
    lathe(D, "floor_border", [(4.6, -0.2), (10.55, -0.2), (10.55, 0.38), (4.6, 0.38)], seg=96)  # gap fill under the sector plates
    gap = math.radians(1.6)
    for k in range(12):
        a0 = math.radians(30 * k) + gap; a1 = math.radians(30 * (k + 1)) - gap
        lathe(D, "disc_plate", [(4.75, 0.2), (10.4, 0.2), (10.4, 0.4), (10.3, 0.48), (4.85, 0.48), (4.75, 0.4)], seg=96, a0=a0, a1=a1)
    lathe(D, "neon_cream", [(4.2, -0.2), (4.6, -0.2), (4.6, 0.44), (4.2, 0.44)], seg=96)
    cyl(D, "disc_center", 0.0, 0.0, 4.2, -0.2, 0.52, seg=64, bev=0.12)
    # cream Neon arrowheads pointing to the four gates, and tick inlays on the metal ring
    for q in range(4):
        a = math.radians(90 * q)
        ca, sa = math.cos(a), math.sin(a)
        def P(r, t, y):  # radial r, tangential t
            return (r * ca - t * sa, y, r * sa + t * ca)
        tri = [P(1.6, -1.0, 0.52), P(3.4, 0.0, 0.52), P(1.6, 1.0, 0.52), P(2.2, 0.0, 0.52)]
        prism(D, "neon_cream", tri, (0, 0.06, 0))
    for k in range(48):
        if k % 4 == 0:
            continue
        a = math.radians(7.5 * k)
        ca, sa = math.cos(a), math.sin(a)
        r0, r1 = 11.2, 11.75
        w = 0.09
        pts = [(r0 * ca - w * sa, 0.6, r0 * sa + w * ca), (r1 * ca - w * sa, 0.6, r1 * sa + w * ca),
               (r1 * ca + w * sa, 0.6, r1 * sa - w * ca), (r0 * ca + w * sa, 0.6, r0 * sa - w * ca)]
        prism(D, "dark_metal", pts, (0, 0.03, 0))
    for q in range(4):  # lane landing-light studs on the outer ring
        a = math.radians(90 * q)
        cyl(D, "neon_cream", 12.85 * math.cos(a), 12.85 * math.sin(a), 0.32, 0.0, 0.38, seg=16, bev=0.08)

# ------------------------------------------------------------------ roof, beams, skylight, ceiling lights
def build_roof():
    R = "H_Roof"
    X0, X1, Z = -90.0, 88.0, 44.0
    sx0, sx1, sz = -27.5, 27.5, 20.625
    box(R, "ceiling", X0, X1, 68.0, 73.0, sz, Z, 0.1)
    box(R, "ceiling", X0, X1, 68.0, 73.0, -Z, -sz, 0.1)
    box(R, "ceiling", X0, sx0, 68.0, 73.0, -sz, sz, 0.1)
    box(R, "ceiling", sx1, X1, 68.0, 73.0, -sz, sz, 0.1)
    # coffer panels (glossy, recessed between beams and purlins)
    xs = [X0] + PIL + [X1]
    zb = [-44.0, -24.0, -sz, sz, 24.0, 44.0]
    for i in range(len(xs) - 1):
        for j in range(len(zb) - 1):
            x0, x1, z0, z1 = xs[i] + 1.6, xs[i + 1] - 1.6, zb[j] + 1.2, zb[j + 1] - 1.2
            if z1 - z0 < 2:
                continue
            inside_sky = xs[i] >= sx0 - 0.1 and xs[i + 1] <= sx1 + 0.1 and zb[j] >= -sz - 0.1 and zb[j + 1] <= sz + 0.1
            if inside_sky:
                continue
            box(R, "ceiling_gloss", x0, x1, 67.4, 68.0, z0, z1, 0.15)
            box(R, "trim_metal", x0 - 0.3, x1 + 0.3, 67.2, 67.45, z0 - 0.3, z1 + 0.3, 0.05)  # coffer lip
    B = "H_Beams"
    for x in PIL + [X0 + 2.0, X1 - 2.0]:
        box(B, "beam_metal", x - 0.4, x + 0.4, 63.6, 67.4, -Z, Z, 0.08)      # web
        box(B, "beam_metal", x - 1.2, x + 1.2, 63.0, 63.6, -Z, Z, 0.1)       # bottom flange
        box(B, "beam_metal", x - 1.2, x + 1.2, 67.4, 68.0, -Z, Z, 0.1)       # top flange
        for zz in range(-40, 41, 8):                                          # stiffeners
            box(B, "beam_metal", x - 1.1, x + 1.1, 63.6, 67.4, zz - 0.12, zz + 0.12, 0.03)
        for sg in (-1, 1):                                                    # haunch brackets into the wall cornice
            zf = sg * Z
            prism(B, "beam_metal", [(x - 0.35, 63.0, zf - sg * 3.6), (x - 0.35, 63.0, zf - sg * 7.0), (x - 0.35, 58.6, zf - sg * 3.6)], (0.7, 0, 0))
    for zz in (-24.0, 24.0):  # purlins carrying the light strips
        box(B, "beam_metal", X0, X1, 64.8, 67.4, zz - 0.5, zz + 0.5, 0.08)
        box(B, "beam_metal", X0, X1, 64.4, 64.8, zz - 1.0, zz + 1.0, 0.08)
    Lg = "H_CeilLights"
    for i in range(len(xs) - 1):
        for zz in (-24.0, 24.0):
            x0, x1 = xs[i] + 2.2, xs[i + 1] - 2.2
            box(Lg, "trim_metal", x0, x1, 63.9, 64.4, zz - 0.9, zz + 0.9, 0.08)
            box(Lg, "neon_lamp", x0 + 0.3, x1 - 0.3, 63.7, 63.95, zz - 0.55, zz + 0.55, 0.0)
        # short diagonal "slash" strips in the coffers between purlin and wall (the RIVALS ceiling-slash role, lamp neon)
    # skylight: curb, mullions, glass
    S = "H_Skylight"
    box(S, "trim_light", sx0 - 0.6, sx1 + 0.6, 73.0, 74.2, sz, sz + 0.6, 0.1)
    box(S, "trim_light", sx0 - 0.6, sx1 + 0.6, 73.0, 74.2, -sz - 0.6, -sz, 0.1)
    box(S, "trim_light", sx0 - 0.6, sx0, 73.0, 74.2, -sz, sz, 0.1)
    box(S, "trim_light", sx1, sx1 + 0.6, 73.0, 74.2, -sz, sz, 0.1)
    for x in [sx0 + 6.875 * k for k in range(1, 8)]:
        box(S, "beam_metal", x - 0.3, x + 0.3, 73.2, 74.4, -sz, sz, 0.06)
    for zz in (-10.3, 0.0, 10.3):
        box(S, "beam_metal", sx0, sx1, 73.4, 74.2, zz - 0.25, zz + 0.25, 0.06)
    box(S, "glass", sx0, sx1, 73.9, 74.0, -sz, sz, 0.0)
    # skylight well lining (light concrete reveal) with an olive Neon line round the well
    box(S, "neon_olive", sx0, sx1, 67.75, 68.0, sz - 0.25, sz, 0.0)
    box(S, "neon_olive", sx0, sx1, 67.75, 68.0, -sz, -sz + 0.25, 0.0)
    box(S, "neon_olive", sx0, sx0 + 0.25, 67.75, 68.0, -sz, sz, 0.0)
    box(S, "neon_olive", sx1 - 0.25, sx1, 67.75, 68.0, -sz, sz, 0.0)

# ------------------------------------------------------------------ catwalks (y 31) and bridges (y 27)
def build_catwalks():
    C = "H_Catwalks"
    for W in (WN, WS):
        X0, X1 = -90.0, 88.0
        W.box(C, "plate_metal", X0, X1, 30.4, 31.0, 0.0, 4.0, 0.06)
        W.box(C, "beam_metal", X0, X1, 29.2, 31.0, 3.65, 4.2, 0.08)
        W.box(C, "trim_metal", X0, X1, 31.0, 31.55, 3.95, 4.15, 0.04)
        edges = [X0] + PIL + [X1]
        for i in range(len(edges) - 1):
            W.box(C, "neon_lamp", edges[i] + 1.8, edges[i + 1] - 1.8, 28.95, 29.2, 3.0, 3.55, 0.0)
        a = W.p(X0, 31.0, 3.9); b = W.p(X1, 31.0, 3.9)
        railing(C, a, b, 3.5)
        W.box(C, "trim_metal", X0, X1, 29.0, 29.4, 0.0, 3.6, 0.05)  # under-deck stringer
    B = "H_Bridges"
    for xc in (-49.0, 49.0):
        box(B, "plate_metal", xc - 3.0, xc + 3.0, 26.4, 27.0, -44.0, 44.0, 0.06)
        for sg in (-1, 1):
            x0, x1 = sorted((xc + sg * 3.0, xc + sg * 3.6))
            box(B, "beam_metal", x0, x1, 25.0, 27.3, -44.0, 44.0, 0.08)
            box(B, "trim_metal", x0 - 0.1, x1 + 0.1, 24.8, 25.1, -44.0, 44.0, 0.05)
            railing(B, (xc + sg * 3.3, 27.3, -40.0), (xc + sg * 3.3, 27.3, 40.0), 3.4)
            for zz in (-27.5, -13.75, 0.0, 13.75, 27.5):  # hanger rods to the roof beams
                rod(B, "trim_light", (xc + sg * 3.3, 27.3, zz), (xc + sg * 3.3, 63.0, zz), 0.16, 8)
                box(B, "dark_metal", xc + sg * 3.3 - 0.3, xc + sg * 3.3 + 0.3, 27.3, 28.0, zz - 0.3, zz + 0.3, 0.05)
        for zz in range(-40, 41, 5):  # cross members under the deck
            box(B, "beam_metal", xc - 3.0, xc + 3.0, 25.6, 26.4, zz - 0.25, zz + 0.25, 0.05)
        box(B, "neon_lamp", xc - 0.5, xc + 0.5, 25.35, 25.6, -38.0, 38.0, 0.0)

# ------------------------------------------------------------------ props (sky military base, RIVALS manner)
def prop_crate(piece, cx, cy, cz, s=4.0, rot=False):
    h = s / 2
    box(piece, "crate_green", cx - h + 0.15, cx + h - 0.15, cy + 0.15, cy + s - 0.15, cz - h + 0.15, cz + h - 0.15, 0.08)
    f = 0.35
    for (x0, x1) in ((cx - h, cx - h + f), (cx + h - f, cx + h)):
        for (z0, z1) in ((cz - h, cz - h + f), (cz + h - f, cz + h)):
            box(piece, "dark_metal", x0, x1, cy, cy + s, z0, z1, 0.06)
    for yy in (cy, cy + s - f):
        box(piece, "dark_metal", cx - h, cx + h, yy, yy + f, cz - h, cz - h + f, 0.06)
        box(piece, "dark_metal", cx - h, cx + h, yy, yy + f, cz + h - f, cz + h, 0.06)
        box(piece, "dark_metal", cx - h, cx - h + f, yy, yy + f, cz - h, cz + h, 0.06)
        box(piece, "dark_metal", cx + h - f, cx + h, yy, yy + f, cz - h, cz + h, 0.06)
    for sg in (-1, 1):  # recessed X brace look: inset panels on two faces + stencil plates
        box(piece, "crate_green", cx - h + 0.6, cx + h - 0.6, cy + 0.6, cy + s - 0.6, cz + sg * (h - 0.05) - 0.05, cz + sg * (h - 0.05) + 0.05, 0.03)
        box(piece, "label_cream", cx - 0.7, cx + 0.7, cy + s * 0.62, cy + s * 0.62 + 0.45, cz + sg * h - 0.02, cz + sg * h + 0.02, 0.0)
        box(piece, "dark_metal", cx + sg * (h + 0.02) - 0.08, cx + sg * (h + 0.02) + 0.08, cy + s * 0.55, cy + s * 0.55 + 0.35, cz - 0.9, cz + 0.9, 0.03)

def prop_longcase(piece, cx, cy, cz, along_x=True):
    L, W, H = 6.0, 2.4, 2.2
    if along_x:
        dx, dz = L / 2, W / 2
    else:
        dx, dz = W / 2, L / 2
    box(piece, "case_dark", cx - dx, cx + dx, cy, cy + H * 0.55, cz - dz, cz + dz, 0.2, 2)
    box(piece, "case_dark", cx - dx + 0.05, cx + dx - 0.05, cy + H * 0.55, cy + H, cz - dz + 0.05, cz + dz - 0.05, 0.25, 2)
    box(piece, "dark_metal", cx - dx - 0.02, cx + dx + 0.02, cy + H * 0.52, cy + H * 0.6, cz - dz - 0.02, cz + dz + 0.02, 0.02)
    for t in (-0.3, 0.3):
        if along_x:
            box(piece, "drum_olive", cx + t * L - 0.3, cx + t * L + 0.3, cy + H * 0.4, cy + H * 0.72, cz + dz - 0.05, cz + dz + 0.12, 0.04)
        else:
            box(piece, "drum_olive", cx + dx - 0.05, cx + dx + 0.12, cy + H * 0.4, cy + H * 0.72, cz + t * L - 0.3, cz + t * L + 0.3, 0.04)
    # ribs on the lid
    for t in (-0.4, -0.13, 0.13, 0.4):
        if along_x:
            box(piece, "case_dark", cx + t * L - 0.12, cx + t * L + 0.12, cy + H - 0.05, cy + H + 0.12, cz - dz + 0.3, cz + dz - 0.3, 0.04)
        else:
            box(piece, "case_dark", cx - dx + 0.3, cx + dx - 0.3, cy + H - 0.05, cy + H + 0.12, cz + t * L - 0.12, cz + t * L + 0.12, 0.04)

def prop_drum(piece, cx, cy, cz):
    lathe(piece, "drum_olive", [(0.1, 0.0), (1.3, 0.0), (1.38, 0.12), (1.38, 0.5), (1.32, 0.6), (1.32, 1.35), (1.4, 1.45), (1.32, 1.55),
                                (1.32, 2.45), (1.4, 2.55), (1.32, 2.65), (1.32, 3.4), (1.38, 3.5), (1.38, 3.88), (1.3, 4.0), (0.1, 4.0)], cx=cx, cz=cz, seg=32, y0=cy)
    cyl(piece, "dark_metal", cx + 0.6, cz, 0.22, cy + 4.0, cy + 4.12, seg=12, bev=0.03)

def prop_console(piece, cx, cy, cz, face=-1):
    """Free-standing ops console; face = +1/-1 along z (screen faces that way)."""
    f = face
    box(piece, "beam_metal", cx - 2.2, cx + 2.2, cy, cy + 3.0, cz - 0.9, cz + 0.9, 0.15, 2)
    box(piece, "dark_metal", cx - 2.0, cx + 2.0, cy, cy + 0.5, cz - 0.7, cz + 0.7, 0.05)
    # slanted desk top (prism in z-y)
    z0, z1 = cz - f * 0.9, cz + f * 1.6
    prism(piece, "trim_metal", [(cx - 2.3, cy + 3.0, z0), (cx - 2.3, cy + 3.6, z0), (cx - 2.3, cy + 3.2, z1), (cx - 2.3, cy + 2.9, z1)], (4.6, 0, 0))
    # upright screen with cream Neon edge and olive status keys
    zs = cz - f * 0.6
    za, zb = sorted((zs, zs - f * 0.35))
    box(piece, "dark_metal", cx - 2.0, cx + 2.0, cy + 3.5, cy + 6.1, za, zb, 0.1)
    zc, zd = sorted((zs + f * 0.02, zs + f * 0.06))
    box(piece, "screen", cx - 1.75, cx + 1.75, cy + 3.75, cy + 5.85, zc, zd, 0.0)
    box(piece, "neon_cream", cx - 1.75, cx + 1.75, cy + 3.65, cy + 3.75, zc, zd, 0.0)
    for i in range(5):
        x = cx - 1.4 + i * 0.7
        zz = cz + f * 0.9
        box(piece, "neon_olive" if i % 2 == 0 else "label_cream", x - 0.2, x + 0.2, cy + 3.3, cy + 3.42, zz - 0.2, zz + 0.2, 0.03)

def build_props():
    P = "H_Props"
    clusters = []
    for sz in (-1, 1):
        zc = sz * 37.0
        # crate stacks in front of vent bays (x +-27.5, +-55), drums + cases near them, consoles at doors' sides
        for xc in (-55.0, 27.5):
            prop_crate(P, xc - 2.3, 0.0, zc, 4.0); prop_crate(P, xc + 2.0, 0.0, zc + sz * 0.3, 4.0); prop_crate(P, xc - 0.2, 4.0, zc, 4.0)
            prop_drum(P, xc + 5.6, 0.0, zc + sz * 1.0); prop_drum(P, xc + 6.4, 0.0, zc - sz * 1.9)
            clusters.append((xc, zc))
        for xc in (-27.5, 55.0):
            prop_longcase(P, xc, 0.0, zc + sz * 0.8, True); prop_longcase(P, xc + 0.4, 2.3, zc + sz * 0.8, True)
            prop_crate(P, xc + 5.4, 0.0, zc + sz * 0.6, 3.0)
            clusters.append((xc, zc))
        prop_console(P, 74.0, 0.0, sz * 33.0, face=-sz)
    # by the tunnel mouth
    prop_crate(P, 80.0, 0.0, 18.0, 4.0); prop_crate(P, 80.0, 0.0, 22.3, 4.0); prop_longcase(P, 80.5, 0.0, -19.0, False)
    prop_drum(P, 82.5, 0.0, -14.5)
    # on the landing (y 4) either side of the riser
    prop_crate(P, -82.0, 4.0, -15.0, 3.0); prop_drum(P, -82.0, 4.0, 15.0); prop_longcase(P, -82.0, 4.0, 22.0, False)
    return clusters

def build_origin_props():
    """One clean copy of each prop at the origin for instancing (separate FBX kit/hub_r1_props.fbx)."""
    prop_crate("P_Crate4", 0, 0, 0, 4.0)
    prop_crate("P_Crate3", 0, 0, 0, 3.0)
    prop_longcase("P_LongCase", 0, 0, 0, True)
    prop_drum("P_Drum", 0, 0, 0)
    prop_console("P_Console", 0, 0, 0, face=-1)
    wall_light(Wall("x", 0.0, -1), 0.0, -1.8, 0.0, piece="P_WallLight")

def build_markers():
    # 10-stud scale cube and an asymmetric marker, high above the hub (studio y 120)
    box("K_Scale1", "label_cream", -5, 5, 115, 125, -5, 5, 0.0)
    box("K_Marker1", "neon_olive", 15, 25, 115, 117, -1, 1, 0.0)      # long arm along +X (east)
    box("K_Marker1", "neon_olive", 15, 17, 117, 123, -1, 1, 0.0)      # upright at the west end (+Y)
    box("K_Marker1", "neon_olive", 15, 17, 115, 117, 1, 5, 0.0)       # short arm along +Z (north)

# ------------------------------------------------------------------ finalize: bmesh -> objects
def collection(name):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
    return c

def coll_for(piece):
    if piece.startswith("K_"):
        return "Markers"
    if piece.startswith("P_"):
        return "Kit_Origin"
    if piece in ("H_SpawnDisc", "H_Props", "H_Signs"):
        return "Hero_Props"
    return "Shell"

def finalize():
    stats = []
    for (piece, mat), bm in ACC.items():
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.transform(S2B)
        uvl = bm.loops.layers.uv.verify()
        for f in bm.faces:
            n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                c = l.vert.co
                if ax == 0:
                    l[uvl].uv = (c.y / UV_STUDS * (1 if n.x > 0 else -1), c.z / UV_STUDS)
                elif ax == 1:
                    l[uvl].uv = (c.x / UV_STUDS * (-1 if n.y > 0 else 1), c.z / UV_STUDS)
                else:
                    l[uvl].uv = (c.x / UV_STUDS, c.y / UV_STUDS)
        for f in bm.faces:
            f.smooth = True
        name = piece if piece.startswith("K_") else f"{piece}__{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me); bm.free()
        # origin at the bounds centre (Import 3D uses scene positions; keeps pivots tidy)
        vs = [v.co for v in me.vertices]
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        c = (mn + mx) / 2
        me.transform(Matrix.Translation(-c))
        ob = bpy.data.objects.new(name, me); ob.location = c
        collection(coll_for(piece)).objects.link(ob)
        me.materials.append(make_material(mat))
        if not piece.startswith("K_") and not mat.startswith("neon") and mat not in ("glass", "hazard"):
            wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.mode = "FACE_AREA"; wn.keep_sharp = True
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        rgb = MATS[mat][0]
        sz = mx - mn
        stats.append(dict(name=name, piece=piece, material=mat, rgb=list(rgb), studio=MATS[mat][6], tris=tris,
                          size_studio=[round(sz.x, 2), round(sz.z, 2), round(sz.y, 2)],
                          center_studio=[round(-c.x, 2), round(c.z, 2), round(c.y, 2)]))
    ACC.clear()
    return stats

def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)

def build_all():
    clear_scene()
    build_long_wall(WN, "N"); build_long_wall(WS, "S")
    build_gate(WN, "N"); build_gate(WS, "S")
    build_east(); build_west()
    build_floor(); build_spawn(); build_roof(); build_catwalks(); build_props(); build_markers()
    build_origin_props()
    stats = finalize()
    # origin kit lives off to the side in Blender only so previews stay clean; FBX of it is exported separately
    for ob in bpy.data.collections["Kit_Origin"].objects:
        pass
    with open(ROOT + "/kit/hub_r1_manifest.json", "w") as f:
        json.dump(stats, f, indent=1)
    return stats

if __name__ == "__main__" or True:
    STATS = build_all()
