"""Training polish capture set (forked from tools/training_capture.py) via the stdio MCP bridge. Forces every RoomLight Training/Showroom light on for the
captures and restores the previous Enabled states afterwards (attribute CapLightPrev).
Usage (from tacticals_rebuild): python tools/polish_training_capture.py <prefix: before|after> [names...]"""
import json, os, subprocess, sys, shutil, tempfile
SID = "7f9e7426-2e49-4e8e-916c-304843df58de"   # Tacticals_rebuild.rbxl (local copy); ids change on reload
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
CAMS = {
  "arrive":   ([0, 605.5, -16],   [0, 605, 60]),        # arrival plaza, eye height, looking north
  "qA":       ([-12, 605.5, 12],  [-90, 609, 90]),      # plaza -> NW quadrant (maze)
  "qB":       ([12, 605.5, 12],   [90, 611, 90]),       # plaza -> NE quadrant (towers / overwatch)
  "qC":       ([12, 605.5, -12],  [90, 604, -90]),      # plaza -> SE quadrant (field)
  "qD":       ([-12, 605.5, -12], [-90, 605, -90]),     # plaza -> SW quadrant (cover course)
  "overview": ([-122, 640, -122], [40, 600, 60]),       # high 3/4 from the SW corner
  "gallery":  ([134, 606, 0],     [352, 603, 0]),       # firing line down the gallery
  "bin":      ([23, 604.8, -24],  [17, 601.4, -17]),    # plaza swap bin close-up
  "exitN":    ([0, 606, 8],       [0, 600, 40]),        # walking out of the plaza north: A | B floor plates
  "exitE":    ([8, 606, 0],       [40, 600, 0]),        # walking out east: B | C floor plates
  "stencil":  ([-30, 605, -19],    [-38, 600.5, -23]),   # WEAPON SWAP stencil at the SW bin, from the plaza side
  "towers":   ([20, 606, 30],     [56, 618, 96]),       # B towers: cream bands with near-black edges
  "wallN":    ([0, 607, 60],      [0, 612, 128]),       # north perimeter wall + band
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
OUT = os.path.join("out", "polish", "training"); os.makedirs(OUT, exist_ok=True)
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
            shutil.move(src, os.path.join(OUT, f"{cid}.png")); print("ok", cid)
        else:
            print("FAIL", cid, r.stdout[-400:], r.stderr[-400:])
finally:
    print(luau(LIGHTS_RESTORE))
