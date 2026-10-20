local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/WeaponController (ModuleScript)
-- Client half of the weapon framework. Works for any weapon in WeaponConfig.
--
--   * Input: fire (left click), reload (R), holster/draw (1)
--   * Predicts ammo, fire rate and reload locally so shooting feels instant,
--     then reconciles with the server's Tool attributes (Ammo / AckShot / Reloading).
--   * Shots travel from the gun's muzzle to the crosshair's aim point. If cover is in the
--     way, the shot hits the cover, and a red ring shows where while aiming.
--   * GTA-style posture: gun down at your side until you aim; crosshair only while aiming.
--     Unaimed shots (hip fire, blind fire from cover) get random spread.
--   * Plays effects for your shots and for other players' shots relayed by the server.
--
-- The server re-checks everything; nothing here can grant ammo, damage or hits.

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ContextActionService = game:GetService("ContextActionService")
ContextActionService = __TG.ContextActionService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- // Modules
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponConfig"))
local WeaponUtil = require(Shared:WaitForChild("WeaponUtil"))
local WeaponEffects = require(script:WaitForChild("WeaponEffects"))

-- // Repository
local Combat = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat")
local FireWeapon = Combat:WaitForChild("FireWeapon")
local ReloadWeapon = Combat:WaitForChild("ReloadWeapon")
local HitConfirm = Combat:WaitForChild("HitConfirm")
local WeaponFired = Combat:WaitForChild("WeaponFired")
local SetGunHandRemote = Combat:WaitForChild("SetGunHand")

-- // Imports
local Get = shared.Get
local localPlayer = Players.LocalPlayer

-- [SET] Settings > Hotkeys / Controls (UI session 2026-10-16): binds and settings arrive as player attributes
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))

-- // Root
local controller = {}

-- // State
local character: Model?, humanoid: Humanoid?
local equipped = nil -- { tool, config, muzzle, connections, tracks }
local shellShots = {} -- [ABILITY2] shot ids still waiting for the server that each cost a round
local shotId = 0
local lastFireTime = -math.huge
local localReloadEnd = 0
local gunHand = 1 -- 1 = right hand, -1 = left hand (follows the camera shoulder)
local triggerHeld = false -- automatic guns keep firing while this is true

local shotParams = RaycastParams.new()
shotParams.FilterType = Enum.RaycastFilterType.Exclude
shotParams.IgnoreWater = true

local CameraController, HUD -- resolved in Start

-- // Helpers
local function isAlive(): boolean
	return humanoid ~= nil and humanoid.Health > 0 and character ~= nil and character.Parent ~= nil
end

