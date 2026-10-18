-- DuelHUD (match place AND lobby, StarterPlayerScripts, LocalScript): RIVALS' in-match HUD in TACTICALS (UI session 2026-10-16).
-- Contract: notes/lobby_duels_design.md section 6. Same state object as MatchFlowUI: ReplicatedStorage (match place) or
-- ReplicatedStorage.LobbyDuels[DuelMatch or DuelSpectate] (lobby).
--   * Score bar (top centre): your team's box left, theirs right (headshots in TeamA/TeamB order, dimmed + crossed when not
--     Alive), the round wins in each box, and the round timer between them (StateEndsAt).
--   * Round banner: "ROUND N" on Countdown with the big countdown number, "ROUND WON" / "ROUND LOST" on RoundEnd
--     (from the score change), plus MatchAnnounce titles.
--   * Kill feed (top right): MatchFlow "Kill" events, killer > weapon > victim, headshot mark, fades after 5 s.
--   * Spectate (spectators and dead duelists): "SPECTATING <name>" bar at the bottom, Q / E cycle Alive players, own team
--     first for duelists; exposes PlayerScripts.DuelSpectate (Get / Set). The camera code follows it.
--   * Results (MatchEnd + MatchResults): VICTORY / DEFEAT / DRAW card with the score, kills / deaths / headshots, XP and
--     scissors earned, and a LEAVE button (MatchFlow "Leave").
-- Built in 1920x1080 design px on a 16:9 canvas, converted to Scale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local W, H = 1920, 1080
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local OLIVE_HI = Color3.fromRGB(150, 172, 84)
local TEAM_A = { Color3.fromRGB(198, 206, 168), Color3.fromRGB(96, 108, 56) }
local TEAM_B = { Color3.fromRGB(232, 92, 72), Color3.fromRGB(140, 36, 28) }
local GOOD, BAD = Color3.fromRGB(110, 220, 80), Color3.fromRGB(235, 70, 60)
local FX = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local STENCIL = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

---------------------------------------------------------------------------------------------------- state
local function stateObject()
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	if id then
		local f = ReplicatedStorage:FindFirstChild("LobbyDuels")
		return f and f:FindFirstChild(tostring(id)), id
	end
	return ReplicatedStorage, nil
end
local function st(name) local o = stateObject(); return o and o:GetAttribute(name) end
local function send(...)
	local ev = ReplicatedStorage:FindFirstChild("MatchFlow")
	if not ev then return end
	local _, id = stateObject()
	if id then ev:FireServer(id, ...) else ev:FireServer(...) end
end
-- the hub (lobby duels). The match places also get a LobbyMap after a match (the pseudo lobby: ReplicatedStorage attribute
-- PseudoLobbyMap), so the map alone doesn't mean the hub.
local function inLobby()
	if ReplicatedStorage:GetAttribute("PseudoLobbyMap") == true then return false end
	return ReplicatedStorage:FindFirstChild("LobbyDuels") ~= nil or workspace:FindFirstChild("LobbyMap") ~= nil
end
local function inMatch()
	-- lobby: only while this player's match object exists (it's destroyed on the return)
	if inLobby() then return stateObject() ~= nil and stateObject() ~= ReplicatedStorage end
	return player:GetAttribute("InMatch") == true or ReplicatedStorage:GetAttribute("LiveMatch") == true
end
local function spectator() return player:GetAttribute("DuelSpectate") ~= nil and player:GetAttribute("DuelMatch") == nil end
local function teamIds(key)
	local ok, ids = pcall(function() return HttpService:JSONDecode(st(key) or "[]") end)
	return (ok and type(ids) == "table") and ids or {}
end

---------------------------------------------------------------------------------------------------- build helpers
local function new(class, props, kids)
	local o = Instance.new(class)
	for k, v in props or {} do if k ~= "Parent" then o[k] = v end end
	for _, k in kids or {} do k.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
-- (2026-10-18, Edward: "as aesthetically pleasing as rivals") RIVALS' glossy panels: a white sheen over the top half
local function gloss(f, r, strength)
	return new("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.5), ZIndex = (f.ZIndex or 1) + 1, Parent = f }, {
		corner(r or 8), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - (strength or 0.3)), NumberSequenceKeypoint.new(1, 1) }) }) })
end
-- a bright bar that sweeps across a card once (round card, banners)
local function sweep(f, z)
	local bar = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.5),
		Size = UDim2.fromScale(0.18, 1.6), Rotation = 20, ZIndex = z or 9, Parent = f }, {
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }) }) })
	f.ClipsDescendants = true
	local tw = game:GetService("TweenService"):Create(bar, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) })
	tw.Completed:Once(function() bar:Destroy() end)
	tw:Play()
end
local scaled = {}
local function label(parent, text, font, size, x, y, w, h, color, align, z)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = font, TextSize = size, TextColor3 = color or WHITE,
		TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3, Parent = parent })
	l:SetAttribute("dTS", size)
	new("UIStroke", { Thickness = math.max(1.5, size / 22), Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end
local function toScale(g, pd)
	for _, c in g:GetChildren() do
		if c:IsA("GuiObject") then
			local w = c.Size.X.Scale * pd.X + c.Size.X.Offset
			local h = c.Size.Y.Scale * pd.Y + c.Size.Y.Offset
			local x = c.Position.X.Scale * pd.X + c.Position.X.Offset
			local y = c.Position.Y.Scale * pd.Y + c.Position.Y.Offset
			c.Size = UDim2.fromScale(pd.X > 0 and w / pd.X or 0, pd.Y > 0 and h / pd.Y or 0)
			c.Position = UDim2.fromScale(pd.X > 0 and x / pd.X or 0, pd.Y > 0 and y / pd.Y or 0)
			if c:GetAttribute("dTS") then table.insert(scaled, c) end
			toScale(c, Vector2.new(w, h))
		elseif c:IsA("UICorner") then
			c:SetAttribute("dR", c:GetAttribute("dR") or c.CornerRadius.Offset)
			table.insert(scaled, c)
		end
	end
end

local gui = new("ScreenGui", { Name = "DuelHUD", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 12,
	Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1), Parent = gui }, { new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local function rescale()
	local f = canvas.AbsoluteSize.Y / H
	for _, n in scaled do
		if n.Parent then
			if n:IsA("UICorner") then n.CornerRadius = UDim.new(0, (n:GetAttribute("dR") or 6) * f)
			else n.TextSize = math.max(1, math.floor(n:GetAttribute("dTS") * f + 0.5)) end
		end
	end
end
canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Parent = canvas })

---------------------------------------------------------------------------------------------------- score bar
local function teamBox(x, cols, right)
	local b = new("Frame", { Position = UDim2.fromOffset(x, 20), Size = UDim2.fromOffset(300, 84), BackgroundColor3 = WHITE, Parent = root },
		{ corner(10), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }),
			new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	gloss(b, 10, 0.28)
	local slots = {}
	for i = 1, 3 do
		local hx = right and (96 + (i - 1) * 64) or (14 + (i - 1) * 64)
		local h = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(hx, 14), Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 3, Parent = b }, { corner(28) })
		local x1 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(28, 28), Size = UDim2.fromOffset(52, 6), BackgroundColor3 = BAD, Visible = false, ZIndex = 4, Parent = h })
		local x2 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -45, Position = UDim2.fromOffset(28, 28), Size = UDim2.fromOffset(52, 6), BackgroundColor3 = BAD, Visible = false, ZIndex = 4, Parent = h })
		-- (2026-10-18, live RIVALS) a dead player's head turns into a skull: cranium, eye holes, nose, jaw with teeth gaps
		local BONE = Color3.fromRGB(236, 232, 218)
		local skull = new("Frame", { Name = "Skull", BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 5, Parent = h })
		new("Frame", { BackgroundColor3 = BONE, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(36, 30), ZIndex = 5, Parent = skull }, { corner(15) })
		new("Frame", { BackgroundColor3 = BONE, Position = UDim2.fromOffset(17, 32), Size = UDim2.fromOffset(22, 14), ZIndex = 5, Parent = skull }, { corner(4) })
		for _, ex in { 16, 30 } do new("Frame", { BackgroundColor3 = BLACK, Position = UDim2.fromOffset(ex, 20), Size = UDim2.fromOffset(10, 10), ZIndex = 6, Parent = skull }, { corner(5) }) end
		new("Frame", { BackgroundColor3 = BLACK, Position = UDim2.fromOffset(26, 31), Size = UDim2.fromOffset(4, 5), ZIndex = 6, Parent = skull })
		for _, tx in { 23, 28, 33 } do new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(tx - 1, 40), Size = UDim2.fromOffset(2, 6), ZIndex = 6, Parent = skull }) end
		slots[i] = { h = h, x1 = x1, x2 = x2, skull = skull }
	end
	local score = label(b, "0", FX, 54, right and 8 or 222, 6, 70, 72, WHITE, nil, 4)
	return { slots = slots, score = score, frame = b }
end
local mineBox = teamBox(580, TEAM_A, false)
local theirBox = teamBox(1040, TEAM_B, true)
local timerBox = new("Frame", { Position = UDim2.fromOffset(888, 20), Size = UDim2.fromOffset(144, 84), BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Parent = root }, { corner(10),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 48, 52), Color3.fromRGB(12, 13, 15)) }),
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
local timerL = label(timerBox, "0:00", FX, 40, 0, 4, 144, 50, WHITE)
-- (2026-10-18) the hourglass shown left of the time between rounds: top and bottom caps, two crossing glass sides
do local hourglass = new("Frame", { Name = "Hourglass", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(24, 36), Visible = false, ZIndex = 4, Parent = timerBox })
new("Frame", { BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(24, 5), ZIndex = 4, Parent = hourglass }, { corner(2) })
new("Frame", { BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(24, 5), ZIndex = 4, Parent = hourglass }, { corner(2) })
for _, rot in { 33, -33 } do
	new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 18), Size = UDim2.fromOffset(4, 32), Rotation = rot, ZIndex = 4, Parent = hourglass })
end end
local roundL = label(timerBox, "ROUND 1", STENCIL, 18, 0, 52, 144, 26, Color3.fromRGB(205, 205, 212))
local toWin = label(root, "", FB, 18, 760, 108, 400, 24, Color3.fromRGB(205, 205, 212))

