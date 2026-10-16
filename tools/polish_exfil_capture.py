"""Exfil polish capture set (player-height cameras) via the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/polish_exfil_capture.py <prefix: before|after|tN> [names...]
       python tools/polish_exfil_capture.py ref name x,y,z lx,ly,lz   (RIVALS reference, read-only)"""
import json, os, subprocess, sys, shutil
SID = "8ef4e21a-3525-484b-91af-79d7677aa213"   # Tacticals_rebuild.rbxl
REF = "2e616d06-6bfd-4b39-a751-ddccf8eb9187"   # RIVALS reference (read-only)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "tunnel":  ([92, 5.5, 0],      [130, 4, 0]),
  "hangar":  ([106, 5.5, 20],    [130, 3, -8]),
  "mouth":   ([118, 5.5, -18],   [150, 4, 10]),
  "pad":     ([150, 8, 24],      [128, 3, -6]),
  "padS":    ([146, 5.5, -22],   [118, 5, 8]),
  "edge":    ([138, 5.5, -16],   [175, 2, -4]),
  "cutcam":  ([120, 9, -18],     [133, 4, 2]),
  "high":    ([152, 22, -26],    [128, 0, 6]),
}
OUT = os.path.join("out", "polish", "exfil"); os.makedirs(OUT, exist_ok=True)
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