-- Predicted ammo = server ammo minus shots the server hasn't acknowledged yet
local function getAmmo(): number
	if not equipped then return 0 end
	local tool = equipped.tool
	local serverAmmo = tool:GetAttribute("Ammo") or 0
	local acked = tool:GetAttribute("AckShot") or 0
	-- [ABILITY2] only shots that cost a round count (a shotgun blast's extra pellets ride on its first shot id)
	local pending = 0
	for i = #shellShots, 1, -1 do
		if shellShots[i] <= acked then table.remove(shellShots, i) else pending += 1 end
	end
	return math.max(serverAmmo - pending, 0)
end

local function isReloading(): boolean
	if not equipped then return false end
	return equipped.tool:GetAttribute("Reloading") == true or os.clock() < localReloadEnd
end

local function refreshHUD()
	if equipped then
		HUD.SetAmmo(getAmmo(), equipped.tool:GetAttribute("Reserve") or 0, isReloading())
	end
end

-- Plays the version of an animation for the hand currently holding the gun ("Fire" -> "FireLeft")
local function playAnimation(name: string)
	if not equipped then return end
	local track = (gunHand < 0 and equipped.tracks[name .. "Left"]) or equipped.tracks[name]
	if track then
		track:Play()
	end
end

local POSE_NAMES = { "Hold", "HoldLeft", "Lowered", "LoweredLeft" }

-- Arms up ("Hold") while aiming or just after a hip-fire shot; gun down at your side ("Lowered") otherwise.
-- Plays the version for the hand holding the gun, and stops the others.
local function updatePose()
	if not equipped then return end
	local base = CameraController.IsFacingCamera() and "Hold" or "Lowered"
	local wanted = (gunHand < 0 and equipped.tracks[base .. "Left"]) or equipped.tracks[base] or equipped.tracks.Hold
	if equipped.activePose == wanted then return end

	for _, name in POSE_NAMES do
		local track = equipped.tracks[name]
		if track and track ~= wanted and track.IsPlaying then track:Stop(0.08) end
	end
	equipped.activePose = wanted
	if wanted and not wanted.IsPlaying then wanted:Play(0.08) end -- quick draw: aiming feels immediate
end

-- Random cone around a direction (degrees)
local function applySpread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then return direction end
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Move the gun to the other hand (instantly here, and on the server for everyone else)
local function setGunHand(side: number)
	gunHand = side
	if character then WeaponUtil.SetGunHand(character, side) end
	SetGunHandRemote:FireServer(side)
	if equipped then equipped.activePose = nil end -- force the pose to switch hands
	updatePose()
end

local function loadAnimations(config): { [string]: AnimationTrack }
	local tracks = {}
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return tracks end

	for name, id in config.Animations do
		-- (pass 40) published to the group: the source carries its asset id
		local pubRoot = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
		local pub = id == "" and pubRoot and pubRoot:FindFirstChild((config.AnimationSourcePrefix or "") .. name)
		if pub and pub:GetAttribute("PublishedId") then id = pub:GetAttribute("PublishedId") end
		-- Studio only: no published ID yet -> play the local KeyframeSequence source
		if id == "" and RunService:IsStudio() then
			local sources = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
			local source = sources and sources:FindFirstChild((config.AnimationSourcePrefix or "") .. name)
			if source and source:IsA("KeyframeSequence") then
				local ok, tempId = pcall(function()
					return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(source)
				end)
				if ok then
					id = tempId
				else
					warn(`[WeaponController] Studio preview of {name} failed: {tempId}`)
				end
			else
				warn(`[WeaponController] No animation ID or source for {name}`)
			end
		end
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok then
				-- Reload / fire / draw must show on the arms even while a cover or crouch pose is playing
				-- (those run at Action3/Action4). The cover pose keeps the legs.
				local base = name:gsub("Left$", "")
				if base == "Reload" or base == "Fire" or base == "Equip" then
					track.Priority = Enum.AnimationPriority.Action4
				end
				tracks[name] = track
			else
				warn(`[WeaponController] Could not load {name} animation: {track}`)
			end
		end
	end
	return tracks
end

-- Where would a shot go right now?
local function computeShot(config, spreadDegrees: number?)
	local head = (character :: Model):FindFirstChild("Head") :: BasePart
	local origin = equipped.muzzle.WorldPosition
	local cameraLook = workspace.CurrentCamera.CFrame.LookVector

	local aimPoint = CameraController.GetAimPoint(config.Range)
	local toAim = aimPoint - origin
	-- Aim point behind or right on top of the muzzle (hugging a wall): shoot straight ahead
	local direction = (toAim.Magnitude > 0.5 and toAim.Unit:Dot(cameraLook) > 0.2) and toAim.Unit or cameraLook
	direction = applySpread(direction, spreadDegrees or 0)

	-- Gun poking through a wall: the wall takes the shot
	local muzzleClear, wallResult = WeaponUtil.IsMuzzleReachable(head.Position, origin, WeaponConfig.Validation.ArmReachOver)
	if not muzzleClear then
		local wall = wallResult :: RaycastResult
		return { origin = origin, direction = direction, endPos = wall.Position, normal = wall.Normal, blocked = true, aimPoint = aimPoint }
	end

	shotParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction * config.Range, shotParams)
	local hitPart, hitCharacter = nil, false
	if result and WeaponUtil.GetCharacterFromPart(result.Instance) then
		hitPart, hitCharacter = result.Instance, true
	end

	return {
		origin = origin,
		direction = direction,
		endPos = result and result.Position or origin + direction * config.Range,
		normal = result and result.Normal,
		hitPart = hitPart,
		hitCharacter = hitCharacter,
		hitPosition = result and result.Position,
		aimPoint = aimPoint,
	}
