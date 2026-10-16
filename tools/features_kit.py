"""Tacticals feature-pass prop kit (features): items 26, 27, 14, 3, 29, 30, 31, wall screens (18/19/21/4) + Training swap bin and
cover crates. RIVALS module language, Tacticals palette. Own geometry only (bmesh + the hub_kit / rooms2 / rooms3 helpers).

Every piece is authored at ITS OWN ORIGIN (pivot) in Studio coordinates (x east, y up, z north; front = -Z = Roblox Front face),
then the finished piece is slid along +X into a row (4-stud gaps) so nothing overlaps in the FBX. The manifest gives each piece's
pivot in the FBX and every mesh's centre relative to that pivot, so a placement script can rebuild each piece as a Model.

Run (background Blender 5.2, fresh file; never read_homefile):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/features_kit.py
Writes kit/features_kit.blend, kit/features.fbx, kit/features_manifest.json, out/features/bl_*.png (+ sheet via tools/features_sheet.py).
"""
import bpy, bmesh, math, os, json, re, sys
from mathutils import Vector, Matrix

_R3 = r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms3_kit.py"
_src = open(_R3).read().rsplit('if __name__ == "__main__" or True:', 1)[0]
exec(_src, globals())   # rooms3 -> rooms2 -> hub_kit: MATS, make_material, box/prism/lathe/cyl/rod, finalize, STUDIO_RGB3, ...

KIT = ROOT + "/kit/"
OUT = ROOT + "/out/features/"
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ extra materials (same tuple layout as MATS)
MATS.update({
    "container_olive": ((88, 98, 58),    "hub_corrugated_metal", 16, 0.4, 0.55, False, "Metal + TacCorrugatedMetal (olive drab paint)"),
    "pipe_grey":       ((150, 148, 142), "hub_metal_satin", 10, 0.85, 0.4, False, "Metal + TacMetal"),
    "trim_cream":      ((236, 232, 218), "hub_metal_satin", 10, 0.3, 0.45, False, "Metal + TacMetal (cream paint)"),
    "lens_warm":       ((255, 241, 208), None, 10, 0.0, 0.2, True, "Neon (warm white lens)"),
    "lens_amber":      ((255, 170, 40),  None, 10, 0.0, 0.2, True, "Neon (amber lens; red 220,40,40 for the Duels shaft)"),
    "holo_lens":       ((236, 232, 218), None, 10, 0.0, 0.2, True, "Neon (cream emitter)"),
    "holo_cone":       ((236, 232, 218), None, 10, 0.0, 0.2, True, "Neon, Transparency 0.85 (or replace with a Beam)"),
    "halo_cream":      ((236, 232, 218), None, 10, 0.0, 0.3, True, "Neon (cream halo)"),
    "crate_trim":      ((65, 94, 56),    "hub_concrete_smooth", 6, 0.0, 0.65, False, "SmoothPlastic (military green, decor ribs / braces)"),
    "screen_b":        ((18, 22, 20),    None, 10, 0.0, 0.15, False, "Glass / SurfaceGui screen (back)"),
})
# Studio colours (hub1/rooms3 decisions) + Edward's effect theme: olive Neon 66,72,36, band 111,114,57 for the FX pieces
STUDIO_RGB_F = dict(STUDIO_RGB3)
STUDIO_RGB_F.update({"crate_green": (65, 94, 56), "crate_trim": (65, 94, 56)})
FX_PIECES = ("F_TrussSpot", "F_BeaconMast", "F_BeaconWall", "F_HoloEmitter")
FX_RGB = {"neon_olive": (66, 72, 36), "band_olive": (111, 114, 57)}

# ------------------------------------------------------------------ extra primitives
def obox(piece, mat, c, eu, ev, ew, hu, hv, hw, bev=0.04, seg=1):
    """Oriented box: centre c, unit axes eu/ev/ew, half sizes."""
    bm = acc(piece, mat)
    eu, ev, ew = Vector(eu).normalized(), Vector(ev).normalized(), Vector(ew).normalized()
    R = Matrix((eu * 2 * hu, ev * 2 * hv, ew * 2 * hw)).transposed().to_4x4()
    M = Matrix.Translation(Vector(c)) @ R
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    b = min(bev, min(hu, hv, hw) * 0.9)
    if b > 0.005:
        edges = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=b, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)

def torus(piece, mat, c, n, R, r, a0=0.0, a1=2 * math.pi, seg=32, rseg=10, u=None):
    """(Partial) torus round axis n through c. u = in-plane start direction."""
    bm = acc(piece, mat)
    c = Vector(c); n = Vector(n).normalized()
    u = Vector(u).normalized() if u is not None else (n.orthogonal().normalized())
    v = n.cross(u).normalized()
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    steps = seg if full else max(2, int(seg * (a1 - a0) / (2 * math.pi)) + 1)
    rings = []
    for i in range(steps if full else steps + 1):
        a = a0 + (a1 - a0) * i / steps
        d = u * math.cos(a) + v * math.sin(a)
        p = c + d * R
        rings.append([bm.verts.new(p + (d * math.cos(b) + n * math.sin(b)) * r) for b in [2 * math.pi * k / rseg for k in range(rseg)]])
    cnt = len(rings)
    for i in range(steps):
        A = rings[i]; B = rings[(i + 1) % cnt]
        for k in range(rseg):
            l = (k + 1) % rseg
            bm.faces.new((A[k], A[l], B[l], B[k]))

def xcyl(piece, mat, x0, x1, r, y=0.0, z=0.0, seg=16):
    rod(piece, mat, (x0, y, z), (x1, y, z), r, seg)

def zcyl(piece, mat, z0, z1, r, x=0.0, y=0.0, seg=16):
    rod(piece, mat, (x, y, z0), (x, y, z1), r, seg)

# ================================================================== 26: TVs on articulated arms
def tv_head(P, zb, cy, f=-1, W=7.2, H=4.2, smat="screen"):
    """TV with its back at z = zb, facing f (-1 = -Z front). Screen = thin box `smat` recessed 0.06 in a proud bezel."""
    Z = lambda d: zb + f * d          # d = distance in front of the back plane
    box(P, "case_dark", -W / 2, W / 2, cy - H / 2, cy + H / 2, Z(0), Z(0.55), 0.12, 2)
    box(P, "dark_metal", -1.4, 1.4, cy - 1.1, cy + 1.1, Z(0.05), Z(-0.35), 0.1)                     # VESA hump
    sw, sh = W / 2 - 0.32, H / 2 - 0.32
    b0, b1 = Z(0.4), Z(0.65)                                                                          # bezel 0.1 proud
    box(P, "trim_metal", -W / 2 - 0.04, W / 2 + 0.04, cy + sh, cy + H / 2 + 0.04, b0, b1, 0.05)
    box(P, "trim_metal", -W / 2 - 0.04, W / 2 + 0.04, cy - H / 2 - 0.04, cy - sh, b0, b1, 0.05)
    box(P, "trim_metal", -W / 2 - 0.04, -sw, cy - sh, cy + sh, b0, b1, 0.05)
    box(P, "trim_metal", sw, W / 2 + 0.04, cy - sh, cy + sh, b0, b1, 0.05)
    box(P, smat, -sw - 0.05, sw + 0.05, cy - sh - 0.05, cy + sh + 0.05, Z(0.57), Z(0.59), 0.0)
    box(P, "neon_cream", -0.18, 0.18, cy - H / 2 + 0.06, cy - H / 2 + 0.16, Z(0.6), Z(0.69), 0.0)    # status LED on the chin
    box(P, "band_olive", -W / 2 - 0.03, W / 2 + 0.03, cy + H / 2 - 0.62, cy + H / 2 - 0.36, Z(-0.03), Z(0.3), 0.03)
    box(P, "neon_cream", -W / 2 + 0.8, W / 2 - 0.8, cy - H / 2 - 0.16, cy - H / 2 + 0.05, Z(0.12), Z(0.36), 0.0)   # under-glow
    for x in (-W / 2 + 0.6, W / 2 - 0.6):                                                             # rear vents
        for k in range(4):
            yy = cy - 0.9 + k * 0.45
            box(P, "dark_metal", x - 0.35, x + 0.35, yy, yy + 0.18, Z(0.02), Z(-0.05), 0.02)
    return dict(w=round(2 * sw, 2), h=round(2 * sh, 2), mesh_w=round(2 * sw + 0.1, 2), mesh_h=round(2 * sh + 0.1, 2),
                face="Front" if f < 0 else "Back", centre=[0.0, cy, round(Z(0.58), 3)])

