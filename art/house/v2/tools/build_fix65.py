"""Fix65 (map grade r3, blocking): the dining set and the slatted hall bench stood on open legs inside solid cover boxes, so
a crouching player saw floor where shots stopped. Rebuilds ONLY the changed masters with build_furniture_1965's builders
(tablecloth table, skirted dinette chairs, closed bench front), bakes them into one new atlas H_Fix65 (the other atlases
are untouched), places every assembly at its pivot from H_Furniture_kit.fbx, and exports:
  fbx/H_Furniture_fix65.fbx   the changed assemblies with the kit's object names + K_ScaleCube + K_Marker (kit positions)
  fbx/<assembly>.fbx          per assembly, pivot at the origin (replaces the old files)
  house_furniture.json        the changed entries (parts, tris, textures) + atlases.Fix65; boxes / sizes must not move
  house_furniture_fix65.blend the fix kit (collection Kit) for blender_check / check_each
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/v2/tools/build_fix65.py
A full build_furniture_1965.py run gives the same shapes in the Dining / Storage2 atlases."""
import os, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import hcore
from hcore import ROOT, FBXD, TEX, PREFIX, log, setup_cycles, bake_atlas, atlas_material, finalize, bbox, studio, studio_size, \
    tris, scale_cube_marker, export_fbx, coll
import build_furniture_1965 as bf

ATL = "Fix65"
NAMES = ["H_DiningSet", "H_DiningTable", "H_DiningChair", "H_HallBench_8"]
MANJ = os.path.join(ROOT, "house_furniture.json")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    man = json.load(open(MANJ))
    old = {e["assembly"]: e for e in man["assemblies"]}
    obs = [bf.dining_table(), bf.dining_chair(), bf.table_setting(), bf.hall_bench("H_HallBench_8", 8.0, "slat")]
    old_unique = {"H_DiningTable": old["H_DiningTable"]["tris"], "H_DiningChair": old["H_DiningChair"]["tris"],
                  "H_TableSetting": [p["tris"] for p in old["H_DiningSet"]["parts"] if p["object"].endswith("H_TableSetting")][0],
                  "H_HallBench_8": old["H_HallBench_8"]["tris"]}
    by_name = {o.name: o for o in obs}
    x = 0.0
    for o in obs:
        o["atlas"] = ATL
        lo, hi = bbox([o]); o.location.x += x - lo.x; o.location.y = 200.0
        bpy.context.view_layer.update(); x = bbox([o])[1].x + 6.0
    setup_cycles()
    imgs = bake_atlas(ATL, obs)
    finalize(obs, atlas_material(ATL, imgs))
    atl_files = {p: f"tex/{PREFIX}{ATL}_{p}.png" for p in imgs}
    for o in obs:
        o.location = (0, 0, 0)
    asm = [a for a in bf.ASM if a[0] in NAMES]
    placed, pivots = bf.layout(by_name, asm)
    cube, mk = scale_cube_marker()
    cube.location = (0, 40, 5); mk.location = (8, 40, 0)
    bpy.context.view_layer.update()
    errs = []
    for name, parts, role, cover, boxes in asm:
        e = old[name]
        objs = placed[name]
        want = Vector(e["pivot_blender_in_kit"])
        d = want - pivots[name]
        for o in objs:
            o.location += d
        pivots[name] = want
        bpy.context.view_layer.update()
        piv = want
        if [o.name for o in objs] != e["objects"]:
            errs.append(f"{name}: object names {[o.name for o in objs]} != kit {e['objects']}")
        lo, hi = bbox(objs)
        if len(boxes) == 1:
            (bl, bh) = boxes[0]
            boxes = [((lo.x - piv.x, lo.y - piv.y, bl[2]), (hi.x - piv.x, hi.y - piv.y, bh[2]))]
        if boxes:
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            c = Vector(((ul.x + uh.x) / 2, (ul.y + uh.y) / 2, 0.0))
            if c.length > 1e-3:
                errs.append(f"{name}: box centre off the pivot by {tuple(c)} (the kit build re-centred it; not expected here)")
        e["size_studio"] = studio_size(hi - lo)
        a_, b_ = studio(lo - piv), studio(hi - piv)
        e["bbox_min_rel_pivot_studio"] = [min(p, q) for p, q in zip(a_, b_)]
        e["bbox_max_rel_pivot_studio"] = [max(p, q) for p, q in zip(a_, b_)]
        nb = []
        for (bl, bh) in boxes:
            bl, bh = Vector(bl), Vector(bh)
            nb.append(dict(size=studio_size(bh - bl), centre_rel_pivot=studio((bl + bh) / 2)))
        e["collision_boxes_studio"] = nb
        e["parts"] = []
        for o in objs:
            l2, h2 = bbox([o])
            e["parts"].append(dict(object=o.name, mesh=o.data.name, atlas=o.get("atlas"), tris=tris(o),
                                   centre_studio_rel_pivot=studio((l2 + h2) / 2 - piv), size_studio=studio_size(h2 - l2),
                                   rot_z_deg=round(math.degrees(o.rotation_euler.z), 1)))
        e["tris"] = sum(p["tris"] for p in e["parts"])
        e["textures"] = sorted(atl_files.values())
        e["fix65"] = "rebuilt 2026-10-28: closed base (tablecloth / skirted chairs / closed bench front); in fbx/H_Furniture_fix65.fbx"
        if boxes:
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            e["art_outside_box"] = round(max(0.0, max(max((ul - (lo - piv))[i], ((hi - piv) - uh)[i]) for i in range(3))), 3)
        log("ASM", name, e["tris"], "tris", e["size_studio"])
    allobjs = [o for n in NAMES for o in placed[n]]
    export_fbx(os.path.join(FBXD, "H_Furniture_fix65.fbx"), allobjs + [cube, mk])
    for name in NAMES:
        objs = placed[name]
        for o in objs:
            o.location -= pivots[name]
        bpy.context.view_layer.update()
        export_fbx(os.path.join(FBXD, name + ".fbx"), objs)
        for o in objs:
            o.location += pivots[name]
        bpy.context.view_layer.update()
    man["atlases"][ATL] = atl_files
    man["unique_tris"] = man["unique_tris"] - sum(old_unique.values()) + sum(tris(o) for o in obs)
    man["fix65"] = dict(fbx="fbx/H_Furniture_fix65.fbx", assemblies=NAMES, atlas=ATL,
                        note="replaces these assemblies one-for-one (same object names, pivots and boxes); import with the H_Fix65 atlas")
    json.dump(man, open(MANJ, "w"), indent=1)
    for c in list(bpy.data.collections):
        if c.name == "Masters" and not c.objects:
            bpy.data.collections.remove(c)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "house_furniture_fix65.blend"))
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    for m in errs:
        log("ERROR", m)
    log("DONE fix65", len(allobjs), "objects", sum(tris(o) for o in obs), "unique tris", "errors", len(errs))


main()
