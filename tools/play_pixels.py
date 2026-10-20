"""Mean rendered colour per part in a PLAY capture (Client datamodel, current camera; camera must be locked/Scriptable).
Usage: python tools/play_pixels.py <png> [filter-substring] [NX NY]
Casts one ray per grid cell from the client camera, skips parts with Transparency >= 0.9 (CanQuery-off visible parts are queried, then restored), averages a 3x3 pixel block per hit."""
import json, os, subprocess, sys, tempfile
from PIL import Image
SID = "5e5685e4-6afe-4dde-b307-dd6c67c0a85d"
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
png = sys.argv[1]
flt = sys.argv[2] if len(sys.argv) > 2 else ""
NX, NY = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (128, 80)
code = f"""
local cam = workspace.CurrentCamera
local vs = cam.ViewportSize
local skip = {{}}
local q = {{}}
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("BasePart") then
  if d.Transparency >= 0.9 then table.insert(skip, d) elseif not d.CanQuery then d.CanQuery = true; table.insert(q, d) end
end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local names, out = {{}}, {{}}
for j = 0, {NY}-1 do for i = 0, {NX}-1 do
  local r = cam:ViewportPointToRay((i+0.5)/{NX}*vs.X, (j+0.5)/{NY}*vs.Y)
  local h = workspace:Raycast(r.Origin, r.Direction*400, rp)
  if h and string.find(h.Instance.Name, "{flt}", 1, true) then
    local p = h.Instance
    local key = p.Name.."|"..math.floor(p.Color.R*255+0.5)..","..math.floor(p.Color.G*255+0.5)..","..math.floor(p.Color.B*255+0.5).."|"..p.Material.Name
    if not names[key] then names[key] = #out + 1; table.insert(out, {{key}}) end
    table.insert(out[names[key]], i..","..j)
  end
end end
for _, d in ipairs(q) do d.CanQuery = false end
local s = {{}}
for _, t in ipairs(out) do table.insert(s, table.concat(t, " ")) end
return table.concat(s, "\\n")
"""
fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": SID, "datamodel_type": "Client", "code": code}, open(path, "w"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(path)
txt = r.stdout
im = Image.open(png).convert("RGB"); W, H = im.size
for line in txt.splitlines():
    parts = line.strip().split(" ")
    if len(parts) < 2 or "|" not in parts[0]:
        continue
    key, cells = parts[0], parts[1:]
    acc = [0, 0, 0]; n = 0
    for c in cells:
        try:
            i, j = map(int, c.split(","))
        except ValueError:
            continue
        x, y = int((i + 0.5) / NX * W), int((j + 0.5) / NY * H)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                px = im.getpixel((min(W - 1, max(0, x + dx)), min(H - 1, max(0, y + dy))))
                acc = [a + b for a, b in zip(acc, px)]; n += 1
    if n:
        m = [a / n for a in acc]
        gr = m[1] / max(m[0], 1); br = m[2] / max(m[0], 1)
        print(f"{key:60s} cells {len(cells):4d} render {m[0]:.0f},{m[1]:.0f},{m[2]:.0f}  G/R {gr:.2f} B/R {br:.2f}")
if "|" not in txt:
    print(txt[:2000]); print(r.stderr[-1500:])
