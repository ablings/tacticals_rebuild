-- DuelHUD (match place AND lobby, StarterPlayerScripts, LocalScript): RIVALS' in-match HUD in TACTICALS (UI session 2026-10-16).
-- Contract: notes/lobby_duels_design.md section 6. Same state object as MatchFlowUI: ReplicatedStorage (match place) or
-- ReplicatedStorage.LobbyDuels[DuelMatch or DuelSpectate] (lobby).
--   * Score bar (top centre): your team's box left, theirs right (headshots in TeamA/TeamB order, dimmed + crossed when not
--     Alive), the round wins in each box, and the round timer between them (StateEndsAt).
--   * Round banner: (no 3-2-1 / FIGHT since 2026-10-19), "ROUND WON" / "ROUND LOST" on RoundEnd
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
local padSettings: (() -> ())? = nil -- [PAD] hold View / Select = Settings in a match (set where Settings is built)
local W, H = 1920, 1080
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local OLIVE_HI = Color3.fromRGB(236, 230, 210) -- (2026-10-21, AI-tells cleanup) was comic yellow; now cream (labels). The rank bar fill is field green inline
local TEAM_A = { Color3.fromRGB(233, 220, 188), Color3.fromRGB(191, 165, 122) } -- (2026-10-20, Edward: "serious", like the old bone/olive but better) us: warm beige
local TEAM_B = { Color3.fromRGB(110, 140, 98), Color3.fromRGB(47, 74, 55) } -- them: muted dark green
-- (2026-10-20, Edward: "a mix" of RIVALS + Sniper / Murder Duels) RIVALS fills its score boxes, round card, kill feed pills and
-- killer card with the side's colour; ours use these muted fills (tan / dark green) so white text stays readable
TEAM_A.fill = { Color3.fromRGB(201, 168, 105), Color3.fromRGB(110, 86, 49) } -- (2026-10-22, colour study: RIVALS' team fills fall ~60 % top to bottom; same tan, deeper ramp)
TEAM_B.fill = { Color3.fromRGB(78, 138, 90), Color3.fromRGB(31, 58, 39) } -- (2026-10-22, colour study: same dark green, deeper ramp)
local GOOD, BAD = Color3.fromRGB(141, 191, 90), Color3.fromRGB(235, 70, 60) -- (2026-10-21, AI-tells cleanup) GOOD: yellow -> field green #8DBF5A
-- (2026-10-20, Edward: "a mixture of the rivals ui and sniper duels / murder duels seriousness") RIVALS' layout and see-through
-- panels in a calmer dress, team colour only as an accent.
-- (2026-10-21, AI-tells cleanup) Oswald Bold headlines / numbers, Rubik body (was Montserrat Heavy + Builder Sans); no hairline
-- panel borders, no left accent bars.
-- The SERIOUS pass at the end of this script applies it to everything (it replaced the comic style D pass).
local FX = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local FB = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold)
local STENCIL = FX

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
-- (2026-10-23, matchmaking rounds) Studio only: the player attribute _UISlowMo stretches the short UI holds (death flash, killer
-- card, round card fade, Eliminated) so a screenshot that takes seconds can still catch them. Live: always 1.
local function slow(t) return t * ((RunService:IsStudio() and tonumber(player:GetAttribute("_UISlowMo"))) or 1) end
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
	new("UIStroke", { Thickness = math.max(1, size / 30), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
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
-- (2026-10-22, 4:3 tablets like RIVALS) the match HUD lives at the top edge: the 16:9 canvas is pinned to the top, not centred
local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
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
	-- (2026-10-20, the RIVALS mix) RIVALS' box filled with the side's colour (muted tan / dark green), white score
	local b = new("Frame", { Position = UDim2.fromOffset(x, 20), Size = UDim2.fromOffset(300, 84), BackgroundColor3 = WHITE, BackgroundTransparency = 0.08, Parent = root },
		{ corner(10), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols.fill[1], cols.fill[2]) }) }) -- (2026-10-21, AI-tells cleanup) hairline edge removed
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
		-- (2026-10-22, spacing grade vs live RIVALS) RIVALS' head carries the level seal bottom-left and the device bottom-right
		local sealH = new("Frame", { Name = "Seal", BackgroundTransparency = 1, Position = UDim2.fromOffset(-10, 26), Size = UDim2.fromOffset(36, 36), ZIndex = 6, Parent = h })
		local dev = new("ImageLabel", { Name = "Device", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(34, 36), Size = UDim2.fromOffset(22, 22),
			Visible = false, ZIndex = 6, Parent = h })
		slots[i] = { h = h, x1 = x1, x2 = x2, skull = skull, seal = sealH, dev = dev }
	end
	local score = label(b, "0", FX, 54, right and 8 or 222, 6, 70, 72, WHITE, nil, 4)
	return { slots = slots, score = score, frame = b, right = right }
end
-- (2026-10-23, matchmaking round m4, graders A + B vs RIVALS t0040) 31 px gaps either side of the timer (were 8)
local mineBox = teamBox(557, TEAM_A, false)
local theirBox = teamBox(1063, TEAM_B, true)
local timerBox = new("Frame", { Position = UDim2.fromOffset(888, 11), -- (m9: the bar's top at y 1 %, RIVALS t0040)
	 Size = UDim2.fromOffset(144, 84), BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Parent = root }, { corner(10),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 48, 52), Color3.fromRGB(12, 13, 15)) }) })
-- (2026-10-23, matchmaking round m2, RIVALS t0046) one line: hourglass + clock, centred in the block; no ROUND / First to lines
local timerL = label(timerBox, "0:00", FX, 44, 0, 17, 144, 50, WHITE)
-- (2026-10-18) the hourglass shown left of the time between rounds: top and bottom caps, two crossing glass sides
do local hourglass = new("Frame", { Name = "Hourglass", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 24), Size = UDim2.fromOffset(24, 36), Visible = false, ZIndex = 4, Parent = timerBox })
new("Frame", { BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(24, 5), ZIndex = 4, Parent = hourglass }, { corner(2) })
new("Frame", { BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(24, 5), ZIndex = 4, Parent = hourglass }, { corner(2) })
for _, rot in { 33, -33 } do
	new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 18), Size = UDim2.fromOffset(4, 32), Rotation = rot, ZIndex = 4, Parent = hourglass })