def arm_seg(P, a, b, y, t=0.26, hw=0.22):
    """Twin-plate arm segment between knuckles a, b (x, z) at height y."""
    a = Vector((a[0], y, a[1])); b = Vector((b[0], y, b[1]))
    d = b - a; L = d.length; eu = d.normalized(); ev = Vector((0, 1, 0)); ew = eu.cross(ev)
    for s in (-1, 1):
        obox(P, "trim_metal", (a + b) / 2 + ev * s * (t / 2 + 0.04), eu, ev, ew, L / 2, t / 2 - 0.04, hw, 0.05)
    obox(P, "dark_metal", (a + b) / 2, eu, ev, ew, L / 2 - 0.3, 0.07, hw - 0.06, 0.02)               # spine between plates

def build_tv_wall():
    P = "F_TVArmWall"
    box(P, "dark_metal", -0.9, 0.9, -1.5, 1.5, -0.35, -0.02, 0.08)                                   # wall plate (back z -0.02)
    for x in (-0.6, 0.6):
        for y in (-1.15, 1.15):
            zcyl(P, "trim_metal", -0.3, -0.45, 0.11, x, y, 10)
    box(P, "trim_metal", -0.3, 0.3, -0.35, 0.35, -0.75, -0.3, 0.06)                                  # stub to the first knuckle
    K = [(0.0, -0.95), (1.7, -2.9), (0.0, -4.5)]
    for i, (x, z) in enumerate(K):
        cyl(P, "beam_metal", x, z, 0.36, -0.42 - 0.04 * i, 0.42 + 0.04 * i, 20, 0.05)
        cyl(P, "band_olive", x, z, 0.39, -0.035, 0.035, 20, 0.0)                                       # olive knuckle collar
    arm_seg(P, K[0], K[1], 0.0); arm_seg(P, K[1], K[2], 0.0)
    for (a, b) in ((K[0], K[1]), (K[1], K[2])):                                                       # cable under the arm
        rod(P, "void", (a[0], -0.52, a[1]), (b[0], -0.52, b[1]), 0.06, 6)
    box(P, "trim_metal", -0.3, 0.3, -0.3, 0.3, -4.5, -5.1, 0.06)                                    # tilt head to the VESA hump
    box(P, "dark_metal", -0.45, 0.45, -0.45, 0.45, -4.85, -5.05, 0.04)
    return dict(mount="wall: back plate at z 0 (wall face), TV faces -Z", screens=[tv_head(P, -5.2, 0.0)])

def build_tv_ceil(dual=False):
    P = "F_TVArmCeilDual" if dual else "F_TVArmCeil"
    box(P, "dark_metal", -0.9, 0.9, -0.35, -0.02, -0.9, 0.9, 0.08)                                   # ceiling plate (top y -0.02)
    for x in (-0.6, 0.6):
        for z in (-0.6, 0.6):
            cyl(P, "trim_metal", x, z, 0.11, -0.47, -0.3, 10, 0.02)
    cyl(P, "beam_metal", 0, 0, 0.22, -3.2, -0.3, 20, 0.04)                                            # drop pole
    cyl(P, "band_olive", 0, 0, 0.26, -1.5, -1.1, 20, 0.03)
    cyl(P, "trim_metal", 0, 0, 0.4, -3.55, -2.95, 20, 0.06)                                           # swivel knuckle
    scr = []
    if dual:
        box(P, "trim_metal", -0.25, 0.25, -3.6, -3.1, -0.5, 0.5, 0.05)
        scr.append(tv_head(P, -0.42, -4.6, f=-1)); scr.append(tv_head(P, 0.42, -4.6, f=+1, smat="screen_b"))
    else:
        box(P, "trim_metal", -0.25, 0.25, -3.5, -3.0, -0.3, 0.0, 0.05)
        box(P, "trim_metal", -0.25, 0.25, -3.5, -3.0, -0.75, -0.25, 0.05)
        scr.append(tv_head(P, -0.6, -4.6, f=-1))
    return dict(mount="ceiling: plate top at y 0 (ceiling face), TV hangs below" + (", two screens back to back (Front and Back)" if dual else ", faces -Z"),
                screens=scr)

# ================================================================== wall screen frames (18/19/21/4)
def build_screen_frame(SW, SH, P):
    D = 0.9; ox, oy = SW / 2 + 0.95, SH / 2 + 0.95
    box(P, "case_dark", -ox, ox, -oy, oy, -D, -0.02, 0.2, 2)                                          # housing (back z -0.02)
    sw, sh = SW / 2, SH / 2
    b0, b1 = -D - 0.12, -D + 0.25
    box(P, "trim_metal", -ox - 0.04, ox + 0.04, sh, oy + 0.04, b0, b1, 0.08)                         # heavy bezel, 0.12 proud
    box(P, "trim_metal", -ox - 0.04, ox + 0.04, -oy - 0.04, -sh, b0, b1, 0.08)
    box(P, "trim_metal", -ox - 0.04, -sw, -sh, sh, b0, b1, 0.08)
    box(P, "trim_metal", sw, ox + 0.04, -sh, sh, b0, b1, 0.08)
    for sx in (-1, 1):                                                                                 # chamfered corner caps
        for sy in (-1, 1):
            x0, y0 = sx * (ox + 0.1), sy * (oy + 0.1)
            box(P, "beam_metal", x0 - sx * 1.3, x0, y0 - sy * 1.3, y0, b0 - 0.06, -0.3, 0.12)
    box(P, "screen", -sw - 0.06, sw + 0.06, -sh - 0.06, sh + 0.06, -D - 0.04, -D - 0.02, 0.0)         # screen 0.08 behind bezel face
    box(P, "band_olive", -sw * 0.7, sw * 0.7, -oy + 0.2, -oy + 0.62, b0 - 0.04, b0 + 0.1, 0.03)     # olive datum strip
    box(P, "neon_cream", -sw + 0.4, sw - 0.4, -oy - 0.14, -oy + 0.12, -0.75, -0.3, 0.0)              # cream under-light
    hw = max(2.0, SW * 0.28)
    box(P, "case_dark", -hw - 0.3, hw + 0.3, oy - 0.2, oy + 1.5, -0.75, -0.02, 0.12)                # header block
    box(P, "label_cream", -hw, hw, oy + 0.2, oy + 1.25, -0.79, -0.6, 0.03)                           # header plate (SurfaceGui)
    for x in (-hw - 0.15, hw + 0.15):
        box(P, "neon_olive", x - 0.08, x + 0.08, oy + 0.25, oy + 1.2, -0.8, -0.6, 0.0)
    for sx in (-1, 1):                                                                                 # side vents
        for k in range(5):
            yy = -1.2 + k * 0.6
            box(P, "dark_metal", sx * ox - 0.05, sx * ox + sx * 0.08, yy, yy + 0.25, -0.75, -0.3, 0.02)
    return dict(mount="wall: back at z 0, faces -Z", screens=[dict(w=SW, h=SH, mesh_w=round(SW + 0.12, 2), mesh_h=round(SH + 0.12, 2),
                face="Front", centre=[0.0, 0.0, -D - 0.03])], label=dict(w=round(2 * hw, 2), h=1.05, face="Front", mesh="__label_cream"))

