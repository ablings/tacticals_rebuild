"""Showroom captures from the hook camera: CameraPoint's CFrame at the Kit menu's FOV 40 (LobbyUIController.Armory reveal), with
the Showroom RoomLights forced on (restored after). Also writes a blurred copy (the menu blurs the room behind the item:
BlurEffect size 16) so the set is judged the way players see it.
Usage (from tacticals_rebuild): python tools/polish_showroom_capture.py <prefix> [wide]"""
import json, os, subprocess, sys, shutil, tempfile
from PIL import Image, ImageFilter
SID = "d93b3ec2-422d-40e2-87ce-6dd7b5c4e24c"
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
OUT = os.path.join("out", "polish", "showroom"); os.makedirs(OUT, exist_ok=True)
def luau(code):
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8")); os.remove(path); return r.stdout.strip()
SETUP = """local CS = game:GetService("CollectionService"); local n = 0
for _, p in CS:GetTagged("RoomLight") do if p:GetAttribute("Room") == "Showroom" then
  for _, l in p:GetDescendants() do if l:IsA("Light") then
    if l:GetAttribute("CapLightPrev") == nil then l:SetAttribute("CapLightPrev", l.Enabled) end
    l.Enabled = true; n += 1 end end end end
local cam = workspace.CurrentCamera; cam:SetAttribute("CapFov", cam.FieldOfView); cam.FieldOfView = %s
local S = workspace.LobbyMap.Showroom
local c, d = S.CameraPoint, S.DisplayPoint
return string.format("%%d lights; cam %%.2f,%%.2f,%%.2f look %%.2f,%%.2f,%%.2f", n, c.Position.X, c.Position.Y, c.Position.Z,
  c.Position.X + c.CFrame.LookVector.X * 20, c.Position.Y + c.CFrame.LookVector.Y * 20, c.Position.Z + c.CFrame.LookVector.Z * 20)"""
RESTORE = """local n = 0
for _, l in workspace:GetDescendants() do if l:IsA("Light") and l:GetAttribute("CapLightPrev") ~= nil then
  l.Enabled = l:GetAttribute("CapLightPrev"); l:SetAttribute("CapLightPrev", nil); n += 1 end end
local cam = workspace.CurrentCamera; cam.FieldOfView = cam:GetAttribute("CapFov") or 70; cam:SetAttribute("CapFov", nil)
return "restored " .. n"""
pre = sys.argv[1]
views = [("cam", "40")] + ([("wide", "70")] if "wide" in sys.argv[2:] else [])
for name, fov in views:
    info = luau(SETUP % fov)
    try:
        import re
        nums = [float(v) for v in re.findall(r"-?\d+\.\d+", info)]
        cam, look = nums[0:3], nums[3:6]
        if name == "wide":
            cam = [cam[0], cam[1] + 2, cam[2] - 14]
        cid = f"{pre}_{name}"
        args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
        r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                           env=dict(os.environ, PYTHONIOENCODING="utf-8"))
        src = os.path.join("out", f"{cid}_1.png")
        if os.path.exists(src):
            dst = os.path.join(OUT, f"{cid}.png"); shutil.move(src, dst)
            im = Image.open(dst).convert("RGB")
            im.filter(ImageFilter.GaussianBlur(im.size[0] / 1920 * 16)).save(os.path.join(OUT, f"{cid}_blur.png"))
            print("ok", cid, info)
        else:
            print("FAIL", cid, r.stdout[-300:], r.stderr[-300:])
    finally:
        print(luau(RESTORE))