---------------------------------------------------------------------------------------------------- round banner
local banner = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Position = UDim2.fromOffset(360, 330), Size = UDim2.fromOffset(1200, 260), Visible = false, Parent = root })
new("Frame", { Name = "Band", BackgroundColor3 = BLACK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(1200, 210), ZIndex = 4, Parent = banner }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1) }) }) })
local bannerTitle = label(banner, "", STENCIL, 110, 0, 0, 1200, 140, WHITE, nil, 5)
local bannerSub = label(banner, "", FX, 48, 0, 140, 1200, 70, Color3.fromRGB(225, 225, 230), nil, 5)
local bannerScale = new("UIScale", { Parent = banner })
local bannerToken = 0
local function showBanner(title, sub, color, seconds)
	bannerToken += 1
	local my = bannerToken
	bannerTitle.Text = title; bannerTitle.TextColor3 = color or WHITE
	bannerSub.Text = sub or ""
	banner.Visible = true
	bannerScale.Scale = 1.25
	TweenService:Create(bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- the title slides in from the left and fades up (RIVALS-style entrance)
	local home = bannerTitle.Position
	bannerTitle.Position = home - UDim2.fromScale(0.06, 0)
	bannerTitle.TextTransparency = 1
	TweenService:Create(bannerTitle, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Position = home, TextTransparency = 0 }):Play()
	if seconds then task.delay(seconds, function() if bannerToken == my then banner.Visible = false end end) end
end

---------------------------------------------------------------------------------------------------- kill feed
local feed = new("Frame", { Name = "KillFeed", BackgroundTransparency = 1, Position = UDim2.fromOffset(1420, 130), Size = UDim2.fromOffset(480, 300), Parent = root },
	{ new("UIListLayout", { Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
local feedN = 0
local function botModel(uid)
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("SpectateId") == uid then return m end
	end
	return nil
end
local function nameOf(uid)
	if (uid or 0) < 0 then local m = botModel(uid); return m and m.Name or "Bot" end
	local p = Players:GetPlayerByUserId(uid or 0)
	return p and p.DisplayName or "?"
end
local function teamOf(uid)
	if table.find(teamIds("TeamA"), uid) then return "A" end
	if table.find(teamIds("TeamB"), uid) then return "B" end
	local p = Players:GetPlayerByUserId(uid or 0)
	return p and p:GetAttribute("Team")
end
local botDown = {} -- bot uid -> true once killed this round (cleared when the next round starts)
local showEliminated -- set below: "Eliminated <name>" under the crosshair
local lastDeath -- the kill event that killed you (the kill-cam card shows how)
local tally = {} -- uid -> { k, d, hs } from this match's kill events (headshots and bots have no attribute)
local function tallyOf(uid) tally[uid] = tally[uid] or { k = 0, d = 0, hs = 0 }; return tally[uid] end
local function addKill(d)
	feedN += 1
	if d.killer then local t = tallyOf(d.killer); t.k += 1; if d.headshot then t.hs += 1 end end
	if d.victim then tallyOf(d.victim).d += 1 end
	if d.victim == player.UserId then lastDeath = d end
	if d.victim and d.victim < 0 then botDown[d.victim] = true end
	if d.killer == player.UserId and d.victim and d.victim ~= player.UserId and showEliminated then showEliminated(d.victim) end
	local myTeam = player:GetAttribute("Team")
	local function col(uid) return WHITE end -- (names white on the team-coloured row, RIVALS)
	-- (2026-10-18, live RIVALS) the row is in the killer's team colour: yours when your side got the kill, red when theirs
	local ours = d.killer == player.UserId or teamOf(d.killer) == myTeam
	local rc = ours and TEAM_A or TEAM_B
	local row = new("Frame", { LayoutOrder = -feedN, Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = WHITE, BackgroundTransparency = 0.05, Parent = feed },
		{ new("UICorner", { CornerRadius = UDim.new(0.25, 0) }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rc[1], rc[2]) }) })
	local mine = d.killer == player.UserId or d.victim == player.UserId
	if mine then new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row }) end
	local verb = d.kind == "Melee" and "bashed" or (d.kind == "Explosion" and "blew up" or (d.kind == "Burn" and "burned" or ">"))
	local txt = string.format('<font color="#%s">%s</font>  %s%s  <font color="#%s">%s</font>', col(d.killer):ToHex(), nameOf(d.killer),
		verb, d.headshot and "  ◉" or "", col(d.victim):ToHex(), nameOf(d.victim)) -- (◉: BuilderSans has no ✦)
	local l = new("TextLabel", { BackgroundTransparency = 1, RichText = true, Text = txt, FontFace = FB, TextScaled = true, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.94, 0.7), Parent = row })
	new("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = l })
	gloss(row, 8, 0.22)
	local ins = new("UIScale", { Scale = 0.6, Parent = row })
	TweenService:Create(ins, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(5, function()
		if row.Parent then
			TweenService:Create(row, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.45, function() row:Destroy() end)
		end
	end)
	local kids = {}
	for _, c in feed:GetChildren() do if c:IsA("Frame") then table.insert(kids, c) end end
	if #kids > 5 then table.sort(kids, function(a, b) return a.LayoutOrder > b.LayoutOrder end); kids[1]:Destroy() end
end

---------------------------------------------------------------------------------------------------- spectate
-- (2026-10-17, Edward: kill-cam) dead in a round = you watch your killer: the Tacticals session sets the player attribute
-- SpectateTarget = killer UserId (SpectateReason "Killer") until the next round. The card: "KILLED BY" in red (or
-- "SPECTATING"), the killer's headshot, name, live health bar and how they got you; Q / E (or the arrows) still cycle.
local specBar = new("Frame", { Name = "Spectate", Position = UDim2.fromOffset(620, 900), Size = UDim2.fromOffset(680, 120), BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.3, Visible = false, Parent = root }, { corner(14), new("UIStroke", { Color = WHITE, Transparency = 0.85, Thickness = 1.5 }) })
local specHead = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(30, 34, 28), Position = UDim2.fromOffset(96, 14), Size = UDim2.fromOffset(92, 92), Parent = specBar }, { corner(10) })
local specTitle = label(specBar, "SPECTATING", STENCIL, 24, 206, 8, 380, 30, Color3.fromRGB(205, 205, 212))
specTitle.TextXAlignment = Enum.TextXAlignment.Left
local specName = label(specBar, "", FX, 36, 206, 34, 380, 44, WHITE)
specName.TextXAlignment = Enum.TextXAlignment.Left
local hpBack = new("Frame", { Position = UDim2.fromOffset(206, 82), Size = UDim2.fromOffset(300, 14), BackgroundColor3 = Color3.fromRGB(40, 44, 38), Parent = specBar }, { corner(7) })
local hpFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOOD, Parent = hpBack }, { corner(7) })
local hpText = label(specBar, "", FB, 20, 514, 76, 80, 26, WHITE)
hpText.TextXAlignment = Enum.TextXAlignment.Left
local specHow = label(specBar, "", FB, 20, 206, 98, 380, 22, Color3.fromRGB(180, 182, 172))
specHow.TextXAlignment = Enum.TextXAlignment.Left
local specPrev = label(specBar, "Q  <", FX, 28, 10, 36, 80, 48, Color3.fromRGB(205, 205, 212))
local specNext = label(specBar, ">  E", FX, 28, 596, 36, 80, 48, Color3.fromRGB(205, 205, 212))
local specStop = new("TextButton", { Name = "StopSpectate", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1280, 950), Size = UDim2.fromOffset(150, 52),
	BackgroundColor3 = WHITE, Visible = false, Parent = root }, { corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(240, 110, 100), Color3.fromRGB(170, 40, 30)) }) })
label(specStop, "Stop", FX, 30, 0, 0, 150, 52, WHITE)
specStop.Activated:Connect(function() send("StopSpectate") end)

local target
local killcamPicked = nil -- the SpectateTarget we last jumped to (Q / E may move off it)
local function aliveList()
	local myTeam = player:GetAttribute("Team")
	local own, other = {}, {}
	for _, key in { "TeamA", "TeamB" } do
		for _, uid in teamIds(key) do
			local p = Players:GetPlayerByUserId(uid)
			if p and p ~= player and p:GetAttribute("Alive") == true then
				table.insert((not spectator() and teamOf(uid) == myTeam) and own or other, uid)
			end
		end
	end
	for _, u in other do table.insert(own, u) end
	return own
end
local headFor -- the uid whose headshot is loaded
local function setTarget(uid)
	target = uid
	specName.Text = uid and nameOf(uid) or "..."
	if uid ~= headFor then
		headFor = uid
		specHead.Image = ""
		if uid and uid > 0 then
			task.spawn(function()
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if ok and headFor == uid then specHead.Image = img end
			end)
		end
	end
end
-- the card's live part: who it is, their health, and "KILLED BY" when it's your killer
local function targetModel(uid)
	if not uid then return nil end
	local p = Players:GetPlayerByUserId(uid)
	if p then return p.Character end
	return botModel(uid)
end
local function refreshSpecCard()
	local killer = player:GetAttribute("SpectateTarget")
	local isKiller = killer ~= nil and target == killer and player:GetAttribute("SpectateReason") == "Killer" and not spectator()
	specName.Text = target and nameOf(target) or "..." -- live (a bot id can move to a new model)
	specTitle.Text = isKiller and "KILLED BY" or "SPECTATING"
	specTitle.TextColor3 = isKiller and BAD or Color3.fromRGB(205, 205, 212)
	local how = ""
	if isKiller and lastDeath and lastDeath.killer == killer then
		local kind = lastDeath.kind == "Melee" and "a melee hit" or (lastDeath.kind == "Explosion" and "an explosion" or (lastDeath.kind == "Burn" and "fire" or nil))
		how = (lastDeath.weapon and ("with " .. tostring(lastDeath.weapon)) or (kind and ("with " .. kind) or "")) .. (lastDeath.headshot and "  ·  HEADSHOT" or "")
	end
	specHow.Text = how
	local m = targetModel(target)
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	local frac = hum and hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
	hpFill.Size = UDim2.fromScale(frac, 1)
	hpFill.BackgroundColor3 = frac > 0.5 and GOOD or (frac > 0.25 and Color3.fromRGB(235, 190, 60) or BAD)
	hpText.Text = hum and tostring(math.ceil(hum.Health)) or ""
	local many = #aliveList() > 1
	specPrev.Visible, specNext.Visible = many, many
