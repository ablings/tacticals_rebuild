"""Capture every bay + the RIVALS arena copy from matching cameras, two frames each (kept only if they match).
Usage: python tools/lookdev/capture.py [bays e.g. ABCD R] [cams e.g. c10,c40,sun,aerial]
Writes out/arena_lookdev/<bay>_<cam>.png and out/arena_lookdev/cams.json."""
import json, os, shutil, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import call, SIDS

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "out", "arena_lookdev")
EYE = 5.1  # Tacticals third-person camera above the floor: HRP 3.0 + pivot 1.5 + 0.6 (ui/set/CameraConfig.lua), FOV 70
FT = 0.6
BAYZ = {"A": 0, "B": 200, "C": 400, "D": 600}


def bay_cams(z):
    e = FT + EYE
    return {  # target: the pillar's sunlit -X face at x 6.5 (sun from -x: direction -0.71, 0.64, 0.28)
        "c10": ([-3.5, e, z], [9, FT + 4, z]),
        "c40": ([-33.5, e, z], [9, FT + 4, z]),
        "sun": ([18, e, z - 12], [18 - 27.9, e + 10.9, z - 12 + 11.1]),  # toward the sun's azimuth, pitched up 20 deg
        "aerial": ([-40, FT + 55, z + 30], [-5, FT, z - 2]),
        "seam": ([-1, FT + 4, z + 17], [7, FT + 1.5, z + 21.5]),  # sill + post + floor: do the lines continue across the parts?
    }


def ref_cams():
    f = 5.0; e = f + EYE  # RIVALS arena floor top 5; target: the north end slab's sunlit -Z face at z 44 (sun -0.56, 0.73, -0.40)
    return {
        "c10": ([-10, e, 34], [-10, f + 4, 46.5]),
        "c40": ([-10, e, 4], [-10, f + 4, 46.5]),
        "sun": ([25, e, 25], [25 - 24.3, e + 10.9, 25 - 17.4]),
        "aerial": ([-50, f + 55, 29], [-15, f, -3]),
        "seam": ([-52, f + 3.5, 32], [-44, f + 1, 39.5]),  # NW corner frame's 3-high sill + post on the floor
    }


def grab(sid, cid, cam, at):
    shots = []
    for i in range(3):
        r = call("screen_capture", {"studio_id": sid, "capture_id": cid, "camera_position": cam, "look_at_position": at})
        src = os.path.join(ROOT, "out", cid + "_1.png")
        if not os.path.exists(src):
            raise SystemExit("capture failed: " + r)
        a = np.asarray(Image.open(src).convert("RGB")).astype(np.int16)
        if a.shape[:2] != (793, 1452):  # every frame at the same viewport (a Ctrl+S restore once shrank it to 812 x 675)
            raise SystemExit(f"viewport is {a.shape[1]} x {a.shape[0]}, not 1452 x 793: maximise the Studio window")
        shots.append(a)
        if len(shots) >= 2 and shots[-1].shape == shots[-2].shape and np.abs(shots[-1] - shots[-2]).mean() < 0.5:
            os.makedirs(OUT, exist_ok=True)
            shutil.move(src, os.path.join(OUT, cid + ".png"))
            return np.abs(shots[-1] - shots[-2]).mean()
    raise SystemExit("frames never matched for " + cid)


if __name__ == "__main__":
    bays = sys.argv[1] if len(sys.argv) > 1 else "ABCDR"
    cams = sys.argv[2].split(",") if len(sys.argv) > 2 else ["c10", "c40", "sun", "aerial", "seam"]
    allcams = {k: bay_cams(z) for k, z in BAYZ.items()}; allcams["R"] = ref_cams()
    os.makedirs(OUT, exist_ok=True)
    json.dump({"eye_above_floor": EYE, "fov": 70, "cams": allcams}, open(os.path.join(OUT, "cams.json"), "w"), indent=1)
    SOLO = """local key = '%s'
local park = game.ServerStorage:FindFirstChild('LookdevParked') or Instance.new('Folder', game.ServerStorage); park.Name = 'LookdevParked'
for _, b in park:GetChildren() do b.Parent = workspace.Lookdev end
if key ~= '' then for _, b in workspace.Lookdev:GetChildren() do if b.Name ~= 'Bay_' .. key then b.Parent = park end end
	-- move the real editor camera to the bay: the lighting grid follows it, not screen_capture's borrowed camera (2026-10-26)
	local z = ({ A = 0, B = 200, C = 400, D = 600 })[key]
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-40, 55.6, z + 30), Vector3.new(-5, 0.6, z - 2)) end
return #workspace.Lookdev:GetChildren()"""
    for b in bays:
        sid = SIDS["ref"] if b == "R" else SIDS["dev"]
        if b != "R":
            call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": SOLO % b})  # only this bay in view
            call("screen_capture", {"studio_id": sid, "capture_id": "warm", "camera_position": allcams[b][cams[0]][0], "look_at_position": allcams[b][cams[0]][1]})
            import time; time.sleep(6)  # 2026-10-26: right after a re-parent the shadow map lags; frames can match before it updates
        for c in cams:
            cam, at = allcams[b][c]
            d = grab(sid, f"{b}_{c}", cam, at)
            print(f"{b}_{c} ok (frame diff {d:.2f})", flush=True)
    print(call("execute_luau", {"studio_id": SIDS["dev"], "datamodel_type": "Edit", "code": SOLO % ""}))  # all bays back
