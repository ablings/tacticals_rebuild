-- Put my Test copy's Edit state back to the place's own look before saving (undo what capenv_ill.lua does for captures):
-- place Sky back from ServerStorage._PlaceSkyPark, MapSky gone, HouseFarField back in MapBackdrops, hidden looks shown,
-- Lighting props / Atmosphere / grade / bloom back from Lighting._HouseEnvSaved (captured on the first capenv run).
local L, SS = game:GetService("Lighting"), game:GetService("ServerStorage")
local s = L:FindFirstChild("MapSky"); if s then s:Destroy() end
local park = SS:FindFirstChild("_PlaceSkyPark"); if park then for _, c in park:GetChildren() do c.Parent = L end park:Destroy() end
local ff = workspace:FindFirstChild("HouseFarField"); if ff then ff.Parent = SS.MapBackdrops end
for _, c in workspace:GetChildren() do
	if c:GetAttribute("MapSky_Hidden") then
		local list = c:GetDescendants(); table.insert(list, c)
		for _, d in list do local t = d:GetAttribute("MapSky_T") if t ~= nil then d.Transparency = t; d:SetAttribute("MapSky_T", nil) end end
		c:SetAttribute("MapSky_Hidden", nil)
	end
end
local saved = L:FindFirstChild("_HouseEnvSaved")
local n = 0
if saved then
	local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
	for k, v in saved:GetAttributes() do
		local obj, key = L, k
		if k:sub(1, 11) == "Atmosphere_" then obj, key = atm, k:sub(12) elseif k:sub(1, 6) == "Grade_" then obj, key = grade, k:sub(7) elseif k:sub(1, 6) == "Bloom_" then obj, key = bloom, k:sub(7) end
		if obj then obj[key] = v; n += 1 end
	end
end
local skies = {} for _, c in L:GetChildren() do if c:IsA("Sky") then table.insert(skies, c.Name) end end
return ("restored %d lighting values; skies %s; farfield in store %s"):format(n, table.concat(skies, ","), tostring(SS.MapBackdrops:FindFirstChild("HouseFarField") ~= nil))
