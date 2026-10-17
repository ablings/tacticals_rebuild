"""Shop polish capture set (player-height cameras) via the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/polish_shop_capture.py <prefix: before|after|tN> [names...]
       python tools/polish_shop_capture.py ref name x,y,z lx,ly,lz   (RIVALS reference, read-only)"""
import json, os, subprocess, sys, shutil
SID = "829eb64d-c313-4a64-bfb2-2bd3c42eb18e"   # Tacticals_rebuild.rbxl
REF = "2e616d06-6bfd-4b39-a751-ddccf8eb9187"   # RIVALS reference (read-only)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "entry":   ([0, 5.5, 69],     [0, 4, 108]),
  "counter": ([-6, 5.5, 88],    [6, 3.5, 108]),
  "west":    ([12, 5.5, 80],    [-28, 4, 92]),
  "east":    ([-12, 5.5, 78],   [28, 4, 92]),
  "ne_corner": ([-26, 6.5, 106],[20, 3, 72]),
  "se_corner": ([26, 6.5, 70],  [-14, 3, 104]),
}
OUT = os.path.join("out", "polish", "shop"); os.makedirs(OUT, exist_ok=True)
def cap(sid, cid, cam, look):
    args = json.dumps({"studio_id": sid, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
pre = sys.argv[1]
if pre == "ref":
    name = sys.argv[2]; cam = [float(v) for v in sys.argv[3].split(",")]; look = [float(v) for v in sys.argv[4].split(",")]
    cap(REF, f"ref_{name}", cam, look)
else:
    for n in (sys.argv[2:] or list(CAMS)):
        cap(SID, f"{pre}_{n}", *CAMS[n])
