"""Feature-kit placement captures (eye height) via the stdio MCP bridge (rivals_practice/mcpcli.py).
Usage (from tacticals_rebuild): python tools/features_kit_capture.py <prefix: before|after|play> [names...]
Writes out/features_kit/<prefix>_<name>.png. Edit-mode captures (screen_capture works on the Edit viewport)."""
import json, os, subprocess, sys, shutil
SID = "829eb64d-c313-4a64-bfb2-2bd3c42eb18e"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "s1_leaderboard":  ([-55.5, 5.5, 14],  [-55.5, 13, 44]),
  "s2_likes":        ([55, 5.5, 14],     [55, 13, 44]),
  "s3_duelstv":      ([-55.5, 5.5, -14], [-55.5, 13, -44]),
  "s4_ad":           ([55, 5.5, -14],    [55, 13, -44]),
  "s5_training":     ([62, 5.5, -16],    [88, 13, -22]),
  "s6_duelssign":    ([-60, 5.5, 4],     [-84, 6, 0]),
  "r1_stand_spawn":  ([0, 5.5, 4],       [-12, 4, -24]),
  "r2_stand_close":  ([-6, 5.5, -12],    [-15, 4.5, -24]),
  "p1_pits":         ([-103, 21.5, 2],   [-114, 16, 17]),
  "p2_pit_close":    ([-108, 21.5, -6],  [-114, 15, -17]),
  "f1_spot_bridge":  ([30, 5.5, 0],      [48.75, 23, 7]),
  "f2_beacons":      ([108, 5.5, 8],     [126, 20, 26]),
  "f3_shop_counter": ([3, 5.5, 90],      [3, 4, 101.8]),
  "f4_armory":       ([-2, 5.5, -80],    [-6, 4, -100]),
  "f5_post_beacon":  ([136, 5.5, 12],    [149.6, 14, 25]),
  "i1_hangar":       ([104, 5.5, -10],   [140, 6, 10]),
  "i2_hub_east":     ([40, 5.5, 20],     [85, 6, -10]),
  "i3_hub_west":     ([-40, 5.5, -20],   [-85, 6, 10]),
  "i4_corridor_n":   ([0, 5.5, 50],      [0, 5, 80]),
  "i5_duels_hall":   ([-100, 21.5, -2],  [-135, 18, 30]),
  "t1_bin":          ([10, 605.5, -10],  [17, 601.5, -17]),
  "t2_crates":       ([-40, 605.5, -40], [-48, 602, -52]),
  "t3_crates5":      ([84, 605.5, -60],  [92, 602, -70]),
}
pre = sys.argv[1]; names = sys.argv[2:] or list(CAMS)
os.makedirs("out/features_kit", exist_ok=True)
for n in names:
    cam, look = CAMS[n]
    cid = f"{pre}_{n}"
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"), cwd=os.getcwd())
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join("out", "features_kit", f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
