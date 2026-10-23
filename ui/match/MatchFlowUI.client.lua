-- MatchFlowUI (match place AND lobby, StarterPlayerScripts, LocalScript): RIVALS' match hand-off in TACTICALS (UI session 2026-10-16).
--   Loading  : dark screen, TACTICALS wordmark, a tip in a white bubble, "Loading" + a counter.
--   MapVote  : the two team boxes up top (headshots, level badges), a timer between them; map tiles below (big, coloured
--              edge, striped name bar). Click to vote: your headshot sits on the tile, white edge; everyone's votes show.
--              The winning map flashes when the vote ends. With one map: Warehouse + Random.
--   Loadout  : the same team boxes + timer; your three slots (Gun / Melee / Gadget) as big 3D cards. Click a slot to open
--              what you own for it underneath; pick one. READY ends it early for you.
-- Driven only by server state (names in STATE below); sends MatchFlow:FireServer("Vote", id) / ("Pick", slot, id) / ("Ready").
-- Self-contained (no UIKit): built in 1920x1080 design px on a 16:9 canvas, converted to Scale at the end (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local localPlayer = player
-- (2026-10-21, RIVALS pass) the shared motion helpers (UIKit.Kit: open / close / bindButton / pop / pulse / loadingDots).
-- pcall'd: if UIKit is missing the screens still work, just without the motion.
local okKit, Kit = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit", 10):WaitForChild("Kit", 10)) end)
if not okKit or type(Kit) ~= "table" then Kit = nil end
local STATE = { -- attribute names (agreed with the Tacticals session)
	Phase = "MatchPhase", EndsAt = "PhaseEndsAt", Maps = "MapList", Votes = "MapVotes", Chosen = "MapChosen",
	Team = "Team", Level = "Level", Owned = "OwnedItems", Kit = { Weapon = "KitWeapon", Melee = "KitMelee", Gadget = "KitGadget" },
}
-- Where the match state lives: the match place keeps it on ReplicatedStorage; the lobby runs several duels at once, each on
-- ReplicatedStorage.LobbyDuels.<matchId> (the player's DuelMatch attribute). The MatchFlow remote then also carries matchId.
local function stateObject()
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	if id then
		local folder = ReplicatedStorage:FindFirstChild("LobbyDuels")
		return folder and folder:FindFirstChild(tostring(id)), id
	end
	return ReplicatedStorage, nil
end
local function st(name)
	local o = stateObject()
	return o and o:GetAttribute(name)
end
local function send(...)
	local ev = ReplicatedStorage:FindFirstChild("MatchFlow")
	if not ev then return end
	local _, id = stateObject()
	if id then ev:FireServer(id, ...) else ev:FireServer(...) end
end
local SLOTS = { { id = "Weapon", label = "Gun" }, { id = "Melee", label = "Melee" }, { id = "Gadget", label = "Gadget" } }
local TIPS = { "Peek from cover: you're only exposed while you aim", "Throw a smoke to cross open ground", "Gun bash is lethal from behind",
	"Headshots end duels fast", "Scissors unlock new gear in the Kit room" }

local W, H = 1920, 1080
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
-- (2026-10-21, AI-tells cleanup) the literal comic yellow is out: field green (Theme.color.field); selected states are field green / cream
local OLIVE, OLIVE_HI = Color3.fromRGB(141, 191, 90), Color3.fromRGB(141, 191, 90)
local FIELD = OLIVE
local TEAM_A = { Color3.fromRGB(233, 220, 188), Color3.fromRGB(191, 165, 122) }  -- (2026-10-20, Edward: "serious", like the old bone/olive but better) us: warm beige
local TEAM_B = { Color3.fromRGB(110, 140, 98), Color3.fromRGB(47, 74, 55) }     -- them: muted dark green
-- (2026-10-20, the RIVALS mix) the muted fills RIVALS-style boxes use (same as DuelHUD)
TEAM_A.fill = { Color3.fromRGB(201, 168, 105), Color3.fromRGB(110, 86, 49) } -- (2026-10-22, colour study: RIVALS' team fills fall ~60 % top to bottom; same tan, deeper ramp)
TEAM_B.fill = { Color3.fromRGB(78, 138, 90), Color3.fromRGB(31, 58, 39) } -- (2026-10-22, colour study: same dark green, deeper ramp)
-- (2026-10-20, Edward: "a mixture of the rivals ui and sniper duels / murder duels seriousness") RIVALS' layout and see-through
-- panels, calmer: Montserrat Heavy headlines, Builder Sans body, hairline white edges, no tilts or drop shadows; "selected"
-- is a warm white; team colours (beige / green) only as accents
-- (2026-10-21, RIVALS pass) Edward's final font decision: headings / big words / numbers in Oswald Bold (was Montserrat Heavy),
-- small / body text in Rubik (FR). (2026-10-21, AI-tells cleanup) FB is Rubik Bold now (was Builder Sans).
local FX = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local FR = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold)
local FB = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local STENCIL = FX
local INK_YELLOW = Color3.fromRGB(236, 230, 210) -- (serious pass) selected: warm white, not comic yellow ((2026-10-21, AI-tells cleanup) = cream #ECE6D2)
local PANEL_T = 0.35 -- RIVALS-style see-through

local function new(class, props, kids)
	local o = Instance.new(class)
	for k, v in props or {} do if k ~= "Parent" then o[k] = v end end
	for _, k in kids or {} do k.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function label(parent, text, font, size, x, y, w, h, color, align, z)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = font, TextSize = size, TextColor3 = color or WHITE,
		TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3, Parent = parent })
	l:SetAttribute("dTS", size)
	new("UIStroke", { Thickness = math.max(1, size / 30), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end
-- ink (serious pass, 2026-10-20): was a hairline white edge (Sniper Duels' tiles). (2026-10-21, AI-tells cleanup) the hairline
-- UIStroke is gone (corner + thin stroke read as AI-made); the fills alone separate the boxes. The old drop-shadow sibling
-- is still made (callers hold it) but it draws nothing.
local function ink(target, off, thick)
	local r = target:FindFirstChildOfClass("UICorner")
	local sh = new("Frame", { Name = target.Name .. "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = target.Position + UDim2.fromOffset(off or 8, off or 8), Size = target.Size, Rotation = target.Rotation,
		ZIndex = math.max(0, target.ZIndex - 1), Visible = target.Visible, Parent = target.Parent }, r and { corner(r.CornerRadius.Offset) } or nil)
	target:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = target.Visible end)
	return sh
end

-- Offset -> Scale for a subtree (sizes / positions from design px); text sizes follow the canvas
local textNodes = {}
local function toScale(g, pd)
	for _, c in g:GetChildren() do
		if c:IsA("GuiObject") then
			local w = c.Size.X.Scale * pd.X + c.Size.X.Offset
			local h = c.Size.Y.Scale * pd.Y + c.Size.Y.Offset
			local x = c.Position.X.Scale * pd.X + c.Position.X.Offset
			local y = c.Position.Y.Scale * pd.Y + c.Position.Y.Offset
			c.Size = UDim2.fromScale(pd.X > 0 and w / pd.X or 0, pd.Y > 0 and h / pd.Y or 0)
			c.Position = UDim2.fromScale(pd.X > 0 and x / pd.X or 0, pd.Y > 0 and y / pd.Y or 0)
			if c:GetAttribute("dTS") then table.insert(textNodes, c) end
			toScale(c, Vector2.new(w, h))
		elseif c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0, c.CornerRadius.Offset) -- radius scales with the factor below
			c:SetAttribute("dR", c:GetAttribute("dR") or c.CornerRadius.Offset)
			table.insert(textNodes, c)
		end
	end
end

local gui = new("ScreenGui", { Name = "MatchFlow", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 30,
	Enabled = false, Parent = player:WaitForChild("PlayerGui") })
game:GetService("CollectionService"):AddTag(gui, "KeepColors") -- (UIStyleController would turn the comic yellow neutral)
local back = new("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = gui },
	{ new("UIGradient", { Rotation = 35, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 12, 10)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(26, 30, 24)), ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 12)) }) }) })
local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1), Parent = gui }, { new("UIAspectRatioConstraint", { AspectRatio = W / H }) })
local function factor() return canvas.AbsoluteSize.Y / H end
local function rescale()
	local f = factor()
	for _, n in textNodes do
		if n.Parent then
			if n:IsA("UICorner") then n.CornerRadius = UDim.new(0, (n:GetAttribute("dR") or 6) * f)
			else n.TextSize = math.max(1, math.floor(n:GetAttribute("dTS") * f + 0.5)) end
		end
	end
end
canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

