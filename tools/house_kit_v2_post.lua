-- tools/house_kit_v2_post.lua: after tools/house_kit_from_import.lua on the 1965 imports: stamp the kit (the installer keys its
-- v1-only fixes off ArtVersion) and measure the import (K_ScaleCube must be 10 studs).
local SS = game:GetService("ServerStorage")
local kit = SS.HouseKit
kit:SetAttribute("ArtVersion", "1965")
local hold = SS._HouseImport
local out = {}
for _, n in { "H_Furniture_kit", "H_House", "H_Exterior" } do
	local m = hold:FindFirstChild(n)
	local c = m and m:FindFirstChild("K_ScaleCube", true)
	local mesh, sa, tex = 0, 0, 0
	for _, d in (m and m:GetDescendants() or {}) do
		if d:IsA("MeshPart") then mesh += 1; if d.TextureID ~= "" then tex += 1 end end
		if d:IsA("SurfaceAppearance") then sa += 1 end
	end
	table.insert(out, ("%s: K_ScaleCube %s, %d MeshParts, %d SA, %d TextureID"):format(n, c and tostring(c.Size) or "MISSING", mesh, sa, tex))
end
local plain = {}
for _, d in kit:GetDescendants() do
	if d:IsA("MeshPart") and d.TextureID == "" and not d:FindFirstChildOfClass("SurfaceAppearance") then plain[d.Name] = (plain[d.Name] or 0) + 1 end
end
local pl = {} for k, v in plain do table.insert(pl, k .. "x" .. v) end table.sort(pl)
table.insert(out, "untextured MeshParts in the kit (" .. #pl .. "): " .. table.concat(pl, ", "))
return table.concat(out, "\n")
