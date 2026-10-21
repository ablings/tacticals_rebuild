-- StarterPlayer/StarterPlayerScripts/Client/Controllers/TutorialController (ModuleScript)
-- Client half of the tutorial (TutorialManager runs the script on the server):
--   * shows each line at the bottom of the screen, with an objective tag when it's waiting on you
--   * highlights the cover you should move to
--   * watches for the action the current step asks for and reports it
-- Keys (lobby, alone; any time in Studio): T = start tutorial, B = spawn a practice AI opponent.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TutorialConfig"))
local Audio = require(ReplicatedStorage.Modules.Shared.Config:WaitForChild("AudioConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Tutorial")
local PracticeRemote = ReplicatedStorage.Events:WaitForChild("Bot"):WaitForChild("RequestPractice")

local localPlayer = Players.LocalPlayer
local Get = shared.Get
local controller = {}

-- // State
local waitFor: string? = nil
local highlightPart: BasePart? = nil
local highlightBox: SelectionBox? = nil
local highlightTag: BillboardGui? = nil
local active = false
local snapshot = {} -- values captured when the current prompt appeared
local sawMoving = false
local wasInCover = false

-- // Control lock: during the tutorial you can only do what the current step tells you.
-- WASD always works while in cover (shuffle/peek); out of cover you can't walk unless allowed ("Move").
-- Q always works out of cover so you can get back into it.
local allowed = {} -- set of "Q" | "E" | "G" | "Aim" | "Shoot" | "Move"
local lockKey = ""
local LOCKS = {
	Q = { Enum.KeyCode.Q },
	E = { Enum.KeyCode.E, Enum.KeyCode.LeftShift }, -- E sneaks to cover, Shift+E rushes
	G = { Enum.KeyCode.G },
	Aim = { Enum.UserInputType.MouseButton2 },
	Shoot = { Enum.UserInputType.MouseButton1 },
	Move = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right },
	Vault = { Enum.KeyCode.Space },
	Crouch = { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	Melee = { Enum.KeyCode.Two, Enum.KeyCode.F }, -- hotbar: 1 gun, 2 melee, 3 gadget
	Gadget2 = { Enum.KeyCode.Three },
	Reload = { Enum.KeyCode.R },
}
local reloadLocked = false -- tutorial 1: R does nothing until the reload lesson
local ALWAYS_LOCKED = { Enum.KeyCode.Z, Enum.KeyCode.One }

local function sink() return Enum.ContextActionResult.Sink end

local function updateLock(inCover: boolean)
	-- S (walking away from the wall) leaves cover too: same rule as Q
	-- (a step that lets you move also lets Shift + a movement key break you out of cover cleanly, even when
	-- Q itself is locked - e.g. the slide lesson)
	localPlayer:SetAttribute("CoverLeaveLocked", active and not (allowed.Q or allowed.Move) or nil)
	local key = ""
	local inputs = {}
	if active then
		for name, list in LOCKS do
			local open = allowed[name]
				or (name == "Move" and inCover)
				or (name == "Q" and not inCover)
				or (name == "Shoot" and (allowed.Melee or allowed.G)) -- left click also swings melee / throws from slot 2
				or (name == "Gadget2" and allowed.G)
				or (name == "Reload" and not reloadLocked)
			if not open then
				key ..= name
				for _, input in list do table.insert(inputs, input) end
			end
		end
		for _, input in ALWAYS_LOCKED do table.insert(inputs, input) end
		if not allowed.Move and not allowed.E and not allowed.Vault then table.insert(inputs, Enum.KeyCode.LeftShift) end
		key ..= "|locked"
	end
	if key == lockKey then return end
	lockKey = key
	ContextActionService:UnbindAction("TutorialLock")
	if #inputs > 0 then
		ContextActionService:BindActionAtPriority("TutorialLock", sink, false, 4000, table.unpack(inputs))
	end
end

-- // UI
-- Builderman's panel: rounded dark glass with chunky Builder Sans type. Lines pop in, keys like [Q] light
-- up blue, CAPS words punch out in bold white. Danger lines (TutorialConfig.Alerts) SLAM a big red
-- headline onto the screen with a red flash and a shake.
local UI_FONT = "rbxasset://fonts/families/BuilderSans.json"
local F_BODY = Font.new(UI_FONT, Enum.FontWeight.Medium)
local F_BOLD = Font.new(UI_FONT, Enum.FontWeight.Bold)
local F_HEAVY = Font.new(UI_FONT, Enum.FontWeight.ExtraBold)
local BLUE = Color3.fromRGB(124, 200, 255)
local ALERT_RED = Color3.fromRGB(255, 64, 70)
local PANEL_POS = UDim2.fromScale(0.5, 0.82) -- [HUDFIT] above the hotbar on any screen (was 66 px from the bottom: covered the item tiles on phones)
local gui, panel, lineLabel, objectiveLabel
local panelScale, portraitScale, panelStroke
local headline, headScale, headStroke, flash
local thump: Sound? = nil
local typeSounds: { Sound } = {} -- created in buildUI
local confirmSound: Sound? = nil
local barTop, barBottom
local function stroke(parent, color, thick, transparency)
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thick
	st.Transparency = transparency
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = parent
	return st
end
local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = PANEL_POS -- between the health bar (left) and the item tiles (right)
	panel.Size = UDim2.fromOffset(660, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y -- grows to fit the line
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 13)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = panel
	panelStroke = stroke(panel, Color3.new(1, 1, 1), 1.5, 0.86)
	panelScale = Instance.new("UIScale"); panelScale.Parent = panel
	local minH = Instance.new("UISizeConstraint"); minH.MinSize = Vector2.new(0, 92); minH.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 84), UDim.new(0, 22)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 16)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = panel

	-- Who's talking: a round portrait popping out of the panel's top-left corner, name tag beside it
	local who = Config.Instructor or {}
	local holder = Instance.new("Frame") -- (outside the list: positioned by hand)
	holder.Name = "Speaker"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = gui
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.AnchorPoint = Vector2.new(0.5, 0.5)
	portrait.Size = UDim2.fromOffset(68, 68)
	portrait.BackgroundColor3 = Color3.fromRGB(28, 29, 34)
	portrait.Image = who.Image or ""
	portrait.ZIndex = 5
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(1, 0) pc.Parent = portrait
	stroke(portrait, BLUE, 3, 0)
	portraitScale = Instance.new("UIScale"); portraitScale.Parent = portrait
	portrait.Parent = panel
	portrait.Position = UDim2.fromOffset(-84 + 14 + 26, 4) -- sits over the panel's left edge
	-- (UIListLayout ignores nothing, so keep the portrait out of it)
	portrait.Parent = gui
	if (who.Image or "") == "" and who.UserId then
		task.spawn(function()
			local ok, image = pcall(Players.GetUserThumbnailAsync, Players, who.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok and image then portrait.Image = image end
		end)
	end
	local nameTag = Instance.new("TextLabel")
	nameTag.Name = "SpeakerName"
	nameTag.BackgroundColor3 = BLUE
	nameTag.AutomaticSize = Enum.AutomaticSize.X
	nameTag.Size = UDim2.fromOffset(0, 24)
	nameTag.FontFace = F_HEAVY
	nameTag.TextSize = 15
	nameTag.TextColor3 = Color3.fromRGB(10, 14, 22)
	nameTag.Text = string.upper(who.Name or "Instructor")
	nameTag.ZIndex = 4
	local np = Instance.new("UIPadding") np.PaddingLeft = UDim.new(0, 40) np.PaddingRight = UDim.new(0, 12) np.Parent = nameTag
	local nc = Instance.new("UICorner") nc.CornerRadius = UDim.new(1, 0) nc.Parent = nameTag
	nameTag.Parent = gui
	-- keep the portrait + name tag glued to the panel's top-left corner (the panel grows with its line)
	game:GetService("RunService").RenderStepped:Connect(function()
		if not gui.Enabled then return end
		local p, sz = panel.AbsolutePosition, panel.AbsoluteSize
		local inset = game:GetService("GuiService"):GetGuiInset()
		local _ = inset
		portrait.Position = UDim2.fromOffset(p.X + 38, p.Y + 8)
		nameTag.Position = UDim2.fromOffset(p.X + 30, p.Y - 26)
		portrait.Visible, nameTag.Visible = panel.Visible, panel.Visible
		local _ = sz
	end)

	objectiveLabel = Instance.new("TextLabel")
	objectiveLabel.Name = "Objective"
	objectiveLabel.LayoutOrder = 1
	objectiveLabel.BackgroundColor3 = BLUE
	objectiveLabel.BackgroundTransparency = 0.82
	objectiveLabel.AutomaticSize = Enum.AutomaticSize.X
	objectiveLabel.Size = UDim2.fromOffset(0, 22)
	objectiveLabel.FontFace = F_HEAVY
	objectiveLabel.TextSize = 14
	objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectiveLabel.TextColor3 = BLUE
	objectiveLabel.Text = ""
	objectiveLabel.Visible = false
	local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(1, 0) oc.Parent = objectiveLabel
	local op = Instance.new("UIPadding") op.PaddingLeft = UDim.new(0, 10) op.PaddingRight = UDim.new(0, 10) op.Parent = objectiveLabel
	objectiveLabel.Parent = panel

	lineLabel = Instance.new("TextLabel")
	lineLabel.Name = "Line"
	lineLabel.LayoutOrder = 2
	lineLabel.BackgroundTransparency = 1
	lineLabel.AutomaticSize = Enum.AutomaticSize.Y
	lineLabel.Size = UDim2.new(1, 0, 0, 26)
	lineLabel.FontFace = F_BODY
	lineLabel.TextSize = 22
	lineLabel.LineHeight = 1.05
	lineLabel.RichText = true
	lineLabel.TextWrapped = true
	lineLabel.TextXAlignment = Enum.TextXAlignment.Left
	lineLabel.TextYAlignment = Enum.TextYAlignment.Top
	lineLabel.TextColor3 = Color3.fromRGB(226, 229, 236)
	lineLabel.Text = ""
	lineLabel.Parent = panel

	-- danger: the slam headline and a red flash over the whole screen
	flash = Instance.new("Frame")
	flash.Name = "AlertFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = ALERT_RED
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	local fg = Instance.new("UIGradient") -- red round the edges, clear in the middle
	fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.85),
		NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 0) })
	fg.Parent = flash
	flash.Parent = gui
	headline = Instance.new("TextLabel")
	headline.Name = "Alert"
	headline.AnchorPoint = Vector2.new(0.5, 0.5)
	headline.Position = UDim2.fromScale(0.5, 0.3)
	headline.Size = UDim2.new(0.9, 0, 0, 90)
	headline.BackgroundTransparency = 1
	headline.FontFace = F_HEAVY
	headline.TextSize = 72
	headline.TextColor3 = ALERT_RED
	headline.TextTransparency = 1
	headline.Text = ""
	headline.ZIndex = 30
	headStroke = stroke(headline, Color3.fromRGB(40, 0, 4), 4, 1)
	headScale = Instance.new("UIScale"); headScale.Parent = headline
	headline.Parent = gui

	-- cinematic letterbox bars (slide in while the camera is directing your eye)
	local function bar(top)
		local f = Instance.new("Frame")
		f.Name = top and "BarTop" or "BarBottom"
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 0.09, 0)
		f.AnchorPoint = Vector2.new(0, top and 1 or 0)
		f.Position = UDim2.fromScale(0, top and 0 or 1) -- hidden off-screen
		f.ZIndex = 0
		f.Parent = gui
		return f
	end
	barTop, barBottom = bar(true), bar(false)
	-- UI sounds: plain Sound objects inside the ScreenGui (2D, always audible), loaded once and
	-- simply :Play()ed. A few copies of the tick take turns so fast typing never cuts one off.
	for i = 1, 4 do
		local snd = Instance.new("Sound")
		snd.Name = "TypeTick" .. i
		snd.SoundId = Audio.TypingSound
		snd.Volume = Audio.TypingVolume
		snd.Parent = gui
		table.insert(typeSounds, snd)
	end
	confirmSound = Instance.new("Sound")
	confirmSound.Name = "Confirm"
	confirmSound.SoundId = Audio.ConfirmSound
	confirmSound.Volume = Audio.ConfirmVolume
	confirmSound.Parent = gui
	thump = Instance.new("Sound")
	thump.Name = "Slam"
	thump.SoundId = "rbxassetid://12222216"
	thump.Volume = 0.8
	thump.PlaybackSpeed = 0.42
	thump.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local barsShown = false