---------------------------------------------------------------------------------------------------- 1. Loading
local loading = new("Frame", { Name = "Loading", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
-- (2026-10-20, Edward: "should utilize our logo") the real TACTICALS logo instead of the plain wordmark (UIKit.Logo)
local okLogo, LogoMod = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Logo", 10)) end)
if okLogo and LogoMod then
	LogoMod.Breathe(LogoMod.Build(loading, { Position = UDim2.fromOffset(960, 400), Size = UDim2.fromOffset(980, 331), ZIndex = 3 }))
else
	label(loading, "TACTICALS", STENCIL, 170, 360, 300, 1200, 200, WHITE)
end
local bubble = new("Frame", { Position = UDim2.fromOffset(120, 950), Size = UDim2.fromOffset(640, 60), BackgroundColor3 = WHITE, Parent = loading }, { corner(10) })
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(40, 60), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bubble })
local tipL = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FB, TextSize = 26, TextColor3 = Color3.fromRGB(20, 20, 24), Size = UDim2.fromScale(1, 1), Parent = bubble })
tipL:SetAttribute("dTS", 26)
-- (2026-10-21, RIVALS pass) honest loading: the fake 0-99 counter is gone. Plain words say what we wait for, and RIVALS'
-- three dots (Kit.loadingDots) sit under them. Rubik (the body font).
local loadWords = label(loading, "Waiting for opponent", FR, 46, 1100, 920, 720, 56, WHITE, Enum.TextXAlignment.Right)
local loadN = label(loading, "", FB, 40, 1440, 976, 380, 50, Color3.fromRGB(205, 205, 212), Enum.TextXAlignment.Right)
loadN.Visible = false -- kept (unused) so nothing else breaks; the dots replace it
if Kit and Kit.loadingDots then
	local dots = Kit.loadingDots(loading)
	dots.AnchorPoint = Vector2.new(1, 0.5)
	dots.Position = UDim2.fromScale(1820 / W, 1004 / H)
	dots.Size = UDim2.fromScale(150 / W, 40 / H)
	dots.ZIndex = 3
	for _, d in dots:GetChildren() do if d:IsA("GuiObject") then d.ZIndex = 3 end end
end

---------------------------------------------------------------------------------------------------- shared: team boxes + timer
local function teamBox(parent, x, cols, right)
	-- (2026-10-20, the RIVALS mix) RIVALS' box filled with the side's muted colour (tan ours, dark green theirs)
	local b = new("Frame", { Position = UDim2.fromOffset(x, 34), Size = UDim2.fromOffset(290, 84), BackgroundColor3 = WHITE, BackgroundTransparency = 0.08,
		ZIndex = 2, Parent = parent }, { corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols.fill[1], cols.fill[2]) }) })
	ink(b, 7, 4)
	local slots = {}
	for i = 1, 3 do
		local hx = right and (75 + (i - 1) * 64) or (14 + (i - 1) * 64) -- (m10: the 139 px plate fits digit + head)
		local h = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(hx, 14), Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 3, Parent = b }, { corner(28) })
		local lv = new("Frame", { Position = UDim2.fromOffset(hx - 8, 50), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = Color3.fromRGB(20, 18, 24), Visible = false, ZIndex = 4, Parent = b }, { corner(7) })
		local ll = label(lv, "", FX, 17, 0, 0, 30, 26, WHITE, nil, 5)
		slots[i] = { h = h, lv = lv, ll = ll }
		h:SetAttribute("dx", hx); h:SetAttribute("dw", 56)
		lv:SetAttribute("dx", hx - 8); lv:SetAttribute("dw", 30)
	end
	-- (2026-10-23, matchmaking round m3, RIVALS t0028) the side's score digit, and the plate hugs its heads (see fitBoxes)
	local score = label(b, "0", FX, 50, 0, 6, 70, 72, WHITE, nil, 3)
	score:SetAttribute("dw", 62)
	slots.frame, slots.score, slots.right, slots.x = b, score, right, x
	return slots
end
-- a plate is 96 + 64 per head wide (the 290 design px fit three); the ours plate keeps its right edge by the timer, theirs its
-- left edge. Runs after toScale, so children are re-placed from the design px kept in their dx / dw attributes.
local function fitBox(slots, n)
	local b = slots.frame
	local w = 75 + 64 * math.max(1, n) -- (m10: 139 px for one head, as the match HUD)
	local x0 = slots.right and 1063 or (857 - w) -- (m5: 31 px gaps to the 888-1032 timer, as the match HUD)
	b.Position = UDim2.new(x0 / W, 0, 11 / H, 0) -- (m10: the bar's top at y 11 = 1 %, as the match HUD)
	b.Size = UDim2.new(w / W, 0, b.Size.Y.Scale, 0)
	for _, c in b:GetChildren() do
		local dx, dw = c:GetAttribute("dx"), c:GetAttribute("dw")
		if c == slots.score then dx = slots.right and 10 or (w - 70) end
		if dx and dw then
			c.Position = UDim2.new(dx / w, 0, c.Position.Y.Scale, 0)
			c.Size = UDim2.new(dw / w, 0, c.Size.Y.Scale, 0)
		end
	end
end
-- (2026-10-23, matchmaking round m1, RIVALS t0026-t0032) the vote clock carries the match HUD's drawn hourglass left of the
-- digits, and both go red at 0.0
local TIMER_RED = Color3.fromRGB(235, 64, 64)
local function timerBox(parent, glass)
	local t = new("Frame", { Position = UDim2.fromOffset(888, 11), Size = UDim2.fromOffset(144, 76), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, ZIndex = 2, Parent = parent }, { corner(6) }) -- (m10: y 34 -> 11 with the plates)
	ink(t, 7, 4)
	if not glass then return label(t, "10.0", FX, 42, 0, 0, 144, 76, WHITE) end
	local hg = new("Frame", { Name = "Hourglass", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 20), Size = UDim2.fromOffset(24, 36), ZIndex = 3, Parent = t })
	new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(24, 5), ZIndex = 3, Parent = hg }, { corner(2) })
	new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(24, 5), ZIndex = 3, Parent = hg }, { corner(2) })
	for _, rot in { 28, -28 } do
		new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 18), Size = UDim2.fromOffset(4, 32), Rotation = rot, ZIndex = 3, Parent = hg })
	end
	return label(t, "10.0", FX, 42, 40, 0, 96, 76, WHITE)
end
local function tintTimer(l, red)
	local col = red and TIMER_RED or WHITE
	if l.TextColor3 == col then return end
	l.TextColor3 = col
	local hg = l.Parent:FindFirstChild("Hourglass")
	if hg then for _, f in hg:GetDescendants() do if f:IsA("Frame") then f.BackgroundColor3 = col end end end
end
local heads = {}
local function teamList(key)
	local ok, ids = pcall(function() return HttpService:JSONDecode(st(key) or "") end)
	if not ok or type(ids) ~= "table" then return nil end
	local out = {}
	for _, uid in ids do
		local p = Players:GetPlayerByUserId(uid)
		table.insert(out, { UserId = uid, player = p, gone = p == nil and uid > 0, bot = uid < 0 })
	end
	return out
