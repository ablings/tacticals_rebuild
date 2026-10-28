-- tools/house_capenv.lua (copy of tools/wh2_capenv.lua): in Edit, show a map under its own MapInfo.Lighting, the way RoundManager.applyMapEnv does when the map
-- wins the vote (Lighting props + Atmosphere + MapGrade + Bloom). MODE = "Warehouse2" | "Warehouse" (the place's own values,
-- saved on the first call as attributes on Lighting._HouseEnvSaved) | "restore". Build copy only.
local MODE = "House" --@MODE
local L = game:GetService("Lighting")
local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
local KEYS = { "ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows" }
local saved = L:FindFirstChild("_HouseEnvSaved")
if not saved then
	saved = Instance.new("Configuration")
	saved.Name = "_HouseEnvSaved"
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
if MODE == "House" or MODE == "Warehouse2" then
	local mod = game:GetService("ReplicatedStorage").DuelMaps[MODE].MapInfo:Clone() -- fresh require
	look = require(mod).Lighting
end
setFrom(L, "", look)
setFrom(atm, "Atmosphere_", look and look.Atmosphere)
setFrom(grade, "Grade_", look and look.Grade)
setFrom(bloom, "Bloom_", look and look.Bloom)
if MODE == "restore" then saved:Destroy() end
-- the broken panes are authored visible (the game hides them until a pane breaks): hide them for Edit captures, put back on
-- "restore" (attribute _CapHidden marks what this script hid)
local house = workspace:FindFirstChild("House")
if house then
	for _, w in house.Shootables:GetChildren() do
		local b = w:FindFirstChild("BrokenGlass")
		for _, d in (b and (b:IsA("BasePart") and { b } or b:GetDescendants()) or {}) do
			if d:IsA("BasePart") then
				if MODE == "restore" then
					if d:GetAttribute("_CapHidden") then d.Transparency = d:GetAttribute("_CapHidden"); d:SetAttribute("_CapHidden", nil) end
				elseif d:GetAttribute("_CapHidden") == nil then
					d:SetAttribute("_CapHidden", d.Transparency); d.Transparency = 1
				end
			end
		end
	end
end
-- capture quality = the PC default players get (Studio's EditQualityLevel is per process and defaulted to Level01 here)
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
return MODE .. " lighting applied: clock " .. L.ClockTime .. " bright " .. L.Brightness .. " exp " .. L.ExposureCompensation .. " | EditQualityLevel " .. tostring(settings().Rendering.EditQualityLevel)