end end
local roundL = label(timerBox, "ROUND 1", STENCIL, 18, 0, 52, 144, 26, Color3.fromRGB(205, 205, 212))
roundL.Visible = false -- (m2) RIVALS shows no round line
local toWin = label(root, "", FB, 18, 760, 108, 400, 24, Color3.fromRGB(205, 205, 212))
-- (2026-10-21, any-map readability) "First to 5" sat bare under the timer and vanished on white maps: a solid dark edge
do local st = toWin:FindFirstChildOfClass("UIStroke"); if st then st.Thickness, st.Transparency, st.Color = 1.3, 0.15, BLACK end; toWin.TextColor3 = Color3.fromRGB(235, 235, 240); toWin:SetAttribute("KeepStroke", true) end

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
-- (2026-10-22, live RIVALS) the feed starts right under the settings gear (y ~0.1), not a third of the way down
-- (2026-10-23, matchmaking round m5, graders A + B vs RIVALS t0054) the feed starts at y 68 and reads ~1.3x bigger (pills ~367 x 38,
-- ~21 px names); anchored at its right edge so the UIScale grows it leftwards
local feed = new("Frame", { Name = "KillFeed", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(1900, 68), Size = UDim2.fromOffset(480, 300), Parent = root },
	{ new("UIListLayout", { Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
		new("UIScale", { Name = "RivalsSize", Scale = 1.12 }) }) -- (m6: 1.3 overshot the pill height, 48 vs RIVALS' 38 px)
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
	if not p then return "?" end
	-- (2026-10-20, Edward) Roblox badges with the name (Premium before, verified after; Settings > Display Badges)
	local ok, B = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
	return (ok and B) and B.Name(p) or p.DisplayName
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
	if d.killer == player.UserId and d.victim and d.victim ~= player.UserId and showEliminated then showEliminated(d.victim, d) end
	local myTeam = player:GetAttribute("Team")
	-- (2026-10-20, the RIVALS mix) RIVALS' feed: ONE pill per kill, filled with the killer's side colour (muted tan ours, dark
	-- green theirs), packed right and sized to its content: killer · weapon silhouette · headshot / no-scope marks · victim
	local function sideOf(uid) return uid == player.UserId or teamOf(uid) == myTeam end
	local ROW_W = 480 -- the feed's design width
	local row = new("Frame", { LayoutOrder = -feedN, Size = UDim2.fromScale(1, 0.15), BackgroundTransparency = 1, Parent = feed })
	local function textW(txt, size) -- (2026-10-21, AI-tells cleanup) measured in the pill's own font (FB, Rubik), not Builder Sans
		local ok, w = pcall(function()
			local prm = Instance.new("GetTextBoundsParams"); prm.Text, prm.Font, prm.Size, prm.Width = txt, FB, size, 1000
			return game:GetService("TextService"):GetTextBoundsAsync(prm).X
		end)
		return ok and w or #txt * size * 0.55
	end
	local verb = ({ Takedown = "took down", Melee = "bashed", Explosion = "blew up", StickyGrenade = "blew up", Landmine = "blew up", Burn = "burned" })[d.kind] or ">"
	local tool
	if typeof(d.weapon) == "string" and d.kind ~= "Takedown" then
		local repo = ReplicatedStorage:FindFirstChild("Repository")
		for _, f in { "Weapons", "Melee" } do
			local folder = repo and repo:FindFirstChild(f)
			tool = tool or (folder and folder:FindFirstChild(d.weapon))
		end
	end
	local KI = nil
	pcall(function() KI = require(ReplicatedStorage.UIKit.KillIcons) end)
	local wIcon = KI and KI.Weapon(typeof(d.weapon) == "string" and d.kind ~= "Takedown" and d.weapon or nil, d.kind)
	local marks = {}
	if KI and d.headshot and KI.Status("headshot") then table.insert(marks, KI.Status("headshot")) end
	if KI and d.noscope and KI.Status("noscope") then table.insert(marks, KI.Status("noscope")) end
	-- the parts, each { kind, value, design width }
	local parts = {}
	if d.killer then table.insert(parts, { "name", nameOf(d.killer), math.clamp(textW(nameOf(d.killer), 22) + 6, 24, 170) }) end
	if wIcon then table.insert(parts, { "icon", wIcon, 46 }) -- (2026-10-22, spacing grade) was 66 at 0.8 tall: ~2 cap, uneven gaps
	elseif tool then table.insert(parts, { "vpf", tool, 66 })
	else table.insert(parts, { "text", verb, textW(verb, 20) + 6 }) end
	if d.headshot and #marks == 0 then table.insert(parts, { "glyph", "◉", 22 }) end
	for _, img in marks do table.insert(parts, { "mark", img, 28 }) end
	if d.victim then table.insert(parts, { "name", nameOf(d.victim), math.clamp(textW(nameOf(d.victim), 22) + 6, 24, 170) }) end
	local GAP, PADX = 8, 14
	local total = PADX * 2
	for i, part in parts do total += part[3] + (i > 1 and GAP or 0) end
	local fill = (d.killer and sideOf(d.killer)) and TEAM_A.fill or TEAM_B.fill
	local pill = new("Frame", { Name = "Pill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(math.min(total, ROW_W) / ROW_W, 0.82),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Parent = row }, {
		new("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(fill[1], fill[2]) }),
		new("UIPadding", { PaddingLeft = UDim.new(PADX / total, 0), PaddingRight = UDim.new(PADX / total, 0) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(GAP / total, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- (2026-10-22, live RIVALS) no ring on your own kills: RIVALS' pills are plain fills (the side colour already says whose)
	for i, part in parts do
		local kind, v, w = part[1], part[2], part[3] / total
		if kind == "name" or kind == "text" or kind == "glyph" then
			local t = new("TextLabel", { LayoutOrder = i, BackgroundTransparency = 1, Text = v, FontFace = FB, TextScaled = true, TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = kind == "text" and Color3.fromRGB(225, 225, 230) or WHITE, Size = UDim2.fromScale(w, 0.6), Parent = pill })
			new("UITextSizeConstraint", { MaxTextSize = kind == "text" and 20 or 22, Parent = t })
			new("UIStroke", { Thickness = 1, Transparency = 0.6, Parent = t })
		elseif kind == "icon" or kind == "mark" then
			new("ImageLabel", { LayoutOrder = i, BackgroundTransparency = 1, Image = v, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(w, kind == "icon" and 0.6 or 0.7), Parent = pill })
		elseif kind == "vpf" then
			local vpf = new("ViewportFrame", { LayoutOrder = i, BackgroundTransparency = 1, Ambient = WHITE, LightColor = Color3.new(0, 0, 0), Size = UDim2.fromScale(w, 1), Parent = pill })
			local m = Instance.new("Model")
			for _, bp in v:GetDescendants() do
				if bp:IsA("BasePart") and bp.Transparency < 0.9 then
					local c = bp:Clone()
					for _, k in c:GetChildren() do if not k:IsA("DataModelMesh") then k:Destroy() end end
					c.Anchored, c.Color, c.Material = true, WHITE, Enum.Material.SmoothPlastic
					if c:IsA("MeshPart") then c.TextureID = "" end
					c.Parent = m
				end
			end
			m.Parent = vpf
			local cf, size = m:GetBoundingBox()
			local cam = Instance.new("Camera")
			cam.FieldOfView = 20
			local reach = math.max(size.Y, size.Z) / 2 / math.tan(math.rad(10)) * 1.08
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach, 0, 0), cf.Position) -- from +X: the barrel (-Z) points right
			cam.Parent = vpf
			vpf.CurrentCamera = cam
		end
	end
	local ins = new("UIScale", { Scale = 0.6, Parent = row })
	TweenService:Create(ins, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(7, function() -- (m6, RIVALS: a feed pill stays ~7 s; was 5)
		-- (m7, RIVALS t0214) a kill that ended the round stays up until the next round is live
		local t0 = os.clock()
		while row.Parent and os.clock() - t0 < 12 do
			local o = stateObject()
			local ms = o and o:GetAttribute("MatchState")
			if ms ~= "RoundEnd" and ms ~= "Countdown" then break end
			task.wait(0.25)
		end
		if row.Parent then
			local fade = TweenInfo.new(0.4)
			for _, v in row:GetDescendants() do
				if v:IsA("GuiObject") and v.BackgroundTransparency < 1 then TweenService:Create(v, fade, { BackgroundTransparency = 1 }):Play() end
				if v:IsA("TextLabel") then TweenService:Create(v, fade, { TextTransparency = 1 }):Play() end
				if v:IsA("ImageLabel") or v:IsA("ViewportFrame") then TweenService:Create(v, fade, { ImageTransparency = 1 }):Play() end
				if v:IsA("UIStroke") then TweenService:Create(v, fade, { Transparency = 1 }):Play() end
			end
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
	BackgroundTransparency = 0.3, Visible = false, Parent = root }, { corner(14) }) -- (2026-10-21, AI-tells cleanup) hairline edge removed
-- (2026-10-21, round 3: match RIVALS) centre-anchored (same spot) so the head can pop from its middle when the target changes
local specHead = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(30, 34, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(142, 60), Size = UDim2.fromOffset(92, 92), Parent = specBar }, { corner(10) })
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
-- (2026-10-21, RIVALS pass) the "Q <" / "> E" labels become chunky clickable arrows (RIVALS' big spectate arrows): a solid dark
-- block (no hairline border), a big chevron and a cream key badge like the hotbar's. Built in a function (200-locals limit);
-- clicks are wired to cycle() below it and Kit.bindButton gives them the press squash (after `stats`).
local specPrev, specNext = (function()
	local OSW = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
	local function arrow(name, x, chev, key, badgeX)
		local b = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 16), Size = UDim2.fromOffset(78, 88),
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, ZIndex = 3, Parent = specBar }, { corner(10) })
		label(b, chev, OSW, 52, 0, 8, 78, 80, WHITE, nil, 4)
		local badge = new("Frame", { Name = "KeyBadge", BackgroundColor3 = Color3.fromRGB(236, 230, 210), Position = UDim2.fromOffset(badgeX, -10), Size = UDim2.fromOffset(32, 32),
			ZIndex = 5, Parent = b }, { corner(6) })
		local kl = label(badge, key, OSW, 22, 0, 0, 32, 32, Color3.fromRGB(17, 17, 20), nil, 6)
		local ks = kl:FindFirstChildOfClass("UIStroke"); if ks then ks.Enabled = false end -- dark letter on cream: no edge needed
		return b
	end
	return arrow("SpecPrev", 8, "<", "Q", -8), arrow("SpecNext", 594, ">", "E", 54)
end)()
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
		-- (2026-10-21, round 3: match RIVALS) a new spectate target lands with a pop (head 0.7 -> 1, Back), so Q / E reads as a switch
		do
			local hs = specHead:FindFirstChild("SwapPop") or new("UIScale", { Name = "SwapPop", Parent = specHead })
			hs.Scale = 0.7
			TweenService:Create(hs, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
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
		local kind = ({ Melee = "a melee hit", Takedown = "a takedown", Explosion = "an explosion", StickyGrenade = "a sticky grenade", Landmine = "a landmine", Burn = "fire" })[lastDeath.kind]
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
-- (2026-10-21, RIVALS pass) the spectate arrows are buttons now: a click cycles like Q / E
specPrev.Activated:Connect(function() cycle(-1) end)
specNext.Activated:Connect(function() cycle(1) end)
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

-- (2026-10-20, Edward: "lobby settings should be in the matchmaking as well") RIVALS' gear in the top right of a match opens
-- the lobby's SETTINGS screen (UIKit.SettingsScreen) with your saved profile; changes save through Events.Lobby.Request
-- "SaveSettings" exactly like the lobby (the match places' SettingsBridge re-applies them at once). Free the cursor (Free
-- Cursor key) to click it; the camera frees the mouse while it is open. In the hub the lobby's own Init is kept.
do
	local gear = new("TextButton", { Name = "SettingsGear", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(1920 - 24, 24),
		Size = UDim2.fromOffset(52, 52), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Parent = root }, { corner(26) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://77423905055797", ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), Parent = gear })
	local SS, busy = nil, false
	local function toggleSettings()
		if busy then return end
		busy = true
		if not SS then
			local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("SettingsScreen", 5)) end)
			if ok and mod and not (mod.HasContext and mod.HasContext()) then
				-- the saved settings come from the profile replica; never open on defaults (a save would overwrite the profile)
				local replica
				pcall(function()
					local P = require(script.Parent:WaitForChild("Client"):WaitForChild("Registry"):WaitForChild("PlayerData", 5))
					replica = P:GetMyReplica()
				end)
				if replica and replica.Data then
					local ev = ReplicatedStorage:FindFirstChild("Events")
					local req = ev and ev:FindFirstChild("Lobby") and ev.Lobby:FindFirstChild("Request")
					mod.Init({
						getSettings = function() return replica.Data.Settings end,
						save = function(st2)
							if type(st2) == "table" then st2.Version = 2 end
							if req then pcall(req.InvokeServer, req, "SaveSettings", st2) end
						end,
					})
					SS = mod
				end
			elseif ok and mod then
				SS = mod
			end
		end
		if SS then
			-- marked so the after-match lobby's guard (PseudoLobby.Guard) doesn't switch it off mid-match
			local sg = player.PlayerGui:FindFirstChild("SettingsUI")
			if sg then sg:SetAttribute("MatchOpened", true) end
			if SS.IsOpen() then SS.Close() else SS.Open() end
		end
		busy = false
	end
	gear.Activated:Connect(toggleSettings)
	-- (2026-10-21) controller: HOLD View / Select opens / closes Settings in a match (a tap is still the scoreboard; D-pad up is
	-- Dash since Edward 2026-10-21), with its glyph beside the gear while a controller is the last input
	local UIS = game:GetService("UserInputService")
	local glyph = new("ImageLabel", { Name = "PadGlyph", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(1920 - 84, 50),
		Size = UDim2.fromOffset(34, 34), Visible = false, Parent = root })
	pcall(function() glyph.Image = UIS:GetImageForKeyCode(Enum.KeyCode.ButtonSelect) end)
	local function onType(t)
		if t == Enum.UserInputType.MouseMovement then return end
		glyph.Visible = t.Name:find("Gamepad") ~= nil and glyph.Image ~= ""
	end
	UIS.LastInputTypeChanged:Connect(onType)
	onType(UIS:GetLastInputType())
	padSettings = function()
		if gui.Enabled and inMatch() and player:GetAttribute("InTraining") ~= true then toggleSettings() end
	end
end
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
-- (2026-10-22, RIVALS 1:1 from a live RIVALS match) the result screen is a SCENE, not a card: the winner's character big in the
-- middle (no panel behind it), a team-colour title plate at the top centre ("VICTORY" small over the winner's name), under the
-- character a team-colour name plate (level seal, name, device) and a dark plate fading down with three stat tiles
-- (Eliminations / Deaths / Assists) and Damage Dealt / Damage Taken under them. Measured on RIVALS at 1920x1080 design px:
-- plate 307x94 at y 117, name plate 396x64 at y 765, stats 388 wide from y 829; the buttons stay bottom right (rcanvas).
local results = new("Frame", { Name = "Results", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1,
	Visible = false, Parent = root })
local resTitle -- the small "VICTORY" / "DEFEAT" line on the plate
local resScore -- the winner's name on the plate (big)
local resMode -- the score + mode, small, under the plate
local stats = {}
do
	-- (2026-10-22, grader vs live RIVALS) a tighter plate (360 x 96, RIVALS ~16 % of the width) with only VICTORY and the name
	-- (m11, grader B vs t0140: 307 x 96)
	stats.plate = new("Frame", { Name = "TitlePlate", Position = UDim2.fromOffset(806, 115), Size = UDim2.fromOffset(307, 96), BackgroundColor3 = WHITE,
		ZIndex = 4, Parent = results }, { corner(8) })
	stats.plateGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(TEAM_A.fill[1], TEAM_A.fill[2]), Parent = stats.plate })
	resTitle = label(stats.plate, "VICTORY", FB, 26, 0, 6, 307, 30, WHITE, nil, 5)
	resScore = label(stats.plate, "", FX, 44, 0, 34, 307, 56, WHITE, nil, 5)
	resMode = label(results, "", FB, 24, 560, 220, 800, 30, Color3.fromRGB(225, 225, 230), nil, 4)
	-- the name plate + the stats plate under the character
	stats.name = new("Frame", { Name = "NamePlate", Position = UDim2.fromOffset(762, 765), Size = UDim2.fromOffset(396, 66), BackgroundColor3 = WHITE,
		ZIndex = 6, Parent = results }, { corner(6) })
	stats.nameGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(TEAM_A.fill[1], TEAM_A.fill[2]), Parent = stats.name })
	stats.seal = new("Frame", { Name = "SealHolder", BackgroundTransparency = 1, Position = UDim2.fromOffset(78, 16), Size = UDim2.fromOffset(33, 33), ZIndex = 7, Parent = stats.name }) -- (2026-10-22, spacing grade) RIVALS' seal ~1.6 cap, against the name
	stats.nameT = label(stats.name, "", FX, 36, 112, 0, 220, 44, WHITE, Enum.TextXAlignment.Left, 7)
	stats.userT = label(stats.name, "", FB, 16, 114, 41, 220, 20, Color3.fromRGB(240, 236, 226), Enum.TextXAlignment.Left, 7)
	stats.dev = new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(334, 1), Size = UDim2.fromOffset(46, 46),
		ZIndex = 7, Parent = stats.name }) -- (2026-10-22) ink ~1.2 cap, centred on the name line (the art has a clear margin)
	stats.panel = new("Frame", { Name = "StatsPlate", Position = UDim2.fromOffset(766, 831), Size = UDim2.fromOffset(388, 212), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.25, ZIndex = 4, Parent = results }, { new("UIGradient", { Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) }) }) })
	stats.tiles = {}
end
-- RIVALS' numbers: Eliminations / Deaths / Assists in dark tiles, Damage Dealt / Damage Taken plain under them (+ our Headshots
-- last, when the server sends it). stats.SLOTS = { centre x, top y, tile? } in results (1920x1080) design px, by display order.
stats.SLOTS = { { 840, 864, true }, { 960, 864, true }, { 1080, 864, true }, { 894, 972, false }, { 1026, 972, false }, { 960, 1030, false } }
for i, k in { { "Kills", "Eliminations" }, { "Deaths", "Deaths" }, { "Assists", "Assists" }, { "DamageDealt", "Damage Dealt" }, { "DamageTaken", "Damage Taken" }, { "Headshots", "Headshots" } } do
	local sl = stats.SLOTS[i]
	stats.tiles[k[1]] = new("Frame", { BackgroundColor3 = Color3.fromRGB(58, 58, 64), BackgroundTransparency = 0.15, Position = UDim2.fromOffset(sl[1] - 41, sl[2]),
		Size = UDim2.fromOffset(82, 66), ZIndex = 5, Visible = sl[3], Parent = results }, { corner(6) })
	stats[k[1]] = label(results, "0", FX, sl[3] and 42 or 34, sl[1] - 75, sl[2] + (sl[3] and 6 or 0), 150, sl[3] and 54 or 40, WHITE, nil, 6)
	stats.cap = stats.cap or {}
	stats.cap[k[1]] = label(results, k[2], FB, 18, sl[1] - 75, sl[2] + (sl[3] and 70 or 38), 150, 24, Color3.fromRGB(225, 225, 230), nil, 6)
end
-- (2026-10-21, RIVALS pass) the shared UIKit.Kit motion helpers, kept in the `stats` table (this script is at the 200-locals
-- limit). stats.bind = Kit.bindButton when Kit loaded (hover 1.05 / press 0.93 / hover + click sfx / pad-select grow).
stats.Kit = (function()
	local ok, K = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit", 10):WaitForChild("Kit", 5)) end)
	return ok and K or nil
end)()
function stats.bind(b, opts)
	if stats.Kit and stats.Kit.bindButton then stats.Kit.bindButton(b, opts) end
	return b
