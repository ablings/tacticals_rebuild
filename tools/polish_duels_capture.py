"""Duels polish capture set (player-height cameras) via the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/polish_armory_capture.py <prefix: before|after|tN> [names...]
       python tools/polish_armory_capture.py ref name x,y,z lx,ly,lz   (RIVALS reference, read-only)"""
import json, os, subprocess, sys, shutil
SID = "d7ca5f9f-18c6-4c56-8fda-3225cb2e5dd1"   # Tacticals_rebuild.rbxl
REF = "2e616d06-6bfd-4b39-a751-ddccf8eb9187"   # RIVALS reference (read-only)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "door":    ([-90, 21.5, 0],    [-140, 19, 0]),
  "stairs":  ([-66, 9, 0],       [-100, 19, 0]),
  "pad1v1":  ([-109, 21.5, -2],  [-99, 16, -18]),
  "pad2v2":  ([-117, 21.5, 2],   [-130, 16, -20]),
  "pad3v3":  ([-112, 21.5, -16], [-114, 16, -38]),
  "back":    ([-140, 21.5, 0],   [-92, 19, 0]),
  "energy":  ([-118, 21.5, 0],   [-160, 22, 0]),
  "high":    ([-100, 40, -40],   [-125, 16, 8]),
}
OUT = os.path.join("out", "polish", "duels"); os.makedirs(OUT, exist_ok=True)
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
