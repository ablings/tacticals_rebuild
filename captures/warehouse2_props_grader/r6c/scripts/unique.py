import bpy
seen = {}
for o in bpy.data.collections["Kit"].all_objects:
    if o.type == "MESH":
        seen.setdefault(o.data.name, sum(len(p.vertices) - 2 for p in o.data.polygons))
print("UNIQUE", len(seen), "meshes", sum(seen.values()), "tris; biggest", max(seen.items(), key=lambda kv: kv[1]))
groups = {o.name.split("__")[0] for o in bpy.data.collections["Kit"].all_objects if o.type == "MESH"}
print("ASSEMBLIES", len(groups))