end
local function cycle(step)
	local list = aliveList()
	if #list == 0 then setTarget(nil) return end
	local i = table.find(list, target) or 0
	setTarget(list[(i - 1 + step) % #list + 1])
end
do
	local hook = Instance.new("BindableFunction")
	hook.Name = "DuelSpectate"
	hook.OnInvoke = function(cmd, uid)
		if cmd == "Set" then setTarget(uid) end
		return target
	end
	hook.Parent = player:WaitForChild("PlayerScripts")
end
UserInputService.InputBegan:Connect(function(i, gp)
	if gp or not specBar.Visible then return end
	if i.KeyCode == Enum.KeyCode.Q then cycle(-1) elseif i.KeyCode == Enum.KeyCode.E then cycle(1) end
end)

local leaveDuel = new("TextButton", { Name = "LeaveDuel", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(30, 30), Size = UDim2.fromOffset(150, 52),
	BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Visible = false, Parent = root }, { corner(10) })
label(leaveDuel, "Leave", FX, 28, 0, 0, 150, 52, WHITE)
local leaveArmed = 0
leaveDuel.Activated:Connect(function()
	-- forfeit asks twice (RIVALS-style confirm: the button turns red for 3 s)
	if os.clock() - leaveArmed < 3 then send("Leave"); leaveDuel.Visible = false; return end
	leaveArmed = os.clock()
	-- ranked: say what leaving costs before the second click (RankedCore.Config.LeavePenalty)
	if st("MatchRanked") == true or ReplicatedStorage:GetAttribute("PlaceKind") == "Ranked" then
		local pen = 25
		pcall(function() pen = require(ReplicatedStorage.Modules.Shared.RankedCore).Config.LeavePenalty or 25 end)
		showBanner("LEAVE RANKED?", "Click again: your normal loss + " .. pen .. " ELO", BAD, 3)
	end
	leaveDuel.BackgroundColor3 = BAD; leaveDuel.BackgroundTransparency = 0.1
	task.delay(3, function() leaveDuel.BackgroundColor3 = BLACK; leaveDuel.BackgroundTransparency = 0.35 end)
end)

---------------------------------------------------------------------------------------------------- results
local results = new("Frame", { Name = "Results", Position = UDim2.fromOffset(560, 230), Size = UDim2.fromOffset(800, 600), BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.25, Visible = false, Parent = root }, { corner(14) })
local resTitle = label(results, "VICTORY", STENCIL, 110, 0, 20, 800, 130, GOOD, nil, 4)
local resScore = label(results, "3 - 1", FX, 60, 0, 150, 800, 70, WHITE, nil, 4)
local resMode = label(results, "", FB, 24, 0, 220, 800, 30, Color3.fromRGB(205, 205, 212), nil, 4)
local stats = {}
for i, k in { "Kills", "Deaths", "Headshots" } do
	local x = 80 + (i - 1) * 220
	stats[k] = label(results, "0", FX, 56, x, 280, 200, 66, WHITE, nil, 4)
	label(results, k, FB, 22, x, 344, 200, 28, Color3.fromRGB(205, 205, 212), nil, 4)
end
local resRewards = label(results, "", FX, 32, 0, 392, 800, 44, OLIVE_HI, nil, 4)
-- ranked: the rank line (promotion / demotion / shield / placements / reveal)
local resRank = label(results, "", FX, 30, 0, 436, 800, 40, WHITE, nil, 4)
local leave = new("TextButton", { Name = "Leave", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(275, 490), Size = UDim2.fromOffset(250, 76),
	BackgroundColor3 = WHITE, Parent = results }, { corner(10), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(196, 214, 120), Color3.fromRGB(92, 110, 44)) }) })
label(leave, "Continue", FX, 40, 0, 0, 250, 76, WHITE, nil, 5)
leave.Activated:Connect(function() send("Leave"); results.Visible = false end)
leave.Visible = false -- (RIVALS) the result screen's Rematch / Play Again / Leave buttons replace Continue
local showResultScreenRef -- the RIVALS result screen (defined just below)
local function showResults(sum)
	sum = sum or {}
	-- no summary from the server yet (the MatchEnd fallback): work the result out from the state, never assume a loss
	if sum.Won == nil and sum.Draw == nil then
		local myTeam = player:GetAttribute("Team") or "A"
		local wt = st("WinnerTeam")
		local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
		if wt then sum.Won = wt == myTeam
		elseif sa ~= sb then sum.Won = (myTeam == "A") == (sa > sb)
		else sum.Draw = true end
	end
	resTitle.Text = sum.Draw and "DRAW" or (sum.Won and "VICTORY" or "DEFEAT")
	resTitle.TextColor3 = sum.Draw and WHITE or (sum.Won and GOOD or BAD)
	local myTeam = sum.Team or player:GetAttribute("Team") or "A"
	local sc = sum.Score or { A = st("ScoreA") or 0, B = st("ScoreB") or 0 }
	local mine, theirs = myTeam == "A" and sc.A or sc.B, myTeam == "A" and sc.B or sc.A
	resScore.Text = string.format("%d  -  %d", mine or 0, theirs or 0)
	resMode.Text = (sum.Mode or st("MatchMode") or "") .. (sum.Ranked and "  ·  RANKED" or "")
	stats.Kills.Text = tostring(sum.Kills or player:GetAttribute("MatchKills") or 0)
	stats.Deaths.Text = tostring(sum.Deaths or player:GetAttribute("MatchDeaths") or 0)
	stats.Headshots.Text = tostring(sum.Headshots or 0)
	local bits = {}
	if sum.XP then table.insert(bits, "+" .. sum.XP .. " XP") end
	if sum.Scissors then table.insert(bits, "+" .. sum.Scissors .. " scissors") end
	if sum.RatingChange and sum.delta == nil then table.insert(bits, (sum.RatingChange >= 0 and "+" or "") .. sum.RatingChange .. " ELO") end
	resRewards.Text = table.concat(bits, "   ")
	-- ranked (notes/ranked_server.md §4): placements hide the rank until the 10th; promotions / demotions / shield get a line
	resRank.Text, resRank.TextColor3 = "", WHITE
	if sum.delta ~= nil then
		local d = (sum.delta >= 0 and "+" or "") .. sum.delta .. " ELO"
		if sum.revealed then
			resRank.Text, resRank.TextColor3 = "RANK REVEALED:  " .. tostring(sum.rankAfter) .. "  (" .. tostring(sum.eloAfter) .. " ELO)", OLIVE_HI
		elseif sum.placement then
			resRank.Text = string.format("Placement match %d / %d: your rank shows after the last one", sum.placed or 0, sum.placements or 10)
		elseif sum.shieldUsed then
			resRank.Text, resRank.TextColor3 = "ELO Shield used: no ELO lost", Color3.fromRGB(205, 205, 212)
		elseif sum.promoted then
			resRank.Text, resRank.TextColor3 = "PROMOTED   " .. tostring(sum.rankBefore) .. "  >  " .. tostring(sum.rankAfter) .. "   " .. d, GOOD
		elseif sum.demoted then
			resRank.Text, resRank.TextColor3 = "DEMOTED   " .. tostring(sum.rankBefore) .. "  >  " .. tostring(sum.rankAfter) .. "   " .. d, BAD
		else
			resRank.Text = tostring(sum.rankAfter or "") .. "   " .. d
		end
	end
	if sum.TestMatch or sum.Aborted then resRewards.Text = sum.Aborted and "Match ended early: no rewards" or "Test match: no rewards" end
	-- the victory screen plays first: the results wait for it (they often arrive during Victory)
	task.spawn(function()
		while st("MatchState") == "Victory" or st("MatchPhase") == "Victory" do task.wait(0.1) end
		results.Visible = true
		if showResultScreenRef then showResultScreenRef(sum) end
	end)
end
---------------------------------------------------------------------------------------------------- RIVALS result screen
-- (2026-10-18, Edward, RIVALS refs) after every ranked match: the screen blurs, your rank emblem sits in the middle with the
-- ELO change in a pill under it ("+22" green / "-15" red), "Congratulations! You've promoted to Silver 1" over it on a
-- promotion, and a bar under that: this tier's floor + emblem on the left, the next tier on the right, "Your ELO" counting
-- up in the middle. A full rank change (Bronze -> Silver, not a division) swaps the emblem with a flash.
-- Every match (ranked or not) ends with RIVALS' buttons: Back (bottom left, back to the match summary from the rank page),
-- Rematch (votes n / needed, greyed "Unavailable" when the series is over), Play Again, Leave.
-- Server contract (Tacticals session): MatchResults fields eloBefore / eloAfter / delta / promoted / demoted / rankBefore /
-- rankAfter / placement / placed / placements / revealed; MatchFlow "Rematch" / "PlayAgain" / "Leave"; state attributes
-- RematchVotes / RematchNeeded / RematchAllowed / RematchReason.
local RankedCoreOk, RankedCore = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("RankedCore", 5)) end)
local RankArtOk2, RankArt2 = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("RankArt", 5)) end)
local function rankWord(name) return name and tostring(name):match("^(%a+)") or nil end
local function emblemOf(name) return RankArtOk2 and RankArt2 and RankArt2.EMBLEM[rankWord(name) or ""] or "" end

local rgui = new("ScreenGui", { Name = "MatchResult", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 15, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local rtint = new("Frame", { Name = "Tint", BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = rgui })
local rcanvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = rgui },
	{ new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local rankPage = new("Frame", { Name = "RankPage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = rcanvas })
-- promotion pill
local promo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.282), Size = UDim2.fromScale(0.36, 0.044), BackgroundColor3 = BLACK, Visible = false, Parent = rankPage },
	{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
local promoT = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.92, 0.76), Parent = promo })
-- emblem + delta pill
local emblem = new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.435),
	Size = UDim2.fromScale(0.2, 0.2), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = rankPage })
