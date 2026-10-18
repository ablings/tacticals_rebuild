-- StarterPlayerScripts.LobbyMovement (LocalScript, hub + the match places' after-match lobby) [LOBBYMOVE] 2026-10-18, Edward:
-- "an in lobby movement system that allows the player to slide in lobby for speed and also jump but they should also be
-- faster in the lobby themselves".
-- Only while you're in the lobby itself: the hub (Workspace.LobbyMap from the start) or the after-match lobby (InPseudoLobby),
-- and never in Training / a duel / a match / a cutscene (the combat MovementController owns movement there).
--   Faster:  walk Speeds.Walk (Roblox's default is 16), hold Sprint (Shift / your Sprint bind) for Speeds.Run. No stamina.
--   Slide:   C / Ctrl / gamepad B / a touch button (fire the SlideRequest BindableEvent under this script) while moving on the
--            ground: a burst to Slide.Speed easing back over Slide.Time, low on the hip (the match slide's pose), a scrape.
--            You keep steering (controls are never disabled, so held keys never get lost).
--   Jump:    JumpHeight Jump.Height. Jumping out of a slide keeps the slide's speed until you land (slide-jumps chain).
-- Speed is only written while this script owns it: if something else changed WalkSpeed (the Armory's 0, a cutscene, ...)
-- it is left alone until it comes back to ours or to Roblox's default. Admin ;speed (AdminSpeed attribute) scales it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = {
	Speeds = { Walk = 22, Run = 28 },
	Slide = { Speed = 46, Time = 0.9, Cooldown = 0.5, MinMove = 4 },
	Jump = { Height = 8 },
	Ease = 70, -- studs/s per second back toward the walk / run speed
}

local player = Players.LocalPlayer
local IS_HUB = workspace:FindFirstChild("LobbyMap") ~= nil and ReplicatedStorage:GetAttribute("PseudoLobbyMap") == nil
local DEFAULT_WALK = game:GetService("StarterPlayer").CharacterWalkSpeed

local humanoid, root = nil, nil
local lastSet = nil       -- the WalkSpeed this script last wrote (nil = not owning it)
local speed = C.Speeds.Walk
local slide = nil         -- { t0, peak } while sliding
local lastSlide = 0
local airSpeed = nil      -- speed carried through a jump out of a slide
local slideTrack = nil

local request = script:FindFirstChild("SlideRequest") or Instance.new("BindableEvent")
request.Name = "SlideRequest"
request.Parent = script

local function active(): boolean
	if not (humanoid and root and humanoid.Health > 0) then return false end
	for _, a in { "InTraining", "InDuel", "InMatch", "Cutscene", "InCutscene", "Deploying" } do
		if player:GetAttribute(a) == true then return false end
	end
	if IS_HUB then return true end
	return player:GetAttribute("InPseudoLobby") == true
end

local function scale(): number
	local admin = player:GetAttribute("AdminSpeed")
	return (type(admin) == "number" and admin > 0) and admin / DEFAULT_WALK or 1
end

local function sprintHeld(): boolean
	if UserInputService:GetFocusedTextBox() then return false end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then return true end
	local ok, pressed = pcall(UserInputService.IsGamepadButtonDown, UserInputService, Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL3)
	return ok and pressed == true
end

local function loadSlidePose()
	if slideTrack or not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	local src = repo and repo:FindFirstChild("AnimationSources") and repo.AnimationSources:FindFirstChild("MoveSlide")
	local id = src and src:GetAttribute("PublishedId")
	if not (animator and id) then return end
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, track = pcall(animator.LoadAnimation, animator, a)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		slideTrack = track
	end
end

local function grounded(): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function startSlide()
	if not active() or slide then return end
	if os.clock() - lastSlide < C.Slide.Cooldown then return end
	if not grounded() or humanoid.MoveDirection.Magnitude < 0.1 then return end
	local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if flat.Magnitude < C.Slide.MinMove then return end
	if lastSet == nil and humanoid.WalkSpeed ~= DEFAULT_WALK then return end -- something else owns movement right now
	slide = { t0 = os.clock(), peak = C.Slide.Speed }
	lastSlide = os.clock()
	airSpeed = nil
	loadSlidePose()
	if slideTrack then slideTrack:Play(0.12) end
	local scrape = Instance.new("Sound")
	scrape.SoundId = "rbxassetid://12222216"
	scrape.Volume = 0.25
	scrape.PlaybackSpeed = 0.6
	scrape.Parent = root
	scrape:Play()
	game:GetService("Debris"):AddItem(scrape, 2)
end

local function endSlide()
	slide = nil
	if slideTrack then slideTrack:Stop(0.2) end
end

local function bind(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
	slide, airSpeed, slideTrack, lastSet = nil, nil, nil, nil
	speed = C.Speeds.Walk
	if not humanoid then return end
	humanoid.StateChanged:Connect(function(_, new)
		-- a jump out of a slide keeps the slide's speed in the air
		if new == Enum.HumanoidStateType.Jumping and slide then
			airSpeed = speed
			endSlide()
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			if airSpeed then speed = airSpeed end -- land carrying it, then ease down (or slide again)
			airSpeed = nil
		end
	end)
end

player.CharacterAdded:Connect(bind)
if player.Character then task.spawn(bind, player.Character) end

request.Event:Connect(startSlide)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.C or k == Enum.KeyCode.LeftControl or k == Enum.KeyCode.ButtonB then startSlide() end
end)

RunService.Heartbeat:Connect(function(dt)
	if not active() then
		if slide then endSlide() end
		-- hand the speed back once (Roblox's default), only if it's still ours
		if lastSet and humanoid and humanoid.Parent and math.abs(humanoid.WalkSpeed - lastSet) < 0.01 then
			humanoid.WalkSpeed = DEFAULT_WALK
			humanoid.JumpHeight = 7.2
		end
		lastSet = nil
		return
	end
	-- someone else changed WalkSpeed (Armory 0, ...): leave it until it's back to ours or Roblox's default
	if lastSet and math.abs(humanoid.WalkSpeed - lastSet) > 0.01 and math.abs(humanoid.WalkSpeed - DEFAULT_WALK) > 0.01 then
		lastSet = nil
		if slide then endSlide() end
		return
	end
	if lastSet == nil and math.abs(humanoid.WalkSpeed - DEFAULT_WALK) > 0.01 then return end

	local base = (sprintHeld() and C.Speeds.Run or C.Speeds.Walk)
	if slide then
		local a = math.clamp((os.clock() - slide.t0) / C.Slide.Time, 0, 1)
		speed = slide.peak + (base - slide.peak) * (a ^ 0.8)
		local flat = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if a >= 1 or humanoid.MoveDirection.Magnitude < 0.1 or (os.clock() - slide.t0 > 0.15 and flat < 3) then endSlide() end
	elseif airSpeed and not grounded() then
		speed = airSpeed -- keep the slide-jump's speed until landing
	else
		if speed > base then speed = math.max(base, speed - C.Ease * dt) else speed = math.min(base, speed + C.Ease * dt) end
	end
	local ws = speed * scale()
	humanoid.WalkSpeed = ws
	lastSet = ws
	if humanoid.UseJumpPower then humanoid.UseJumpPower = false end
	if humanoid.JumpHeight ~= C.Jump.Height and humanoid.JumpHeight > 0 then humanoid.JumpHeight = C.Jump.Height end
end)