# ================================================================== 27: industrial props
def build_container(P, L, W=7.0, H=7.5):
    hx, hz = L / 2, W / 2
    box(P, "container_olive", -hx + 0.05, hx - 0.05, 0.1, H - 0.1, -hz + 0.05, hz - 0.05, 0.05)       # shell
    n = int((L - 1.8) / 0.8)
    for i in range(n + 1):                                                                             # side corrugation ribs
        x = -hx + 0.9 + i * (L - 1.8) / n
        for s in (-1, 1):
            box(P, "container_olive", x - 0.17, x + 0.17, 0.62, H - 0.62, s * (hz - 0.2), s * (hz + 0.07), 0.04)
    for k in range(5):                                                                                 # closed end (-X) ribs
        z = -hz + 0.9 + k * (W - 1.8) / 4
        box(P, "container_olive", -hx - 0.07, -hx + 0.2, 0.62, H - 0.62, z - 0.17, z + 0.17, 0.04)
    m = int((L - 1.2) / 1.1)
    for i in range(m + 1):                                                                             # roof ribs
        x = -hx + 0.6 + i * (L - 1.2) / m
        box(P, "container_olive", x - 0.2, x + 0.2, H - 0.3, H - 0.02, -hz + 0.5, hz - 0.5, 0.04)
    for sx in (-1, 1):                                                                                 # corner posts, 0.09 proud
        for sz in (-1, 1):
            box(P, "dark_metal", sx * (hx - 0.55), sx * (hx + 0.04), 0.02, H, sz * (hz - 0.55), sz * (hz + 0.04), 0.06)
            for (yy, y2) in ((0.06, 0.5), (H - 0.46, H + 0.06)):                                         # corner castings
                box(P, "trim_metal", sx * (hx - 0.42), sx * (hx + 0.1), yy, y2, sz * (hz - 0.42), sz * (hz + 0.1), 0.05)
    for sz in (-1, 1):                                                                                 # side rails top / bottom
        for (y0, y1) in ((0.02, 0.6), (H - 0.6, H + 0.02)):
            box(P, "dark_metal", -hx + 0.55, hx - 0.55, y0, y1, sz * (hz - 0.35), sz * (hz + 0.12), 0.05)
    for sx in (-1, 1):                                                                                 # end rails
        for (y0, y1) in ((0.02, 0.6), (H - 0.6, H + 0.02)):
            box(P, "dark_metal", sx * (hx - 0.35), sx * (hx + 0.12), y0, y1, -hz + 0.55, hz - 0.55, 0.05)
    for sz in (-1, 1):                                                                                 # door leaves (+X end)
        box(P, "container_olive", hx - 0.15, hx + 0.03, 0.6, H - 0.6, sz * 0.03, sz * (hz - 0.55), 0.04)
        for zz in (sz * 1.0, sz * 2.45):                                                               # lock bars + keepers
            rod(P, "trim_metal", (hx + 0.22, 0.7, zz), (hx + 0.22, H - 0.7, zz), 0.08, 10)
            for yy in (0.95, H - 0.95):
                box(P, "dark_metal", hx, hx + 0.36, yy - 0.15, yy + 0.15, zz - 0.18, zz + 0.18, 0.03)
            box(P, "dark_metal", hx + 0.2, hx + 0.42, 3.3, 3.5, zz - 0.05, zz + sz * 0.7, 0.03)        # handle
    box(P, "label_cream", hx + 0.0, hx + 0.07, 4.7, 5.5, -2.15, -1.3, 0.02)                          # door stencil plate
    box(P, "label_cream", -2.0, 2.0, H - 2.0, H - 1.2, -hz - 0.11, -hz + 0.0, 0.02)                  # side ID plate (over the ribs)
    return dict(mount="floor: bottom at y 0, doors at +X", colours="olive drab 88,98,58 (default) / sage 167,173,152 / warm grey 200,196,186 / near-black 40,42,38")

PR = 0.45
def pipe_straight(P, x0, x1, y=0.0, z=0.0, flange=True, band=True):
    xcyl(P, "pipe_grey", x0 + 0.05, x1 - 0.05, PR, y, z, 20)
    if flange:
        for (a, b) in ((x0, x0 + 0.28), (x1 - 0.28, x1)):
            xcyl(P, "dark_metal", a, b, PR + 0.18, y, z, 20)
            for k in range(6):
                ang = 2 * math.pi * k / 6 + 0.26
                xcyl(P, "trim_metal", a - 0.05, b + 0.05, 0.06, y + math.cos(ang) * (PR + 0.1), z + math.sin(ang) * (PR + 0.1), 6)
    if band:
        xm = (x0 + x1) / 2
        xcyl(P, "band_olive", xm - 0.35, xm + 0.35, PR + 0.04, y, z, 20)
        xcyl(P, "trim_cream", xm + 0.55, xm + 0.75, PR + 0.03, y, z, 20)

def build_pipe_straight():
    P = "F_PipeStraight"; pipe_straight(P, -4.0, 4.0)
    return dict(mount="pipe axis = X through the origin, length 8, ports at x -4 / +4, r 0.45 (flanges r 0.63)")

def build_pipe_elbow():
    P = "F_PipeElbow"; R = 1.5
    torus(P, "pipe_grey", (0, R, 0), (0, 0, 1), R, PR, a0=-math.pi / 2, a1=0.0, seg=40, rseg=20, u=(1, 0, 0))
    xcyl(P, "pipe_grey", -0.6, 0.0, PR, 0, 0, 20)
    rod(P, "pipe_grey", (R, R, 0), (R, R + 0.6, 0), PR, 20)
    xcyl(P, "dark_metal", -0.85, -0.57, PR + 0.18, 0, 0, 20)
    rod(P, "dark_metal", (R, R + 0.57, 0), (R, R + 0.85, 0), PR + 0.18, 20)
    torus(P, "band_olive", (0, R, 0), (0, 0, 1), R, PR + 0.04, a0=-math.pi / 4 - 0.12, a1=-math.pi / 4 + 0.12, seg=40, rseg=20, u=(1, 0, 0))
    return dict(mount="port A at (-0.85, 0, 0) facing -X, port B at (1.5, 2.35, 0) facing +Y; bend radius 1.5 in the XY plane")

def build_pipe_valve():
    P = "F_PipeValve"
    pipe_straight(P, -2.5, 2.5, band=False)
    xcyl(P, "trim_metal", -0.75, 0.75, 0.78, 0, 0, 24)                                                # valve body
    for (a, b) in ((-0.95, -0.65), (0.65, 0.95)):
        xcyl(P, "dark_metal", a, b, 0.9, 0, 0, 24)
    lathe(P, "trim_metal", [(0.02, 0.5), (0.55, 0.5), (0.55, 1.45), (0.4, 1.6), (0.02, 1.6)], seg=24)   # bonnet
    lathe(P, "dark_metal", [(0.02, 1.4), (0.66, 1.4), (0.66, 1.52), (0.02, 1.52)], seg=24)             # bonnet flange
    cyl(P, "pipe_grey", 0, 0, 0.09, 1.6, 2.55, 10, 0.0)                                               # stem
    torus(P, "band_olive", (0, 2.35, 0), (0, 1, 0), 0.95, 0.1, seg=36, rseg=10)                       # handwheel
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rod(P, "band_olive", (0, 2.35, 0), (math.cos(a) * 0.95, 2.35, math.sin(a) * 0.95), 0.06, 8)
    cyl(P, "dark_metal", 0, 0, 0.2, 2.2, 2.5, 12, 0.03)
    box(P, "label_cream", -0.5, 0.5, -0.35, 0.35, -0.86, -0.7, 0.02)                                 # tag plate on the body front
    return dict(mount="pipe axis = X, length 5, ports at x -2.5 / +2.5; handwheel up (+Y)")

