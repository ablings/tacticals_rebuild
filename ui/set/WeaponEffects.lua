-- StarterPlayer/StarterPlayerScripts/Client/Controllers/WeaponController/WeaponEffects (ModuleScript)
-- Private helper of WeaponController. Purely cosmetic, runs on each client:
--   muzzle flash + light + gun smoke, a bullet streak that travels at bullet speed,
--   surface impacts (sparks, dust in the surface colour, chips, bullet hole, impact sound),
--   a small mist on body hits, and spent casings on reload.
-- Used for your own shots and for other players' shots relayed by the server.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local WeaponUtil = require(game:GetService("ReplicatedStorage").Modules.Shared.WeaponUtil)
local WeaponConfig = require(game:GetService("ReplicatedStorage").Modules.Shared.Config.WeaponConfig)
local ImpactSounds = require(game:GetService("ReplicatedStorage").Modules.Shared.ImpactSounds)
local SoundTrim = require(game:GetService("ReplicatedStorage").Modules.Shared.SoundTrim)

local effects = {}

-- // Tunables
local BULLET_SPEED = 900          -- studs/s for the visible streak
local STREAK_LENGTH = 4
local HOLE_LIFETIME = 20
local MAX_HOLES = 40
local IMPACT_SOUNDS = { "rbxassetid://131554175554758", "rbxassetid://85805517776968", "rbxassetid://78578946566141", "rbxassetid://91269662967532" }
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local holes = {}
local CASING_SOUNDS = { "rbxassetid://9117197553" } -- metal on floor, pitched up = brass
local SPEED_OF_SOUND = 1200 -- studs/s (roughly 340 m/s)
local FLINCH_SOURCE = "HitFlinch"

local function seq(...)
	local pts = {}
	for _, p in { ... } do table.insert(pts, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(pts)
end

local function charactersFilter()
	local list = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(list, p.Character) end end
	return list
end

-- Emit a one-shot burst from a temporary attachment facing `normal`
local function burst(position: Vector3, normal: Vector3, count: number, life: number, setup: (ParticleEmitter) -> ())
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = CFrame.lookAt(position, position + normal)
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	setup(emitter)
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, life)
end