local emblemScale = new("UIScale", { Parent = emblem })
local glow = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxasset://textures/ui/Glow.png", ImageColor3 = Color3.fromRGB(255, 220, 140), ImageTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.8, 1.8), ZIndex = 0, Parent = emblem })
local deltaPill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.516), Size = UDim2.fromScale(0.105, 0.062), BackgroundColor3 = BLACK, Parent = rankPage },
	{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
local deltaT = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FX, TextScaled = true, TextColor3 = GOOD, Position = UDim2.fromScale(0.1, 0.08), Size = UDim2.fromScale(0.8, 0.84), Parent = deltaPill })
-- the tier bar
local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.65), Size = UDim2.fromScale(0.48, 0.075), BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, Parent = rankPage },
	{ new("UICorner", { CornerRadius = UDim.new(0.12, 0) }) })
local track = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(40, 40, 44), Position = UDim2.fromScale(0.08, 0.68), Size = UDim2.fromScale(0.84, 0.12), Parent = bar },
	{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = OLIVE_HI, Size = UDim2.fromScale(0, 1), Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local leftEmb = new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(1.1, 1.1),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 2, Parent = bar })
local rightEmb = new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.95, 0.5), Size = UDim2.fromScale(1.1, 1.1),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 2, Parent = bar })
local function barText(x, align, top, size)
	return new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FX, TextScaled = true, TextColor3 = WHITE, TextXAlignment = align, Position = UDim2.fromScale(x, top),
		Size = UDim2.fromScale(0.3, size), Parent = bar })
end
local leftFloor = barText(0.1, Enum.TextXAlignment.Left, 0.1, 0.3)
local leftName = barText(0.1, Enum.TextXAlignment.Left, 0.38, 0.3)
local rightFloor = barText(0.6, Enum.TextXAlignment.Right, 0.1, 0.3)
local rightName = barText(0.6, Enum.TextXAlignment.Right, 0.38, 0.3)
local eloCap = new("TextLabel", { BackgroundTransparency = 1, Text = "Your ELO", FontFace = FB, TextScaled = true, TextColor3 = Color3.fromRGB(205, 205, 212), Position = UDim2.fromScale(0.4, 0.04),
	Size = UDim2.fromScale(0.2, 0.22), Parent = bar })
local eloNum = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.4, 0.24), Size = UDim2.fromScale(0.2, 0.44), Parent = bar })

-- buttons (RIVALS: dark gradient, thick white rim)
local function bigButton(name, text, sub, pos)
	local b = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 1), Position = pos, Size = UDim2.fromScale(0.132, 0.078),
		BackgroundColor3 = WHITE, Parent = rcanvas }, { new("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 156, 140), Color3.fromRGB(16, 18, 15)) }),
		new("UIStroke", { Color = Color3.fromRGB(236, 232, 218), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	local t = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.08, sub and 0.1 or 0.18),
		Size = UDim2.fromScale(0.84, sub and 0.52 or 0.64), Parent = b }, { new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }) })
	local st2 = sub and new("TextLabel", { BackgroundTransparency = 1, Text = sub, FontFace = FB, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.2, 0.62),
		Size = UDim2.fromScale(0.6, 0.26), Parent = b }) or nil
	local sc = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.04 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	return b, t, st2
end
local resultBackdrop -- (defined further down; the buttons call it)
local backB = bigButton("Back", "Back", nil, UDim2.fromScale(0.005, 0.99))
local leaveB = bigButton("Leave", "Leave", nil, UDim2.fromScale(0.863, 0.99))
local againB = bigButton("PlayAgain", "Play Again", nil, UDim2.fromScale(0.863, 0.903))
local rematchB, rematchT, rematchSub = bigButton("Rematch", "Rematch", "0/2", UDim2.fromScale(0.863, 0.816))
local rematchVoted = false
local function postMatch() return st("PostMatch") == true or player:GetAttribute("InPseudoLobby") == true end
leaveB.Activated:Connect(function()
	send(postMatch() and "ToHub" or "Leave") -- (the Tacticals session's post-match phase: Leave takes you to the hub)
	rgui.Enabled = false; results.Visible = false
	if resultBackdrop then resultBackdrop(false) end
end)
againB.Activated:Connect(function() send("PlayAgain"); againB:FindFirstChildOfClass("TextLabel").Text = "Searching..." end)
rematchB.Activated:Connect(function()
	if st("RematchAllowed") == false then return end
	send("Rematch") -- toggles your vote on the server (player attribute RematchVote shows it)
end)
-- one look for a Rematch button: votes "n/needed", your own vote lit olive, "Starting in N" once everyone's in,
-- greyed "Unavailable" when the series is over (a side has 2 wins, 3 games played, or someone left)
local function styleRematch(btn, title, sub)
	local allowed = st("RematchAllowed") ~= false and st("RematchNeeded") ~= nil
	local voted = player:GetAttribute("RematchVote") == true
	btn.Active = allowed
	btn.BackgroundTransparency = allowed and 0 or 0.6
	title.TextTransparency = allowed and 0 or 0.6
	sub.TextTransparency = allowed and 0 or 0.6
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = (allowed and voted) and OLIVE_HI or Color3.fromRGB(236, 232, 218) end
	local startsAt = st("RematchStartsAt")
	if not allowed then
		sub.Text = tostring(st("RematchReason") or "Unavailable")
	elseif typeof(startsAt) == "number" and startsAt > workspace:GetServerTimeNow() then
		sub.Text = "Starting in " .. math.ceil(startsAt - workspace:GetServerTimeNow())
	else
		sub.Text = string.format("%d/%d", st("RematchVotes") or 0, st("RematchNeeded") or 2) .. (voted and "  ·  voted" or "")
	end
end
local function refreshRematch() styleRematch(rematchB, rematchT, rematchSub) end

local lastSum
local function showRankPage(sum)
	-- the summary card (VICTORY / DEFEAT, stats) steps back; Back brings it again
	results.Visible = false
	rankPage.Visible = true
	backB.Visible = true
	local before, after = tonumber(sum.eloBefore) or 0, tonumber(sum.eloAfter) or 0
	local d = tonumber(sum.delta) or (after - before)
	deltaT.Text = (d >= 0 and "+" or "") .. d
	deltaT.TextColor3 = d >= 0 and Color3.fromRGB(80, 230, 70) or BAD
	-- placements: no rank yet (a faded Bronze), the count in the pill
	local placing = sum.placement and not sum.revealed
	local infoB = RankedCoreOk and RankedCore.Info(before) or { name = sum.rankBefore, floor = before, nextFloor = before + 100, nextName = "" }
	local infoA = RankedCoreOk and RankedCore.Info(after) or { name = sum.rankAfter, floor = after, nextFloor = after + 100, nextName = "" }
	promo.Visible = false
	if sum.revealed then promoT.Text = "Your rank: " .. tostring(sum.rankAfter or infoA.name); promo.Visible = true
	elseif placing then promoT.Text = string.format("Placement match %d / %d", sum.placed or 0, sum.placements or 10); promo.Visible = true
	elseif sum.promoted then promoT.Text = "Congratulations! You've promoted to " .. tostring(sum.rankAfter or infoA.name); promo.Visible = true
	elseif sum.demoted then promoT.Text = "You've been demoted to " .. tostring(sum.rankAfter or infoA.name); promo.Visible = true
	elseif sum.shieldUsed then promoT.Text = "ELO Shield used: no ELO lost"; promo.Visible = true end
	-- emblem: the old rank's; a full rank change swaps it with a flash after the count
	local oldRank, newRank = rankWord(sum.rankBefore or infoB.name), rankWord(sum.rankAfter or infoA.name)
	emblem.Image = emblemOf(oldRank)
	emblem.ImageTransparency = placing and 0.6 or 0
	emblemScale.Scale = 0.6
	TweenService:Create(emblemScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- the bar starts on the old tier, the number counts to the new ELO
	local function setBar(info, elo)
		leftEmb.Image, rightEmb.Image = emblemOf(info.name), emblemOf(info.nextName)
		leftFloor.Text, leftName.Text = tostring(info.floor or ""), tostring(info.name or "")
		rightFloor.Text, rightName.Text = tostring(info.nextFloor or ""), tostring(info.nextName or "")
		local span = math.max(1, (info.nextFloor or (info.floor + 100)) - info.floor)
		return math.clamp((elo - info.floor) / span, 0, 1)
	end
	bar.Visible = not placing
	fill.Size = UDim2.fromScale(setBar(infoB, before), 1)
	eloNum.Text = tostring(before)
	task.spawn(function()
		task.wait(0.5)
		local t0, dur = os.clock(), 1.1
		while os.clock() - t0 < dur and rankPage.Visible do
			local k = (os.clock() - t0) / dur
			k = 1 - (1 - k) ^ 3
			eloNum.Text = tostring(math.floor(before + (after - before) * k + 0.5))
			task.wait()
		end
		eloNum.Text = tostring(after)
		if infoA.name ~= infoB.name then
			-- crossed a tier: fill out (or empty) the old bar, then the new tier's
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(after > before and 1 or 0, 1) }):Play()
			task.wait(0.3)
			fill.Size = UDim2.fromScale(after > before and 0 or 1, 1)
		end
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(setBar(infoA, after), 1) }):Play()
		if newRank and oldRank and newRank ~= oldRank and not placing then
			-- a whole new rank: the emblem flashes and swaps (RIVALS)
			TweenService:Create(emblemScale, TweenInfo.new(0.18), { Scale = 0.2 }):Play()
			task.wait(0.18)
			emblem.Image = emblemOf(newRank)
			glow.ImageTransparency = 0.1
			TweenService:Create(glow, TweenInfo.new(1.2), { ImageTransparency = 1 }):Play()
			TweenService:Create(emblemScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1.15 }):Play()
			task.wait(0.45)
			TweenService:Create(emblemScale, TweenInfo.new(0.25), { Scale = 1 }):Play()
			local snd = Instance.new("Sound")
			snd.SoundId = "rbxasset://sounds/victory.wav"; snd.Volume = 0.5
			snd.SoundGroup = game:GetService("SoundService"):FindFirstChild("Effects")
			snd.Parent = game:GetService("SoundService"); snd:Play()
			task.delay(3, function() snd:Destroy() end)
		end
	end)
