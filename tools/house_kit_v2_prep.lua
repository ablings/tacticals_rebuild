-- tools/house_kit_v2_prep.lua (2026-10-28, House 1965 restyle): run BEFORE tools/house_kit_from_import.lua when the 1965 kit
-- (art/house/v2: H_Furniture_kit, H_House, H_Exterior imported with Import 3D, gunsy funsy, scale 0.01, scene position) is in
-- Workspace. Parks the v1 kit and its raw imports (UNDO path: rename them back) so the converter builds a fresh kit and never
-- picks up v1's H_Trees (the green trees don't fit the desert: DONE_1965.md step 2). UNDO = true puts v1 back.
local UNDO = false --@UNDO
local SS = game:GetService("ServerStorage")
local function park(name, as)
	local a = SS:FindFirstChild(name)
	if a and not SS:FindFirstChild(as) then a.Name = as return name .. " -> " .. as end
	return name .. " ="
end
if UNDO then
	local k = SS:FindFirstChild("HouseKit"); if k and k:GetAttribute("ArtVersion") == "1965" then k.Name = "_HouseKit_1965" end
	local i = SS:FindFirstChild("_HouseImport"); if i and SS:FindFirstChild("_HouseImport_v1") then i.Name = "_HouseImport_1965" end
	return park("_HouseKit_v1", "HouseKit") .. "; " .. park("_HouseImport_v1", "_HouseImport")
end
assert(workspace:FindFirstChild("H_Furniture_kit") and workspace:FindFirstChild("H_House") and workspace:FindFirstChild("H_Exterior"),
	"the three 1965 imports are not in Workspace")
return park("HouseKit", "_HouseKit_v1") .. "; " .. park("_HouseImport", "_HouseImport_v1")
