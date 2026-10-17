"""Overlap sweep capture set (eye height ~5 above floor) via the stdio MCP bridge.
Usage: python tools/overlap_capture.py <prefix: before|after> [names...]   (run from tacticals_rebuild)"""
import json, os, subprocess, sys, shutil
SID = "018a7af6-6613-4d98-b9b4-c31491a28f2b"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "o1_duels_eastwall": ([-125, 21, 20],  [-95, 30, -10]),   # Duels east wall = hub W wall back + Duels cladding
  "o2_duels_door":     ([-108, 21, -6],  [-95, 26, 4]),     # door cheeks from the hall
  "o3_tunnel_mouth":   ([96, 5, -6],     [88, 9, 11]),      # tunnel jamb / portal / band from inside the tunnel
  "o4_hub_tunnel":     ([70, 5, -14],    [90, 9, 11]),      # portal side faces from the hub
  "o5_gateN_cheek":    ([-14, 5, 34],    [-6, 7, 44]),      # N gate cheek + band
  "o6_corrN":          ([0, 5, 47],      [0, 10, 66]),      # corridor + shop door lintel
  "o7_bays_low":       ([-55, 5, 30],    [-41, 1.5, 43.3]), # vent-bay door leaf / trim at the floor
  "o8_exfil_portal":   ([100, 5, 4],     [106, 9, -11]),    # E_Portal band/trim
  "o9_duels_west":     ([-128, 21, 0],   [-141, 26, -6]),   # west gate D_West band/trim
  "o10_pass":          ([-145, 21, 2],   [-156, 26, -7.6]), # passage band
  "o11_hub_rotor":     ([60, 40, -10],   [88, 47, 0]),      # old Props.Rotor in the hub E wall
  "o12_duels_beacon":  ([-115, 40, 20],  [-102.5, 55, 43]), # old FX3 beacon floating off the Duels N wall
}
pre = sys.argv[1]; names = sys.argv[2:] or list(CAMS)
os.makedirs("out/overlap", exist_ok=True)
for n in names:
    cam, look = CAMS[n]; cid = f"{pre}_{n}"
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True, env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src): shutil.move(src, os.path.join("out", "overlap", f"{cid}.png")); print("ok", cid)
    else: print("FAIL", cid, r.stdout[-300:], r.stderr[-300:])