def build_pipe_run():
    P = "F_PipeRun"
    for y in (0.0, 1.3):
        pipe_straight(P, -8.0, 0.0, y, -1.0, band=(y == 0.0)); pipe_straight(P, 0.0, 8.0, y, -1.0, band=(y > 0))
    for x in (-6.0, 0.0, 6.0):                                                                         # wall brackets
        sh = 0.6 if x == 0.0 else 0.0
        box(P, "dark_metal", x - 0.3 + sh, x + 0.3 + sh, -0.8, 2.1, -0.35, -0.02, 0.05)
        box(P, "trim_metal", x - 0.15 + sh, x + 0.15 + sh, -0.75, 2.05, -1.0, -0.3, 0.04)
        for y in (0.0, 1.3):
            torus(P, "trim_metal", (x + sh, y, -1.0), (1, 0, 0), PR + 0.08, 0.06, seg=24, rseg=6)
    return dict(mount="wall: brackets at z 0, two pipes at z -1 (y 0 and 1.3), length 16 along X (ports x -8 / +8)")

def build_power_box():
    P = "F_PowerBox"
    box(P, "trim_light", -1.6, 1.6, -2.2, 2.2, -1.1, -0.02, 0.1)
    box(P, "trim_metal", -1.45, 1.45, -2.05, 2.05, -1.16, -1.0, 0.05)                                # door
    for y in (-1.5, 1.5):
        box(P, "dark_metal", -1.66, -1.4, y - 0.3, y + 0.3, -1.2, -0.9, 0.03)                         # hinges
    box(P, "dark_metal", 1.0, 1.2, -0.6, 0.6, -1.32, -1.1, 0.04)                                       # handle
    for k in range(5):                                                                                 # louvre
        y = -1.8 + k * 0.28
        box(P, "dark_metal", -0.9, 0.9, y, y + 0.14, -1.22, -1.12, 0.02)
    box(P, "label_cream", -0.8, 0.8, 0.9, 1.7, -1.2, -1.1, 0.02)                                      # warning plate (decal / text)
    box(P, "hazard", -1.3, 1.3, 1.78, 1.96, -1.21, -1.12, 0.0)
    for i, x in enumerate((-1.1, -0.8, -0.5)):
        box(P, "neon_olive" if i < 2 else "neon_cream", x - 0.1, x + 0.1, 0.35, 0.55, -1.22, -1.1, 0.02)
    cyl(P, "dark_metal", 0.8, -0.5, 0.18, 2.1, 4.5, 12, 0.0)                                          # conduit up
    cyl(P, "trim_metal", 0.8, -0.5, 0.26, 2.15, 2.5, 12, 0.03)
    box(P, "dark_metal", 0.5, 1.1, 3.8, 4.1, -0.8, -0.02, 0.03)                                        # conduit strap
    return dict(mount="wall: back at z 0, faces -Z, centre at y 0 (box y -2.2..2.2); conduit to y 4.5")

def build_junction_box():
    P = "F_JunctionBox"
    box(P, "trim_light", -0.7, 0.7, -0.7, 0.7, -0.6, -0.02, 0.06)
    box(P, "trim_metal", -0.62, 0.62, -0.62, 0.62, -0.65, -0.5, 0.04)
    for x in (-0.48, 0.48):
        for y in (-0.48, 0.48):
            zcyl(P, "dark_metal", -0.6, -0.71, 0.06, x, y, 8)
    box(P, "label_cream", -0.4, 0.4, 0.1, 0.35, -0.69, -0.6, 0.01)
    cyl(P, "dark_metal", 0, -0.3, 0.14, 0.65, 1.6, 10, 0.0)
    cyl(P, "dark_metal", 0, -0.3, 0.14, -1.6, -0.65, 10, 0.0)
    return dict(mount="wall: back at z 0, faces -Z; conduit stubs to y +-1.6")

def build_intercom():
    P = "F_Intercom"
    box(P, "dark_metal", -0.7, 0.7, -1.2, 1.2, -0.25, -0.02, 0.06)
    box(P, "trim_light", -0.6, 0.6, -1.1, 1.1, -0.3, -0.2, 0.04)
    box(P, "void", -0.42, 0.42, 0.1, 0.7, -0.33, -0.25, 0.0)
    for k in range(5):
        y = 0.13 + k * 0.12
        box(P, "dark_metal", -0.45, 0.45, y, y + 0.05, -0.37, -0.28, 0.01)
    box(P, "trim_metal", -0.46, 0.46, -0.4, 0.0, -0.335, -0.27, 0.02)                                  # screen bezel
    box(P, "screen", -0.4, 0.4, -0.35, -0.05, -0.37, -0.3, 0.0)
    zcyl(P, "neon_olive", -0.28, -0.42, 0.12, 0.0, -0.72, 12)                                          # call button
    torus(P, "trim_metal", (0.0, -0.72, -0.31), (0, 0, 1), 0.17, 0.04, seg=16, rseg=6)
    box(P, "label_cream", -0.45, 0.45, 0.8, 1.0, -0.34, -0.28, 0.01)
    cyl(P, "dark_metal", 0, -0.12, 0.08, -2.0, -1.15, 8, 0.0)
    return dict(mount="wall: back at z 0, faces -Z, centre at y 0 (mount ~5 studs up)",
                screens=[dict(w=0.8, h=0.3, mesh_w=0.8, mesh_h=0.3, face="Front", centre=[0.0, -0.2, -0.37])])

# ================================================================== 14: top-player reward stand
def build_reward_stand():
    P = "F_RewardStand"
    lathe(P, "dark_metal", [(0.02, 0.0), (3.4, 0.0), (3.4, 0.5), (3.25, 0.65), (0.02, 0.65)], seg=64)
    lathe(P, "wall_light", [(0.02, 0.6), (2.6, 0.6), (2.6, 3.0), (0.02, 3.0)], seg=64)
    lathe(P, "band_olive", [(2.5, 1.45), (2.66, 1.45), (2.66, 1.95), (2.5, 1.95)], seg=64)
    for y in (1.25, 2.05):
        lathe(P, "trim_cream", [(2.5, y), (2.64, y), (2.64, y + 0.12), (2.5, y + 0.12)], seg=64)
    lathe(P, "trim_metal", [(0.02, 2.95), (2.9, 2.95), (2.9, 3.25), (2.75, 3.4), (0.02, 3.4)], seg=64)
    lathe(P, "case_dark", [(0.02, 3.35), (1.9, 3.35), (1.9, 3.5), (0.02, 3.5)], seg=48)                # display top (y 3.5)
    lathe(P, "neon_cream", [(1.95, 3.3), (2.15, 3.3), (2.15, 3.46), (1.95, 3.46)], seg=64)
    lathe(P, "neon_olive", [(3.6, -0.04), (3.9, -0.04), (3.9, 0.04), (3.6, 0.04)], seg=64)                 # floor ring, 0.04 proud
    torus(P, "halo_cream", (0, 7.6, 0), (0, 1, 0), 1.9, 0.07, seg=64, rseg=8)                          # floating halo ring
    box(P, "sign_board", -1.2, 1.2, 1.15, 2.25, -2.82, -2.3, 0.05)                                    # front name plate
    box(P, "label_cream", -1.05, 1.05, 1.3, 2.1, -2.86, -2.78, 0.02)
    for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):                       # olive feet on the base
        c = Vector((math.cos(a) * 3.0, 0.3, math.sin(a) * 3.0))
        obox(P, "band_olive", c, (math.cos(a), 0, math.sin(a)), (0, 1, 0), (-math.sin(a), 0, math.cos(a)), 0.48, 0.24, 0.3, 0.04)
    return dict(mount="floor: bottom at y 0; display top flat at y 3.5 (r 1.9); spin the reward model at (0, 6, 0) with the LobbySpin tag; "
                      "halo ring r 1.9 at y 7.6; name plate faces -Z", spin_anchor=[0.0, 6.0, 0.0], top_y=3.5,
                label=dict(w=2.1, h=0.8, face="Front", mesh="__label_cream"))

