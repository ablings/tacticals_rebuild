-- Side rooms (pass 22): room lights only switch on near their room (keeps the enabled-light count inside the
-- ~45 budget), and display pieces with a Spin attribute turn slowly. Streaming-safe (tag signals).
local CS = game:GetService("CollectionService"); local RS = game:GetService("RunService")
local CENTRES = {Shop = Vector3.new(0, 6, 89), Armory = Vector3.new(0, 8, -91), Exfil = Vector3.new(150, 10, 0), Training = Vector3.new(0, 606, 0), Showroom = Vector3.new(0, 410, 8)}
local RADIUS = 75
local ROOM_RADIUS = {Training = 175}   -- the huge training room (pass 31)
-- [TX] Training extras (notes/training_extras_done.md): Training lights use a box over the arena + gallery
-- (TrainingConfig.RoomBox, flag RoomFXBox) instead of the 175 sphere, so they stay off at the Showroom (Kit menu) camera.
local TXok, TX = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TrainingConfig", 10)) end)
local function inBox(p, b) return p.X >= b.Min.X and p.X <= b.Max.X and p.Y >= b.Min.Y and p.Y <= b.Max.Y and p.Z >= b.Min.Z and p.Z <= b.Max.Z end
local lights = {}
local function add(h) table.insert(lights, h) end
for _, h in CS:GetTagged("RoomLight") do add(h) end
CS:GetInstanceAddedSignal("RoomLight"):Connect(add)
local spins = {}
local function scan(root) for _, d in root:GetDescendants() do if d:IsA("Model") and d:GetAttribute("Spin") then spins[d] = d:GetPivot() end end end
task.spawn(function() local map = workspace:WaitForChild("LobbyMap", 30); if map then task.wait(2); scan(map); map.DescendantAdded:Connect(function(d) if d:IsA("Model") and d:GetAttribute("Spin") then task.wait(); spins[d] = d:GetPivot() end end) end end)
local t, acc = 0, 0
RS.Heartbeat:Connect(function(dt)
	t += dt; acc += dt
	for m, cf0 in spins do
		if m.Parent then m:PivotTo(CFrame.new(cf0.Position + Vector3.new(0, math.sin(t * 1.3) * 0.15, 0)) * CFrame.Angles(0, math.rad(t * m:GetAttribute("Spin")), 0) * cf0.Rotation) else spins[m] = nil end
	end
	if acc < 0.5 then return end; acc = 0
	local cam = workspace.CurrentCamera; if not cam then return end
	local p = cam.CFrame.Position
	for _, h in lights do
		local c = CENTRES[h:GetAttribute("Room")]
		local on = c ~= nil and (p - c).Magnitude < (ROOM_RADIUS[h:GetAttribute("Room")] or RADIUS)
		if h:GetAttribute("Room") == "Training" and TXok and TX and TX.On("RoomFXBox") then on = inBox(p, TX.RoomBox) end   -- [TX]
		for _, l in h:GetChildren() do if l:IsA("Light") then l.Enabled = on end end
	end
end)