end
local function fillTeams(boxes)
	local mine = player:GetAttribute(STATE.Team) or "A"
	local teams = { A = teamList("TeamA"), B = teamList("TeamB") }
	if not teams.A or not teams.B then -- before TeamA/TeamB exist: scan players
		teams = { A = {}, B = {} }
		for _, p in Players:GetPlayers() do
			local t = p:GetAttribute(STATE.Team) or "A"
			table.insert(teams[t] or teams.A, { UserId = p.UserId, player = p })
		end
	end
	local left = teams[mine] or teams.A
	local right = mine == "A" and teams.B or teams.A
	for side, list in { [1] = left, [2] = right } do
		for i = 1, 3 do
			local s = boxes[side][i]
			local p = list[i]
			s.h.Visible = p ~= nil; s.lv.Visible = p ~= nil
			if p then
				local pl = p.player
				local lv = pl and pl:GetAttribute(STATE.Level) or nil
				local ready = pl and pl:GetAttribute("LoadoutReady") == true
				-- (2026-10-20, Edward) the ONE icon rule (UIKit.Badges.Icon): streak flame, else rank emblem (Rank mode), else level
				local kind, v = "level", lv
				if pl and not ready then
					local okB, B = pcall(function() return require(ReplicatedStorage.UIKit.Badges) end)
					if okB and B then kind, v = B.Icon(pl) end
				end
				local icon = s.lv:FindFirstChild("Icon") or new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), ZIndex = 4, Parent = s.lv })
				local isImg = kind == "streak" or kind == "rank" or (kind == "level" and pl ~= nil and not ready)
				if kind == "level" and isImg then -- (2026-10-20) our tiered level shield
					local K = require(ReplicatedStorage.UIKit.Kit)
					if K.levelTier then icon.Image, icon.ImageColor3 = K.levelTier(v), Color3.new(1, 1, 1) else isImg = false end
				elseif isImg then
					local K = require(ReplicatedStorage.UIKit.Kit)
					local img, tint = K.ICONS.streak, Color3.fromRGB(255, 140, 40)
					if K.streakImage then img, tint = K.streakImage() end
					if kind == "rank" then img, tint = v, Color3.new(1, 1, 1) end
					icon.Image, icon.ImageColor3 = img, tint
				end
				icon.Visible = isImg
				-- (2026-10-22, Edward: level numbers like RIVALS) over the seal: the chunky white number with the deep-blue edge
				local Kl = require(ReplicatedStorage.UIKit.Kit)
				local lst = s.ll:FindFirstChildOfClass("UIStroke")
				if kind == "level" and isImg and Kl.levelNumber then Kl.levelNumber(s.ll)
				elseif lst then lst.Color = Color3.new(0, 0, 0) end
				s.ll.Text = ready and "✓" or (p.bot and "BOT" or (kind == "rank" and "" or tostring(v or "-")))
				s.ll.ZIndex = 6
				s.lv.BackgroundTransparency = isImg and 1 or 0
				s.lv.BackgroundColor3 = ready and Color3.fromRGB(90, 178, 255) or Color3.fromRGB(20, 18, 24)
				s.h.ImageTransparency = p.gone and 0.6 or 0
				if p.bot then s.h.Image = ""
				elseif heads[p.UserId] then s.h.Image = heads[p.UserId]
				else task.spawn(function()
					local ok, im = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
					if ok then heads[p.UserId] = im; s.h.Image = im end
				end) end
			end
		end
		fitBox(boxes[side], #list) -- (m3) the plate hugs its heads
	end
end

---------------------------------------------------------------------------------------------------- 2. Map vote
local vote = new("Frame", { Name = "MapVote", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
local voteBoxes = { teamBox(vote, 588, TEAM_A, false), teamBox(vote, 1042, TEAM_B, true) }
local voteTimer = timerBox(vote, true)
-- (2026-10-22, live RIVALS map vote) no title; the map cards are one big row right under the team boxes (top at 11 % of the
-- height, 12.8-87.2 % of the width, ~24.4 % wide each, 8 px apart), like RIVALS' three featured maps
local mapHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(250, 95), Size = UDim2.fromOffset(1420, 760), Parent = vote })
local MAP_GAP = 8
local STRIPE_TOP, STRIPE_BOTTOM = Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46) -- field green: the name strip + the card edge
local mapTiles = {}
-- (2026-10-21, round 3: match RIVALS) every 3D picture on these screens is live: map renders turn slowly on a camera orbit,
-- item renders sway and spin round when hovered (RIVALS' item tiles are posed renders; ours are real models, so they move).
-- vpf -> { cam, c (centre), r (orbit radius), h (height), a (angle), map = true | holder (item: spins on Hover) }
local live3D = setmetatable({}, { __mode = "k" })

-- (2026-10-21, round 3: match RIVALS) RIVALS' map vote shows a picture of every map. A map with no uploaded picture AND no
-- model in this place (DuelMaps / Workspace) used to be an empty black tile: now a small arena built from Parts stands in
-- (floor, low walls, crates, a tower, a tan and a green spawn pad), laid out from the map id so each map looks different.
local function miniArena(id)
	local m = Instance.new("WorldModel")
	local seed = 0
	for i = 1, #id do seed = (seed * 31 + string.byte(id, i)) % 2147483647 end
	local rng = Random.new(seed)
	local function part(size, pos, col, mat, rot)
		local q = Instance.new("Part")
		q.Anchored = true
		q.Size = size
		q.CFrame = CFrame.new(pos) * (rot or CFrame.identity)
		q.Color = col
		q.Material = mat or Enum.Material.SmoothPlastic
		q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		q.Parent = m
		return q
	end
	local floors = { Color3.fromRGB(150, 146, 132), Color3.fromRGB(118, 128, 104), Color3.fromRGB(160, 150, 120) }
	part(Vector3.new(60, 1, 44), Vector3.new(0, -0.5, 0), floors[rng:NextInteger(1, #floors)], Enum.Material.Concrete)
	local wall = Color3.fromRGB(196, 190, 172)
	part(Vector3.new(60, 6, 1.5), Vector3.new(0, 3, -22), wall)
	part(Vector3.new(60, 6, 1.5), Vector3.new(0, 3, 22), wall)
	part(Vector3.new(1.5, 6, 44), Vector3.new(-30, 3, 0), wall)
	part(Vector3.new(1.5, 6, 44), Vector3.new(30, 3, 0), wall)
	part(Vector3.new(8, 0.4, 8), Vector3.new(-23, 0.2, 0), TEAM_A[2], Enum.Material.SmoothPlastic) -- our spawn (tan)
	part(Vector3.new(8, 0.4, 8), Vector3.new(23, 0.2, 0), TEAM_B[1], Enum.Material.SmoothPlastic) -- theirs (green)
	local tall = rng:NextInteger(7, 12)
	part(Vector3.new(6, tall, 6), Vector3.new(0, tall / 2, rng:NextNumber(-6, 6)), Color3.fromRGB(92, 98, 84), Enum.Material.Concrete)
	for _ = 1, rng:NextInteger(6, 9) do
		local s = rng:NextNumber(2.4, 4.2)
		local x, z = rng:NextNumber(-17, 17), rng:NextNumber(-17, 17)
		if math.abs(x) > 5 or math.abs(z) > 5 then
			part(Vector3.new(s, s, s), Vector3.new(x, s / 2, z), Color3.fromRGB(146, 112, 70), Enum.Material.WoodPlanks, CFrame.Angles(0, rng:NextNumber(0, 1.5), 0))
		end
	end
	for _ = 1, 3 do -- cover walls
		local x, z = rng:NextNumber(-14, 14), rng:NextNumber(-15, 15)
		part(Vector3.new(rng:NextNumber(6, 10), 3.2, 1.2), Vector3.new(x, 1.6, z), Color3.fromRGB(108, 112, 100), Enum.Material.Concrete, CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, 0))
	end
	return m
end

local refreshVotes
local function buildMaps(list)
	for _, c in mapHolder:GetChildren() do c:Destroy() end
	mapTiles = {}
	local all = table.clone(list)
	table.insert(all, 1, { id = "Random", name = "Random", random = true }) -- (m1, RIVALS t0028) Random leads the row
	local n = #all
	local tw = math.min(434, (1420 - (n - 1) * MAP_GAP) / n) -- (m16, grader A vs t0032: a tile is 22.6 % wide; was up to 560)
	local th = math.floor(tw * 0.613)
	local x0 = (1420 - (n * tw + (n - 1) * MAP_GAP)) / 2
	for i, m in all do
		local t = new("TextButton", { Name = m.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x0 + (i - 1) * (tw + MAP_GAP), 40), Size = UDim2.fromOffset(tw, th),
			BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, ClipsDescendants = true, ZIndex = 2, Parent = mapHolder }, { corner(6) })
		ink(t, 12, 0)
		-- (2026-10-22, live RIVALS) every card carries its strip colour as a 3 px edge; your vote turns it beige
		local edgeCol = STRIPE_BOTTOM
		local edge = new("UIStroke", { Color = edgeCol, Thickness = 3, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = t })
		local randomQ
		if m.random then
			randomQ = label(t, "⇄", FB, 150, 0, th * 0.08, tw, th * 0.62, WHITE) -- (m1) RIVALS' shuffle, not a "?"
		elseif m.image and m.image ~= "" then
			new("ImageLabel", { BackgroundTransparency = 1, Image = m.image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = t })
		else
			-- (2026-10-20) no picture uploaded yet (Practice Range): an aerial render of the map itself. Lobby duels keep the
			-- map's look in ReplicatedStorage.DuelMaps[id].Visual; the match place has it in Workspace[id].
			local reg = ReplicatedStorage:FindFirstChild("DuelMaps") and ReplicatedStorage.DuelMaps:FindFirstChild(m.id)
			local src = (reg and reg:FindFirstChild("Visual")) or workspace:FindFirstChild(m.id)
			local vpf = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(150, 190, 225), Size = UDim2.fromScale(1, 1),
				Ambient = Color3.fromRGB(120, 124, 132), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.35), Parent = t })
			local world
			if src then
				world = Instance.new("WorldModel")
				for _, d in src:GetDescendants() do
					if d:IsA("BasePart") and d.Transparency < 0.95 then
						local c = d:Clone()
						for _, k in c:GetChildren() do if not (k:IsA("DataModelMesh") or k:IsA("Decal") or k:IsA("Texture") or k:IsA("SurfaceAppearance")) then k:Destroy() end end
						c.Anchored = true
						c.Parent = world
					end
				end
			end
			-- (2026-10-21, round 3: match RIVALS) nothing to render (or an empty model): the Parts arena stands in
			if not world or #world:GetChildren() == 0 then
				if world then world:Destroy() end
				world = miniArena(m.id)
			end
			world.Parent = vpf
			local cf, size = world:GetBoundingBox()
			local cam = Instance.new("Camera")
			cam.FieldOfView = 40
			local span = math.max(size.X, size.Z)
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-0.45 * span, 0.62 * span, 0.62 * span), cf.Position)
			cam.Parent = vpf
			vpf.CurrentCamera = cam
			-- (2026-10-21, round 3: match RIVALS) the map turns slowly (same height and distance, orbiting from this view)
			live3D[vpf] = { cam = cam, c = cf.Position, r = math.sqrt(0.45 ^ 2 + 0.62 ^ 2) * span, h = 0.62 * span, a = math.atan2(-0.45, 0.62), map = true }
		end
		-- striped name bar
		local barH = math.floor(th * 0.2) -- (m16: the name strip 20 % of the tile)
		-- (2026-10-22, live RIVALS) the name sits on a field-green strip with faint diagonal stripes (RIVALS' map strips), white
		-- Bold, not upper-case
		-- (2026-10-23, matchmaking round m8, grader B vs RIVALS t0028) RIVALS' strip is a dark see-through band with thin field-green
		-- hazard stripes, not a solid green bar; the name a size up
		local bar = new("Frame", { Position = UDim2.fromOffset(0, th - barH), Size = UDim2.fromOffset(tw, barH), BackgroundColor3 = BLACK, BackgroundTransparency = 0.3,
			BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = t })
		for k = -2, math.ceil(tw / 22) + 2 do
			new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 72, 76), BackgroundTransparency = 0.35, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 35, -- (m9, grader B: RIVALS' stripes are dark grey; only the edge is green)
				Position = UDim2.fromOffset(k * 22, barH / 2), Size = UDim2.fromOffset(6, barH * 2.2), ZIndex = 2, Parent = bar })
		end
		local nameL = label(bar, m.name, FB, 38, 0, 0, tw, barH, WHITE, nil, 3)
		-- voters (headshots along the top)
		local voters = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(tw - 24, 56), ZIndex = 4, Parent = t },
			{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
		local count = label(t, "", FX, 34, tw - 110, 12, 96, 44, WHITE, Enum.TextXAlignment.Right, 4)
		-- (2026-10-21, RIVALS pass) Kit.bindButton: the same hover grow plus a press squash (every tap answers)
		if Kit then Kit.bindButton(t, { hover = 1.03 })
		else
			local sc = new("UIScale", { Parent = t })
			t.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.03 }):Play() end)
			t.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
		end
		t.Activated:Connect(function()
			send("Vote", m.id)
			player:SetAttribute("_MyVote", m.id) -- instant feedback before the server echoes MapVotes
			refreshVotes()
		end)
		-- (2026-10-21, round 3: match RIVALS) the tiles pop in one after another when the vote opens
		if Kit then Kit.popIn(t, 0.08 + (i - 1) * 0.07) end
		mapTiles[m.id] = { t = t, edge = edge, col = edgeCol, voters = voters, count = count, tw = tw, q = randomQ, nameL = nameL, name = m.name }
	end
