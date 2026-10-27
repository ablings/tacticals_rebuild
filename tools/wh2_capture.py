"""Warehouse 2: capture fixed review cameras on the old Warehouse or on Warehouse 2 (same plan cameras on both maps).
Usage: python tools/wh2_capture.py <old|new> <cams.json> [outdir] [only_name_substring]
Cameras are in plan coords (e east, h above floor, n north), as notes/warehouse_study/cams.json.
Old Warehouse: centre (-84.2, 7.5), floor 0.4 (geom.py). Warehouse 2: centre and floor from tools/wh2_layout.py (ORIGIN).
Each camera: set by script, then captured until two consecutive frames match (Map Proof Check 7)."""
import hashlib, json, os, re, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wh2_mcp
from wh2_layout import ORIGIN_X, ORIGIN_Z, FLOOR_Y

MAPS = {"old": (-84.2, 7.5, 0.4), "new": (ORIGIN_X, ORIGIN_Z, FLOOR_Y)}


def world(c, e, h, n):
    cx, cz, fy = c
    return (cx - e, fy + h, cz + n)


def capture(which, cams, outdir, only=None, hide_ui=True):
    c = MAPS[which]
    os.makedirs(outdir, exist_ok=True)
    res = []
    for cam in cams:
        if only and only not in cam["name"]:
            continue
        p = world(c, *cam["eye"]); t = world(c, *cam["at"])
        code = f"""local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Scriptable cam.FieldOfView={cam.get('fov', 70)}
cam.CFrame=CFrame.lookAt(Vector3.new({p[0]},{p[1]},{p[2]}),Vector3.new({t[0]},{t[1]},{t[2]})) cam.Focus=CFrame.new({t[0]},{t[1]},{t[2]})
game.Selection:Set({{}}) return 'ok'"""
        wh2_mcp.lua(code)
        hs = []
        for k in range(5):
            out = wh2_mcp.call("screen_capture", {"capture_id": "wh2cap"})
            img = [l.split(" ", 1)[1] for l in out.splitlines() if l.startswith("IMAGE")]
            if not img:
                print("  no image", out[:300]); break
            h = hashlib.md5(open(img[0], "rb").read()).hexdigest(); hs.append(h)
            dst = os.path.join(outdir, f"{which}_{cam['name']}.png")
            shutil.copy(img[0], dst)
            if len(hs) >= 2 and hs[-1] == hs[-2]:
                break
        ok = len(hs) >= 2 and hs[-1] == hs[-2]
        print(cam["name"], "frames", len(hs), "stable" if ok else "UNSTABLE")
        res.append((cam["name"], ok))
    return res


if __name__ == "__main__":
    which, camfile = sys.argv[1], sys.argv[2]
    outdir = sys.argv[3] if len(sys.argv) > 3 else os.path.join("captures", "warehouse2")
    only = sys.argv[4] if len(sys.argv) > 4 else None
    capture(which, json.load(open(camfile)), outdir, only)
