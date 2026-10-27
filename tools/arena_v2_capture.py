"""Arena v2 review cameras: capture the Arena in a Studio place from the fixed cameras in captures/cams-arena_v2.json.

    python tools/arena_v2_capture.py <studio_id> <prefix>      e.g.  ... f252f12a-... v2     (writes out/arena_v2/<prefix>_<cam>.png)

The viewing conditions are the match's: the Arena's MapInfo.Lighting is applied to Lighting for the shots (as RoundManager's
applyMapEnv does when the map wins the vote), Studio EditQualityLevel 21, FOV 70; everything is put back afterwards (the
original values are written to out/arena_v2/<prefix>_restore.json first, so a crash mid-run can be undone by hand).
Every shot is kept only when two consecutive frames match (mean abs diff < 0.5).
"""
import json, os, shutil, sys, time
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "lookdev"))
from run import call  # noqa: E402

OUT = os.path.join(ROOT, "out", "arena_v2")
CAMS = os.path.join(ROOT, "captures", "cams-arena_v2.json")
ORIGIN = (-600.0, 0.0, 0.0)
FT = 0.6
EYE = 5.1  # third-person camera above the feet (CameraConfig), FOV 70


def W(x, y, z):  # plan (x east, y north, z up from the floor top) -> world
    return [ORIGIN[0] + x, FT + z, ORIGIN[2] - y]


def cams():
    e = EYE
    c = {
        "aerial": (W(-95, -88, 75), W(0, 0, 0)),
        "plan": (W(0, -1, 140), W(0, 0, 0)),
        "A1_spawn_east": (W(-70, 0, e), W(0, 0, 3)),
        "A2_exit_perch": (W(-60, 12, e), W(-34, 50, 3)),
        "A3_perch_northlane": (W(-34, 49, 5 + e), W(23, 30, 3)),
        "A4_southgate_lane": (W(-27, -45, e), W(36, -51, 4)),
        "B1_spawn_west": (W(70, 2.5, e), W(0, 2.5, 3)),
        "B2_northgate_perch": (W(26, 30, e), W(-34, 50, 6)),
        "B3_ledge_southlane": (W(36, -48.5, 5 + e), W(-23, -45, 3)),
        "B4_centre_sill": (W(4, 7.5, e), W(-40, 7.5, 3)),
    }
    return {k: [v[0], v[1]] for k, v in c.items()}


SETUP = r'''
local HS = game:GetService("HttpService")
local L = game:GetService("Lighting")
local info = require(game.ReplicatedStorage.DuelMaps.Arena.MapInfo)
local look = info.Lighting
local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
local function enc(v)
	if typeof(v) == "Color3" then return { c = { v.R, v.G, v.B } } end
	return v
end
local orig = { light = {}, atmo = {}, grade = {}, bloom = {} }
local function apply(obj, bucket, values, keys)
	if not obj or not values then return end
	for _, k in keys do
		if values[k] ~= nil then bucket[k] = enc(obj[k]); obj[k] = values[k] end
	end
end
apply(L, orig.light, look, { "ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows" })
apply(atm, orig.atmo, look.Atmosphere, { "Density", "Offset", "Haze", "Glare", "Color", "Decay" })
apply(grade, orig.grade, look.Grade, { "Brightness", "Contrast", "Saturation", "TintColor" })
apply(bloom, orig.bloom, look.Bloom, { "Intensity", "Size", "Threshold" })
orig.quality = settings().Rendering.EditQualityLevel.Value
orig.fov = workspace.CurrentCamera.FieldOfView
orig.cam = { workspace.CurrentCamera.CFrame:GetComponents() }
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
workspace.CurrentCamera.FieldOfView = 70
return HS:JSONEncode(orig)
'''

RESTORE = r'''
local HS = game:GetService("HttpService")
local L = game:GetService("Lighting")
local orig = HS:JSONDecode([==[%s]==])
local function dec(v) if type(v) == "table" and v.c then return Color3.new(v.c[1], v.c[2], v.c[3]) end return v end
local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
for _, pair in { { L, orig.light }, { atm, orig.atmo }, { grade, orig.grade }, { bloom, orig.bloom } } do
	if pair[1] then for k, v in pair[2] do pair[1][k] = dec(v) end end
end
for _, q in Enum.QualityLevel:GetEnumItems() do if q.Value == orig.quality then settings().Rendering.EditQualityLevel = q end end
workspace.CurrentCamera.FieldOfView = orig.fov
workspace.CurrentCamera.CFrame = CFrame.new(table.unpack(orig.cam))
return "restored"
'''


def grab(sid, cid, cam, at):
    for _ in range(2):  # warm-up: the first frames after a move miss the shadow map
        call("screen_capture", {"studio_id": sid, "capture_id": cid, "camera_position": cam, "look_at_position": at})
    prev = None
    for i in range(5):
        r = call("screen_capture", {"studio_id": sid, "capture_id": cid, "camera_position": cam, "look_at_position": at})
        src = os.path.join(ROOT, "out", cid + "_1.png")
        if not os.path.exists(src):
            raise SystemExit("capture failed: " + r)
        a = np.asarray(Image.open(src).convert("RGB")).astype(np.int16)
        if prev is not None and prev.shape == a.shape and np.abs(prev - a).mean() < 0.5:
            shutil.move(src, os.path.join(OUT, cid + ".png"))
            return float(np.abs(prev - a).mean()), a.shape
        prev = a
        time.sleep(1.5)
    raise SystemExit("frames never matched for " + cid)


if __name__ == "__main__":
    sid, prefix = sys.argv[1], sys.argv[2]
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(CAMS), exist_ok=True)
    cs = cams()
    json.dump({"map": "Arena v2", "origin": ORIGIN, "floor_top": FT, "eye_above_floor": EYE, "fov": 70, "edit_quality": 21,
               "lighting": "Arena MapInfo.Lighting applied for the shots", "cams": cs}, open(CAMS, "w"), indent=1)
    orig = call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": SETUP}).strip()
    if not orig.startswith("{"):
        raise SystemExit("setup failed: " + orig)
    open(os.path.join(OUT, prefix + "_restore.json"), "w").write(orig)
    try:
        # the lighting grid follows the real editor camera: park it over the Arena first
        call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code":
              "workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(%g, %g, %g), Vector3.new(%g, %g, %g)) return 1" % (*cs["aerial"][0], *cs["aerial"][1])})
        time.sleep(4)
        for k, (cam, at) in cs.items():
            if only and k not in only:
                continue
            d, shape = grab(sid, f"{prefix}_{k}", cam, at)
            print(k, "ok", round(d, 3), shape[1], "x", shape[0])
    finally:
        print(call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": RESTORE % orig}))
