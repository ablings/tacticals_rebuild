"""Rooms2 capture set (Shop, Armory, both corridors; player height + 3/4) via the stdio MCP bridge (rivals_practice/mcpcli.py).
Usage: python tools/rooms2_capture.py <prefix: before|after> [names...]   (run from tacticals_rebuild)"""
import json, os, subprocess, sys, shutil
SID = "8ef4e21a-3525-484b-91af-79d7677aa213"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "n1_corrN_player": ([0, 5.5, 34],    [0, 5, 80]),
  "n2_corrN_34":     ([3.5, 10.5, 47], [-3, 1, 64]),
  "s1_shop_entry":   ([0, 5.5, 71],    [0, 4, 108]),
  "s2_shop_counter": ([-12, 5.5, 84],  [8, 3, 106]),
  "s3_shop_34":      ([-27, 11.5, 71], [8, 0, 100]),
  "s4_shop_east":    ([24, 5.5, 72],   [-10, 4, 100]),
  "n3_corrS_player": ([0, 5.5, -34],   [0, 5, -80]),
  "n4_corrS_34":     ([3.5, 10.5, -47],[-3, 1, -64]),
  "a1_arm_entry":    ([0, 5.5, -69],   [0, 6, -112]),
  "a2_arm_gunwall":  ([4, 5.5, -88],   [-6, 7, -112]),
  "a3_arm_34":       ([27, 19, -69],   [-8, 0, -100]),
  "a4_arm_supply":   ([-6, 5.5, -92],  [12, 4, -110]),
}
pre = sys.argv[1]; names = sys.argv[2:] or list(CAMS)
os.makedirs("out/rooms2", exist_ok=True)
for n in names:
    cam, look = CAMS[n]
    cid = f"{pre}_{n}"
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join("out", "rooms2", f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
