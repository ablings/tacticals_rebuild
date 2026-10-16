local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/ExplosionController (ModuleScript)
-- What an explosion looks, sounds and feels like on this client (the server does the damage):
-- a white-hot flash, a rolling fireball, a pressure ring along the floor, sparks and embers that rain
-- back down, chunks of barrel flung across the room, a black smoke column, a scorch mark, and a camera
-- kick that's brutal up close and a rumble far away. Also the orange "you're on fire" screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShootableConfig"))
local Combat = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat")

local localPlayer = Players.LocalPlayer
local controller = {}

local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function seq(...)
	local pts = {}
	for _, p in { ... } do table.insert(pts, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(pts)
end
local function colors(...)
	local pts = {}
	for _, p in { ... } do table.insert(pts, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(pts)
end

local function holderAt(position: Vector3): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = workspace
	return p
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

-- // Camera shake ------------------------------------------------------------------------------------------
local shake = { amount = 0, decay = 3 }
local function addShake(amount: number, decay: number?)
	shake.amount = math.max(shake.amount, amount)
	shake.decay = decay or 3
end

-- // Screen: flash + burn ---------------------------------------------------------------------------------------
local flashCC = Instance.new("ColorCorrectionEffect")
flashCC.Name = "ExplosionFlash"
flashCC.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "ExplosionBlur"
blur.Size = 0
blur.Parent = Lighting

local burnGui: ScreenGui? = nil
local function buildBurnGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BurningOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(255, 90, 20)
	f.BackgroundTransparency = 0.82
	f.BorderSizePixel = 0
	f.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Transparency = seq({ 0, 0 }, { 0.5, 0.85 }, { 1, 0 })
	grad.Rotation = 90
	grad.Parent = f
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	burnGui = gui
end

-- // The explosion -----------------------------------------------------------------------------------------------
local function explode(position: Vector3, kind: string)
	local cfg = Config.Explosions[kind] or Config.Explosions.Barrel
	local barrel = kind == "Barrel"
	local scale = barrel and 1 or 0.75
	local h = holderAt(position + Vector3.new(0, 0.8, 0))
	Debris:AddItem(h, 9)

	-- flash of light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Brightness = 18
	light.Range = 60
	light.Shadows = true
	light.Parent = h
	TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0, Range = 30 }):Play()

	-- white-hot core, then a rolling fireball
	emitter(h, {
		Texture = FIRE_TEX, LightEmission = 1, LightInfluence = 0,
		Color = colors({ 0, Color3.fromRGB(255, 255, 235) }, { 0.3, Color3.fromRGB(255, 200, 90) }, { 1, Color3.fromRGB(255, 110, 30) }),
		Size = seq({ 0, 3 * scale }, { 0.3, 10 * scale }, { 1, 13 * scale }),
		Transparency = seq({ 0, 0 }, { 0.6, 0.3 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.18, 0.3), Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
	}):Emit(14)
	emitter(h, {
		Texture = FIRE_TEX, LightEmission = 0.8, LightInfluence = 0.2,
		Color = colors({ 0, Color3.fromRGB(255, 190, 80) }, { 0.35, Color3.fromRGB(240, 90, 20) }, { 0.7, Color3.fromRGB(90, 30, 12) }, { 1, Color3.fromRGB(30, 22, 20) }),
		Size = seq({ 0, 4 * scale }, { 0.4, 11 * scale }, { 1, 15 * scale }),
		Transparency = seq({ 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(10, 22), Drag = 4,
		Acceleration = Vector3.new(0, 9, 0),
		SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
	}):Emit(barrel and 26 or 16)

	-- sparks + embers that arc and fall back down
	emitter(h, {
		Texture = SPARK_TEX, LightEmission = 1, LightInfluence = 0,
		Color = colors({ 0, Color3.fromRGB(255, 240, 200) }, { 1, Color3.fromRGB(255, 120, 30) }),
		Size = seq({ 0, 0.35 }, { 1, 0 }),
		Lifetime = NumberRange.new(0.5, 1.6), Speed = NumberRange.new(35, 85), Drag = 1.2,
		Acceleration = Vector3.new(0, -45, 0), SpreadAngle = Vector2.new(180, 180),
	}):Emit(barrel and 90 or 60)
	emitter(h, {
		Texture = SPARK_TEX, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 150, 50)),
		Size = seq({ 0, 0.18 }, { 1, 0.05 }),
		Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(6, 18), Drag = 0.8,
		Acceleration = Vector3.new(0, -6, 0), SpreadAngle = Vector2.new(180, 180),
	}):Emit(40)

	-- black smoke column, slow and heavy
	local smoke = emitter(h, {
		Texture = SMOKE_TEX, LightInfluence = 1,
		Color = colors({ 0, Color3.fromRGB(60, 50, 45) }, { 1, Color3.fromRGB(25, 24, 24) }),
		Size = seq({ 0, 4 * scale }, { 1, 16 * scale }),
		Transparency = seq({ 0, 0.25 }, { 0.7, 0.55 }, { 1, 1 }),
		Lifetime = NumberRange.new(3.5, 5.5), Speed = NumberRange.new(6, 14), Drag = 1.6,
		Acceleration = Vector3.new(0.5, 4, 0.3), SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
		EmissionDirection = Enum.NormalId.Top,
	})
	smoke:Emit(barrel and 22 or 12)

	-- shockwave: a sphere of compressed air that races out and fades
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Ball
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Material = Enum.Material.ForceField
	wave.Color = Color3.fromRGB(255, 225, 190)
	wave.Transparency = 0.3
	wave.Size = Vector3.one * 1
	wave.Position = position
	wave.Parent = workspace
	TweenService:Create(wave, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * cfg.Radius * 2.6, Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.45)

	-- pressure ring along the floor
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Glass
	ring.Color = Color3.fromRGB(255, 220, 180)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position.X, position.Y - 1.2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, cfg.Radius * 3, cfg.Radius * 3), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
	-- floor dust kicked outward
	emitter(h, {
		Texture = SMOKE_TEX, LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(150, 140, 130)),
		Size = seq({ 0, 1.5 }, { 1, 6 }), Transparency = seq({ 0, 0.4 }, { 1, 1 }),
		Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(30, 45), Drag = 5,
		SpreadAngle = Vector2.new(0, 180), EmissionDirection = Enum.NormalId.Right,
	}):Emit(30)

	-- scorch mark
	local floorHit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0))
	if floorHit then
		local scorch = Instance.new("Part")
		scorch.Shape = Enum.PartType.Cylinder
		scorch.Anchored, scorch.CanCollide, scorch.CanQuery, scorch.CanTouch, scorch.CastShadow = true, false, false, false, false
		scorch.Material = Enum.Material.Slate
		scorch.Color = Color3.fromRGB(14, 12, 11)
		scorch.Transparency = 0.15
		scorch.Size = Vector3.new(0.04, cfg.Radius * 0.9, cfg.Radius * 0.9)
		scorch.CFrame = CFrame.new(floorHit.Position + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, math.random() * 6, math.rad(90))
		scorch.Parent = workspace
		task.delay(40, function()
			TweenService:Create(scorch, TweenInfo.new(3), { Transparency = 1 }):Play()
			Debris:AddItem(scorch, 3.5)
		end)
	end

	-- chunks of the barrel / grenade flung across the room, some still burning
	for i = 1, (barrel and 9 or 4) do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(0.2 + math.random() * 0.5, 0.1, 0.3 + math.random() * 0.8)
		chunk.Material = Enum.Material.CorrodedMetal
		chunk.Color = barrel and Color3.fromRGB(120, 25, 18) or Color3.fromRGB(60, 70, 55)
		chunk.CanQuery, chunk.CanTouch = false, false
		chunk.CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, 0.4 + math.random() * 0.8, math.random() - 0.5).Unit
		chunk.AssemblyLinearVelocity = dir * (35 + math.random() * 35)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 40
		if barrel and i <= 4 then
			local a = Instance.new("Attachment") a.Parent = chunk
			emitter(a, {
				Texture = FIRE_TEX, LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(255, 140, 40)),
				Size = seq({ 0, 0.8 }, { 1, 0 }), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0, 1),
				Rate = 40,
			})
		end
		Debris:AddItem(chunk, 6)
	end

	-- sound: the boom (a heavy, pitched-down gunshot under Roblox's blast) + debris rattle
	local boomSrc = ReplicatedStorage.Repository.Weapons:FindFirstChild("Revolver")
	boomSrc = boomSrc and boomSrc:FindFirstChild("Handle") and boomSrc.Handle:FindFirstChild("Fire")
	for _, speed in { 0.32, 0.5 } do
		if boomSrc then
			local s = boomSrc:Clone()
			s.PlaybackSpeed = speed
			s.Volume = 2.5
			-- proximity: deafening up close, a distant thud across the arena, silent beyond
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 16
			s.RollOffMaxDistance = 240
			s:SetAttribute("Proximity", true)
			local reverb = Instance.new("ReverbSoundEffect")
			reverb.DecayTime = 3.5
			reverb.WetLevel = 0
			reverb.Parent = s
			s.Parent = h
			s:Play()
		end
	end
	local blast = Instance.new("Explosion")
	blast.BlastPressure = 0
	blast.BlastRadius = 0
	blast.DestroyJointRadiusPercent = 0
	blast.Visible = false
	blast.Position = position
	blast.Parent = workspace

	-- how it hits YOU: shake, flash, ringing blur - all by distance
	local camera = workspace.CurrentCamera
	local dist = (camera.CFrame.Position - position).Magnitude
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then dist = math.min(dist, (root.Position - position).Magnitude) end
	local t = math.clamp(1 - dist / (cfg.ShakeRange or 70), 0, 1)
	if t > 0 then
		addShake((cfg.Shake or 1) * (0.25 + 1.6 * t * t), 2.2)
		local onScreen = camera.CFrame.LookVector:Dot((position - camera.CFrame.Position).Unit) > 0.3
		local bright = (onScreen and 0.55 or 0.2) * t
		flashCC.Brightness = bright
		flashCC.TintColor = Color3.fromRGB(255, 230, 200)
		TweenService:Create(flashCC, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		if dist < 18 then
			blur.Size = 14 * (1 - dist / 18)
			TweenService:Create(blur, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Size = 0 }):Play()
		end
	end
end

function controller.Start()
	buildBurnGui()
	Combat:WaitForChild("Explosion").OnClientEvent:Connect(explode)
	RunService:BindToRenderStep("ExplosionShake", Enum.RenderPriority.Camera.Value + 6, function(dt)
		if shake.amount > 0.002 then
			local a = shake.amount
			local camera = workspace.CurrentCamera
			local tm = os.clock() * 38
			camera.CFrame *= CFrame.Angles(
				math.rad(math.noise(tm, 1.3) * 3.2 * a),
				math.rad(math.noise(tm, 7.1) * 3.2 * a),
				math.rad(math.noise(tm, 3.7) * 2.0 * a)
			) + Vector3.new(math.noise(tm, 9.9), math.noise(tm, 4.4), 0) * 0.25 * a
			shake.amount = math.max(0, a - a * shake.decay * dt - 0.05 * dt)
		end
		-- on fire?
		local character = localPlayer.Character
		local burning = character and character:GetAttribute("Burning") == true
		if burnGui then
			burnGui.Enabled = burning
			if burning then
				burnGui.Frame.BackgroundTransparency = 0.78 + math.sin(os.clock() * 13) * 0.05
			end
		end
	end)
end

return controller