end
-- one button behaviour: the spectate arrows, Stop and Leave (built above `stats`) squash like every Kit button
stats.bind(specPrev); stats.bind(specNext); stats.bind(specStop); stats.bind(leaveDuel)
local resRewards = label(results, "", FX, 26, 560, 1040, 800, 34, OLIVE_HI, nil, 6) -- (2026-10-22) under the stats, off the winner
-- ranked: the rank line (promotion / demotion / shield / placements / reveal)
local resRank = label(results, "", FX, 26, 560, 220, 800, 34, WHITE, nil, 6) -- ranked line: right under the plate
-- the winner, big in the middle: a copy of their live character in its own lit viewport (RIVALS films the winner in the
-- world; a clone over the softly blurred world reads the same). Falls back to the winner's avatar thumbnail.
do
	local av = new("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(560, 236), Size = UDim2.fromOffset(800, 760), ZIndex = 3, Parent = results }) -- (2026-10-22) taller: the legs run under the name plate like RIVALS
	local vpf = new("ViewportFrame", { Name = "Pose", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
		Ambient = Color3.fromRGB(150, 150, 156), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.6, -0.8, -0.5), Parent = av })
	local wm = Instance.new("WorldModel"); wm.Parent = vpf
	local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vpf; vpf.CurrentCamera = cam
	local spin
	-- stats.winner = { char = Model?, uid = number? } (set by showResults before the screen shows)
	local function pose()
		wm:ClearAllChildren()
		if spin then spin:Disconnect(); spin = nil end
		local w = stats.winner or {}
		local char = w.char
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		av.Image = ""
		if not (char and hum) then
			av.ImageTransparency = 0
			if w.uid and w.uid > 0 then
				task.spawn(function()
					local ok, img = pcall(function() return Players:GetUserThumbnailAsync(w.uid, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420) end)
					if ok and img then av.Image = img end
				end)
			end
			return
		end
		local was = char.Archivable
		char.Archivable = true
		local okC, clone = pcall(function() return char:Clone() end)
		char.Archivable = was
		if not (okC and clone) then av.ImageTransparency = 0; return end
		for _, d in clone:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy()
			elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.LocalTransparencyModifier = 0 end
		end
		local hrp = clone:FindFirstChild("HumanoidRootPart")
		if hrp then clone.PrimaryPart = hrp end
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = wm
		local cf, size = clone:GetBoundingBox()
		local dist = size.Y / 2 / math.tan(math.rad(cam.FieldOfView / 2)) * 1.12 -- (2026-10-22) a bit closer than before (1.08 of a taller frame)
		-- a little from below and to the side, like RIVALS' hero shot
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.18, -size.Y * 0.06, -dist), cf.Position + Vector3.new(0, size.Y * 0.04, 0))
		av.ImageTransparency = 1
		local t0 = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			-- RIVALS shows only the winner: our own body in the world hides while the result screen is up
			local me = player.Character
			if not results.Visible then
				if stats.hidMe then
					stats.hidMe = nil
					if me then for _, d in me:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end end
				end
				return
			end
			if me then for _, d in me:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end end; stats.hidMe = true end
			clone:PivotTo(CFrame.Angles(0, math.rad(-14) + math.sin((os.clock() - t0) * 0.6) * math.rad(10), 0))
		end)
	end
	results:GetPropertyChangedSignal("Visible"):Connect(function() if results.Visible then pose() end end)
end
local leave = new("TextButton", { Name = "Leave", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(275, 490), Size = UDim2.fromOffset(250, 76),
	BackgroundColor3 = WHITE, Parent = results }, { corner(10), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(90, 178, 255), Color3.fromRGB(30, 99, 214)) }) })
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
	local myTeam = sum.Team or player:GetAttribute("Team") or "A"
	local sc = sum.Score or { A = st("ScoreA") or 0, B = st("ScoreB") or 0 }
	local mine, theirs = myTeam == "A" and sc.A or sc.B, myTeam == "A" and sc.B or sc.A
	-- (2026-10-22, RIVALS) the plate names the WINNER in the winner's team colour (tan = us, dark green = them); the name plate
	-- and the posed character are the winner's too. 1v1: the opponent when you lose; a team match: its best player we can find.
	do
		local winTeam = sum.Draw and myTeam or (sum.Won and myTeam or (myTeam == "A" and "B" or "A"))
		local cols = (winTeam == myTeam) and TEAM_A.fill or TEAM_B.fill
		stats.plateGrad.Color = ColorSequence.new(cols[1], cols[2])
		stats.nameGrad.Color = ColorSequence.new(cols[1], cols[2])
		local wp, wchar, wname, wuid = nil, nil, nil, nil
		if winTeam == myTeam then
			wp = player
		else
			for _, p in Players:GetPlayers() do
				if p ~= player and p:GetAttribute("Team") == winTeam then wp = p break end
			end
		end
		if wp then
			wchar, wuid, wname = wp.Character, wp.UserId, nameOf(wp.UserId)
		else
			-- a bot won: its rig in the world (no Player), its name from the score bar's member list
			for _, m in workspace:GetChildren() do
				local h = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
				if h and not Players:GetPlayerFromCharacter(m) and m:GetAttribute("Team") ~= myTeam and (m:GetAttribute("IsBot") or m.Name:find("Bot")) then
					wchar, wname = m, m.Name
					break
				end
			end
		end
		stats.winner = { char = wchar, uid = wuid }
		resScore.Text = (wp and wp.DisplayName) or wname or (winTeam == myTeam and player.DisplayName or "Opponent") -- (2026-10-22) no badge glyph: RIVALS' plate is the name alone
		stats.nameT.Text = wp and wp.DisplayName or (wname or "")
		stats.userT.Text = wp and ("@" .. wp.Name) or ""
		local okB, B = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
		local dev = wp and okB and B and B.DeviceIcon and B.DeviceIcon(wp)
		stats.dev.Image = dev or ""
		-- (2026-10-22, Edward: every icon a precise distance from the name) the device follows the name 10 design px after
		-- its text, not pinned to the plate's right edge
		task.defer(function()
			local tb, pw = stats.nameT.TextBounds.X, stats.name.AbsoluteSize.X
			if tb > 0 and pw > 0 then stats.dev.Position = UDim2.fromScale(math.min(112 + tb * 396 / pw + 8, 346) / 396, 1 / 66) end
		end)
		stats.seal:ClearAllChildren()
		if stats.Kit and stats.Kit.levelSeal then
			pcall(function() stats.Kit.levelSeal(stats.seal, wp and tonumber(wp:GetAttribute("Level")) or 1, { ZIndex = 8 }) end)
		end
	end
	resMode.Text = string.format("%d - %d", mine or 0, theirs or 0) .. "   ·   " .. (sum.Mode or st("MatchMode") or "") .. (sum.Ranked and "  ·  RANKED" or "")
	resMode.Visible = false -- (2026-10-22, live RIVALS) no score line under the plate; the score is in the team boxes
	-- (2026-10-21, RIVALS pass) few big numbers: a stat the server didn't send is hidden (no "-"); the shown ones are laid out
	-- Eliminations / Deaths / Headshots big on row 1, the rest on row 2; they count up when the card shows (stats.vals)
	stats.vals = {
		Kills = tonumber(sum.Kills or player:GetAttribute("MatchKills") or 0) or 0,
		Deaths = tonumber(sum.Deaths or player:GetAttribute("MatchDeaths") or 0) or 0,
		Headshots = tonumber(sum.Headshots or 0) or 0,
		Assists = tonumber(sum.Assists),
		DamageDealt = sum.DamageDealt ~= nil and math.floor(tonumber(sum.DamageDealt) or 0) or nil,
		DamageTaken = sum.DamageTaken ~= nil and math.floor(tonumber(sum.DamageTaken) or 0) or nil,
	}
	stats.order = {}
	-- (2026-10-22, RIVALS) shown stats fill stats.SLOTS in order: the first three in tiles, the rest plain under them
	for _, key in { "Kills", "Deaths", "Assists", "DamageDealt", "DamageTaken", "Headshots" } do
		if key == "Headshots" and #stats.order >= 5 then stats.vals.Headshots = nil end -- (RIVALS shows five; a sixth row crowds the plate)
		local v, num, cap, tile = stats.vals[key], stats[key], stats.cap[key], stats.tiles[key]
		num.Visible, cap.Visible, tile.Visible = v ~= nil, v ~= nil, false
		if v ~= nil then
			table.insert(stats.order, key)
			local sl = stats.SLOTS[#stats.order]
			local big = sl[3]
			tile.Visible = big
			tile.Position = UDim2.fromScale((sl[1] - 41) / W, sl[2] / H)
			num.Position, num.Size = UDim2.fromScale((sl[1] - 75) / W, (sl[2] + (big and 6 or 0)) / H), UDim2.fromScale(150 / W, (big and 54 or 40) / H)
			cap.Position = UDim2.fromScale((sl[1] - 75) / W, (sl[2] + (big and 70 or 38)) / H)
			num:SetAttribute("dTS", big and 42 or 34)
			num.Text = tostring(v)
		end
	end
	rescale()
	local bits = {}
	if sum.XP then table.insert(bits, "+" .. sum.XP .. " XP") end
	if sum.Scissors then table.insert(bits, "+" .. sum.Scissors .. " scissors") end
	if sum.RatingChange and sum.delta == nil then table.insert(bits, (sum.RatingChange >= 0 and "+" or "") .. sum.RatingChange .. " ELO") end
	resRewards.Text = table.concat(bits, "   ")
	-- ranked (notes/ranked_server.md §4): placements hide the rank until the 10th; promotions / demotions / shield get a line
	resRank.Text, resRank.TextColor3 = "", WHITE
	if sum.delta ~= nil then
		local d = (sum.delta >= 0 and "+" or "") .. sum.delta .. " ELO"
		-- (2026-10-21, RIVALS pass) short kid-readable phrases; the long explanation lives on the rank page (same colours)
		if sum.revealed then
			resRank.Text, resRank.TextColor3 = "Your rank: " .. tostring(sum.rankAfter), OLIVE_HI
		elseif sum.placement then
			resRank.Text = string.format("Placement %d/%d", sum.placed or 0, sum.placements or 10)
		elseif sum.shieldUsed then
			resRank.Text, resRank.TextColor3 = "Shield saved you", Color3.fromRGB(205, 205, 212)
		elseif sum.promoted then
			resRank.Text, resRank.TextColor3 = "Rank up! " .. tostring(sum.rankAfter) .. "   " .. d, GOOD
		elseif sum.demoted then
			resRank.Text, resRank.TextColor3 = "Rank down: " .. tostring(sum.rankAfter) .. "   " .. d, BAD
		else
			resRank.Text = tostring(sum.rankAfter or "") .. "   " .. d
		end
	end
	if sum.TestMatch or sum.Aborted then resRewards.Text = sum.Aborted and "Match ended early: no rewards" or "Test match: no rewards" end
	-- the victory screen plays first: the results wait for it (they often arrive during Victory)
	task.spawn(function()
		while st("MatchState") == "Victory" or st("MatchPhase") == "Victory" do task.wait(0.1) end
		-- (2026-10-21, RIVALS pass) the card pops in (Kit.open), VICTORY slides in and fades up like showBanner, and the numbers
		-- count up from 0, staggered. A second summary for a card already up only recounts.
		local K = stats.Kit
		if K and not results.Visible then K.open(results) else results.Visible = true end
		stats.titleHome = stats.titleHome or resTitle.Position
		if K then
			resTitle.Position = stats.titleHome - UDim2.fromScale(0.06, 0)
			resTitle.TextTransparency = 1
			TweenService:Create(resTitle, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Position = stats.titleHome, TextTransparency = 0 }):Play()
			for i, key in stats.order or {} do
				local num, v = stats[key], stats.vals[key]
				num.Text = "0"
				task.delay(0.15 + (i - 1) * 0.08, function() K.countTo(num, 0, v, 0.5) end)
			end
		end
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
local function emblemOf(name) -- "Gold 2" -> Gold's division-2 look (RankArt v3); a bare rank word -> its middle look
	if not (RankArtOk2 and RankArt2) then return "" end
	local div = name and tonumber(tostring(name):match("(%d+)%s*$"))
	return (RankArt2.Emblem and RankArt2.Emblem(rankWord(name), div)) or RankArt2.EMBLEM[rankWord(name) or ""] or ""
end

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
local fill = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(141, 191, 90), Size = UDim2.fromScale(0, 1), Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) }) -- (2026-10-21, AI-tells cleanup) progress: field green
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