end
backB.Activated:Connect(function()
	if rankPage.Visible then
		rankPage.Visible = false
		results.Visible = true
		backB.Visible = lastSum ~= nil and lastSum.delta ~= nil -- from the summary, Back returns to the rank page
	elseif lastSum and lastSum.delta ~= nil then
		showRankPage(lastSum)
	elseif postMatch() then
		-- back into the pseudo lobby: the results go, the corner panel keeps To Hub / Play Again / Rematch
		rgui.Enabled = false; results.Visible = false
		if resultBackdrop then resultBackdrop(false) end
	end
end)
-- RIVALS blurs the world and drops the gameplay HUD behind the result screen; both come back when it closes
local rblur, rblurOn
local rHidden = {}
function resultBackdrop(on)
	local Lighting = game:GetService("Lighting")
	rblur = rblur or Lighting:FindFirstChild("ResultBlur") or new("BlurEffect", { Name = "ResultBlur", Size = 0, Parent = Lighting })
	if rblurOn ~= on then rblurOn = on; TweenService:Create(rblur, TweenInfo.new(0.3), { Size = on and 22 or 0 }):Play() end
	local pg = player.PlayerGui
	if on then
		for _, n in { "Hotbar", "Vitals", "HUD", "TouchControls", "TouchStick", "MainUI", "TutorialUI", "StealthUI", "RangeKitUI" } do
			local g = pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled and rHidden[g] == nil then rHidden[g] = true; g.Enabled = false end
		end
	else
		for g in rHidden do if g.Parent then g.Enabled = true end end
		rHidden = {}
	end
end
local function showResultScreen(sum)
	lastSum = sum
	resultBackdrop(true)
	rematchVoted = false
	againB:FindFirstChildOfClass("TextLabel").Text = "Play Again"
	rgui.Enabled = true
	refreshRematch()
	if sum.delta ~= nil then showRankPage(sum) else rankPage.Visible = false; backB.Visible = postMatch() end
end

---------------------------------------------------------------------------------------------------- pseudo-lobby panel
-- (2026-10-18, Edward) after the match the server keeps everyone in a lobby copy (PostMatch). Bottom right, always there
-- while you walk around: To Hub, Play Again, Rematch (votes / countdown / Unavailable). Hidden while the result screen is up.
local pgui = new("ScreenGui", { Name = "PostMatchPanel", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 9, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local pcanvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = pgui },
	{ new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local function panelButton(name, text, sub, y)
	local b = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.992, y), Size = UDim2.fromScale(0.118, 0.066),
		BackgroundColor3 = WHITE, Parent = pcanvas }, { new("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 156, 140), Color3.fromRGB(16, 18, 15)) }),
		new("UIStroke", { Color = Color3.fromRGB(236, 232, 218), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	local t = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.08, sub and 0.1 or 0.18),
		Size = UDim2.fromScale(0.84, sub and 0.52 or 0.64), Parent = b }, { new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }) })
	local st2 = sub and new("TextLabel", { BackgroundTransparency = 1, Text = sub, FontFace = FB, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.15, 0.62),
		Size = UDim2.fromScale(0.7, 0.26), Parent = b }) or nil
	local sc = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.04 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	return b, t, st2
end
local hubP = panelButton("ToHub", "To Hub", nil, 0.985)
local againP, againPT = panelButton("PlayAgain", "Play Again", nil, 0.91)
local rematchP, rematchPT, rematchPS = panelButton("Rematch", "Rematch", "0/2", 0.835)
hubP.Activated:Connect(function() send("ToHub") end)
againP.Activated:Connect(function() send("PlayAgain"); againPT.Text = "Searching..." end)
rematchP.Activated:Connect(function() if st("RematchAllowed") ~= false then send("Rematch") end end)
RunService.Heartbeat:Connect(function()
	-- (after-match lobby) a lobby menu / the Kit room hides the play row: the panel goes with it
	local row = player.PlayerGui:FindFirstChild("PlayRowUI")
	local on = postMatch() and not rgui.Enabled and not (row ~= nil and not row.Enabled)
	if on ~= pgui.Enabled then pgui.Enabled = on; if on then againPT.Text = "Play Again" end end
	if on then
		styleRematch(rematchP, rematchPT, rematchPS)
		-- in the after-match lobby the play row's big PLAY AGAIN is the Play Again: the panel keeps Rematch + To Hub
		local lobbyRow = row ~= nil and row.Enabled
		againP.Visible = not lobbyRow
		rematchP.Position = UDim2.fromScale(0.992, lobbyRow and 0.91 or 0.835)
	end
end)
RunService.Heartbeat:Connect(function()
	if rgui.Enabled then
		refreshRematch()
		-- keep the HUD down while it's up (the victory screen restores the HUD after we've hidden it) and no banner over the card
		resultBackdrop(true)
		banner.Visible = false
		rtint.Visible = rankPage.Visible -- the summary card (another ScreenGui, under this one) mustn't be dimmed
		backB.Visible = rankPage.Visible or (lastSum ~= nil and lastSum.delta ~= nil) or postMatch() -- (PostMatch may land after the results)
		-- a rematch (or any new match) is running: the result screen goes
		local ms = st("MatchState")
		local running = ms ~= nil and ms ~= "MatchEnd" and ms ~= "Ended" and ms ~= "Victory" and not postMatch()
		if running or (not inMatch() and not postMatch()) then
			rgui.Enabled = false; results.Visible = false
			resultBackdrop(false)
			return
		end
	end
end)
showResultScreenRef = showResultScreen


local RV = {} -- (2026-10-18) the RIVALS round-end pieces, in a block: this script is at the 200-locals limit
do
---------------------------------------------------------------------------------------------------- round card (RIVALS)
-- (2026-10-18, live RIVALS with Edward) a round's end: a small green "ROUND / WON" or red "ROUND / LOST" card pops in under
-- the timer with a white flash, and stays until the next round goes live.
local roundCard = new("Frame", { Name = "RoundCard", Position = UDim2.fromOffset(818, 116), Size = UDim2.fromOffset(284, 100), BackgroundColor3 = WHITE,
	Visible = false, ZIndex = 6, Parent = root }, { corner(8) })
local roundGrad = new("UIGradient", { Rotation = 90, Parent = roundCard })
local roundSmall = label(roundCard, "ROUND", FB, 26, 0, 4, 284, 30, WHITE, nil, 7)
local roundBig = label(roundCard, "WON", FX, 64, 0, 26, 284, 70, WHITE, nil, 7)
new("UIStroke", { Thickness = 2, Transparency = 0.5, Parent = roundBig })
local roundFlash = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = roundCard }, { corner(8) })
local roundPop = new("UIScale", { Parent = roundCard })
gloss(roundCard, 8, 0.3)
local function showRoundCard(won)
	roundGrad.Color = won and ColorSequence.new(Color3.fromRGB(120, 230, 70), Color3.fromRGB(40, 140, 24)) or ColorSequence.new(Color3.fromRGB(240, 70, 60), Color3.fromRGB(120, 18, 14))
	roundBig.Text = won and "WON" or "LOST"
	roundCard.Visible = true
	roundPop.Scale = 1.35
	TweenService:Create(roundPop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	roundFlash.BackgroundTransparency = 0
	TweenService:Create(roundFlash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, sweep, roundCard, 9)
end

---------------------------------------------------------------------------------------------------- eliminated
local elimL = new("TextLabel", { Name = "Eliminated", BackgroundTransparency = 1, RichText = true, Text = "", FontFace = FB, TextSize = 34, TextColor3 = WHITE,
	Position = UDim2.fromOffset(560, 640), Size = UDim2.fromOffset(800, 46), Visible = false, ZIndex = 6, Parent = root })
elimL:SetAttribute("dTS", 34); table.insert(scaled, elimL)
new("UIStroke", { Thickness = 2, Transparency = 0.4, Parent = elimL })
local elimToken = 0
showEliminated = function(uid)
	elimToken += 1
	local my = elimToken
	elimL.Text = 'Eliminated  <font color="#C8A8FF">' .. nameOf(uid) .. '</font>'
	elimL.TextTransparency = 0
	elimL.Visible = true
	local pop = elimL:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = elimL })
	pop.Scale = 1.4
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.2, function()
		if elimToken ~= my then return end
		TweenService:Create(elimL, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.45, function() if elimToken == my then elimL.Visible = false end end)
	end)
end

---------------------------------------------------------------------------------------------------- killer card (RIVALS)
-- bottom right while your killer is on camera: their headshot with a health bar over it, level badge, win streak flame,
-- name + @username, "eliminated you with <weapon>". In the killer's team colour.
local kcard = new("Frame", { Name = "KillerCard", Position = UDim2.fromOffset(1150, 640), Size = UDim2.fromOffset(740, 140), BackgroundColor3 = WHITE,
	Visible = false, ZIndex = 6, Parent = root }, { corner(10), new("UIGradient", { Rotation = 0, Color = ColorSequence.new(TEAM_B[1], TEAM_B[2]),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) }) }) })
gloss(kcard, 10, 0.2)
local kHead = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(20, 26), Size = UDim2.fromOffset(104, 104), ZIndex = 7, Parent = kcard }, { corner(52) })
local kHpBack = new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, Position = UDim2.fromOffset(32, 12), Size = UDim2.fromOffset(80, 10), ZIndex = 8, Parent = kcard }, { corner(5) })
local kHp = new("Frame", { BackgroundColor3 = GOOD, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = kHpBack }, { corner(5) })
local kLevel = new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 150, 230), Position = UDim2.fromOffset(8, 92), Size = UDim2.fromOffset(44, 44), ZIndex = 9, Parent = kcard }, { corner(22),
	new("UIStroke", { Color = WHITE, Thickness = 2 }) })
