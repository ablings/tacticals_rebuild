-- ReplicatedFirst/LoadingScreen (LocalScript)
-- The game's loading screen. The lobby and the match place keep identical copies.
--   1. The red / blue TACTICALS frame glitches in and the white letters drop into it one by one.
--   2. The loading bar sits under the logo until the game has really loaded (place, assets,
--      character, UI - all with time-outs).
--   3. Once it's fully loaded, GF comes in and clears the letters: sword slices (each letter splits
--      along the cut), jabs, spinning kicks and backflips. Some letters won't budge to fists and feet,
--      so GF flips back and shoots them. A click skips to the end.
--   4. GF takes the centre on a black badge; the background dims, GF kicks pieces off the red/blue
--      frame, the rest crumbles to dust and falls, and the amber/olive glow swaps and swells. Then the
--      screen dissolves into the game.
-- It also covers teleports between places (TeleportService:SetTeleportGui).
-- QUICK INTRO (match place; this script's attribute QuickIntro = true, UI session 2026-10-16, Edward): no GF fight.
--   The logo holds with the bar until this client has loaded, then tells the server (MatchFlow "Loaded") and waits on
--   "WAITING FOR OPPONENT" while ReplicatedStorage.MatchPhase is "Loading" (the server leaves Loading only when every
--   player in the match has loaded, so both sides start together). Then the letters and the frame crumble to dust and
--   the screen dissolves into the map vote. Servers with no match flow (test / tutorial) crumble straight away.
-- When it's finished, LocalPlayer gets the attribute LoadingDone = true.
-- Once loading is complete, a click or any key shortens the remaining waits.
--
-- ART (uploaded 2026-10-08): the frame, the nine letters and their cut halves were split out of the
-- TACTICALS logo; letters/halves live in two 1024 atlases. Flash and slash are in the FX atlas.
-- Katana + pistol (2026-10-11): Codex image gen, keyed and cropped (tacticals_ui/art/intro).
-- The previous loading screen is kept in ServerStorage._DevTools.LoadingScreen_v1_backup.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TeleportService = game:GetService("TeleportService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-------------------------------------------------------------------------------
-- Art + layout
-------------------------------------------------------------------------------
local IMG = {
	Backdrop = "rbxassetid://78445006727868",  -- (2026-10-21) teal-fixed tac_logo_frame (was 81042695231423, a teal line on the olive half)
	-- was:  -- the frame with the letters removed (1024 x 346), recoloured bone/olive (pass 34; amber version rbxassetid://97236428853521)
	                                           -- (red/blue original: rbxassetid://119406307898600; art/logo in tacticals_ui)
	Letters = "rbxassetid://117542693397702",  -- atlas: the nine letters
	Halves = "rbxassetid://100554075354658",   -- atlas: every letter cut in two along a slash (glowing cut edge)
	FX = "rbxassetid://120145497714154",       -- atlas: sword, pistol, muzzle flash, slash arc
	GF = "rbxassetid://102042415045078",       -- GF logo, transparent background
	Katana = "rbxassetid://82013962570615",    -- 1024 x 106, blade pointing right
	Pistol = "rbxassetid://139394529190036",   -- 600 x 399, muzzle pointing right
}
local STAGE = Vector2.new(1024, 346)           -- the frame image, in "logo pixels"
-- letter, home x, home y (top-left in the frame), atlas rect {x,y,w,h}, cut halves A/B (first five only), cut angle
local LETTERS = {
	{ "T", 53, 38, { 0, 0, 425, 231 }, { 0, 0, 425, 231 }, { 427, 0, 425, 231 }, -24 },
	{ "A", 94, 84, { 624, 0, 210, 200 }, { 394, 233, 210, 200 }, { 606, 233, 210, 200 }, 24 },
	{ "C", 289, 79, { 230, 233, 130, 176 }, { 615, 440, 130, 176 }, { 747, 440, 130, 176 }, -24 },
	{ "T", 388, 79, { 0, 233, 124, 177 }, { 155, 440, 124, 177 }, { 281, 440, 124, 177 }, 24 },
	{ "I", 464, 79, { 126, 233, 102, 177 }, { 407, 440, 102, 177 }, { 511, 440, 102, 177 }, -24 },
	{ "C", 530, 79, { 362, 233, 139, 176 }, { 879, 440, 139, 176 }, { 0, 630, 139, 176 }, 24 },
	{ "A", 575, 82, { 427, 0, 195, 205 }, { 0, 233, 195, 205 }, { 197, 233, 195, 205 }, -24 },
	{ "L", 765, 82, { 503, 233, 112, 174 }, { 141, 630, 112, 174 }, { 255, 630, 112, 174 }, 24 },
	{ "S", 832, 86, { 836, 0, 153, 188 }, { 818, 233, 153, 188 }, { 0, 440, 153, 188 }, -24 },
}
local FXR = { Sword = { 0, 0, 600, 96 }, Pistol = { 0, 100, 320, 200 }, Flash = { 330, 100, 200, 200 }, Slash = { 0, 310, 512, 160 } }
local GF_RATIO = 970 / 613

local SOUNDS = {
	Thud = "rbxassetid://140594308250996",
	Slash = "rbxasset://sounds/swordslash.wav",
	Shot = "rbxassetid://127604219525464",
	Whoosh = "rbxassetid://12222216",
	Bang = "rbxassetid://130435518414889",
}
local RED, BLUE, TEAL = Color3.fromRGB(230, 36, 48), Color3.fromRGB(36, 120, 255), Color3.fromRGB(40, 230, 200)
local AMBER, OLIVE = Color3.fromRGB(138, 156, 74), Color3.fromRGB(107, 122, 58) -- (2026-10-20, Edward) back to the original olive: the palette pass had made it yellow without being asked
-- the whole intro uses the lobby UI's military look: gunmetal, amber (left / primary), olive (right / secondary)
local GLOW_L, GLOW_R = AMBER, OLIVE
-- (2026-10-21, RIVALS pass) Edward's final font decision: Gotham (drawn as Montserrat) is out. Big words / numbers in
-- Oswald Bold (FONT), the small status line in Rubik (FONT_BODY). The logo art is untouched.
local FONT = "rbxasset://fonts/families/Oswald.json"
local FONT_BODY = "rbxassetid://12187365977"
local UI_READY = { "LobbyUI", "HUD" }
local MAX_LOAD_TIME = 40
local ASSET_TIMEOUT = 12 -- (2026-10-16) essentials only now; whatever isn't in by then streams in during play
-- (2026-10-21, Edward: "loading on mobile for some reason is so slow") phones wait at most 5 s for assets; the rest loads in play
if game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled then ASSET_TIMEOUT = 5 end
local STAGE_Y = 0.42

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function new(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function tween(obj, time: number, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function rand(a: number, b: number): number return a + math.random() * (b - a) end
-- (pass 44) Scale only (Design Rules): everything is laid out in STAGE pixels (the 1024 x 346 logo) and turned
-- into Scale of the stage, which is itself Scale + an aspect lock. No Offset anywhere on this screen.
local function SP(x: number, y: number): UDim2 return UDim2.fromScale(x / STAGE.X, y / STAGE.Y) end
local function sprite(image: string, rect, props)
	local i = new("ImageLabel", { BackgroundTransparency = 1, Image = image, ImageRectOffset = Vector2.new(rect[1], rect[2]),
		ImageRectSize = Vector2.new(rect[3], rect[4]), Size = SP(rect[3], rect[4]) })
	for k, v in props or {} do if k ~= "Parent" then i[k] = v end end
	if props and props.Parent then i.Parent = props.Parent end
	return i
end

-------------------------------------------------------------------------------
-- Screen
-------------------------------------------------------------------------------
local arriving = TeleportService:GetArrivingTeleportGui()
if arriving then arriving.Parent = playerGui end

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, DisplayOrder = 1000, ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.None })
gui:SetAttribute("NoStyle", true)

-- background: gunmetal with an amber glow on the left and an olive glow on the right (the UI theme)
local function background(parent)
	local bg = new("Frame", { Name = "Background", BackgroundColor3 = Color3.fromRGB(10, 12, 10), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 1, Parent = parent })
	for i, c in { GLOW_L, GLOW_R } do
		local g = new("Frame", { Name = "Glow" .. i, BackgroundColor3 = c, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 1 and 0.18 or 0.82, 0.45), Size = UDim2.fromScale(0.9, 1.3), BackgroundTransparency = 0.8, ZIndex = 1,
			Parent = bg }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1) }), Rotation = 0, Parent = g })
	end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = bg })
	return bg