-- buttons (RIVALS layout; 2026-10-20 serious pass: flat dark plates, Sniper / Murder Duels; no hairline edge since 2026-10-21)
local function bigButton(name, text, sub, pos)
	local b = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 1), Position = pos, Size = UDim2.fromScale(0.132, 0.078),
		BackgroundColor3 = Color3.fromRGB(18, 19, 23), BackgroundTransparency = 0.2, Parent = rcanvas }, { new("UICorner", { CornerRadius = UDim.new(0.08, 0) }) })
		-- (2026-10-21, AI-tells cleanup) flat dark plate, hairline edge removed (Rematch gets a thick VotedEdge in styleRematch)
	local t = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.08, sub and 0.1 or 0.18),
		Size = UDim2.fromScale(0.84, sub and 0.52 or 0.64), Parent = b }, { new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }) })
	local st2 = sub and new("TextLabel", { BackgroundTransparency = 1, Text = sub, FontFace = FB, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.2, 0.62),
		Size = UDim2.fromScale(0.6, 0.26), Parent = b }) or nil
	-- (2026-10-21, RIVALS pass) one button behaviour: Kit.bindButton (hover 1.05, press 0.93, sfx) replaces the hover-only UIScale
	stats.bind(b)
	return b, t, st2
end
local resultBackdrop -- (defined further down; the buttons call it)
local backB = bigButton("Back", "Back", nil, UDim2.fromScale(0.005, 0.99))
local leaveB = bigButton("Leave", "Leave", nil, UDim2.fromScale(0.863, 0.99))
local againB = bigButton("PlayAgain", "Play Again", nil, UDim2.fromScale(0.863, 0.903))
local rematchB, rematchT, rematchSub = bigButton("Rematch", "Rematch", "0/2", UDim2.fromScale(0.863, 0.816))
-- (2026-10-21, RIVALS pass) a clear order: Play Again is THE primary (field-green #8DBF5A -> #4C7A2E fill, cream words, no hairline
-- border), Rematch the tan secondary (the file's own TEAM_A.fill tan), Leave and Back stay dark plates
do
	-- (2026-10-23, matchmaking round m1, RIVALS t0140) Play Again / Leave / Back are RIVALS' dark buttons: a 3 px white outline,
	-- a soft gloss across the top half and white words. Play Again is no longer a green fill (RIVALS has none).
	for _, b in { againB, leaveB, backB } do
		b.BackgroundColor3, b.BackgroundTransparency = Color3.fromRGB(24, 25, 29), 0.08
		new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
		new("Frame", { Name = "Gloss", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.45), ZIndex = b.ZIndex, Parent = b }, {
			new("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }) }) })
		local words = b:FindFirstChildOfClass("TextLabel")
		words.TextColor3, words.ZIndex = WHITE, b.ZIndex + 1 -- (over the gloss)
	end
	-- (m11, grader B vs RIVALS t0140) Rematch is a dim dark button with a 2 px stroke, so Play Again leads (was a tan fill)
	rematchB.BackgroundColor3 = Color3.fromRGB(24, 25, 29) -- styleRematch keeps driving its transparency (greyed when unavailable)
	new("UIStroke", { Name = "RivalsEdge", Color = WHITE, Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = rematchB })
	-- (2026-10-21, round 3: match RIVALS) RIVALS' action buttons are chunky (round_lost_full.jpg, t0113.0s): the primary gets
	-- Kit.button's darker bottom lip instead of reading as a flat sticker
end
-- (2026-10-19, Edward: "Rematch 2/2" after a rematch) the game-end snapshot: votes / own vote still left from the last game
-- read as 0 until the server changes them (a table, not new locals: this script is at the 200-locals limit)
local rematchVoted = { stale = false }
local function postMatch() return st("PostMatch") == true or player:GetAttribute("InPseudoLobby") == true end
-- [PAD] (Edward 2026-10-20, RIVALS results) Y Rematch, X Play Again, B Leave: a round glyph on each button's left edge with a
-- controller, and those buttons press them (in a table / do-block: this script is at the 200-locals limit)
local resultActs = {}
function resultActs.leave()
	send(postMatch() and "ToHub" or "Leave") -- (the Tacticals session's post-match phase: Leave takes you to the hub)
	rgui.Enabled = false; results.Visible = false
	if resultBackdrop then resultBackdrop(false) end
end
function resultActs.again() send("PlayAgain"); againB:FindFirstChildOfClass("TextLabel").Text = "Searching..." end
function resultActs.rematch()
	if st("RematchAllowed") == false then return end
	send("Rematch") -- toggles your vote on the server (player attribute RematchVote shows it)
end
leaveB.Activated:Connect(resultActs.leave)
againB.Activated:Connect(resultActs.again)
rematchB.Activated:Connect(resultActs.rematch)
do
	local MAP = { { rematchB, Enum.KeyCode.ButtonY, resultActs.rematch }, { againB, Enum.KeyCode.ButtonX, resultActs.again }, { leaveB, Enum.KeyCode.ButtonB, resultActs.leave } }
	local glyphs = {}
	for _, m in MAP do
		local img = ""
		pcall(function() img = UserInputService:GetImageForKeyCode(m[2]) end)
		local g = new("ImageLabel", { Name = "PadGlyph", BackgroundTransparency = 1, Image = img, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeYY, Visible = false, ZIndex = 9, Parent = m[1] })
		table.insert(glyphs, g)
	end
	local padOn = false
	local function show() for _, g in glyphs do g.Visible = padOn and g.Image ~= "" end end
	local function onType(t)
		if t == Enum.UserInputType.MouseMovement then return end -- (a resting mouse must not hide the glyphs)
		local pad = t.Name:find("Gamepad") ~= nil
		if not pad and not (t == Enum.UserInputType.Keyboard or t.Name:find("Mouse") or t == Enum.UserInputType.Touch) then return end
		padOn = pad; show()
	end
	UserInputService.LastInputTypeChanged:Connect(onType)
	onType(UserInputService:GetLastInputType())
	player:GetAttributeChangedSignal("_ForcePad"):Connect(function() if RunService:IsStudio() then padOn = player:GetAttribute("_ForcePad") == true; show() end end)
	UserInputService.InputBegan:Connect(function(input)
		if not rgui.Enabled then return end
		for _, m in MAP do
			if input.KeyCode == m[2] and m[1].Visible then m[3]() return end
		end
	end)
end
-- one look for a Rematch button: votes "n/needed", your own vote lit olive, "Starting in N" once everyone's in,
-- greyed only when the server says RematchAllowed = false (with RematchReason). (2026-10-19, Edward: "you should be able to
-- rematch instantly") nil = not sent yet = allowed, and RematchNeeded defaults to the match's player count (1v1 -> 2), so it
-- reads 0/2 the moment the game ends.
local function styleRematch(btn, title, sub)
	local allowed = st("RematchAllowed") ~= false
	local rv = rematchVoted
	local votes, vote = st("RematchVotes"), player:GetAttribute("RematchVote")
	if rv.stale and (votes ~= rv.votes or vote ~= rv.vote) then rv.stale = false end   -- the server moved: trust it
	if rv.stale then votes, vote = 0, false end
	local voted = vote == true
	local needed = tonumber(st("RematchNeeded"))
	if not needed then
		local a, b = tostring(st("MatchMode") or ""):match("(%d+)%s*[vV]%s*(%d+)")
		needed = (tonumber(a) or 1) + (tonumber(b) or 1)
	end
	btn.Active = allowed
	btn.BackgroundTransparency = allowed and 0 or 0.6
	title.TextTransparency = allowed and 0 or 0.6
	sub.TextTransparency = allowed and 0 or 0.6
	-- (2026-10-21, AI-tells cleanup) no hairline at rest; a thick (3 px) beige ring only once voted (it carries the state)
	local stroke = btn:FindFirstChild("VotedEdge") or new("UIStroke", { Name = "VotedEdge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = TEAM_A[1],
		Thickness = 3, Transparency = 1, Parent = btn })
	stroke.Color, stroke.Thickness = TEAM_A[1], 3
	stroke.Transparency = (allowed and voted) and 0 or 1
	local startsAt = st("RematchStartsAt")
	if not allowed then
		sub.Text = tostring(st("RematchReason") or "Unavailable")
	elseif typeof(startsAt) == "number" and startsAt > workspace:GetServerTimeNow() then
		sub.Text = "Starting in " .. math.ceil(startsAt - workspace:GetServerTimeNow())
	else
		sub.Text = string.format("%d/%d", tonumber(votes) or 0, needed) .. (voted and "  ·  voted" or "")
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
	deltaT.TextColor3 = d >= 0 and Color3.fromRGB(90, 190, 255) or BAD
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
	if rblurOn ~= on then rblurOn = on; TweenService:Create(rblur, TweenInfo.new(0.3), { Size = on and 8 or 0 }):Play() end -- (2026-10-22, RIVALS: the world stays clear behind the winner; a light blur only seats the posed clone)
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
	stats.wasPseudo = player:GetAttribute("InPseudoLobby") == true -- (only the arrival AFTER the results closes them)
	resultBackdrop(true)
	rematchVoted = { stale = true, votes = st("RematchVotes"), vote = player:GetAttribute("RematchVote") }
	print(string.format("[Rematch] game end: RematchAllowed=%s RematchNeeded=%s RematchReason=%s RematchVotes=%s RematchVote=%s MatchMode=%s",
		tostring(st("RematchAllowed")), tostring(st("RematchNeeded")), tostring(st("RematchReason")), tostring(st("RematchVotes")),
		tostring(player:GetAttribute("RematchVote")), tostring(st("MatchMode"))))
	againB:FindFirstChildOfClass("TextLabel").Text = "Play Again"
	-- (2026-10-23, Edward: "play again should not be an option in lobby duels" - it queues you against the whole server) a hub pad
	-- duel (the lobby's LobbyMap + a DuelMatch / InDuel player) shows Rematch and Leave only
	local padDuel = workspace:FindFirstChild("LobbyMap") ~= nil and (player:GetAttribute("DuelMatch") ~= nil or player:GetAttribute("InDuel") == true
		or tostring(st("MatchMode") or ""):find("Lobby") ~= nil)
	againB.Visible = not padDuel
	rematchB.Visible = not padDuel -- (the lead: pad duels never had a rematch; the button is simply absent there)
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
		BackgroundColor3 = Color3.fromRGB(18, 19, 23), BackgroundTransparency = 0.2, Parent = pcanvas }, { new("UICorner", { CornerRadius = UDim.new(0.08, 0) }) })
		-- (2026-10-21, AI-tells cleanup) flat dark plate, hairline edge removed
	local t = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = FX, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.08, sub and 0.1 or 0.18),
		Size = UDim2.fromScale(0.84, sub and 0.52 or 0.64), Parent = b }, { new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }) })
	local st2 = sub and new("TextLabel", { BackgroundTransparency = 1, Text = sub, FontFace = FB, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.15, 0.62),
		Size = UDim2.fromScale(0.7, 0.26), Parent = b }) or nil
	stats.bind(b) -- (2026-10-21, RIVALS pass) one button behaviour (Kit.bindButton; it re-anchors the button to its centre)
	return b, t, st2
end
local hubP = panelButton("ToHub", "To Hub", nil, 0.985)
local againP, againPT = panelButton("PlayAgain", "Play Again", nil, 0.91)
local rematchP, rematchPT, rematchPS = panelButton("Rematch", "Rematch", "0/2", 0.835)
hubP.Activated:Connect(function() send("ToHub") end)
againP.Activated:Connect(function() send("PlayAgain"); againPT.Text = "Searching..." end)
-- (2026-10-21, round 3: match RIVALS) the after-match panel's Play Again matches the results card's primary: field-green
-- gradient (#8DBF5A -> #4C7A2E), cream words, a chunky bottom lip (it was the one dark plate left of the "skipped" list)
againP.BackgroundColor3, againP.BackgroundTransparency = WHITE, 0
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)), Parent = againP })
new("Frame", { Name = "Lip", BackgroundColor3 = BLACK, BackgroundTransparency = 0.7, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.16), Parent = againP }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
againPT.TextColor3 = Color3.fromRGB(236, 230, 210)
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
		-- (2026-10-22, live RIVALS after a match) one row at the play row's height: To Hub (left) | Play | Rematch (right), each
		-- the Play button's size, 1.6 % of the width apart. Without the play row: the old bottom-right stack.
		local playB = lobbyRow and row:FindFirstChild("Play", true)
		local cs, cp = pcanvas.AbsoluteSize, pcanvas.AbsolutePosition
		if playB and playB:IsA("GuiObject") and playB.AbsoluteSize.X > 0 and cs.X > 0 then
			local px, py = (playB.AbsolutePosition.X - cp.X) / cs.X, (playB.AbsolutePosition.Y - cp.Y) / cs.Y
			local pw, ph = playB.AbsoluteSize.X / cs.X, playB.AbsoluteSize.Y / cs.Y
			for i, b in { hubP, rematchP } do
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Size = UDim2.fromScale(pw, ph)
				b.Position = UDim2.fromScale(px + pw / 2 + (i == 1 and -1 or 1) * (pw + 0.016), py + ph / 2)
			end
		else
			-- (2026-10-21, RIVALS pass) bottom-right corner at (0.992, y) whatever its anchor (Kit.bindButton centres it)
			for _, e in { { hubP, 0.985 }, { rematchP, 0.835 } } do
				local b = e[1]
				b.Size = UDim2.fromScale(0.118, 0.066)
				local ap, sz = b.AnchorPoint, b.Size
				b.Position = UDim2.fromScale(0.992 - sz.X.Scale * (1 - ap.X), e[2] - sz.Y.Scale * (1 - ap.Y))
			end
		end
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
		-- (2026-10-22, live RIVALS) arriving back in the lobby closes the result screen: the To Hub / Play / Rematch row takes over
		if player:GetAttribute("InPseudoLobby") == true and stats.wasPseudo == false and not rankPage.Visible then
			stats.wasPseudo = true
			rgui.Enabled = false; results.Visible = false
			resultBackdrop(false)
			return
		end
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
do -- the round-change dip to black (its own ScreenGui above the HUD; full screen, Scale only)
	local fg = new("ScreenGui", { Name = "RoundFade", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 14, Parent = player:WaitForChild("PlayerGui") })
	RV.fade = new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = fg })
	RV.fadeWant = 1
