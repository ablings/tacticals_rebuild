"""Mean rendered colour per part from a capture: casts camera rays in Studio (same camera as the capture) on a grid,
maps each grid pixel to the part it hits, and averages the PNG pixels per part (with the part's own Color).
Usage: python tools/part_pixels.py <png> x,y,z lx,ly,lz [filter-substring]"""
import json, os, subprocess, sys, tempfile
from PIL import Image
SID = "5e5685e4-6afe-4dde-b307-dd6c67c0a85d"
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
png, cam, look = sys.argv[1], sys.argv[2], sys.argv[3]
flt = sys.argv[4] if len(sys.argv) > 4 else ""
NX, NY = 64, 40
code = f"""
local cam = workspace.CurrentCamera
local old = cam.CFrame
cam.CFrame = CFrame.lookAt(Vector3.new({cam}), Vector3.new({look}))
local vs = cam.ViewportSize
local q = {{}}
for _, d in ipairs(workspace.LobbyMap:GetDescendants()) do
  if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.9 then d.CanQuery = true; table.insert(q, d) end
end
local skip = {{}}
for _, d in ipairs(workspace.LobbyMap:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.9 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local out = {{}}
for j = 0, {NY}-1 do for i = 0, {NX}-1 do
  local fx, fy = (i + 0.5) / {NX}, (j + 0.5) / {NY}
  local r = cam:ViewportPointToRay(fx * vs.X, fy * vs.Y)
  local h = workspace:Raycast(r.Origin, r.Direction * 200, rp)
  if h then
    local p = h.Instance
    table.insert(out, string.format("%d,%d,%s,%d,%d,%d,%s", i, j, p.Name, p.Color.R*255, p.Color.G*255, p.Color.B*255, p.Material.Name))
  end
end end
for _, d in ipairs(q) do d.CanQuery = false end
cam.CFrame = old
return table.concat(out, ";")
"""
fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code}, open(path, "w"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(path)
txt = r.stdout
s = txt[txt.find("0,"):] if "0," in txt else txt
im = Image.open(png).convert("RGB"); W, H = im.size
agg = {}
for rec in s.strip().strip('"').split(";"):
    f = rec.split(",")
    if len(f) < 7: continue
    try: i, j = int(f[0]), int(f[1])
    except ValueError: continue
    name = f[2]
    if flt and flt not in name: continue
    px = im.getpixel((int((i + 0.5) / NX * W), int((j + 0.5) / NY * H)))
    a = agg.setdefault(name, [0, 0, 0, 0, f[3:6], f[6]])
    a[0] += px[0]; a[1] += px[1]; a[2] += px[2]; a[3] += 1
for name, a in sorted(agg.items(), key=lambda kv: -kv[1][3]):
    n = a[3]
    if n < 4: continue
    m = (a[0] / n, a[1] / n, a[2] / n)
    col = [float(v) for v in a[4]]
    rat = "/".join(f"{m[k] / max(col[k], 1):.2f}" for k in range(3))
    print(f"{name:34s} n{n:4d} render {m[0]:5.0f},{m[1]:5.0f},{m[2]:5.0f}  part {','.join(f'{c:.0f}' for c in col)} {a[5]:12s} ratio {rat}  B-R {m[2]-m[0]:+.0f}")