local kLevelL = label(kLevel, "1", FX, 24, 0, 0, 44, 44, WHITE, nil, 10)
local kStreak = new("Frame", { BackgroundColor3 = Color3.fromRGB(240, 110, 30), Position = UDim2.fromOffset(98, 96), Size = UDim2.fromOffset(38, 38), Visible = false, ZIndex = 9, Parent = kcard }, { corner(19),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 70, 20)) }), new("UIStroke", { Color = WHITE, Thickness = 2 }) })
local kStreakL = label(kStreak, "3", FX, 22, 0, 0, 38, 38, WHITE, nil, 10)
local kName = label(kcard, "", FX, 46, 150, 10, 560, 52, WHITE, Enum.TextXAlignment.Left, 7)
local kUser = label(kcard, "", FB, 20, 150, 60, 560, 24, Color3.fromRGB(235, 225, 225), Enum.TextXAlignment.Left, 7)
local kHow = label(kcard, "", FB, 28, 158, 88, 560, 34, WHITE, Enum.TextXAlignment.Left, 7)
new("UIStroke", { Thickness = 2, Transparency = 0.5, Parent = kName })
local kFor
local function refreshKillerCard(uid)
	if uid ~= kFor then
		kFor = uid
		kHead.Image = ""
		if uid and uid > 0 then
			task.spawn(function()
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if ok and kFor == uid then kHead.Image = img end
			end)
		end
	end
	local p = uid and uid > 0 and Players:GetPlayerByUserId(uid)
	kName.Text = nameOf(uid)
	kUser.Text = p and ("@" .. p.Name) or ""
	kLevelL.Text = tostring(p and p:GetAttribute("Level") or 1)
	local streak = p and tonumber(p:GetAttribute("WinStreak")) or 0
	kStreak.Visible = streak > 0
	kStreakL.Text = tostring(streak)
	local m = targetModel(uid)
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	local frac = hum and hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
	kHp.Size = UDim2.fromScale(frac, 1)
	kHp.BackgroundColor3 = frac > 0.5 and GOOD or (frac > 0.25 and Color3.fromRGB(235, 190, 60) or BAD)
	local how = "eliminated you"
	if lastDeath and lastDeath.killer == uid then
		local kind = lastDeath.kind == "Melee" and "a melee hit" or (lastDeath.kind == "Explosion" and "an explosion" or (lastDeath.kind == "Burn" and "fire" or nil))
		local w = lastDeath.weapon and tostring(lastDeath.weapon) or kind
		if w then how ..= " with " .. w end
	end
	kHow.Text = how
end

---------------------------------------------------------------------------------------------------- switch weapons (RIVALS)
-- between rounds: a blue "Switch Weapons [M]" button in the middle; it (or M) opens the loadout picker (MatchFlowUI)
local switchB = new("TextButton", { Name = "SwitchWeapons", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(700, 770), Size = UDim2.fromOffset(470, 78),
	BackgroundColor3 = WHITE, Visible = false, ZIndex = 6, Parent = root }, { corner(8),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 180, 255), Color3.fromRGB(20, 110, 230)) }) })
label(switchB, "Switch Weapons", FX, 40, 20, 0, 370, 78, WHITE, nil, 7)
local keyChip = new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 62, 66), Position = UDim2.fromOffset(396, 14), Size = UDim2.fromOffset(52, 50), ZIndex = 7, Parent = switchB }, { corner(6),
	new("UIStroke", { Color = Color3.fromRGB(200, 200, 205), Thickness = 2 }) })
local keyL = label(keyChip, "M", FX, 30, 0, 0, 52, 50, WHITE, nil, 8)
local switchScale = new("UIScale", { Parent = switchB })
gloss(switchB, 8, 0.3)
switchB.MouseEnter:Connect(function() TweenService:Create(switchScale, TweenInfo.new(0.1), { Scale = 1.04 }):Play() end)
switchB.MouseLeave:Connect(function() TweenService:Create(switchScale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
local function switchHook() return player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("SwitchWeapons") end
switchB.Activated:Connect(function() local h = switchHook(); if h then h:Invoke("Toggle") end end)
UserInputService.InputBegan:Connect(function(i, gp)
	if gp or not switchB.Visible then return end
	if i.KeyCode == Enum.KeyCode.M or i.KeyCode == Enum.KeyCode.ButtonY then local h = switchHook(); if h then h:Invoke("Toggle") end end
end)

RV.roundCard, RV.showRoundCard, RV.kcard, RV.refreshKillerCard, RV.switchB, RV.switchHook = roundCard, showRoundCard, kcard, refreshKillerCard, switchB, switchHook
end

toScale(canvas, Vector2.new(W, H))
rescale()

---------------------------------------------------------------------------------------------------- headshots + score
local heads = {}
local function fillBox(box, ids)
	for i = 1, 3 do
		local s = box.slots[i]
		local uid = ids[i]
		s.h.Visible = uid ~= nil
		if uid then
			local p = uid > 0 and Players:GetPlayerByUserId(uid) or nil
			local dead = (uid > 0 and not p) or (p and p:GetAttribute("Alive") == false)
			if uid < 0 then -- a bot: dead once a kill event took it this round (its model can't always be found), or its humanoid is down
				local bm = botModel(uid)
				local bh = bm and bm:FindFirstChildOfClass("Humanoid")
				dead = botDown[uid] == true or (bh ~= nil and bh.Health <= 0)
			end
			s.h.ImageTransparency = dead and 1 or 0
			s.x1.Visible, s.x2.Visible = false, false
			s.skull.Visible = dead
			if uid < 0 then s.h.Image = ""
			elseif heads[uid] then s.h.Image = heads[uid]
			elseif heads[uid] == nil then
				heads[uid] = false
				task.spawn(function()
					local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
					if ok then heads[uid] = im end
				end)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------- wiring
local lastState, lastScoreMine, lastScoreTheirs, resultsShown, lastMatchId
local gotSummary = false -- the server's MatchResults arrived for this match
local function hookEvents()
	local ev = ReplicatedStorage:WaitForChild("MatchFlow", 30)
	if ev then
		ev.OnClientEvent:Connect(function(a, b, c)
			-- lobby: (matchId, kind, data); match place: (nil, kind, data) or (kind, data)
			local kind, data = b, c
			if type(a) == "string" and (a == "Kill" or a == "Arena" or a == "Return") then kind, data = a, b end
			if kind == "Kill" and type(data) == "table" then addKill(data) end
			if kind == "Return" then results.Visible = false; banner.Visible = false end
		end)
	end
	-- (wait for them: the server makes Events.Match.* as it starts, after this client may already be running; a plain
	-- FindFirstChild at join missed MatchResults, so the result screen never got the ranked summary)
	local ev = ReplicatedStorage:WaitForChild("Events", 30)
	local m = ev and ev:WaitForChild("Match", 30)
	if m then
		m:WaitForChild("MatchResults", 30)
		local ann = m:FindFirstChild("MatchAnnounce")
		if ann then ann.OnClientEvent:Connect(function(t, sub)
			-- (RIVALS) a round's end is the small won / lost card only: no big "TEAM A WINS THE ROUND" across the screen
			if tostring(t or ""):upper():find("WINS THE ROUND", 1, true) then return end
			if inMatch() then showBanner(tostring(t or ""), sub and tostring(sub) or "", WHITE, 2.5) end end) end
		local res = m:FindFirstChild("MatchResults")
		-- (the results can land after the post-match phase began, when InMatch is already off)
		if res then res.OnClientEvent:Connect(function(sum) if inMatch() or st("PostMatch") == true or player:GetAttribute("InPseudoLobby") == true then resultsShown = true; gotSummary = true; showResults(sum) end end) end
	end
end
task.spawn(hookEvents)
-- (2026-10-18) RIVALS' notification banners in a match too ("Contract Completed" mid-game): UIKit.Notify
task.spawn(function()
	local uk = ReplicatedStorage:WaitForChild("UIKit", 30)
	local m = uk and uk:WaitForChild("Notify", 30)
	local ok, N = pcall(function() return m and require(m) end)
	if ok and N then N.Hook() end
end)

RunService.RenderStepped:Connect(function()
	local o = stateObject()
	local state = o and o:GetAttribute("MatchState")
	local playing = inMatch() and (state == "RunIn" or state == "Countdown" or state == "Live" or state == "RoundEnd" or state == "Victory" or state == "MatchEnd")
		and not (st("PostMatch") == true or player:GetAttribute("InPseudoLobby") == true) -- the post-match lobby: no match HUD (the results card can still show)
	-- a new match (or none): the old card / banner never carries over
	local _, mid = stateObject()
	if mid ~= lastMatchId then
		lastMatchId = mid
		results.Visible = false; banner.Visible = false; resultsShown = false; lastState = nil
		for _, c in feed:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		tally = {}
	end
	if not inMatch() and not postMatch() then results.Visible = false end -- (the post-match lobby keeps it)
	gui.Enabled = playing or results.Visible
	-- the victory screen owns the screen while it's up (its round banner and the feed drew over VICTORY / DEFEAT)
	local vs = player.PlayerGui:FindFirstChild("VictoryScreen")
	if vs and vs.Enabled and not results.Visible then gui.Enabled = false end
	if not gui.Enabled then
		lastState = nil; resultsShown = false
		return
	end
	leaveDuel.Visible = inLobby() and not spectator() and state ~= "MatchEnd"
	-- score bar
	local myTeam = player:GetAttribute("Team") or "A"
	if spectator() then myTeam = "A" end
	local ids = { A = teamIds("TeamA"), B = teamIds("TeamB") }
	-- Settings > Game: Hide Teammate Display keeps only you in your team's box; Gameplay HUD "Minimal" drops the score
	-- bar and kill feed (banners and the results card stay)
	local myIds = ids[myTeam] or ids.A
	if player:GetAttribute("Setting_HideTeammateDisplay") == true and not spectator() then
		myIds = table.find(myIds, player.UserId) and { player.UserId } or {}
	end
	local minimal = player:GetAttribute("Setting_GameplayHUD") == "Minimal"
	local resUp = rgui ~= nil and rgui.Enabled
	mineBox.frame.Visible, theirBox.frame.Visible, timerBox.Visible, toWin.Visible, feed.Visible = not minimal and not resUp, not minimal and not resUp, not minimal and not resUp, not minimal and not resUp, not minimal and not resUp
	fillBox(mineBox, myIds)
	fillBox(theirBox, myTeam == "A" and ids.B or ids.A)
	local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
	local mine, theirs = myTeam == "A" and sa or sb, myTeam == "A" and sb or sa
	mineBox.score.Text, theirBox.score.Text = tostring(mine), tostring(theirs)
	local left = math.max(0, (st("StateEndsAt") or st("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
	local between = state == "RoundEnd" or state == "Countdown"
	timerBox.Hourglass.Visible = between
	timerL.Text = between and string.format("%.1f", left) or string.format("%d:%02d", left // 60, math.floor(left) % 60)
	timerL.Position = UDim2.fromScale(between and 0.12 or 0, timerL.Position.Y.Scale)
	roundL.Text = "ROUND " .. tostring(st("RoundNumber") or 1)
	toWin.Text = st("RoundsToWin") and ("First to " .. st("RoundsToWin")) or ""
	-- banners
	if state ~= lastState then
		if state == "Countdown" or state == "RunIn" then gotSummary = false end
		if state == "Countdown" then
			-- (RIVALS) the first round gets the big "ROUND 1"; later ones keep the won / lost card up instead
			if not RV.roundCard.Visible then showBanner("ROUND " .. tostring(st("RoundNumber") or 1), "", WHITE) end
		elseif state == "Live" then
			RV.roundCard.Visible = false
			table.clear(botDown)
			if (st("RoundNumber") or 1) <= 1 then showBanner("FIGHT!", "", GOOD, 0.9) end
		elseif state == "RoundEnd" and not spectator() then
			if mine ~= lastScoreMine and mine > (lastScoreMine or 0) then RV.showRoundCard(true)
			elseif theirs ~= lastScoreTheirs and theirs > (lastScoreTheirs or 0) then RV.showRoundCard(false) end
		elseif state ~= "RoundEnd" then
			RV.roundCard.Visible = false
		elseif state == "MatchEnd" and not resultsShown then
			-- the fallback card only when the server's summary never came (it often lands first, during Victory)
			task.delay(1.5, function() if not resultsShown and not gotSummary and inMatch() then resultsShown = true; showResults(nil) end end)
		end
		lastState = state
		lastScoreMine, lastScoreTheirs = mine, theirs
	end
	if state == "Countdown" and banner.Visible then bannerSub.Text = tostring(math.ceil(left)) end
	-- Switch Weapons: between rounds (not the last one), for players in the match
	local over = (st("MatchPhase") == "Victory" or st("MatchPhase") == "Finisher")
	local mf = player.PlayerGui:FindFirstChild("MatchFlow")
	local picking = mf ~= nil and mf.Enabled -- the Switch Weapons picker is up: only the score bar stays (RIVALS)
	RV.switchB.Visible = between and not over and not spectator() and RV.switchHook() ~= nil and not picking
	if picking then RV.roundCard.Visible = false; feed.Visible = false; local el = root:FindFirstChild("Eliminated"); if el then el.Visible = false end end
	-- spectate: spectators, and duelists while dead
	local spec = spectator() or (player:GetAttribute("Alive") == false and (state == "Live" or state == "RoundEnd" or state == "Victory"))
	-- your killer on camera: RIVALS' killer card bottom right instead of the spectate bar
	local killerUid = player:GetAttribute("SpectateTarget")
	local onKiller = spec and not spectator() and killerUid ~= nil and target == killerUid and player:GetAttribute("SpectateReason") == "Killer"
	specBar.Visible = spec and not onKiller
	if onKiller and not RV.kcard.Visible then
		-- slide in from the right edge
		local home = RV.kcardHome or RV.kcard.Position
		RV.kcardHome = home
		RV.kcard.Position = home + UDim2.fromScale(0.25, 0)
		TweenService:Create(RV.kcard, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Position = home }):Play()
	end
	RV.kcard.Visible = onKiller
	if onKiller then RV.refreshKillerCard(killerUid) end
	specStop.Visible = spectator()
	if spec then
		-- your killer first (SpectateTarget), then anyone alive
		local killer = player:GetAttribute("SpectateTarget")
		if killer and killer ~= killcamPicked and not spectator() then
			killcamPicked = killer -- the server moved it (or a new death): follow; Q / E may still move off
			setTarget(killer)
		end
		local m = targetModel(target)
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		local p = target and Players:GetPlayerByUserId(target)
		local alive = hum ~= nil and hum.Health > 0 and (not p or p:GetAttribute("Alive") ~= false)
		if not alive and target ~= killer then cycle(1) end
		refreshSpecCard()
	else
		killcamPicked = nil
	end
end)

---------------------------------------------------------------------------------------------------- victory screen
-- (2026-10-17, Edward: a final-round cutscene) the Tacticals session runs the flow on the state object: MatchPhase
-- "Finisher" (the last kill, a placeholder slow beat) then "Victory"; Winner = "A" / "B". This draws the default screen
-- over whatever camera shot it plays: letterbox bars, a huge VICTORY / DEFEAT (spectators: "TEAM A WINS"), a light sweep
-- across it, the winners' headshots and names, and the final score. The results card follows when the phase ends.
local vgui = new("ScreenGui", { Name = "VictoryScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 13, Enabled = false,
	Parent = player:WaitForChild("PlayerGui") })
local barTop = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BLACK, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.12), Parent = vgui })
local barBot = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BLACK, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.12), Parent = vgui })
local vcanvas = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = vgui },
	{ new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local vTitle = new("TextLabel", { BackgroundTransparency = 1, Text = "VICTORY", FontFace = STENCIL, TextScaled = true, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.8, 0.2), Parent = vcanvas })