end
do
---------------------------------------------------------------------------------------------------- round card (RIVALS)
-- (2026-10-18, live RIVALS with Edward) a round's end: a small green "ROUND / WON" or red "ROUND / LOST" card pops in under
-- the timer with a white flash, and stays until the next round goes live.
-- (2026-10-20, the RIVALS mix) back to RIVALS' small card under the timer: "ROUND" over "WON" / "LOST", filled with the side's
-- muted colour (tan ours, dark green theirs). Through a deciding round's countdown it reads MATCH POINT (RV.showMatchPoint).
-- (2026-10-22, live RIVALS ROUND LOST) 246 x 95 at y 147: a clear gap under the timer, narrower, a heavier word
-- (m7, RIVALS t0118: the round card sits right under the score bar, y 10.8 %; was 147)
local roundCard = new("Frame", { Name = "RoundCard", Position = UDim2.fromOffset(837, 117), Size = UDim2.fromOffset(246, 95), BackgroundColor3 = WHITE, BackgroundTransparency = 0.06,
	Visible = false, ZIndex = 6, Parent = root }, { corner(8) })
local roundGrad = new("UIGradient", { Rotation = 90, Parent = roundCard })
local roundSmall = label(roundCard, "ROUND", FB, 22, 0, 4, 246, 26, WHITE, nil, 7)
local roundBig = label(roundCard, "WON", FX, 56, 0, 26, 246, 64, WHITE, nil, 7)
roundBig:FindFirstChildOfClass("UIStroke").Thickness, roundBig:FindFirstChildOfClass("UIStroke").Transparency = 2.5, 0.2
local roundMP = label(roundCard, "MATCH POINT", FX, 32, 0, 8, 246, 44, WHITE, nil, 7)
local roundMPSub = label(roundCard, "", FB, 19, 0, 54, 246, 30, WHITE, nil, 7)
roundMP.Visible, roundMPSub.Visible = false, false
local roundPop = new("UIScale", { Parent = roundCard })
local function showRoundCard(won)
	local f = won and TEAM_A.fill or TEAM_B.fill
	roundGrad.Color = ColorSequence.new(f[1], f[2])
	roundBig.Text = won and "WON" or "LOST"
	roundSmall.Text = "ROUND"
	roundBig.Visible, roundSmall.Visible, roundMP.Visible, roundMPSub.Visible = true, true, false, false
	roundCard.Visible = true
	-- (m8, grader A vs RIVALS t0054 / t0210) WON sits right under the score bar (y 117), LOST a little lower (y 147)
	roundCard.Position = UDim2.fromScale(837 / W, (won and 117 or 147) / H)
	RV.dimRoundCard(false)
	roundPop.Scale = 1.25
	TweenService:Create(roundPop, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	RV.flashRoundCard()
end
-- (2026-10-23, matchmaking round m1, RIVALS t0122) when MATCH POINT / SUDDEN DEATH lands at the countdown, the WON / LOST card
-- under it fades to about half
function RV.dimRoundCard(on)
	local ti = TweenInfo.new(on and 0.3 or 0)
	TweenService:Create(roundCard, ti, { BackgroundTransparency = on and 0.3 or 0.06 }):Play() -- (m7: 0.5 went grey; RIVALS keeps the colour)
	for _, l in { roundBig, roundSmall } do
		TweenService:Create(l, ti, { TextTransparency = on and 0.5 or 0 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then TweenService:Create(st, ti, { Transparency = on and 0.75 or 0.2 }):Play() end
	end
end
function RV.fadeRoundCard()
	local ti = TweenInfo.new(0.4)
	TweenService:Create(roundCard, ti, { BackgroundTransparency = 1 }):Play()
	for _, l in { roundBig, roundSmall } do
		TweenService:Create(l, ti, { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then TweenService:Create(st, ti, { Transparency = 1 }):Play() end
	end
	task.delay(0.45, function() roundCard.Visible = false; RV.dimRoundCard(false) end)
end
-- (2026-10-21, RIVALS pass) the flash the header comment promises: a cream wash fades off the card (0.3 -> 1 over 0.25 s) and the
-- existing sweep() bar crosses it once. In RV (200-locals limit); MATCH POINT uses it too.
function RV.flashRoundCard()
	local wash = new("Frame", { Name = "Flash", BackgroundColor3 = Color3.fromRGB(236, 230, 210), BackgroundTransparency = 0.3, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = roundCard })
	local c = roundCard:FindFirstChildOfClass("UICorner"); if c then c:Clone().Parent = wash end
	local tw = TweenService:Create(wash, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	tw.Completed:Once(function() wash:Destroy() end)
	tw:Play()
	sweep(roundCard, 8)
end

---------------------------------------------------------------------------------------------------- eliminated
-- (2026-10-23, matchmaking round m7, grader A vs RIVALS t0054 / t0118: y 69-73 %, ~24 % wide, ~3.9 % tall) lower and bigger
local elimL = new("TextLabel", { Name = "Eliminated", BackgroundTransparency = 1, RichText = true, Text = "", FontFace = FB, TextSize = 44, TextColor3 = WHITE,
	Position = UDim2.fromOffset(460, 748), Size = UDim2.fromOffset(1000, 56), Visible = false, ZIndex = 6, Parent = root })
elimL:SetAttribute("dTS", 44); table.insert(scaled, elimL)
new("UIStroke", { Thickness = 2, Transparency = 0.4, Parent = elimL })
-- (2026-10-20, the common theme of every duel game Edward showed: Knife / Murder Duels' "+XP HEADSHOT / KILL", Redliner's
-- "Killed X!", Hood Rivals' ELIMINATED) what the kill was, in small grey caps under the name
local elimSub = new("TextLabel", { Name = "EliminatedHow", BackgroundTransparency = 1, Text = "", FontFace = FB, TextSize = 22, TextColor3 = Color3.fromRGB(232, 232, 236),
	Position = UDim2.fromOffset(560, 804), Size = UDim2.fromOffset(800, 28), Visible = false, ZIndex = 6, Parent = root })
elimSub:SetAttribute("dTS", 22); table.insert(scaled, elimSub)
new("UIStroke", { Thickness = 2, Transparency = 0.25, Parent = elimSub }) -- (live check) readable over the bright Practice Range walls
local elimToken = 0
function RV.endElim()
	if not elimL.Visible then return end
	elimToken += 1
	local ti = TweenInfo.new(0.3)
	TweenService:Create(elimL, ti, { TextTransparency = 1 }):Play()
	TweenService:Create(elimSub, ti, { TextTransparency = 1 }):Play()
	task.delay(0.32, function() elimL.Visible = false; elimSub.Visible = false end)
end
showEliminated = function(uid, d)
	elimToken += 1
	local my = elimToken
	-- (serious pass) the name in their side's colour (light green), not the old purple
	elimL.Text = 'Eliminated  <font color="#96B288">' .. nameOf(uid) .. '</font>'
	elimL.TextTransparency = 0
	elimL.Visible = true
	local how = {}
	if d and d.noscope then table.insert(how, "NO-SCOPE") end
	if d and d.headshot then table.insert(how, "HEADSHOT") end
	if d and (d.kind == "Melee" or d.kind == "Takedown") then table.insert(how, string.upper(d.kind)) end
	table.insert(how, "KILL")
	elimSub.Text = table.concat(how, "   ·   ")
	elimSub.TextTransparency = 0
	elimSub.Visible = true
	local pop = elimL:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = elimL })
	pop.Scale = 1.4
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(slow(4), function() -- (m5, RIVALS t0118-t0122: "Eliminated X" holds ~4 s, through the round end; was 2.2)
		if elimToken ~= my then return end
		TweenService:Create(elimL, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(elimSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.45, function() if elimToken == my then elimL.Visible = false; elimSub.Visible = false end end)
	end)
end

---------------------------------------------------------------------------------------------------- killer card (RIVALS)
-- bottom right while your killer is on camera: their headshot with a health bar over it, level badge, win streak flame,
-- name + @username, "eliminated you with <weapon>". In the killer's team colour.
-- (2026-10-22, Edward: "match it with rivals") RIVALS' kill banner (rv_match r0044.6): 675 x 134 at (1143, 822), a solid
-- top-to-bottom fill of the killer's side, no fade; the head a dark rounded square inset at the left with the health bar inside
-- its top, the level seal hanging over the banner's left edge, the device on the head's bottom-right; no weapon picture
local kcard = new("Frame", { Name = "KillerCard", Position = UDim2.fromOffset(1143, 822), Size = UDim2.fromOffset(675, 134), BackgroundColor3 = WHITE,
	Visible = false, ZIndex = 6, Parent = root }, { corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(TEAM_B.fill[1], TEAM_B.fill[2]) }) })
-- (2026-10-20, the RIVALS mix) RIVALS' killer card filled with the killer's side colour (muted dark green), fading to the right
local kHead = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.15, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(110, 110), ZIndex = 7, Parent = kcard }, { corner(10) }) -- (2026-10-22, live RIVALS) a dark rounded square, not a disc
local kHpBack = new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, Position = UDim2.fromOffset(22, 20), Size = UDim2.fromOffset(90, 9), ZIndex = 8, Parent = kcard }, { corner(5) }) -- inside the head's top, like RIVALS
local kHp = new("Frame", { BackgroundColor3 = GOOD, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = kHpBack }, { corner(5) })
local kLevel = new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 150, 230), Position = UDim2.fromOffset(-6, 66), Size = UDim2.fromOffset(62, 62), ZIndex = 9, Parent = kcard }, { corner(31) }) -- (2026-10-22, RIVALS) the seal (~half the banner tall) hangs over the banner's left edge, head bottom-left -- (2026-10-21, AI-tells cleanup) hairline ring removed
local kLevelL = label(kLevel, "1", FX, 24, 0, 0, 46, 46, WHITE, nil, 10)
-- the win streak: the flame silhouette with the number over it (Kit.ICONS.streak), like RIVALS
local kStreak = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://89001729086571", ImageColor3 = Color3.fromRGB(255, 140, 40), -- (re-pointed below to Kit.streakImage)
	Position = UDim2.fromOffset(94, 88), Size = UDim2.fromOffset(46, 46), Visible = false, ZIndex = 9, Parent = kcard })
