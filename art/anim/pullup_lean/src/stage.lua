--@lib
local old = workspace:FindFirstChild("_AnimStage"); if old then old:Destroy() end
local f = Instance.new("Folder"); f.Name = "_AnimStage"; f.Parent = workspace
local function part(name, size, cfr, color, mat)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cfr
	p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.Parent = f; return p
end
local O = Vector3.new(0, 800, 0)
part("Floor", Vector3.new(60, 1, 60), CFrame.new(O + Vector3.new(0, -0.5, 0)), Color3.fromRGB(150, 152, 158), Enum.Material.Concrete)
part("Back", Vector3.new(60, 30, 1), CFrame.new(O + Vector3.new(0, 15, 22)), Color3.fromRGB(200, 196, 186))
part("Back2", Vector3.new(1, 30, 60), CFrame.new(O + Vector3.new(-24, 15, 0)), Color3.fromRGB(200, 196, 186))
local rig = L.rig:Clone(); rig.Name = "StageRig"
for _, d in rig:GetDescendants() do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
rig:PivotTo(CFrame.new(O + Vector3.new(0, 3, 0)))  -- faces -Z
rig.HumanoidRootPart.Anchored = true
rig.HumanoidRootPart.Transparency = 1
rig.Parent = f
return "stage ok, rig look " .. tostring(rig.HumanoidRootPart.CFrame.LookVector) .. " anim=" .. tostring(rig.Humanoid:FindFirstChildOfClass("Animator"))
