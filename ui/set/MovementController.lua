local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/MovementController (ModuleScript)
-- On-foot movement out of cover:
--   Walk (default, slower than Roblox's 16)    Shift: sprint (a bit faster than 16, no stamina)
--   C: crouch / crab walk (silent)             Shift while crouched: fast silent strides (uses stamina)
-- Aiming or firing stops a sprint: firing while sprinting drops you to walk speed and shoots.
-- The sprint stays off until Shift is released and pressed again.
-- While in cover or mid cover-move / vault, CoverController owns speed and pose; this steps aside.
--
-- API: IsCrouched(), IsSprinting(), StopSprint(), GetStamina()

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local UserInputService = game:GetService("UserInputService")
UserInputService = __TG.UserInputService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundTrim = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SoundTrim"))

-- // Config
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MovementConfig"))
local SetStance = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Movement"):WaitForChild("SetStance")

local localPlayer = Players.LocalPlayer

-- [SET] Settings > Hotkeys / Controls (UI session 2026-10-16): binds and settings arrive as player attributes
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))
local function isDown(k): boolean
	if not k then return false end
	if k.EnumType == Enum.UserInputType then return UserInputService:IsMouseButtonPressed(k) end
	return UserInputService:IsKeyDown(k)
end
local sprintToggled = false -- [SET] Toggle Sprint: on until you stop, aim or fire
local sprintBlockedAt = 0
-- [SET] Shift (your Sprint bind) held, or Toggle Sprint / Auto Sprint asking to run
local function wantsSprint(): boolean
	if localPlayer:GetAttribute("Setting_AutoSprint") == true then return true end
	if localPlayer:GetAttribute("Setting_ToggleSprint") == true then return sprintToggled end
	return isDown(Binds.Key(localPlayer, "Sprint", Config.Keybinds.Sprint))
end
local Get = shared.Get
local FLAT = Vector3.new(1, 0, 1)

-- // Root
local controller = {}

-- // State
local humanoid: Humanoid?, rootPart: BasePart?
local crouched = false
local sprinting = false
local sprintBlocked = false   -- set by firing / aiming / running dry; cleared when Shift is released
local stamina = Config.Stamina.Max
local exhausted = false       -- ran dry: fast strides off until MinToStart
local lastStaminaUse = 0
local currentSpeed = Config.Speeds.Walk
local tracks: { [string]: AnimationTrack }? = nil
local CoverController, CameraController
local sliding: { start: number, dir: Vector3, wantCover: boolean? }? = nil
local lastSlide = 0
local controls = nil
local staminaFill: Frame?, staminaGui: ScreenGui?

-- // Helpers
local function isAlive(): boolean
	return humanoid ~= nil and rootPart ~= nil and rootPart.Parent ~= nil and humanoid.Health > 0
end

local function loadTracks()
	local result = {}
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return result end
	local sources = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
	for name, id in Config.Animations do
		-- (pass 40) published to the group: the source carries its asset id
		local pub = id == "" and sources and sources:FindFirstChild("Move" .. name)
		if pub and pub:GetAttribute("PublishedId") then id = pub:GetAttribute("PublishedId") end
		if id == "" and RunService:IsStudio() and sources then
			local source = sources:FindFirstChild("Move" .. name)
			if source then
				local ok, tempId = pcall(function()
					return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(source)
				end)
				if ok then id = tempId end
			end
		end
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok then
				track.Looped = true
				result[name] = track
			end
		end
	end
	return result
end

local function setPose(name: string?, speed: number?)
	tracks = tracks or loadTracks()
	for trackName, track in tracks do
		if trackName == name then
			if not track.IsPlaying then track:Play(0.2) end
			if speed then track:AdjustSpeed(speed) end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

local function setCrouched(value: boolean)
	if crouched == value then return end
	crouched = value
	SetStance:FireServer(value and "Crouch" or "Stand")
end

-- Stamina bar: only shows while not full
local function buildStaminaBar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StaminaBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -28)
	back.Size = UDim2.fromOffset(160, 5)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	staminaGui, staminaFill = gui, fill
