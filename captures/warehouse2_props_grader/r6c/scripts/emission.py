import bpy
for m in bpy.data.materials:
    if not m.node_tree: continue
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            es = n.inputs["Emission Strength"].default_value
            ec = tuple(round(x, 3) for x in n.inputs["Emission Color"].default_value)
            linked = n.inputs["Emission Color"].is_linked or n.inputs["Emission Strength"].is_linked
            print("EMI", m.name, "strength", es, "color", ec, "linked", linked)
        if n.type == "EMISSION":
            print("EMI-NODE", m.name)
