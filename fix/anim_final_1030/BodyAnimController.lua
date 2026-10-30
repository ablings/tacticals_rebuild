local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/BodyAnimController (ModuleScript) [ANIMFINAL] (2026-10-30, systems
-- session; installed by fix/anim_final_1030.lua, source fix/anim_final_1030/BodyAnimController.lua)
-- The final body animation layer. Every number is in ReplicatedStorage.Modules.Shared.Config.AnimFinalConfig; every clip is
-- looked up by name (AnimLib), so a clip nobody has made yet just doesn't play.
--   YOUR BODY (your client plays the tracks; Roblox replicates them to everyone):
--     * walk / run / strafe / backpedal blended by your velocity relative to where the body faces; sprint (gun low)
--     * start, stop and turn-in-place one-shots; a hard landing above a fall speed; a low-health limp
--     * DiveAim while aiming in the airborne part of a dive; idle fidgets after N seconds still
--     * RoundReady / Victory / Defeat at the match beats; DoorOpen (a door prompt, or controller.DoorOpen())
--     * explosion stagger and burning (hit flinches / the headshot snap: WeaponEffects; deaths: the server, DeathAnims)
--   BOTS: stagger and burning are played by every client locally (a bot's body belongs to the server).
--   EVERY BODY (each client draws it; Transform changes never replicate, so every client computes the same thing):
--     * procedural breathing: a Sine chest and shoulder rise, deeper and faster when out of breath (your stamina; for
--       others their replicated speed: sprints and bursts), settling in Breath.SettleTime
--     * a quiet out-of-breath sound (Breath.SoundId; heard within SoundMaxDistance; no AI noise event)
--   YOUR CAMERA: a slight aim sway scaled by breath (a post-process undone each frame; never while dead).
-- API: controller.Exertion(character?) -> 0..1, controller.BreathSway() -> degrees, controller.DoorOpen(), controller.PlayOneShot(logical)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RawRunService = RunService
RunService = __TG.RunService
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local AnimLib = require(Shared:WaitForChild("AnimLib"))
local AF = AnimLib.Config
local L, B, H, LF = AF.Loco, AF.Breath, AF.Hits, AF.Life

local Get = shared.Get
local localPlayer = Players.LocalPlayer
local controller = {}

-- // own body state
local character: Model?, humanoid: Humanoid?, root: BasePart?, animator: Animator?
local ready = false
local loco = {} -- [logical] = { track, w } for the blended loops
local LOOPS = { "WalkF", "AimF", "WalkB", "WalkL", "WalkR", "Sprint", "SprintPistol", "Limp" }
local wasMoving, movingSince, stoppedSince, lastSpeed, fastSince = false, 0, 0, 0, 0
local yawHistory = {} -- { t, yaw }
local fallSpeed = 0
local stillSince = os.clock()
local nextFidgetAt = math.huge
local fidgetTrack: AnimationTrack? = nil
local diveTrack: AnimationTrack? = nil
local oneShot: AnimationTrack? = nil
local burnTracks = {} -- [Model] = AnimationTrack (own body + bots)
local lastBeat = nil

local function enabled(): boolean
	return AF.Enabled ~= false
end

local function alive(): boolean
	return humanoid ~= nil and humanoid.Health > 0 and character ~= nil and character.Parent ~= nil
end

local function ctl(name: string)
	local ok, c = pcall(Get, name)
	return ok and c or nil
end

local function stopLoops(fade: number?)
	for _, e in loco do
		if e.track and e.track.IsPlaying then e.track:Stop(fade or 0.2) end
		e.w = 0
	end
end

local function playOne(logical: string, priority: Enum.AnimationPriority?, fade: number?): AnimationTrack?
	if not enabled() or not animator then return nil end
	local t = AnimLib.LoadClip(animator, logical, priority or Enum.AnimationPriority.Action, false)
	if t then t:Play(fade or 0.1) end
	return t
end

function controller.PlayOneShot(logical: string): boolean
	local t = playOne(logical, Enum.AnimationPriority.Action)
	if t then oneShot = t end
	return t ~= nil
end

function controller.DoorOpen()
	if alive() then controller.PlayOneShot("DoorOpen") end
end

local function loadLoops()
	loco = {}
	for _, logical in LOOPS do
		local t = AnimLib.LoadClip(animator, logical, L.Priority, true)
		if t then loco[logical] = { track = t, w = 0 } end
	end
end

-- // locomotion -----------------------------------------------------------------------------------------------------------
local function locoBlocked(): boolean
	if not L.Enabled or not alive() or not root then return true end
	local Cover = ctl("CoverController")
	if Cover and ((L.OffWhileInCover and Cover.IsInCover and Cover.IsInCover()) or (Cover.IsMoving and Cover.IsMoving())) then return true end
	local Move = ctl("MovementController")
	if Move and ((Move.IsSliding and Move.IsSliding()) or (Move.IsCrouched and Move.IsCrouched())) then return true end
	local st = (humanoid :: Humanoid):GetState()
	if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Climbing
		or st == Enum.HumanoidStateType.Swimming or st == Enum.HumanoidStateType.Seated or st == Enum.HumanoidStateType.Dead then
		return true
	end
	if (humanoid :: Humanoid).Sit or (root :: BasePart).Anchored then return true end
	return false
end

local function setW(logical: string, target: number, dt: number, speed: number)
	local e = loco[logical]
	if not e then return end
	e.w += (target - e.w) * math.min(1, dt * L.BlendRate)
	if target <= 0 and e.w < 0.02 then
		e.w = 0
		if e.track.IsPlaying then e.track:Stop(0.15) end
		return
	end
	if not e.track.IsPlaying then e.track:Play(0.15, math.max(e.w, 0.01)) end
	e.track:AdjustWeight(math.max(e.w, 0.01), 0.05)
	e.track:AdjustSpeed(speed)
end

local function updateLoco(dt: number)
	if not loco.WalkF then return end -- no walk clip yet: Roblox's walk stays
	if locoBlocked() then
		stopLoops(0.15)
		wasMoving = false
		return
	end
	local r = root :: BasePart
	local v = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local speed = v.Magnitude
	local now = os.clock()
	local moving = speed > L.MinMoveSpeed
	-- start / stop one-shots
	if moving and not wasMoving then
		movingSince = now
		if now - stoppedSince > 0.3 then playOne("Start", L.Priority, 0.1) end
	elseif not moving and wasMoving then
		stoppedSince = now
		if lastSpeed >= L.StopMinSpeed or now - fastSince < 0.25 then playOne("Stop", L.Priority, 0.1) end
	end
	if speed >= L.StopMinSpeed then fastSince = now end
	wasMoving, lastSpeed = moving, speed
	if not moving then
		for _, logical in LOOPS do setW(logical, 0, dt, 1) end
		-- turn in place: the body turned TurnInPlaceAngle within TurnWindow while standing
		local look = r.CFrame.LookVector
		local yaw = math.deg(math.atan2(-look.X, -look.Z))
		table.insert(yawHistory, { now, yaw })
		while #yawHistory > 0 and now - yawHistory[1][1] > L.TurnWindow do table.remove(yawHistory, 1) end
		local d = (yaw - yawHistory[1][2] + 540) % 360 - 180
		if math.abs(d) >= L.TurnInPlaceAngle then
			yawHistory = {}
			playOne(d > 0 and "TurnL" or "TurnR", L.Priority, 0.1)
		end
		return
	end
	yawHistory = {}
	local rel = r.CFrame:VectorToObjectSpace(v)
	local fwd, right = -rel.Z / speed, rel.X / speed
	local wF, wB, wR, wL = math.max(fwd, 0), math.max(-fwd, 0), math.max(right, 0), math.max(-right, 0)
	local sum = wF + wB + wR + wL
	if sum > 0 then wF, wB, wR, wL = wF / sum, wB / sum, wR / sum, wL / sum end
	-- a missing side / back clip: that share goes to the walk (backwards for the back)
	local backSign = 1
	if not loco.WalkB then wF += wB; wB = 0; if fwd < 0 then backSign = -1 end end
	if not loco.WalkR then wF += wR; wR = 0 end
	if not loco.WalkL then wF += wL; wL = 0 end
	local Move = ctl("MovementController")
	local sprinting = Move and Move.IsSprinting and Move.IsSprinting() and speed >= L.SprintSpeed and fwd > 0.5
	local limp = loco.Limp and (humanoid :: Humanoid).Health <= L.LimpHealth and not sprinting
	local Cam = ctl("CameraController")
	local aimed = loco.AimF and Cam and Cam.IsAiming and Cam.IsAiming()
	-- sprint: the one-handed set for pistols / revolvers (the held gun's prefix)
	local sprintName = "Sprint"
	local tool = character and character:FindFirstChildOfClass("Tool")
	local prefix = tool and tool:GetAttribute("WeaponId") and AF.GunPrefixes[tool:GetAttribute("WeaponId")] or (tool and tool:GetAttribute("WeaponId") and AF.GunFallbackPrefix)
	if (prefix == "Pistol" or prefix == "Revolver") and loco.SprintPistol then sprintName = "SprintPistol" end
	local sprintW = (sprinting and loco[sprintName]) and 1 or 0
	local keep = 1 - sprintW
	local limpW = limp and L.LimpWeight or 0
	local A = L.Authored
	local function sc(name) return speed / (A[name] or 10) end
	local fName = aimed and "AimF" or "WalkF"
	setW("WalkF", fName == "WalkF" and wF * keep * (1 - limpW) or 0, dt, sc("WalkF") * backSign)
	setW("AimF", fName == "AimF" and wF * keep * (1 - limpW) or 0, dt, sc("AimF") * backSign)
	setW("WalkB", wB * keep * (1 - limpW), dt, sc("WalkB"))
	setW("WalkR", wR * keep * (1 - limpW), dt, sc("WalkR"))
	setW("WalkL", wL * keep * (1 - limpW), dt, sc("WalkL"))
	setW("Sprint", sprintName == "Sprint" and sprintW or 0, dt, sc("Sprint"))
	setW("SprintPistol", sprintName == "SprintPistol" and sprintW or 0, dt, sc("SprintPistol"))
	setW("Limp", limpW * keep, dt, sc("Limp"))
end

-- // idle fidgets, dive aim, beats ------------------------------------------------------------------------------------------
local function scheduleFidget(first: boolean)
	local r = LF.FidgetEvery
	nextFidgetAt = os.clock() + (first and LF.FidgetAfter or (r[1] + math.random() * (r[2] - r[1])))
end

local function stopFidget()
	if fidgetTrack and fidgetTrack.IsPlaying then fidgetTrack:Stop(0.2) end
	fidgetTrack = nil
end

local function updateLife()
	local now = os.clock()
	local Cam = ctl("CameraController")
	local aiming = Cam and Cam.IsAiming and Cam.IsAiming()
	local Cover = ctl("CoverController")
	local moving = root and (root :: BasePart).AssemblyLinearVelocity.Magnitude > L.MinMoveSpeed
	local still = alive() and not moving and not aiming and not (Cover and Cover.IsInCover and Cover.IsInCover())
	if not still then
		stillSince = now
		stopFidget()
		scheduleFidget(true)
	elseif now >= nextFidgetAt and not (fidgetTrack and fidgetTrack.IsPlaying) then
		local list = AnimLib.All(AF.Clips.Fidgets)
		if #list > 0 and animator then
			local pickName = list[math.random(1, #list)]
			fidgetTrack = AnimLib.Load(animator, pickName, Enum.AnimationPriority.Action, false)
			if fidgetTrack then fidgetTrack:Play(0.25) controller._lastFidget = pickName .. "@" .. math.floor(now - stillSince + 0.5) end
		end
		scheduleFidget(false)
	end
	-- DiveAim: aiming in the airborne part of a dive
	if LF.DiveAim and animator then
		local diving = alive() and Cover and Cover.IsDiving and Cover.IsDiving() and aiming
		if diving then
			diveTrack = diveTrack or AnimLib.LoadClip(animator, "DiveAim", Enum.AnimationPriority.Action3, true)
			if diveTrack and not diveTrack.IsPlaying then diveTrack:Play(0.08) end
		elseif diveTrack and diveTrack.IsPlaying then
			diveTrack:Stop(0.12)
		end
	end
end

local function stateObj(): Instance
	local obj = ReplicatedStorage
	pcall(function()
		local MS = require(Shared:FindFirstChild("MatchState"))
		obj = MS.For(localPlayer) or ReplicatedStorage
	end)
	return obj
end

local function onBeat()
	if not LF.BeatClips or not alive() then return end
	local s = stateObj()
	local st = s:GetAttribute("MatchState")
	if st == lastBeat then return end
	lastBeat = st
	if st == "Countdown" then
		controller.PlayOneShot("RoundReady")
	elseif st == "Victory" then
		local won = s:GetAttribute("WinnerTeam") ~= nil and s:GetAttribute("WinnerTeam") == localPlayer:GetAttribute("Team")
		controller.PlayOneShot(won and "Victory" or "Defeat")
	end
end

-- // reactions: explosion stagger and burning (own body + bots; other players play their own) -----------------------------
local reactConns = {} -- [Model] = { connections }
local lastHealth = {} -- [Model] = number
local function unbindReact(model: Model)
	for _, c in reactConns[model] or {} do c:Disconnect() end
	reactConns[model] = nil
	lastHealth[model] = nil
	local bt = burnTracks[model]
	if bt and bt.IsPlaying then bt:Stop(0.2) end
	burnTracks[model] = nil
end

local function bindReact(model: Model)
	if reactConns[model] or not H.Enabled then return end
	local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if not hum or not model.Parent then return end
	local conns = {}
	reactConns[model] = conns
	lastHealth[model] = hum.Health
	table.insert(conns, hum.HealthChanged:Connect(function(hp)
		local before = lastHealth[model] or hp
		lastHealth[model] = hp
		if not enabled() or hp <= 0 or hp >= before then return end
		local kind = hum:GetAttribute("LastAttackKind")
		if kind and H.StaggerKinds[kind] and before - hp >= H.StaggerMinDamage then
			local t = AnimLib.LoadClip(hum:FindFirstChildOfClass("Animator"), "Stagger", Enum.AnimationPriority.Action4, false)
			if t then t:Play(0.05) end
		end
	end))
	local function burn()
		local on = enabled() and model:GetAttribute("Burning") == true and hum.Health > 0
		local t = burnTracks[model]
		if on then
			t = t or AnimLib.LoadClip(hum:FindFirstChildOfClass("Animator"), "Burning", Enum.AnimationPriority.Action2, true)
			burnTracks[model] = t
			if t and not t.IsPlaying then t:Play(0.15, H.BurnWeight) end
		elseif t and t.IsPlaying then
			t:Stop(0.25)
		end
	end
	table.insert(conns, model:GetAttributeChangedSignal("Burning"):Connect(burn))
	table.insert(conns, hum.Died:Connect(burn))
	table.insert(conns, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then unbindReact(model) end
	end))
	burn()
end

-- // breathing (every body) ------------------------------------------------------------------------------------------------
local bodies = {} -- [Model] = { e, phase, lastPos, burstAt, sound }
local myExertion = 0

local function exertionOf(model: Model): number
	local b = bodies[model]
	return b and b.e or 0
end
function controller.Exertion(model: Model?): number
	if model == nil or model == character then return myExertion end
	return exertionOf(model)
end

local function jointOf(part: Instance?, name: string): Instance?
	local j = part and part:FindFirstChild(name)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
	return nil
end

local function breathe(model: Model, b, dt: number, layerOn: boolean)
	local e = b.e
	local rate = B.CalmRate + (B.HeavyRate - B.CalmRate) * e
	b.phase = (b.phase + dt * rate * math.pi * 2) % (math.pi * 2)
	local s = (math.sin(b.phase) + 1) * 0.5
	local k = layerOn and B.ProceduralWithLayer or 1
	local chest = math.rad((B.CalmChest + (B.HeavyChest - B.CalmChest) * e) * s * k)
	local rise = (B.CalmShoulder + (B.HeavyShoulder - B.CalmShoulder) * e) * s * k
	local waist = jointOf(model:FindFirstChild("UpperTorso"), "Waist")
	if waist then (waist :: any).Transform = (waist :: any).Transform * CFrame.Angles(chest, 0, 0) end
	for _, side in { "Left", "Right" } do
		local sh = jointOf(model:FindFirstChild(side .. "UpperArm"), side .. "Shoulder")
		if sh then (sh :: any).Transform = CFrame.new(0, rise, 0) * (sh :: any).Transform end
	end
end

local breathLayer: AnimationTrack? = nil
local function updateSound(model: Model, b)
	if B.SoundId == "" then return end
	local head = model:FindFirstChild("Head")
	if not head then return end
	if not b.sound or b.sound.Parent ~= head then
		local snd = Instance.new("Sound")
		snd.Name = "AnimFinalBreath"
		snd.SoundId = B.SoundId
		snd.Looped = true
		snd.Volume = 0
		snd.RollOffMode = Enum.RollOffMode.Linear
		snd.RollOffMinDistance = 2
		snd.RollOffMaxDistance = B.SoundMaxDistance
		snd.Parent = head
		b.sound = snd
	end
	local snd = b.sound
	local vol = b.e > B.SoundFrom and B.SoundVolume * (b.e - B.SoundFrom) / (1 - B.SoundFrom) or 0
	if vol > 0.001 then
		if not snd.IsPlaying then snd:Play() end
		snd.Volume = vol
	elseif snd.IsPlaying then
		snd.Volume = 0
		snd:Stop() -- a looped Sound faded to 0 keeps playing: stop it
	end
end

local function bodyList(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(list, p.Character) end
	end
	for _, m in CollectionService:GetTagged("Bot") do
		if m:IsA("Model") and m.Parent then table.insert(list, m) end
	end
	return list
end

local function updateBreath(dt: number)
	if not B.Enabled or not enabled() then return end
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	-- own exertion from stamina, plus bursts
	local Move = ctl("MovementController")
	if character and Move and Move.GetStamina then
		local deficit = 1 - math.clamp(Move.GetStamina() / B.StaminaFull, 0, 1)
		myExertion = math.max(myExertion - dt / B.SettleTime, deficit, 0)
		local Cover = ctl("CoverController")
		local burst = (Cover and Cover.IsMoving and Cover.IsMoving()) or (Move.IsSliding and Move.IsSliding())
		if burst and not controller._burst then myExertion = math.min(1, myExertion + B.ExertGainBurst) end
		controller._burst = burst
	end
	-- drop gone bodies
	for model, b in bodies do
		if not model.Parent then
			if b.sound then b.sound:Destroy() end
			bodies[model] = nil
		end
	end
	local list = bodyList()
	table.sort(list, function(a, c)
		local ra, rc = a:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("HumanoidRootPart")
		local da = ra and (ra.Position - camPos).Magnitude or math.huge
		local dc = rc and (rc.Position - camPos).Magnitude or math.huge
		return da < dc
	end)
	for i, model in list do
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not r or not hum or hum.Health <= 0 then continue end
		local b = bodies[model]
		if not b then
			b = { e = 0, phase = math.random() * math.pi * 2 }
			bodies[model] = b
		end
		if model == character then
			b.e = myExertion
		else
			local flat = (r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			b.e = math.max(0, b.e - dt / B.SettleTime)
			if flat > B.SprintSpeed then b.e = math.min(1, b.e + B.ExertGainSprint * dt * 2) end
			if flat > B.BurstSpeed and os.clock() - (b.burstAt or 0) > 1 then
				b.burstAt = os.clock()
				b.e = math.min(1, b.e + B.ExertGainBurst)
			end
		end
		if i <= B.MaxBodies and (r.Position - camPos).Magnitude <= B.MaxDistance then
			breathe(model, b, dt, model == character and breathLayer ~= nil and breathLayer.IsPlaying)
		end
		updateSound(model, b)
	end
	-- the animator's BreatheCalm / BreatheHeavy layer on your own body (replicates): unarmed only (a weapon Hold keys the torso,
	-- the code breath above covers it), crossfading to Heavy when out of breath
	if animator and alive() then
		local unarmed = character ~= nil and character:FindFirstChildOfClass("Tool") == nil
		local calm = AnimLib.LoadClip(animator, "Breathing", B.LayerPriority or Enum.AnimationPriority.Idle, true)
		local heavy = AnimLib.LoadClip(animator, "BreathingHeavy", B.LayerPriority or Enum.AnimationPriority.Idle, true)
		local want = nil
		if unarmed then want = (myExertion > 0.5 and heavy) or calm end
		for _, t in { calm, heavy } do
			if t and t ~= want and t.IsPlaying then t:Stop(0.4) end
		end
		breathLayer = want
		if want then
			local w = B.LayerWeightCalm + (B.LayerWeightHeavy - B.LayerWeightCalm) * myExertion
			if not want.IsPlaying then want:Play(0.4, w) end
			want:AdjustWeight(w, 0.2)
		end
	end
end

-- the sprint exertion the stamina doesn't show (stamina only falls while sprinting): nothing extra; a climb is a burst
function controller.OnClimb()
	myExertion = math.min(1, myExertion + B.ExertGainBurst)
end

-- // aim sway (camera post-process, undone at the start of every frame) -------------------------------------------------
local swayApplied: CFrame? = nil
local swayT = 0
function controller.BreathSway(): number
	return B.SwayCalm + (B.SwayDegrees - B.SwayCalm) * myExertion
end
local function swayUndo()
	if swayApplied then
		local cam = workspace.CurrentCamera
		if cam then cam.CFrame = cam.CFrame * swayApplied:Inverse() end
		swayApplied = nil
	end
end
local function swayApply(dt: number)
	swayApplied = nil
	if not B.Enabled or not enabled() or not alive() then return end
	local Cam = ctl("CameraController")
	if not (Cam and Cam.IsAiming and Cam.IsAiming()) then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local deg = controller.BreathSway()
	if deg <= 0 then return end
	local rate = B.CalmRate + (B.HeavyRate - B.CalmRate) * myExertion
	swayT += dt * rate * math.pi * 2
	local off = CFrame.Angles(math.rad(deg * math.sin(swayT)), math.rad(deg * 0.6 * math.sin(swayT * 0.5 + 1.3)), 0)
	cam.CFrame = cam.CFrame * off
	swayApplied = off
end

-- // melee items: Equip + Hold while out (bat / katana / shield), the bat's charge, the shield's hits; the medkit stop ----------
local meleeConns = {}
local meleeTracks = {} -- logical -> track (current item)
local function meleeSet(tool: Instance?)
	local id = tool and tool:GetAttribute("MeleeId")
	return id and AF.Melee[id] or nil
end
local function meleeLoad(set, logical: string, priority, looped): AnimationTrack?
	if not set or not set[logical] or not animator then return nil end
	return AnimLib.Load(animator, AnimLib.First(set[logical]), priority, looped)
end
local function clearMelee()
	for _, c in meleeConns do c:Disconnect() end
	meleeConns = {}
	for _, t in meleeTracks do if t.IsPlaying then t:Stop(0.15) end end
	meleeTracks = {}
end
local function bindMelee(tool: Tool)
	clearMelee()
	local set = meleeSet(tool)
	if not set or not enabled() then return end
	local equipT = meleeLoad(set, "Equip", Enum.AnimationPriority.Action2, false)
	local holdT = meleeLoad(set, "Hold", Enum.AnimationPriority.Action, true)
	meleeTracks.Equip, meleeTracks.Hold = equipT, holdT
	if equipT then equipT:Play(0.05) end
	if holdT then holdT:Play(0.15) end
	-- the shield: a hit jolts it, breaking tears it off
	local lastHp = tool:GetAttribute("ShieldHealth")
	table.insert(meleeConns, tool:GetAttributeChangedSignal("ShieldHealth"):Connect(function()
		local hp = tool:GetAttribute("ShieldHealth")
		if type(hp) == "number" and type(lastHp) == "number" and hp < lastHp then
			local t = meleeLoad(set, "Impact", Enum.AnimationPriority.Action3, false)
			if t then t:Play(0) end
		end
		lastHp = hp
	end))
	table.insert(meleeConns, tool:GetAttributeChangedSignal("ShieldBroken"):Connect(function()
		if tool:GetAttribute("ShieldBroken") == true then
			if holdT and holdT.IsPlaying then holdT:Stop(0.1) end
			local t = meleeLoad(set, "Break", Enum.AnimationPriority.Action4, false)
			if t then t:Play(0.05) end
		end
	end))
end
local function onChargeChanged()
	local tool = character and character:FindFirstChildOfClass("Tool")
	local set = meleeSet(tool)
	local charging = localPlayer:GetAttribute("MeleeChargeStart") ~= nil
	local wind = meleeLoad(set, "Windup", Enum.AnimationPriority.Action3, false)
	local hold = meleeLoad(set, "ChargeHold", Enum.AnimationPriority.Action3, true)
	if charging and enabled() then
		if wind then
			wind:Play(0.05)
			local myWind = wind
			task.delay(math.max(wind.Length - 0.05, 0), function()
				if localPlayer:GetAttribute("MeleeChargeStart") ~= nil and hold and myWind.IsPlaying ~= nil then hold:Play(0.1) end
			end)
		elseif hold then
			hold:Play(0.1)
		end
	else
		if wind and wind.IsPlaying then wind:Stop(0.05) end
		if hold and hold.IsPlaying then hold:Stop(0.05) end
	end
end
local function onMedkitChanged()
	if localPlayer:GetAttribute("MedkitUntil") ~= nil or not animator then return end
	-- the channel ended (healed, or damage stopped it): the clip stops too
	local name = AnimLib.First(AF.Gadgets.Medkit and AF.Gadgets.Medkit.Use)
	local t = name and AnimLib.Load(animator, name)
	if t and t.IsPlaying then t:Stop(0.1) end
end

-- // own character binding ------------------------------------------------------------------------------------------------
local function bindCharacter(newCharacter: Model)
	stopLoops(0)
	stopFidget()
	clearMelee()
	character, humanoid, root, animator, ready = newCharacter, nil, nil, nil, false
	breathLayer, diveTrack, oneShot = nil, nil, nil
	myExertion = 0
	lastBeat = nil
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	if character ~= newCharacter or not humanoid then return end
	root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	-- the server rebuilds the body after a spawn (PlayerRegistry, character attribute Ready): load after that
	local waited = 0
	while newCharacter:GetAttribute("Ready") ~= true and waited < 6 and character == newCharacter do
		waited += task.wait(0.1)
	end
	task.wait()
	if character ~= newCharacter then return end
	animator = (humanoid :: Humanoid):FindFirstChildOfClass("Animator")
	if not animator then return end
	loadLoops()
	ready = true
	scheduleFidget(true)
	bindReact(newCharacter)
	local hum = humanoid :: Humanoid
	-- hard landing
	hum.StateChanged:Connect(function(_, new)
		if character ~= newCharacter then return end
		if new == Enum.HumanoidStateType.Landed then
			if fallSpeed >= L.HardLandSpeed then playOne("LandHard", Enum.AnimationPriority.Action2, 0.05) end
			fallSpeed = 0
		end
	end)
	hum.Died:Connect(function()
		stopLoops(0.1)
		stopFidget()
		clearMelee()
	end)
	newCharacter.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c:GetAttribute("MeleeId") and character == newCharacter then bindMelee(c) end
	end)
	newCharacter.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") and c:GetAttribute("MeleeId") then clearMelee() end
	end)
	local held = newCharacter:FindFirstChildOfClass("Tool")
	if held and held:GetAttribute("MeleeId") then bindMelee(held) end
end

function controller.Start()
	if localPlayer.Character and __TG.On() then task.spawn(bindCharacter, localPlayer.Character) end
	__TG.CharacterAdded:Connect(bindCharacter)

	UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			stillSince = os.clock()
			stopFidget()
			scheduleFidget(true)
		end
	end)

	-- bots: stagger and burning, drawn by every client
	for _, m in CollectionService:GetTagged("Bot") do task.spawn(bindReact, m) end
	CollectionService:GetInstanceAddedSignal("Bot"):Connect(function(m) task.spawn(bindReact, m) end)

	localPlayer:GetAttributeChangedSignal("MeleeChargeStart"):Connect(onChargeChanged)
	localPlayer:GetAttributeChangedSignal("MedkitUntil"):Connect(onMedkitChanged)

	-- match beats
	local watched = nil
	local function watch()
		local s = stateObj()
		if watched == s then return end
		watched = s
		s:GetAttributeChangedSignal("MatchState"):Connect(function() if watched == s then onBeat() end end)
	end
	watch()
	localPlayer:GetAttributeChangedSignal("MatchId"):Connect(watch)
	task.spawn(function()
		while true do task.wait(2) watch() end
	end)

	-- DoorOpen: a door prompt you trigger to open it
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= localPlayer then return end
		local name = (prompt.ObjectText .. " " .. prompt.Name .. " " .. (prompt.Parent and prompt.Parent.Name or "") .. " "
			.. (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name or "")):lower()
		if prompt.ActionText == "Open" and (name:find("door") or name:find("shutter")) then controller.DoorOpen() end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not enabled() or not ready then return end
		if root then
			local vy = (root :: BasePart).AssemblyLinearVelocity.Y
			if vy < -fallSpeed and (humanoid :: Humanoid):GetState() == Enum.HumanoidStateType.Freefall then fallSpeed = -vy end
		end
		updateLoco(dt)
		updateLife()
	end)
	-- breathing after the Animator wrote this frame's pose (Transform), on every body
	RawRunService.Stepped:Connect(function(_, dt)
		updateBreath(dt)
	end)
	RawRunService:BindToRenderStep("AnimFinalSwayUndo", Enum.RenderPriority.First.Value, swayUndo)
	RawRunService:BindToRenderStep("AnimFinalSway", Enum.RenderPriority.Camera.Value + 5, swayApply)

	-- Studio-only test hook
	if RawRunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "BodyAnimTestHook"
		hook.OnInvoke = function(action, arg)
			if action == "state" then
				local w = {}
				for k, e in loco do w[k] = math.floor(e.w * 100 + 0.5) / 100 end
				local playing = {}
				if animator then for _, t in (animator :: Animator):GetPlayingAnimationTracks() do table.insert(playing, t.Name) end end
				return { ready = ready, weights = w, exertion = myExertion, sway = controller.BreathSway(), playing = playing,
					fidget = controller._lastFidget, dive = diveTrack ~= nil and diveTrack.IsPlaying,
					bodies = (function() local n = 0 for _ in bodies do n += 1 end return n end)() }
			elseif action == "exert" then
				myExertion = tonumber(arg) or 1
				return myExertion
			elseif action == "shot" then -- arg = { tool, origin, endPos }: a shot effect as if relayed from another shooter
				local fx = require(script.Parent:WaitForChild("WeaponController"):WaitForChild("WeaponEffects"))
				local WC = require(Shared.Config.WeaponConfig)
				fx.PlayShot(arg[1], arg[2], arg[3], true, nil, WC.Weapons.Pistol.Effects)
				return true
			elseif action == "ctl" then -- arg = { controller, function, ... }: call a controller in the game's VM
				local c = Get(arg[1])
				local f = c and c[arg[2]]
				if type(f) ~= "function" then return "no " .. tostring(arg[1]) .. "." .. tostring(arg[2]) end
				return f(table.unpack(arg, 3))
			elseif action == "oneshot" then
				return controller.PlayOneShot(tostring(arg))
			end
			return nil
		end
		hook.Parent = localPlayer:WaitForChild("PlayerScripts")
	end
end

return controller
