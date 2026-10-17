"""Rooms3 capture set (Duels hall / west deck, Exfil tunnel end / hangar / pad / cutscene camera) via the stdio MCP bridge.
Usage: python tools/rooms3_capture.py <prefix: before|after> [names...]   (run from tacticals_rebuild)"""
import json, os, subprocess, sys, shutil
SID = "018a7af6-6613-4d98-b9b4-c31491a28f2b"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "d1_door_hall":   ([-86, 21.5, 0],    [-125, 20, 0]),    # from the hub top landing through the Duels door
  "d2_pads_34":     ([-100, 34, -42],   [-122, 16, 8]),     # 3/4 over the pads
  "d3_1v1_boards":  ([-118, 21.5, 0],   [-95, 25, 0]),      # hall centre looking back at both 1v1 boards
  "d4_1v1_pad":     ([-104, 21.5, -4],  [-96, 26, -18.5]),  # standing beside the 1v1 A pad
  "d5_energy_wall": ([-112, 21.5, 0],   [-148, 30, 0]),     # old energy wall / new glass screen
  "d6_deck":        ([-158, 22, 22],    [-196, 16, -18]),   # west deck
  "e1_tunnel_end":  ([92, 5.5, 0],      [130, 4, 0]),       # tunnel end into the hangar
  "e2_hangar":      ([108, 10, 22],     [126, 3, -10]),     # hangar 3/4
  "e3_pad":         ([150, 12, 24],     [128, 3, -6]),      # pad from the open corner
  "e4_cutcam":      ([120, 9, -18],     [133, 4, 2]),       # ExfilFX cutscene camera toward the heli
}
pre = sys.argv[1]; names = sys.argv[2:] or list(CAMS)
os.makedirs("out/rooms3", exist_ok=True)
for n in names:
    cam, look = CAMS[n]
    cid = f"{pre}_{n}"
    args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
    r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                       env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src):
        shutil.move(src, os.path.join("out", "rooms3", f"{cid}.png")); print("ok", cid)
    else:
        print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