end

-- // Actions
-- (2026-10-18, Edward: "you can not aim in while reloading") CameraController.IsAiming asks this
function controller.IsReloading(): boolean
	return isReloading()
end

-- [MOVE2] draw time (Edward: "wait until your gun is fully pulled out to shoot it and aim in"); CameraController.IsAiming asks too
function controller.IsDrawing(): boolean
	return equipped ~= nil and os.clock() < (equipped.drawEndsAt or 0)
end

-- [MOVE2] crosshair countdown (RIVALS): client-only player attributes the HUD draws next to the crosshair, all in os.clock() time.
--   XhairDrawEnd / XhairDrawTime     the gun is still coming out
--   XhairReloadEnd / XhairReloadTime the reload (shell by shell: one shell at a time)
--   XhairFireEnd / XhairFireTime     the next shot, only for slow guns (FireInterval >= XHAIR_MIN_COOLDOWN)
local XHAIR_MIN_COOLDOWN = 0.3
local function setCountdown(kind: string, duration: number?)
	localPlayer:SetAttribute("Xhair" .. kind .. "End", duration and os.clock() + duration or nil)
	localPlayer:SetAttribute("Xhair" .. kind .. "Time", duration)
end
local function clearCountdowns()
	for _, kind in { "Draw", "Reload", "Fire" } do setCountdown(kind, nil) end
end

-- [MOVE2] reload cancel (Edward: "the full sound cue for reloads plays even after i cancel the reload by switching weapons"):
-- the server already stops the reload when the gun leaves the hands; this stops what you see and hear. Runs on unequip /
-- switching, death, a shot cutting a shell-by-shell reload, and the server dropping Reloading before the magazine is full.
local function cancelReloadFx(eq)
	eq = eq or equipped
	if not eq then return end
	eq.reloadId = (eq.reloadId or 0) + 1 -- skips the pending revolver casing drop
	local sound = eq.reloadSound
	eq.reloadSound = nil
	if sound then sound:Stop(); sound:Destroy() end
	for _, name in { "Reload", "ReloadLeft" } do
		local track = eq.tracks and eq.tracks[name]
		if track and track.IsPlaying then track:Stop(0.1) end
	end
	if eq == equipped then localReloadEnd = 0 end
	setCountdown("Reload", nil)
end

function controller.Reload()
	if not equipped or not isAlive() or isReloading() then return end
	local config = equipped.config
	if getAmmo() >= config.MagazineSize then return end
	if (equipped.tool:GetAttribute("Reserve") or 0) <= 0 then return end -- no spare rounds

	-- [ABILITY2] shell by shell (Pump Shotgun): predict the first shell; the server's Reloading flag covers the rest
	localReloadEnd = os.clock() + (config.ShellReload and (config.ShellReload.StartDelay + config.ShellReload.ShellTime) or config.ReloadTime)
	setCountdown("Reload", localReloadEnd - os.clock()) -- [MOVE2] (shell by shell: the first shell; the Ammo watcher times the rest)
	setCountdown("Fire", nil)
	ReloadWeapon:FireServer()
	equipped.reloadSound = WeaponEffects.PlaySound(equipped.tool, "Reload") -- [MOVE2] kept so a cancel can cut it
	equipped.reloadId = (equipped.reloadId or 0) + 1
	equipped.reloadEndsAt = os.clock() + config.ReloadTime
	playAnimation("Reload")
	do -- [ABILITY] the reload animation fits the gun's ReloadTime (the speed ladder)
		local track = equipped and ((gunHand < 0 and equipped.tracks.ReloadLeft) or equipped.tracks.Reload)
		if track and track.Length > 0 then track:AdjustSpeed(track.Length / config.ReloadTime) end
	end
	local Scope = Get("ScopeController")
	if Scope and Scope.OnReload then Scope.OnReload(config.ReloadTime) end -- the scope comes down to reload
	local spent = config.MagazineSize - getAmmo()
	local reloadTool = equipped.tool
	if config.CasingEject ~= "Fire" then -- revolvers dump their spent casings on reload
		local thisEquip, thisReload = equipped, equipped.reloadId
		task.delay(0.5, function()
			if equipped ~= thisEquip or thisEquip.reloadId ~= thisReload then return end -- [MOVE2] the reload was cancelled
			WeaponEffects.DropCasings(reloadTool, spent)
		end)
	end
	refreshHUD()
	task.delay(config.ReloadTime + 0.05, refreshHUD)