local function playSoundAt(position: Vector3, soundId: string, volume: number, pitch: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 120
	sound.Parent = attachment
	SoundTrim.Play(sound)
	Debris:AddItem(attachment, 3)
end

-- // Muzzle
-- Driven by the gun's blueprint (WeaponConfig …Effects.Muzzle / .GasPuff), so a revolver, a service
-- pistol and a suppressed pistol each fire with their own signature.
local function flashMuzzle(tool: Tool?, effectConfig)
	local muzzle = tool and WeaponUtil.GetMuzzle(tool)
	if not muzzle then return end
	local bp = effectConfig and effectConfig.Muzzle or nil
	local scale = bp and bp.Scale or 1

	local light = muzzle:FindFirstChild("Flash")
	if light and light:IsA("Light") then
		if bp and bp.Light then
			light.Brightness = bp.Light.Brightness
			if light:IsA("PointLight") then light.Range = bp.Light.Range end
		end
		light.Enabled = true
		task.delay(bp and bp.Light and bp.Light.Time or 0.045, function() light.Enabled = false end)
	end
	local function emit(name: string, count: number)
		if count <= 0 then return end
		local e = muzzle:FindFirstChild(name)
		if e and e:IsA("ParticleEmitter") then e:Emit(count) end
	end
	emit("FlashCore", bp and bp.Core or 3)
	emit("FlashSide", bp and bp.Side or 1)
	emit("FlashParticles", bp and bp.Sparks or 6)
	emit("MuzzleSmoke", bp and bp.Smoke or 4)
	-- a thin ring of compressed air snaps out of the muzzle for a frame
	if bp and bp.Ring then
		local fwd = muzzle.WorldCFrame.LookVector
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 235, 200)
		ring.Transparency = 0.55
		ring.Size = Vector3.new(0.02, 0.15, 0.15)
		ring.CFrame = CFrame.lookAt(muzzle.WorldPosition + fwd * 0.5, muzzle.WorldPosition + fwd * 2) * CFrame.Angles(0, math.rad(90), 0)
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.02, 1.4 * scale, 1.4 * scale), Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.12)
	end
	-- revolver: flame jets out of the cylinder gap, perpendicular to the barrel
	if bp and bp.SideJets then
		local cf = muzzle.WorldCFrame
		local gap = cf.Position - cf.LookVector * 0.9 -- back by the cylinder
		for _, side in { cf.RightVector, -cf.RightVector } do
			burst(gap, side, 3, 0.4, function(e)
				e.Texture = SPARK_TEX
				e.Color = ColorSequence.new(Color3.fromRGB(255, 235, 180), Color3.fromRGB(255, 120, 30))
				e.LightEmission = 1
				e.LightInfluence = 0
				e.Size = seq({ 0, 0.3 * scale }, { 1, 0 })
				e.Lifetime = NumberRange.new(0.05, 0.12)
				e.Speed = NumberRange.new(10, 18)
				e.SpreadAngle = Vector2.new(12, 12)
			end)
		end
	end
	-- suppressed: the trapped gas leaks out of the can and hangs in the air
	local gasCount = effectConfig and effectConfig.GasPuff or 0
	if gasCount > 0 then
		local gas = muzzle:FindFirstChild("GasPuff")
		if not gas then
			gas = Instance.new("ParticleEmitter")
			gas.Name = "GasPuff"
			gas.Texture = SMOKE_TEX
			gas.Color = ColorSequence.new(Color3.fromRGB(205, 205, 200))
			gas.LightInfluence = 1
			gas.Size = seq({ 0, 0.15 }, { 1, 1.1 })
			gas.Transparency = seq({ 0, 0.45 }, { 1, 1 })
			gas.Lifetime = NumberRange.new(0.9, 1.5)
			gas.Speed = NumberRange.new(2.5, 4) -- pushed out of the can...
			gas.Drag = 4 -- ...then it just hangs
			gas.SpreadAngle = Vector2.new(8, 8)
			gas.EmissionDirection = Enum.NormalId.Front
			gas.Acceleration = Vector3.new(0, 0.8, 0)
			gas.Rate = 0
			gas.Parent = muzzle
		end
		gas:Emit(gasCount)
	end
	-- a thread of smoke keeps drifting off the barrel for a moment after each shot
	local drift = muzzle:FindFirstChild("BarrelDrift")
	if not drift then
		drift = Instance.new("ParticleEmitter")
		drift.Name = "BarrelDrift"
		drift.Texture = SMOKE_TEX
		drift.Color = ColorSequence.new(Color3.fromRGB(190, 190, 185))
		drift.LightInfluence = 1
		drift.Size = seq({ 0, 0.08 }, { 1, 0.6 })
		drift.Transparency = seq({ 0, 0.6 }, { 1, 1 })
		drift.Lifetime = NumberRange.new(0.7, 1.1)
		drift.Speed = NumberRange.new(0.4, 0.9)
		drift.SpreadAngle = Vector2.new(25, 25)
		drift.Acceleration = Vector3.new(0, 1.4, 0)
		drift.Rate = 0
		drift.Parent = muzzle
	end
	drift.Rate = 14
	local stamp = os.clock()
	muzzle:SetAttribute("DriftStamp", stamp)
	task.delay(0.9, function()
		if muzzle.Parent and muzzle:GetAttribute("DriftStamp") == stamp then drift.Rate = 0 end
	end)
end

function effects.PlaySound(tool: Tool?, soundName: string)
	local handle = tool and tool:FindFirstChild("Handle")
	local template = handle and handle:FindFirstChild(soundName)
	if not template or not template:IsA("Sound") then return end
	local sound = template:Clone()
	sound.PlaybackSpeed = template.PlaybackSpeed * (0.96 + math.random() * 0.08)
	if soundName == "Fire" then
		-- How far the shot carries follows the gun's Loudness (a suppressor shrinks it a lot)
		local config = WeaponConfig.Get(tool and tool:GetAttribute("WeaponId") or "")
		local loudness = config and config.Loudness or 1
		sound.RollOffMaxDistance = template.RollOffMaxDistance * loudness
		sound.RollOffMinDistance = math.min(template.RollOffMinDistance, sound.RollOffMaxDistance * 0.25)
	end
	sound.Parent = handle
	SoundTrim.Play(sound)
	Debris:AddItem(sound, math.max(sound.TimeLength, 2) + 0.5)
