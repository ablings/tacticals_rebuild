"""Sky backdrop capture set (where players see the east sky) via the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/backdrop_capture.py <prefix: before|after|tN> [names...]
Run `pwsh -NoProfile -File tools/show_studio.ps1 tacticals` first (covered windows capture blank)."""
import json, os, subprocess, sys, shutil
SID = "8ef4e21a-3525-484b-91af-79d7677aa213"   # Tacticals_rebuild.rbxl
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "pad":     ([140, 5.5, 0],     [230, 22, 0]),       # player on the pad looking out east
  "edge":    ([138, 5.5, -16],   [175, 2, -4]),       # exfil polish 'edge' view
  "padNE":   ([136, 5.5, -20],   [210, 18, 45]),
  "padSE":   ([136, 5.5, 20],    [210, 14, -50]),
  "hangar":  ([108, 5.5, 4],     [170, 10, -4]),
  "tunnel":  ([92, 5.5, 0],      [130, 4, 0]),
  "hubeast": ([45, 6, 0],        [110, 7, 0]),
  "cut0":    ([120, 9, -18],     [133, 4, 2]),        # ExfilFX start shot
  "cut1":    ([120, 10.5, -20],  [135.6, 6.4, 0.4]),  # lift e = 1
  "cut2":    ([120, 12.9, -23.2],[154.0, 13.4, 0.4]), # lift e = 2.6 (last frame before the fade)
  "dHangar": ([215, 22, -55],    [305, 8, -125]),     # detail views (not player views)
  "dComms":  ([400, 60, 10],     [470, 55, 55]),
  "dPad":    ([195, 12, 85],     [245, -4, 120]),
  "dDepot":  ([300, 10, -230],   [360, -8, -290]),
  "wide":    ([60, 70, -120],    [330, -10, 0]),      # overview (not a player view)
}
OUT = os.path.join("out", "polish", "backdrop"); os.makedirs(OUT, exist_ok=True)
def cap(cid, cam, look):
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
pre = sys.argv[1]
for n in (sys.argv[2:] or list(CAMS)):
    cap(f"{pre}_{n}", *CAMS[n])
