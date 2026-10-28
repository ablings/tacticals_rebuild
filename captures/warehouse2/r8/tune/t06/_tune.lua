-- tools/wh2_env.lua: in Edit, show a map under its own MapInfo.Lighting, the way RoundManager.applyMapEnv does when the map
-- wins the vote (Lighting props + Atmosphere + MapGrade + Bloom). MODE = "Warehouse2" | "Warehouse" (the place's own values,
-- saved on the first call as attributes on Lighting._WH2EnvSaved) | "restore". Build copy only.
local MODE = "Warehouse2" --@MODE
local L = game:GetService("Lighting")
local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
local KEYS = { "ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows" }
local saved = L:FindFirstChild("_WH2EnvSaved")
if not saved then
	saved = Instance.new("Configuration")
	saved.Name = "_WH2EnvSaved"
	for _, k in KEYS do saved:SetAttribute(k, L[k]) end
	for _, k in { "Density", "Offset", "Haze", "Glare", "Color", "Decay" } do saved:SetAttribute("Atmosphere_" .. k, atm[k]) end
	for _, k in { "Brightness", "Contrast", "Saturation", "TintColor" } do saved:SetAttribute("Grade_" .. k, grade[k]) end
	for _, k in { "Intensity", "Size", "Threshold" } do saved:SetAttribute("Bloom_" .. k, bloom[k]) end
	saved.Parent = L
end
local function setFrom(obj, prefix, look)
	for k, v in saved:GetAttributes() do
		if prefix == "" and not k:find("_") then obj[k] = (look and look[k] ~= nil) and look[k] or v
		elseif prefix ~= "" and k:sub(1, #prefix) == prefix then
			local key = k:sub(#prefix + 1)
			obj[key] = (look and look[key] ~= nil) and look[key] or v
		end
	end
end
local look
if MODE == "Warehouse2" then
	local mod = game:GetService("ReplicatedStorage").DuelMaps.Warehouse2.MapInfo:Clone() -- fresh require
	look = require(mod).Lighting
end
setFrom(L, "", look)
setFrom(atm, "Atmosphere_", look and look.Atmosphere)
setFrom(grade, "Grade_", look and look.Grade)
setFrom(bloom, "Bloom_", look and look.Bloom)
if MODE == "restore" then saved:Destroy() end

local T = { amb = "50,51,57", out = "60,62,70", exp = 0, bright = 1, diffuse = 0.12, specular = 0.2, density = 0.32, haze = 0.4, contrast = 0.16, sat = -0.12, bloom = 0.6, thresh = 1.3, endPoint = 0.6, endRange = 40, endSpot = 2.3, endAngle = 100, endSpotRange = 20, midPoint = 0.45, midRange = 40, midSpot = 4, midAngle = 90, midSpotRange = 20, wall = 2.6, wallRange = 28, wallAngle = 100, roof = "150,152,150", door = 0.9, housingShadow = false, pointShadow = false }
local L = game:GetService("Lighting")
local function c3(s) local r, g, b = s:match("([%d.]+),%s*([%d.]+),%s*([%d.]+)") return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
-- the place's own Lighting is saved once by wh2_env.lua (Lighting._WH2EnvSaved); this only overrides the Warehouse 2 values
L.ClockTime, L.Brightness, L.ExposureCompensation = 0, T.bright, T.exp
L.Ambient, L.OutdoorAmbient = c3(T.amb), c3(T.out)
L.EnvironmentDiffuseScale, L.EnvironmentSpecularScale = T.diffuse, T.specular
local atm = L:FindFirstChildOfClass("Atmosphere") atm.Density, atm.Haze = T.density, T.haze
local g = L:FindFirstChild("MapGrade") g.Contrast, g.Saturation = T.contrast, T.sat
local b = L:FindFirstChildOfClass("BloomEffect") b.Intensity, b.Threshold = T.bloom, T.thresh
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
local map = workspace.Warehouse2
local n = 0
for _, d in map:GetDescendants() do
	if d:IsA("Light") and d.Parent and d.Parent.Name == "Lens" then
		local beam = d.Parent.Parent and d.Parent.Parent.Parent
		local mid = beam and (beam.Name == "LightBeam_2" or beam.Name == "LightBeam_3")
		if d:IsA("PointLight") then d.Brightness, d.Range, d.Shadows = mid and T.midPoint or T.endPoint, mid and T.midRange or T.endRange, T.pointShadow
		elseif d:IsA("SpotLight") then
			d.Brightness, d.Angle, d.Range = mid and T.midSpot or T.endSpot, mid and T.midAngle or T.endAngle, mid and T.midSpotRange or T.endSpotRange
		end
		n += 1
	elseif d:IsA("SpotLight") and d.Parent and d.Parent.Name == "LightSource" then
		d.Brightness, d.Range, d.Angle = T.wall, T.wallRange, T.wallAngle n += 1
	elseif d:IsA("SpotLight") and d.Parent and d.Parent.Name:match("^DoorLight_") then
		d.Brightness = T.door n += 1
	elseif d:IsA("BasePart") and (d.Name == "Housing" or d.Name == "Clamp") and d.Parent and d.Parent.Name:match("^LightBar_") then
		d.CastShadow = T.housingShadow
	elseif d:IsA("BasePart") and d.Name == "RoofSheet" then
		d.Color = c3(T.roof)
	end
end
return "tuned " .. n .. " lights | q " .. tostring(settings().Rendering.EditQualityLevel)
