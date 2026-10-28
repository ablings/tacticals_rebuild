-- Warehouse 2: turn the Import 3D result (Workspace.W2_Props_kit, one MeshPart per part named "<assembly>__<part>") into
-- ServerStorage.Warehouse2Kit with one Model per assembly (the installer looks them up by name). The raw import is kept in
-- ServerStorage._W2_PropsImport (UNDO path); nothing is deleted. Re-runnable: an existing Warehouse2Kit is rebuilt.
local SS = game:GetService("ServerStorage")
local src = workspace:FindFirstChild("W2_Props_kit") or (SS:FindFirstChild("_W2_PropsImport") and SS._W2_PropsImport:FindFirstChild("W2_Props_kit"))
if not src then return "no import found" end
local kit = SS:FindFirstChild("Warehouse2Kit")
if kit then kit.Parent = nil end
kit = Instance.new("Folder"); kit.Name = "Warehouse2Kit"
local groups, order = {}, {}
for _, p in src:GetChildren() do
	if p:IsA("BasePart") and not p.Name:match("^K_") then
		local asm = p.Name:match("^(.-)__") or p.Name
		if not groups[asm] then groups[asm] = {} table.insert(order, asm) end
		table.insert(groups[asm], p)
	end
end
table.sort(order)
local lines = {}
for _, asm in order do
	local m = Instance.new("Model"); m.Name = asm
	for _, p in groups[asm] do
		local c = p:Clone()
		c.Name = p.Name:match("__(.+)$") or p.Name
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
		c.PivotOffset = CFrame.new() -- Import 3D's "pivot to scene origin" leaves a Z-up turn here: the model's box would swap Y / Z
		c.Parent = m
	end
	m.Parent = kit
	-- pivot: the bottom centre of the assembly's box, world-aligned (the installer places by the box, not the pivot)
	local bcf, bs = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bcf.Position - Vector3.new(0, bs.Y / 2, 0))
	local _, s = m:GetBoundingBox()
	table.insert(lines, ("%s: %d parts, %.2f x %.2f x %.2f"):format(asm, #m:GetChildren(), s.X, s.Y, s.Z))
end
kit.Parent = SS
local hold = SS:FindFirstChild("_W2_PropsImport") or Instance.new("Folder")
hold.Name = "_W2_PropsImport"; hold.Parent = SS
if src.Parent == workspace then src.Parent = hold end
return table.concat(lines, "\n")