end

-- // Bullet streak travelling from the muzzle to the hit point
local function bulletStreak(origin: Vector3, endPos: Vector3, effectConfig)
	local distance = (endPos - origin).Magnitude
	if distance < 1 then return end
	local direction = (endPos - origin) / distance
	local length = math.min(STREAK_LENGTH, distance)

	local streak = Instance.new("Part")
	streak.Name = "BulletStreak"
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.CanTouch = false
	streak.CastShadow = false
	streak.Material = Enum.Material.Neon
	streak.Color = effectConfig.TracerColor
	streak.Transparency = 0.25
	streak.Size = Vector3.new(0.035, 0.035, length)
	local startCF = CFrame.lookAt(origin + direction * (length / 2), origin + direction * length)
	streak.CFrame = startCF
	streak.Parent = workspace

	local travel = math.max(distance - length, 0)
	local duration = math.max(travel / BULLET_SPEED, 0.02)
	TweenService:Create(streak, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = startCF + direction * travel,
	}):Play()
	Debris:AddItem(streak, duration + 0.02)
	return duration
end

-- // Impacts
local function surfaceImpact(position: Vector3, normal: Vector3, surface: BasePart?)
	local surfaceColor = surface and surface.Color or Color3.fromRGB(130, 130, 130)
	local dustColor = surfaceColor:Lerp(Color3.fromRGB(170, 165, 155), 0.5)

	-- Sparks
	burst(position, normal, 10, 0.5, function(e)
		e.Texture = SPARK_TEX
		e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 140, 40))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = seq({ 0, 0.18 }, { 1, 0 })
		e.Lifetime = NumberRange.new(0.08, 0.25)
		e.Speed = NumberRange.new(14, 30)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Drag = 2
	end)
	-- Dust puff in the surface colour
	burst(position, normal, 6, 2, function(e)
		e.Texture = SMOKE_TEX
		e.Color = ColorSequence.new(dustColor)
		e.LightInfluence = 1
		e.Size = seq({ 0, 0.4 }, { 1, 2.2 })
		e.Transparency = seq({ 0, 0.3 }, { 1, 1 })
		e.Lifetime = NumberRange.new(0.6, 1.3)
		e.Speed = NumberRange.new(3, 7)
		e.SpreadAngle = Vector2.new(30, 30)
		e.Drag = 5
		e.Acceleration = Vector3.new(0, 0.8, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
	end)
	-- Chips flying off
	for _ = 1, 3 do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.12, 0.12, 0.12) * (0.6 + math.random() * 0.8)
		chip.Color = surfaceColor
		chip.Material = surface and surface.Material or Enum.Material.Concrete
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CollisionGroup = "Default"
		chip.CFrame = CFrame.new(position + normal * 0.15) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.Parent = workspace
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 12
		chip.AssemblyLinearVelocity = normal * (10 + math.random() * 10) + spread
		Debris:AddItem(chip, 1.5)
	end
	-- Bullet hole (only on solid, anchored geometry so it doesn't float)
	if surface and surface.Anchored then
		local hole = Instance.new("Part")
		hole.Name = "BulletHole"
		hole.Shape = Enum.PartType.Cylinder
		hole.Size = Vector3.new(0.02, 0.22, 0.22)
		hole.Color = surfaceColor:Lerp(Color3.new(0, 0, 0), 0.8)
		hole.Material = Enum.Material.SmoothPlastic
		hole.Anchored = true
		hole.CanCollide = false
		hole.CanQuery = false
		hole.CanTouch = false
		hole.CastShadow = false
		-- cylinder axis is X: point it along the surface normal
		hole.CFrame = CFrame.lookAt(position + normal * 0.01, position + normal * 1) * CFrame.Angles(0, math.rad(90), 0)
		hole.Parent = workspace
		table.insert(holes, hole)
		if #holes > MAX_HOLES then
			local oldest = table.remove(holes, 1)
			if oldest then oldest:Destroy() end
		end
		task.delay(HOLE_LIFETIME - 2, function()
			if hole.Parent then
				TweenService:Create(hole, TweenInfo.new(2), { Transparency = 1 }):Play()
				Debris:AddItem(hole, 2)
			end
		end)
	end
	-- the hit itself: metal clanks, wood thocks, concrete cracks (ImpactSounds decides from the surface)
	local kind = ImpactSounds.Classify(surface)
	ImpactSounds.Play(position, kind)
	-- a flash of light off the impact
	do
		local a = Instance.new("Attachment")
		a.WorldPosition = position + normal * 0.4
		a.Parent = workspace.Terrain
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 200, 130)
		l.Brightness = 3
		l.Range = 7
		l.Parent = a
		TweenService:Create(l, TweenInfo.new(0.12), { Brightness = 0 }):Play()
		Debris:AddItem(a, 0.2)
	end
	-- a thin wisp keeps rising out of the hole for a moment
	burst(position, normal, 3, 2.5, function(e)
		e.Texture = SMOKE_TEX
		e.Color = ColorSequence.new(Color3.fromRGB(150, 148, 145))
		e.LightInfluence = 1
		e.Size = seq({ 0, 0.15 }, { 1, 0.9 })
		e.Transparency = seq({ 0, 0.55 }, { 1, 1 })
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Speed = NumberRange.new(0.6, 1.2)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Rate = 0
	end)
	-- scorch halo round the hole
	if surface and surface.Anchored then
		local halo = Instance.new("Part")
		halo.Name = "BulletScorch"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.015, 0.55, 0.55)
		halo.Color = surfaceColor:Lerp(Color3.new(0, 0, 0), 0.55)
		halo.Material = Enum.Material.SmoothPlastic
		halo.Transparency = 0.55
		halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch, halo.CastShadow = true, false, false, false, false
		halo.CFrame = CFrame.lookAt(position + normal * 0.005, position + normal * 1) * CFrame.Angles(0, math.rad(90), 0)
		halo.Parent = workspace
		task.delay(HOLE_LIFETIME - 2, function()
			if halo.Parent then TweenService:Create(halo, TweenInfo.new(2), { Transparency = 1 }):Play() Debris:AddItem(halo, 2) end
		end)
	end
	-- metal: now and then a ricochet whine
	-- metal: now and then a bright "tink" on top (a glancing ricochet)
	if kind == "Metal" and math.random() < 0.35 then
		task.delay(0.03, function() ImpactSounds.Play(position, "Metal", 0.45, 1.9 + math.random() * 0.5) end)
	end
