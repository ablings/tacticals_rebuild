-- Client/Controllers/MatchFoundGate (ModuleScript, auto-loaded; lobby). UI session, Shadow PC, 2026-10-19.
-- Edward: "when you find a game in ranked it should automatically remove all the ui aspects on your screen to show that you
-- found a game when you are connected to one this includes the ranked screen".
-- ONE gate for every screen instead of per-screen hacks: while the player attribute MM_Status is "Found" or "Teleporting"
-- (MatchmakingManager; any online queue, ranked included):
--   * every LayerCollector in PlayerGui (ScreenGuis: Ranked, Play, Kit, Shop, Settings, Inbox / News, the HUD corner, the play
--     row, missions, party, toasts...; BillboardGuis: the nameplates) is switched off, except KEEP below. What each one wanted is
--     remembered (and kept up to date if a script turns one on while the gate is up, or a new one appears), then put back
--     exactly when the gate drops. ProximityPromptService is off and the Roblox player list hidden too.
--   * only PadUI's teleport screen (TACTICALS wordmark, mode, tip, Loading counter; handed to TeleportService) stays, with a
--     big centred MATCH FOUND (+ RANKED / mode) on top of it here, which steps aside once Teleporting starts.
--   * our hotkeys (letters, numbers, Tab, Esc, the gamepad buttons) are sunk at a high ContextAction priority, so no menu opens.
-- Falls through (MM_Status leaves Found / Teleporting without a teleport, or TeleportInitFailed): everything is restored and a
-- Whoops says so, with the server's MM_FailReason when set (fix/mm_failreason.lua; set just before MM_Status -> nil).
-- Server order (MatchmakingManager): Searching -> Found -> 1.2 s -> Teleporting, MM_Queue set throughout (ranked ids start
-- with "R"); a failure sets MM_Status AND MM_Queue nil (not re-queued). Studio: Found -> nil after 2.5 s. UI rule: Scale only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local controller = {}
local player = Players.LocalPlayer
local KEEP = { PadUI = true, MatchFoundUI = true, TacticalsTeleport = true, LoadingScreen = true, Whoops = true }
local ON = { Found = true, Teleporting = true }

local active = false
local wanted = {}          -- [LayerCollector] = Enabled it should have when the gate drops
local conns = {}
local gui, stamp, sub
local promptsWas, listWas
local failedAt = nil       -- a TeleportInitFailed: stay down until MM_Status changes again

local okKit, Kit = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Kit")) end)
local okCfg, Config = pcall(function() return require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig) end)

local function modeText()
	local q = player:GetAttribute("MM_Queue")
	if q == nil then return "" end
	local oq = okCfg and Config.QueueById and Config.QueueById(q)
	if oq then return (oq.Ranked and "RANKED  ·  " or "") .. string.upper(tostring(oq.Mode or "")) end
	-- (2026-10-20 review: the line was blank) unknown to QueueById: read the id itself. Ranked ids start with "R" ("R1v1"),
	-- a bare "Ranked" is just RANKED
	local s = tostring(q)
	if s:lower() == "ranked" then return "RANKED" end
	local ranked = s:match("^R%d") ~= nil
	local mode = ranked and s:sub(2) or s
	return (ranked and "RANKED  ·  " or "") .. string.upper(mode)
end

local function build()
	if gui and gui.Parent then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "MatchFoundUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	-- its own backdrop (the teleport screen's colours) while Found; it fades at Teleporting to show PadUI's loading screen
	local back = Instance.new("Frame")
	back.Name = "Backdrop"
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = gui
	local bg = Instance.new("UIGradient"); bg.Rotation = 90
	bg.Color = ColorSequence.new(Color3.fromRGB(32, 37, 27), Color3.fromRGB(8, 9, 7)); bg.Parent = back
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 16 / 9; ar.Parent = canvas
	local function text(name, y, h, str, color, weight)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.8, h)
		l.Text = str
		l.TextScaled = true
		l.TextColor3 = color
		l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", weight)
		local st = Instance.new("UIStroke"); st.Thickness = 3; st.Transparency = 0.2; st.Parent = l
		l.Parent = canvas
		return l
	end
	-- sits over the teleport screen's wordmark, which it covers until Teleporting
	stamp = text("MatchFound", 0.4, 0.17, "MATCH FOUND", Color3.fromRGB(236, 232, 218), Enum.FontWeight.Bold)
	sub = text("Mode", 0.53, 0.05, "", Color3.fromRGB(138, 156, 74), Enum.FontWeight.Bold)
	local sc = Instance.new("UIScale"); sc.Name = "Pop"; sc.Parent = stamp
end

