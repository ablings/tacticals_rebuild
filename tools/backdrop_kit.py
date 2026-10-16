"""Tacticals sky backdrop kit (backdrop_sky): four floating base platforms in the RIVALS craft (chamfered slabs, bevels, neutral
greys, thin olive / cream accent lines) and the Tacticals palette. Own geometry only (bmesh + the hub_kit helpers).
Matches the Parts blockout of fix/backdrop_sky.lua (same sizes; cables and clouds stay Parts in Studio).

Every piece is authored at ITS OWN PIVOT (deck top centre) in Studio coordinates (x east, y up, z north; the pad-facing side is
-X) and slid along +X into a row so nothing overlaps in the FBX. The manifest gives each piece's pivot in the FBX, its world
placement (= the blockout's position) and every mesh's centre relative to the pivot.

Run via the Blender MCP (background): execute_blender_code_for_cli(blend_file=<any kit .blend>,
  code='exec(open(r"C:/Users/aroki/Documents/tacticals_rebuild/tools/backdrop_kit.py").read())')
or: blender -b --factory-startup --python tools/backdrop_kit.py
Writes kit/backdrop.blend, kit/backdrop.fbx, kit/backdrop_manifest.json, out/polish/backdrop/bl_preview.png. Never calls read_homefile.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

_HK = r"C:/Users/aroki/Documents/tacticals_rebuild/tools/hub_kit.py"
_src = open(_HK).read().rsplit('if __name__ == "__main__" or True:', 1)[0]
exec(_src, globals())   # MATS, make_material, acc, box, prism, chamfer_poly, lathe, cyl, rod, finalize, clear_scene, S2B

KIT = ROOT + "/kit/"
OUT = ROOT + "/out/polish/backdrop/"
os.makedirs(OUT, exist_ok=True)

# name: (sRGB, colour tex, studs per tile, metallic, roughness, emissive, studio material)
MATS.update({
    "deck_top":   ((163, 162, 165), "hub_concrete_panels", 40, 0.0, 0.8, False, "Concrete + TacConcretePanels"),
    "deck_side":  ((124, 123, 126), "hub_concrete_smooth", 30, 0.0, 0.8, False, "Concrete + TacConcrete"),
    "hull":       ((84, 84, 88),    "hub_metal_satin", 30, 0.8, 0.5, False, "Metal + TacMetal"),
    "hull_dark":  ((58, 58, 62),    "hub_metal_satin", 30, 0.8, 0.5, False, "Metal + TacMetal"),
    "shed_wall":  ((200, 196, 186), "hub_concrete_panels", 30, 0.0, 0.8, False, "Concrete + TacConcretePanels (warm grey)"),
    "roof_metal": ((124, 123, 126), "hub_corrugated_metal", 24, 0.6, 0.5, False, "Metal + TacCorrugatedMetal"),
    "door_dark":  ((34, 35, 36),    "hub_corrugated_metal", 16, 0.3, 0.7, False, "Concrete (matte near-black)"),
    "band_olive": ((138, 130, 60),  "hub_concrete_smooth", 12, 0.0, 0.7, False, "SmoothPlastic (olive paint 138,130,60)"),
    "line_cream": ((236, 232, 218), None, 10, 0.0, 0.6, False, "SmoothPlastic (cream paint)"),
    "tank_cream": ((236, 232, 218), "hub_metal_satin", 20, 0.3, 0.5, False, "SmoothPlastic (cream)"),
    "tank_sage":  ((167, 173, 152), "hub_metal_satin", 20, 0.3, 0.5, False, "SmoothPlastic (sage)"),
    "olive_dark": ((107, 122, 58),  "hub_metal_satin", 20, 0.3, 0.5, False, "SmoothPlastic (dark olive)"),
    "mast_metal": ((124, 123, 126), "hub_metal_satin", 10, 0.85, 0.42, False, "Metal + TacMetal"),
    "glass_dark": ((10, 12, 10),    None, 10, 0.0, 0.1, False, "Glass (near-black)"),
    "neon_sage":  ((150, 166, 120), None, 10, 0.0, 0.5, True, "Neon 150,166,120"),
    "neon_cream": ((226, 220, 196), None, 10, 0.0, 0.5, True, "Neon 226,220,196"),
})

OX = 0.0   # current piece slide along +X
def P(x, y, z): return (x + OX, y, z)

def slab(piece, mat, cx, cz, sx, sz, c, y0, y1, bev=0.25):
    """Chamfered slab (45-degree vertical edges), top/bottom edges bevelled."""
    hx, hz = sx / 2, sz / 2
    poly = chamfer_poly([(cx - hx, 0, cz - hz), (cx + hx, 0, cz - hz), (cx + hx, 0, cz + hz), (cx - hx, 0, cz + hz)], c)
    bm = acc(piece, mat)
    a = [bm.verts.new(Vector((p[0] + OX, y0, p[2]))) for p in poly]
    b = [bm.verts.new(Vector((p[0] + OX, y1, p[2]))) for p in poly]
    n = len(poly)
    fb = bm.faces.new(a[::-1]); ft = bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    if bev > 0:
        edges = [e for e in fb.edges] + [e for e in ft.edges]
        bmesh.ops.bevel(bm, geom=edges, offset=min(bev, (y1 - y0) * 0.3), offset_type="OFFSET", segments=1, profile=0.5,
                        affect="EDGES", clamp_overlap=True)

def bx(piece, mat, cx, cy, cz, sx, sy, sz, bev=0.2):
    box(piece, mat, cx - sx / 2 + OX, cx + sx / 2 + OX, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2, bev)

def ring(piece, mat, cx, cz, r0, r1, y0, y1, seg=48):
    lathe(piece, mat, [(r0, 0), (r1, 0), (r1, y1 - y0), (r0, y1 - y0)], cx=cx + OX, cz=cz, seg=seg, y0=y0)

def disc(piece, mat, cx, cz, r, y0, y1, seg=48, bev=0.2):
    cyl(piece, mat, cx + OX, cz, r, y0, y1, seg=seg, bev=bev)

def revolve(piece, mat, prof, M, seg=32):
    """Revolve an open (r, h) profile (r = 0 at the ends allowed) about local +Y, then transform by M (studio space)."""
    bm = acc(piece, mat)
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ca, sa = math.cos(a), math.sin(a)
        rings.append([bm.verts.new(M @ Vector((r * ca, h, r * sa))) for (r, h) in prof])
    n = len(prof)
    for i in range(seg):
        A, B = rings[i], rings[(i + 1) % seg]
        for k in range(n - 1):
            bm.faces.new((A[k], B[k], B[k + 1], A[k + 1]))
    bmesh.ops.remove_doubles(bm, verts=[v for r in rings for v in r], dist=1e-4)

def hull(piece, cx, cz, sx, sz, c, ringR, neon="neon_sage", top=-8.0):
    """Stepped hull under a deck whose underside is at y = top: two chamfered tiers, a Neon anti-grav ring, a thruster pod."""
    slab(piece, "hull", cx, cz, sx * 0.78, sz * 0.78, c * 0.78, top - 6, top)
    slab(piece, "hull_dark", cx, cz, sx * 0.52, sz * 0.52, c * 0.52, top - 10, top - 6)
    ring(piece, neon, cx, cz, ringR - 2.2, ringR, top - 11.2, top - 10)
    disc(piece, "hull_dark", cx, cz, ringR - 2.2, top - 11.2, top - 10, bev=0)
    lathe(piece, "hull_dark", [(0, 0), (ringR - 2, 0), (ringR - 2.6, -1.5), (ringR - 4.5, -3), (0, -3)], cx=cx + OX, cz=cz, seg=48, y0=top - 11.2)
    disc(piece, "neon_cream", cx, cz, ringR * 0.38, top - 14.3, top - 14.1, bev=0)

def mast(piece, x, y0, z, h):
    bx(piece, "mast_metal", x, y0 + h / 2, z, 1.2, h, 1.2, 0.1)
    bx(piece, "band_olive", x, y0 + h * 0.6, z, 1.4, 1.4, 1.4, 0.1)
    bx(piece, "neon_cream", x, y0 + h + 0.9, z, 1.8, 1.8, 1.8, 0.2)

INFO = {}

def hangar_deck():
    p = "B_HangarDeck"
    slab(p, "deck_side", 0, 0, 130, 80, 14, -8, -0.4)
    slab(p, "deck_top", 0, 0, 130.2, 80.2, 14.05, -0.4, 0, bev=0.1)
    slab(p, "band_olive", 0, 0, 130.4, 80.4, 14.1, -2.7, -1.7, bev=0.1)
    hull(p, -25, 0, 80, 70, 12, 15)
    hull(p, 32, 0, 60, 60, 10, 12)
    bxs, bzs = 18, -6
    bx(p, "shed_wall", bxs, 11, bzs, 66, 22, 48, 0.4)
    # chamfered roof: a prism along x with a 45-degree chamfer on both long edges
    prof = [(-24.2, 22), (24.2, 22), (24.2, 23), (16.2, 28), (-16.2, 28), (-24.2, 23)]
    prism(p, "roof_metal", [P(bxs - 33.2, y, bzs + z) for z, y in prof][::-1], (66.4, 0, 0))
    bx(p, "band_olive", bxs, 19.5, bzs, 66.6, 1.2, 48.6, 0.1)
    bx(p, "door_dark", bxs - 33.1, 6.5, bzs, 0.6, 13, 34, 0.05)
    bx(p, "line_cream", bxs - 33.3, 13.5, bzs, 0.8, 1, 36, 0.1)
    for s in (-1, 1):
        bx(p, "line_cream", bxs - 33.3, 6.5, bzs + s * 17.5, 0.8, 13, 1, 0.1)
    bx(p, "door_dark", bxs - 33.2, 16.6, bzs, 0.5, 4, 14, 0.05)   # H-07 sign plate (SurfaceGui text in Studio)
    for z in (bzs - 6, bzs + 6):
        bx(p, "line_cream", -40, 0.1, z, 40, 0.2, 1.2, 0.0)
    bx(p, "line_cream", -58, 0.1, bzs, 1.2, 0.2, 30, 0.0)
    bx(p, "olive_dark", -50, 2.5, 28, 8, 5, 6, 0.3)
    bx(p, "olive_dark", -41, 2.5, 28, 8, 5, 6, 0.3)
    bx(p, "tank_sage", -45.5, 7.5, 28, 8, 5, 6, 0.3)
    mast(p, -58, 0, 33, 22); mast(p, 58, 0, 33, 22); mast(p, -58, 0, -33, 18)
    return p, (300, 12, -120), "Hangar deck, south-east, mid distance; hangar door + H-07 plate face the Exfil pad (-X)."

def comms_island():
    p = "B_CommsIsland"
    slab(p, "deck_side", 0, 0, 52, 52, 13, -5, -0.4)
    slab(p, "deck_top", 0, 0, 52.2, 52.2, 13.05, -0.4, 0, bev=0.1)
    slab(p, "line_cream", 0, 0, 52.4, 52.4, 13.1, -2.0, -1.2, bev=0.1)
    hull(p, 0, 0, 40, 40, 10, 12, neon="neon_cream", top=-5)
    disc(p, "deck_side", 10, 10, 7, 0, 5)
    revolve(p, "tank_cream", [(9 * math.sin(math.pi * k / 16), -9 * math.cos(math.pi * k / 16)) for k in range(17)],
            Matrix.Translation(P(10, 12, 10)), seg=40)
    mx, mz, mh = -8, -8, 64
    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        bx(p, "mast_metal", mx + sx * 2.2, mh / 2, mz + sz * 2.2, 1, mh, 1, 0.1)
    for i in range(1, 5):
        bx(p, "band_olive" if i % 2 == 0 else "line_cream", mx, i * mh / 5, mz, 5.4, 0.8, 5.4, 0.1)
    bx(p, "line_cream", mx, mh, mz, 5.4, 0.8, 5.4, 0.1)
    bx(p, "mast_metal", mx, mh + 7, mz, 0.8, 14, 0.8, 0.1)
    bx(p, "neon_cream", mx, mh + 14.6, mz, 2.2, 2.2, 2.2, 0.3)
    dish = [(0, 0), (2.5, 0.25), (4.5, 0.8), (6, 1.6), (6, 1.9), (4.4, 1.15), (2.4, 0.6), (0, 0.35)]
    for y, yaw, sc in ((38, -0.5, 1.0), (24, 0.6, 0.75)):
        M = Matrix.Translation(P(mx - 5, y, mz)) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(math.pi / 2 + 0.25, 4, "Z") @ Matrix.Scale(sc, 4)
        revolve(p, "line_cream", dish, M, seg=24)
        bx(p, "mast_metal", mx - 2.5, y, mz, 4, 0.8, 0.8, 0.1)
    bx(p, "mast_metal", -12, 3, 13, 3, 6, 3, 0.2)
    M = Matrix.Translation(P(-12, 11, 13)) @ Matrix.Rotation(-0.4, 4, "Y") @ Matrix.Rotation(math.pi / 2 + 0.55, 4, "Z") @ Matrix.Scale(1.65, 4)
    revolve(p, "line_cream", dish, M, seg=32)
    bx(p, "shed_wall", 12, 4, -12, 12, 8, 10, 0.3)
    bx(p, "band_olive", 12, 6.4, -12, 12.3, 1, 10.3, 0.1)
    bx(p, "door_dark", 5.9, 2.5, -12, 0.4, 5, 3, 0.05)
    return p, (470, 50, 55), "Comms / radar island, far east and high: radome, lattice mast with dishes, ground dish, hut."

def landing_pad():
    p = "B_LandingPad"
    lathe(p, "deck_side", [(0, -4), (32.4, -4), (33, -3.4), (33, -0.6), (32.6, -0.25), (0, -0.25)], cx=OX, cz=0, seg=64)
    disc(p, "hull", 0, 0, 33.1, -0.25, 0, seg=64, bev=0.05)
    ring(p, "line_cream", 0, 0, 27.5, 29, 0, 0.06, seg=64)
    ring(p, "band_olive", 0, 0, 33, 33.3, -1.7, -0.7, seg=64)
    bx(p, "line_cream", 0, 0.05, -7, 18, 0.1, 2.6, 0)
    bx(p, "line_cream", 0, 0.05, 7, 18, 0.1, 2.6, 0)
    bx(p, "line_cream", 0, 0.05, 0, 2.6, 0.1, 11.4, 0)
    for i in range(8):
        a = i * math.pi / 4
        bx(p, "neon_cream" if i % 2 == 0 else "neon_sage", math.cos(a) * 31, 0.5, math.sin(a) * 31, 1.6, 1, 1.6, 0.2)
    lathe(p, "hull", [(0, 0), (25, 0), (25, -4), (17, -6), (0, -6)], cx=OX, cz=0, seg=48, y0=-4)
    ring(p, "neon_sage", 0, 0, 12.8, 15, -11.2, -10, seg=48)
    lathe(p, "hull_dark", [(0, 0), (12.8, 0), (12, -1.5), (10, -3), (0, -3)], cx=OX, cz=0, seg=48, y0=-10)
    disc(p, "neon_cream", 0, 0, 5, -13.1, -12.9, bev=0)
    bx(p, "deck_side", 36, -1.5, 6, 12, 3, 10, 0.3)
    bx(p, "shed_wall", 38, 5, 6, 9, 10, 8, 0.3)
    bx(p, "glass_dark", 38, 7.6, 6, 9.2, 2.4, 8.2, 0.05)
    bx(p, "band_olive", 38, 9.4, 6, 9.3, 0.8, 8.3, 0.1)
    mast(p, 40, 10, 9, 10)
    return p, (245, 2, 120), "Landing pad, north-east, low: background of the ExfilFX lift shot. H faces the base."

def fuel_depot():
    p = "B_FuelDepot"
    slab(p, "deck_side", 0, 0, 74, 46, 10, -6, -0.4)
    slab(p, "deck_top", 0, 0, 74.2, 46.2, 10.05, -0.4, 0, bev=0.1)
    slab(p, "band_olive", 0, 0, 74.4, 46.4, 10.1, -2.4, -1.6, bev=0.1)
    hull(p, 0, 0, 56, 36, 8, 12, top=-6)
    tank = [(0, -20.5), (2.6, -20.2), (4.3, -19.2), (5, -18), (5, 18), (4.3, 19.2), (2.6, 20.2), (0, 20.5)]
    for i, tz in enumerate((-12, 0, 12)):
        M = Matrix.Translation(P(-8, 7, tz)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
        revolve(p, "tank_sage" if i == 1 else "tank_cream", tank, M, seg=32)
        for dx in (-12, 12):
            M2 = Matrix.Translation(P(-8 + dx, 7, tz)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
            revolve(p, "olive_dark", [(5.15, -0.8), (5.2, -0.8), (5.2, 0.8), (5.15, 0.8)], M2, seg=32)
            bx(p, "hull", -8 + dx * 1.17, 1.5, tz, 2, 3, 8, 0.2)
    revolve(p, "shed_wall", [(7.5 * math.sin(math.pi * k / 14), -7.5 * math.cos(math.pi * k / 14)) for k in range(15)],
            Matrix.Translation(P(24, 9.5, 8)), seg=32)
    bx(p, "hull", 24, 2, 8, 9, 4, 9, 0.3)
    rod(p, "mast_metal", P(-12, 2, -19), P(28, 2, -19), 1.0, seg=12)
    bx(p, "mast_metal", 26, 5, -19, 2, 10, 2, 0.15)
    mast(p, -32, 0, 18, 18)
    return p, (360, -6, -290), "Fuel / depot module, far south-east, low: three tanks on saddles, a sphere tank, a pipe run."

def markers():
    box("K_Scale6", "label_cream", -5, 5, 145, 155, -5, 5, 0.0)
    box("K_Marker6", "neon_olive", 15, 25, 145, 147, -1, 1, 0.0)
    box("K_Marker6", "neon_olive", 15, 17, 147, 153, -1, 1, 0.0)
    box("K_Marker6", "neon_olive", 15, 17, 145, 147, 1, 5, 0.0)

def coll_for(piece):   # override
    return "B_Markers" if piece.startswith("K_") else "B_Kit"

def build_all():
    global OX
    clear_scene()
    for ox, fn in ((0, hangar_deck), (190, comms_island), (300, landing_pad), (430, fuel_depot)):
        OX = float(ox)
        piece, world, note = fn()
        INFO[piece] = {"pivot_fbx_studio": [OX, 0, 0], "place_world": list(world), "note": note}
    OX = 0.0
    markers()
    return finalize()

def preview():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_shadows = True; sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 800
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = world
    world.color = (0.32, 0.55, 0.78)
    cam = bpy.data.cameras.new("PreviewCam"); cam.lens = 22
    co = bpy.data.objects.new("PreviewCam", cam); bpy.context.scene.collection.objects.link(co)
    # studio (x, y, z) -> blender (-x, z, y); look from the south-west, above, at the row's middle
    tgt = Vector((-225, 0, 4)); co.location = Vector((-225, -430, 140))
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    for ob in bpy.data.objects:
        if ob.name.startswith("K_"):
            ob.hide_render = True
    for ob in bpy.data.objects:   # material viewport colours = Studio colours
        if ob.type == "MESH" and ob.active_material:
            m = ob.active_material; mat = m.name
            if mat in MATS:
                r, g, b = [srgb2lin(v) for v in MATS[mat][0]]; m.diffuse_color = (r, g, b, 1)
    sc.render.filepath = OUT + "bl_preview.png"
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co, do_unlink=True)

STATS = build_all()
for ob in bpy.data.objects:
    if ob.type == "MESH":
        ob["piece"] = ob.name.split("__")[0]
man = {"_note": "backdrop kit (2026-10-16, backdrop_sky). Studio coords; each piece authored at its pivot (deck top centre) and slid "
                "along +X (pivot_fbx_studio). Import 3D (group Gunsy Funsy) with Insert Using Scene Position; per piece: a Model from its "
                "meshes, mesh CFrame = place_world + center_rel_pivot. Backdrop only: CanCollide/CanQuery/CanTouch false, CastShadow "
                "false, NotCover; neon_* meshes Material Neon. Replace the matching Polish.Backdrop Parts groups (cables + clouds stay "
                "Parts). K_Scale6 10-stud cube at (0,150,0), K_Marker6 long arm +X, upright +Y, short arm +Z.",
       "pieces": {}, "meshes": []}
for st in STATS:
    e = dict(st)
    piv = INFO.get(st["piece"], {}).get("pivot_fbx_studio", [0, 0, 0])
    e["center_rel_pivot"] = [round(e["center_studio"][i] - piv[i], 3) for i in range(3)]
    e["material_studio"] = "Neon" if st["material"].startswith("neon") else MATS[st["material"]][6]
    man["meshes"].append(e)
for piece, meta in INFO.items():
    ms = [m for m in man["meshes"] if m["piece"] == piece]
    meta["meshes"] = [m["name"] for m in ms]
    meta["tris"] = sum(m["tris"] for m in ms)
    meta["max_mesh_tris"] = max(m["tris"] for m in ms)
    man["pieces"][piece] = meta
with open(KIT + "backdrop_manifest.json", "w") as f:
    json.dump(man, f, indent=1)
bpy.ops.object.select_all(action="DESELECT")
for ob in bpy.data.objects:
    if ob.type == "MESH":
        ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=KIT + "backdrop.fbx", use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                         mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0, axis_forward="-Z", axis_up="Y",
                         add_leaf_bones=False, path_mode="STRIP", bake_anim=False)
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=KIT + "backdrop.blend")
try:
    preview()
    bpy.ops.wm.save_mainfile()
    PREV = "ok"
except Exception as ex:
    PREV = "preview failed: %s" % ex
result = {"meshes": len(STATS), "pieces": {k: (v["tris"], v["max_mesh_tris"], len(v["meshes"])) for k, v in man["pieces"].items()},
          "maxtris": max(s["tris"] for s in STATS), "preview": PREV}
print("BACKDROP_DONE", result)