end

local function fire()
	if not equipped or not isAlive() then return end
	local config = equipped.config

	-- [SET] per-match flag: lobby duels keep it on their own state object (MatchState.For), the match place on ReplicatedStorage
	local stateObj = ReplicatedStorage
	pcall(function()
		local MS = require(ReplicatedStorage.Modules.Shared:FindFirstChild("MatchState"))
		stateObj = MS.For(localPlayer) or ReplicatedStorage
	end)
	if stateObj:GetAttribute("CombatEnabled") == false then return end -- countdown / between rounds
	local now = os.clock()
	if now < (equipped.drawEndsAt or 0) then return end -- [MOVE2] still drawing the gun
	if (localPlayer:GetAttribute("NoFireUntil") or 0) > now then return end -- [ABILITY2] stunned (takedown / bash)
	-- [ABILITY2] Dual Pistols: twice the fire rate while moving
	local interval = config.FireInterval
	if config.MovingFireInterval and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then interval = config.MovingFireInterval end
	if now - lastFireTime < interval then return end
	-- [ABILITY2] Pump Shotgun: a shot cuts a shell-by-shell reload short (the server stops it too)
	if config.ShellReload and isReloading() and getAmmo() > 0 then cancelReloadFx() end -- [MOVE2] stops at the current shell
	if isReloading() and not (config.ShellReload and getAmmo() > 0) then return end

	if getAmmo() <= 0 then
		WeaponEffects.PlaySound(equipped.tool, "Empty")
		controller.Reload()
		return
	end
	local aiming = CameraController.IsAiming()

	-- Firing while sprinting: the sprint stops and you shoot while walking
	-- [ABILITY] Run and Gun (Mini Uzi): the sprint carries on through the burst
	local MovementController = Get("MovementController")
	local runningAimed = config.RunAndGun and aiming and MovementController and MovementController.IsSprinting()
	if MovementController and not config.RunAndGun then MovementController.StopSprint() end

	local CoverController = Get("CoverController")

	-- No shooting mid-hop (and the hop itself waits for the shot to finish, see CoverController)
	-- [TX] Training jump pads (notes/training_extras_done.md): airborne from a pad you may shoot; normal rule again on landing
	local TXpads = script.Parent:FindFirstChild("TrainingPadsController") and Get("TrainingPadsController") -- lobby only (no warning in matches)
	if CoverController and CoverController.IsHopping() and not (TXpads and TXpads.IsPadFlight and TXpads.IsPadFlight()) then return end

	-- Mid vault: fire straight away, but very inaccurately. Mid cover dash: as inaccurate as blind fire.
	if CoverController and CoverController.IsMoving() then
		lastFireTime = now
		local spread = CoverController.IsVaulting() and config.VaultFireSpread or config.BlindFireSpread
		controller._Shoot(config, spread)
		return
	end

	-- Blind fire: in cover without aiming. The arm pops around/over the cover first, then shoots inaccurately.
	if not aiming and CoverController and CoverController.IsInCover() then
		local accepted = CoverController.BlindFire(function()
			if equipped and isAlive() and not isReloading() and getAmmo() > 0 then
				controller._Shoot(config, config.BlindFireSpread)
			end
		end)
		if accepted then lastFireTime = now end
		return
	end
	-- Automatic: keep an exact rhythm instead of rounding every shot up to the next frame
	if config.FireMode == "Auto" and now - lastFireTime < config.FireInterval * 1.5 then
		lastFireTime += config.FireInterval
	else
		lastFireTime = now
	end

	-- Hip fire: snap to face the crosshair and raise the gun first
	if not aiming then
		CameraController.FaceCamera(config.HipFireFaceTime)
		updatePose()
	end
	controller._Shoot(config, aiming and (runningAimed and (config.AimSprintSpread or 0) or 0) or config.HipFireSpread)
end

