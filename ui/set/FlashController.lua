local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/FlashController (ModuleScript)
-- What a flashbang does to YOU. The server says where it went off; this works out what saw it:
--   1. your CHARACTER: a clear line from your head to the flash AND your character is facing it
--      (within GadgetConfig.Flash.FacingAngle)                                   -> Severe
--   2. only your CAMERA: the flash is on screen with a clear line from the camera  -> Camera (moderate)
--   3. neither (behind a wall, behind you, around a corner)                        -> Minimal
-- Strength also scales with distance and how head-on it was.
-- Effects (all tiers, scaled):
--   * whiteout: the screen burns white, then fades through a blown-out, washed-out afterimage
--   * hearing: a high ring, and every other sound muffled (low-passed) and quieter, recovering slowly
--   * stun: slower movement, a drifting/wobbling camera, and you can't aim or peek for a moment
-- Also: Studio test helper controller._Test(tier) plays a tier without a grenade.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Modules.Shared.Config.GadgetConfig).Flash
local Combat = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat")

local localPlayer = Players.LocalPlayer
local Get = shared.Get
local controller = {}

local white: Frame
local cc: ColorCorrectionEffect
local blur: BlurEffect
local ring: Sound
local master: SoundGroup
local eq: EqualizerSoundEffect

-- state, all in os.clock() terms
local blindStart, blindEnd, blindPeak = 0, 0, 0
local ringStart, ringEnd = 0, 0
local stunStart, stunEnd, swayStrength = 0, 0, 0

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearLine(from: Vector3, to: Vector3): boolean
	local ignore = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	for _, b in game:GetService("CollectionService"):GetTagged("Bot") do table.insert(ignore, b) end
	for _, s in game:GetService("CollectionService"):GetTagged("SmokeCloud") do table.insert(ignore, s) end
	mapParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, mapParams)
	return hit == nil or (hit.Position - to).Magnitude < 0.6
end

-- Every sound in the world goes through one SoundGroup so the flash can muffle all of it at once
local function route(sound: Instance)
	if sound:IsA("Sound") and sound ~= ring and sound.SoundGroup == nil then
		sound.SoundGroup = master
	end
end

local function apply(tierName: string, strength: number)
	local tier = Config[tierName]
	local now = os.clock()
	strength = math.clamp(strength, 0.15, 1)
	-- whiteout
	local blind = tier.Blind * strength
	local peak = (tier.Peak or 1) * (tierName == "Severe" and 1 or math.clamp(strength + 0.2, 0, 1))
	if now + blind > blindEnd then
		blindStart, blindEnd, blindPeak = now, now + blind, math.max(peak, now < blindEnd and blindPeak or 0)
	end
	-- hearing
	local ringFor = tier.Ring * math.clamp(strength + 0.3, 0, 1)
	if now + ringFor > ringEnd then ringStart, ringEnd = now, now + ringFor end
	ring.Volume = 0.25 + 0.6 * strength * (tierName == "Severe" and 1 or 0.6)
	ring.TimePosition = 0
	ring:Play()
	-- stun
	local stun = tier.Stun * strength
	if now + stun > stunEnd then stunStart, stunEnd = now, now + stun end
	swayStrength = math.max(swayStrength, tier.Sway * strength)
	localPlayer:SetAttribute("StunUntil", now + stun)
	localPlayer:SetAttribute("StunScale", tier.SpeedScale)
	local Cover = Get("CoverController")
	if Cover and Cover.Suppress then Cover.Suppress(stun * 0.8) end
end

