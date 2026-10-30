"""cap.py <out.png> cx cy cz lx ly lz : screen_capture of the anim-body Studio from a camera (stage coords, origin 0,800,0)."""
import json, os, subprocess, sys, shutil, glob, time
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
D = os.path.join(ROOT, "out", "anim_body")
sid = open(os.path.join(D, "studio_id.txt")).read().strip()
out = sys.argv[1]; f = [float(x) for x in sys.argv[2:8]]
args = {"studio_id": sid, "capture_id": os.path.splitext(os.path.basename(out))[0],
        "camera_position": [f[0], f[1] + 800, f[2]], "look_at_position": [f[3], f[4] + 800, f[5]]}
p = os.path.join(D, "_cap.json"); json.dump(args, open(p, "w"))
for old in glob.glob(os.path.join(D, "out", args["capture_id"] + "_*.png")):
    os.remove(old)
r = subprocess.run([sys.executable, "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py", "call", "screen_capture", p], capture_output=True, text=True, cwd=D)
got = glob.glob(os.path.join(D, "out", args["capture_id"] + "_*.png"))
if got:
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    shutil.move(got[0], out); print(out)
else:
    print("NO IMAGE", r.stdout[-400:], r.stderr[-300:])