# ================================================================== 3: drop-pit rim (10 x 10 hole)
def build_pit_rim():
    P = "F_PitRim"; A, B = 5.0, 6.0
    for s in (-1, 1):                                                                                  # rim frame, top 0.04 proud
        box(P, "dark_metal", -B, B, -0.6, 0.04, s * A, s * B, 0.05)
        box(P, "dark_metal", s * A, s * B, -0.6, 0.04, -A, A, 0.05)
        box(P, "hazard", -B + 0.12, B - 0.12, 0.0, 0.08, s * (A + 0.12), s * (B - 0.12), 0.0)          # hazard inlay 0.04 above rim
        box(P, "hazard", s * (A + 0.12), s * (B - 0.12), 0.0, 0.08, -A + 0.05, A - 0.05, 0.0)
        box(P, "trim_metal", -A + 0.08, A - 0.08, -0.35, 0.0, s * (A - 0.08), s * (A + 0.1), 0.02)     # inner lip angle
        box(P, "trim_metal", s * (A - 0.08), s * (A + 0.1), -0.35, 0.0, -A + 0.08, A - 0.08, 0.02)
        box(P, "grate", -A + 0.04, A - 0.04, -0.95, -0.8, s * (A - 0.8), s * (A + 0.04), 0.0)          # grate ledge
        box(P, "grate", s * (A - 0.8), s * (A + 0.04), -0.95, -0.8, -A + 0.84, A - 0.84, 0.0)
        box(P, "wall_dark", -A - 0.4, A + 0.4, -8.0, -0.5, s * (A + 0.04), s * (A + 0.4), 0.0)          # shaft liner
        box(P, "wall_dark", s * (A + 0.04), s * (A + 0.4), -8.0, -0.5, -A - 0.04, A + 0.04, 0.0)
        box(P, "neon_olive", -A + 0.5, A - 0.5, -2.2, -2.0, s * (A + 0.0), s * (A + 0.06), 0.0)        # olive warning line in the shaft
        box(P, "neon_olive", s * (A + 0.0), s * (A + 0.06), -2.2, -2.0, -A + 0.5, A - 0.5, 0.0)
    box(P, "void", -A - 0.04, A + 0.04, -8.1, -7.95, -A - 0.04, A + 0.04, 0.0)                        # black bottom
    return dict(mount="floor: hole 10 x 10 centred on the origin, floor top y 0; rim 12 x 12 (top y 0.04, hazard 0.08); shaft to y -8 "
                      "(void bottom). Cut a 10 x 10 hole in the floor; put the teleporter From part inside the shaft (e.g. y -6, 10 x 2 x 10).")

# ================================================================== 29: truss spotlight + truss segment
def build_truss_spot():
    P = "F_TrussSpot"
    torus(P, "dark_metal", (0, 0, 0), (1, 0, 0), 0.38, 0.08, a0=0.0, a1=math.pi, seg=24, rseg=8, u=(0, 0, 1))   # clamp over a r 0.3 tube
    box(P, "dark_metal", -0.25, 0.25, -0.75, -0.3, -0.48, 0.48, 0.05)
    zcyl(P, "trim_metal", -0.6, 0.6, 0.07, 0.0, -0.55, 8)
    cyl(P, "beam_metal", 0, 0, 0.12, -1.25, -0.7, 12, 0.0)
    box(P, "trim_metal", -1.0, 1.0, -1.4, -1.2, -0.17, 0.17, 0.04)                                   # yoke
    for s in (-1, 1):
        box(P, "trim_metal", s * 0.84, s * 1.0, -2.65, -1.25, -0.17, 0.17, 0.04)
        xcyl(P, "dark_metal", s * 0.62, s * 1.08, 0.14, -2.35, 0.0, 12)
    lathe(P, "beam_metal", [(0.02, -1.55), (0.5, -1.55), (0.66, -1.7), (0.66, -3.1), (0.76, -3.15), (0.76, -3.3), (0.58, -3.3),
                            (0.58, -3.18), (0.02, -3.18)], seg=32)
    for y in (-1.95, -2.2, -2.45, -2.7):
        lathe(P, "dark_metal", [(0.6, y), (0.72, y), (0.72, y + 0.07), (0.6, y + 0.07)], seg=32)       # cooling fins
    lathe(P, "lens_warm", [(0.02, -3.26), (0.6, -3.26), (0.6, -3.22), (0.02, -3.22)], seg=32)
    for k in range(4):                                                                                 # barn doors
        a = k * math.pi / 2
        d = Vector((math.cos(a), 0, math.sin(a))); t = Vector((-math.sin(a), 0, math.cos(a)))
        ang = math.radians(25); dn = (d * math.sin(ang) + Vector((0, -1, 0)) * math.cos(ang)).normalized()
        c = d * 0.8 + Vector((0, -3.3, 0)) + dn * 0.3
        obox(P, "dark_metal", c, t, dn, dn.cross(t), 0.5, 0.3, 0.025, 0.01)
    cyl(P, "band_olive", 0, 0, 0.15, -1.15, -0.95, 12, 0.02)
    return dict(mount="clamps on a horizontal tube along X (axis through the origin, tube r 0.3); can aims -Y; rotate about X/Z to aim. "
                      "SpotLight on the lens mesh (Face Bottom): 255,241,208, brightness 1.5-2.5, range 30-60, shadows on 1-2 only",
                lens="__lens_warm")

def build_truss():
    P = "F_Truss10"; L = 5.0; h = 0.6
    for y in (-h, h):
        for z in (-h, h):
            xcyl(P, "beam_metal", -L + 0.1, L - 0.1, 0.12, y, z, 10)
    n = 8
    for i in range(n):                                                                                 # zigzag diagonals on 4 faces
        x0 = -L + 0.15 + i * (2 * L - 0.3) / n; x1 = x0 + (2 * L - 0.3) / n
        a, b = (x0, x1) if i % 2 == 0 else (x1, x0)
        rod(P, "beam_metal", (a, -h, -h), (b, h, -h), 0.06, 6); rod(P, "beam_metal", (a, -h, h), (b, h, h), 0.06, 6)
        rod(P, "beam_metal", (a, h, -h), (b, h, h), 0.06, 6); rod(P, "beam_metal", (a, -h, -h), (b, -h, h), 0.06, 6)
    for s in (-1, 1):
        box(P, "dark_metal", s * (L - 0.15), s * L, -h - 0.25, h + 0.25, -h - 0.25, h + 0.25, 0.05)
    return dict(mount="square box truss 1.2 x 1.2, length 10 along X, chords r 0.12 at y/z +-0.6 (chords are where F_TrussSpot clamps; "
                      "its tube r 0.3 clamp also fits)")

# ================================================================== 30: beacons
def beacon_head(P, y):
    lathe(P, "dark_metal", [(0.02, y), (0.62, y), (0.62, y + 0.25), (0.02, y + 0.25)], seg=32)
    lathe(P, "trim_metal", [(0.02, y + 0.2), (0.45, y + 0.2), (0.45, y + 0.6), (0.02, y + 0.6)], seg=32)
    lathe(P, "lens_amber", [(0.02, y + 0.55), (0.4, y + 0.55), (0.4, y + 0.9), (0.3, y + 1.15), (0.15, y + 1.25), (0.02, y + 1.28)], seg=32)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rod(P, "dark_metal", (math.cos(a) * 0.5, y + 0.25, math.sin(a) * 0.5), (math.cos(a) * 0.5, y + 1.36, math.sin(a) * 0.5), 0.045, 6)
    torus(P, "dark_metal", (0, y + 0.85, 0), (0, 1, 0), 0.5, 0.045, seg=32, rseg=6)
    lathe(P, "dark_metal", [(0.02, y + 1.32), (0.56, y + 1.32), (0.56, y + 1.42), (0.02, y + 1.42)], seg=32)
    cyl(P, "trim_metal", 0, 0, 0.04, y + 1.42, y + 2.4, 6, 0.0)                                       # lightning rod

