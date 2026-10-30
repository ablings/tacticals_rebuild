-- tools/move_feel/course.lua (SERVER, Studio Play only; never saved): a test course at y 300 for the move feel measurements
local old = workspace:FindFirstChild("_MoveFeelCourse")
if old then old:Destroy() end
local m = Instance.new("Model")
m.Name = "_MoveFeelCourse"
local function part(name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(120, 120, 125)
	p.Material = Enum.Material.Concrete
	p.Parent = m
	return p
end
local Y = 300
local yaw = workspace:GetAttribute("_MFCourseYaw") or 0 -- the client camera's yaw: the lane runs where W goes
local F = CFrame.new(0, Y + 1, 0) * CFrame.Angles(0, yaw, 0)
part("Pad", Vector3.new(260, 2, 260), CFrame.new(0, Y, 0))
local top = 0 -- heights below are over the pad top, in the lane frame F
-- the chain lane (along -Z from z = 0): sprint, slide, Q at the low wall, vault, pull-up onto the block
part("LowWall", Vector3.new(14, 3, 1.5), F * CFrame.new(0, 1.5, -40), Color3.fromRGB(90, 110, 80))
part("PullBlock", Vector3.new(14, 4.5, 10), F * CFrame.new(0, 2.25, -48.5), Color3.fromRGB(150, 140, 120))
-- stairs at x = 50 (rise 0.6, run 1.6), up along -Z
for i = 1, 8 do part("Step" .. i, Vector3.new(10, 0.6 * i, 1.6), F * CFrame.new(50, 0.3 * i, 10 - 1.6 * i), Color3.fromRGB(110, 110, 140)) end
-- a 20 degree slope at x = -50
local w = Instance.new("WedgePart")
w.Name = "Slope20"
w.Anchored = true
w.Size = Vector3.new(12, 20 * math.tan(math.rad(20)), 20)
w.CFrame = F * CFrame.new(-50, w.Size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
w.Color = Color3.fromRGB(140, 110, 110)
w.Parent = m
m.Parent = workspace
local p = game.Players:GetPlayers()[1]
if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
	p.Character.HumanoidRootPart.CFrame = F * CFrame.new(0, 3.1, 40)
end
return "course built"
