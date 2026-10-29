-- tools/house_kit_fix65.lua (2026-10-28, grade 1965 r3): swap the modeler's closed-base fix (art/house/v2/FIX65_DONE.md,
-- H_Furniture_fix65.fbx imported with Import 3D: gunsy funsy, scale 0.01, scene position) into ServerStorage.HouseKit.
-- Same grouping and pivot rule as tools/house_kit_from_import.lua (object "Asm__Part" -> assembly Asm; pivot = bottom centre of
-- the bounding box). The replaced assemblies go to ServerStorage._HouseKit_prefix65 (UNDO: move them back). Re-runnable.
local SS = game:GetService("ServerStorage")
local src = workspace:FindFirstChild("H_Furniture_fix65") or (SS:FindFirstChild("_HouseImport") and SS._HouseImport:FindFirstChild("H_Furniture_fix65"))
assert(src, "import H_Furniture_fix65 first")
local kit = SS.HouseKit
local old = SS:FindFirstChild("_HouseKit_prefix65") or Instance.new("Folder"); old.Name = "_HouseKit_prefix65"; old.Parent = SS
local groups, order = {}, {}
for _, p in src:GetDescendants() do
	if p:IsA("BasePart") and not p.Name:match("^K_") then
		local asm = p.Name:match("^(.-)__") or p.Name:gsub("%.%d+$", "")
		if not groups[asm] then groups[asm] = {} table.insert(order, asm) end
		table.insert(groups[asm], p)
	end
end
local lines = {}
for _, asm in order do
	local prev = kit:FindFirstChild(asm)
	if prev then
		if not old:FindFirstChild(asm) then prev.Parent = old else prev:Destroy() end
	end
	local m = Instance.new("Model"); m.Name = asm
	for _, p in groups[asm] do
		local c = p:Clone()
		for _, ch in c:GetChildren() do if ch:IsA("BasePart") then ch:Destroy() end end
		c.Name = (p.Name:match("__(.+)$") or p.Name)
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
		c.PivotOffset = CFrame.new()
		c.Parent = m
	end
	local bcf, bs = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bcf.Position - Vector3.new(0, bs.Y / 2, 0))
	m:SetAttribute("Fix65", true)
	m.Parent = kit
	local sa = 0 for _, d in m:GetDescendants() do if d:IsA("SurfaceAppearance") then sa += 1 end end
	table.insert(lines, ("%s %d parts %d SA %.2fx%.2fx%.2f"):format(asm, #m:GetChildren(), sa, bs.X, bs.Y, bs.Z))
end
local hold = SS:FindFirstChild("_HouseImport"); if hold then src.Parent = hold end
return "fix65 swapped: " .. table.concat(lines, "; ")
