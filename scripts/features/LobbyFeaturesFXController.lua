-- Controllers/LobbyFeaturesFXController (client, lobby place): the feature-pass effects that move (notes/features_done.md).
--   * Beacons (tag LF_Beacon): slow aviation-style pulse (smooth on/off, LobbyFeaturesConfig.Beacons.Period, per-beacon Phase).
--     The Neon lens fades between its colour and a dark glass; its PointLight follows.
--   * Vent puffs (tag LF_VentPuff, a ParticleEmitter with Rate 0): a small puff of 3-5 particles every MinGap..MaxGap seconds.
--   * Drop pit return: a short black fade when the server puts you back at the Duels start (player attribute LF_PitReturn).
-- No ambient particles (fix/particles_fix.lua rule): every effect here is bound to a fixture (beacon, vent, pit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local controller = {}

local player = Players.LocalPlayer
local okC, LF = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyFeaturesConfig", 10)) end)
local DARK = Color3.fromRGB(40, 22, 18)

local beacons = {}   -- [Part] = { color, light, phase, period }
local function addBeacon(p)
	if not p:IsA("BasePart") or beacons[p] then return end
	beacons[p] = { color = p.Color, light = p:FindFirstChildWhichIsA("Light"), phase = p:GetAttribute("Phase") or 0,
		period = p:GetAttribute("Period") or (okC and LF.Beacons.Period) or 2.6, bright = (p:FindFirstChildWhichIsA("Light") or {}).Brightness }
end

local function puffLoop(e)
	local lo, hi = (okC and LF.VentPuffs.MinGap) or 6, (okC and LF.VentPuffs.MaxGap) or 12
	task.wait(math.random() * hi)
	while e.Parent and e:IsDescendantOf(workspace) do
		e:Emit(math.random(3, 5))
		task.wait(lo + math.random() * (hi - lo))
	end
end

local function fade()
	local gui = Instance.new("ScreenGui"); gui.Name = "LF_PitFade"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 50; gui.ResetOnSpawn = false
	local f = Instance.new("Frame"); f.Size = UDim2.fromScale(1, 1); f.BackgroundColor3 = Color3.new(0, 0, 0); f.BorderSizePixel = 0; f.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local t = TweenService:Create(f, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	t:Play(); t.Completed:Once(function() gui:Destroy() end)
end

function controller.Start()
	if not okC then return end
	if LF.On("Beacons") then
		for _, p in CollectionService:GetTagged("LF_Beacon") do addBeacon(p) end
		CollectionService:GetInstanceAddedSignal("LF_Beacon"):Connect(addBeacon)
		CollectionService:GetInstanceRemovedSignal("LF_Beacon"):Connect(function(p) beacons[p] = nil end)
		local acc = 0
		RunService.RenderStepped:Connect(function(dt)
			acc += dt
			if acc < 1 / 30 then return end
			acc = 0
			local t = os.clock()
			for p, b in beacons do
				-- 0..1 pulse: quick rise, slow fall, dark half the cycle (aviation obstruction light feel)
				local x = ((t / b.period) + b.phase) % 1
				local a = x < 0.12 and (x / 0.12) or (x < 0.5 and (1 - (x - 0.12) / 0.38) ^ 2 or 0)
				p.Color = DARK:Lerp(b.color, a)
				if b.light then b.light.Brightness = (b.bright or 1) * a end
			end
		end)
	end
	if LF.On("VentPuffs") then
		for _, e in CollectionService:GetTagged("LF_VentPuff") do if e:IsA("ParticleEmitter") then task.spawn(puffLoop, e) end end
		CollectionService:GetInstanceAddedSignal("LF_VentPuff"):Connect(function(e) if e:IsA("ParticleEmitter") then task.spawn(puffLoop, e) end end)
	end
	if LF.On("DropPits") then
		player:GetAttributeChangedSignal("LF_PitReturn"):Connect(fade)
	end
end

return controller
