"""Export hub1: kit/hub_r1.fbx (in-place shell + hero + props + markers) and kit/hub_r1_props.fbx (origin modules + markers),
then save kit/hub_kit.blend. exec() in Blender after hub_kit.py (and hub_preview.py if renders are wanted)."""
import bpy

R = r"C:/Users/aroki/Documents/tacticals_rebuild/kit/"

def _export(path, cols):
    bpy.ops.object.select_all(action="DESELECT")
    n = 0
    for cn in cols:
        for o in bpy.data.collections[cn].objects:
            o.select_set(True); n += 1
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0, axis_forward="-Z", axis_up="Y",
                             add_leaf_bones=False, path_mode="STRIP", bake_anim=False)
    return n

def export_all():
    for cn in ("Kit_Origin", "Markers"):
        c = bpy.data.collections[cn]; c.hide_viewport = False
    n1 = _export(R + "hub_r1.fbx", ["Shell", "Hero_Props", "Markers"])
    n2 = _export(R + "hub_r1_props.fbx", ["Kit_Origin", "Markers"])
    bpy.data.collections["Kit_Origin"].hide_viewport = True
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=R + "hub_kit.blend")
    return n1, n2