def build_beacon_mast():
    P = "F_BeaconMast"; H = 12.0
    box(P, "dark_metal", -0.8, 0.8, 0.0, 0.2, -0.8, 0.8, 0.04)
    for x in (-0.6, 0.6):
        for z in (-0.6, 0.6):
            cyl(P, "trim_metal", x, z, 0.08, 0.15, 0.32, 8, 0.02)
    lathe(P, "beam_metal", [(0.02, 0.15), (0.32, 0.15), (0.22, H + 0.05), (0.02, H + 0.05)], seg=24)
    for i in range(5):                                                                                 # aviation stripes in palette
        y0 = 2.0 + i * 2.0; r = 0.32 - 0.1 * (y0 + 1.0) / H + 0.04
        lathe(P, "band_olive" if i % 2 == 0 else "trim_cream", [(r - 0.08, y0), (r, y0), (r, y0 + 1.0), (r - 0.08, y0 + 1.0)], seg=24)
    beacon_head(P, H)
    return dict(mount="floor / roof: base at y 0, 12-stud mast, lens dome at y 12.55-13.3; PointLight in the lens (amber 255,170,40 or red "
                      "220,40,40), slow pulse", lens="__lens_amber")

def build_beacon_wall():
    P = "F_BeaconWall"
    box(P, "dark_metal", -0.5, 0.5, -0.7, 0.7, -0.25, -0.02, 0.05)
    box(P, "trim_metal", -0.2, 0.2, -0.11, 0.11, -1.35, -0.2, 0.04)
    obox(P, "trim_metal", (0, -0.4, -0.55), (0, 0, 1), (0, 1, -1), (1, 0, 0), 0.45, 0.06, 0.12, 0.02)  # diagonal brace
    lathe(P, "dark_metal", [(0.02, -0.15), (0.3, -0.15), (0.3, 0.15), (0.02, 0.15)], cx=0.0, cz=-1.0, seg=24)
    beacon_head_at(P, 0.15, -1.0)
    return dict(mount="wall: back at z 0; arm out 1 stud (-Z), lens dome at (0, 0.7..1.43, -1)", lens="__lens_amber")

def beacon_head_at(P, y, cz):
    # same head as beacon_head, centred at z = cz
    lathe(P, "dark_metal", [(0.02, y), (0.62, y), (0.62, y + 0.25), (0.02, y + 0.25)], cz=cz, seg=32)
    lathe(P, "trim_metal", [(0.02, y + 0.2), (0.45, y + 0.2), (0.45, y + 0.6), (0.02, y + 0.6)], cz=cz, seg=32)
    lathe(P, "lens_amber", [(0.02, y + 0.55), (0.4, y + 0.55), (0.4, y + 0.9), (0.3, y + 1.15), (0.15, y + 1.25), (0.02, y + 1.28)], cz=cz, seg=32)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rod(P, "dark_metal", (math.cos(a) * 0.5, y + 0.25, cz + math.sin(a) * 0.5), (math.cos(a) * 0.5, y + 1.36, cz + math.sin(a) * 0.5), 0.045, 6)
    torus(P, "dark_metal", (0, y + 0.85, cz), (0, 1, 0), 0.5, 0.045, seg=32, rseg=6)
    lathe(P, "dark_metal", [(0.02, y + 1.32), (0.56, y + 1.32), (0.56, y + 1.42), (0.02, y + 1.42)], cz=cz, seg=32)

# ================================================================== 31: hologram cone emitter
def build_holo_emitter():
    P = "F_HoloEmitter"
    lathe(P, "dark_metal", [(0.02, 0.0), (1.8, 0.0), (1.8, 0.2), (1.6, 0.35), (0.02, 0.35)], seg=48)
    lathe(P, "trim_metal", [(0.02, 0.3), (1.45, 0.3), (1.45, 0.7), (1.2, 0.85), (0.02, 0.85)], seg=48)
    lathe(P, "band_olive", [(1.4, 0.42), (1.5, 0.42), (1.5, 0.6), (1.4, 0.6)], seg=48)
    lathe(P, "neon_cream", [(0.75, 0.8), (0.95, 0.8), (0.95, 0.9), (0.75, 0.9)], seg=48)
    lathe(P, "holo_lens", [(0.02, 0.8), (0.6, 0.8), (0.6, 0.93), (0.02, 0.93)], seg=32)
    lathe(P, "neon_olive", [(2.0, 0.0), (2.25, 0.0), (2.25, 0.04), (2.0, 0.04)], seg=64)
    for k in range(3):                                                                                 # radial fins
        a = k * 2 * math.pi / 3 + math.pi / 6
        d = Vector((math.cos(a), 0, math.sin(a)))
        obox(P, "trim_light", d * 1.55 + Vector((0, 0.5, 0)), d, (0, 1, 0), d.cross(Vector((0, 1, 0))), 0.25, 0.3, 0.08, 0.03)
    lathe(P, "holo_cone", [(0.6, 0.95), (2.4, 5.5), (2.36, 5.5), (0.56, 0.95)], seg=48)              # optional cone shell
    return dict(mount="floor: base at y 0, emitter top at y 0.93; hologram / model centred at (0, 3.5, 0); holo_cone mesh optional "
                      "(Transparency 0.85, or replace with a Beam); sparkles on the lens attachment", spin_anchor=[0.0, 3.5, 0.0])

# ================================================================== Training: swap bin + cover crates
def build_swap_bin():
    P = "F_SwapBin"
    box(P, "crate_green", -1.5, 1.5, 0.0, 2.5, -1.5, 1.5, 0.1, 2)                                     # = old Body 3 x 2.5 x 3
    box(P, "dark_metal", -1.6, 1.6, 2.495, 2.845, -1.6, 1.6, 0.06)                                    # = old Lid 3.2 x 0.35 x 3.2
    box(P, "neon_cream", -1.53, 1.53, 1.65, 1.95, -1.53, 1.53, 0.0)                                   # = old Stripe, 0.03 proud
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(P, "trim_metal", sx * 1.15, sx * 1.57, 0.04, 2.55, sz * 1.15, sz * 1.57, 0.04)          # corner posts 0.07 proud
        box(P, "dark_metal", sx * 1.5, sx * 1.64, 2.05, 2.3, -0.6, 0.6, 0.03)                          # side grab handles
    box(P, "label_cream", -0.8, 0.8, 0.55, 1.35, -1.54, -1.45, 0.02)                                  # front plate (WEAPONS text)
    box(P, "dark_metal", -0.22, 0.22, 2.2, 2.62, -1.66, -1.45, 0.03)                                  # front latch
    for sx in (-1, 1):
        box(P, "dark_metal", sx * 0.95 - 0.06, sx * 0.95 + 0.06, 0.5, 1.4, -1.54, -1.48, 0.01)        # plate side rails
    return dict(mount="floor: bottom at y 0, front plate faces -Z (the old script points -Z at the room centre with CFrame.lookAt)",
                replaces=dict(model="LobbyMap.Training.Extras.SwapBins.SwapBin", body=[3, 2.5, 3], body_centre=[0, 1.25, 0],
                              lid=[3.2, 0.35, 3.2], lid_centre=[0, 2.67, 0], stripe=[3.06, 0.3, 3.06], stripe_centre=[0, 1.8, 0],
                              prompt="Attachment PromptAt at Body local (0, 1.6, 0) = (0, 2.85, 0) on the lid top; keep the BinPrompt "
                                     "ProximityPrompt (TrainingBin attr) and the Model attribute TrainingBin; PrimaryPart = the body mesh "
                                     "(F_SwapBin__crate_green, bounds exactly 3 x 2.5 x 3, centre y 1.25) so GetPivot() is unchanged",
                              lid_top_y=2.845))