local vGrad = new("UIGradient", { Rotation = 90, Parent = vTitle })
new("UIStroke", { Thickness = 3, Transparency = 0.3, Parent = vTitle })
local vScale = new("UIScale", { Parent = vTitle })
-- the light sweep: a soft white band that crosses the title once
local sweepClip = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromScale(0.8, 0.2), Parent = vcanvas })
local sweep = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Rotation = 18, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.5),
	Size = UDim2.fromScale(0.06, 2.2), Parent = sweepClip }, { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }) })
local vScore = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FX, TextScaled = true, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.07), Parent = vcanvas }, { new("UIStroke", { Thickness = 2, Transparency = 0.4 }) })
local vRow = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.57), Size = UDim2.fromScale(0.7, 0.2), Parent = vcanvas },
	{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0) }) })
local vFinisher = new("TextLabel", { BackgroundTransparency = 1, Text = "FINAL KILL", FontFace = STENCIL, TextScaled = true, TextColor3 = Color3.fromRGB(235, 232, 218),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromScale(0.3, 0.06), TextTransparency = 1, Parent = vcanvas },
	{ new("UIStroke", { Thickness = 2, Transparency = 0.5 }) })

local vPhase
-- the gameplay HUD steps aside for the cutscene (put back as it was after)
local HUD_GUIS = { "Hotbar", "Vitals", "HUD", "TouchControls", "TouchStick", "TouchGui", "DuelHUD", "MatchHUD", "TutorialUI", "MainUI",
	"StealthUI", "RangeKitUI", "LobbyHud" }
local hidden = {}
local setCutscene = false
local function hudAside(on)
	local pg = player.PlayerGui
	if on then
		for _, n in HUD_GUIS do
			local g = pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled and hidden[g] == nil then hidden[g] = true; g.Enabled = false end
		end
		if player:GetAttribute("InCutscene") ~= true then setCutscene = true; player:SetAttribute("InCutscene", true) end -- touch + lobby HUD follow it
	else
		for g in hidden do if g.Parent then g.Enabled = true end end
		hidden = {}
		if setCutscene then setCutscene = false; player:SetAttribute("InCutscene", nil) end -- only if we set it
	end
end
local function winnerCard(uid)
	local card = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.16, 1), Parent = vRow })
	local head = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(30, 34, 28), BackgroundTransparency = 0.2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.7, 0.7), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = Color3.fromRGB(233, 196, 106), Thickness = 3 }) })
	if uid and uid > 0 then
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok then head.Image = img end
		end)
	end
	new("TextLabel", { BackgroundTransparency = 1, Text = nameOf(uid), FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.22), Parent = card }, { new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }) })
end
local function showVictory(phase)
	vgui.Enabled = true
	hudAside(true)
	TweenService:Create(barTop, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Position = UDim2.fromScale(0, 0.12) }):Play()
	TweenService:Create(barBot, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Position = UDim2.fromScale(0, 0.88) }):Play()
	local finisher = phase == "Finisher"
	vFinisher.Visible = finisher -- (its outline stayed on screen after the text faded)
	if finisher then
		vTitle.Visible, vScore.Visible, vRow.Visible, sweepClip.Visible = false, false, false, false
		TweenService:Create(vFinisher, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		return
	end
	TweenService:Create(vFinisher, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
	local winner = st("WinnerTeam") or (sa > sb and "A" or (sb > sa and "B" or nil))
	local finalKiller = st("Winner") -- UserId: the final kill on the winning team (else its first member)
	local myTeam = player:GetAttribute("Team")
	local title, top, bottom
	if spectator() or not myTeam then
		title, top, bottom = winner and ("TEAM " .. winner .. " WINS") or "DRAW", Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 180)
	elseif winner == myTeam then
		title, top, bottom = "VICTORY", Color3.fromRGB(255, 230, 150), Color3.fromRGB(214, 160, 40)
	elseif winner then
		title, top, bottom = "DEFEAT", Color3.fromRGB(255, 140, 120), Color3.fromRGB(170, 40, 30)
	else
		title, top, bottom = "DRAW", Color3.fromRGB(235, 235, 235), Color3.fromRGB(150, 150, 150)
	end
	vTitle.Text = title
	vGrad.Color = ColorSequence.new(top, bottom)
	local mine = (myTeam == "B") and sb or sa
	local theirs = (myTeam == "B") and sa or sb
	vScore.Text = ((spectator() or not myTeam) and (sa .. " - " .. sb) or (mine .. " - " .. theirs))
		.. (finalKiller and ("   ·   final kill: " .. nameOf(finalKiller)) or "")
	vScore.Size = UDim2.fromScale(finalKiller and 0.6 or 0.3, 0.07)
	for _, c in vRow:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	if winner then for _, uid in teamIds("Team" .. winner) do winnerCard(uid) end end
	vTitle.Visible, vScore.Visible, vRow.Visible, sweepClip.Visible = true, true, true, true
	-- the stinger: a bass hit on the slam, the victory fanfare for winners (Roblox client sounds, SFX group)
	local SoundService = game:GetService("SoundService")
	for _, spec in { { "bass.wav", 0.7, title == "DEFEAT" and 0.8 or 1 }, title == "VICTORY" and { "victory.wav", 0.5, 1 } or nil } do
		if spec then
			local snd = Instance.new("Sound")
			snd.SoundId = "rbxasset://sounds/" .. spec[1]
			snd.Volume, snd.PlaybackSpeed = spec[2], spec[3]
			snd.SoundGroup = SoundService:FindFirstChild("Effects")
			snd.Parent = SoundService
			snd:Play()
			task.delay(4, function() snd:Destroy() end)
		end
	end
	-- slam in, then the light sweep
	vScale.Scale = 1.6
	vTitle.TextTransparency = 1
	TweenService:Create(vScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(vTitle, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	sweep.Position = UDim2.fromScale(-0.2, 0.5)
	task.delay(0.35, function() TweenService:Create(sweep, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) }):Play() end)
end
local function hideVictory()
	hudAside(false)
	TweenService:Create(barTop, TweenInfo.new(0.3), { Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(barBot, TweenInfo.new(0.3), { Position = UDim2.fromScale(0, 1) }):Play()
	TweenService:Create(vTitle, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	task.delay(0.32, function() if not vPhase then vgui.Enabled = false end end)
end
RunService.Heartbeat:Connect(function()
	local phase = inMatch() and st("MatchPhase") or nil
	if phase ~= "Finisher" and phase ~= "Victory" then phase = nil end
	if phase ~= vPhase then
		vPhase = phase
		if phase then showVictory(phase) else hideVictory() end
	end
end)

-- (RunIn controls: the Tacticals session's RunInClient owns them; nothing here)

---------------------------------------------------------------------------------------------------- scoreboard
-- (2026-10-17, Edward) RIVALS' in-match scoreboard: hold Tab (your Open Scoreboard bind), the touch Scoreboard button
-- toggles it, a controller uses View / Select. Score and round on top, then your team and the enemy team: headshot,
-- name (+ rank emblem in ranked), K, D, HS, and a dimmed row while dead.
local RankArtOk, RankArt = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("RankArt", 5)) end)
local sgui = new("ScreenGui", { Name = "MatchScoreboard", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 14, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local scanvas = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = sgui },
	{ new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local board = new("Frame", { Name = "Board", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.5, 0.6), BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.25, Parent = scanvas }, { new("UICorner", { CornerRadius = UDim.new(0.025, 0) }), new("UIStroke", { Color = WHITE, Transparency = 0.85, Thickness = 1.5 }) })
local sbTitle = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = STENCIL, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.04, 0.025),
	Size = UDim2.fromScale(0.92, 0.08), Parent = board })
local sbSub = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FB, TextScaled = true, TextColor3 = Color3.fromRGB(190, 192, 182), Position = UDim2.fromScale(0.04, 0.105),
	Size = UDim2.fromScale(0.92, 0.04), Parent = board })