end

refreshVotes = function()
	local ok, votes = pcall(function() return HttpService:JSONDecode(st(STATE.Votes) or "{}") end)
	votes = ok and votes or {}
	-- (m13, grader C vs RIVALS t0028 "Arena [100%]") each voted map shows its share of the votes after its name
	-- (m14, grader C: count each voter once; while your change is in flight you sat on two tiles, 67 % in a 1v1)
	local voters, total = {}, 0
	for _, ids in votes do if type(ids) == "table" then for _, uid in ids do voters[uid] = true end end end
	if player:GetAttribute("_MyVote") then voters[player.UserId] = true end
	for _ in voters do total += 1 end
	local mine = player:GetAttribute("_MyVote")
	for id, tile in mapTiles do
		local ids = table.clone(votes[id] or {})
		if mine and mine ~= id then local k = table.find(ids, player.UserId); if k then table.remove(ids, k) end end
		local hasMe = table.find(ids, player.UserId) ~= nil
		if mine == id and not hasMe then table.insert(ids, player.UserId); hasMe = true end
		for _, c in tile.voters:GetChildren() do if c:IsA("ImageLabel") then c:Destroy() end end
		-- (2026-10-21, RIVALS pass) a head that just joined this tile pops in (the others are rebuilt still)
		local before = tile.seen or {}
		tile.seen = {}
		for k, uid in ids do
			if k > 6 then break end
			local img = new("ImageLabel", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tile.voters },
				{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
					uid == player.UserId and new("UIStroke", { Color = WHITE, Thickness = 3 }) or nil }) -- (2026-10-21, AI-tells cleanup) only your head is ringed, thick
			if heads[uid] then img.Image = heads[uid] else task.spawn(function()
				local ok2, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if ok2 then heads[uid] = im; img.Image = im end
			end) end
			tile.seen[uid] = true
			if Kit and not before[uid] then Kit.popIn(img) end
		end
		-- (2026-10-21, RIVALS pass) the vote count punches when it changes
		local countText = #ids > 0 and tostring(#ids) or ""
		if Kit and countText ~= tile.count.Text and countText ~= "" then Kit.pop(tile.count) end
		tile.count.Text = countText
		if tile.nameL then tile.nameL.Text = (#ids > 0 and total > 0) and string.format("%s [%d%%]", tile.name, math.floor(#ids / total * 100 + 0.5)) or tile.name end
		tile.edge.Color = hasMe and TEAM_A[1] or tile.col
		tile.edge.Thickness = hasMe and 5 or 3
		tile.edge.Transparency = 0
		-- (2026-10-23, matchmaking round m2, RIVALS t0026-t0030) the tile you voted for washes pale
		local wash = tile.t:FindFirstChild("VotedWash") or new("Frame", { Name = "VotedWash", BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = tile.t }, { corner(6) }) -- (over the art, under the name and heads)
		TweenService:Create(wash, TweenInfo.new(0.2), { BackgroundTransparency = hasMe and 0.62 or 1 }):Play() -- (m3: your vote only)
	end
end

---------------------------------------------------------------------------------------------------- 3. Loadout
local lo = new("Frame", { Name = "Loadout", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
local loBoxes = { teamBox(lo, 588, TEAM_A, false), teamBox(lo, 1042, TEAM_B, true) }
local loTimer = timerBox(lo)
local titleL = label(lo, "CHOOSE YOUR GUN", STENCIL, 44, 560, 136, 800, 54, WHITE)
local mapChip = label(lo, "", FB, 24, 560, 184, 800, 30, Color3.fromRGB(205, 205, 212))

-- drawn stand-ins for items with no model in the Repository (same as the in-match hotbar)
local function p(model, size, cf, color, shape, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end

local function skinColor()
	local char = localPlayer.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	return hand and hand.Color or Color3.fromRGB(234, 184, 146)
end

-- stand-ins for items with no visible model. Drawn facing -X (they're turned to the camera later).
local METAL = Color3.fromRGB(176, 182, 194)
local BUILDERS = {}
function BUILDERS.Fists(m)
	local skin = skinColor()
	for i = 0, 3 do
		local z = -0.45 + i * 0.3
		p(m, Vector3.new(0.5, 0.42, 0.25), CFrame.new(0, 0.2, z), skin)
		p(m, Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 0.41, z), skin, Enum.PartType.Ball)
	end
	p(m, Vector3.new(0.5, 0.42, 1.18), CFrame.new(0.04, -0.18, 0), skin:Lerp(Color3.new(0, 0, 0), 0.08))
	p(m, Vector3.new(0.5, 0.24, 0.7), CFrame.new(-0.06, -0.1, -0.3) * CFrame.Angles(math.rad(12), 0, 0), skin:Lerp(Color3.new(1, 1, 1), 0.06))
	p(m, Vector3.new(0.5, 0.5, 0.72), CFrame.new(0.04, -0.6, 0.12), skin:Lerp(Color3.new(0, 0, 0), 0.12))
end
local GRENADE = {
	Smoke = { body = Color3.fromRGB(96, 110, 102), band = Color3.fromRGB(228, 232, 238) },
	Flash = { body = Color3.fromRGB(64, 70, 82), band = Color3.fromRGB(80, 160, 255) },
	Frag = { body = Color3.fromRGB(82, 96, 60), band = Color3.fromRGB(60, 70, 44) },
}
local function grenade(m, kind)
	local look = GRENADE[kind]
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand up
	if kind == "Frag" then
		p(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0, 0), look.body, Enum.PartType.Ball)
		p(m, Vector3.new(0.34, 0.5, 0.5), CFrame.new(0, 0.72, 0) * up, METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
	else
		local w = kind == "Flash" and 0.78 or 0.95
		p(m, Vector3.new(1.55, w, w), CFrame.new(0, 0, 0) * up, look.body, Enum.PartType.Cylinder)
		p(m, Vector3.new(0.22, w + 0.02, w + 0.02), CFrame.new(0, 0.1, 0) * up, look.band, Enum.PartType.Cylinder)
		if kind == "Flash" then
			p(m, Vector3.new(0.12, w + 0.02, w + 0.02), CFrame.new(0, -0.45, 0) * up, look.band, Enum.PartType.Cylinder)
		end
		p(m, Vector3.new(0.22, w * 0.7, w * 0.7), CFrame.new(0, 0.88, 0) * up, METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
	end
	p(m, Vector3.new(0.12, 1.0, 0.14), CFrame.new(0, 0.4, 0.58) * CFrame.Angles(math.rad(10), 0, 0), METAL, nil, Enum.Material.Metal)
	p(m, Vector3.new(0.08, 0.36, 0.36), CFrame.new(0, 1.04, -0.4), METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
end
BUILDERS.Smoke = function(m) grenade(m, "Smoke") end
BUILDERS.Flash = function(m) grenade(m, "Flash") end
BUILDERS.Frag = function(m) grenade(m, "Frag") end

-- (2026-10-19) the new gadgets: Sticky Grenade, Landmine, Medkit (same look as the Kit icons)
BUILDERS.StickyGrenade = function(m)
	local up = CFrame.Angles(0, 0, math.rad(90))
	p(m, Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, 0, 0), Color3.fromRGB(150, 44, 36), Enum.PartType.Ball)
	p(m, Vector3.new(0.66, 0.66, 0.66), CFrame.new(-0.45, -0.2, -0.22), Color3.fromRGB(120, 220, 70), Enum.PartType.Ball)
	p(m, Vector3.new(0.36, 0.36, 0.36), CFrame.new(-0.62, -0.5, 0.02), Color3.fromRGB(120, 220, 70), Enum.PartType.Ball)
	p(m, Vector3.new(0.3, 0.42, 0.42), CFrame.new(0, 0.68, 0) * up, METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
end
BUILDERS.Landmine = function(m)
	local up = CFrame.Angles(0, 0, math.rad(90))
	p(m, Vector3.new(0.3, 1.8, 1.8), up, Color3.fromRGB(86, 96, 58), Enum.PartType.Cylinder)
	p(m, Vector3.new(0.16, 1.15, 1.15), CFrame.new(0, 0.22, 0) * up, Color3.fromRGB(64, 72, 44), Enum.PartType.Cylinder)
	p(m, Vector3.new(0.12, 0.42, 0.42), CFrame.new(0, 0.32, 0) * up, Color3.fromRGB(40, 42, 38), Enum.PartType.Cylinder)
	p(m, Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.58, 0.22, -0.32), Color3.fromRGB(255, 50, 40), Enum.PartType.Ball, Enum.Material.Neon)
end
BUILDERS.Medkit = function(m)
	p(m, Vector3.new(1.55, 1.1, 0.58), CFrame.new(0, 0, 0), Color3.fromRGB(236, 234, 228))
	p(m, Vector3.new(0.52, 0.17, 0.06), CFrame.new(0, 0, -0.31), Color3.fromRGB(210, 40, 40))
	p(m, Vector3.new(0.17, 0.52, 0.06), CFrame.new(0, 0, -0.31), Color3.fromRGB(210, 40, 40))
	p(m, Vector3.new(0.62, 0.13, 0.17), CFrame.new(0, 0.65, 0), Color3.fromRGB(60, 62, 66))
end


local function weaponModel(id)
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	local src
	for _, f in { "Weapons", "Melee", "Gadgets" } do
		local folder = repo and repo:FindFirstChild(f)
		src = src or (folder and folder:FindFirstChild(id))
	end
	if not src then
		if BUILDERS[id] then local mm = Instance.new("Model"); BUILDERS[id](mm); mm:SetAttribute("Drawn", true); return mm end
		return nil
	end
	local m = Instance.new("Model")
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			local c = d:Clone()
			for _, k in c:GetChildren() do if not k:IsA("DataModelMesh") then k:Destroy() end end
			c.Anchored = true; c.Color = c.Color:Lerp(WHITE, 0.2); c.Parent = m
		end
	end
	if #m:GetChildren() == 0 then
		if BUILDERS[id] then BUILDERS[id](m); m:SetAttribute("Drawn", true); return m end
		return nil
	end
	return m
end
local function viewport(holder, id)
	for _, c in holder:GetChildren() do if c:IsA("ViewportFrame") then c:Destroy() end end
	if not id then return end -- an empty slot (e.g. a loadout chip before its pick): just cleared
	local m = weaponModel(id)
	if not m then return end
	local vpf = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(170, 170, 176), LightColor = WHITE,
		LightDirection = Vector3.new(-0.5, -1, -0.6), ZIndex = holder.ZIndex, Parent = holder })
	local cam = new("Camera", { FieldOfView = 30, Parent = vpf })
	vpf.CurrentCamera = cam
	m.Parent = vpf
	local cf, size = m:GetBoundingBox()
	-- models: barrel to the side; drawn stand-ins are built facing -X (hotbar pose)
	local pose = m:GetAttribute("Drawn") and (CFrame.Angles(math.rad(10), 0, 0) * CFrame.Angles(0, math.rad(114), 0) * CFrame.Angles(0, 0, math.rad(-6)))
		or (CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(20), 0, 0))
	m:PivotTo(pose * CFrame.new(-cf.Position) * m:GetPivot())
	local cf2, size2 = m:GetBoundingBox()
	local r = size2.Magnitude / 2
	cam.CFrame = CFrame.lookAt(cf2.Position + Vector3.new(0, 0, r / math.tan(math.rad(15)) * 0.95), cf2.Position)
	-- (2026-10-21, round 3: match RIVALS) a live item: it sways a little at rest and turns round while its tile is hovered
	-- (the holder's Hover attribute, set by optionTile). Same distance, so it never clips the frame.
	live3D[vpf] = { cam = cam, c = cf2.Position, r = r / math.tan(math.rad(15)) * 0.95, h = 0, a = 0, holder = holder, t = math.random() * 6, spin = 0 }
end
local function itemName(id) return (id or "?"):gsub("(%l)(%u)", "%1 %2") end

-- (2026-10-16, Edward: "it should tell you which one to pick in order, not preselect them", RIVALS) a guided pick:
-- GUN -> MELEE -> GADGET. Each step lists that slot like RIVALS' weapon list (owned bright with its render, the rest dim
-- between padlocks); a click locks the slot and moves on. Picks collect in the chips at the bottom (click one to re-pick);
-- READY shows once all three are chosen. Nothing is preselected (if time runs out the server keeps your current kit).
local GREY = Color3.fromRGB(205, 205, 212)
local convertLater -- defined with the phases below
local function owned()
	local ok, list = pcall(function() return HttpService:JSONDecode(player:GetAttribute(STATE.Owned) or "[]") end)
	return ok and list or {}
end
local ITEMS -- LobbyConfig.Items (id -> { Name, Slot, Default, Price, Rarity }) when the place has it
pcall(function() ITEMS = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig).Items end)
local function nameOf(id) return (ITEMS and ITEMS[id] and ITEMS[id].Name) or itemName(id) end
local function slotItems(slot)
	-- every item of this slot: owned first (cheapest first), then the locked ones
	local mine, out = {}, {}
	for _, id in owned() do mine[id] = true end
	local kit = player:GetAttribute(STATE.Kit[slot])
	if kit then mine[kit] = true end
	if ITEMS then
		for id, it in ITEMS do
			if it.Slot == slot then table.insert(out, { id = id, owned = mine[id] == true or it.Default == true, price = it.Price or 0 }) end
		end
	else
		for id in mine do table.insert(out, { id = id, owned = true, price = 0 }) end
	end
	table.sort(out, function(a, b)
		if a.owned ~= b.owned then return a.owned end
		if a.price ~= b.price then return a.price < b.price end
		return a.id < b.id
	end)
	return out
end

-- (2026-10-18, Edward: "the loadout switched to rivals layout", RIVALS ref) the map in a dark bar, your picks under it
-- (click one to re-pick), a row of slot tabs (GUN / MELEE / GADGET: the open one white), and the slot's items as a 5-wide
-- grid of square tiles that scrolls: Random first, then owned items coloured by rarity (Standard grey, Rare blue, Epic purple,
-- Legendary gold), the item rendered big and spilling over the tile's top, its name outlined along the bottom; items you
-- don't own sit dimmed under a padlock. Still guided: a pick jumps to the next empty tab; READY once all three are set.
titleL.Visible = false
mapChip.Visible = false
-- (2026-10-23, matchmaking round m4, graders A + B vs RIVALS t0036) the whole pick block sits 97 px (9 %) lower: map bar, slots,
-- tabs and the options grid
local LO_DROP = 97
local mapBar = new("Frame", { Name = "MapBar", Position = UDim2.fromOffset(660, 120 + LO_DROP), Size = UDim2.fromOffset(600, 50), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = lo },
	{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
local mapBarL = label(mapBar, "Map", FX, 32, 0, 0, 600, 50, WHITE)

-- your picks: three slots in a row (each shows its pick in 3D; the open one framed)
local SLOT_W, SLOT_GAP = 86, 12
local slotRowX = 960 - (#SLOTS * SLOT_W + (#SLOTS - 1) * SLOT_GAP) / 2
local chips = {}
for i, s2 in SLOTS do
	local chip = new("TextButton", { Name = "Slot" .. s2.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(slotRowX + (i - 1) * (SLOT_W + SLOT_GAP), 186 + LO_DROP),
		Size = UDim2.fromOffset(SLOT_W, SLOT_W), BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, ZIndex = 2, Parent = lo }, { corner(6) })
	ink(chip, 6, 4)
	local edge = new("UIStroke", { Color = INK_YELLOW, Thickness = 5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip }) -- (m4: 3 -> 5, RIVALS' bold active ring)
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-8, -12), Size = UDim2.fromOffset(SLOT_W + 16, SLOT_W + 8), ZIndex = 3, Parent = chip })
	local q = label(chip, string.upper(s2.label), STENCIL, 18, 0, 0, SLOT_W, SLOT_W, Color3.fromRGB(110, 112, 108))
	chips[s2.id] = { chip = chip, edge = edge, art = art, q = q, index = i }
end

-- slot tabs
local TAB_W, TAB_GAP = 250, 10 -- (2026-10-20) wide enough for "MELEE  ·  SET" (Oswald now)
local tabX = 960 - (#SLOTS * TAB_W + (#SLOTS - 1) * TAB_GAP) / 2
local tabs = {}
for i, s2 in SLOTS do
	local t = new("TextButton", { Name = "Tab" .. s2.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(tabX + (i - 1) * (TAB_W + TAB_GAP), 300 + LO_DROP),
		Size = UDim2.fromOffset(TAB_W, 48), BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, ZIndex = 2, Parent = lo }, { corner(4) })
	ink(t, 6, 4)
	local tl = label(t, string.upper(s2.label), FX, 26, 0, 0, TAB_W, 48, WHITE)
	tabs[i] = { b = t, l = tl }
	-- (2026-10-22, live RIVALS loadout) no slot tabs: the framed slot square above says which pick is next, and a pick moves on
	-- by itself (the tabs stay built for the gamepad / old flow, just hidden)
	t.Visible = false
end

-- the grid: 5 per row in a scroll area
local OPT, OPT_GAP, PER_ROW = 122, 36, 5
local GRID_W, GRID_H = 5 * OPT + 4 * OPT_GAP + 40, 560
-- (2026-10-22) the grid moves up into the hidden tabs' place (y 296, was 368)
local optArea = new("ScrollingFrame", { Name = "Options", Position = UDim2.fromOffset(960 - GRID_W / 2, 296 + LO_DROP), Size = UDim2.fromOffset(GRID_W, GRID_H), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = GREY, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), Parent = lo })
local list = optArea
local ready = new("TextButton", { Name = "Ready", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1500, 900), Size = UDim2.fromOffset(300, 80),
	BackgroundColor3 = FIELD, Visible = false, ZIndex = 2, Parent = lo }, { corner(6) }) -- (2026-10-21, AI-tells cleanup) ready = field green
ink(ready, 10, 6)
local readyL = label(ready, "READY!", FX, 56, 0, 0, 300, 80, BLACK)
for _, k in readyL:GetChildren() do if k:IsA("UIStroke") then k.Color = WHITE; k.Thickness = 2 end end
ready.Activated:Connect(function()
	send("Ready")
	player:SetAttribute("_Ready", true)
	readyL.Text = "LOCKED IN!"
end)

local RARITY = {
	Standard = { Color3.fromRGB(104, 108, 116), Color3.fromRGB(40, 42, 46) },
	Rare = { Color3.fromRGB(70, 140, 235), Color3.fromRGB(24, 58, 120) },
	Epic = { Color3.fromRGB(150, 70, 235), Color3.fromRGB(60, 22, 120) },
	Legendary = { Color3.fromRGB(245, 200, 60), Color3.fromRGB(150, 96, 14) },
}
local function rarityOf(id) return ITEMS and ITEMS[id] and ITEMS[id].Rarity or "Standard" end

local picks, step = {}, 1
local showStep
local function refreshChips()
	for _, s2 in SLOTS do
		local c = chips[s2.id]
		local id = picks[s2.id]
		c.q.Visible = false -- (Edward: the tabs below already name the slot; the empty square stays plain, like RIVALS)
		if c.shown ~= id then
			c.shown = id; viewport(c.art, id)
			if Kit and id then Kit.pop(c.chip) end -- (2026-10-21, RIVALS pass) a new pick lands with a punch
		end
		c.edge.Transparency = (step == c.index and optArea.Visible) and 0 or 1
	end
	for i, t in tabs do
		local on = i == step and optArea.Visible
		t.b.BackgroundColor3 = on and FIELD or BLACK -- (2026-10-21, AI-tells cleanup) the open tab: field green fill, not the yellow
		t.b.BackgroundTransparency = on and 0 or PANEL_T
		t.l.TextColor3 = on and BLACK or WHITE
		local ts = t.l:FindFirstChildOfClass("UIStroke"); if ts then ts.Color = on and WHITE or BLACK end
		t.l.Text = string.upper(SLOTS[i].label) .. ((picks[SLOTS[i].id] and not on) and "  ·  SET" or "")
	end
	ready.Visible = false -- (2026-10-21, Edward) no Ready button: the third pick readies you (allPicked)
end
local switching = false -- (2026-10-18, RIVALS "Switch Weapons [M]") the picker opened between rounds
local function allPicked()
	optArea.Visible = false
	refreshChips()
	if switching then task.delay(0.35, function() switching = false end) end -- the last pick closes it (RIVALS)
	-- (2026-10-21, Edward: "there shouldn't be a ready button ... after you pick all your weapons it should put you in the game")
	if not switching and player:GetAttribute("_Ready") ~= true then
		send("Ready")
		player:SetAttribute("_Ready", true)
	end
end
local function optionTile(parent, x, y, id, text, onPick, kind)
	-- kind: "random" | "locked" | rarity name
	local cols = kind == "random" and { Color3.fromRGB(20, 20, 24), Color3.fromRGB(6, 6, 8) } or (RARITY[kind] or RARITY.Standard)
	local t = new("TextButton", { Name = text, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(OPT, OPT), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.2, ZIndex = 2, Parent = parent },
		{ corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }) })
	ink(t, 7, 4)
	local scale = new("UIScale", { Parent = t })
	if kind == "random" then
		label(t, "⇄", FB, 64, 0, 6, OPT, 80, Color3.fromRGB(200, 200, 206))
	else
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-14, -34), Size = UDim2.fromOffset(OPT + 28, OPT + 8), ZIndex = 3, Parent = t })
		task.defer(viewport, art, id)
		-- (2026-10-21, round 3: match RIVALS) hovered / pad-selected: the item turns round (live3D loop below)
		t.MouseEnter:Connect(function() art:SetAttribute("Hover", true) end)
		t.MouseLeave:Connect(function() art:SetAttribute("Hover", nil) end)
		t.SelectionGained:Connect(function() art:SetAttribute("Hover", true) end)
		t.SelectionLost:Connect(function() art:SetAttribute("Hover", nil) end)
	end
	local n = label(t, text, FX, #text > 11 and 26 or 32, -10, OPT - 40, OPT + 20, 36, WHITE) -- (m2, RIVALS t0036: Title case, not upper)
	n.ZIndex = 4
	if kind == "locked" then
		t.BackgroundTransparency = 0.5
		new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = t }, { corner(8) })
		local lock = label(t, "🔒", FX, 40, 0, 30, OPT, 50, WHITE)
		lock.ZIndex = 6
		return t
	end
	-- (2026-10-21, RIVALS pass) Kit.bindButton (hover / gamepad grow 1.08 as before, plus a press squash); same UIScale
	if Kit then Kit.bindButton(t, { hover = 1.08 })
	else
		t.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play() end)
		t.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
		t.SelectionGained:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play() end)
		t.SelectionLost:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	end
	t.Activated:Connect(onPick)
	return t