def crate(P, s, var):
    h = s / 2
    box(P, "crate_green", -h, h, 0.0, s, -h, h, 0.12, 2)                                              # collision body = s x s x s exactly
    if var == "A":      # strapped: two wrap straps + 8 corner caps + stencil plates
        for fy in (0.22, 0.78):
            y = s * fy
            box(P, "dark_metal", -h - 0.05, h + 0.05, y - 0.175, y + 0.175, -h - 0.05, h + 0.05, 0.03)
        for sx in (-1, 1):
            for sz in (-1, 1):
                for (y0, y1) in ((0.04, 0.55), (s - 0.55, s + 0.09)):
                    box(P, "trim_metal", sx * (h - 0.5), sx * (h + 0.09), y0, y1, sz * (h - 0.5), sz * (h + 0.09), 0.04)
        for sz in (-1, 1):
            box(P, "label_cream", -0.7, 0.7, s * 0.5 - 0.25, s * 0.5 + 0.2, sz * (h - 0.05), sz * (h + 0.03), 0.01)
    elif var == "B":    # framed: 12 edge bars + strap over the top + X brace on two faces
        e = 0.38
        for sx in (-1, 1):
            for sz in (-1, 1):
                box(P, "dark_metal", sx * (h - e), sx * (h + 0.06), 0.04, s + 0.06, sz * (h - e), sz * (h + 0.06), 0.04)
        for (y0, y1) in ((0.04, e), (s - e, s + 0.06)):
            for sz in (-1, 1):
                box(P, "dark_metal", -h + e, h - e, y0, y1, sz * (h - e), sz * (h + 0.06), 0.04)
            for sx in (-1, 1):
                box(P, "dark_metal", sx * (h - e), sx * (h + 0.06), y0, y1, -h + e, h - e, 0.04)
        box(P, "trim_metal", -h - 0.1, h + 0.1, 0.08, s + 0.1, -0.2, 0.2, 0.02)                     # strap over the top
        L = (s - 2 * e) * math.sqrt(2) / 2
        for sz in (-1, 1):
            for d in (1, -1):
                eu = Vector((1, d, 0)).normalized()
                obox(P, "crate_trim", (0, s / 2, sz * (h + 0.015)), eu, Vector((-d, 1, 0)).normalized(), (0, 0, 1), L - 0.05, 0.16, 0.035, 0.02)
        for sx in (-1, 1):
            box(P, "label_cream", sx * (h - 0.05), sx * (h + 0.03), s * 0.55, s * 0.55 + 0.4, -0.75, -0.25, 0.01)
    else:               # C ribbed: plank ribs, corner posts, lid frame, rope handles
        for fy in (0.3, 0.5, 0.7):
            y = s * fy
            box(P, "crate_trim", -h - 0.04, h + 0.04, y - 0.12, y + 0.12, -h - 0.04, h + 0.04, 0.03)
        for sx in (-1, 1):
            for sz in (-1, 1):
                box(P, "dark_metal", sx * (h - 0.3), sx * (h + 0.08), 0.04, s - 0.36, sz * (h - 0.3), sz * (h + 0.08), 0.04)
        for sz in (-1, 1):
            box(P, "trim_metal", -h - 0.12, h + 0.12, s - 0.32, s + 0.05, sz * (h - 0.3), sz * (h + 0.12), 0.03)
        for sx in (-1, 1):
            box(P, "trim_metal", sx * (h - 0.3), sx * (h + 0.12), s - 0.32, s + 0.05, -h + 0.3, h - 0.3, 0.03)
            box(P, "dark_metal", sx * h, sx * (h + 0.16), s * 0.82, s * 0.82 + 0.16, -0.55, 0.55, 0.03)   # handle bar
            for zz in (-0.55, 0.55):
                box(P, "dark_metal", sx * h, sx * (h + 0.16), s * 0.82 - 0.2, s * 0.82 + 0.16, zz - 0.08, zz + 0.08, 0.02)
        box(P, "label_cream", -0.6, 0.6, s * 0.83 - 0.15, s * 0.83 + 0.15, -h - 0.05, -h + 0.02, 0.01)

def build_crate(s, var):
    P = "F_Crate%d%s" % (s, var)
    crate(P, s, var)
    n = {4: 20, 5: 4}[s]
    return dict(mount="floor: bottom at y 0, centred on x/z", variant=var,
                replaces=dict(kind="crate", part="Range2.Cover.Crate (+ 2 CrateStrap parts per crate)", size=[s, s, s],
                              part_centre=[0, s / 2, 0], count_in_training=n,
                              collision="body mesh F_%s__crate_green: bounds exactly %d x %d x %d, CanCollide + CanQuery on, NO NotCover "
                                        "(crates are cover); CollisionFidelity Box. All other meshes: decor (CanCollide/CanQuery/CanTouch off, "
                                        "NotCover true), like the old CrateStrap parts" % (P[2:], s, s, s)))

def build_markers5():
    box("K_Scale5", "label_cream", -5, 5, 115, 125, -5, 5, 0.0)
    box("K_Marker5", "neon_olive", 15, 25, 115, 117, -1, 1, 0.0)
    box("K_Marker5", "neon_olive", 15, 17, 117, 123, -1, 1, 0.0)
    box("K_Marker5", "neon_olive", 15, 17, 115, 117, 1, 5, 0.0)

# ================================================================== checks
def coplanar_check(piece, tol=0.029, min_area=0.004):
    """Same-facing axis-aligned faces of DIFFERENT materials within tol of each other with overlapping rects."""
    faces = []
    for (p, m), bm in ACC.items():
        if p != piece:
            continue
        bm.normal_update()
        for f in bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            if abs(n[ax]) < 0.999 or f.calc_area() < min_area:
                continue
            o = [i for i in range(3) if i != ax]
            vs = [v.co for v in f.verts]
            faces.append((ax, 1 if n[ax] > 0 else -1, vs[0][ax], m,
                          min(v[o[0]] for v in vs), max(v[o[0]] for v in vs), min(v[o[1]] for v in vs), max(v[o[1]] for v in vs)))
    faces.sort(key=lambda t: (t[0], t[1], t[2]))
    hits = []
    for i in range(len(faces)):
        a = faces[i]
        for j in range(i + 1, len(faces)):
            b = faces[j]
            if b[0] != a[0] or b[1] != a[1] or b[2] - a[2] > tol:
                break
            if a[3] == b[3]:
                continue
            ox = min(a[5], b[5]) - max(a[4], b[4]); oy = min(a[7], b[7]) - max(a[6], b[6])
            if ox > 0.01 and oy > 0.01:
                hits.append(dict(mats=[a[3], b[3]], axis="xyz"[a[0]], sign=a[1], d=[round(a[2], 3), round(b[2], 3)], area=round(ox * oy, 3)))
    return hits

