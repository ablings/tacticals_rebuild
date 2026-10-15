"""kit/hub_r1_tex.fbx: one 4x4-stud quad per texture set (TX_<name>), Principled material wired to the set's images,
textures embedded, so Import 3D uploads them under the chosen Creator (Gunsy Funsy) as SurfaceAppearances.
Quads in a grid at Studio y 200 (Blender z 200). Also writes kit/hub_r1_tex_map.json. exec() inside Blender.
verify() re-imports the FBX into a scratch scene and reports which images came back, then removes the scratch data."""
import bpy, bmesh, json, os
from mathutils import Matrix

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
TEX = ROOT + "/tex/"
OUT = ROOT + "/kit/hub_r1_tex.fbx"

def sets():
    idx = json.load(open(TEX + "textures.json"))["textures"]
    out = []
    for key, info in idx.items():
        if key.endswith("_*"):
            base = key[:-2]
            files = dict(color=base + "_color.png", normal=base + "_normal.png", roughness=base + "_rough.png")
            for m in info.get("maps", []):
                if m.startswith("metalness="):
                    files["metalness"] = m.split("=", 1)[1]
            name = base.replace("hub_", "")
        else:
            base = key[:-4]
            files = dict(color=key)
            if base == "hub_grate_alpha":
                files["normal"] = "hub_grate_normal.png"
            name = base.replace("hub_", "")
        files = {k: v for k, v in files.items() if os.path.exists(TEX + v)}
        out.append(("TX_" + name, files, info))
    return out

def img(fn, noncolor):
    im = bpy.data.images.get(fn) or bpy.data.images.load(TEX + fn)
    im.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
    assert max(im.size) <= 1024, fn
    return im

def material(name, files):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True
    N = m.node_tree.nodes; L = m.node_tree.links
    b = N.get("Principled BSDF")
    t = N.new("ShaderNodeTexImage"); t.image = img(files["color"], False)
    L.new(t.outputs["Color"], b.inputs["Base Color"])
    with open(TEX + files["color"], "rb") as fh:  # PNG IHDR colour type: 6 = RGBA, 4 = grey + alpha
        has_alpha = fh.read(26)[25] in (4, 6)
    if has_alpha:
        L.new(t.outputs["Alpha"], b.inputs["Alpha"])
    if "normal" in files:
        tn = N.new("ShaderNodeTexImage"); tn.image = img(files["normal"], True)
        nm = N.new("ShaderNodeNormalMap"); L.new(tn.outputs["Color"], nm.inputs["Color"]); L.new(nm.outputs["Normal"], b.inputs["Normal"])
    if "roughness" in files:
        tr = N.new("ShaderNodeTexImage"); tr.image = img(files["roughness"], True)
        L.new(tr.outputs["Color"], b.inputs["Roughness"])
    if "metalness" in files:
        tm = N.new("ShaderNodeTexImage"); tm.image = img(files["metalness"], True)
        L.new(tm.outputs["Color"], b.inputs["Metallic"])
    return m

def build():
    col = bpy.data.collections.get("TexQuads")
    if col:
        for o in list(col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        col = bpy.data.collections.new("TexQuads"); bpy.context.scene.collection.children.link(col)
    mapping = {}
    S = sets()
    for i, (name, files, info) in enumerate(S):
        me = bpy.data.meshes.get(name)
        if me:
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        # 4 x 4 stud quad facing up (Studio +Y = Blender +Z), UV 0..1
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=2.0, calc_uvs=True)
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me); col.objects.link(ob)
        r, c = divmod(i, 4)
        sx, sz = 200.0 + c * 6.0, r * 6.0       # Studio x, z
        ob.location = (-sx, sz, 200.0)           # Blender (-Xs, Zs, Ys)
        me.materials.append(material(name, files))
        mapping[name] = dict(files=files, use=info["use"], studs_per_tile=info["studs_per_tile"],
                             maps=info.get("maps"), studio_pos=[sx, 200.0, sz])
    with open(ROOT + "/kit/hub_r1_tex_map.json", "w") as f:
        json.dump(dict(note="Import kit/hub_r1_tex.fbx with Import 3D (Creator = Gunsy Funsy): each TX_ quad gets a SurfaceAppearance "
                            "whose ColorMap/NormalMap/RoughnessMap/MetalnessMap asset ids are the uploaded images. Copy those ids into "
                            "MaterialVariants / Texture objects per 'use', then delete the quads.", sets=mapping), f, indent=1)
    bpy.ops.object.select_all(action="DESELECT")
    for o in col.objects:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True,
                             apply_unit_scale=True, axis_forward="-Z", axis_up="Y", add_leaf_bones=False, bake_anim=False)
    bpy.ops.object.select_all(action="DESELECT")
    return len(S), os.path.getsize(OUT)

def verify():
    main = bpy.context.window.scene
    before_imgs = set(bpy.data.images.keys()); before_mats = set(bpy.data.materials.keys())
    before_obj = set(bpy.data.objects.keys()); before_me = set(bpy.data.meshes.keys())
    sc = bpy.data.scenes.new("_tex_verify")
    bpy.context.window.scene = sc
    res = {}
    try:
        bpy.ops.import_scene.fbx(filepath=OUT)
        for o in sc.objects:
            got = {}
            for slot in o.material_slots:
                m = slot.material
                if not m or not m.use_nodes:
                    continue
                b = [n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
                for sock in ("Base Color", "Normal", "Roughness", "Metallic", "Alpha"):
                    s = b.inputs[sock]
                    if s.is_linked:
                        n = s.links[0].from_node
                        if n.type == "NORMAL_MAP" and n.inputs["Color"].is_linked:
                            n = n.inputs["Color"].links[0].from_node
                        if n.type == "TEX_IMAGE" and n.image:
                            im = n.image
                            got[sock] = dict(file=os.path.basename(im.filepath), packed=bool(im.packed_file), size=list(im.size),
                                             has_data=im.has_data or im.size[0] > 0)
            res[o.name] = got
    finally:
        for o in list(sc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.context.window.scene = main
        bpy.data.scenes.remove(sc)
        for k in set(bpy.data.meshes.keys()) - before_me:
            bpy.data.meshes.remove(bpy.data.meshes[k])
        for k in set(bpy.data.materials.keys()) - before_mats:
            bpy.data.materials.remove(bpy.data.materials[k])
        for k in set(bpy.data.images.keys()) - before_imgs:
            bpy.data.images.remove(bpy.data.images[k])
    return res
