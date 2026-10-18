"""Hub2 capture set (same cameras as hub1) via the stdio MCP bridge (rivals_practice/mcpcli.py).
Usage: python tools/hub2_capture.py <prefix: before|after> [names...]   (run from tacticals_rebuild)"""
import json, os, subprocess, sys, shutil
SID = "d7ca5f9f-18c6-4c56-8fda-3225cb2e5dd1"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "c1_spawn_east":   ([0, 6, -4],    [90, 9, 0]),
  "c2_tunnel_west":  ([78, 6, -22],  [-80, 12, 10]),
  "c3_riser_east":   ([-66, 6, 22],  [40, 8, -10]),
  "c4_ne_disc":      ([70, 6, 34],   [-20, 4, -20]),
  "c5_south_north":  ([12, 6, -36],  [0, 10, 44]),
  "c6_high_34":      ([-62, 40, -38],[20, 0, 15]),
  "g1_north_gate":   ([0, 6, 26],    [0, 7, 70]),
  "g2_south_gate":   ([0, 6, -26],   [0, 7, -70]),
  "g3_west_stairs":  ([-52, 6, -18], [-88, 10, -22]),
  "t1_top_landing":  ([-74, 25, 16],  [-88, 16, 0]),
}
pre = sys.argv[1]; names = sys.argv[2:] or [k for k in CAMS if k[0] == "c"]
os.makedirs("out/hub2", exist_ok=True)
for n in names:
    cam, look = CAMS[n]
    cid = f"{pre}_{n}"
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join("out", "hub2", f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
