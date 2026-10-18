-- Spins the lobby helicopter rotors on the client only (visual, no replication cost).
local RunService = game:GetService("RunService")
local heli = workspace:WaitForChild("LobbyMap"):WaitForChild("Heli")
local spinners = {}
local function add(p)
	if p:IsA("BasePart") and p:GetAttribute("SpinAxis") then
		table.insert(spinners, { part = p, base = p.CFrame, axis = p:GetAttribute("SpinAxis"), centre = p:GetAttribute("SpinCenter"), rps = p:GetAttribute("RPS") or 1, a = math.random() * 6.28 })
	end
end
for _, p in heli:GetChildren() do add(p) end
heli.ChildAdded:Connect(add)
RunService.RenderStepped:Connect(function(dt)
	for _, s in spinners do
		s.a = (s.a + dt * s.rps * math.pi * 2) % (math.pi * 2)
		local pivot = CFrame.new(s.centre)
		s.part.CFrame = pivot * CFrame.fromAxisAngle(s.axis, s.a) * pivot:Inverse() * s.base
	end
end)
