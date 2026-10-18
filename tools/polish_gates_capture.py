"""Gate corridors (N/S airlocks) capture set (player-height cameras) via the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/polish_gates_capture.py <prefix: before|after|tN> [names...]
       python tools/polish_gates_capture.py ref name x,y,z lx,ly,lz   (RIVALS reference, read-only)"""
import json, os, subprocess, sys, shutil
SID = "7f9e7426-2e49-4e8e-916c-304843df58de"   # Tacticals_rebuild.rbxl
REF = "2e616d06-6bfd-4b39-a751-ddccf8eb9187"   # RIVALS reference (read-only)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "Nhub":    ([0, 5.5, 28],     [0, 5, 70]),
  "Nmid":    ([0, 5.5, 46],     [0, 5, 75]),
  "Nwall":   ([3.6, 5.5, 48.5], [-4.9, 4.5, 59]),
  "Nback":   ([0, 5.5, 74],     [0, 5, 40]),
  "Nsign":   ([0, 9, 18],       [0, 17, 44]),
  "Shub":    ([0, 5.5, -28],    [0, 5, -70]),
  "Smid":    ([0, 5.5, -46],    [0, 5, -75]),
  "Swall":   ([-3.6, 5.5, -48.5], [4.9, 4.5, -59]),
  "Sback":   ([0, 5.5, -74],    [0, 5, -40]),
  "Ssign":   ([0, 9, -18],      [0, 17, -44]),
}
OUT = os.path.join("out", "polish", "gates"); os.makedirs(OUT, exist_ok=True)
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
