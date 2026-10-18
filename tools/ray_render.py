"""Fallback 'camera' when screen_capture returns blank white (minimised Studio window): a raycast albedo render.
Usage (from tacticals_rebuild): python tools/ray_render.py out.png cx,cy,cz lx,ly,lz [W H FOV]
Read-only apart from toggling CanQuery on non-queryable visible parts inside a 90-stud box round the camera (restored).
Shading: part colour x (0.35 + 0.65 * max(0, n.l)), Neon unshaded, SurfaceGuis ignored, transparency >= 0.95 skipped."""
import json, os, subprocess, sys, tempfile
from PIL import Image
SID = "7f9e7426-2e49-4e8e-916c-304843df58de"
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
out = sys.argv[1]; cam = sys.argv[2]; look = sys.argv[3]
W = int(sys.argv[4]) if len(sys.argv) > 4 else 256; H = int(sys.argv[5]) if len(sys.argv) > 5 else 160
FOV = float(sys.argv[6]) if len(sys.argv) > 6 else 70
code = f"""
local cam = Vector3.new({cam}); local look = Vector3.new({look})
local W, H, FOV = {W}, {H}, {FOV}
local J0, J1 = __J0__, __J1__
local q = {{}}
for _, d in ipairs(workspace:GetDescendants()) do
  if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and (d.Position - cam).Magnitude < 90 then d.CanQuery = true; table.insert(q, d) end
end
local skip = {{}}
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 and (d.Position - cam).Magnitude < 90 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local cf = CFrame.lookAt(cam, look)
local th = math.tan(math.rad(FOV / 2)); local aspect = W / H
local Ld = Vector3.new(0.35, 0.8, -0.45).Unit
local buf = table.create(W * H)
for j = J0, J1 - 1 do
  for i = 0, W - 1 do
    local u = ((i + 0.5) / W * 2 - 1) * th * aspect; local v = (1 - (j + 0.5) / H * 2) * th
    local dir = cf:VectorToWorldSpace(Vector3.new(u, v, -1)).Unit
    local h = workspace:Raycast(cam, dir * 200, rp)
    local r, g, b = 150, 180, 210
    if h then
      local c = h.Instance.Color
      local k
      if h.Instance.Material == Enum.Material.Neon then k = 1.15 else
        local n = h.Normal
        k = 0.35 + 0.65 * math.max(0, n:Dot(Ld)) * 0.7 + 0.3 * math.abs(n:Dot(-dir)) * 0.65
        local dist = (h.Position - cam).Magnitude; k = k * (1 - math.min(dist, 120) / 400)
      end
      r, g, b = math.min(255, c.R * 255 * k), math.min(255, c.G * 255 * k), math.min(255, c.B * 255 * k)
    end
    buf[#buf + 1] = string.format("%02x%02x%02x", r, g, b)
  end
  if j % 20 == 0 then task.wait() end
end
for _, d in ipairs(q) do d.CanQuery = false end
return table.concat(buf)
"""
import re
BAND = max(1, 3000 // W)
txt = ""
for j0 in range(0, H, BAND):
    j1 = min(H, j0 + BAND)
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code.replace("__J0__", str(j0)).replace("__J1__", str(j1))}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    os.remove(path)
    need = W * (j1 - j0) * 6
    m = re.findall(r"[0-9a-f]{%d,}" % need, r.stdout)
    if not m:
        print("FAIL band", j0, r.stdout[:300], r.stderr[-500:]); sys.exit(1)
    txt += m[-1][-need:]
im = Image.frombytes("RGB", (W, H), bytes.fromhex(txt))
im.resize((W * 3, H * 3), Image.NEAREST).save(out); print("ok", out)