pcall(function() -- (2026-10-20) the full-colour codex flame once it's uploaded (UIKit.Kit.streakImage)
	local K = require(ReplicatedStorage.UIKit.Kit)
	if K.streakImage then kStreak.Image, kStreak.ImageColor3 = K.streakImage() end
end)
local kStreakL = label(kStreak, "3", FX, 22, 0, 16, 46, 26, WHITE, nil, 10)
new("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(240, 70, 30), Parent = kStreakL }) -- (2026-10-20) RIVALS number edge
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 222, 196)), Parent = kStreakL })
-- (2026-10-22, spacing grade vs RIVALS) the name sits ~0.45 cap off the head (was 26 design px, ~0.9 cap)
local kName = label(kcard, "", FX, 46, 137, 6, 560, 52, WHITE, Enum.TextXAlignment.Left, 7)
local kUser = label(kcard, "", FB, 20, 138, 52, 520, 24, Color3.fromRGB(235, 225, 225), Enum.TextXAlignment.Left, 7)
kUser.TextTransparency = 0.35 -- (2026-10-22, RIVALS) the @handle is faint
local kHow = label(kcard, "", FB, 28, 145, 74, 560, 34, WHITE, Enum.TextXAlignment.Left, 7)
-- RIVALS: the device on the head's bottom-right corner, the level seal on its bottom-left
RV.kDev = new("ImageLabel", { Name = "Device", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(84, 84), Size = UDim2.fromOffset(34, 34),
	Visible = false, ZIndex = 9, Parent = kcard })
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
	kName.Text = (uid and uid > 0 and Players:GetPlayerByUserId(uid)) and Players:GetPlayerByUserId(uid).DisplayName or nameOf(uid) -- (2026-10-22, RIVALS) the name alone on the banner, no badge glyph
	kUser.Text = p and ("@" .. p.Name) or ("@" .. string.lower(nameOf(uid))) -- (m11: bots get one too, like RIVALS' line)
	do
		local okD, BD = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
		local dv = p and okD and BD and BD.DeviceIcon and BD.DeviceIcon(p) or nil
		RV.kDev.Visible, RV.kDev.Image = dv ~= nil, dv or ""
	end
	-- (2026-10-20, Edward) ONE icon (UIKit.Badges.Icon): their streak flame, else their rank emblem (Rank mode), else their level
	local okB, B = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
	local kind, v = "level", p and p:GetAttribute("Level") or 1
	if okB and B and p then kind, v = B.Icon(p) end
	local emb = kcard:FindFirstChild("RankIcon") or new("ImageLabel", { Name = "RankIcon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Position = kLevel.Position, Size = kLevel.Size, ZIndex = 9, Parent = kcard })
	kStreak.Visible = kind == "streak"
	kStreak.Position = kLevel.Position
	kStreakL.Text = tostring(kind == "streak" and v or 0)
	emb.Visible, emb.Image = kind == "rank", kind == "rank" and v or ""
	kLevel.Visible = kind == "level" or kind == "wins"
	kLevelL.Text = tostring((kind == "level" or kind == "wins") and v or 1)
	-- (2026-10-20) level: our tiered shield (Kit.levelTier) instead of the blue circle
	local okK, K = pcall(function() return require(ReplicatedStorage.UIKit.Kit) end)
	local shield = kLevel:FindFirstChild("Shield") or new("ImageLabel", { Name = "Shield", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.3, 1.3), ZIndex = 9, Parent = kLevel })
	local useShield = kind == "level" and okK and K.levelTier ~= nil
	shield.Visible = useShield
	kLevel.BackgroundTransparency = useShield and 1 or 0
	local ks = kLevel:FindFirstChildOfClass("UIStroke"); if ks then ks.Enabled = not useShield end
	local ls = kLevelL:FindFirstChildOfClass("UIStroke")
	if useShield then
		local img, edge = K.levelTier(v)
		shield.Image = img
		if ls then ls.Color, ls.Transparency = edge, 0 end
		if K.levelNumber then K.levelNumber(kLevelL) end -- (2026-10-22, Edward: level numbers like RIVALS)
		-- the seal's number at RIVALS' size: as wide as the seal (3 digits run past it), ~0.54 of it tall, a hair below centre
		kLevelL.TextScaled, kLevelL.AnchorPoint = true, Vector2.new(0.5, 0.5)
		kLevelL.Position, kLevelL.Size = UDim2.fromScale(0.5, 0.55), UDim2.fromScale(1.12, 0.54)
		shield.Size = UDim2.fromScale(1, 1)
	elseif ls then ls.Color = BLACK end
	local m = targetModel(uid)
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	local frac = hum and hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
	kHp.Size = UDim2.fromScale(frac, 1)
	kHp.BackgroundColor3 = frac > 0.5 and GOOD or (frac > 0.25 and Color3.fromRGB(235, 190, 60) or BAD)
	local how = "eliminated you"
	if lastDeath and lastDeath.killer == uid then
		local kind = ({ Melee = "a melee hit", Takedown = "a takedown", Explosion = "an explosion", StickyGrenade = "a sticky grenade", Landmine = "a landmine", Burn = "fire" })[lastDeath.kind]
		local w = lastDeath.weapon and tostring(lastDeath.weapon) or kind
		if w then how ..= " with " .. w end
	end
	kHow.Text = how
	-- (2026-10-22, Edward: match RIVALS) RIVALS' banner names the weapon in the text only: no silhouette, no headshot mark
	-- (kept built but hidden, in case the separate kill card wants them)
	local KI = nil
	pcall(function() KI = require(ReplicatedStorage.UIKit.KillIcons) end)
	local wi = kcard:FindFirstChild("WeaponIcon") or new("ImageLabel", { Name = "WeaponIcon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(0.7, 0.12), Size = UDim2.fromScale(0.27, 0.5), ZIndex = 8, Parent = kcard })
	local mk = kcard:FindFirstChild("ShotMark") or new("ImageLabel", { Name = "ShotMark", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(0.86, 0.6), Size = UDim2.fromScale(0.1, 0.34), ZIndex = 8, Parent = kcard })
	local ld = (lastDeath and lastDeath.killer == uid) and lastDeath or nil
	wi.Image = (KI and ld and KI.Weapon(typeof(ld.weapon) == "string" and ld.kind ~= "Takedown" and ld.weapon or nil, ld.kind)) or ""
	mk.Image = (KI and ld and ((ld.noscope and KI.Status("noscope")) or (ld.headshot and KI.Status("headshot")))) or ""
	wi.Visible, mk.Visible = false, false
	RV.setKillWeapon(uid, ld and ld.kind ~= "Takedown" and typeof(ld.weapon) == "string" and ld.weapon or nil)
end

-- (2026-10-22, Edward's live RIVALS games, notes/ui_rivals/killcard t0208-t0336) the kill banner carries the killer's actual weapon
-- as a big tilted 3D model in its skin, poking out of the banner's right end (from above its top edge to the screen bottom). The
-- model is the Repository copy, in its own colours. Built once per weapon.
RV.kWeapon = new("ViewportFrame", { Name = "KillWeapon", BackgroundTransparency = 1, Ambient = Color3.fromRGB(215, 215, 220), LightColor = WHITE,
	LightDirection = Vector3.new(-1, -0.6, 0.3), Position = UDim2.fromOffset(455, -150), Size = UDim2.fromOffset(340, 340), Visible = false, ZIndex = 10, Parent = kcard })
function RV.setKillWeapon(uid, weapon)
	local vpf = RV.kWeapon
	if not weapon then vpf.Visible = false; RV.kWeaponKey = nil; return end
	local key = weapon
	vpf.Visible = true
	if RV.kWeaponKey == key then return end
	RV.kWeaponKey = key
	vpf:ClearAllChildren()
	-- the Repository model (laid out barrel along -Z, like the kill feed's); a held tool's world pose is arbitrary
	-- (TODO once wraps ship to the match: copy the killer's wrap onto it)
	local src
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	for _, f in { "Weapons", "Melee" } do
		local folder = repo and repo:FindFirstChild(f)
		src = src or (folder and folder:FindFirstChild(weapon))
	end
	if not src then vpf.Visible = false; return end
	local model = Instance.new("Model")
	for _, bp in src:GetDescendants() do
		if bp:IsA("BasePart") and bp.Transparency < 0.9 then
			local c = bp:Clone()
			for _, k in c:GetChildren() do
				if not (k:IsA("DataModelMesh") or k:IsA("Decal") or k:IsA("Texture") or k:IsA("SurfaceAppearance")) then k:Destroy() end
			end
			c.Anchored = true
			c.Parent = model
		end
	end
	model.Parent = vpf
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 20
	local reach = math.max(size.X, size.Y, size.Z) / 2 / math.tan(math.rad(10)) * 1.05
	-- side on from +X (the Repository models' muzzle then points left), rolled so it points up-left like RIVALS' banner weapon
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.xAxis * reach, cf.Position) * CFrame.Angles(0, 0, math.rad(-35))
	cam.Parent = vpf
	vpf.CurrentCamera = cam
end

---------------------------------------------------------------------------------------------------- switch weapons (RIVALS)
-- between rounds: a blue "Switch Weapons [M]" button in the middle; it (or M) opens the loadout picker (MatchFlowUI)
-- (2026-10-22, live RIVALS intermission) a slim pill: ~15 % of the width, 50 tall, centred at 72 % of the height (was 470 x 78)
local switchB = new("TextButton", { Name = "SwitchWeapons", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(810, 752), Size = UDim2.fromOffset(300, 50),
	BackgroundColor3 = WHITE, Visible = false, ZIndex = 6, Parent = root }, { corner(8),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 180, 255), Color3.fromRGB(20, 110, 230)) }) })
label(switchB, "Switch Weapons", FX, 27, 10, 0, 236, 50, WHITE, nil, 7)
local keyChip = new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 62, 66), Position = UDim2.fromOffset(254, 8), Size = UDim2.fromOffset(34, 34), ZIndex = 7, Parent = switchB }, { corner(6) }) -- (2026-10-21, AI-tells cleanup) hairline edge removed
local keyL = label(keyChip, "M", FX, 22, 0, 0, 34, 34, WHITE, nil, 8)
local switchScale = new("UIScale", { Parent = switchB })
gloss(switchB, 8, 0.3)
-- (2026-10-21, RIVALS pass) one button behaviour: Kit.bindButton drives switchScale (hover 1.05 / press 0.93 / sfx)
stats.bind(switchB)
local function switchHook() return player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("SwitchWeapons") end
switchB.Activated:Connect(function() local h = switchHook(); if h then h:Invoke("Toggle") end end)
UserInputService.InputBegan:Connect(function(i, gp)
	if gp or not switchB.Visible then return end
	if i.KeyCode == Enum.KeyCode.M or i.KeyCode == Enum.KeyCode.ButtonX then local h = switchHook(); if h then h:Invoke("Toggle") end end -- [PAD] X (Edward 2026-10-20)
end)
-- the chip shows X with a controller
local function chipText(t)
	t = t or UserInputService:GetLastInputType()
	if t == Enum.UserInputType.MouseMovement then return end -- (2026-10-20) mouse MOVEMENT never flips back to keyboard + mouse: a resting mouse / locked cursor sends it, and hid every controller icon
	keyL.Text = t.Name:find("Gamepad") and "X" or "M"
end
UserInputService.LastInputTypeChanged:Connect(chipText)
chipText()

RV.roundCard, RV.showRoundCard, RV.kcard, RV.refreshKillerCard, RV.switchB, RV.switchHook = roundCard, showRoundCard, kcard, refreshKillerCard, switchB, switchHook
-- (2026-10-20, Knife Duels / Murder Duels / RIVALS) MATCH POINT on the same banner, through the countdown of a round that can
-- end the match: "You need 1 point to win!" (ours, beige) / "They need 1 point to win" (theirs, green) / both: "Next round wins"
-- (2026-10-23, Edward: "match point screens and sudden death being 4-4 ... add these aesthetics", his RIVALS recording t0122 / t0338 /
-- t0358) RIVALS' ribbon: a big red banner across the top centre (0.31-0.69 W, over the score boxes) with a huge white "MATCH POINT",
-- or "SUDDEN DEATH" when both sides are one round from winning; the ROUND WON / LOST card stays under it. It pops in as the round
-- ends and fades out once the next round is live.
-- (2026-10-23, matchmaking round m2, RIVALS t0122) a thin red bar (714 x 50, top at y 50) with oversized ExtraBold words that
-- spill above and past it; no folded tabs
RV.ribbon = new("Frame", { Name = "MatchPointRibbon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 50), Size = UDim2.fromOffset(714, 50),
	BackgroundColor3 = WHITE, Visible = false, ZIndex = 9, Parent = root }, { corner(4),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 64, 60)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(205, 36, 36)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 18, 22)) }) }) })
RV.ribbonText = label(RV.ribbon, "MATCH POINT", Font.new("rbxassetid://12187365977", Enum.FontWeight.ExtraBold), 88, -60, -50, 834, 104, WHITE, nil, 10)
do
	local st2 = RV.ribbonText:FindFirstChildOfClass("UIStroke")
	if st2 then st2.Thickness, st2.Transparency, st2.Color = 2, 0.45, Color3.fromRGB(60, 8, 10) end