local function setBars(on: boolean)
	if on == barsShown or not barTop then return end
	barsShown = on
	local info = TweenInfo.new(on and 0.45 or 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(barTop, info, { AnchorPoint = Vector2.new(0, on and 0 or 1) }):Play()
	TweenService:Create(barBottom, info, { AnchorPoint = Vector2.new(0, on and 1 or 0) }):Play()
end

-- Point the camera at what the line is talking about
-- The finishing shot: a beat of "slow motion" feel - the world drains of colour, sound dips, a stamp
local function killcam()
	local Lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Killcam"
	cc.Saturation = -0.85
	cc.Contrast = 0.25
	cc.TintColor = Color3.fromRGB(255, 236, 225)
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "KillcamBlur"
	blur.Size = 6
	blur.Parent = Lighting
	local world = game:GetService("SoundService"):FindFirstChild("World")
	if world and world:IsA("SoundGroup") then
		world.Volume = 0.35
		TweenService:Create(world, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 1 }):Play()
	end
	local stamp = Instance.new("TextLabel")
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.42)
	stamp.Size = UDim2.fromOffset(520, 70)
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.GothamBlack
	stamp.Text = "ELIMINATED"
	stamp.TextSize = 54
	stamp.TextColor3 = Color3.fromRGB(255, 70, 60)
	stamp.TextStrokeTransparency = 0.4
	stamp.TextTransparency = 1
	stamp.Rotation = -4
	local scale = Instance.new("UIScale") scale.Scale = 1.6 scale.Parent = stamp
	stamp.Parent = gui
	TweenService:Create(stamp, TweenInfo.new(0.18, Enum.EasingStyle.Back), { TextTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.4, function()
		TweenService:Create(cc, TweenInfo.new(0.9), { Saturation = 0, Contrast = 0 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.9), { Size = 0 }):Play()
		TweenService:Create(stamp, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1, function() cc:Destroy() blur:Destroy() stamp:Destroy() end)
	end)
end

-- Black fade with a title card (used for the cut between tutorials)
local fadeFrame, fadeTitle
local function fade(mode: string, title: string?)
	if not fadeFrame then
		fadeFrame = Instance.new("Frame")
		fadeFrame.Size = UDim2.fromScale(1, 1)
		fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.BorderSizePixel = 0
		fadeFrame.ZIndex = 50
		fadeFrame.Parent = gui
		fadeTitle = Instance.new("TextLabel")
		fadeTitle.AnchorPoint = Vector2.new(0.5, 0.5)
		fadeTitle.Position = UDim2.fromScale(0.5, 0.5)
		fadeTitle.Size = UDim2.new(0.8, 0, 0, 80)
		fadeTitle.BackgroundTransparency = 1
		fadeTitle.Font = Enum.Font.GothamMedium
		fadeTitle.TextSize = 26
		fadeTitle.TextWrapped = true
		fadeTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
		fadeTitle.TextTransparency = 1
		fadeTitle.ZIndex = 51
		fadeTitle.Parent = gui
	end
	gui.Enabled = true
	if mode == "in" then
		fadeTitle.Text = title or ""
		TweenService:Create(fadeFrame, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
		task.delay(0.7, function()
			TweenService:Create(fadeTitle, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		end)
	else
		TweenService:Create(fadeTitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(1.4, function()
			TweenService:Create(fadeFrame, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		end)
	end
end

-- Opening cutscene (placeholder): after the stand-off you scramble back to your spawn cover on your own
local cutsceneActive = false
local openingGo = false
local function playOpening(payload)
	cutsceneActive = true
	openingGo = false
	localPlayer:SetAttribute("Cutscene", true) -- MovementController keeps its hands off your speed
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not root then cutsceneActive = false localPlayer:SetAttribute("Cutscene", nil) return end
	local PlayerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Disable()
	-- go the moment he does (the server says when), so you both get to your pillars together
	local tGo = os.clock()
	while not openingGo and os.clock() - tGo < (payload.runAfter or 2) + 2.5 do task.wait() end
	-- break for cover: sprint back along the route, then dive in
	local points = table.clone(payload.runRoute or {})
	if payload.runTo then table.insert(points, payload.runTo.Position) end
	local runSpeed = payload.runSpeed or 22 -- the server times his run to match this, so you arrive together
	hum.WalkSpeed = runSpeed
	hum.AutoRotate = true
	-- the roll (same placeholder the cover system uses)
	local rollTrack
	local animator = hum:FindFirstChildOfClass("Animator")
	local src = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository.AnimationSources:FindFirstChild("CoverRoll")
	-- (pass 40) published to the group: use its id; Studio preview otherwise
	if animator and src and (src:GetAttribute("PublishedId") or game:GetService("RunService"):IsStudio()) then
		local ok, id = true, src:GetAttribute("PublishedId")
		if not id then ok, id = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(src) end) end
		if ok then
			local anim = Instance.new("Animation") anim.AnimationId = id
			local ok2, tr = pcall(animator.LoadAnimation, animator, anim)
			if ok2 then tr.Priority = Enum.AnimationPriority.Action4 rollTrack = tr end
		end
	end
	-- keep level with his progress: total route length, and how much of it is left from where you are
	local routeLen, prevP = 0, root.Position
	for _, q in points do routeLen += ((q - prevP) * Vector3.new(1, 0, 1)).Magnitude prevP = q end
	routeLen = math.max(routeLen, 1)
	local function leftFrom(index: number): number
		local d, from = 0, root.Position
		for k = index, #points do
			d += ((points[k] - from) * Vector3.new(1, 0, 1)).Magnitude
			from = points[k]
		end
		return d
	end
	local bossModel = workspace:FindFirstChild(Config.BossName)
	for i, p in points do
		if i == #points - 1 then
			-- a running hop on the way in
			root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, 26, 0)
		elseif i == #points then
			-- ...and roll into the cover. You're round the pillar now
			hum.WalkSpeed = runSpeed
			if rollTrack then rollTrack:Play(0.05) end
			Remotes.Progress:FireServer("OpeningAround")
		end
		local reached = false
		local reachConn = hum.MoveToFinished:Once(function() reached = true end)
		hum:MoveTo(p)
		local t0 = os.clock()
		while not reached and os.clock() - t0 < 2.5 and ((root.Position - p) * Vector3.new(1, 0, 1)).Magnitude > 1.6 do
			local bossFrac = bossModel and bossModel.Parent and bossModel:GetAttribute("RunFrac")
			if bossFrac then
				local mine = 1 - leftFrom(i) / routeLen
				-- ahead of him: ease off; behind: push on (and once he's in, just get there)
				local k = bossFrac >= 1 and 1.25 or math.clamp(1 + 2 * (bossFrac - mine), 0.8, 1.25)
				hum.WalkSpeed = runSpeed * k
			end
			task.wait()
		end
		reachConn:Disconnect()
	end
	if payload.runTo then root.CFrame = payload.runTo end
	hum:MoveTo(root.Position)
	controls:Enable()
	local Cover = Get("CoverController")
	for _ = 1, 10 do
		if Cover and Cover.TryEnterCover() then break end
		task.wait(0.1)
	end
	cutsceneActive = false
	localPlayer:SetAttribute("Cutscene", nil)
	Remotes.Progress:FireServer("OpeningDone")
end

local function directCamera(payload)
	local Camera = Get("CameraController")
	if not Camera or not Camera.Guide or payload.focus == nil then return end
	local focus = payload.focus
	if typeof(focus) == "table" and focus.feet then
		local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local cam = workspace.CurrentCamera.CFrame
		local look = cam.LookVector * Vector3.new(1, 0, 1)
		local right = cam.RightVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.zero
		right = right.Magnitude > 0.1 and right.Unit or Vector3.zero
		-- just off to the side (default right), so the cloud doesn't swallow the view ahead
		focus = root.Position + look * 2 + right * 3.5 * (focus.side or 1) - Vector3.new(0, 3, 0)
	end
	local duration = payload.focusTime or 1.1
	local follow = payload.follow or 0
	-- keep the camera (and so the mouse) on the shot until the line has finished typing out
	local text = payload.line and (Config.Lines[payload.line] or (Config.Lines2 and payload.line) or payload.line) or ""
	follow = math.max(follow, #tostring(text) * (Config.TypeSpeed or 0.03) + 0.35 - duration)
	Camera.Guide(focus, duration, follow)
	if payload.cinematic then
		setBars(true)
		task.delay(duration + math.max(follow, 0.6), function() setBars(false) end)
	end
end

local typeToken = 0
local tickIndex = 0
local typingDoneAt = 0
local pendingAllow = nil -- the step's unlocked actions wait until the line has fully typed out
local pendingAuto = nil  -- a scripted move the game performs for you once the line has typed out
local lightKeys: ((names: { string }) -> ())? = nil -- set further down (presses keys in the line for show)
local function runAuto(auto)
	local Cover = Get("CoverController")
	if not Cover then return end
	task.delay(auto.delay or 0.5, function()
		if not active then return end
		for _ = 1, 8 do -- retry briefly: a move/vault may still be finishing
			local done = false
			if auto.rush and Cover.ForceRush then done = Cover.ForceRush(auto.rush, auto.standAt)
			elseif auto.vaultBack and Cover.ForceVaultBack then done = Cover.ForceVaultBack() end
			if done then
				if auto.light and lightKeys then lightKeys(auto.light) end
				return
			end
			task.wait(0.25)
		end
	end)
end
-- Rich text for a line: [Keys] in blue, CAPS words bold white
-- Each [Key] in a line lights up on its own: the 1st press turns the 1st [C] green, the 2nd press the
-- 2nd [C], and so on. keyCount[name] = presses done; keyAnim[name] = the one being pushed in right now.
local keyCount, keyAnim = {}, {}
local function richLine(text: string): string
	local out = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	local occ = {}
	out = out:gsub("(%f[%a]%u%u%u+%f[%A])", '<font color="#FFFFFF"><b>%1</b></font>')
	out = out:gsub("{(%d+)}", function(n)
		local left = lineCounter or tonumber(n)
		return '<font color="' .. (left == 0 and "#78E68C" or "#FF5A5A") .. '"><b>' .. tostring(left) .. '</b></font>'
	end)
	out = out:gsub("%[([^%]]+)%]", function(name)
		local key = string.lower(name)
		occ[key] = (occ[key] or 0) + 1
		local k = occ[key]
		local st = (keyAnim[key] == k and "down") or (k <= (keyCount[key] or 0) and "done") or nil
		if st == "down" then
			return '<font color="#9CF0AC" size="18" transparency="0.45"><b>[' .. name .. ']</b></font>'
		elseif st == "done" then
			return '<font color="#78E68C"><b>[' .. name .. ']</b></font>'
		end
		return '<font color="#7CC8FF"><b>[' .. name .. ']</b></font>'
	end)
	return out
end

-- which [Key] names in a line an input counts as
local KEY_NAMES = {
	[Enum.KeyCode.LeftShift] = "shift", [Enum.KeyCode.RightShift] = "shift", [Enum.KeyCode.Space] = "space",
	[Enum.KeyCode.LeftControl] = "c", [Enum.KeyCode.RightControl] = "c", -- Ctrl crouches too, so it lights [C]
	[Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3",
}
local function keyNameFor(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.MouseButton1 then return "left click" end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then return "right click" end
	if input.KeyCode == Enum.KeyCode.Unknown then return nil end
	return KEY_NAMES[input.KeyCode] or string.lower(input.KeyCode.Name)
end
local shownText = "" -- the line in the panel (plain), for re-rendering when a key lights up
local lineIsDemo = false -- the game is doing this one for you ("Like this:"): your own presses don't light keys
-- The game does a move for you ("Like this:"): its keys in the line press in and go green, one after another
lightKeys = function(names: { string })
	task.spawn(function()
		for _, name in names do
			if not shownText or shownText == "" then return end
			local textNow = shownText
			keyAnim[name] = (keyCount[name] or 0) + 1
			local v = lineLabel.MaxVisibleGraphemes
			lineLabel.Text = richLine(shownText)
			lineLabel.MaxVisibleGraphemes = v
			task.wait(0.14)
			if shownText ~= textNow then return end
			keyAnim[name] = nil
			keyCount[name] = (keyCount[name] or 0) + 1
			v = lineLabel.MaxVisibleGraphemes
			lineLabel.Text = richLine(shownText)
			lineLabel.MaxVisibleGraphemes = v
			task.wait(0.12)
		end
	end)
end

-- headline per line (key or text), built from TutorialConfig.Alerts
local alertFor = {}
for key, head in Config.Alerts or {} do
	alertFor[key] = head
	for _, t in { Config.Lines, Config.Lines2, Config.Lines3 } do
		if t and t[key] then alertFor[t[key]] = head end
	end
end

local function shakePanel(strength: number, time: number)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local k = 1 - (os.clock() - t0) / time
			panel.Position = PANEL_POS + UDim2.fromOffset((math.random() * 2 - 1) * strength * k, (math.random() * 2 - 1) * strength * 0.6 * k)
			task.wait()
		end
		panel.Position = PANEL_POS
	end)
end

local slamToken = 0
local function slam(text: string)
	slamToken += 1
	local token = slamToken
	headline.Text = text
	headline.TextTransparency = 0
	headline.TextColor3 = Color3.new(1, 1, 1)
	headline.Position = UDim2.fromScale(0.5, 0.3)
	headStroke.Transparency = 0
	headScale.Scale = 2.8
	headline.Rotation = -10
	local inInfo = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(headScale, inInfo, { Scale = 0.92 }):Play()
	TweenService:Create(headline, inInfo, { Rotation = -3 }):Play()
	task.delay(0.13, function()
		if token ~= slamToken then return end
		-- impact
		TweenService:Create(headScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(headline, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { TextColor3 = ALERT_RED }):Play()
		flash.BackgroundTransparency = 0.35
		TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		if thump then thump:Play() end
		shakePanel(10, 0.35)
		panelStroke.Color = ALERT_RED
		panelStroke.Transparency = 0
		panelStroke.Thickness = 3
		TweenService:Create(panelStroke, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Transparency = 0.86, Thickness = 1.5 }):Play()
		task.delay(1.4, function() if token == slamToken then panelStroke.Color = Color3.new(1, 1, 1) end end)
		-- a red/white throb while it's up
		task.spawn(function()
			local t0 = os.clock()
			while token == slamToken and os.clock() - t0 < 1.8 do
				local k = (math.sin((os.clock() - t0) * 14) + 1) / 2
				headline.TextColor3 = ALERT_RED:Lerp(Color3.fromRGB(255, 190, 190), k * 0.5)
				task.wait()
			end
		end)
	end)
	task.delay(2.2, function()
		if token ~= slamToken then return end
		local outInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(headline, outInfo, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.24) }):Play()
		TweenService:Create(headStroke, outInfo, { Transparency = 1 }):Play()
	end)
end

local function showLine(text: string, key: string?)
	gui.Enabled = true
	-- [TOUCH] touch-only players get the button names instead of keys (TutorialConfig.ForTouch)
	do
		local uis = game:GetService("UserInputService")
		local touchOnly = (uis.TouchEnabled and not uis.KeyboardEnabled) or game:GetService("Players").LocalPlayer:GetAttribute("_ForceTouch") == true
		if touchOnly and Config.ForTouch then text = Config.ForTouch(text) end
	end
	local head = (key and alertFor[key]) or alertFor[text]
	if head then
		-- the headline says it big; the panel carries on with the rest of the line
		local lower, headLower = string.lower(text), string.lower(head)
		if string.sub(lower, 1, #headLower) == headLower then
			text = (string.gsub(string.sub(text, #head + 1), "^%s+", ""))
		end
		slam(head)
	end
	-- pop in: a bouncy little grow from the bottom, the portrait bobs
	panel.BackgroundTransparency = 0.6
	panelScale.Scale = 0.88
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.25 }):Play()
	TweenService:Create(panelScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	portraitScale.Scale = 1.25
	TweenService:Create(portraitScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	typeToken += 1
	local token = typeToken
	keyCount, keyAnim = {}, {}
	shownText = text
	lineCounter = string.match(text, "{(%d+)}") and tonumber(string.match(text, "{(%d+)}")) or nil
	lineLabel.Text = richLine(text)
	lineLabel.TextColor3 = head and Color3.fromRGB(255, 214, 214) or Color3.fromRGB(226, 229, 236)
	lineLabel.MaxVisibleGraphemes = 0
	local count = utf8.len(text) or #text
	task.spawn(function()
		for i = 1, count do
			if token ~= typeToken then return end
			lineLabel.MaxVisibleGraphemes = i
			-- typewriter tick (every other letter, skipping spaces, slightly varied)
			local ch = text:sub(i, i)
			if i % (Audio.TypingEvery or 2) == 0 and ch ~= " " and #typeSounds > 0 then
				tickIndex = tickIndex % #typeSounds + 1
				local snd = typeSounds[tickIndex]
				snd.PlaybackSpeed = 0.95 + math.random() * 0.15
				snd:Play()
			end
			task.wait(Config.TypeSpeed or 0.03)
		end
		lineLabel.MaxVisibleGraphemes = -1
		typingDoneAt = os.clock()
		if pendingAllow then
			allowed = pendingAllow
			pendingAllow = nil
		end
		if pendingAuto then
			local auto = pendingAuto
			pendingAuto = nil
			runAuto(auto)
		end
	end)
end

local function objectiveFor(event: string?): string?
	if event == "Smoke" then
		local kit = localPlayer:GetAttribute("KitGadget")
		return kit == "Flash" and "Throw the flashbang" or kit == "Frag" and "Throw the frag" or "Throw the smoke"
	end
	return event
end

local function setObjective(text: string?, done: boolean?)
	objectiveLabel.Visible = text ~= nil
	objectiveLabel.Text = text and ((done and "✓  " or "OBJECTIVE  ·  ") .. string.upper(text)) or ""
	local color = done and Color3.fromRGB(120, 230, 140) or BLUE
	objectiveLabel.TextColor3 = color
	objectiveLabel.BackgroundColor3 = color
end

local OBJECTIVES = {
	LeftCover = "Leave cover",
	EnteredCover = "Take cover",
	Dashed = "Rush to cover",
	PeekShot = "Peek and shoot",
	Smoke = "Throw your grenade",
	BlindShot1 = "Blind fire",
	SlidIntoCover = "Slide into cover",
	ReachedHighlight = "Reach the highlighted cover",
	Shuffled = "Slide along cover",
	Crouched = "Crouch",
	BlindFire = "Blind fire",
	Reloaded = "Reload",
	Vaulted = "Vault the wall",
	VaultedIntoCover = "Silent vault into cover",
	CrouchedMove = "Crouch",
	VaultedBack = "Vault back into cover",
}
local sawVault = false
local zoneMarker: BasePart? = nil
local lastEdgeDir: Vector3? = nil -- which way your pillar's peek edge was (for the scripted step-out)
local stepOutArmed = false -- this step's Q walks you straight out to the right
local guideTarget: Instance? = nil -- after a vault, swing the camera here (the cover to E into)
local guided = false
local lineCounter: number? = nil -- the live {3} count in a line (red, down to a green 0)

-- "Leave cover": the game walks you out past the edge of your pillar, into his view - you're on the move
-- when he opens up, and the rush back cuts the walk short. You get control back when you stop.
local function stepOut()
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local dir = lastEdgeDir or (root.CFrame.RightVector * Vector3.new(1, 0, 1))
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local PlayerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Disable()
	local target = root.Position + dir * 5
	hum:MoveTo(target)
	task.spawn(function()
		local Cover = Get("CoverController")
		local t0 = os.clock()
		while active and os.clock() - t0 < 3.5 do
			if Cover and (Cover.IsMoving() or Cover.IsInCover()) then return end -- the rush took over (it gives control back)
			if ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude < 1 then break end
			task.wait()
		end
		Remotes.Progress:FireServer("SteppedOut") -- you've stopped out in the open: that's when he fires
		if Cover and (Cover.IsMoving() or Cover.IsInCover()) then return end
		hum:MoveTo(root.Position)
		controls:Enable()
	end)
end

-- // Highlight
local function clearHighlight()
	localPlayer:SetAttribute("MoveTarget", nil)
	if highlightBox then highlightBox:Destroy() end
	if highlightTag then highlightTag:Destroy() end
	highlightBox, highlightTag, highlightPart = nil, nil, nil
end

local function setHighlight(part: BasePart)
	clearHighlight()
	highlightPart = part
	localPlayer:SetAttribute("MoveTarget", part.Name) -- E / Shift+E only go to this cover
	local box = Instance.new("SelectionBox")
	box.Adornee = part
	box.Color3 = Color3.fromRGB(90, 170, 255)
	box.LineThickness = 0.06
	box.SurfaceTransparency = 0.85
	box.SurfaceColor3 = Color3.fromRGB(90, 170, 255)
	box.Parent = workspace.CurrentCamera
	highlightBox = box
	local tag = Instance.new("BillboardGui")
	tag.Adornee = part
	tag.Size = UDim2.fromOffset(120, 28)
	tag.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	tag.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextColor3 = Color3.fromRGB(90, 170, 255)
	t.TextStrokeTransparency = 0.4
	t.Text = "▼ COVER"
	t.Parent = tag
	tag.Parent = workspace.CurrentCamera
	highlightTag = tag
end

-- // Watching for the requested action
local function currentAmmo(): number?
	local character = localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("Ammo")
end

local function gadgetCharges(): number
	return (localPlayer:GetAttribute("SmokeCharges") or 0) + (localPlayer:GetAttribute("FlashCharges") or 0)
end

local function takeSnapshot()
	local Cover = Get("CoverController")
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	snapshot = {
		ammo = currentAmmo(),
		smoke = gadgetCharges(),
		throws = localPlayer:GetAttribute("GadgetThrows") or 0,
		part = Cover and Cover.GetCoverPart(),
		pos = root and root.Position,
		at = os.clock(),
	}
	sawMoving = false
	sawVault = false
	guided = false
end

-- "Da-ding!": every completed task gets a chime and the objective pops green
local function confirm()
	if confirmSound then
		confirmSound.PlaybackSpeed = 1.15
		confirmSound:Play()
		-- the second, higher note
		task.delay(0.12, function()
			if not confirmSound then return end
			local hi = confirmSound:Clone()
			hi.PlaybackSpeed = 1.5
			hi.Parent = gui
			hi:Play()
			game:GetService("Debris"):AddItem(hi, 1.5)
		end)
	end
	local scale = objectiveLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = objectiveLabel
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local stroke = panel:FindFirstChild("ConfirmStroke") or Instance.new("UIStroke")
	stroke.Name = "ConfirmStroke"
	stroke.Color = Color3.fromRGB(120, 230, 140)
	stroke.Thickness = 2
	stroke.Transparency = 0
	stroke.Parent = panel
	TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
end

local function report(eventName: string)
	if waitFor ~= eventName then return end
	waitFor = nil
	if eventName == "Shuffled" then localPlayer:SetAttribute("TutorialShuffle", nil) localPlayer:SetAttribute("ShuffleDone", nil) end
	if eventName == "LeftCover" and stepOutArmed then
		stepOutArmed = false
		task.spawn(stepOut) -- straight away, no waiting on the server
	end
	setObjective(eventName == "Smoke" and objectiveFor(eventName) or OBJECTIVES[eventName], true)
	confirm()
	Remotes.Progress:FireServer(eventName)
end

local lastDuck, lastAmmoSeen = 0, nil
local function duckCheck()
	local ammo = currentAmmo()
	local fired = ammo and lastAmmoSeen and ammo < lastAmmoSeen
	lastAmmoSeen = ammo
	local aimingAt = false
	local Camera = Get("CameraController")
	local boss = workspace:FindFirstChild(Config.BossName)
	if Camera and Camera.IsAiming() and boss and boss:FindFirstChild("HumanoidRootPart") then
		local cam = workspace.CurrentCamera.CFrame
		local p = boss.HumanoidRootPart.Position
		local t = (p - cam.Position):Dot(cam.LookVector)
		aimingAt = t > 0 and (cam.Position + cam.LookVector * t - p).Magnitude < 3.5
	end
	if (fired or aimingAt) and os.clock() - lastDuck > 0.25 then
		lastDuck = os.clock()
		Remotes.Progress:FireServer("Duck")
	end
end

-- Blind fire lesson: at most BLIND_CAP shots between "blind fire back" and "make him duck (3 shots)",
-- so the magazine always has the 3 that lesson needs (reloading is locked until after it)
local BLIND_CAP = 9
local blindCap: { shots: number, ammo: number? }? = nil
local function watch()
	if not active then return end
	duckCheck()
	if blindCap then
		local ammo = currentAmmo()
		if ammo and blindCap.ammo and ammo < blindCap.ammo then blindCap.shots += blindCap.ammo - ammo end
		blindCap.ammo = ammo
		if blindCap.shots >= BLIND_CAP then
			allowed.Shoot = nil
			if pendingAllow then pendingAllow.Shoot = nil end
		end
	end
	local Cover = Get("CoverController")
	if not Cover then return end
	local inCover = Cover.IsInCover()
	if inCover and Cover.GetPeekEdgeDirection then lastEdgeDir = Cover.GetPeekEdgeDirection() end
	updateLock(inCover)
	if Cover.IsMoving() then sawMoving = true end
	local vaulting = Cover.IsVaulting()
	if vaulting then sawVault = true end
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

	if waitFor == "LeftCover" and wasInCover and not inCover then report("LeftCover")
	elseif waitFor == "EnteredCover" and inCover and not wasInCover then report("EnteredCover")
	elseif waitFor == "Dashed" and sawMoving and inCover and not Cover.IsMoving() then report("Dashed")
	elseif waitFor == "PeekShot" then
		-- aimed shots (each one also makes him duck): 3 of them, or stop for 3 seconds after the first
		local ammo = currentAmmo()
		if ammo and snapshot.ammo and ammo < snapshot.ammo then
			local Camera = Get("CameraController")
			if Camera and Camera.IsAiming() then
				snapshot.shots = (snapshot.shots or 0) + (snapshot.ammo - ammo)
				snapshot.lastShot = os.clock()
			end
			snapshot.ammo = ammo
			if (snapshot.shots or 0) >= 3 then report("PeekShot") end
		end
		if (snapshot.shots or 0) >= 1 and snapshot.lastShot and os.clock() - snapshot.lastShot >= 3 then report("PeekShot") end
		if ammo and (not snapshot.ammo or ammo > snapshot.ammo) then snapshot.ammo = ammo end -- reloaded meanwhile
	elseif waitFor == "Smoke" then
		if (localPlayer:GetAttribute("GadgetThrows") or 0) > (snapshot.throws or 0) then report("Smoke") end
	elseif waitFor == "Shuffled" then
		local away = inCover and root and snapshot.pos and Cover.GetCoverPart() == snapshot.part
			and ((root.Position - snapshot.pos) * Vector3.new(1, 0, 1)).Magnitude or 0
		if Cover.IsPillarLocked and Cover.IsPillarLocked() then
			-- on a pillar: [A] all the way across, then [D] all the way back (CoverController drives it)
			if localPlayer:GetAttribute("ShuffleDone") then report("Shuffled") end
		elseif away > 0.9 then report("Shuffled")
		end
	elseif waitFor == "Crouched" and inCover then
		-- crouch, then stand back up
		if Cover.IsCrouched() then snapshot.crouchedOnce = true
		elseif snapshot.crouchedOnce then report("Crouched") end
	elseif waitFor == "CrouchedMove" and ((localPlayer.Character and localPlayer.Character:GetAttribute("Stance") == "Crouch") or (inCover and Cover.IsCrouched())) then report("CrouchedMove")
	elseif waitFor == "BlindShot1" then
		local ammo = currentAmmo()
		if ammo and snapshot.ammo and ammo < snapshot.ammo and Cover.IsBlindFiring() then report("BlindShot1") end
		if ammo then snapshot.ammo = ammo end
	elseif waitFor == "BlindFire" then
		-- 3 blind-fire shots
		local ammo = currentAmmo()
		if ammo and snapshot.ammo and ammo < snapshot.ammo then
			snapshot.shots = (snapshot.shots or 0) + (snapshot.ammo - ammo) -- every shot counts (blind or not)
			snapshot.ammo = ammo
			if lineCounter then
				local left = math.max(0, 3 - (snapshot.shots or 0))
				if left ~= lineCounter then
					lineCounter = left
					local v = lineLabel.MaxVisibleGraphemes
					lineLabel.Text = richLine(shownText)
					lineLabel.MaxVisibleGraphemes = v
				end
			end
			if (snapshot.shots or 0) >= 3 then report("BlindFire") end
		end
		if ammo and (not snapshot.ammo or ammo > snapshot.ammo) then snapshot.ammo = ammo end
	elseif waitFor == "Reloaded" then
		local ammo = currentAmmo()
		if ammo and snapshot.ammo and ammo > snapshot.ammo then report("Reloaded") end
		if ammo and (not snapshot.ammo or ammo < snapshot.ammo) then snapshot.ammo = ammo end
	elseif waitFor == "Vaulted" and sawVault and not vaulting then report("Vaulted")
	elseif waitFor == "VaultedBack" and sawVault and not vaulting and inCover then report("VaultedBack")
	elseif waitFor == "VaultedIntoCover" and sawVault and not vaulting and inCover and not Cover.IsMoving() then report("VaultedIntoCover")
	elseif waitFor == "VaultedIntoCover" and sawVault and not vaulting and guideTarget and not guided then
		-- landed: swing the camera smoothly round to the cover you're going to sneak into
		guided = true
		local Camera = Get("CameraController")
		if Camera and Camera.Guide then Camera.Guide(guideTarget, 0.8, 1.6) end
	elseif waitFor == "ReachedHighlight" and highlightPart and inCover and Cover.GetCoverPart() == highlightPart then
		report("ReachedHighlight")
	end
	wasInCover = inCover
end

-- // Server steps
local function onStep(payload)
	if payload.reloadLocked ~= nil then reloadLocked = payload.reloadLocked end
	if payload.finished then
		reloadLocked = false
		active = false
		localPlayer:SetAttribute("TutorialActive", nil)
		localPlayer:SetAttribute("TutorialShuffle", nil)
		waitFor = nil
		allowed = {}
		updateLock(false)
		setBars(false)
		clearHighlight()
		if zoneMarker then zoneMarker:Destroy() zoneMarker = nil end
		localPlayer:SetAttribute("GadgetZone", nil)
		task.delay(1.5, function() if not active then gui.Enabled = false end end)
		return
	end
	active = true
	localPlayer:SetAttribute("TutorialActive", true) -- CoverController pins you to the right edge of pillars
	if typeof(payload.teleport) == "CFrame" then
		local Cover = Get("CoverController")
		if Cover and Cover.Reset then Cover.Reset() end
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = payload.teleport
		end
	end
	if payload.focus ~= nil then task.defer(directCamera, payload) end
	if payload.stepOut then task.defer(stepOut) end
	if payload.openingGo then openingGo = true end
	if payload.line then lineIsDemo = payload.autoLight ~= nil end
	if payload.waitFor then
		stepOutArmed = payload.stepOutOnLeave == true
		guideTarget = typeof(payload.guideAfterVault) == "Instance" and payload.guideAfterVault or nil
	end
	if payload.waitFor == "Shuffled" then localPlayer:SetAttribute("ShuffleDone", nil) end
	if payload.waitFor == "BlindShot1" then blindCap = { shots = 0, ammo = currentAmmo() }
	elseif payload.waitFor == "BlindFire" then blindCap = nil end
	if payload.fade then fade(payload.fade, payload.title) end
	if payload.cutscene == "Opening" then task.spawn(playOpening, payload) end
	if payload.killcam then task.spawn(killcam) end
	if payload.autoRush or payload.autoVaultBack then
		local auto = { rush = payload.autoRush, standAt = payload.autoRushStand, vaultBack = payload.autoVaultBack, delay = payload.autoDelay, light = payload.autoLight }
		if payload.line and not payload.autoDuringLine then pendingAuto = auto else runAuto(auto) end
	end
	if payload.allow then
		local want = {}
		for _, name in payload.allow do want[name] = true end
		if payload.line then
			-- locked until the whole line is on screen, so you can't act before you've read it
			allowed = {}
			pendingAllow = want
		else
			pendingAllow = nil
			allowed = want
		end
	end
	if payload.enterCover then
		task.spawn(function()
			local Cover = Get("CoverController")
			for _ = 1, 10 do
				task.wait(0.25)
				if cutsceneActive then break end
				if Cover and Cover.TryEnterCover() then break end
			end
		end)
	end
	if payload.zone == false then
		if zoneMarker then zoneMarker:Destroy() zoneMarker = nil end
		localPlayer:SetAttribute("GadgetZone", nil)
	elseif typeof(payload.zone) == "Vector3" then
		localPlayer:SetAttribute("GadgetZone", payload.zone)
		if zoneMarker then zoneMarker:Destroy() end
		zoneMarker = Instance.new("Part")
		zoneMarker.Name = "TutorialZone"
		zoneMarker.Shape = Enum.PartType.Cylinder
		zoneMarker.Size = Vector3.new(0.1, 5, 5)
		zoneMarker.CFrame = CFrame.new(payload.zone + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		zoneMarker.Anchored, zoneMarker.CanCollide, zoneMarker.CanQuery, zoneMarker.CanTouch = true, false, false, false
		zoneMarker.Material = Enum.Material.Neon
		zoneMarker.Color = Color3.fromRGB(90, 170, 255)
		zoneMarker.Transparency = 0.55
		zoneMarker.Parent = workspace.CurrentCamera
	end
	if payload.highlight == false then clearHighlight()
	elseif typeof(payload.highlight) == "Instance" then setHighlight(payload.highlight) end
	if payload.line then
		local template = Config.Lines[payload.line] or payload.line
		local ok, text = pcall(string.format, template, table.unpack(payload.args or {}))
		showLine(ok and text or template, payload.line)
	end
	-- the slide lesson is the only time you can move along a pillar in the tutorials
	localPlayer:SetAttribute("TutorialShuffle", payload.waitFor == "Shuffled" or nil)
	if payload.waitFor then
		waitFor = payload.waitFor
		takeSnapshot()
		local Cover = Get("CoverController")
		wasInCover = Cover and Cover.IsInCover() or false
		setObjective(payload.waitFor == "Smoke" and objectiveFor("Smoke") or OBJECTIVES[payload.waitFor] or payload.waitFor, false)
	elseif payload.line then
		setObjective(nil)
	end
end

function controller.Start()
	buildUI()
	Remotes.Step.OnClientEvent:Connect(onStep)
	-- a slide that ended in cover (MovementController sets this)
	localPlayer:GetAttributeChangedSignal("SlideCoverAt"):Connect(function()
		if active and waitFor == "SlidIntoCover" then report("SlidIntoCover") end
	end)
	-- (pass 35) any slide at all (the starter tutorial just wants you to slide once)
	localPlayer:GetAttributeChangedSignal("SlidAt"):Connect(function()
		if active and waitFor == "Slid" then report("Slid") end
	end)
	RunService.Heartbeat:Connect(watch)
	-- keys the line says to HOLD ("hold [Shift]") go back to blue when you let go
	UserInputService.InputEnded:Connect(function(input)
		if not gui or shownText == "" then return end
		if lineIsDemo then return end
		local name = keyNameFor(input)
		if not name or not keyCount[name] then return end
		if not string.find(string.lower(shownText), "hold [" .. name .. "]", 1, true) then return end
		keyCount[name], keyAnim[name] = nil, nil
		local v = lineLabel.MaxVisibleGraphemes
		lineLabel.Text = richLine(shownText)
		lineLabel.MaxVisibleGraphemes = v
	end)
	-- press a key the line mentions: it pushes in (smaller, faded, a little shake), then turns green
	UserInputService.InputBegan:Connect(function(input)
		if not gui or not gui.Enabled or shownText == "" then return end
		if lineIsDemo then return end -- the game is showing you: only its own presses light up
		local name = keyNameFor(input)
		if not name or keyAnim[name] then return end
		local lower = string.lower(shownText)
		local _, total = string.gsub(lower, "%[" .. string.gsub(name, "%p", "%%%0") .. "%]", "")
		local done = keyCount[name] or 0
		if total == 0 or done >= total then return end
		-- "[A] ... then [D]": D doesn't count until A has been pressed
		if name == "d" and string.find(lower, "[a]", 1, true) and (keyCount.a or 0) == 0 then return end
		keyAnim[name] = done + 1
		local visible = lineLabel.MaxVisibleGraphemes
		lineLabel.Text = richLine(shownText)
		lineLabel.MaxVisibleGraphemes = visible
		shakePanel(3, 0.15)
		local textNow = shownText
		task.delay(0.14, function()
			if shownText ~= textNow or keyAnim[name] ~= done + 1 then return end
			keyAnim[name] = nil
			keyCount[name] = done + 1
			local v = lineLabel.MaxVisibleGraphemes
			lineLabel.Text = richLine(shownText)
			lineLabel.MaxVisibleGraphemes = v
		end)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Config.Keybind and not active then
			Remotes.Start:FireServer(1)
		elseif input.KeyCode == Config.Keybind2 and not active then
			Remotes.Start:FireServer(2)
		elseif Config.Keybind3 and input.KeyCode == Config.Keybind3 and not active then
			Remotes.Start:FireServer(3)
		elseif input.KeyCode == Config.PracticeKeybind and not active then
			PracticeRemote:FireServer()
		end
	end)
end

return controller