end
local bg = background(gui)

-- diagonal light streaks in amber and olive drifting across the back
local streaks = {}
for i = 1, 4 do
	local s = new("Frame", { BackgroundColor3 = i % 2 == 1 and GLOW_L or GLOW_R, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.035 + (i % 3) * 0.03, 0, 2.4, 0), Rotation = 28, BackgroundTransparency = 0.82, ZIndex = 2, Parent = gui })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90, Parent = s })
	streaks[i] = { frame = s, phase = i * 0.41, speed = 0.03 + i * 0.008 }
end

-- the stage lives in frame pixels; a UIScale fits it to the screen
local stage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, STAGE_Y),
	Size = UDim2.fromScale(0.72, 0.4), ZIndex = 10, Parent = gui })
new("UIAspectRatioConstraint", { AspectRatio = STAGE.X / STAGE.Y, Parent = stage })
local backdrop = new("ImageLabel", { Name = "Frame", BackgroundTransparency = 1, Image = IMG.Backdrop, Size = UDim2.fromScale(1, 1),
	ImageTransparency = 1, ZIndex = 10, Parent = stage })
-- chromatic copies used by the glitch-in (red pushed left, blue pushed right)
local ghosts = {}
for i, c in { AMBER, OLIVE } do
	ghosts[i] = new("ImageLabel", { BackgroundTransparency = 1, Image = IMG.Backdrop, ImageColor3 = c, Size = UDim2.fromScale(1, 1),
		ImageTransparency = 1, ZIndex = 9, Parent = stage })
end

local flash = new("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = gui })
local fx = new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = stage })

-- loading bar
local barBox = new("Frame", { Name = "Bar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = SP(STAGE.X * 0.36, 40),
	Position = SP(STAGE.X / 2, STAGE.Y + 26), ZIndex = 15, Parent = stage })
local barGroup = new("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, ZIndex = 15, Parent = barBox })
local statusText = new("TextLabel", { BackgroundTransparency = 1, FontFace = Font.new(FONT_BODY, Enum.FontWeight.Medium), TextSize = 13,
	TextColor3 = Color3.fromRGB(167, 173, 152), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Size = UDim2.fromScale(0.8, 0.45), TextScaled = true,
	ZIndex = 16, Parent = barGroup }, { new("UITextSizeConstraint", { MaxTextSize = 15 }) })
local pctText = new("TextLabel", { BackgroundTransparency = 1, FontFace = Font.new(FONT, Enum.FontWeight.Bold), TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, Text = "0%", Size = UDim2.fromScale(0.2, 0.45), TextScaled = true,
	Position = UDim2.fromScale(0.8, 0), ZIndex = 16, Parent = barGroup }, { new("UITextSizeConstraint", { MaxTextSize = 16 }) })
local track = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.86, BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.65), ZIndex = 16, Parent = barGroup }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 17, Parent = track },
	{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, OLIVE), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(236, 232, 218)),
	ColorSequenceKeypoint.new(1, AMBER) }), Parent = fill })

local sounds = {}
for name, id in SOUNDS do sounds[name] = new("Sound", { Name = name, SoundId = id, Volume = 0.6, Parent = gui }) end
local function play(name: string, volume: number, pitch: number)
	local base = sounds[name]
	if not base then return end
	local s = base:Clone()
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.Parent = gui
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
end

local logoScale = 1 -- screen pixels per stage pixel (read-only maths: nothing is placed with it)
local function fit()
	if stage.AbsoluteSize.X > 2 then logoScale = stage.AbsoluteSize.X / STAGE.X end
end
stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
gui.Parent = playerGui
fit()
if arriving then task.defer(function() arriving:Destroy() end) end

ContextActionService:BindActionAtPriority("LoadingScreenBlock", function() return Enum.ContextActionResult.Sink end, false,
	Enum.ContextActionPriority.High.Value + 100, Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)

