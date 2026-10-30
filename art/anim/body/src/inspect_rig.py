import bpy
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, o.parent.name if o.parent else "-", tuple(round(v,3) for v in o.location))
    if o.type == 'ARMATURE':
        for b in o.data.bones:
            print("  BONE", b.name, b.parent.name if b.parent else "-", tuple(round(v,3) for v in b.head_local), tuple(round(v,3) for v in b.tail_local))
print("ACTIONS", [a.name for a in bpy.data.actions])
print("FPS", bpy.context.scene.render.fps, "addons", [m for m in bpy.context.preferences.addons.keys()][:40])