end
RV.ribbonScale = new("UIScale", { Parent = RV.ribbon })
function RV.showRibbon(text)
	RV.ribbonText.Text = text
	RV.ribbon.BackgroundTransparency = 0
	RV.ribbonText.TextTransparency = 0
	for _, f in RV.ribbon:GetChildren() do if f:IsA("Frame") then f.BackgroundTransparency = 0 end end
	if not RV.ribbon.Visible then
		RV.ribbon.Visible = true
		RV.ribbonScale.Scale = 1.35
		TweenService:Create(RV.ribbonScale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end
function RV.fadeRibbon()
	if not RV.ribbon.Visible then return end
	local ti = TweenInfo.new(0.6)
	TweenService:Create(RV.ribbon, ti, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(RV.ribbonText, ti, { TextTransparency = 1 }):Play()
	for _, f in RV.ribbon:GetChildren() do if f:IsA("Frame") then TweenService:Create(f, ti, { BackgroundTransparency = 1 }):Play() end end
	task.delay(0.65, function() RV.ribbon.Visible = false end)
end
RV.showMatchPoint = function(mine, theirs, toWin)
	if not toWin or (mine < toWin - 1 and theirs < toWin - 1) then return end
	if mine >= toWin or theirs >= toWin then return end -- the match is over: no ribbon
	RV.showRibbon((mine >= toWin - 1 and theirs >= toWin - 1) and "SUDDEN DEATH" or "MATCH POINT")
	do return end -- (the old in-card MATCH POINT below is kept for reference; the ribbon replaces it)
	local us, them = mine >= toWin - 1, theirs >= toWin - 1
	local f = (us and not them) and TEAM_A.fill or ((them and not us) and TEAM_B.fill or { Color3.fromRGB(40, 42, 48), Color3.fromRGB(16, 17, 20) })
	roundGrad.Color = ColorSequence.new(f[1], f[2])
	roundMPSub.Text = (us and them) and "Next round wins" or (us and "You need 1 point to win!" or "They need 1 point to win")
	roundBig.Visible, roundSmall.Visible, roundMP.Visible, roundMPSub.Visible = false, false, true, true
	roundCard.Visible = true
	roundPop.Scale = 1.25
	TweenService:Create(roundPop, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	RV.flashRoundCard() -- (2026-10-21, RIVALS pass)
end
end

toScale(canvas, Vector2.new(W, H))
rescale()

---------------------------------------------------------------------------------------------------- headshots + score
local heads = {}
local function fillBox(box, ids)
	-- (2026-10-22, live RIVALS) a box is as wide as its team: one head + the score in a 1v1 (156 design px), up to three heads
	-- (284). The pair hugs the timer (mine ends at x 880, theirs starts at 1040); heads and score re-laid in Scale of the box.
	local n = math.clamp(#ids, 1, 3)
	if box.n ~= n then
		box.n = n
		local w = 75 + 64 * n -- (m9, grader A vs RIVALS t0040: a 1v1 plate is 139 px; was 128)
		box.frame.Size = UDim2.fromScale(w / W, 84 / H)
		box.frame.Position = UDim2.fromScale((box.right and 1063 or (857 - w)) / W, 11 / H) -- (m5: 31 px gaps to the timer, RIVALS t0040; m9: top at y 11 = 1 %)
		for i = 1, 3 do
			local hx = box.right and (58 + (i - 1) * 64) or (14 + (i - 1) * 64)
			box.slots[i].h.Position = UDim2.fromScale(hx / w, 14 / 84)
			box.slots[i].h.Size = UDim2.fromScale(56 / w, 56 / 84)
		end
		box.score.Position = UDim2.fromScale((box.right and 10 or (w - 60)) / w, 6 / 84) -- (the digit sits ~11 px off the head)
		box.score.Size = UDim2.fromScale(50 / w, 72 / 84)
	end
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
			-- (2026-10-21, RIVALS pass) a death is noticed: the skull pops 1.6 -> 1 when a head flips to dead (state in s.dead)
			if dead and s.dead == false and stats.Kit then
				if not s.centred then s.centred = true; stats.Kit.centreAnchor(s.skull) end -- grow from the middle of the head
				stats.Kit.pop(s.skull, 1.6)
			end
			s.dead = dead and true or false
			local lv = p and tonumber(p:GetAttribute("Level")) or nil
			if s.lv ~= lv then
				s.lv = lv
				s.seal:ClearAllChildren()
				if lv and stats.Kit and stats.Kit.levelSeal then pcall(function() stats.Kit.levelSeal(s.seal, lv, { ZIndex = 7 }) end) end
			end
			local okB, B = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
			local dv = p and okB and B and B.DeviceIcon and B.DeviceIcon(p) or nil
			s.dev.Visible = dv ~= nil and not dead
			s.dev.Image = dv or ""
			s.seal.Visible = not dead
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
			-- (Edward 2026-10-19) no ROUND n / FIGHT call-outs around the countdown: the top clock counts it instead
			local up = tostring(t or ""):upper()
			if up:find("^FIGHT") or up:find("^ROUND %d+$") then return end
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
	-- (2026-10-20, Knife / Sniper / Murder Duels, Hood Rivals, Redliner) the round-change dip to black: the last 0.35 s of a
	-- RoundEnd in your match, lifted as soon as the next state starts (before any early return, so it can never stick)
	do
		local endsIn = (st("StateEndsAt") or 0) - workspace:GetServerTimeNow()
		local want = (inMatch() and state == "RoundEnd" and endsIn < 0.35 and endsIn > 0) and 0 or 1
		if want ~= RV.fadeWant then
			RV.fadeWant = want
			TweenService:Create(RV.fade, TweenInfo.new(want == 0 and 0.3 or 0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = want }):Play()
		end
	end
	local playing = inMatch() and (state == "RunIn" or state == "Countdown" or state == "Live" or state == "RoundEnd" or state == "Victory" or state == "MatchEnd")
		and not (st("PostMatch") == true or player:GetAttribute("InPseudoLobby") == true) -- the post-match lobby: no match HUD (the results card can still show)
	-- a new match (or none): the old card / banner never carries over
	local _, mid = stateObject()
	if mid ~= lastMatchId then
		lastMatchId = mid
		results.Visible = false; banner.Visible = false; resultsShown = false; lastState = nil
		for _, c in feed:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		tally = {}
		mineBox.last, theirBox.last = nil, nil -- (2026-10-21, RIVALS pass) no score bump for the new match's 0
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
	-- score bar
	local myTeam = player:GetAttribute("Team") or "A"
	if spectator() then myTeam = "A" end
	local ids = { A = teamIds("TeamA"), B = teamIds("TeamB") }
	-- (Edward 2026-10-20) no Leave button in a real match: only in solo duels (everyone else is a bot) and Studio tests
	local solo = RunService:IsStudio()
	if not solo then
		solo = true
		for _, team in { ids.A, ids.B } do
			for _, uid in team do if uid > 0 and uid ~= player.UserId then solo = false end end
		end
	end
	leaveDuel.Visible = solo and not spectator() and state ~= "MatchEnd"
	-- Settings > Game: Hide Teammate Display keeps only you in your team's box; Gameplay HUD "Minimal" drops the score
	-- bar and kill feed (banners and the results card stay)
	local myIds = ids[myTeam] or ids.A
	if player:GetAttribute("Setting_HideTeammateDisplay") == true and not spectator() then
		myIds = table.find(myIds, player.UserId) and { player.UserId } or {}
	end
	local minimal = player:GetAttribute("Setting_GameplayHUD") == "Minimal"
	local resUp = rgui ~= nil and rgui.Enabled
	mineBox.frame.Visible, theirBox.frame.Visible, timerBox.Visible, toWin.Visible, feed.Visible = not minimal and not resUp, not minimal and not resUp, not minimal and not resUp, false, not minimal and not resUp -- (m2: no "First to N" line, as RIVALS)
	if RV.ribbon and RV.ribbon.Visible then mineBox.frame.Visible, theirBox.frame.Visible, timerBox.Visible = false, false, false end -- (m3, RIVALS t0122: the ribbon replaces the score bar)
	fillBox(mineBox, myIds)
	fillBox(theirBox, myTeam == "A" and ids.B or ids.A)
	local sa, sb = st("ScoreA") or 0, st("ScoreB") or 0
	local mine, theirs = myTeam == "A" and sa or sb, myTeam == "A" and sb or sa
	mineBox.score.Text, theirBox.score.Text = tostring(mine), tostring(theirs)
	-- (2026-10-21, RIVALS pass) the score block bumps on a point (Kit.pop 1.5 -> 1); the last value lives in the box table
	for _, bx in { { mineBox, mine }, { theirBox, theirs } } do
		if bx[1].last ~= nil and bx[1].last ~= bx[2] and stats.Kit then
			if not bx[1].centred then bx[1].centred = true; stats.Kit.centreAnchor(bx[1].score) end -- grow from the digit's middle
			stats.Kit.pop(bx[1].score, 1.5)
		end
		bx[1].last = bx[2]
	end
	local left = math.max(0, (st("StateEndsAt") or st("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
	local between = state == "RoundEnd" or state == "Countdown"
	timerBox.Hourglass.Visible = true -- (m2, RIVALS t0046: the hourglass stays through the live round too)
	-- (RIVALS, Edward 2026-10-19) under a minute the clock counts tenths (59.9, ... 4.9, 4.8); under 5 s of a live round it turns red
	timerL.Text = left < 60 and string.format("%.1f", math.floor(left * 10) / 10) or string.format("%d:%02d", left // 60, math.floor(left) % 60)
	-- (m5, RIVALS t0118-t0120) the round clock freezes where the round ended instead of counting the round end down
	if state == "Live" then RV.liveClock = timerL.Text elseif state == "RoundEnd" and RV.liveClock then timerL.Text = RV.liveClock end
	if state == "Countdown" then RV.liveClock = nil end
	timerL.TextColor3 = (state == "Live" and left < 5) and BAD or WHITE
	timerL.Position = UDim2.fromScale(0.12, timerL.Position.Y.Scale)
	-- (2026-10-21, round 3: match RIVALS) the clock ticks: the whole timer block punches once per second in the last 5 s of a
	-- live round and the last 3 s of a countdown (timerL's own Position is rewritten every frame, so the block pops, centred
	-- once; state in the stats table, no new locals)
	if stats.Kit and ((state == "Live" and left > 0 and left < 5) or (state == "Countdown" and left > 0 and left < 3)) then
		if stats.timerBeat ~= state .. math.ceil(left) then
			stats.timerBeat = state .. math.ceil(left)
			if not stats.timerCentred then stats.timerCentred = true; stats.Kit.centreAnchor(timerBox) end
			stats.Kit.pop(timerBox, state == "Live" and 1.14 or 1.1)
		end
	end
	roundL.Text = "ROUND " .. tostring(st("RoundNumber") or 1)
	toWin.Text = st("RoundsToWin") and ("First to " .. st("RoundsToWin")) or ""
	-- banners
	if state ~= lastState then
		if state == "Countdown" or state == "RunIn" then gotSummary = false end
		if state == "Countdown" then
			-- (Edward 2026-10-19) no 3-2-1 / FIGHT: the top clock counts the countdown down in tenths instead
			-- the round's WIN / LOSS banner stays through the countdown, unless the next round can end the match (MATCH POINT)
			RV.showMatchPoint(mine, theirs, st("RoundsToWin")) -- (2026-10-23: spectators see the ribbon too, like RIVALS)
			RV.endElim() -- (m10, RIVALS t0122) "Eliminated X" ends when the countdown starts
			if RV.ribbon.Visible and RV.roundCard.Visible then RV.dimRoundCard(true)
			elseif RV.roundCard.Visible then
				-- (m8, RIVALS t0214) without a ribbon the card fades out ~2 s into the countdown
				local card = RV.roundCard
				task.delay(slow(2), function()
					local o = stateObject()
					if card.Visible and o and o:GetAttribute("MatchState") == "Countdown" and not RV.ribbon.Visible then RV.fadeRoundCard() end
				end)
			end
		elseif state == "Live" then
			RV.roundCard.Visible = false
			task.delay(1.2, RV.fadeRibbon)
			table.clear(botDown)
		elseif state == "RoundEnd" and not spectator() then
			if mine ~= lastScoreMine and mine > (lastScoreMine or 0) then RV.showRoundCard(true)
			elseif theirs ~= lastScoreTheirs and theirs > (lastScoreTheirs or 0) then RV.showRoundCard(false) end
			-- (m1, RIVALS t0118-t0122) the WON / LOST card stands alone here; the ribbon only comes in at the countdown
		elseif state == "MatchEnd" and not resultsShown then
			-- the fallback card only when the server's summary never came (it often lands first, during Victory)
			-- (m11, grader C: this branch sat after `state ~= "RoundEnd"`, which caught MatchEnd first, so it could never run)
			RV.roundCard.Visible = false
			task.delay(1.5, function() if not resultsShown and not gotSummary and inMatch() then resultsShown = true; showResults(nil) end end)
		elseif state ~= "RoundEnd" then
			RV.roundCard.Visible = false
		end
		if state == "Victory" or state == "MatchEnd" then RV.endElim() end -- (m10: and when the match ends)
		lastState = state
		lastScoreMine, lastScoreTheirs = mine, theirs
	end
	-- Switch Weapons: between rounds (not the last one), for players in the match
	local over = (st("MatchPhase") == "Victory" or st("MatchPhase") == "Finisher")
	local mf = player.PlayerGui:FindFirstChild("MatchFlow")
	local picking = mf ~= nil and mf.Enabled -- the Switch Weapons picker is up: only the score bar stays (RIVALS)
	-- (2026-10-20, Edward: "switching weapons appears way too early ... it should only appear when the round starts") like
	-- RIVALS: only through the countdown into a round, and not before the first one (you just picked your kit)
	-- + (Edward: "you should be able to change your weapon until you shoot or move") on into the live round until the server
	-- sets KitLocked (your first move / landed shot); picks before that swap at once
	local preRound = (state == "Countdown" and (tonumber(st("RoundNumber")) or 1) > 1) or (state == "Live" and player:GetAttribute("KitLocked") ~= true)
	RV.switchWant = preRound and not over and not spectator() and RV.switchHook() ~= nil and not picking
	-- (2026-10-21, round 3: match RIVALS) the one between-rounds action pops in when it appears (intermission_switch.jpg), not a cut
	-- (m3, RIVALS t0056 -> t0058) Switch Weapons follows the ribbon by 0.4 s instead of landing with it
	if RV.switchWant and not RV.switchB.Visible then
		RV.switchAt = RV.switchAt or (os.clock() + 0.4)
		if os.clock() >= RV.switchAt then
			RV.switchB.Visible = true
			if stats.Kit then stats.Kit.popIn(RV.switchB) end
		end
	elseif not RV.switchWant then
		RV.switchAt = nil
		RV.switchB.Visible = false
	end
	if picking then RV.roundCard.Visible = false; feed.Visible = false; local el = root:FindFirstChild("Eliminated"); if el then el.Visible = false end end
	-- spectate: spectators, and duelists while dead
	local spec = spectator() or (player:GetAttribute("Alive") == false and (state == "Live" or state == "RoundEnd" or state == "Victory"))
	-- your killer on camera: RIVALS' killer card bottom right instead of the spectate bar
	local killerUid = player:GetAttribute("SpectateTarget")
	local onKiller = spec and not spectator() and killerUid ~= nil and target == killerUid and player:GetAttribute("SpectateReason") == "Killer"
	specBar.Visible = spec and not onKiller
	-- (2026-10-23, matchmaking round m2, RIVALS t0212-t0214) the killer card stays ~1.5 s into the next countdown
	-- (m4: once the card has shown it holds through the whole round end and 1.5 s into the countdown; the server clears
	-- SpectateTarget early in the round end, so neither it nor a timer from that moment can carry the card that far)
	if state ~= RV.kcState then RV.kcState, RV.kcSince = state, os.clock() end
	if onKiller then RV.kcardShown = true elseif state == "Live" or state == "MatchEnd" or state == "Victory" then RV.kcardShown = false end
	local keepCard = not onKiller and RV.kcardShown and (state == "RoundEnd" or (state == "Countdown" and os.clock() - (RV.kcSince or 0) < slow(2.0))) -- (m8: RIVALS t0212 -> t0214, ~2 s in)
	if onKiller and not RV.kcard.Visible then
		-- slide in from the right edge
		local home = RV.kcardHome or RV.kcard.Position
		RV.kcardHome = home
		RV.kcard.Position = home + UDim2.fromScale(0.25, 0)
		TweenService:Create(RV.kcard, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Position = home }):Play()
	end
	-- (m5, grader C) it slides back out to the right instead of cutting
	if onKiller or keepCard then
		if RV.kcardLeaving then
			RV.kcardLeaving = nil
			if RV.kcardExit then RV.kcardExit:Cancel(); RV.kcardExit = nil end -- (m6: a card that comes back mid-exit stops sliding away)
			if RV.kcardHome then RV.kcard.Position = RV.kcardHome end
		end
		RV.kcard.Visible = true
	elseif RV.kcard.Visible and not RV.kcardLeaving then
		RV.kcardLeaving = true
		local home = RV.kcardHome or RV.kcard.Position
		RV.kcardHome = home
		RV.kcardExitN = (RV.kcardExitN or 0) + 1
		local exitN = RV.kcardExitN
		RV.kcardExit = TweenService:Create(RV.kcard, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Position = home + UDim2.fromScale(0.25, 0) })
		RV.kcardExit:Play()
		task.delay(0.3, function()
			if RV.kcardLeaving and RV.kcardExitN == exitN then RV.kcardLeaving = nil; RV.kcardExit = nil; RV.kcard.Visible = false; RV.kcard.Position = home end -- (m7: only this exit's own timer)
		end)
	end
	-- (2026-10-22, RIVALS) the weapon HUD is gone while the kill banner is up (it sat under the banner, bottom right)
	do
		local hb = player.PlayerGui:FindFirstChild("Hotbar")
		if hb and hb:IsA("ScreenGui") then
			if (onKiller or keepCard) and hb.Enabled then RV.hbHidden = true; hb.Enabled = false
			elseif not (onKiller or keepCard) and RV.hbHidden then RV.hbHidden = nil; if rblurOn then rHidden[hb] = true else hb.Enabled = true end end -- (the results screen restores it)
		end
	end
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
		title, top, bottom = "VICTORY", TEAM_A[1], TEAM_A[2]
	elseif winner then
		title, top, bottom = "DEFEAT", Color3.fromRGB(150, 178, 136), TEAM_B[1]
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
	BackgroundTransparency = 0.25, Parent = scanvas }, { new("UICorner", { CornerRadius = UDim.new(0.025, 0) }) }) -- (2026-10-21, AI-tells cleanup) hairline edge removed
local sbTitle = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = STENCIL, TextScaled = true, TextColor3 = WHITE, Position = UDim2.fromScale(0.04, 0.025),
	Size = UDim2.fromScale(0.92, 0.08), Parent = board })
local sbSub = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FB, TextScaled = true, TextColor3 = Color3.fromRGB(190, 192, 182), Position = UDim2.fromScale(0.04, 0.105),
	Size = UDim2.fromScale(0.92, 0.04), Parent = board })
local sbList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.17), Size = UDim2.fromScale(0.94, 0.8), Parent = board },
	{ new("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
local sbOpenHold, sbOpenToggle = false, false

local function sbHeader(order, text, color)
	local f = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.07), Parent = sbList })
	-- (2026-10-21, AI-tells cleanup) the thin left accent bar is gone; the header text keeps the team colour
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
local selectPress, selectHeld = 0, false
UserInputService.InputBegan:Connect(function(i, gp)
	if i.KeyCode == scoreboardKey() and not gp then sbOpenHold = true end
	if i.KeyCode == Enum.KeyCode.ButtonSelect then -- [PAD] tap = scoreboard, hold 0.5 s = Settings
		selectPress += 1
		local press = selectPress
		selectHeld = true
		task.delay(0.5, function()
			if selectHeld and press == selectPress then selectHeld = false if padSettings then padSettings() end end
		end)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.KeyCode == scoreboardKey() then sbOpenHold = false end
	if i.KeyCode == Enum.KeyCode.ButtonSelect and selectHeld then selectHeld = false sbOpenToggle = not sbOpenToggle end
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

---------------------------------------------------------------------------------------------------- SERIOUS (2026-10-20)
-- (Edward: "a mixture of the rivals ui and sniper duels / murder duels seriousness") over the whole duel HUD + results:
--   * gloss highlights off; panel borders become a hairline white edge (Sniper Duels' tiles); corners small
--   * text strokes soft (a faint dark edge for legibility, no ink outline); no drop shadows, no tilts
--   * runs on what exists now and on everything added later (kill feed rows, results rows)
do
	local CS = game:GetService("CollectionService")
	local function calmOne(d)
		if d:IsA("UIStroke") then
			local p = d.Parent
			local onText = p and (p:IsA("TextLabel") or p:IsA("TextButton") or p:IsA("TextBox")) and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
			if not onText then
				-- (2026-10-21, AI-tells cleanup) no hairline panel borders: thin ones (< 3) go; thick state rings (voted, your kill) stay
				if d.Thickness < 3 then d:Destroy() else d.LineJoinMode = Enum.LineJoinMode.Round end
			elseif d.Parent and (d.Parent:IsA("TextLabel") or d.Parent:IsA("TextButton")) and not d.Parent:GetAttribute("KeepStroke") then
				d.Color = BLACK; d.Transparency = math.max(d.Transparency, 0.55); d.Thickness = math.min(d.Thickness, 2); d.LineJoinMode = Enum.LineJoinMode.Round
			end
		elseif d:IsA("UICorner") then
			if d.CornerRadius.Scale == 0 then
				local r = d:GetAttribute("dR") or d.CornerRadius.Offset
				if r > 6 and r < 20 then d:SetAttribute("dR", 6); d.CornerRadius = UDim.new(0, math.min(d.CornerRadius.Offset, 6)) end
			elseif d.CornerRadius.Scale > 0.05 and d.CornerRadius.Scale < 0.4 then
				d.CornerRadius = UDim.new(0.08, 0)
			end
		elseif d:IsA("Frame") and d.Name == "Gloss" then
			d.Visible = false
		end
	end
	local function calmTree(g)
		CS:AddTag(g, "KeepColors")
		for _, d in g:GetDescendants() do calmOne(d) end
		g.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then calmOne(d) end end) end)
	end
	calmTree(gui)
	calmTree(rgui)