end

local BODY_HIT_SOUND = "rbxassetid://9117197553"
local function bodyImpact(position: Vector3, normal: Vector3, direction: Vector3?)
	playSoundAt(position, BODY_HIT_SOUND, 0.5, 0.45 + math.random() * 0.1) -- a dull thud
	burst(position, normal, 5, 1.6, function(e)
		e.Texture = SMOKE_TEX
		e.Color = ColorSequence.new(Color3.fromRGB(95, 8, 8))
		e.LightInfluence = 1
		e.Size = seq({ 0, 0.3 }, { 1, 1.6 })
		e.Transparency = seq({ 0, 0.5 }, { 1, 1 })
		e.Lifetime = NumberRange.new(0.6, 1.0)
		e.Speed = NumberRange.new(1, 2.5)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Drag = 4
		e.Acceleration = Vector3.new(0, -3, 0)
	end)
	burst(position, normal, 8, 1, function(e)
		e.Texture = SMOKE_TEX
		e.Color = ColorSequence.new(Color3.fromRGB(120, 10, 10), Color3.fromRGB(70, 5, 5))
		e.LightInfluence = 1
		e.Size = seq({ 0, 0.25 }, { 1, 1.1 })
		e.Transparency = seq({ 0, 0.2 }, { 1, 1 })
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Drag = 6
		e.Acceleration = Vector3.new(0, -8, 0)
	end)
	-- through-and-out: a finer spray carries on out of the far side of the body...
	if direction then
		burst(position + direction * 0.8, direction, 7, 1.2, function(e)
			e.Texture = SMOKE_TEX
			e.Color = ColorSequence.new(Color3.fromRGB(110, 8, 8), Color3.fromRGB(60, 4, 4))
			e.LightInfluence = 1
			e.Size = seq({ 0, 0.2 }, { 1, 1.4 })
			e.Transparency = seq({ 0, 0.35 }, { 1, 1 })
			e.Lifetime = NumberRange.new(0.25, 0.5)
			e.Speed = NumberRange.new(8, 16)
			e.SpreadAngle = Vector2.new(14, 14)
			e.Drag = 5
			e.Acceleration = Vector3.new(0, -10, 0)
		end)
		-- ...and a few droplets arc out and fall
		for _ = 1, 4 do
			local drop = Instance.new("Part")
			drop.Shape = Enum.PartType.Ball
			drop.Size = Vector3.one * (0.05 + math.random() * 0.05)
			drop.Color = Color3.fromRGB(90, 6, 6)
			drop.Material = Enum.Material.SmoothPlastic
			drop.CanCollide, drop.CanQuery, drop.CanTouch, drop.CastShadow = false, false, false, false
			drop.Position = position + direction * 0.4
			drop.Parent = workspace
			local spread = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5) * 8
			drop.AssemblyLinearVelocity = direction * (6 + math.random() * 8) + spread
			Debris:AddItem(drop, 0.9)
		end
	end
