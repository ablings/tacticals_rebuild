"""Hub (command deck) capture set via the stdio MCP bridge. Run tools/show_studio.ps1 tacticals (or rivals) first.
Usage (from tacticals_rebuild): python tools/polish_hub_capture.py <prefix: before|after|tN> [names...]
       python tools/polish_hub_capture.py ref name x,y,z lx,ly,lz   (RIVALS reference, read-only)
       python tools/polish_hub_capture.py cam prefix_name x,y,z lx,ly,lz   (one-off Tacticals camera)"""
import json, os, subprocess, sys, shutil
SID = "5e5685e4-6afe-4dde-b307-dd6c67c0a85d"   # Tacticals_rebuild.rbxl
REF = "2e616d06-6bfd-4b39-a751-ddccf8eb9187"   # RIVALS reference (read-only)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  # from the spawn disc (eye height) toward each gate
  "toN":     ([0, 5.5, -8],     [0, 9, 45]),
  "toS":     ([0, 5.5, 8],      [0, 9, -45]),
  "toE":     ([-8, 5.5, 0],     [95, 9, 0]),
  "toW":     ([8, 5.5, 0],      [-84, 9, 0]),
  # wide views
  "wideNE":  ([62, 24, 32],     [-10, 4, -6]),
  "wideSW":  ([-62, 22, -32],   [12, 4, 6]),
  "disc":    ([16, 9, 16],      [0, 0.6, 0]),
  "ceiling": ([0, 5, -14],      [0, 70, 22]),
  # features round the hall
  "reward":  ([-4, 5.5, -12],   [-15, 2.5, -24]),
  "board":   ([-48, 5.5, 18],   [-55.5, 14, 41]),
  "likes":   ([48, 5.5, 18],    [55, 14, 41]),
  "tunnel":  ([60, 5.5, -10],   [96, 7, 0]),
}
OUT = os.path.join("out", "polish", "hub"); os.makedirs(OUT, exist_ok=True)
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
if pre in ("ref", "cam"):
    name = sys.argv[2]; cam = [float(v) for v in sys.argv[3].split(",")]; look = [float(v) for v in sys.argv[4].split(",")]
    cap(REF if pre == "ref" else SID, f"ref_{name}" if pre == "ref" else name, cam, look)
else:
    for n in (sys.argv[2:] or list(CAMS)):
        cap(SID, f"{pre}_{n}", *CAMS[n])
