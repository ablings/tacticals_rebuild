local L = game:GetService("Lighting")
local out = {}
local function p(s) table.insert(out, s) end
local okT,tech=pcall(function() return L.Technology end) p("Tech="..tostring(tech).." Style="..tostring(L.LightingStyle).." Prio="..tostring(L.PrioritizeLightingQuality))
for _,k in {"ClockTime","GeographicLatitude","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows","ShadowSoftness","ColorShift_Top","ColorShift_Bottom"} do
  p(k.."="..tostring(L[k]))
end
for _,c in L:GetChildren() do
  local s = c.ClassName.." "..c.Name
  pcall(function() s = s.." Enabled="..tostring(c.Enabled) end)
  if c:IsA("Atmosphere") then s=s..string.format(" D=%.3f O=%.3f H=%.2f G=%.2f C=%s Dc=%s",c.Density,c.Offset,c.Haze,c.Glare,tostring(c.Color),tostring(c.Decay)) end
  if c:IsA("ColorCorrectionEffect") then s=s..string.format(" B=%.3f C=%.3f S=%.3f T=%s",c.Brightness,c.Contrast,c.Saturation,tostring(c.TintColor)) end
  if c:IsA("BloomEffect") then s=s..string.format(" I=%.2f S=%.1f T=%.2f",c.Intensity,c.Size,c.Threshold) end
  if c:IsA("Sky") then s=s.." Up="..c.SkyboxUp.." Moon="..tostring(c.MoonAngularSize).." Stars="..c.StarCount.." Celestial="..tostring(c.CelestialBodiesShown) end
  if c:IsA("SunRaysEffect") then s=s..string.format(" I=%.3f",c.Intensity) end
  if c:IsA("DepthOfFieldEffect") then s=s.." DOF" end
  p(s)
end
p("FOV="..workspace.CurrentCamera.FieldOfView.." Streaming="..tostring(workspace.StreamingEnabled).." CamType="..tostring(workspace.CurrentCamera.CameraType))
p("Quality="..tostring(settings().Rendering.QualityLevel))
p("RunMode IsRunning="..tostring(game:GetService("RunService"):IsRunning()))
local wh2 = workspace:FindFirstChild("Warehouse2")
p("WH2 exists="..tostring(wh2~=nil).." Indoor="..tostring(wh2 and wh2:GetAttribute("Indoor")))
local ex = workspace:FindFirstChild("Warehouse2Exterior")
p("Exterior exists="..tostring(ex~=nil).." Indoor="..tostring(ex and ex:GetAttribute("Indoor")))
local old = workspace:FindFirstChild("Warehouse")
p("Old warehouse descendants="..tostring(old and #old:GetDescendants()))
local ms = game:GetService("MaterialService")
local mv = {}
for _,d in ms:GetDescendants() do if d:IsA("MaterialVariant") then table.insert(mv,d.Name) end end
p("MaterialVariants="..table.concat(mv,","))
local okU,u22=pcall(function() return ms.Use2022Materials end) p("Use2022="..tostring(u22))
local saved = L:FindFirstChild("_WH2EnvSaved")
p("EnvSaved="..tostring(saved~=nil))
p("TeleportData="..tostring(workspace:FindFirstChild("StudioTeleportData")) )
local sel = game.Selection:Get()
p("Selection="..#sel)
return table.concat(out,"\n")
