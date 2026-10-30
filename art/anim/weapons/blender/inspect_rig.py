import bpy
print("BLENDVER", bpy.data.version, "unit", bpy.context.scene.unit_settings.scale_length, "fps", bpy.context.scene.render.fps)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, "parent", o.parent.name if o.parent else None, "ptype", o.parent_type, "pbone", o.parent_bone, tuple(round(v,4) for v in o.location), tuple(round(v,4) for v in o.rotation_euler), tuple(round(v,3) for v in o.scale), "dims", tuple(round(v,3) for v in o.dimensions))
    if o.type=='ARMATURE':
        mw=o.matrix_world
        for b in o.data.bones:
            h=mw@b.head_local; t=mw@b.tail_local
            print("  BONE", b.name, "parent", b.parent.name if b.parent else None, "head", tuple(round(v,3) for v in h), "tail", tuple(round(v,3) for v in t), "roll-ish y", tuple(round(v,3) for v in (mw.to_3x3()@b.matrix_local.to_3x3()).col[1]), "z", tuple(round(v,3) for v in (mw.to_3x3()@b.matrix_local.to_3x3()).col[2]))
        for pb in o.pose.bones:
            if pb.constraints: print("  CON", pb.name, [(c.type,c.name) for c in pb.constraints])
    for m in getattr(o,'modifiers',[]): print("  MOD", m.type, getattr(m,'object',None) and m.object.name)
    if o.type=='MESH': print("  vgroups", [g.name for g in o.vertex_groups][:30])
print("ACTIONS", [a.name for a in bpy.data.actions])
