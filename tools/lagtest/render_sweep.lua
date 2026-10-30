-- Edit (or Client): for each camera x quality level, read RenderBreakdown + FrameRateManager. CAMS = "name:px,py,pz>lx,ly,lz;..."  LEVELS = "1,5,10,21"
local S = game:GetService("Stats")
local cam = workspace.CurrentCamera
local old = cam.CFrame
local isEdit = not game:GetService("RunService"):IsRunning()
local function setQ(n)
  local e = Enum.QualityLevel["Level" .. string.format("%02d", n)]
  pcall(function() settings().Rendering.EditQualityLevel = e end)
  pcall(function() settings().Rendering.QualityLevel = e end)
end
local function read()
  local rb, tris, draws, passes = S.RenderBreakdown, 0, 0, {}
  for _, c in rb:GetChildren() do
    local t, d = c:GetValueString():match("(%d+) tris, (%d+) draws"); t, d = tonumber(t) or 0, tonumber(d) or 0
    tris += t; draws += d; if d > 0 then table.insert(passes, c.Name .. " " .. t .. "/" .. d) end
  end
  local F = S.FrameRateManager
  local function g(k) local it = F:FindFirstChild(k); return it and it:GetValue() or -1 end
  return string.format("tris %d draws %d | allTris~%dk | gpu %.2fms rthread %.2fms | batches %d | %s", tris, draws, g("Indices") / 3000, g("AverageGPU"), g("RenderThreadAverage"), g("Batches"), table.concat(passes, ", "))
end
local out = {}
local hold = tonumber("{{HOLD}}") or 2.5
for spec in string.gmatch("{{CAMS}}", "[^;]+") do
  local name, a, b = spec:match("([^:]+):([^>]+)>(.+)")
  if spec == "here" then name, a, b = "here", "0,0,0", "0,0,1" end
  local function v(s) local x, y, z = s:match("([-%d.]+),([-%d.]+),([-%d.]+)"); return Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
  local cf = CFrame.lookAt(v(a), v(b))
  for lv in string.gmatch("{{LEVELS}}", "[^,]+") do
    setQ(tonumber(lv))
    local root = not isEdit and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local function place() if spec == "here" then return elseif isEdit then cam.CFrame = cf elseif root then root.CFrame = CFrame.lookAt(cf.Position - Vector3.new(0, 1.5, 0), cf.Position - Vector3.new(0, 1.5, 0) + cf.LookVector * Vector3.new(1, 0, 1)); root.AssemblyLinearVelocity = Vector3.zero end end
    local t0 = os.clock(); while os.clock() - t0 < hold do place(); task.wait() end
    table.insert(out, string.format("%-10s L%02d | %s", name, tonumber(lv), read()))
  end
end
setQ(21)
if isEdit then cam.CFrame = old end
return table.concat(out, "\n")