-- Fires one shot now (after all checks). Used by aimed, hip and blind fire.
function controller._Shoot(config, spreadDegrees: number)
	local CoverController = Get("CoverController")
	if CoverController then CoverController.NotifyShot() end -- blocks hopping until the shot has finished
	-- [ABILITY2] Dual Pistols: the shots alternate between the two guns
	-- (Edward 2026-10-19: one gun per shot, L R L R) name both muzzles: GetMuzzle returns the first Muzzle found, which can be
	-- the left gun's, so "else GetMuzzle" fired the left gun every time
	if config.Akimbo then
		local left = equipped.tool:FindFirstChild("LeftBarrel")
		local right = equipped.tool:FindFirstChild("Barrel")
		local leftMuzzle = left and left:FindFirstChild("Muzzle")
		local rightMuzzle = right and right:FindFirstChild("Muzzle")
		if leftMuzzle and rightMuzzle then
			equipped.akimboLeft = not equipped.akimboLeft
			equipped.muzzle = equipped.akimboLeft and leftMuzzle or rightMuzzle
		end
	end
	-- [ABILITY2] extra info for the server: fully aimed in (the Revolver's knockback), which pellet of a shotgun blast
	local aimedIn = CameraController.IsAiming() and (not config.Knockback or localPlayer:GetAttribute("RevolverReady") == true)
	local shot = computeShot(config, spreadDegrees + (config.PelletSpread or 0) * (config.Pellets and 0.5 or 0))
	shotId += 1
	table.insert(shellShots, shotId)
	FireWeapon:FireServer(shotId, shot.origin, shot.direction, shot.hitPart, shot.hitPosition, { aimed = aimedIn, pellet = config.Pellets and 1 or nil })

	WeaponEffects.PlayShot(equipped.tool, shot.origin, shot.endPos, shot.hitCharacter == true, shot.normal, config.Effects)
	-- [ABILITY2] the rest of the blast: each pellet its own ray in the cone, one shell, one bang
	for i = 2, config.Pellets or 1 do
		local pellet = computeShot(config, spreadDegrees + (config.PelletSpread or 0))
		shotId += 1
		FireWeapon:FireServer(shotId, pellet.origin, pellet.direction, pellet.hitPart, pellet.hitPosition, { aimed = aimedIn, pellet = i })
		WeaponEffects.PlayShot(equipped.tool, pellet.origin, pellet.endPos, pellet.hitCharacter == true, pellet.normal, config.Effects, true)
	end
	local Props = Get("PropController")
	if Props and Props.OnLocalShot then Props.OnLocalShot(shot.origin, shot.endPos) end -- bottles etc. react this frame
	if config.CasingEject == "Fire" then WeaponEffects.DropCasings(equipped.tool, 1) end -- pistols eject one per shot
	playAnimation("Fire")
	if config.FireInterval >= XHAIR_MIN_COOLDOWN then setCountdown("Fire", config.FireInterval) end -- [MOVE2] slow guns only

	local recoil = config.Recoil
	-- through a scope the kick is shorter, and the scope adds its own clean shot motion (ScopeController)
	local Scope = Get("ScopeController")
	local scoped = Scope and Scope.IsScoped and Scope.IsScoped()
	local k = scoped and ((config.Scope and config.Scope.RecoilScale) or 0.45) or 1
	CameraController.AddRecoil(recoil.Pitch * k, (recoil.YawMin + math.random() * (recoil.YawMax - recoil.YawMin)) * k, recoil.Recovery)
	if scoped then
		Scope.OnShot(config)
	else
		local Cinematic = Get("CinematicCamera")
		if Cinematic and Cinematic.Kick then Cinematic.Kick(math.clamp(recoil.Pitch / 3.5, 0.5, 1.4)) end
	end

	refreshHUD()

	-- Out of ammo: start reloading automatically once the shot settles
	-- (unless the tutorial wants you to press R yourself: player attribute NoAutoReload)
	if getAmmo() == 0 and not game:GetService("Players").LocalPlayer:GetAttribute("NoAutoReload") then
		task.delay(config.FireInterval, function()
			if equipped and getAmmo() == 0 then
				controller.Reload()
			end
		end)
	end
end

local function toggleHolster()
	if not isAlive() then return end
	if equipped then
		return -- (pass 43) no holstering: you always hold the gun, the melee or the gadget
	end
	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	for _, tool in (backpack and backpack:GetChildren() or {}) do
		if tool:IsA("Tool") and tool:GetAttribute("WeaponId") then
			(humanoid :: Humanoid):EquipTool(tool)
			return
		end
	end
end

-- // Equip / unequip
local function onInput(actionName: string, inputState: Enum.UserInputState)
	-- (pass 45) cursor freed (Left Alt / a menu): clicks are for the UI, not the gun
	if actionName == "WeaponFire" and CameraController and CameraController.IsMouseFree and CameraController.IsMouseFree() then
		triggerHeld = false
		return Enum.ContextActionResult.Pass
	end
	if actionName == "WeaponFire" then
		triggerHeld = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "WeaponFire" then
		fire()
	elseif actionName == "WeaponReload" then
		controller.Reload()
	end
	return Enum.ContextActionResult.Pass
end

local function unequip()
	if not equipped then return end
	for _, conn in equipped.connections do
		conn:Disconnect()
	end
	for _, track in equipped.tracks do
		track:Stop()
	end
	cancelReloadFx() -- [MOVE2] switching weapons cancels the reload: no sound tail, no animation, no casings
	equipped = nil
	triggerHeld = false
	localReloadEnd = 0
	clearCountdowns() -- [MOVE2]
	ContextActionService:UnbindAction("WeaponFire")
	ContextActionService:UnbindAction("WeaponReload")
	HUD.SetWeapon(nil)
end

local function equip(tool: Tool)
	local config = WeaponConfig.Get(tool:GetAttribute("WeaponId"))
	local muzzle = WeaponUtil.GetMuzzle(tool)
	if not config or not muzzle then
		warn(`[WeaponController] {tool.Name} is missing a WeaponConfig entry or a Muzzle attachment`)
		return
	end

	unequip()
	equipped = {
		tool = tool,
		config = config,
		muzzle = muzzle,
		connections = {},
		tracks = {}, -- filled in once the character is Ready (see below)
	}

	-- Any shots the server already acknowledged are not "pending"
	shotId = math.max(shotId, tool:GetAttribute("AckShot") or 0)

	for _, attribute in { "Ammo", "AckShot", "Reloading", "Reserve" } do
		table.insert(equipped.connections, tool:GetAttributeChangedSignal(attribute):Connect(refreshHUD))
	end
	-- [MOVE2] draw time: no firing or aiming in until the gun is out (the server checks it too); the crosshair counts it down
	equipped.drawEndsAt = os.clock() + (config.DrawTime or 0)
	clearCountdowns()
	setCountdown("Draw", (config.DrawTime or 0) > 0 and config.DrawTime or nil)
	-- [MOVE2] crosshair reload countdown: ends with the server's Reloading flag; shell by shell, one shell at a time
	local thisEquipR = equipped
	table.insert(equipped.connections, tool:GetAttributeChangedSignal("Reloading"):Connect(function()
		if tool:GetAttribute("Reloading") == true then return end
		-- [MOVE2] the server stopped the reload before the magazine was full (cancelled): stop the sound and animation too
		if (tool:GetAttribute("Ammo") or 0) < config.MagazineSize and (config.ShellReload or os.clock() < (thisEquipR.reloadEndsAt or 0) - 0.15) then
			cancelReloadFx(thisEquipR)
		elseif os.clock() >= localReloadEnd then
			setCountdown("Reload", nil)
		end
	end))
	table.insert(equipped.connections, tool:GetAttributeChangedSignal("Ammo"):Connect(function()
		if config.ShellReload and tool:GetAttribute("Reloading") == true then setCountdown("Reload", config.ShellReload.ShellTime) end
	end))

	local keys = WeaponConfig.Keybinds
	-- [SET] your Fire / Reload binds (re-read on every equip), plus the pad triggers
	ContextActionService:BindAction("WeaponFire", onInput, false, Binds.Key(localPlayer, "Fire", keys.Fire), Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("WeaponReload", onInput, false, Binds.Key(localPlayer, "Reload", keys.Reload), Enum.KeyCode.ButtonX)

	HUD.SetWeapon(config.DisplayName)
	refreshHUD()

	-- The server rebuilds the body (PlayerRegistry normalization) right after spawning.
	-- Animations loaded before that finishes get lost, so wait for the Ready flag first.
	local thisEquip = equipped
	task.spawn(function()
		local waited = 0
		while character and character:GetAttribute("Ready") ~= true and waited < 10 do
			waited += task.wait(0.1)
		end
		task.wait() -- let the rebuilt joints settle for a frame
		if equipped ~= thisEquip then return end -- unequipped meanwhile

		thisEquip.tracks = loadAnimations(config)
		for _, name in POSE_NAMES do
			local pose = thisEquip.tracks[name]
			if pose then
				pose.Looped = true
				-- If anything stops the active pose while the gun is out, start it again
				table.insert(thisEquip.connections, pose.Stopped:Connect(function()
					if equipped == thisEquip and thisEquip.activePose == pose then
						pose:Play()
					end
				end))
			end
		end
		setGunHand(CameraController.GetShoulder()) -- also starts the right pose
		playAnimation("Equip")
		do -- [MOVE2] the draw animation fits the gun's DrawTime (whatever is left of it after the Ready wait)
			local track = thisEquip.tracks.Equip
			local left = (thisEquip.drawEndsAt or 0) - os.clock()
			if track and track.Length > 0 and left > 0.05 then track:AdjustSpeed(track.Length / left) end
		end
	end)
end

local function bindCharacter(newCharacter: Model)
	unequip()
	character = newCharacter
	shotId = 0
	gunHand = 1
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	if character ~= newCharacter then return end
	if humanoid then humanoid.Died:Connect(function() cancelReloadFx() end) end -- [MOVE2] dying cancels the reload

	newCharacter.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			equip(child)
		end
	end)
	newCharacter.ChildRemoved:Connect(function(child)
		if equipped and child == equipped.tool then
			unequip()
		end
	end)

	local current = newCharacter:FindFirstChildOfClass("Tool")
	if current and current:GetAttribute("WeaponId") then
		equip(current)
	end
end

-- // Per frame: show where cover blocks the shot while aiming
local function updateBlockedMarker()
	-- Automatic fire: keep shooting while the trigger is held (fire() enforces the fire rate)
	if triggerHeld and equipped and equipped.config.FireMode == "Auto" then
		if getAmmo() > 0 then
			fire()
		else
			triggerHeld = false -- ran dry: let go (the auto-reload is already on its way)
		end
	end
	-- Gun hand follows the camera shoulder (V, or automatic in cover)
	if equipped and equipped.activePose ~= nil and CameraController.GetShoulder() ~= gunHand then
		setGunHand(CameraController.GetShoulder())
	end
	updatePose()

	-- Centre dot: always there while you're alive (gun, melee, gadget or empty hands) - solid while you're
	-- aimed in, 75% see-through otherwise
	local alive = isAlive()
	local Scope = Get("ScopeController")
	local scopedView = Scope ~= nil and Scope.Blend ~= nil and Scope.Blend() > 0.5 -- the scope has its own reticle
	HUD.SetCrosshair(alive and not scopedView, alive and CameraController.IsAiming())
	local aiming = equipped ~= nil and alive and CameraController.IsAiming()

	if not aiming then
		HUD.SetBlocked(nil)
		return
	end

	local shot = computeShot(equipped.config)
	local blockPos: Vector3? = nil
	if shot.blocked then
		blockPos = shot.endPos
	elseif shot.hitPosition
		and (shot.hitPosition - shot.origin).Magnitude < (shot.aimPoint - shot.origin).Magnitude - 1 then
		blockPos = shot.hitPosition -- the gun's line of fire stops short of what the crosshair is on
	end

	if blockPos then
		local screen, onScreen = workspace.CurrentCamera:WorldToViewportPoint(blockPos)
		HUD.SetBlocked(onScreen and Vector2.new(screen.X, screen.Y) or nil)
	else
		HUD.SetBlocked(nil)
	end
end

-- // Start
function controller.Start()
	CameraController = Get("CameraController")

	-- [TOUCH] mobile: the Fire / Reload buttons (and the double-tap fire) run the key handler
	task.spawn(function()
		local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		IA.BindCAS("Fire", function(_, state, input) if equipped then return onInput("WeaponFire", state, input) end end, "WeaponFire")
		IA.BindCAS("Reload", function(_, state, input) if equipped then return onInput("WeaponReload", state, input) end end, "WeaponReload")
	end)
	HUD = Get("HUD")

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- our own HUD replaces the hotbar
	end)

	-- [SET] Equip Gun follows Settings > Hotkeys
	local function bindHolster()
		ContextActionService:UnbindAction("WeaponHolster")
		ContextActionService:BindAction("WeaponHolster", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				toggleHolster()
			end
			return Enum.ContextActionResult.Pass
		end, false, Binds.Key(localPlayer, "EquipGun", WeaponConfig.Keybinds.Holster))
	end
	bindHolster()
	Binds.Changed(localPlayer, "EquipGun", bindHolster)
	-- [TOUCH] mobile: the gun circle draws the gun (the key toggles; a tap only ever draws)
	task.spawn(function()
		local ok, IA = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		IA.Bind("Equip1", function(state) if state == Enum.UserInputState.Begin and not equipped then toggleHolster() end end)
	end)

	HitConfirm.OnClientEvent:Connect(function(zone: string, _damage: number, killed: boolean, headshot: boolean?, kind: string?)
		-- (2026-10-19) ability hits: the Fists vault takedown gets RIVALS-style big TAKEDOWN text
		if kind == "Takedown" and HUD.ShowTakedown then HUD.ShowTakedown() end
		-- [SET] 4th arg: true only for gun hits on the head (backstabs report zone "Head" but send no flag)
		HUD.ShowHitmarker(zone, killed, headshot)
	end)

	Combat:WaitForChild("DamageTaken").OnClientEvent:Connect(function(source: Vector3)
		if typeof(source) == "Vector3" then
			HUD.ShowDamageFrom(source)
		end
	end)

	local remoteBlastAt = setmetatable({}, { __mode = "k" }) -- [ABILITY2] [shooter] = os.clock() of their last shotgun blast
	WeaponFired.OnClientEvent:Connect(function(shooter: Instance, origin: Vector3, endPos: Vector3, hitCharacter: boolean)
		if shooter == localPlayer then return end -- already played locally
		-- shooter is a Player, or an AI character Model
		local shooterCharacter = shooter and (shooter:IsA("Player") and shooter.Character or shooter)
		local tool = shooterCharacter and shooterCharacter:FindFirstChildOfClass("Tool")
		local config = WeaponConfig.Get(tool and tool:GetAttribute("WeaponId") or "") or WeaponConfig.Get(WeaponConfig.DefaultWeapon)
		-- [ABILITY2] a shotgun blast arrives as one event per pellet: one bang and one shell for the lot
		local now = os.clock()
		local samePellets = config.Pellets and remoteBlastAt[shooter] and now - remoteBlastAt[shooter] < 0.12
		if not samePellets then remoteBlastAt[shooter] = now end
		WeaponEffects.PlayShot(tool, origin, endPos, hitCharacter, nil, config.Effects, samePellets)
		if config.CasingEject == "Fire" and not samePellets then WeaponEffects.DropCasings(tool, 1) end
	end)

	-- Weapon select: cycles your loadout (the server only allows it between rounds, or any time in Studio)
	local SelectWeapon = Combat:WaitForChild("SelectWeapon")
	ContextActionService:BindAction("SelectWeapon", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		local list = WeaponConfig.Loadout
		local current = localPlayer:GetAttribute("Loadout") or WeaponConfig.DefaultWeapon
		local index = table.find(list, current) or 0
		SelectWeapon:FireServer(list[index % #list + 1])
		return Enum.ContextActionResult.Sink
	end, false, Binds.Key(localPlayer, "CycleWeapon", WeaponConfig.Keybinds.SelectWeapon)) -- [SET] Cycle Weapon

	if localPlayer.Character and __TG.On() then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	__TG.CharacterAdded:Connect(bindCharacter)

	RunService.RenderStepped:Connect(updateBlockedMarker)
end

return controller