local function onFlash(position: Vector3)
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 then return end
	local cam = workspace.CurrentCamera
	local dist = (position - head.Position).Magnitude
	if dist > Config.MaxRange then return end
	local distFactor = math.clamp(1 - (dist - 6) / (Config.MaxRange - 6), 0, 1) -- full inside 6 studs

	-- 1. the character's eyes
	local toFlash = (position - head.Position).Unit
	local look = head.CFrame.LookVector
	local charAngle = math.deg(math.acos(math.clamp(look:Dot(toFlash), -1, 1)))
	if charAngle <= Config.FacingAngle and clearLine(head.Position, position) then
		local angleFactor = 1 - (charAngle / Config.FacingAngle) * 0.5
		apply("Severe", distFactor * angleFactor)
		return
	end
	-- 2. the camera
	local screen, onScreen = cam:WorldToViewportPoint(position)
	if onScreen and screen.Z > 0 and clearLine(cam.CFrame.Position, position) then
		local viewport = cam.ViewportSize
		local off = (Vector2.new(screen.X, screen.Y) - viewport / 2).Magnitude / (viewport.Magnitude / 2)
		apply("Camera", distFactor * (1 - off * 0.5))
		return
	end
	-- 3. neither
	if dist <= Config.Minimal.Range then
		apply("Minimal", math.clamp(1 - dist / Config.Minimal.Range, 0, 1))
	end
end

local function update()
	local now = os.clock()
	-- whiteout: hold full white for the first ~40%, then fade through a blown-out afterimage
	local b = 0
	if now < blindEnd then
		local t = (now - blindStart) / math.max(blindEnd - blindStart, 0.01)
		b = blindPeak * (t < 0.4 and 1 or (1 - (t - 0.4) / 0.6) ^ 1.6)
	end
	-- [SET] Video > Accessibility > Dark Blinds: the screen goes dark instead of burning white
	local dark = localPlayer:GetAttribute("Setting_DarkBlinds") == true
	white.BackgroundColor3 = dark and Color3.fromRGB(6, 6, 8) or Color3.fromRGB(255, 255, 252)
	white.BackgroundTransparency = 1 - math.clamp(b, 0, 1)
	cc.Brightness = (dark and -0.35 or 0.6) * b
	cc.Contrast = -0.4 * b
	cc.Saturation = -0.9 * b
	blur.Size = 18 * b

	-- hearing: muffled (low-passed and quieter), recovering over the ring time
	local h = 0
	if now < ringEnd then
		h = 1 - (now - ringStart) / math.max(ringEnd - ringStart, 0.01)
	elseif ring.IsPlaying then
		ring:Stop()
	end
	ring.Volume = ring.Volume * 0.995
	eq.HighGain = -45 * h
	eq.MidGain = -18 * h
	eq.LowGain = -4 * h
	master.Volume = 1 - 0.55 * h

	-- stun sway: the camera drifts and wobbles
	if now < stunEnd then
		local s = swayStrength * (1 - (now - stunStart) / math.max(stunEnd - stunStart, 0.01))
		local cam = workspace.CurrentCamera
		local tt = now * 2.3
		if localPlayer:GetAttribute("Setting_CameraShake") == false then s = 0 end -- [SET] Camera Shake
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(math.sin(tt) * 2.2 * s), math.rad(math.cos(tt * 0.8) * 3 * s), math.rad(math.sin(tt * 1.3) * 2 * s))
	else
		swayStrength = 0
	end
end

function controller._Test(tier: string, strength: number?)
	apply(tier, strength or 1)
end

function controller.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlashUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	white = Instance.new("Frame")
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.fromRGB(255, 255, 252)
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FlashColor"
	cc.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "FlashBlur"
	blur.Size = 0
	blur.Parent = Lighting

	master = Instance.new("SoundGroup")
	master.Name = "World"
	master.Parent = SoundService
	eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain, eq.MidGain, eq.LowGain = 0, 0, 0
	eq.Parent = master

	ring = Instance.new("Sound")
	ring.Name = "FlashRing"
	ring.SoundId = Config.RingSound
	ring.PlaybackSpeed = 4.5 -- pitched up into a ring
	ring.Looped = true
	ring.Volume = 0
	ring.Parent = SoundService

	for _, d in workspace:GetDescendants() do route(d) end
	workspace.DescendantAdded:Connect(route)
	for _, d in localPlayer.PlayerGui:GetDescendants() do route(d) end

	Combat:WaitForChild("FlashDetonated").OnClientEvent:Connect(onFlash)
	RunService:BindToRenderStep("FlashEffects", Enum.RenderPriority.Camera.Value + 6, update)
end

return controller