end

-- tool may be nil (the shooter's tool hasn't replicated); effects still draw
-- A shot heard from far away: arrives late (speed of sound), loses its highs, longer tail
local function distantShot(tool: Tool?, origin: Vector3)
	local cam = workspace.CurrentCamera
	local dist = (cam.CFrame.Position - origin).Magnitude
	if dist < 60 then return false end
	local handle = tool and tool:FindFirstChild("Handle")
	local template = handle and handle:FindFirstChild("Fire")
	if not template then return false end
	local config = WeaponConfig.Get(tool and tool:GetAttribute("WeaponId") or "")
	local loudness = config and config.Loudness or 1
	if dist > 400 * loudness then return true end -- too far to hear at all
	task.delay(dist / SPEED_OF_SOUND, function()
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = origin
		attachment.Parent = workspace.Terrain
		local sound = template:Clone()
		sound.RollOffMinDistance = 400
		sound.RollOffMaxDistance = 600
		sound.Volume = template.Volume * math.clamp(1 - dist / (450 * loudness), 0.08, 0.6)
		sound.PlaybackSpeed = template.PlaybackSpeed * 0.9
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -20
		eq.MidGain = -6
		eq.LowGain = 2
		eq.Parent = sound
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 2.2
		reverb.WetLevel = -2
		reverb.DryLevel = -6
		reverb.Parent = sound
		sound.Parent = attachment
		SoundTrim.Play(sound)
		Debris:AddItem(attachment, 4)
	end)
	return true
end

-- A character that takes a hit jolts (everyone sees it)
local flinchTracks = setmetatable({}, { __mode = "k" })
local function flinch(position: Vector3)
	local closest, best = nil, 4
	local candidates = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(candidates, p.Character) end end
	for _, b in game:GetService("CollectionService"):GetTagged("Bot") do table.insert(candidates, b) end
	for _, c in candidates do
		local root = c:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude < best then closest, best = c, (root.Position - position).Magnitude end
	end
	local humanoid = closest and closest:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	local track = flinchTracks[animator]
	if not track then
		local src = game:GetService("ReplicatedStorage").Repository.AnimationSources:FindFirstChild(FLINCH_SOURCE)
		if not src then return end
		-- (pass 40) published to the group: use its id; Studio preview otherwise
		local ok, id = true, src:GetAttribute("PublishedId")
		if not id then
			if not game:GetService("RunService"):IsStudio() then return end
			ok, id = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(src) end)
		end
		if not ok then return end
		local a = Instance.new("Animation") a.AnimationId = id
		local ok2, t = pcall(animator.LoadAnimation, animator, a)
		if not ok2 then return end
		t.Priority = Enum.AnimationPriority.Action4
		flinchTracks[animator] = t
		track = t
	end
	track:Play(0.03)
end

