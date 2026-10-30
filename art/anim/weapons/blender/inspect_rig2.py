import bpy
arm=bpy.data.objects['Blocky Rig']
for pb in arm.pose.bones:
    ks={k:pb[k] for k in pb.keys() if not k.startswith('_')}
    if ks: print("PROP", pb.name, ks)
for pb in arm.pose.bones:
    for c in pb.constraints:
        d={'type':c.type,'inf':round(c.influence,3)}
        for a in ('target','subtarget','pole_target','pole_subtarget','chain_count','pole_angle','use_tail','owner_space','target_space','mix_mode'):
            if hasattr(c,a):
                v=getattr(c,a); d[a]=v.name if hasattr(v,'name') else v
        print("CON", pb.name, c.name, d)
    print("ROTMODE", pb.name, pb.rotation_mode, "lockIK", tuple(pb.lock_ik_x for _ in [0]), "deform", arm.data.bones[pb.name].use_deform)
ad=arm.animation_data
if ad:
    for d in ad.drivers: print("DRV", d.data_path, d.array_index, d.driver.expression, [(v.name,[(t.id.name if t.id else None,t.data_path,t.bone_target) for t in v.targets]) for v in d.driver.variables])
