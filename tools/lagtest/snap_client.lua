-- Client: one snapshot of render / memory / network numbers. LABEL = tag for the line.
local S = game:GetService("Stats")
local out = { label = "{{LABEL}}" }
local function item(path)
  local it = S
  for seg in string.gmatch(path, "[^/]+") do it = it and it:FindFirstChild(seg) end
  if not it then return nil end
  local ok, v = pcall(function() return it:GetValue() end)
  if ok then return v end
  local ok2, s = pcall(function() return it:GetValueString() end)
  return ok2 and s or nil
end
local rb = S:FindFirstChild("RenderBreakdown")
local tris, draws, parts = 0, 0, {}
if rb then for _, c in rb:GetChildren() do
  local s = c:GetValueString(); local t, d = s:match("(%d+) tris, (%d+) draws")
  t, d = tonumber(t) or 0, tonumber(d) or 0
  if t > 0 or d > 0 then parts[c.Name] = t .. "/" .. d end
  tris += t; draws += d
end end
out.tris, out.draws, out.passes = tris, draws, parts
for _, k in { "Batches", "Indices", "MaterialChanges", "AverageFPS", "RenderAverage", "PrepareAverage", "PerformAverage", "AverageGPU",
  "RenderThreadAverage", "FramebufferWidth", "FramebufferHeight", "AverageQualityLevel", "FrameSpikeCount" } do
  out[k] = item("FrameRateManager/" .. k)
end
out.memTotal = math.floor(S:GetTotalMemoryUsageMb())
local mem = {}
for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
  local ok, v = pcall(function() return S:GetMemoryUsageMbForTag(tag) end)
  if ok and v and v >= 1 then mem[tag.Name] = math.floor(v * 10) / 10 end
end
out.mem = mem
out.recvKbps = math.floor(S.DataReceiveKbps * 10) / 10
out.sendKbps = math.floor(S.DataSendKbps * 10) / 10
out.physRecv = math.floor(S.PhysicsReceiveKbps * 10) / 10
out.instances = S.InstanceCount
out.primitives = S.PrimitivesCount
out.heartbeatMs = math.floor(S.HeartbeatTimeMs * 100) / 100
out.q = tostring(settings().Rendering.QualityLevel)
local ok, eq = pcall(function() return tostring(settings().Rendering.EditQualityLevel) end); out.eq = ok and eq or "?"
-- lights and emitters near the camera
local cam = workspace.CurrentCamera
local cpos = cam and cam.CFrame.Position or Vector3.zero
local near, nearShadow, pe, peRate = 0, 0, 0, 0
for _, d in workspace:GetDescendants() do
  if d:IsA("Light") and d.Enabled then
    local p = d.Parent
    local pos = p and (p:IsA("BasePart") and p.Position or (p:IsA("Attachment") and p.WorldPosition))
    if pos and (pos - cpos).Magnitude < 150 then near += 1; if d.Shadows then nearShadow += 1 end end
  elseif d:IsA("ParticleEmitter") and d.Enabled then pe += 1; peRate += d.Rate end
end
out.lights150, out.shadowLights150, out.peOn, out.peRate = near, nearShadow, pe, math.floor(peRate)
out.cam = cam and string.format("%.0f,%.0f,%.0f", cpos.X, cpos.Y, cpos.Z)
return game:GetService("HttpService"):JSONEncode(out)