-- A bullet through smoke (CS2-style): it drills a tunnel - the smoke along its path is shoved outward
-- in curling wisps and a thin clear channel stays open for a moment (the server thins the cloud there).
local function smokeTunnel(origin: Vector3, endPos: Vector3)
	local cells = game:GetService("CollectionService"):GetTagged("SmokeCloud")
	if #cells == 0 then return end
	local ab = endPos - origin
	local length = ab.Magnitude
	if length < 0.5 then return end
	local dir = ab / length
	-- which stretch of the path is inside smoke
	local inside = {}
	for _, cell in cells do
		local r = cell:GetAttribute("Radius") or 0
		if r > 0.5 then
			local t = math.clamp((cell.Position - origin):Dot(dir), 0, length)
			if (origin + dir * t - cell.Position).Magnitude < r then table.insert(inside, t) end
		end
	end
	if #inside == 0 then return end
	table.sort(inside)
	local first, last = math.max(inside[1] - 2, 0), math.min(inside[#inside] + 2, length)
	local step = 1.6
	local t = first
	while t <= last do
		local p = origin + dir * t
		local attachment = Instance.new("Attachment")
		attachment.WorldCFrame = CFrame.lookAt(p, p + dir)
		attachment.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE_TEX
		e.Rate = 0
		e.LightInfluence = 1
		e.Color = ColorSequence.new(Color3.fromRGB(225, 225, 220))
		e.Size = seq({ 0, 0.6 }, { 1, 2.6 })
		e.Transparency = seq({ 0, 0.35 }, { 0.6, 0.7 }, { 1, 1 })
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(5, 9)        -- shoved out sideways from the bullet's path
		e.Drag = 6
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(180, 0)      -- a ring around the path
		e.RotSpeed = NumberRange.new(-120, 120)  -- curl
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = attachment
		e:Emit(4)
		Debris:AddItem(attachment, 1.2)
		t += step
	end
end

function effects.PlayShot(tool: Tool?, origin: Vector3, endPos: Vector3, hitCharacter: boolean, _normal: Vector3?, effectConfig)
	task.spawn(smokeTunnel, origin, endPos)
	flashMuzzle(tool, effectConfig)
	if not distantShot(tool, origin) then
		effects.PlaySound(tool, "Fire")
	end
	local travelTime = bulletStreak(origin, endPos, effectConfig) or 0

	-- Find what was hit (cosmetic raycast) so impacts work for everyone's shots
	local direction = endPos - origin
	if direction.Magnitude < 0.1 then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = hitCharacter and {} or charactersFilter()
	local result = workspace:Raycast(origin, direction + direction.Unit * 0.5, params)

	task.delay(travelTime, function()
		if hitCharacter then
			bodyImpact(endPos, -direction.Unit, direction.Unit)
			flinch(endPos)
		elseif result then
			surfaceImpact(result.Position, result.Normal, result.Instance :: BasePart)
		end
	end)
end

-- Spent casings fall out when reloading
function effects.DropCasings(tool: Tool?, count: number)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then return end
	for i = 1, count do
		task.delay(i * 0.03, function()
			if not handle.Parent then return end
			local casing = Instance.new("Part")
			casing.Name = "Casing"
			casing.Shape = Enum.PartType.Cylinder
			casing.Size = Vector3.new(0.18, 0.07, 0.07)
			casing.Color = Color3.fromRGB(196, 156, 72)
			casing.Material = Enum.Material.Metal
			casing.Reflectance = 0.2
			casing.CanQuery = false
			casing.CanTouch = false
			casing.CFrame = handle.CFrame * CFrame.new((math.random() - 0.5) * 0.2, 0.3, -0.3)
			casing.Parent = workspace
			local cf = handle.CFrame
			if count == 1 then
				-- flicked out of the ejection port: right and up, tumbling hard
				casing.AssemblyLinearVelocity = cf.RightVector * (4 + math.random() * 3)
					+ cf.UpVector * (4 + math.random() * 2)
					+ cf.LookVector * ((math.random() - 0.5) * 1.5)
			else
				-- a reload dumps the spent cylinder: they just tumble out downward
				casing.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 3, -2, (math.random() - 0.5) * 3)
			end
			casing.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, math.random() * 20)
			Debris:AddItem(casing, 6)
			-- brass tinkling on the floor: once when it lands, a softer second bounce
			for k, delayTime in { 0.32 + math.random() * 0.1, 0.55 + math.random() * 0.15 } do
				task.delay(delayTime, function()
					if casing.Parent then
						playSoundAt(casing.Position, CASING_SOUNDS[math.random(1, #CASING_SOUNDS)], k == 1 and 0.35 or 0.18, 1.6 + math.random() * 0.4)
					end
				end)
			end
		end)
	end
end

return effects
