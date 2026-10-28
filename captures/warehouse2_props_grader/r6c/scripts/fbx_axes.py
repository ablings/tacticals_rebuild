import sys, os
import addon_utils
argv = sys.argv[sys.argv.index("--")+1:]
from io_scene_fbx import parse_fbx
root, ver = parse_fbx.parse(argv[0])
def find(e, name):
    for c in e.elems:
        if c.id == name.encode(): return c
for c in root.elems:
    if c.id == b"GlobalSettings":
        props = find(c, "Properties70")
        for p in props.elems:
            k = p.props[0].decode()
            if k in ("UpAxis","UpAxisSign","FrontAxis","FrontAxisSign","CoordAxis","CoordAxisSign","UnitScaleFactor","OriginalUnitScaleFactor"):
                print("GS", k, p.props[-1])
print("FBX version", ver)
