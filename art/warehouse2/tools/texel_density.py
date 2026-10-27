"""px per stud of every shipped mesh's visible surface in its atlas (1024 colour maps). Runs inside Blender on the kit.
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/texel_density.py"""
import bpy, math
seen = set()
for o in bpy.data.collections["Kit"].objects:
    me = o.data
    if me.name in seen or not me.uv_layers:
        continue
    seen.add(me.name)
    uv = me.uv_layers[0].data
    A3 = A2 = 0.0
    for p in me.polygons:
        pts = [uv[i].uv for i in p.loop_indices]
        a2 = 0.0
        for i in range(1, len(pts) - 1):
            a2 += abs((pts[i].x - pts[0].x) * (pts[i + 1].y - pts[0].y) - (pts[i].y - pts[0].y) * (pts[i + 1].x - pts[0].x)) / 2
        if a2 > 1e-9:      # buried faces have zero UV area: they are not part of the visible surface
            A3 += p.area; A2 += a2
    print(f"TEXEL {me.name:28s} {math.sqrt(A2 * 1024 * 1024 / max(A3, 1e-6)):6.1f} px/stud  ({me.materials[0].name})")
