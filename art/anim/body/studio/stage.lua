-- stage.lua: the anim-body capture stage at (0, 800, 0) in my place copy: floor, tall wall, low wall, stairs, and avatars
-- kept in ServerStorage._AnimAvatars (a default blocky R15 + real player avatars by user id). Edit mode only.
local Players = game:GetService("Players")
local O = Vector3.new(0, 800, 0)
local old = workspace:FindFirstChild("_AnimStage"); if old then old:Destroy() end
local f = Instance.new("Folder"); f.Name = "_AnimStage"; f.Parent = workspace
local function part(name, size, cfr, color, mat)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cfr
	p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.TopSurface = Enum.SurfaceType.Smooth; p.Parent = f; return p
end
part("Floor", Vector3.new(80, 1, 80), CFrame.new(O + Vector3.new(0, -0.5, 0)), Color3.fromRGB(150, 152, 158), Enum.Material.Concrete)
part("Backdrop", Vector3.new(80, 40, 1), CFrame.new(O + Vector3.new(0, 20, 30)), Color3.fromRGB(200, 196, 186))
-- tall cover wall behind the cover spot (character at x=0,z=0 faces -z, wall at z=+1.6)
part("TallWall", Vector3.new(10, 7, 2), CFrame.new(O + Vector3.new(0, 3.5, 2.05)), Color3.fromRGB(107, 122, 58), Enum.Material.Concrete)
-- low cover at x=-14
part("LowWall", Vector3.new(8, 3, 2), CFrame.new(O + Vector3.new(-14, 1.5, 2.05)), Color3.fromRGB(138, 156, 74), Enum.Material.Concrete)
-- stairs at x=14, rising toward -z: 0.5 rise, 1.0 run
for i = 0, 7 do
	part("Step" .. i, Vector3.new(6, 0.5 * (i + 1), 1), CFrame.new(O + Vector3.new(14, 0.25 * (i + 1), 2 - i)), Color3.fromRGB(163, 162, 165), Enum.Material.Concrete)
end
-- avatars
local store = game.ServerStorage:FindFirstChild("_AnimAvatars")
if not store then
	store = Instance.new("Folder"); store.Name = "_AnimAvatars"; store.Parent = game.ServerStorage
end
local made = {}
local function keep(name, model)
	model.Name = name
	for _, d in model:GetDescendants() do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	model.Parent = store
	table.insert(made, name)
end
if not store:FindFirstChild("Blocky") then
	keep("Blocky", Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15))
end
for _, n in { "AvatarA", "AvatarB" } do local o = store:FindFirstChild(n); if o and o:FindFirstChildOfClass("Humanoid").RigType ~= Enum.HumanoidRigType.R15 then o:Destroy() end end
for _, u in { { "AvatarA", 156 }, { "AvatarB", 261 } } do
	if not store:FindFirstChild(u[1]) then
		local ok, m = pcall(function() return Players:CreateHumanoidModelFromDescription(Players:GetHumanoidDescriptionFromUserId(u[2]), Enum.HumanoidRigType.R15) end)
		if ok and m then keep(u[1], m) else table.insert(made, u[1] .. " FAILED " .. tostring(m)) end
	end
end
local names = {}
for _, c in store:GetChildren() do table.insert(names, c.Name .. "(" .. tostring(c:FindFirstChildOfClass("Humanoid").RigType) .. ")") end
return "stage ok; made " .. table.concat(made, ",") .. "; avatars " .. table.concat(names, ",")
