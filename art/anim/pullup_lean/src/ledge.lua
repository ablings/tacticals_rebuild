local f = workspace._AnimStage
local old = f:FindFirstChild("Ledge"); if old then old:Destroy() end
local p = Instance.new("Part"); p.Name = "Ledge"; p.Anchored = true
p.Size = Vector3.new(2.6, 4.5, 8); p.CFrame = CFrame.new(0, 800 + 2.25, -1.6 - 4)
p.Color = Color3.fromRGB(107, 122, 58); p.Material = Enum.Material.Concrete; p.Parent = f
return "ledge"