# ================================================================== build all
BUILDERS = [
    ("F_TVArmWall", build_tv_wall, "26"), ("F_TVArmCeil", lambda: build_tv_ceil(False), "26"), ("F_TVArmCeilDual", lambda: build_tv_ceil(True), "26"),
    ("F_Screen16x9", lambda: build_screen_frame(16.0, 9.0, "F_Screen16x9"), "18/19/4"),
    ("F_Screen12x4", lambda: build_screen_frame(12.0, 4.0, "F_Screen12x4"), "21"),
    ("F_Container20", lambda: build_container("F_Container20", 16.0), "27"), ("F_Container10", lambda: build_container("F_Container10", 8.0), "27"),
    ("F_PipeStraight", build_pipe_straight, "27"), ("F_PipeElbow", build_pipe_elbow, "27"), ("F_PipeValve", build_pipe_valve, "27"),
    ("F_PipeRun", build_pipe_run, "27"), ("F_PowerBox", build_power_box, "27"), ("F_JunctionBox", build_junction_box, "27"),
    ("F_Intercom", build_intercom, "27"), ("F_RewardStand", build_reward_stand, "14"), ("F_PitRim", build_pit_rim, "3"),
    ("F_TrussSpot", build_truss_spot, "29"), ("F_Truss10", build_truss, "29"), ("F_BeaconMast", build_beacon_mast, "30"),
    ("F_BeaconWall", build_beacon_wall, "30"), ("F_HoloEmitter", build_holo_emitter, "31"),
    ("F_SwapBin", build_swap_bin, "Training"),
] + [("F_Crate%d%s" % (s, v), (lambda s=s, v=v: build_crate(s, v)), "Training") for s in (4, 5) for v in "ABC"]

# collision policy per piece: "none" = all decor; "solid" = structural mats collide; "body" = only the listed body mesh
COLL = {"F_Container20": "solid", "F_Container10": "solid", "F_PowerBox": "solid", "F_RewardStand": "solid", "F_PitRim": "pit",
        "F_HoloEmitter": "solid", "F_PipeStraight": "solid", "F_PipeElbow": "solid", "F_PipeValve": "solid", "F_PipeRun": "solid",
        "F_SwapBin": "bin", "F_BeaconMast": "solid"}
DECOR_MATS = {"neon_lamp", "neon_cream", "neon_olive", "void", "glass", "label_cream", "screen", "screen_b", "hazard", "ceiling_gloss",
              "sign_board", "lens_warm", "lens_amber", "holo_lens", "holo_cone", "halo_cream", "grate", "trim_cream"}

def piece_bounds(piece):
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for (p, m), bm in ACC.items():
        if p == piece:
            for v in bm.verts:
                for i in range(3):
                    mn[i] = min(mn[i], v.co[i]); mx[i] = max(mx[i], v.co[i])
    return mn, mx

def build_all():
    clear_scene()
    ACC.clear()
    info = {}; cursor = 0.0; checks = {}
    for (piece, fn, item) in BUILDERS:
        meta = fn() or {}
        checks[piece] = coplanar_check(piece)
        mn, mx = piece_bounds(piece)
        dx = cursor - mn.x
        for (p, m), bm in ACC.items():
            if p == piece:
                bm.transform(Matrix.Translation((dx, 0, 0)))
        meta.update(item=item, pivot_studio=[round(dx, 3), 0.0, 0.0],
                    bounds_rel_pivot=dict(min=[round(v, 3) for v in mn], max=[round(v, 3) for v in mx]))
        info[piece] = meta
        cursor += (mx.x - mn.x) + 4.0
    build_markers5()
    stats = finalize()
    return info, stats, checks

def mesh_fields(st, piece, info):
    mat = st["material"]
    if piece.startswith("K_"):
        base, var = "SmoothPlastic", ""
    elif mat.startswith(("neon", "lens", "holo", "halo")) or mat == "void":
        base, var = "Neon", ""
    elif mat in ("screen", "screen_b", "glass"):
        base, var = "Glass", ""
    else:
        base, var = studio_fields(mat)
    rgb = STUDIO_RGB_F.get(mat, st["rgb"])
    if piece in FX_PIECES:
        rgb = FX_RGB.get(mat, rgb)
    pol = COLL.get(piece, "none" if not piece.startswith("F_Crate") else "body")
    if pol == "solid":
        coll = mat not in DECOR_MATS
    elif pol == "pit":
        coll = mat in ("dark_metal", "wall_dark")
    elif pol in ("body", "bin"):
        coll = mat == "crate_green" if pol == "body" else mat in ("crate_green", "dark_metal")
    else:
        coll = False
    piv = info.get(piece, {}).get("pivot_studio", [0, 0, 0])
    e = dict(st)
    e["rgb_kit"] = list(st["rgb"]); e["rgb"] = list(rgb)
    e["material_studio"] = base; e["variant"] = var; e["variant_folder"] = "MaterialService.TacHub1" if var else ""
    e["can_collide"] = coll; e["can_query"] = coll; e["can_touch"] = False
    e["not_cover"] = not (piece.startswith(("F_Crate", "F_Container", "F_SwapBin")) and coll)   # old Crate / bin Body + Lid had no NotCover
    e["collision_fidelity"] = "Box" if (piece.startswith(("F_Crate", "F_SwapBin", "F_PitRim", "F_Container")) or not coll) else "Hull"
    e["cast_shadow"] = not (base == "Neon" or mat in ("glass",))
    e["transparency"] = {"glass": 0.6, "holo_cone": 0.85}.get(mat, 0.0)
    e["texture_overlay"] = {"hazard": "TX_hazard_stripe 4x1 Top", "grate": "TX_grate_alpha 3x3"}.get(mat, "")
    e["center_rel_pivot"] = [round(e["center_studio"][i] - piv[i], 3) for i in range(3)]
    e["role"] = "screen" if mat in ("screen", "screen_b") else ("lens" if mat.startswith(("lens", "holo_lens")) else
                ("label" if mat == "label_cream" else ("collision_body" if coll and piece.startswith(("F_Crate", "F_SwapBin")) and mat == "crate_green" else "")))
    return e

def export_and_save(info, stats, checks):
    man = {"_note": "features kit (2026-10-15). Studio coords; each piece authored at its pivot then slid along +X (pivot_studio). "
                    "Import 3D with Insert Using Scene Position (group Gunsy Funsy); per piece: Model from its meshes, PivotOffset/CFrame = "
                    "pivot_studio; mesh CFrame = pivot + center_rel_pivot. Front = -Z (Roblox Front face). K_Scale5 10-stud cube at (0,120,0), "
                    "K_Marker5 long arm +X, upright +Y, short arm +Z.",
           "pieces": {}, "meshes": []}
    for st in stats:
        piece = st["piece"]
        e = mesh_fields(st, piece, info)
        man["meshes"].append(e)
    for piece, meta in info.items():
        ms = [m for m in man["meshes"] if m["piece"] == piece]
        meta = dict(meta)
        meta["meshes"] = [m["name"] for m in ms]
        meta["tris"] = sum(m["tris"] for m in ms)
        meta["max_mesh_tris"] = max(m["tris"] for m in ms)
        meta["coplanar_flags"] = checks.get(piece, [])
        man["pieces"][piece] = meta
    with open(KIT + "features_manifest.json", "w") as f:
        json.dump(man, f, indent=1)
    # collections already: finalize puts F_* into coll_for(piece)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=KIT + "features.fbx", use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0, axis_forward="-Z", axis_up="Y",
                             add_leaf_bones=False, path_mode="STRIP", bake_anim=False)
    bpy.ops.object.select_all(action="DESELECT")
    return man

def coll_for(piece):   # override: one collection per item group
    if piece.startswith("K_"):
        return "F_Markers"
    return "F_Kit"

if __name__ == "__main__":
    INFO, STATS, CHECKS = build_all()
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob["piece"] = ob.name.split("__")[0]
    MAN = export_and_save(INFO, STATS, CHECKS)
    bpy.ops.wm.save_as_mainfile(filepath=KIT + "features_kit.blend")
    bad = {p: len(v) for p, v in CHECKS.items() if v}
    print("FEATURES_DONE meshes=%d pieces=%d coplanar=%s maxtris=%d" % (len(STATS), len(INFO), bad, max(s["tris"] for s in STATS)))