local function sink() return Enum.ContextActionResult.Sink end
-- A-Z, 0-9, Tab, Esc, ` and the gamepad buttons (a TextBox with focus, i.e. chat, still types: CAS skips it)
local SINK_KEYS = {}
local EXTRA = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Tab", "Escape", "Backquote",
	"ButtonA", "ButtonB", "ButtonX", "ButtonY", "ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2", "ButtonSelect",
	"DPadUp", "DPadDown", "DPadLeft", "DPadRight" }
for c = string.byte("A"), string.byte("Z") do table.insert(SINK_KEYS, Enum.KeyCode[string.char(c)]) end
for _, n in EXTRA do table.insert(SINK_KEYS, Enum.KeyCode[n]) end

local function hold(g)
	if KEEP[g.Name] or wanted[g] ~= nil then return end
	wanted[g] = g.Enabled
	g.Enabled = false
	table.insert(conns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
		if active and g.Enabled then wanted[g] = true; g.Enabled = false end   -- a script asked for it: remember, keep it off
	end))
end

local function enter()
	if active then return end
	active = true
	build()
	local pg = player:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do if g:IsA("LayerCollector") then hold(g) end end
	table.insert(conns, pg.ChildAdded:Connect(function(g) if g:IsA("LayerCollector") then task.defer(hold, g) end end))
	-- close our menus first, so their blur / free mouse don't linger (they come back closed only if a fall-through happens)
	pcall(function()
		local LobbyUI = shared.Get and shared.Get("LobbyUIController")
		if LobbyUI and LobbyUI.CloseScreens then LobbyUI.CloseScreens() end
	end)
	pcall(function()
		local TB = shared.Get and shared.Get("TrainingBinsController")
		if TB and TB.Close then TB.Close() end
	end)
	promptsWas = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	local ok, v = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList)
	listWas = ok and v
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	ContextActionService:BindActionAtPriority("MatchFoundGate", sink, false, 5000, table.unpack(SINK_KEYS))
	-- the stamp
	sub.Text = modeText()
	gui.Enabled = true
	local pop = stamp.Pop
	pop.Scale = 1.25
	stamp.TextTransparency = 1
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(stamp, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
end

local function exit(fellThrough)
	if not active then return end
	active = false
	ContextActionService:UnbindAction("MatchFoundGate")
	for _, c in conns do c:Disconnect() end
	table.clear(conns)
	for g, en in wanted do if g.Parent then g.Enabled = en end end
	table.clear(wanted)
	if promptsWas ~= nil then ProximityPromptService.Enabled = promptsWas end
	if listWas ~= nil then pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, listWas) end
	if gui then gui.Enabled = false end
	if fellThrough and okKit and Kit.whoops then
		Kit.whoops(type(fellThrough) == "string" and fellThrough or "The match fell through. You're back in the lobby.")
	end
end

local function update()
	local st = player:GetAttribute("MM_Status")
	if ON[st] and not failedAt then
		enter()
		-- Teleporting: the teleport screen's own wordmark + Loading take over
		if gui and st == "Teleporting" then
			local ti = TweenInfo.new(0.3)
			TweenService:Create(stamp, ti, { TextTransparency = 1 }):Play()
			TweenService:Create(sub, ti, { TextTransparency = 1 }):Play()
			TweenService:Create(gui.Backdrop, ti, { BackgroundTransparency = 1 }):Play()
			for _, s in { stamp, sub } do
				local st2 = s:FindFirstChildOfClass("UIStroke"); if st2 then TweenService:Create(st2, ti, { Transparency = 1 }):Play() end
			end
		elseif gui then
			stamp.TextTransparency, sub.TextTransparency, gui.Backdrop.BackgroundTransparency = 0, 0, 0
			for _, s in { stamp, sub } do
				local st2 = s:FindFirstChildOfClass("UIStroke"); if st2 then st2.Transparency = 0.2 end
			end
			sub.Text = modeText()
		end
	elseif active then
		local reason = player:GetAttribute("MM_FailReason")
		exit(type(reason) == "string" and reason ~= "" and reason or true)
	end
end

function controller.IsActive() return active end
-- Studio test hook: MatchFoundGate.Test("Found" | "Teleporting" | nil) drives the gate without a real match
function controller.Test(status)
	if RunService:IsStudio() then player:SetAttribute("MM_Status", status) end
end

function controller.Start()
	if not player then return end
	player:GetAttributeChangedSignal("MM_Status"):Connect(function()
		failedAt = nil
		update()
	end)
	player:GetAttributeChangedSignal("MM_Queue"):Connect(function()
		if active and sub and player:GetAttribute("MM_Queue") ~= nil then sub.Text = modeText() end   -- a late queue id still shows
	end)
	TeleportService.TeleportInitFailed:Connect(function(p, _, msg)
		if p ~= player or not active then return end
		warn("[MatchFoundGate] teleport failed: " .. tostring(msg))
		-- the server normally answers first (MM_FailReason, then MM_Status -> nil); this is the backstop if it doesn't
		task.delay(1.5, function()
			if not active then return end
			failedAt = os.clock()
			local reason = player:GetAttribute("MM_FailReason")
			exit(type(reason) == "string" and reason ~= "" and reason or "Teleport failed: " .. tostring(msg))
		end)
	end)
	update()
end

return controller
