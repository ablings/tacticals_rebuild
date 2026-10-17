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
local function inLobby() return ReplicatedStorage:FindFirstChild("LobbyDuels") ~= nil or workspace:FindFirstChild("LobbyMap") ~= nil end
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
		{ corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }) })
	local slots = {}
	for i = 1, 3 do
		local hx = right and (96 + (i - 1) * 64) or (14 + (i - 1) * 64)
		local h = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(hx, 14), Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 3, Parent = b }, { corner(28) })
		local x1 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(28, 28), Size = UDim2.fromOffset(52, 6), BackgroundColor3 = BAD, Visible = false, ZIndex = 4, Parent = h })
		local x2 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -45, Position = UDim2.fromOffset(28, 28), Size = UDim2.fromOffset(52, 6), BackgroundColor3 = BAD, Visible = false, ZIndex = 4, Parent = h })
		slots[i] = { h = h, x1 = x1, x2 = x2 }
	end
	local score = label(b, "0", FX, 54, right and 8 or 222, 6, 70, 72, WHITE, nil, 4)
	return { slots = slots, score = score, frame = b }
end
local mineBox = teamBox(580, TEAM_A, false)
local theirBox = teamBox(1040, TEAM_B, true)
local timerBox = new("Frame", { Position = UDim2.fromOffset(888, 20), Size = UDim2.fromOffset(144, 84), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, Parent = root }, { corner(8) })
local timerL = label(timerBox, "0:00", FX, 40, 0, 4, 144, 50, WHITE)
local roundL = label(timerBox, "ROUND 1", STENCIL, 18, 0, 52, 144, 26, Color3.fromRGB(205, 205, 212))
local toWin = label(root, "", FB, 18, 760, 108, 400, 24, Color3.fromRGB(205, 205, 212))

---------------------------------------------------------------------------------------------------- round banner
local banner = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Position = UDim2.fromOffset(360, 330), Size = UDim2.fromOffset(1200, 260), Visible = false, Parent = root })
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
local lastDeath -- the kill event that killed you (the kill-cam card shows how)
local tally = {} -- uid -> { k, d, hs } from this match's kill events (headshots and bots have no attribute)
local function tallyOf(uid) tally[uid] = tally[uid] or { k = 0, d = 0, hs = 0 }; return tally[uid] end
local function addKill(d)
	feedN += 1
	if d.killer then local t = tallyOf(d.killer); t.k += 1; if d.headshot then t.hs += 1 end end
	if d.victim then tallyOf(d.victim).d += 1 end
	if d.victim == player.UserId then lastDeath = d end
	local myTeam = player:GetAttribute("Team")
	local function col(uid) if uid == player.UserId then return WHITE end; return teamOf(uid) == myTeam and TEAM_A[1] or Color3.fromRGB(255, 140, 120) end
	local row = new("Frame", { LayoutOrder = -feedN, Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Parent = feed }, { new("UICorner", { CornerRadius = UDim.new(0.25, 0) }) })
	local mine = d.killer == player.UserId or d.victim == player.UserId
	if mine then new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row }) end
	local verb = d.kind == "Melee" and "bashed" or (d.kind == "Explosion" and "blew up" or (d.kind == "Burn" and "burned" or ">"))
	local txt = string.format('<font color="#%s">%s</font>  %s%s  <font color="#%s">%s</font>', col(d.killer):ToHex(), nameOf(d.killer),
		verb, d.headshot and "  ◉" or "", col(d.victim):ToHex(), nameOf(d.victim)) -- (◉: BuilderSans has no ✦)
	local l = new("TextLabel", { BackgroundTransparency = 1, RichText = true, Text = txt, FontFace = FB, TextScaled = true, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.94, 0.7), Parent = row })
	new("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = l })
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
local function showResults(sum)
	sum = sum or {}
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
	results.Visible = true
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
			s.h.ImageTransparency = dead and 0.65 or 0
			s.x1.Visible, s.x2.Visible = dead, dead
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
	local m = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Match")
	if m then
		local ann = m:FindFirstChild("MatchAnnounce")
		if ann then ann.OnClientEvent:Connect(function(t, sub) if inMatch() then showBanner(tostring(t or ""), sub and tostring(sub) or "", WHITE, 2.5) end end) end
		local res = m:FindFirstChild("MatchResults")
		if res then res.OnClientEvent:Connect(function(sum) if inMatch() then resultsShown = true; showResults(sum) end end) end
	end
end
task.spawn(hookEvents)

RunService.RenderStepped:Connect(function()
	local o = stateObject()
	local state = o and o:GetAttribute("MatchState")
	local playing = inMatch() and (state == "RunIn" or state == "Countdown" or state == "Live" or state == "RoundEnd" or state == "Victory" or state == "MatchEnd")
	-- a new match (or none): the old card / banner never carries over
	local _, mid = stateObject()
	if mid ~= lastMatchId then
		lastMatchId = mid
		results.Visible = false; banner.Visible = false; resultsShown = false; lastState = nil
		for _, c in feed:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		tally = {}
	end
	if not inMatch() then results.Visible = false end
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
	mineBox.frame.Visible, theirBox.frame.Visible, timerBox.Visible, toWin.Visible, feed.Visible = not minimal, not minimal, not minimal, not minimal, not minimal
	fillBox(mineBox, myIds)
	fillBox(theirBox, myTeam == "A" and ids.B or ids.A)
	local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
	local mine, theirs = myTeam == "A" and sa or sb, myTeam == "A" and sb or sa
	mineBox.score.Text, theirBox.score.Text = tostring(mine), tostring(theirs)
	local left = math.max(0, (st("StateEndsAt") or st("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
	timerL.Text = string.format("%d:%02d", left // 60, math.floor(left) % 60)
	roundL.Text = "ROUND " .. tostring(st("RoundNumber") or 1)
	toWin.Text = st("RoundsToWin") and ("First to " .. st("RoundsToWin")) or ""
	-- banners
	if state ~= lastState then
		if state == "Countdown" then
			showBanner("ROUND " .. tostring(st("RoundNumber") or 1), "", WHITE)
		elseif state == "Live" then
			showBanner("FIGHT!", "", GOOD, 0.9)
		elseif state == "RoundEnd" and not spectator() then
			if mine ~= lastScoreMine and mine > (lastScoreMine or 0) then showBanner("ROUND WON", mine .. " - " .. theirs, GOOD, 2.5)
			elseif theirs ~= lastScoreTheirs and theirs > (lastScoreTheirs or 0) then showBanner("ROUND LOST", mine .. " - " .. theirs, BAD, 2.5) end
		elseif state == "MatchEnd" and not resultsShown then
			task.delay(1.5, function() if not resultsShown and inMatch() then resultsShown = true; showResults(nil) end end)
		end
		lastState = state
		lastScoreMine, lastScoreTheirs = mine, theirs
	end
	if state == "Countdown" and banner.Visible then bannerSub.Text = tostring(math.ceil(left)) end
	-- spectate: spectators, and duelists while dead
	local spec = spectator() or (player:GetAttribute("Alive") == false and (state == "Live" or state == "RoundEnd" or state == "Victory"))
	specBar.Visible = spec
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