end
function showStep(i)
	step = i
	local slot = SLOTS[i].id
	for _, c in optArea:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local mine, locked = {}, {}
	for _, it in slotItems(slot) do
		if it.owned then table.insert(mine, it.id) else table.insert(locked, it.id) end
	end
	local function pick(id)
		picks[slot] = id
		send("Pick", slot, id)
		local nextStep
		for k, s2 in SLOTS do if not picks[s2.id] then nextStep = k break end end
		if nextStep then showStep(nextStep) else allPicked() end
	end
	local entries = { { kind = "random" } }
	for _, id in mine do table.insert(entries, { id = id, kind = rarityOf(id) }) end
	-- (2026-10-18, Edward: "locked weapons shouldn't show up at all") only what you own is listed
	local rows = math.ceil(#entries / PER_ROW)
	local rowH = OPT + 40
	local contentH = math.max(GRID_H, 40 + rows * rowH)
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(GRID_W, contentH), Parent = optArea })
	-- (2026-10-22, live RIVALS) a short row is centred under the slots, not packed left
	local rowStart = 20
	if #entries < PER_ROW then rowStart = (GRID_W - (#entries * OPT + (#entries - 1) * OPT_GAP)) / 2 end
	for k, e in entries do
		local row = (k - 1) // PER_ROW
		local col = (k - 1) % PER_ROW
		local x = rowStart + col * (OPT + OPT_GAP)
		local y = 36 + row * rowH
		if e.kind == "random" then
			local rt = optionTile(content, x, y, nil, "Random", function() if #mine > 0 then pick(mine[math.random(#mine)]) end end, "random")
			if Kit then Kit.popIn(rt, 0) end -- (2026-10-21, round 3: match RIVALS) the slot's tiles pop in, staggered
		else
			local tile = optionTile(content, x, y, e.id, nameOf(e.id), function() pick(e.id) end, e.kind)
			if Kit then Kit.popIn(tile, math.min(k - 1, 10) * 0.03) end
			if picks[slot] == e.id then
				-- (2026-10-21, AI-tells cleanup) ink() no longer adds an edge: the current pick gets its own thick cream ring
				new("UIStroke", { Color = INK_YELLOW, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile })
			end
		end
	end
	optArea.Visible = true
	optArea.CanvasSize = UDim2.fromScale(optArea.Size.X.Scale, optArea.Size.Y.Scale * contentH / GRID_H)
	optArea.ScrollBarImageTransparency = contentH > GRID_H and 0.3 or 1
	optArea.CanvasPosition = Vector2.zero
	convertLater(content, Vector2.new(GRID_W, contentH))
	content.Size = UDim2.fromScale(1, 1)
	refreshChips()
end
for _, s2 in SLOTS do chips[s2.id].chip.Activated:Connect(function() showStep(chips[s2.id].index) end) end
for i, t in tabs do t.b.Activated:Connect(function() showStep(i) end) end
local function startLoadout()
	picks, step = {}, 1
	for _, c in chips do c.shown = false end
	player:SetAttribute("_Ready", nil); readyL.Text = "READY!"
	mapBarL.Text = "Map: " .. itemName(st(STATE.Chosen) or "?")
	showStep(1)
end
local function refreshLoadout() refreshChips() end

---------------------------------------------------------------------------------------------------- convert + phases
toScale(canvas, Vector2.new(W, H))
-- children of converted frames keep Scale; holders built later are converted against their own design size
function convertLater(holder, size) toScale(holder, size); rescale() end
rescale()
-- (2026-10-21, RIVALS pass) things that punch / pulse grow from their centre, not their top-left corner
if Kit then
	for _, c in chips do Kit.centreAnchor(c.chip) end
	Kit.centreAnchor(voteTimer); Kit.centreAnchor(loTimer)
end

local phase
local function flowOn(p) return p == "Loading" or p == "MapVote" or p == "Loadout" or p == "Switch" end
-- (2026-10-21, RIVALS pass) phases pop in (Kit.open: scale 0.9 -> 1, Back) and step out (Kit.close: shrink, then hide)
-- instead of instant Visible flips. A frame reopened while its close is still running is shown again by the close's done().
-- Frames stay plain Frames (no CanvasGroup: the map / item ViewportFrames and big text would go soft), so the fade is the
-- backdrop's, below.
local function showFrame(f, show)
	if not Kit then f.Visible = show; return end
	if show then
		if f:GetAttribute("_FlowOn") then return end
		f:SetAttribute("_FlowOn", true)
		Kit.open(f)
	else
		if not f:GetAttribute("_FlowOn") then f.Visible = false; return end
		f:SetAttribute("_FlowOn", nil)
		Kit.close(f, function() if f:GetAttribute("_FlowOn") then f.Visible = true end end)
	end
end
local function setPhase(p)
	if p == phase then return end
	phase = p
	local on = flowOn(p)
	if on or not Kit then gui.Enabled = on
	else -- let the close motion play before the whole screen switches off
		task.delay(0.14, function() if not flowOn(phase) then gui.Enabled = false end end)
	end
	showFrame(loading, p == "Loading")
	showFrame(vote, p == "MapVote")
	showFrame(lo, p == "Loadout" or p == "Switch")
	loTimer.Parent.Visible = false -- (m1, RIVALS t0034-t0038: no clock during the pick; between rounds the match HUD's timer counts down)
	-- Switch Weapons (RIVALS): the picker over the blurred match instead of the dark backdrop, no team boxes
	local sw = p == "Switch"
	-- RIVALS: the gun pick sits over the world, see-through; the loading screen AND the map vote stay solid (Edward 2026-10-21:
	-- "rivals uses a background overlay ... to hide the player from seeing what map they are on" during map selection)
	-- (2026-10-21, RIVALS pass) the backdrop fades to its level (and away when the flow ends) instead of snapping
	-- (2026-10-22, live RIVALS) the gun pick: the world heavily blurred (blur below), only a light shade, no team boxes
	local backT = not on and 1 or (sw and 0.55 or ((p == "Loading" or p == "MapVote") and 0 or 0.7))
	if Kit then
		if back.BackgroundTransparency ~= backT then TweenService:Create(back, TweenInfo.new(0.18), { BackgroundTransparency = backT }):Play() end
	else back.BackgroundTransparency = backT end
	for _, bx in loBoxes do local f = type(bx) == "table" and (bx.frame or (bx[1] and bx[1].h and bx[1].h.Parent)) or bx; if typeof(f) == "Instance" then f.Visible = not (sw or p == "Loadout") end end
	local Lighting = game:GetService("Lighting")
	local blur = Lighting:FindFirstChild("SwitchWeaponsBlur") or new("BlurEffect", { Name = "SwitchWeaponsBlur", Size = 0, Parent = Lighting })
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = (on and ((sw and 16) or (p == "Loadout" and 24))) or 0 }):Play()
	-- the match HUD steps out while the picker is up (RIVALS keeps only the score bar); back on when it closes
	local pg = player:FindFirstChild("PlayerGui")
	for _, n in { "HUD", "Hotbar", "Vitals", "StealthUI", "TutorialUI", "NearMissUI", "TouchControls" } do
		local g = pg and pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then
			-- (2026-10-20) the see-through vote / gun pick hide the match HUD too
			local hideHud = sw or p == "MapVote" or p == "Loadout"
			if hideHud and g.Enabled then g.Enabled = false; g:SetAttribute("SwitchHid", true)
			elseif not hideHud and g:GetAttribute("SwitchHid") then g:SetAttribute("SwitchHid", nil); g.Enabled = true end
		end
	end
	if p == "Switch" then
		local chosen = st(STATE.Chosen)
		mapBarL.Text = "Map: " .. itemName(chosen or "?")
		startLoadout()
	end
	if p == "Loading" then tipL.Text = TIPS[math.random(#TIPS)] end
	if p == "MapVote" then
		player:SetAttribute("_MyVote", nil)
		local ok, list = pcall(function() return HttpService:JSONDecode(st(STATE.Maps) or "[]") end)
		buildMaps(ok and list or {})
		convertLater(mapHolder, Vector2.new(1420, 760))
		fillTeams(voteBoxes); refreshVotes()
	end
	if p == "Loadout" then
		local chosen = st(STATE.Chosen)
		mapChip.Text = chosen and ("Map: " .. itemName(chosen)) or ""
		fillTeams(loBoxes)
		startLoadout()
	end
end
-- map vote ends: the winner flashes (RIVALS) before the next phase shows
local lastChosen, lastVotes
local function onChosen()
	local tile = mapTiles[st(STATE.Chosen) or ""]
	if tile and phase == "MapVote" then
		-- (2026-10-21, round 3: match RIVALS) the result reads at a glance: the winner punches and its map spins up, the
		-- other tiles dim under a dark wash
		if Kit then Kit.pop(tile.t, 1.1) end
		-- (2026-10-22, live RIVALS) the other cards go and the winner glides to the middle, a little lower, on its own
		for _, other in mapTiles do
			if other ~= tile then
				local wash = new("Frame", { Name = "LostWash", BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = other.t }, { new("UICorner", { CornerRadius = UDim.new(0.04, 0) }) })
				TweenService:Create(wash, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
				task.delay(0.25, function() if other.t.Parent then other.t.Visible = false end end)
			end
		end
		do
			local sx, sy = tile.t.Size.X.Scale, tile.t.Size.Y.Scale
			local ap = tile.t.AnchorPoint
			-- (m10, graders A + C vs RIVALS t0032) the winner lands centred on the screen (was 120 px below its row)
			local y = tile.t.Position.Y.Scale + 120 / 760
			local par, sg = tile.t.Parent, tile.t:FindFirstAncestorWhichIsA("LayerCollector")
			if par and sg and par.AbsoluteSize.Y > 0 then
				local midAbs = sg.AbsolutePosition.Y + sg.AbsoluteSize.Y / 2
				y = (midAbs - par.AbsolutePosition.Y) / par.AbsoluteSize.Y - (0.5 - tile.t.AnchorPoint.Y) * sy
			end
			TweenService:Create(tile.t, TweenInfo.new(0.4, Enum.EasingStyle.Quart), { Position = UDim2.fromScale((1 - sx) / 2 + sx * ap.X, y) }):Play()
		end
		for vpf, s in live3D do if s.map and vpf:IsDescendantOf(tile.t) then s.boost = 1 end end
		task.spawn(function()
			-- (2026-10-21, AI-tells cleanup) the ring blinks on / off (no grey hairline at rest any more)
			for _ = 1, 3 do tile.edge.Color = TEAM_A[1]; tile.edge.Thickness = 4; tile.edge.Transparency = 0; task.wait(0.15); tile.edge.Transparency = 1; task.wait(0.15) end
			tile.edge.Color = TEAM_A[1]; tile.edge.Transparency = 0
		end)
	end
end
for _, s in SLOTS do
	player:GetAttributeChangedSignal(STATE.Kit[s.id]):Connect(function()
		if phase == "Loadout" then refreshLoadout() end
	end)
end

local loadStart = os.clock()
local teamTick
local lastBeat -- (2026-10-21, RIVALS pass) the last timer second that pulsed
local wordsAt = 0 -- (2026-10-21, RIVALS pass) when the loading words were last checked
RunService.RenderStepped:Connect(function()
	-- (Edward 2026-10-20) Switch Weapons stays up when the next round goes live: only the match moving on closes it
	-- (or the player: Done / X / M / B)
	if switching then
		local ms = st("MatchState")
		if ms ~= "RoundEnd" and ms ~= "Countdown" and ms ~= "Live" then switching = false end
	end
	if player:GetAttribute("SwitchingWeapons") ~= (switching or nil) then player:SetAttribute("SwitchingWeapons", switching or nil) end
	setPhase(switching and "Switch" or st(STATE.Phase))
	-- (2026-10-20, live check with Edward) the hotbar / health came back behind the map vote and gun pick: their controllers
	-- switch them on after the phase began, so keep them off every frame while one of these screens is up
	-- (2026-10-20, Edward: "i shouldnt see myself floating when the match starts") your body is parked out of the way
	-- during loading / map vote / gun pick: hide it on your screen (LocalTransparencyModifier, client only), back when it ends
	do
		local hide = phase == "Loading" or phase == "MapVote" or phase == "Loadout"
		local char = player.Character
		if char and (hide or char:GetAttribute("_FlowHidden")) then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = hide and 1 or 0 end
			end
			char:SetAttribute("_FlowHidden", hide or nil)
		end
	end
	if phase == "MapVote" or phase == "Loadout" or phase == "Switch" then
		local pg = player:FindFirstChild("PlayerGui")
		for _, n in { "HUD", "Hotbar", "Vitals", "TutorialUI", "NearMissUI", "TouchControls" } do
			local g = pg and pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled then g.Enabled = false; g:SetAttribute("SwitchHid", true) end
		end
	end
	-- (2026-10-20) picks during a live round are queued by the server (NextKitWeapon / Melee / Gadget) for the next spawn
	if phase == "Switch" then
		local q = {}
		for _, k in { "NextKitWeapon", "NextKitMelee", "NextKitGadget" } do
			local v = player:GetAttribute(k)
			if v then table.insert(q, tostring(v)) end
		end
		local txt = st("MatchState") == "Live" and (#q > 0 and ("Next round: " .. table.concat(q, ", ")) or "Changes apply next round")
			or ("Map: " .. itemName(st(STATE.Chosen) or "?"))
		if mapBarL.Text ~= txt then mapBarL.Text = txt end
	end
	local left = math.max(0, (st(STATE.EndsAt) or 0) - workspace:GetServerTimeNow())
	-- (2026-10-21, RIVALS pass) the last 3 s: the timer punches once per whole second (no colour flash this round: Q1 pending)
	if Kit and (phase == "MapVote" or phase == "Loadout") and left > 0 then
		local beat = phase .. math.ceil(left)
		if math.ceil(left) <= 3 and beat ~= lastBeat then lastBeat = beat; Kit.pulse(phase == "MapVote" and voteTimer or loTimer) end
	end
	if phase == "MapVote" then
		voteTimer.Text = string.format("%.1f", left)
		tintTimer(voteTimer, left <= 0.05)
		local v, c = st(STATE.Votes), st(STATE.Chosen)
		if v ~= lastVotes then lastVotes = v; refreshVotes() end
		if c ~= lastChosen then lastChosen = c; if c then onChosen() end end
	end
	if phase == "Loadout" then
		loTimer.Text = string.format("%.1f", left); refreshLoadout()
		teamTick = (teamTick or 0) + 1
		if teamTick % 15 == 0 then fillTeams(loBoxes) end -- ready ticks
	end
	-- (2026-10-21, RIVALS pass) honest loading: no fake counter. Twice a second: is anyone on the other side yet?
	if phase == "Loading" and os.clock() - wordsAt > 0.5 then
		wordsAt = os.clock()
		local mine = player:GetAttribute(STATE.Team) or "A"
		local other = teamList(mine == "A" and "TeamB" or "TeamA")
		local here = false
		for _, e in other or {} do if e.bot or e.player then here = true break end end
		loadWords.Text = here and "Getting the map ready" or "Waiting for opponent"
	end
end)

-- (2026-10-21, round 3: match RIVALS) the live 3D pictures: maps orbit slowly (the winner spins up), items sway and turn
-- round while hovered; the Random map's "?" rocks. Only runs while a vote / pick screen is up.
RunService.RenderStepped:Connect(function(dt)
	if phase ~= "MapVote" and phase ~= "Loadout" and phase ~= "Switch" then return end
	dt = math.min(dt, 1 / 20)
	for vpf, s in live3D do
		if not vpf.Parent then live3D[vpf] = nil
		elseif s.map then
			if phase == "MapVote" then
				s.boost = math.max(0, (s.boost or 0) - dt * 0.5)
				s.a += dt * (0.07 + (s.boost or 0) * 1.6)
				s.cam.CFrame = CFrame.lookAt(s.c + Vector3.new(math.sin(s.a) * s.r, s.h, math.cos(s.a) * s.r), s.c)
			end
		else
			s.t += dt
			if s.holder and s.holder:GetAttribute("Hover") then
				s.spin += dt * 2.4
			elseif s.spin ~= 0 then -- let go: ease back the short way to the posed view
				local w = (s.spin + math.pi) % (2 * math.pi) - math.pi
				s.spin = math.abs(w) < 0.01 and 0 or w * (1 - math.min(1, dt * 6))
			end
			local a = s.spin + math.sin(s.t * 1.1) * 0.16
			s.cam.CFrame = CFrame.lookAt(s.c + Vector3.new(math.sin(a) * s.r, 0, math.cos(a) * s.r), s.c)
		end
	end
	local rq = mapTiles.Random and mapTiles.Random.q
	if rq and phase == "MapVote" then rq.Rotation = math.sin(os.clock() * 2.2) * 8 end
end)

-- (2026-10-18) DuelHUD's Switch Weapons button / M key: PlayerScripts.SwitchWeapons:Invoke("Open" | "Close" | "Toggle") -> open?
do
	local sw = Instance.new("BindableFunction")
	sw.Name = "SwitchWeapons"
	sw.OnInvoke = function(cmd)
		local ms = st("MatchState")
		-- (2026-10-20, Edward) the countdown into a round (not before the first), and on into the live round until you move or
		-- land a shot (the server's KitLocked)
		local allowed = ((ms == "Countdown" and (tonumber(st("RoundNumber")) or 1) > 1) or (ms == "Live" and player:GetAttribute("KitLocked") ~= true)) and st(STATE.Phase) ~= "Loadout"
		if cmd == "Close" or (cmd == "Toggle" and switching) then switching = false
		elseif allowed then switching = true end
		return switching
	end
	sw.Parent = player:WaitForChild("PlayerScripts")
end

-- Studio only: MatchFlowTest:Invoke(phase) fakes the server state, so the screens can be checked without a match server
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "MatchFlowTest"
	hook.OnInvoke = function(p, extra)
		local o = stateObject() or ReplicatedStorage
		if p == "MapVote" and not o:GetAttribute(STATE.Maps) then
			o:SetAttribute(STATE.Maps, HttpService:JSONEncode({ { id = "Warehouse", name = "Warehouse", image = extra or "" } }))
		end
		if p == "Loadout" then
			player:SetAttribute(STATE.Owned, player:GetAttribute(STATE.Owned) or HttpService:JSONEncode({ "Pistol", "Revolver", "Sniper", "Fists", "Knife", "Smoke", "Flash" }))
			for slot, def in { Weapon = "Pistol", Melee = "Fists", Gadget = "Smoke" } do
				if not player:GetAttribute(STATE.Kit[slot]) then player:SetAttribute(STATE.Kit[slot], def) end
			end
		end
		o:SetAttribute(STATE.EndsAt, workspace:GetServerTimeNow() + (p == "MapVote" and 10 or 15))
		o:SetAttribute(STATE.Phase, p)
		return true
	end
	hook.Parent = player:WaitForChild("PlayerScripts")
end