local sbList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.17), Size = UDim2.fromScale(0.94, 0.8), Parent = board },
	{ new("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
local sbOpenHold, sbOpenToggle = false, false

local function sbHeader(order, text, color)
	local f = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.07), Parent = sbList })
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color, Size = UDim2.fromScale(0.008, 0.8), Position = UDim2.fromScale(0, 0.1), Parent = f })
	new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = STENCIL, TextScaled = true, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.5, 0.8), Parent = f })
	for i, c in { "K", "D", "HS" } do
		new("TextLabel", { BackgroundTransparency = 1, Text = c, FontFace = FB, TextScaled = true, TextColor3 = Color3.fromRGB(170, 172, 162),
			Position = UDim2.fromScale(0.64 + (i - 1) * 0.12, 0.2), Size = UDim2.fromScale(0.1, 0.6), Parent = f })
	end
end
local function sbRow(order, uid, mine)
	local p = Players:GetPlayerByUserId(uid)
	local t = tally[uid] or { k = 0, d = 0, hs = 0 }
	local kills = (p and p:GetAttribute("MatchKills")) or t.k
	local deaths = (p and p:GetAttribute("MatchDeaths")) or t.d
	local alive
	if p then alive = p:GetAttribute("Alive") ~= false
	else local m = botModel(uid); local h = m and m:FindFirstChildOfClass("Humanoid"); alive = h ~= nil and h.Health > 0 end
	local f = new("Frame", { LayoutOrder = order, Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = WHITE, BackgroundTransparency = uid == player.UserId and 0.86 or 0.94,
		Parent = sbList }, { new("UICorner", { CornerRadius = UDim.new(0.2, 0) }) })
	local head = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(30, 34, 28), Position = UDim2.fromScale(0.012, 0.1), Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, ImageTransparency = alive and 0 or 0.5, Parent = f }, { new("UICorner", { CornerRadius = UDim.new(0.25, 0) }) })
	if uid > 0 then
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			if ok then head.Image = img end
		end)
	end
	local nameX = 0.1
	if RankArtOk and RankArt and p and (st("MatchRanked") == true or ReplicatedStorage:GetAttribute("PlaceKind") == "Ranked") then
		local r = RankArt.Of(p)
		if r.image then
			new("ImageLabel", { BackgroundTransparency = 1, Image = r.image, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.05, 0.8), Parent = f })
			nameX = 0.16
		end
	end
	new("TextLabel", { BackgroundTransparency = 1, Text = nameOf(uid) .. (p and p:GetAttribute("Level") and ("  ·  Lv " .. p:GetAttribute("Level")) or ""), FontFace = FB, TextScaled = true,
		TextColor3 = alive and WHITE or Color3.fromRGB(140, 140, 136), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromScale(nameX, 0.2), Size = UDim2.fromScale(0.62 - nameX, 0.6), Parent = f })
	for i, v in { kills, deaths, t.hs } do
		new("TextLabel", { BackgroundTransparency = 1, Text = tostring(v), FontFace = FX, TextScaled = true, TextColor3 = WHITE,
			Position = UDim2.fromScale(0.64 + (i - 1) * 0.12, 0.18), Size = UDim2.fromScale(0.1, 0.64), Parent = f })
	end
	if not alive then
		new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BAD, BackgroundTransparency = 0.3, Position = UDim2.fromScale(0.012, 0.48), Size = UDim2.fromScale(0.05, 0.06), Rotation = -20, Parent = f })
	end
end
local function renderScoreboard()
	for _, c in sbList:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local myTeam = player:GetAttribute("Team") or "A"
	if spectator() then myTeam = "A" end
	local other = myTeam == "A" and "B" or "A"
	local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
	local mine, theirs = myTeam == "A" and sa or sb, myTeam == "A" and sb or sa
	sbTitle.Text = (spectator() and ("TEAM A  " .. sa .. " - " .. sb .. "  TEAM B")) or (mine .. "  -  " .. theirs)
	sbSub.Text = string.format("Round %d  ·  First to %s  ·  %s", st("RoundNumber") or 1, tostring(st("RoundsToWin") or "?"), tostring(st("MatchMode") or ReplicatedStorage:GetAttribute("MatchMode") or ""))
	local order = 0
	local function team(key, title, color)
		order += 1
		sbHeader(order, title, color)
		local ids = teamIds("Team" .. key)
		table.sort(ids, function(a, b)
			local ta, tb = tally[a] or { k = 0 }, tally[b] or { k = 0 }
			local pa, pb = Players:GetPlayerByUserId(a), Players:GetPlayerByUserId(b)
			return ((pa and pa:GetAttribute("MatchKills")) or ta.k) > ((pb and pb:GetAttribute("MatchKills")) or tb.k)
		end)
		for _, uid in ids do order += 1; sbRow(order, uid, key == myTeam) end
	end
	team(myTeam, spectator() and "TEAM " .. myTeam or "YOUR TEAM", TEAM_A[1])
	team(other, spectator() and "TEAM " .. other or "ENEMY", Color3.fromRGB(255, 140, 120))
end
local function scoreboardWanted() return (sbOpenHold or sbOpenToggle) and gui.Enabled end
local function scoreboardKey()
	local name = player:GetAttribute("Bind_OpenScoreboard")
	local ok, kc = pcall(function() return name and Enum.KeyCode[name] end)
	return (ok and kc) or Enum.KeyCode.Tab
end
UserInputService.InputBegan:Connect(function(i, gp)
	if i.KeyCode == scoreboardKey() and not gp then sbOpenHold = true end
	if i.KeyCode == Enum.KeyCode.ButtonSelect then sbOpenToggle = not sbOpenToggle end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.KeyCode == scoreboardKey() then sbOpenHold = false end
end)
task.spawn(function()
	local ok, IA = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
	if ok and IA then IA.Bind("Scoreboard", function(state) if state == Enum.UserInputState.Begin and inMatch() then sbOpenToggle = not sbOpenToggle end end) end
end)
local sbNext = 0
RunService.Heartbeat:Connect(function()
	local want = scoreboardWanted() and inMatch()
	if not inMatch() then sbOpenToggle = false end
	if want ~= sgui.Enabled then
		sgui.Enabled = want
		if want then renderScoreboard(); sbNext = os.clock() + 0.5 end
	elseif want and os.clock() > sbNext then
		sbNext = os.clock() + 0.5
		renderScoreboard()
	end
end)

-- Studio only: DuelHUDTest:Invoke(state, extra) fakes a match on the current state object
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "DuelHUDTest"
	hook.OnInvoke = function(stateName, extra)
		local o = stateObject() or ReplicatedStorage
		if stateName == "Kill" then addKill(extra) return true end
		if stateName == "Results" then showResults(extra) return true end
		if stateName == "Scoreboard" then sbOpenToggle = extra ~= false return true end
		if stateName == "Finisher" or stateName == "Victory" or stateName == "NoPhase" then
			o:SetAttribute("MatchPhase", stateName ~= "NoPhase" and stateName or nil)
			return true
		end
		o:SetAttribute("LiveMatch", true)
		player:SetAttribute("InMatch", true)
		player:SetAttribute("Team", player:GetAttribute("Team") or "A")
		player:SetAttribute("Alive", true)
		if not o:GetAttribute("TeamA") then o:SetAttribute("TeamA", HttpService:JSONEncode({ player.UserId })) end
		if not o:GetAttribute("TeamB") then o:SetAttribute("TeamB", HttpService:JSONEncode({ 1 })) end
		o:SetAttribute("RoundsToWin", o:GetAttribute("RoundsToWin") or 3)
		if extra and type(extra) == "table" then for k, v in extra do o:SetAttribute(k, v) end end
		o:SetAttribute("StateEndsAt", workspace:GetServerTimeNow() + (stateName == "Countdown" and 3 or 90))
		o:SetAttribute("MatchState", stateName)
		return true
	end
	hook.Parent = player:WaitForChild("PlayerScripts")
end
