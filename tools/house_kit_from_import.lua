local ASM = {["H_Sofa_Sectional"]="H_Sofa_Sectional", ["H_Armchair"]="H_Armchair", ["H_KitchenIsland"]="H_KitchenIsland", ["H_DiningSet__H_DiningTable"]="H_DiningSet", ["H_DiningSet__H_DiningChair"]="H_DiningSet", ["H_DiningSet__H_DiningChair.001"]="H_DiningSet", ["H_DiningSet__H_DiningChair.002"]="H_DiningSet", ["H_DiningSet__H_DiningChair.003"]="H_DiningSet", ["H_DiningSet__H_DiningChair.004"]="H_DiningSet", ["H_DiningSet__H_DiningChair.005"]="H_DiningSet", ["H_DiningTable"]="H_DiningTable", ["H_DiningChair"]="H_DiningChair", ["H_Bed_Double"]="H_Bed_Double", ["H_Bed_Single"]="H_Bed_Single", ["H_Dresser"]="H_Dresser", ["H_Bathtub"]="H_Bathtub", ["H_TVConsole"]="H_TVConsole", ["H_TVConsole_WithTV__H_TVConsole"]="H_TVConsole_WithTV", ["H_TVConsole_WithTV__H_TV"]="H_TVConsole_WithTV", ["H_TVConsole_WithTV__H_TV_Screen"]="H_TVConsole_WithTV", ["H_KitchenBase"]="H_KitchenBase", ["H_KitchenSink"]="H_KitchenSink", ["H_KitchenHob"]="H_KitchenHob", ["H_Bookcase"]="H_Bookcase", ["H_Fridge"]="H_Fridge", ["H_Wardrobe"]="H_Wardrobe", ["H_TallCabinet"]="H_TallCabinet", ["H_Pantry"]="H_Pantry", ["H_ShelfWall__H_ShelfWall"]="H_ShelfWall", ["H_ShelfWall__H_ShelfWall_Books"]="H_ShelfWall", ["H_OvenWall"]="H_OvenWall", ["H_SlatScreen"]="H_SlatScreen", ["H_HeadboardWall"]="H_HeadboardWall", ["H_KitchenBench"]="H_KitchenBench", ["H_HallBench_3"]="H_HallBench_3", ["H_HallBench_8"]="H_HallBench_8", ["H_Planter__H_Planter"]="H_Planter", ["H_Planter__H_Planter_Tree"]="H_Planter", ["H_DisplayColumn"]="H_DisplayColumn", ["H_KitchenUpper"]="H_KitchenUpper", ["H_RangeHood"]="H_RangeHood", ["H_BarStool"]="H_BarStool", ["H_Nightstand"]="H_Nightstand", ["H_CoffeeTable"]="H_CoffeeTable", ["H_SideTable"]="H_SideTable", ["H_Desk"]="H_Desk", ["H_DeskChair"]="H_DeskChair", ["H_WashingMachine"]="H_WashingMachine", ["H_FruitBowl"]="H_FruitBowl", ["H_Microwave"]="H_Microwave", ["H_CoffeeMachine"]="H_CoffeeMachine", ["H_Kettle"]="H_Kettle", ["H_TV__H_TV"]="H_TV", ["H_TV__H_TV_Screen"]="H_TV", ["H_Laptop"]="H_Laptop", ["H_FloorLamp__H_FloorLamp"]="H_FloorLamp", ["H_FloorLamp__H_FloorLamp_Shade"]="H_FloorLamp", ["H_TableLamp__H_TableLamp"]="H_TableLamp", ["H_TableLamp__H_TableLamp_Shade"]="H_TableLamp", ["H_PendantLamp__H_PendantLamp"]="H_PendantLamp", ["H_PendantLamp__H_PendantLamp_Bulb"]="H_PendantLamp", ["H_Frame_Abstract"]="H_Frame_Abstract", ["H_Frame_Landscape"]="H_Frame_Landscape", ["H_Frame_Botanical"]="H_Frame_Botanical", ["H_Frame_Geometric"]="H_Frame_Geometric", ["H_Rug_Living"]="H_Rug_Living", ["H_Rug_Runner"]="H_Rug_Runner", ["H_PlantFiddle"]="H_PlantFiddle", ["H_PlantSnake"]="H_PlantSnake", ["H_Toilet"]="H_Toilet", ["H_Vanity"]="H_Vanity", ["H_Mirror"]="H_Mirror", ["H_ShowerSet"]="H_ShowerSet", ["H_ShowerGlass__H_ShowerGlass"]="H_ShowerGlass", ["H_ShowerGlass__H_ShowerGlassProfile"]="H_ShowerGlass", ["H_TowelRail"]="H_TowelRail", ["H_ToyBlocks"]="H_ToyBlocks", ["H_ToyBall"]="H_ToyBall", ["H_ToyCar"]="H_ToyCar", ["H_Teddy"]="H_Teddy"}

