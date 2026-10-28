import bpy, json, sys
from mathutils import Vector
out = {}
def walk(c, d=0):
    print("  "*d + f"[C] {c.name}: {len(c.objects)} objs, children {[x.name for x in c.children]}")
    for ch in c.children:
        walk(ch, d+1)
walk(bpy.context.scene.collection)
print("images:")
for im in bpy.data.images:
    print("  ", im.name, im.filepath, im.size[:], im.has_data if hasattr(im,'has_data') else '')
print("materials:", len(bpy.data.materials))
for m in bpy.data.materials:
    imgs = [n.image.name for n in (m.node_tree.nodes if m.use_nodes else []) if n.type=='TEX_IMAGE' and n.image]
    print("  ", m.name, imgs)
print("objects:")
for o in bpy.context.scene.objects:
    if o.type != 'MESH': 
        print("  ", o.type, o.name); continue
    me = o.data
    tris = sum(len(p.vertices)-2 for p in me.polygons)
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    print(f"   {o.name:34s} coll={[c.name for c in o.users_collection]} tris={tris} uv={[u.name for u in me.uv_layers]} mats={[m.name if m else None for m in me.materials]} size={[round(hi[i]-lo[i],3) for i in range(3)]} loc={[round(x,3) for x in o.location]} scale={[round(x,3) for x in o.scale]} hide={o.hide_get()} props={ {k:o[k] for k in o.keys() if not k.startswith('_')} }")
