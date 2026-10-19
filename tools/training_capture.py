"""Training (and Showroom) capture set via the stdio MCP bridge. Forces every RoomLight Training/Showroom light on for the
captures and restores the previous Enabled states afterwards (attribute CapLightPrev).
Usage (from tacticals_rebuild): python tools/training_capture.py <prefix: before|after> [names...]"""
import json, os, subprocess, sys, shutil, tempfile
SID = "d93b3ec2-422d-40e2-87ce-6dd7b5c4e24c"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "t1_overview": ([-122, 630, -122], [40, 600, 60]),     # high 3/4 from the SW corner (under the old 636.5 ceiling too)
  "t2_spawn":    ([-30, 611, -30],   [0, 602, 0]),       # plaza + arrivals ring
  "t3_maze":     ([-12, 606, 18],    [-80, 612, 80]),    # NW block maze from the boulevard
  "t4_roof":     ([-104, 628, 40],   [-40, 624, 110]),   # on the maze roof deck
  "t5_gallery":  ([134, 606, 0],     [352, 603, 0]),     # firing line down the gallery
  "t6_field":    ([20, 607, -25],    [100, 602, -120]),  # SE free-fire field lines
  "t7_cover":    ([-25, 607, -25],   [-110, 602, -100]), # SW cover course
  "t8_towers":   ([18, 607, 22],     [100, 616, 100]),   # NE towers + overwatch ramp
  "s1_showroom_cam": ([0, 407.4, -5], [0, 406.3, 8]),    # Kit-menu camera (CameraPoint -> DisplayPoint)
}
# lights on unless hidden by place_training (old Training lights carry TrainingHidden)
LIGHTS_ON = """local CS = game:GetService("CollectionService"); local n = 0
for _, p in CS:GetTagged("RoomLight") do local r = p:GetAttribute("Room"); if r == "Training" or r == "Showroom" then
  for _, l in p:GetDescendants() do if l:IsA("Light") then
    if l:GetAttribute("CapLightPrev") == nil then l:SetAttribute("CapLightPrev", l.Enabled) end
    if not l:GetAttribute("TrainingHidden") then l.Enabled = true; n += 1 end end end end end
return "lights on " .. n"""
LIGHTS_RESTORE = """local n = 0
for _, l in workspace:GetDescendants() do if l:IsA("Light") and l:GetAttribute("CapLightPrev") ~= nil then
  l.Enabled = l:GetAttribute("CapLightPrev"); l:SetAttribute("CapLightPrev", nil); n += 1 end end
return "restored " .. n"""
def luau(code):
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8")); os.remove(path); return r.stdout.strip()
pre = sys.argv[1]; names = sys.argv[2:] or list(CAMS)
os.makedirs("out/training", exist_ok=True)
print(luau(LIGHTS_ON))
try:
    for n in names:
        cam, look = CAMS[n]
        cid = f"{pre}_{n}"
        args = json.dumps({"studio_id": SID, "capture_id": cid, "camera_position": cam, "look_at_position": look})
        r = subprocess.run([sys.executable, CLI, "call", "screen_capture", args], capture_output=True, text=True,
                           env=dict(os.environ, PYTHONIOENCODING="utf-8"))
        src = os.path.join("out", f"{cid}_1.png")
        if os.path.exists(src):
            shutil.move(src, os.path.join("out", "training", f"{cid}.png")); print("ok", cid)
        else:
            print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
finally:
    print(luau(LIGHTS_RESTORE))