-- tools/house_kit_from_import.lua (generated part: ASM = house_furniture.json objects -> assembly). Turns the three Import 3D
-- results in Workspace (H_Furniture_kit, H_House, H_Exterior) into ServerStorage.HouseKit: one Model per furniture assembly
-- (pivot = the bottom centre of its box, every PivotOffset reset), and H_House / H_Exterior as whole models pivoted on the plan
-- origin (Import 3D with "Insert Using Scene Position": Studio = (-x, z, y) of the plan). The raw imports are kept in
-- ServerStorage._HouseImport (UNDO path); K_ScaleCube / K_Marker stay there. Re-runnable.
local SS = game:GetService("ServerStorage")
local hold = SS:FindFirstChild("_HouseImport") or Instance.new("Folder")
hold.Name = "_HouseImport"; hold.Parent = SS
local function raw(n) return workspace:FindFirstChild(n) or hold:FindFirstChild(n) end
local fk, hs, ex = raw("H_Furniture_kit"), raw("H_House"), raw("H_Exterior")
assert(fk and hs and ex, "missing an import")
for _, m in { fk, hs, ex } do m.Parent = hold end
local kit = SS:FindFirstChild("HouseKit"); if kit then kit:Destroy() end
kit = Instance.new("Folder"); kit.Name = "HouseKit"
local groups, order, unknown = {}, {}, {}
for _, p in fk:GetDescendants() do
	if p:IsA("BasePart") and not p.Name:match("^K_") then
		local base = p.Name
		local asm = ASM[base] or ASM[base:gsub("%.%d+$", "")] or base:match("^(.-)__")
		if not asm then table.insert(unknown, base) asm = base end
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
		for _, ch in c:GetChildren() do if ch:IsA("BasePart") then ch:Destroy() end end
		c.Name = (p.Name:match("__(.+)$") or p.Name)
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
		c.PivotOffset = CFrame.new()
		c.Parent = m
	end
	local bcf, bs = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bcf.Position - Vector3.new(0, bs.Y / 2, 0))
	m.Parent = kit
	table.insert(lines, ("%s %d %.2fx%.2fx%.2f"):format(asm, #m:GetChildren(), bs.X, bs.Y, bs.Z))
end
local function whole(src, name)
	local m = src:Clone(); m.Name = name
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name:match("^K_") then d:Destroy() else d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false; d.PivotOffset = CFrame.new() end
		end
	end
	m.WorldPivot = CFrame.new() -- the plan origin
	m.Parent = kit
	return m
end
local h = whole(hs, "H_House"); local e = whole(ex, "H_Exterior")
kit.Parent = SS
return ("HouseKit: %d furniture assemblies, H_House %d parts, H_Exterior %d parts; unknown names: %s\n%s"):format(#order,
	#h:GetDescendants(), #e:GetDescendants(), table.concat(unknown, ","), table.concat(lines, "; "))