end

local function updateStaminaBar()
	if not staminaFill or not staminaGui then return end
	local full = stamina >= Config.Stamina.Max - 0.01
	staminaGui.Enabled = not full and isAlive()
	staminaFill.Size = UDim2.fromScale(stamina / Config.Stamina.Max, 1)
	staminaFill.BackgroundColor3 = exhausted and Color3.fromRGB(200, 70, 60) or Color3.fromRGB(235, 235, 235)
end

local function getControls()
	if controls then return controls end
	local ok, result = pcall(function()
		return require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	if ok then controls = result end
	return controls
end

-- // Slide
local function startSlide()
	local hum, root = humanoid :: Humanoid, rootPart :: BasePart
	local v = root.AssemblyLinearVelocity * FLAT
	local dir = v.Magnitude > 2 and v.Unit or (hum.MoveDirection * FLAT)
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	sliding = { start = os.clock(), dir = dir }
	lastSlide = os.clock()
	stamina = math.max(0, stamina - Config.Slide.StaminaCost)
	lastStaminaUse = os.clock()
	setCrouched(true)
	sprinting = false
	hum.AutoRotate = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	local c = getControls()
	if c then c:Disable() end
	setPose("Slide")
	local scrape = Instance.new("Sound")
	scrape.SoundId = "rbxassetid://12222216"
	scrape.Volume = 0.3
	scrape.PlaybackSpeed = 0.55
	scrape.Parent = root
	SoundTrim.Play(scrape)
	game:GetService("Debris"):AddItem(scrape, 2)
end

-- [SLIDE] Roblox's keyboard controller zeroes its key state while it's disabled (the slide disables it), so keys still held
-- when it comes back don't move you until they're pressed again. Re-read them into it.
local function resyncHeldMoveKeys(c)
	local kb = c and c.activeController
	if not (kb and kb.forwardValue ~= nil and kb.UpdateMovement) then return end
	local function down(...)
		for _, k in { ... } do if UserInputService:IsKeyDown(k) then return true end end
		return false
	end
	kb.forwardValue = down(Enum.KeyCode.W, Enum.KeyCode.Up) and -1 or 0
	kb.backwardValue = down(Enum.KeyCode.S, Enum.KeyCode.Down) and 1 or 0
	kb.leftValue = down(Enum.KeyCode.A) and -1 or 0
	kb.rightValue = down(Enum.KeyCode.D) and 1 or 0
	pcall(kb.UpdateMovement, kb, Enum.UserInputState.Begin)
end

local lastSlideEnd = 0
local function endSlide()
	lastSlideEnd = os.clock()
	local wantCover = sliding ~= nil and sliding.wantCover == true
	sliding = nil
	local c = getControls()
	if c then c:Enable(); resyncHeldMoveKeys(c) end
	if humanoid then
		humanoid.AutoRotate = true
		humanoid:Move(Vector3.zero)
	end
	setPose(nil)
	localPlayer:SetAttribute("SlidAt", os.clock())
	-- Q pressed during the slide: it ends in the cover beside you (and you stay low behind it)
	if wantCover and CoverController and CoverController.TryEnterCover and CoverController.TryEnterCover() then
		if CoverController.SetCrouched then CoverController.SetCrouched(true) end
		localPlayer:SetAttribute("SlideCoverAt", os.clock())
		return
	end
	-- a plain slide: you come back up on your feet; still holding Sprint and a movement key = straight on into a sprint
	-- (Edward 2026-10-18: "if i am holding shift and a movement key and the slide has ended it should continue into a sprint"),
	-- else walking pace
	setCrouched(false)
	local moveHeld = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
	local c2 = getControls()
	local kb = c2 and c2.activeController
	if kb and kb.moveVector and kb.moveVector.Magnitude > 0.1 then moveHeld = true end
	local keepRunning = moveHeld and wantsSprint() and not sprintBlocked and not exhausted and stamina > 0
		and UserInputService:GetFocusedTextBox() == nil
	currentSpeed = keepRunning and Config.Speeds.Sprint or Config.Speeds.Walk
end

-- A slide finished within the last `window` seconds (Q right after it still counts as sliding in)
function controller.SlideEndedRecently(window: number): boolean
	return os.clock() - lastSlideEnd <= window
end

-- Q mid-slide (CoverController calls this): end the slide in cover
function controller.QueueSlideCover(): boolean
	if not sliding then return false end
	sliding.wantCover = true
	return true
end

local function updateSlide(): boolean
	local s = sliding
	if not s then return false end
	local hum, root = humanoid :: Humanoid, rootPart :: BasePart
	local S = Config.Slide
	local elapsed = os.clock() - s.start
	local a = math.clamp(elapsed / S.Time, 0, 1)
	local speed = S.Speed + (S.EndSpeed - S.Speed) * (a ^ 0.7)
	local actual = (root.AssemblyLinearVelocity * FLAT).Magnitude
	if a >= 1 or (elapsed > 0.15 and actual < 2.5) then -- done, or ran into something
		endSlide()
		return true
	end
	hum.WalkSpeed = speed
	hum:Move(s.dir, false)
	return true
end

function controller.IsSliding(): boolean
	return sliding ~= nil
end

-- // Per frame
-- Heavier guns slow you down (WeaponConfig MoveSpeed), and more so while aiming (AimMoveSpeed)
local WeaponConfig = require(ReplicatedStorage.Modules.Shared.Config.WeaponConfig)
local function weaponSpeedScale(character: Model?): number
	local tool = character and character:FindFirstChildOfClass("Tool")
	local config = tool and WeaponConfig.Get(tool:GetAttribute("WeaponId") or "")
	if not config then return 1 end
	local scale = config.MoveSpeed or 1
	if CameraController and CameraController.IsAiming and CameraController.IsAiming() then
		scale *= config.AimMoveSpeed or 1
	end
	return scale
end

local function update(dt: number)
	updateStaminaBar()
	if not isAlive() then
		sprinting = false
		return
	end
	local hum = humanoid :: Humanoid
	local St = Config.Stamina

	-- Regenerate
	if os.clock() - lastStaminaUse > St.RegenDelay then
		stamina = math.min(St.Max, stamina + St.Regen * dt)
	end
	if exhausted and stamina >= St.MinToStart then exhausted = false end
	if updateSlide() then return end
	if localPlayer:GetAttribute("Cutscene") then setPose(nil) return end -- a cutscene is driving you

	local shiftDown = wantsSprint() and UserInputService:GetFocusedTextBox() == nil -- [SET]
	if not shiftDown then sprintBlocked = false end
	-- [SET] with Auto / Toggle Sprint the key isn't held: a block from firing / aiming wears off after a moment
	if sprintBlocked and not isDown(Binds.Key(localPlayer, "Sprint", Config.Keybinds.Sprint)) and os.clock() - sprintBlockedAt > 0.8
		and not (CameraController and CameraController.IsAiming()) then
		sprintBlocked = false
	end

	-- Cover owns movement while you're in it / moving between covers
	if CoverController and (CoverController.IsInCover() or CoverController.IsMoving()) then
		sprinting = false
		setPose(nil)
		local adminSpeed = localPlayer:GetAttribute("AdminSpeed") -- keep currentSpeed unscaled (see the WalkSpeed line below)
		currentSpeed = hum.WalkSpeed / (type(adminSpeed) == "number" and adminSpeed > 0 and adminSpeed / Config.Speeds.Walk or 1)
		return
	end
	local aiming = CameraController and CameraController.IsAiming()
	if aiming then sprintBlocked = true; sprintBlockedAt = os.clock(); sprintToggled = false end
	local moving = hum.MoveDirection.Magnitude > 0.1
	if not moving then sprintToggled = false end -- [SET] Toggle Sprint ends when you stop

	local target
	sprinting = false
	-- no sprint-crawling: Shift while crouched (and moving) stands you straight up into a run
	if crouched and shiftDown and moving and not sprintBlocked then
		setCrouched(false)
	end
	if crouched then
		target = Config.Speeds.Crouch
	else
		if shiftDown and moving and not sprintBlocked and not exhausted and stamina > 0 then
			sprinting = true
			target = Config.Speeds.Sprint
			stamina = math.max(0, stamina - St.SprintDrain * dt)
			lastStaminaUse = os.clock()
			if stamina <= 0 then exhausted = true end
		else
			target = Config.Speeds.Walk
		end
	end

	-- Ease between speeds (no instant jumps when switching modes)
	local step = Config.SpeedChangeRate * dt
	if currentSpeed < target then currentSpeed = math.min(target, currentSpeed + step)
	else currentSpeed = math.max(target, currentSpeed - step) end
	-- stunned (flashbang): everything is slower
	local stunScale = (localPlayer:GetAttribute("StunUntil") or 0) > os.clock() and (localPlayer:GetAttribute("StunScale") or 1) or 1
	-- [SET] admin ;speed: the AdminSpeed attribute replaces the base walk speed (sprint / crouch scale with it)
	local adminSpeed = localPlayer:GetAttribute("AdminSpeed")
	local adminScale = type(adminSpeed) == "number" and adminSpeed > 0 and adminSpeed / Config.Speeds.Walk or 1
	hum.WalkSpeed = currentSpeed * stunScale * weaponSpeedScale(hum.Parent) * adminScale

	-- Crouch poses (legs only; the gun arms keep doing their thing)
	if crouched then
		local speedNow = (rootPart :: BasePart).AssemblyLinearVelocity * FLAT
		if moving and speedNow.Magnitude > 1 then
			setPose("CrouchWalk", speedNow.Magnitude / Config.CrouchWalkAnimSpeed)
		else
			setPose("CrouchIdle")
		end
	else
		setPose(nil)
	end
end

-- // Input
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	-- [SET] Toggle Sprint: tap your Sprint key to start / stop running
	if Binds.Matches(localPlayer, "Sprint", input, Config.Keybinds.Sprint) and localPlayer:GetAttribute("Setting_ToggleSprint") == true then
		sprintToggled = not sprintToggled
	end
	-- [SET] the Slide key slides while sprinting, whatever Easy Slide says
	local slideKey = Binds.Key(localPlayer, "Slide", nil)
	if slideKey and Binds.Matches(localPlayer, "Slide", input, nil) then
		if isAlive() and sprinting and not crouched and not sliding and os.clock() - lastSlide > Config.Slide.Cooldown
			and not (CoverController and (CoverController.IsInCover() or CoverController.IsMoving())) then
			startSlide()
		end
		return
	end
	-- your Crouch bind (C by default) or Ctrl crouches / slides
	local isCrouchKey = Binds.Matches(localPlayer, "Crouch", input, Config.Keybinds.Crouch) or input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl
	if not isCrouchKey then return end
	if not isAlive() then return end
	-- In cover, C is the cover crouch (CoverController handles it)
	if CoverController and (CoverController.IsInCover() or CoverController.IsMoving()) then return end
	if sliding then return end
	-- sprinting: C slides instead of crouching ([SET] unless Easy Slide is off)
	if sprinting and not crouched and os.clock() - lastSlide > Config.Slide.Cooldown and localPlayer:GetAttribute("Setting_EasySlide") ~= false then
		startSlide()
		return
	end
	-- [SET] Toggle Crouch off = hold to crouch (let go to stand, see onInputEnded)
	if localPlayer:GetAttribute("Setting_ToggleCrouch") == false then setCrouched(true) return end
	setCrouched(not crouched)
end

-- [SET] hold-to-crouch: letting go of the key stands you up
local function onInputEnded(input: InputObject)
	if localPlayer:GetAttribute("Setting_ToggleCrouch") ~= false then return end
	local isCrouchKey = Binds.Matches(localPlayer, "Crouch", input, Config.Keybinds.Crouch) or input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl
	if not isCrouchKey or not crouched then return end
	if CoverController and (CoverController.IsInCover() or CoverController.IsMoving()) then return end
	setCrouched(false)
end

local function bindCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	tracks = nil
	if sliding then sliding = nil local c = getControls() if c then c:Enable() end end
	crouched = false
	sprinting = false
	stamina = Config.Stamina.Max
	exhausted = false
	currentSpeed = Config.Speeds.Walk
	if humanoid then humanoid.WalkSpeed = Config.Speeds.Walk end
end

-- // Public
function controller.IsCrouched(): boolean
	return crouched
end

function controller.IsSprinting(): boolean
	return sprinting
end

-- CoverController keeps your stance in step with cover: you take a crouch into cover with you, C in
-- cover crouches / stands you, and stepping out of cover always stands you back up.
function controller.SetCrouched(value: boolean)
	setCrouched(value)
end

-- Called when firing: drop to walk speed; sprint resumes only after Shift is pressed again
function controller.StopSprint()
	sprintBlocked = true
	sprintBlockedAt = os.clock() -- [SET]
	sprintToggled = false
	if sprinting and humanoid then
		sprinting = false
		currentSpeed = crouched and Config.Speeds.Crouch or Config.Speeds.Walk
		humanoid.WalkSpeed = currentSpeed
	end
end

-- Called by CoverController when a vault lands: stand up, and carry straight on at full
-- walk/sprint speed instead of easing up from zero. Returns the speed to carry.
function controller.OnVaultLanded(): number
	setCrouched(false)
	local shiftDown = wantsSprint() -- [SET]
	currentSpeed = (shiftDown and not sprintBlocked) and Config.Speeds.Sprint or Config.Speeds.Walk
	if humanoid then humanoid.WalkSpeed = currentSpeed end
	return currentSpeed
end

-- Called by CoverController when Shift + a movement key breaks cover: you come out already sprinting
function controller.OnCoverBroken()
	sprintBlocked = false
	setCrouched(false)
	if exhausted or stamina <= 0 then
		currentSpeed = Config.Speeds.Walk
	else
		sprinting = true
		currentSpeed = Config.Speeds.Sprint
	end
	if humanoid then humanoid.WalkSpeed = currentSpeed end
end

function controller.GetStamina(): number
	return stamina
end

function controller.Start()
	CoverController = Get("CoverController")
	CameraController = Get("CameraController")
	buildStaminaBar()
	if localPlayer.Character and __TG.On() then task.spawn(bindCharacter, localPlayer.Character) end
	__TG.CharacterAdded:Connect(bindCharacter)
	UserInputService.InputBegan:Connect(onInputBegan)
	-- [TOUCH] mobile: the Crouch button = your crouch key (same rules: slide when sprinting, toggle / hold);
	-- the Slide button slides while you're running
	task.spawn(function()
		local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		local function crouchInput(state)
			local k = Binds.Key(localPlayer, "Crouch", Config.Keybinds.Crouch)
			return { KeyCode = (typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode) and k or Enum.KeyCode.C, UserInputType = Enum.UserInputType.Keyboard, UserInputState = state }
		end
		IA.Bind("Crouch", function(state)
			if state == Enum.UserInputState.Begin then onInputBegan(crouchInput(state), false) else onInputEnded(crouchInput(state)) end
		end)
		IA.Bind("Slide", function(state)
			if state ~= Enum.UserInputState.Begin or not isAlive() or crouched or sliding or os.clock() - lastSlide <= Config.Slide.Cooldown then return end
			if CoverController and (CoverController.IsInCover() or CoverController.IsMoving()) then return end
			local root = humanoid and humanoid.RootPart
			local speed = root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
			if sprinting or speed > 12 then startSlide() end
		end)
	end)
	UserInputService.InputEnded:Connect(onInputEnded) -- [SET] hold-to-crouch
	RunService.Heartbeat:Connect(update)
end

return controller
