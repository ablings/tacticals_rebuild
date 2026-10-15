-- Client/Controllers/TrainingTargetsController (client, lobby place): pop effect for the Training bullseyes
-- (notes/training_extras_done.md). Server: TrainingTargetsManager fires Events.Training.TargetPop(position, shooterUserId).
-- Everyone in Training sees a small burst of red / cream shards; the shooter also gets the HUD hitmarker (kill style).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)

local player = Players.LocalPlayer
local controller = {}
local COLOURS = { Color3.fromRGB(196, 40, 40), Color3.fromRGB(236, 232, 218) }

local function burst(pos: Vector3)
	for i = 1, 8 do
		local p = Instance.new("Part"); p.Name = "BullseyeShard"; p.Size = Vector3.new(0.5, 0.5, 0.12)
		p.Color = COLOURS[i % 2 + 1]; p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
		p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, 0)
		p.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		p.AssemblyLinearVelocity = dir * (14 + math.random() * 10)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
		Debris:AddItem(p, 1.2)
	end
end

function controller.Start()
	if not (ok and TX.On("Bullseyes")) then return end
	local ev = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training"):WaitForChild("TargetPop", 30)
	if not ev then return end
	ev.OnClientEvent:Connect(function(pos, shooterId)
		if player:GetAttribute("InTraining") ~= true or typeof(pos) ~= "Vector3" then return end
		burst(pos)
		if shooterId == player.UserId then
			local hud = shared.Get and shared.Get("HUD")
			if hud and hud.ShowHitmarker then hud.ShowHitmarker("Head", true) end
		end
	end)
end

return controller