-------------------------------------------------------------------------------
-- Teleport cover
-------------------------------------------------------------------------------
local function teleportGui()
	local tg = new("ScreenGui", { Name = "TacticalsTeleport", IgnoreGuiInset = true, DisplayOrder = 1000, ResetOnSpawn = false })
	tg:SetAttribute("NoStyle", true)
	background(tg)
	-- (2026-10-20, Edward: server transitions "should utilize our logo") the TACTICALS logo (UIKit.Logo) instead of the GF mark
	local okL, LogoMod = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit", 5):WaitForChild("Logo", 5)) end)
	if okL and LogoMod then
		LogoMod.Build(tg, { Position = UDim2.fromScale(0.5, STAGE_Y), Size = UDim2.fromScale(0.5, 0.3), ZIndex = 5 })
	else
		local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, STAGE_Y),
			Size = UDim2.fromScale(0.26, 0.26), ZIndex = 5, Parent = tg }, { new("UIAspectRatioConstraint", { AspectRatio = GF_RATIO }) })
		new("ImageLabel", { BackgroundTransparency = 1, Image = IMG.GF, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	end
	new("TextLabel", { BackgroundTransparency = 1, Text = "DEPLOYING", FontFace = Font.new(FONT, Enum.FontWeight.Bold), TextSize = 14,
		TextColor3 = Color3.fromRGB(160, 168, 190), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromScale(0.3, 0.03), TextScaled = true, ZIndex = 5, Parent = tg }, { new("UITextSizeConstraint", { MaxTextSize = 16 }) })
	return tg
end
task.spawn(function() pcall(function() TeleportService:SetTeleportGui(teleportGui()) end) end)

-------------------------------------------------------------------------------
-- Letters
-------------------------------------------------------------------------------
local letters = {}
for i, L in LETTERS do
	local r = L[4]
	local home = SP(L[2] + r[3] / 2, L[3] + r[4])
	local obj = sprite(IMG.Letters, r, { Name = "Letter" .. i, AnchorPoint = Vector2.new(0.5, 1), Position = home, Visible = false,
		ZIndex = 12 + i, Parent = stage })
	letters[i] = { obj = obj, home = home, x = L[2], y = L[3], w = r[3], h = r[4], cutA = L[5], cutB = L[6], angle = L[7] or 0,
		centre = Vector2.new(L[2] + r[3] / 2, L[3] + r[4] / 2) }
end

-------------------------------------------------------------------------------
-- Effects
-------------------------------------------------------------------------------
local shake = 0
local function addShake(a: number) shake = math.max(shake, a) end

local function puff(pos: Vector2, size: number, dir: number)
	local p = new("Frame", { BackgroundColor3 = Color3.fromRGB(220, 224, 236), BackgroundTransparency = 0.6, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = SP(pos.X, pos.Y), Size = SP(size * 0.3, size * 0.3),
		ZIndex = 31, Parent = fx }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	tween(p, 0.45, { Size = SP(size, size * 0.7), Position = SP(pos.X + dir * size * 0.9, pos.Y - size * 0.25),
		BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.5, function() p:Destroy() end)
end

local function sparks(pos: Vector2, count: number, reach: number, colors)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rand(-0.3, 0.3)
		local dir = Vector2.new(math.cos(angle), math.sin(angle))
		local len = rand(18, 50)
		local s = new("Frame", { BackgroundColor3 = colors[math.random(#colors)], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = SP(pos.X, pos.Y), Size = SP(len, 3), Rotation = math.deg(angle), ZIndex = 33, Parent = fx },
			{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local d = reach * rand(0.5, 1)
		tween(s, rand(0.3, 0.5), { Position = SP(pos.X + dir.X * d, pos.Y + dir.Y * d), Size = SP(3, 2),
			BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
		task.delay(0.55, function() s:Destroy() end)
	end
end

local function ring(pos: Vector2, color: Color3, to: number, time: number, thick: number)
	local r = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = SP(pos.X, pos.Y),
		Size = SP(20, 20), ZIndex = 32, Parent = fx }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local s = new("UIStroke", { Color = color, Thickness = thick, Parent = r })
	tween(r, time, { Size = SP(to, to) }, Enum.EasingStyle.Quart)
	tween(s, time, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(time + 0.05, function() r:Destroy() end)
end

-- stage pixels -> screen pixels
local function toScreen(p: Vector2): Vector2 return p end -- effects live in stage space now

-------------------------------------------------------------------------------
-- Real loading
-------------------------------------------------------------------------------
-- (pass 42) every stage reports real sub-progress, so the bar moves the whole way instead of sitting at 70%
-- and jumping to 100. Assets carry most of the weight: they're most of the real wait.
local progress = { place = 0, assets = 0, character = 0, ui = 0 }
local WEIGHTS = { place = 0.15, assets = 0.6, character = 0.15, ui = 0.1 }
local statusLine = "CONNECTING"
local loaded = false
local startTime = os.clock()

local function collectAssets(): { any }
	local seen, ids = {}, {}
	-- meshes / sounds / animations go in as their instances: a plain id string preloads as an Image, which printed
	-- "Asset type does not match requested type" for every MeshId (the Tacticals session's log check, 2026-10-17)
	local function addInst(inst, id)
		if type(id) == "string" and id ~= "" and not seen[id] and not string.find(id, "^rbxasset://") then
			seen[id] = true
			table.insert(ids, inst)
		end
	end
	local function add(id)
		if type(id) == "string" and id ~= "" and not seen[id] and not string.find(id, "^rbxasset://") then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	-- (2026-10-16, Edward: "load only the necessary things to start", like RIVALS) only what the first view needs: the UI,
	-- sky and sounds, plus the meshes / textures within 150 studs of where you spawn. The rest streams in while you play.
	local list = {}
	for _, root in { Lighting, game:GetService("SoundService"), playerGui } do
		for _, d in root:GetDescendants() do table.insert(list, d) end
	end
	local spawnAt = (function()
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then return r.Position end
		local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		return sp and sp.Position
	end)()
	if spawnAt then
		for _, part in workspace:GetPartBoundsInRadius(spawnAt, 150) do
			table.insert(list, part)
			for _, d in part:GetChildren() do table.insert(list, d) end
		end
	end
	local n = 0
	do
		for _, d in list do
			n += 1
			if n % 3000 == 0 then task.wait() end
			pcall(function()
				if d:IsA("MeshPart") then addInst(d, d.MeshId) add(d.TextureID)
				elseif d:IsA("SpecialMesh") then addInst(d, d.MeshId) add(d.TextureId)
				elseif d:IsA("Decal") then add(d.Texture)
				elseif d:IsA("Sound") then addInst(d, d.SoundId)
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then add(d.Image)
				elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then add(d.Texture)
				elseif d:IsA("Animation") then addInst(d, d.AnimationId)
				elseif d:IsA("Sky") then
					add(d.SkyboxBk) add(d.SkyboxDn) add(d.SkyboxFt) add(d.SkyboxLf) add(d.SkyboxRt) add(d.SkyboxUp)
				end
			end)
		end
	end
	return ids
end
local function waitUntil(check: () -> boolean, timeout: number)
	local t0 = os.clock()
	while not check() and os.clock() - t0 < timeout do task.wait(0.05) end
end

task.spawn(function()
	statusLine = "LOADING MAP"
	if not game:IsLoaded() then
		local t0 = os.clock()
		local creep = RunService.Heartbeat:Connect(function() progress.place = math.min(0.9, (os.clock() - t0) / 8) end)
		game.Loaded:Wait()
		creep:Disconnect()
	end
	progress.place = 1
	statusLine = "LOADING ASSETS"
	local ids = collectAssets()
	for _, s in sounds do table.insert(ids, s) end -- Sound instances (an id string would preload as an Image)
	local total = math.max(1, #ids)
	local done, finished = 0, false
	-- preload in batches: each batch's callback counts its assets as they really finish
	task.spawn(function()
		local BATCH = 40
		for i = 1, #ids, BATCH do
			local batch = table.move(ids, i, math.min(i + BATCH - 1, #ids), 1, {})
			pcall(function()
				ContentProvider:PreloadAsync(batch, function()
					done += 1
					progress.assets = math.min(1, done / total)
				end)
			end)
			done = math.max(done, math.min(i + BATCH - 1, #ids)) -- a failed asset still counts as handled
			progress.assets = math.min(1, done / total)
		end
		finished = true
	end)
	waitUntil(function() return finished end, ASSET_TIMEOUT)
	statusLine = "DEPLOYING"
	-- character: exists -> has a body -> avatar appearance loaded
	local function characterStep(): number
		local c = player.Character
		if not c then return 0 end
		local p = 0.35
		if c:FindFirstChild("HumanoidRootPart") then p = 0.7 end
		if p == 0.7 and player:HasAppearanceLoaded() then p = 1 end
		return p
	end
	if Players.CharacterAutoLoads then
		local t0 = os.clock()
		while os.clock() - t0 < 12 do
			progress.character = characterStep()
			if progress.character >= 1 then break end
			task.wait(0.05)
		end
	end
	progress.character = 1
	statusLine = "PREPARING"
	-- UI: every StarterGui screen plus the game's own UI (built by code) has to be in PlayerGui
	local expected = {}
	for _, g in game:GetService("StarterGui"):GetChildren() do
		if g:IsA("LayerCollector") then table.insert(expected, g.Name) end
	end
	local function uiStep(): number
		local found = 0
		for _, name in expected do if playerGui:FindFirstChild(name) then found += 1 end end
		local own = false
		for _, name in UI_READY do if playerGui:FindFirstChild(name) then own = true end end
		local guis = #expected > 0 and found / #expected or 1
		return guis * 0.5 + (own and 0.5 or 0)
	end
	local t1 = os.clock()
	while os.clock() - t1 < 8 do
		progress.ui = uiStep()
		if progress.ui >= 1 then break end
		task.wait(0.05)
	end
	progress.ui = 1
	statusLine = "READY"
	loaded = true
end)

local shown = 0
local function targetProgress(): number
	local p = 0
	for k, w in WEIGHTS do p += progress[k] * w end
	return p
end

-------------------------------------------------------------------------------
-- Frame loop: shake, streaks, bar, flying pieces
-------------------------------------------------------------------------------
local debris = {}
local GRAVITY = 2400 -- stage pixels / s^2
local function fling(obj: GuiObject, pos: Vector2, vel: Vector2, spin: number, life: number)
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = SP(pos.X, pos.Y)
	table.insert(debris, { obj = obj, pos = pos, vel = vel, rot = obj.Rotation, spin = spin, age = 0, life = life or 1 })
end
local frameConn = RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	if shake > 0.1 then
		local sz = gui.AbsoluteSize
		stage.Position = UDim2.fromScale(0.5 + rand(-shake, shake) / math.max(sz.X, 1), STAGE_Y + rand(-shake, shake) / math.max(sz.Y, 1))
		shake *= math.exp(-dt * 14)
	else
		stage.Position = UDim2.fromScale(0.5, STAGE_Y)
	end
	local t = os.clock()
	for _, s in streaks do s.frame.Position = UDim2.fromScale(((t * s.speed + s.phase) % 1.6) - 0.3, 0.5) end
	shown += (targetProgress() - shown) * math.min(1, dt * 5)
	fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	pctText.Text = math.floor(shown * 100 + 0.5) .. "%"
	if statusText.Text ~= statusLine then statusText.Text = statusLine end
	for i = #debris, 1, -1 do
		local d = debris[i]
		d.age += dt
		d.vel += Vector2.new(0, GRAVITY * dt)
		d.pos += d.vel * dt
		d.rot += d.spin * dt
		d.obj.Position = SP(d.pos.X, d.pos.Y)
		d.obj.Rotation = d.rot
		local fade = math.clamp((d.age - d.life * 0.5) / (d.life * 0.5), 0, 1)
		if d.obj:IsA("ImageLabel") then d.obj.ImageTransparency = fade else d.obj.BackgroundTransparency = math.max(d.base or 0, fade) end
		if d.age > d.life then
			d.obj:Destroy()
			table.remove(debris, i)
		end
	end
end)

-------------------------------------------------------------------------------
-- The sequence
-------------------------------------------------------------------------------
local skip, canSkip = false, false
local function pause(t: number)
	local t0 = os.clock()
	while os.clock() - t0 < t and not skip do task.wait() end
end

-- 1. the frame glitches in: a few chromatic flickers, then it locks
local function frameIn()
	play("Bang", 0.35, 1.4)
	for k = 1, 4 do
		local off = (5 - k) * 6
		ghosts[1].Position = SP(-off, rand(-3, 3))
		ghosts[2].Position = SP(off, rand(-3, 3))
		ghosts[1].ImageTransparency, ghosts[2].ImageTransparency = 0.35, 0.35
		backdrop.ImageTransparency = k % 2 == 0 and 0.1 or 0.6
		task.wait(0.05)
		ghosts[1].ImageTransparency, ghosts[2].ImageTransparency = 1, 1
		task.wait(0.035)
	end
	backdrop.ImageTransparency = 0
	addShake(6)
	ring(STAGE / 2, Color3.new(1, 1, 1), STAGE.X * 1.1, 0.5, 4)
end

local function dropLetter(e)
	local obj = e.obj
	local fall = gui.AbsoluteSize.Y / math.max(logoScale, 0.05) * 0.8 + e.h
	obj.Position = e.home - SP(rand(-30, 30), fall)
	obj.Rotation = rand(-22, 22)
	obj.Visible = true
	tween(obj, 0.32, { Position = e.home, Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.32, function()
		tween(obj, 0.05, { Size = SP(e.w * 1.08, e.h * 0.86) })
		task.delay(0.05, function() tween(obj, 0.3, { Size = SP(e.w, e.h) }, Enum.EasingStyle.Back) end)
		addShake(3 + e.w / 90)
		play("Thud", 0.35, rand(0.6, 0.75))
		local base = toScreen(Vector2.new(e.x + e.w / 2, e.y + e.h - 6))
		puff(base - Vector2.new(e.w * 0.35, 0), 52, -1)
		puff(base + Vector2.new(e.w * 0.35, 0), 52, 1)
	end)
end

-- GF: an ImageLabel in stage space. The sword and pistol are drawn and put away per move.
local GF_H = 118
local SWORD_SIZE, PISTOL_SIZE = UDim2.fromScale(250 / (GF_H * GF_RATIO), 26 / GF_H), UDim2.fromScale(100 / (GF_H * GF_RATIO), 66 / GF_H)
local gf = new("ImageLabel", { Name = "GF", BackgroundTransparency = 1, Image = IMG.GF, AnchorPoint = Vector2.new(0.5, 0.5),
	Size = SP(GF_H * GF_RATIO, GF_H), Position = SP(-300, 200), Visible = false, ZIndex = 30, Parent = stage }) -- hidden until the fight
-- gripped at the handle (katana) / the grip (pistol)
local sword = new("ImageLabel", { Name = "Sword", BackgroundTransparency = 1, Image = IMG.Katana, AnchorPoint = Vector2.new(0.1, 0.5), Size = SWORD_SIZE,
	Position = UDim2.new(0.82, 0, 0.6, 0), Rotation = -55, Visible = false, ZIndex = 31, Parent = gf })
local pistol = new("ImageLabel", { Name = "Pistol", BackgroundTransparency = 1, Image = IMG.Pistol, AnchorPoint = Vector2.new(0.2, 0.7), Size = PISTOL_SIZE,
	Position = UDim2.new(0.86, 0, 0.55, 0), Visible = false, ZIndex = 31, Parent = gf })

-- run fn(alpha 0..1) every frame for t seconds
local function animate(t: number, fn)
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / t, 0, 1)
		fn(a)
		if a >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end
local function gfPos(): Vector2 return Vector2.new(gf.Position.X.Scale * STAGE.X, gf.Position.Y.Scale * STAGE.Y) end
local function setPos(p: Vector2) gf.Position = SP(p.X, p.Y) end

-- jump along an arc to `to`, optionally spinning (degrees) on the way
local function hop(to: Vector2, t: number, height: number, spin: number?)
	local from, r0 = gfPos(), gf.Rotation
	animate(t, function(a)
		local e = 1 - (1 - a) * (1 - a)
		setPos(from:Lerp(to, e) - Vector2.new(0, math.sin(a * math.pi) * height))
		if spin then gf.Rotation = r0 + spin * e end
	end)
	if spin then gf.Rotation = 0 end
end

local function land()
	local base = toScreen(gfPos() + Vector2.new(0, GF_H * 0.45))
	puff(base, 60, -1)
	puff(base, 60, 1)
	play("Thud", 0.3, 1.1)
end

local function backflip(dx: number, height: number?)
	play("Whoosh", 0.5, 1.25)
	hop(gfPos() + Vector2.new(dx, 0), 0.42, height or 115, dx < 0 and -360 or 360)
	land()
end

local held = nil
local function draw(item)
	if held == item then return end
	for _, w in { sword, pistol } do
		if w ~= item and w.Visible then
			tween(w, 0.08, { Size = UDim2.fromScale(0.02, 0.03) })
			task.delay(0.08, function() w.Visible = false end)
		end
	end
	held = item
	if item then
		item.Visible = true
		item.Size = UDim2.fromScale(0.03, 0.05)
		tween(item, 0.12, { Size = item == sword and SWORD_SIZE or PISTOL_SIZE }, Enum.EasingStyle.Back)
	end
end

local function standFor(e): Vector2 return Vector2.new(e.x - 34, e.centre.Y + 8) end

local function impact(at: Vector2, big: boolean)
	local s = toScreen(at)
	ring(s, Color3.new(1, 1, 1), big and 185 or 130, 0.3, big and 4 or 3)
	sparks(s, big and 14 or 9, big and 115 or 85, { Color3.new(1, 1, 1), AMBER, big and AMBER or OLIVE })
	addShake(big and 10 or 6)
	play("Bang", big and 0.45 or 0.3, big and 1.5 or 1.9)
end

-- the letter takes the hit and flies off
local function knock(e, vel: Vector2, spin: number)
	e.gone = true
	fling(e.obj, e.centre, vel, spin, 0.95)
end

-- the letter won't budge: it rattles in place and throws sparks
local function wobble(e)
	local obj = e.obj
	local hit = toScreen(Vector2.new(e.x + e.w * 0.2, e.centre.Y))
	sparks(hit, 8, 70, { Color3.new(1, 1, 1), AMBER })
	play("Thud", 0.45, 1.6)
	addShake(4)
	task.spawn(function()
		for _, r in { 7, -6, 4, -2, 0 } do
			tween(obj, 0.05, { Rotation = r })
			task.wait(0.05)
		end
	end)
end

-- moves -----------------------------------------------------------------------
local function slice(e, approachSpin: number?)
	draw(sword)
	local stand = standFor(e)
	hop(stand, 0.065, approachSpin and 70 or 20, approachSpin)
	play("Slash", 0.6, rand(1.05, 1.25))
	sword.Rotation = -70
	tween(sword, 0.02, { Rotation = 75 }, Enum.EasingStyle.Quad)
	tween(gf, 0.02, { Rotation = -8, Position = SP(stand.X + 26, stand.Y) })
	local arc = sprite(IMG.FX, FXR.Slash, { AnchorPoint = Vector2.new(0.5, 0.5), Size = SP(e.w * 1.5, e.w * 0.47),
		Position = SP(e.centre.X, e.centre.Y), Rotation = -e.angle + 180, ZIndex = 29, Parent = stage })
	tween(arc, 0.1, { ImageTransparency = 1, Size = SP(e.w * 1.9, e.w * 0.55) })
	task.delay(0.18, function() arc:Destroy() end)
	task.wait(0.01)
	-- split along the cut: two halves (with a glowing cut edge) slide apart and fall
	e.gone = true
	e.obj.Visible = false
	local a = math.rad(e.angle)
	local n = Vector2.new(-math.sin(a), math.cos(a))
	local along = Vector2.new(math.cos(a), math.sin(a))
	for k, rect in { e.cutA, e.cutB } do
		local half = sprite(IMG.Halves, rect, { ZIndex = 20, Parent = stage })
		local side = k == 1 and -1 or 1
		-- the top half slides along the cut first, then both drop
		fling(half, e.centre, along * side * rand(120, 220) + n * side * rand(120, 240) + Vector2.new(0, -rand(150, 320)), side * rand(60, 200), 1.15)
	end
	local flashLine = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = SP(e.centre.X, e.centre.Y), Size = SP(e.w * 1.3, 4), Rotation = e.angle, ZIndex = 32, Parent = stage })
	tween(flashLine, 0.18, { BackgroundTransparency = 1, Size = SP(e.w * 1.6, 1) })
	task.delay(0.2, function() flashLine:Destroy() end)
	sparks(e.centre, 10, 105, { Color3.new(1, 1, 1), AMBER })
	addShake(7)
	task.wait(0.015)
	tween(sword, 0.04, { Rotation = -55 })
	tween(gf, 0.04, { Rotation = 0 })
end

local function punch(e, budge: boolean)
	draw(nil)
	local stand = standFor(e)
	hop(stand, 0.16, 26)
	-- jab: lunge in, squash on contact
	tween(gf, 0.06, { Position = SP(stand.X + 34, stand.Y), Rotation = 10 }, Enum.EasingStyle.Quad)
	task.wait(0.06)
	impact(Vector2.new(e.x + 8, e.centre.Y), budge)
	if budge then
		knock(e, Vector2.new(rand(900, 1300), -rand(350, 650)), rand(400, 800))
	else
		wobble(e)
	end
	tween(gf, 0.12, { Position = SP(stand.X - (budge and 0 or 18), stand.Y), Rotation = 0 }, Enum.EasingStyle.Back)
	task.wait(0.14)
end

local function kick(e, budge: boolean)
	draw(nil)
	local stand = standFor(e)
	play("Whoosh", 0.45, 1.4)
	-- spinning jump kick into the letter
	hop(stand + Vector2.new(16, 0), 0.24, 70, 360)
	impact(Vector2.new(e.x + 8, e.centre.Y - 20), budge)
	if budge then
		knock(e, Vector2.new(rand(1000, 1400), -rand(700, 1000)), rand(700, 1100))
	else
		wobble(e)
	end
	task.wait(0.12)
end

local function shoot(e, budge: boolean)
	draw(pistol)
	task.wait(0.06)
	local function muzzle()
		local m = pistol.AbsolutePosition + Vector2.new(pistol.AbsoluteSize.X * 0.97, pistol.AbsoluteSize.Y * 0.22)
		return (m - stage.AbsolutePosition) / math.max(logoScale, 0.01) -- screen px -> stage px
	end
	local target = toScreen(e.centre)
	local from = muzzle()
	local aim = math.deg(math.atan2(target.Y - from.Y, target.X - from.X))
	tween(pistol, 0.035, { Rotation = aim })
	task.wait(0.04)
	from = muzzle()
	play("Shot", 0.55, rand(0.95, 1.08))
	local fl = sprite(IMG.FX, FXR.Flash, { AnchorPoint = Vector2.new(0.5, 0.5), Size = SP(100, 100),
		Position = SP(from.X, from.Y), Rotation = rand(0, 90), ZIndex = 34, Parent = fx })
	tween(fl, 0.08, { ImageTransparency = 1, Size = SP(40, 40) })
	task.delay(0.1, function() fl:Destroy() end)
	local d = target - from
	local ang = math.deg(math.atan2(d.Y, d.X))
	tween(pistol, 0.03, { Rotation = aim - 18 })
	task.delay(0.03, function() tween(pistol, 0.08, { Rotation = aim }) end)
	-- the bullet: a hot streak that crosses the gap in a blink, with a fading trail behind it
	local bullet = new("Frame", { BackgroundColor3 = Color3.fromRGB(236, 232, 218), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = SP(from.X, from.Y), Size = SP(68, 4), Rotation = ang, ZIndex = 34, Parent = fx },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIGradient", { Transparency = NumberSequence.new(1, 0) }) })
	local tr = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = SP((from.X + target.X) / 2, (from.Y + target.Y) / 2), Size = SP(d.Magnitude, 2),
		Rotation = ang, BackgroundTransparency = 0.45, ZIndex = 33, Parent = fx })
	new("UIGradient", { Color = ColorSequence.new(AMBER, Color3.new(1, 1, 1)), Transparency = NumberSequence.new(0.8, 0.2), Parent = tr })
	tween(bullet, 0.06, { Position = SP(target.X, target.Y) }, Enum.EasingStyle.Linear)
	tween(tr, 0.14, { BackgroundTransparency = 1, Size = SP(d.Magnitude, 1) })
	task.wait(0.06)
	bullet:Destroy()
	task.delay(0.1, function() tr:Destroy() end)
	ring(target, Color3.new(1, 1, 1), 160, 0.3, 3)
	sparks(target, 12, 115, { Color3.new(1, 1, 1), OLIVE, AMBER })
	addShake(8)
	if budge then
		knock(e, Vector2.new(rand(900, 1400), -rand(500, 900)), rand(500, 900))
	else
		wobble(e)
	end
	task.wait(0.08)
end


-------------------------------------------------------------------------------
-- Finale: GF badge, the frame kicked apart, crumbling to dust
-------------------------------------------------------------------------------
-- the frame image cut into tiles (stage pixels) so it can break apart
local TILE_W, TILE_H = 64, 58
local function crack(): { any }
	local tiles = {}
	for r = 0, math.ceil(STAGE.Y / TILE_H) - 1 do
		for c = 0, math.ceil(STAGE.X / TILE_W) - 1 do
			local w, h = math.min(TILE_W, STAGE.X - c * TILE_W), math.min(TILE_H, STAGE.Y - r * TILE_H)
			local t = new("ImageLabel", { Name = "Tile", BackgroundTransparency = 1, Image = IMG.Backdrop,
				ImageRectOffset = Vector2.new(c * TILE_W, r * TILE_H), ImageRectSize = Vector2.new(w, h),
				Size = SP(w, h), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = SP(c * TILE_W + w / 2, r * TILE_H + h / 2), ImageTransparency = backdrop.ImageTransparency,
				ZIndex = 10, Parent = stage })
			table.insert(tiles, { obj = t, centre = Vector2.new(c * TILE_W + w / 2, r * TILE_H + h / 2), red = c * TILE_W + w / 2 < STAGE.X / 2 })
		end
	end
	backdrop.ImageTransparency = 1
	return tiles
end

-- a tile turns to dust: a little shudder, then specks drift down as it fades
local function dust(tile)
	if tile.gone then return end
	tile.gone = true
	local obj, at = tile.obj, tile.centre
	tween(obj, 0.12, { Rotation = rand(-8, 8), Position = SP(at.X + rand(-4, 4), at.Y + rand(-3, 3)) })
	task.delay(0.12, function()
		tween(obj, 0.35, { ImageTransparency = 1, Size = SP(TILE_W * 0.4, TILE_H * 0.4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.4, function() obj:Destroy() end)
		local col = tile.red and AMBER or OLIVE -- (tile.red = the left half of the frame)
		for _ = 1, 6 do
			local sz = rand(3, 8)
			local speck = new("Frame", { BackgroundColor3 = math.random() < 0.3 and Color3.fromRGB(200, 196, 186) or col:Lerp(Color3.new(0, 0, 0), rand(0, 0.4)),
				BorderSizePixel = 0, Size = SP(sz, sz), BackgroundTransparency = rand(0, 0.3), ZIndex = 11, Parent = stage })
			fling(speck, at + Vector2.new(rand(-TILE_W / 2, TILE_W / 2), rand(-TILE_H / 2, TILE_H / 2)), Vector2.new(rand(-60, 60), rand(-140, 20)), rand(-200, 200), rand(1.1, 1.8))
		end
	end)
end

local function logoFinale()
	-- 1. GF lands centre stage on a black rounded badge (so it reads as a logo); the background dims
	local big = 250
	local logo = new("CanvasGroup", { Name = "Logo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = SP(STAGE.X / 2, STAGE.Y / 2), Size = SP(big * GF_RATIO + 90, big + 70), ZIndex = 30, Parent = stage })
	local badgeScale = new("UIScale", { Scale = 0.2, Parent = logo })
	local box = new("Frame", { Name = "Badge", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 29, Parent = logo }, {
		new("UICorner", { CornerRadius = UDim.new(34 / (big + 70), 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 44, 40), Color3.fromRGB(6, 7, 6)) }),
	})
	new("UIStroke", { Color = AMBER, Thickness = 4, Transparency = 0.15, Parent = box })
	new("Frame", { Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0,
		Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.92, 0.4), ZIndex = 29, Parent = logo }, { new("UICorner", { CornerRadius = UDim.new(0.2, 0) }) })
	-- GF flies to the middle, then moves into the badge
	tween(gf, 0.3, { Position = SP(STAGE.X / 2, STAGE.Y / 2), Size = SP(big * GF_RATIO, big), Rotation = 0 }, Enum.EasingStyle.Back)
	task.wait(0.3)
	gf.Parent = logo
	gf.AnchorPoint = Vector2.new(0.5, 0.5)
	gf.Position = UDim2.fromScale(0.5, 0.5)
	gf.Size = UDim2.fromScale(big * GF_RATIO / (big * GF_RATIO + 90), big / (big + 70)) -- now Scale of the badge
	tween(badgeScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	play("Bang", 0.5, 1.1)
	addShake(10)
	flash.BackgroundTransparency = 0.6
	tween(flash, 0.4, { BackgroundTransparency = 1 })
	ring(STAGE / 2, AMBER, STAGE.X * 0.9, 0.55, 5)
	tween(bg, 0.6, { BackgroundTransparency = 0.25 })
	for _, g in bg:GetChildren() do if g:IsA("Frame") then tween(g, 0.6, { BackgroundTransparency = 0.9 }) end end
	for _, s in streaks do tween(s.frame, 0.6, { BackgroundTransparency = 0.95 }) end
	pause(0.35)

	-- 2. the badge kicks pieces off the frame, one blow at a time
	local tiles = crack()
	local KICKS = { Vector2.new(70, 120), Vector2.new(960, 220), Vector2.new(250, 40), Vector2.new(780, 40), Vector2.new(160, 300), Vector2.new(880, 300), Vector2.new(512, 330) }
	for _, target in KICKS do
		if skip then break end
		local dir = (target - STAGE / 2).Unit
		play("Whoosh", 0.35, rand(1.3, 1.6))
		tween(logo, 0.06, { Position = SP(STAGE.X / 2 + dir.X * 34, STAGE.Y / 2 + dir.Y * 22), Rotation = dir.X * 9 }, Enum.EasingStyle.Quad)
		task.wait(0.06)
		impact(target, true)
		for _, t in tiles do
			if not t.gone and (t.centre - target).Magnitude < 150 then
				t.gone = true
				local out = (t.centre - STAGE / 2).Unit
				fling(t.obj, t.centre, out * rand(500, 900) + Vector2.new(0, -rand(250, 550)), rand(-500, 500), rand(0.9, 1.3))
			end
		end
		tween(logo, 0.12, { Position = SP(STAGE.X / 2, STAGE.Y / 2), Rotation = 0 }, Enum.EasingStyle.Back)
		pause(0.16)
	end

	-- 3. what's left crumbles to dust and falls; the amber/olive glow swaps sides and swells
	play("Thud", 0.5, 0.55)
	addShake(5)
	for i, g in ipairs({ bg:FindFirstChild("Glow1"), bg:FindFirstChild("Glow2") }) do
		if g then tween(g, 1.2, { BackgroundColor3 = i == 1 and OLIVE or AMBER, BackgroundTransparency = 0.72 }, Enum.EasingStyle.Sine) end
	end
	for i, s in streaks do tween(s.frame, 1.2, { BackgroundColor3 = i % 2 == 1 and OLIVE or AMBER, BackgroundTransparency = 0.85 }, Enum.EasingStyle.Sine) end
	tween(fill, 1.2, { BackgroundColor3 = AMBER })
	local left = {}
	for _, t in tiles do if not t.gone then table.insert(left, t) end end
	-- crumble from the outside in
	table.sort(left, function(x, y) return math.abs(x.centre.X - STAGE.X / 2) > math.abs(y.centre.X - STAGE.X / 2) end)
	for i, t in left do
		if skip then dust(t) else
			task.delay(i / #left * 0.9, function() dust(t) end)
		end
	end
	pause(1.4)
	-- the badge settles
	tween(logo, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
	ring(STAGE / 2, OLIVE, STAGE.X * 0.6, 0.6, 4)
end

-- the fight -------------------------------------------------------------------
-- Each step is one move on one letter. Some letters won't budge to fists and feet, so GF flips
-- back and shoots them instead. A click skips straight to the end.
local L = letters
local FIGHT = {
	function() slice(L[1]) end,                                   -- T: dash in, slice
	function() kick(L[2], true) end,                              -- A: spinning kick
	function() punch(L[3], true) end,                             -- C: jab
	function() slice(L[4]) end,                                   -- T: slice
	function() punch(L[5], false) end,                            -- I: won't budge...
	function() punch(L[5], false) end,                            --    ...still won't
	function() backflip(-120) end,                                --    flip back
	function() shoot(L[5], false) shoot(L[5], true) end,          --    two shots
	function() slice(L[6], 360) end,                              -- C: flip over, slice
	function() kick(L[7], false) end,                             -- A: won't budge
	function() backflip(-110) end,
	function() shoot(L[7], true) end,                             --    shot
	function() punch(L[8], true) end,                             -- L: jab
	function() backflip(-90, 140) slice(L[9], -360) end,           -- S: flip, aerial slice
}

local function fight()
	play("Whoosh", 0.7, 0.9)
	-- (pass 44) start just past the real left edge of the screen (wide screens/phones show more than the logo's width)
	local edge = -stage.AbsolutePosition.X / math.max(logoScale, 0.01)
	gf.Position = SP(math.min(-260, edge - GF_H * GF_RATIO), 200)
	gf.Rotation = -12
	gf.Visible = true
	for _, step in FIGHT do
		if skip then break end
		step()
	end
	-- skipped: clear whatever is left
	for _, e in letters do
		if not e.gone then knock(e, Vector2.new(rand(-600, 1200), -rand(600, 1000)), rand(-600, 600)) end
	end
	draw(nil)
	logoFinale()
end

local function reveal()
	ContextActionService:UnbindAction("LoadingScreenBlock")
	local blur = new("BlurEffect", { Name = "LoadingBlur", Size = 22, Parent = Lighting })
	local time = 0.75
	tween(bg, time, { BackgroundTransparency = 1 })
	for _, g in bg:GetChildren() do if g:IsA("Frame") then tween(g, time * 0.6, { BackgroundTransparency = 1 }) end end
	for _, s in streaks do tween(s.frame, time * 0.6, { BackgroundTransparency = 1 }) end
	tween(stage, time, { Size = UDim2.fromScale(0.72 * 1.5, 0.4 * 1.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(backdrop, time * 0.8, { ImageTransparency = 1 })
	tween(gf, time, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local logo = stage:FindFirstChild("Logo")
	if logo then tween(logo, time, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
	tween(barGroup, 0.2, { GroupTransparency = 1 })
	tween(blur, 1, { Size = 0 })
	task.wait(1.05)
	blur:Destroy()
	frameConn:Disconnect()
	gui:Destroy()
	player:SetAttribute("LoadingDone", true)
end

UserInputService.InputBegan:Connect(function(input)
	if not (loaded and canSkip) then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
		or t == Enum.UserInputType.Gamepad1 then
		skip = true
	end
end)

-- preload the screen's own art first so nothing pops in blank
local own = { IMG.Backdrop, IMG.Letters, IMG.Halves, IMG.FX, IMG.GF, IMG.Katana, IMG.Pistol }
for _, s in sounds do table.insert(own, s) end
local ownDone = false
task.spawn(function()
	pcall(function() ContentProvider:PreloadAsync(own) end)
	ownDone = true
end)
-- (2026-10-21, Edward: the logo looked pixelated for a moment on phone / tablet) 4 s ran out on mobile and the letters dropped
-- in on their low-res first pass: wait longer for the screen's own art before the logo appears
waitUntil(function() return ownDone end, 10)

-- 1. frame + letters while the game loads, with the bar under them
pause(0.2)
frameIn()
pause(0.15)
for _, e in letters do
	dropLetter(e)
	pause(0.07)
end
pause(0.4)
fit()
tween(barGroup, 0.35, { GroupTransparency = 0 })
while not loaded and os.clock() - startTime < MAX_LOAD_TIME do task.wait() end
loaded = true
progress.place, progress.assets, progress.character, progress.ui = 1, 1, 1, 1
task.wait(0.45)

if script:GetAttribute("QuickIntro") == true then
	-- 2q. match place: report in, hold for the other players, then the logo crumbles (no GF, no skipping: both sides wait the same)
	local RS = game:GetService("ReplicatedStorage")
	task.spawn(function()
		local ev = RS:WaitForChild("MatchFlow", 20)
		if ev then ev:FireServer("Loaded") end
	end)
	local function phase() return RS:GetAttribute("MatchPhase") end
	local t0 = os.clock()
	while phase() == nil and os.clock() - t0 < 3 do task.wait(0.1) end -- the server sets the phase right after the teleport
	if phase() == "Loading" then
		-- the server counts who has loaded (LoadedCount / LoadedTotal; bots count as loaded)
		while phase() == "Loading" and os.clock() - t0 < 90 do
			local n, total = RS:GetAttribute("LoadedCount"), RS:GetAttribute("LoadedTotal")
			statusLine = (type(n) == "number" and type(total) == "number" and total > 0)
				and string.format("WAITING FOR PLAYERS  %d/%d READY", n, total) or "WAITING FOR OPPONENT"
			task.wait(0.05)
		end
	end
	statusLine = "READY"
	task.wait(0.25)
	tween(barGroup, 0.2, { GroupTransparency = 1 })
	-- the letters go first (outside in), then the frame
	play("Thud", 0.5, 0.55)
	addShake(6)
	local bits = {}
	for _, e in letters do
		if e.obj.Visible then table.insert(bits, { obj = e.obj, centre = e.centre, red = e.centre.X < STAGE.X / 2 }) end
	end
	table.sort(bits, function(x, y) return math.abs(x.centre.X - STAGE.X / 2) > math.abs(y.centre.X - STAGE.X / 2) end)
	for i, b in bits do task.delay(i / #bits * 0.45, function() dust(b) end) end
	task.wait(0.35)
	local tiles = crack()
	table.sort(tiles, function(x, y) return math.abs(x.centre.X - STAGE.X / 2) > math.abs(y.centre.X - STAGE.X / 2) end)
	for i, t in tiles do task.delay(i / #tiles * 0.7, function() dust(t) end) end
	for i, g in ipairs({ bg:FindFirstChild("Glow1"), bg:FindFirstChild("Glow2") }) do
		if g then tween(g, 1, { BackgroundColor3 = i == 1 and OLIVE or AMBER, BackgroundTransparency = 0.72 }, Enum.EasingStyle.Sine) end
	end
	task.wait(1.1)
	reveal()
	return
end

-- 2. fully loaded: the bar goes and GF comes in to clear the letters (click to skip)
tween(barGroup, 0.2, { GroupTransparency = 1 })
canSkip = true
-- (2026-10-16, Edward) the game is ready: say so, any key / click skips the rest of the intro
do
	local prompt = new("TextLabel", { Name = "SkipPrompt", BackgroundTransparency = 1, Text = "PRESS ANY KEY TO CONTINUE",
		FontFace = Font.new(FONT, Enum.FontWeight.Bold), TextScaled = true, TextColor3 = Color3.fromRGB(236, 232, 218),
		TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.94), Size = UDim2.fromScale(0.4, 0.03),
		ZIndex = 50, Parent = gui })
	task.spawn(function()
		while prompt.Parent and not skip do
			tween(prompt, 0.6, { TextTransparency = 0.05 }) task.wait(0.7)
			tween(prompt, 0.6, { TextTransparency = 0.6 }) task.wait(0.7)
		end
		if prompt.Parent then tween(prompt, 0.2, { TextTransparency = 1 }) end
	end)
end
fight()
pause(0.9)
reveal()