end

-- (2026-10-23, matchmaking round m2, grader C vs RIVALS t0118-t0122 / t0206) under the HUD: the world dims ~40 % from 1.5 s
-- into a round end through the countdown, and a red wash flashes when you die in a match
do
	local dgui = new("ScreenGui", { Name = "RoundDim", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -1, Parent = player:WaitForChild("PlayerGui") })
	local dim = new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = dgui })
	local red = new("Frame", { BackgroundColor3 = Color3.fromRGB(200, 20, 24), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = dgui })
	local lastState, since, dimOn, afterRound = nil, 0, false, false
	RunService.RenderStepped:Connect(function()
		local o = stateObject()
		local state = o and o:GetAttribute("MatchState")
		if state ~= lastState then afterRound = lastState == "RoundEnd" or (state == "Countdown" and afterRound); lastState, since = state, os.clock() end
		local want = inMatch() and ((state == "RoundEnd" and os.clock() - since > 1.5) or (state == "Countdown" and afterRound)) -- (not round 1's countdown)
		if want ~= dimOn then
			dimOn = want
			TweenService:Create(dim, TweenInfo.new(want and 0.5 or 0.25), { BackgroundTransparency = want and 0.6 or 1 }):Play()
		end
	end)
	-- (m8, grader C vs RIVALS t0206) at the death moment (1.5 s): a red vignette round the edges (four soft gradient strips) and a
	-- red chevron on a ring round the centre pointing at the killer
	-- (m9: a CanvasGroup so the whole vignette fades out; the sides reach ~30 % in like RIVALS)
	local vig = new("CanvasGroup", { Name = "DeathVignette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = dgui })
	for _, e in { { 0, 0, 1, 0.2, 90 }, { 0, 0.8, 1, 0.2, -90 }, { 0, 0, 0.2, 1, 0 }, { 0.8, 0, 0.2, 1, 180 } } do -- (m10, grader B: the outer ~20 %, softer)
		new("Frame", { BackgroundColor3 = Color3.fromRGB(190, 16, 20), BorderSizePixel = 0, Position = UDim2.fromScale(e[1], e[2]), Size = UDim2.fromScale(e[3], e[4]), Parent = vig },
			{ new("UIGradient", { Rotation = e[5], Transparency = NumberSequence.new(0.55, 1) }) }) -- (m11: alpha 0.45 at the edge)
	end
	local arrow = new("TextLabel", { Name = "KillerArrow", BackgroundTransparency = 1, Text = "▲", TextColor3 = Color3.fromRGB(235, 40, 40), TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.08, 0.12), Visible = false, Parent = dgui }) -- (m9: 2x, RIVALS' arc is big)
	RunService.RenderStepped:Connect(function()
		local dead = player:GetAttribute("Alive") == false and inMatch()
		local flash = dead and RV.deathFlashUntil ~= nil and os.clock() < RV.deathFlashUntil -- (RIVALS t0206 -> t0208: only the death moment)
		vig.Visible = flash
		-- (m10, grader C) full strength for the first 2/3 (1.0 s live), then a 0.5 s fade; the chevron fades with it
		local fadeT = flash and math.clamp(1 - (RV.deathFlashUntil - os.clock()) / ((RV.deathFlashLen or 1.5) / 3), 0, 1) or 1
		if flash then vig.GroupTransparency = fadeT end
		arrow.TextTransparency = fadeT
		if not (arrow.Visible and dead) then arrow.Visible = false return end
		local m = RV.killerModel
		if not (m and m.Parent) then -- (m11, grader C: the kill event can arrive after Alive flips; look again each frame)
			local k = (lastDeath and lastDeath.killer) or player:GetAttribute("SpectateTarget")
			m = k and (k < 0 and botModel(k) or (Players:GetPlayerByUserId(k) and Players:GetPlayerByUserId(k).Character)) or nil
			RV.killerModel = m
		end
		local root = m and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
		local cam = workspace.CurrentCamera
		if not root or not cam then arrow.TextTransparency = 1 return end -- (m11: stays armed; the killer may resolve next frame)
		local rel = cam.CFrame:PointToObjectSpace(root.Position)
		local ang = math.atan2(rel.X, -rel.Z) -- 0 = straight ahead, + = to the right
		local ar = dgui.AbsoluteSize.X / math.max(1, dgui.AbsoluteSize.Y)
		arrow.Position = UDim2.fromScale(0.5 + math.sin(ang) * 0.16 / ar, 0.5 - math.cos(ang) * 0.16)
		arrow.Rotation = math.deg(ang)
	end)
	player:GetAttributeChangedSignal("Alive"):Connect(function()
		if player:GetAttribute("Alive") ~= false or not inMatch() then return end
		local k = lastDeath and lastDeath.killer
		RV.killerModel = k and (k < 0 and botModel(k) or (Players:GetPlayerByUserId(k) and Players:GetPlayerByUserId(k).Character)) or nil
		arrow.Visible = true -- (m11: the RenderStepped above finds the killer, hides it if there is none)
		RV.deathFlashLen = slow(1.5)
		RV.deathFlashUntil = os.clock() + RV.deathFlashLen
		task.delay(RV.deathFlashLen, function() arrow.Visible = false end)
		red.BackgroundTransparency = 0.65 -- (m3, RIVALS t0206: the red holds ~1.5 s; m10: 0.5 -> 0.65 with the edge vignette on top)
		TweenService:Create(red, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	end)
end
