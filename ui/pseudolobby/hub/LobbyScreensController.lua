-- Controllers/LobbyScreensController (client, lobby place): the lobby feature screens (notes/features_done.md).
-- Each screen is a Part tagged "LobbyScreen" with attribute Screen = Training | DuelsTV | DuelsSign | Likes | Ad. The UI is a
-- SurfaceGui in PlayerGui adorned to that part (Front face), so the part can be re-parented into a TV kit model later
-- without touching this code. Every Position/Size is Scale (Edward's rule); canvas = 100 px per stud of the part face.
-- Data: Training = players' InTraining attribute; DuelsTV / DuelsSign = ReplicatedStorage attribute LF_LiveDuels
-- (LobbyFeaturesManager); Likes = LF_LikesCurrent / LF_LikesGoal / LF_LikesReward; Ad = LF_AdReady (+ Events.Lobby.LF_WatchAd).
-- (2026-10-21, RIVALS pass) Look: field-green header plates, chunky plates with a darker offset lip (no strokes, no accent
-- bars), Oswald / Rubik, flat icons (LIVE pill, eye, thumbs-up). Life: numbers count up, new rows pop in, the LIVE pill
-- pulses. Rows and cards are pooled and reused, so the 1 s Duels clock only rewrites text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local controller = {}

local player = Players.LocalPlayer
local okC, LF = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyFeaturesConfig", 10)) end)

-- palette (2026-10-21, RIVALS pass): near-black plates, cream / tan text, field green for primary, olive for ranked,
-- comic yellow kept for a #1 only (none on these screens), LIVE red stays red
local INK, INK2, PANEL = Color3.fromRGB(10, 12, 10), Color3.fromRGB(22, 25, 21), Color3.fromRGB(30, 34, 29)
local LIP, LIPG = Color3.fromRGB(4, 5, 4), Color3.fromRGB(34, 56, 20)
local CREAM, TAN = Color3.fromRGB(236, 230, 210), Color3.fromRGB(226, 210, 172)
local GREEN_HI, GREEN_LO = Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)
local OLIVE, OLIVE_LO = Color3.fromRGB(138, 156, 74), Color3.fromRGB(92, 106, 46)
local RED = Color3.fromRGB(196, 64, 52)
local WHITE = Color3.new(1, 1, 1)
local TITLE = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local ICON = {
	eye = "rbxassetid://139964028443214", live = "rbxassetid://85639052729616", thumbs = "rbxassetid://133746546608841",
	matches = "rbxassetid://125681613105062", gadget = "rbxassetid://122224655406431",
}
local SRC = { pad = "ON A PAD", online = "ONLINE", remote = "OTHER LOBBY" }
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local COUNT = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class); for k, v in props do o[k] = v end; if parent then o.Parent = parent end; return o
end
local function box(parent, pos, size, color, props)
	local f = new("Frame", { Position = pos, Size = size, BackgroundColor3 = color or PANEL, BorderSizePixel = 0 }, parent)
	for k, v in props or {} do f[k] = v end
	return f
end
local function text(parent, str, pos, size, color, font, align, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Position = pos, Size = size, Text = str, TextColor3 = color or CREAM,
		FontFace = font or TITLE, TextScaled = true, TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end
local S = UDim2.fromScale
local CENTER, RIGHT = Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function fmt(n) n = math.floor(tonumber(n) or 0); local s = tostring(n); local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (r:gsub("^,", "")) end
local function round(f) new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f) end
local function grad(f, a, b) return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }, f) end
local function icon(parent, id, pos, size, color)
	return new("ImageLabel", { BackgroundTransparency = 1, Position = pos, Size = size, Image = id, ImageColor3 = color or CREAM, ScaleType = Enum.ScaleType.Fit }, parent)
end
-- (2026-10-21, RIVALS pass) chunky plate: a darker lip frame offset under the face instead of a stroke. Returns face, holder.
-- The holder is centre-anchored (pos is still its top-left corner) so pop() grows it from the middle.
local function centre(pos, size) return S(pos.X.Scale + size.X.Scale / 2, pos.Y.Scale + size.Y.Scale / 2) end
local function plate(parent, pos, size, color, lip, depth)
	depth = depth or 0.1
	local holder = box(parent, centre(pos, size), size, INK, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5) })
	box(holder, S(0, depth), S(1, 1 - depth), lip or LIP)
	return box(holder, S(0, 0), S(1, 1 - depth), color or PANEL), holder
end
-- (2026-10-21, RIVALS pass) new rows / cards pop in (UIScale 0.8 -> 1, Back)
local function pop(g, from)
	local sc = g:FindFirstChildOfClass("UIScale") or new("UIScale", {}, g)
	sc.Scale = from or 0.8
	TweenService:Create(sc, POP, { Scale = 1 }):Play()
end
-- (2026-10-21, RIVALS pass) a number label ticks from its last value to the new one (one NumberValue per label, reused)
local counters = {}
local function countTo(label, n, suffix)
	n = math.floor(tonumber(n) or 0)
	local c = counters[label]
	if not c then
		c = { v = new("NumberValue", { Value = n }), n = n, suffix = suffix or "" }
		counters[label] = c
		c.v.Changed:Connect(function(x) label.Text = fmt(x) .. c.suffix end)
		label.Text = fmt(n) .. c.suffix
		label.Destroying:Connect(function() counters[label] = nil; c.v:Destroy() end)
		return
	end
	if c.n == n then return end
	c.n = n
	TweenService:Create(c.v, COUNT, { Value = n }):Play()
end

local thumbs = {}
local function headshot(uid, img)
	if thumbs[uid] then img.Image = thumbs[uid] return end
	img.Image = ""
	task.spawn(function()
		local okT, url = pcall(Players.GetUserThumbnailAsync, Players, math.max(1, uid), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if okT then thumbs[uid] = url; if img.Parent then img.Image = url end end
	end)
end

-- the SurfaceGui + base panel on a screen part. Returns root frame (16 px design grid not needed: all Scale)
local function surface(part, name)
	local gui = new("SurfaceGui", { Name = "LF_" .. name, Adornee = part, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(math.floor(part.Size.X * 100), math.floor(part.Size.Y * 100)), LightInfluence = 0, Brightness = 1.25,
		MaxDistance = 180, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true }, player:WaitForChild("PlayerGui"))
	local root = box(gui, S(0, 0), S(1, 1), INK)
	grad(root, INK2, INK)
	part.AncestryChanged:Connect(function() if not part:IsDescendantOf(workspace) then gui:Destroy() end end)
	return root, gui
end
-- (2026-10-21, RIVALS pass) red LIVE pill (artwork already says LIVE; never tinted), gentle breathe
local function livePill(parent, center, size)
	local img = icon(parent, ICON.live, center, size, WHITE)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	local sc = new("UIScale", {}, img)
	TweenService:Create(sc, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 }):Play()
	return img
end
-- (2026-10-21, RIVALS pass) header: field-green gradient plate with a dark-green lip, shadowed cream title, right tag and/or LIVE pill
local function header(root, title, tag, live, h)
	h = h or 0.17
	local bar = box(root, S(0, 0), S(1, h), WHITE)
	grad(bar, GREEN_HI, GREEN_LO)
	box(root, S(0, h), S(1, 0.025), LIPG)
	text(bar, title, S(0.039, 0.17), S(0.6, 0.76), LIPG, TITLE)
	text(bar, title, S(0.035, 0.12), S(0.6, 0.76), CREAM, TITLE)
	local right = 0.965
	if live then livePill(bar, S(0.9, 0.5), S(0.12, 0.62)); right = 0.83 end
	local t = tag and text(bar, tag, S(right - 0.42, 0.29), S(0.42, 0.42), CREAM, BOLD, RIGHT)
	return bar, t
end
-- (2026-10-21, RIVALS pass) bottom bar: green call-to-action or dark info strip
local function footer(root, green)
	local foot = box(root, S(0, 0.885), S(1, 0.115), green and WHITE or INK2)
	if green then grad(foot, GREEN_HI, GREEN_LO) end
	return foot
end
-- round headshot chip with an initial letter until (or instead of) the thumbnail
local function head(parent, pos, size)
	local ring = box(parent, pos, size or S(0.7, 0.7), INK2, { SizeConstraint = Enum.SizeConstraint.RelativeYY })
	round(ring)
	local ini = text(ring, "", S(0, 0.18), S(1, 0.64), TAN, TITLE, CENTER)
	local img = new("ImageLabel", { BackgroundTransparency = 1, Size = S(1, 1) }, ring)
	round(img)
	return { ring = ring, ini = ini, img = img }
end
local function byName(display)
	for _, p in Players:GetPlayers() do if p.DisplayName == display then return p end end
end
local function setHead(h, list)
	local first = type(list) == "table" and list[1]
	if type(first) ~= "string" then h.ring.Visible = false; h.who = nil return end
	h.ring.Visible = true
	if h.who == first then return end
	h.who = first
	local p = byName(first)
	local cut = utf8.offset(first, 2)
	h.ini.Text = string.upper(cut and string.sub(first, 1, cut - 1) or first)
	h.ini.Visible = p == nil
	if p then headshot(p.UserId, h.img) else h.img.Image = "" end
end

-------------------------------------------------------------------------------- 4: who is in Training
local function buildTraining(part)
	local root = surface(part, "Training")
	header(root, "TRAINING RANGE", nil, true)
	local countN = text(root, "0", S(0.035, 0.205), S(0.08, 0.11), CREAM, TITLE)
	local countT = text(root, "", S(0.12, 0.225), S(0.845, 0.07), TAN, BOLD)
	local list = box(root, S(0.035, 0.34), S(0.93, 0.52), INK, { BackgroundTransparency = 1 })
	local more = text(list, "", S(0, 0.98), S(1, 0.1), TAN, BOLD, RIGHT, { Visible = false })
	local foot = footer(root, true)
	text(foot, "BOARD THE HELI AT EXFIL  >", S(0.035, 0.15), S(0.93, 0.7), CREAM, TITLE)
	local max = (okC and LF.TrainingScreen.MaxNames) or 8
	local cards = {}   -- (2026-10-21, RIVALS pass) Player -> card, reused across renders; only new players pop in
	local function card()
		local face, holder = plate(list, S(0, 0), S(0.49, 0.22), PANEL)
		local h = head(face, S(0.025, 0.1), S(0.8, 0.8))
		local name = text(face, "", S(0.22, 0.18), S(0.75, 0.64), CREAM, BOLD, nil, { TextTruncate = Enum.TextTruncate.AtEnd })
		return { face = face, holder = holder, img = h.img, name = name }
	end
	local function render()
		local inside = {}
		for _, p in Players:GetPlayers() do if p:GetAttribute("InTraining") == true then table.insert(inside, p) end end
		table.sort(inside, function(a, b) return a.DisplayName < b.DisplayName end)
		countN.Visible = #inside > 0
		countT.Position = #inside > 0 and S(0.12, 0.225) or S(0.035, 0.225)
		countTo(countN, #inside)
		countT.Text = #inside == 0 and "RANGE OPEN  ·  NOBODY INSIDE RIGHT NOW" or ((#inside == 1 and "OPERATOR" or "OPERATORS") .. " TRAINING NOW")
		local keep = {}
		for i = 1, math.min(#inside, max) do
			local p = inside[i]
			keep[p] = true
			local c = cards[p]
			if not c then
				c = card(); cards[p] = c
				headshot(p.UserId, c.img)
				pop(c.holder)
			end
			c.holder.Position = centre(S(((i - 1) % 2) * 0.51, ((i - 1) // 2) * 0.25), c.holder.Size)
			c.face.BackgroundColor3 = p == player and GREEN_LO or PANEL
			c.name.Text = string.upper(p == player and (p.DisplayName .. " (YOU)") or p.DisplayName)
		end
		for p, c in cards do if not keep[p] then c.holder:Destroy(); cards[p] = nil end end
		more.Visible = #inside > max
		more.Text = "+" .. math.max(0, #inside - max) .. " MORE"
	end
	local function hook(p) p:GetAttributeChangedSignal("InTraining"):Connect(render) end
	for _, p in Players:GetPlayers() do hook(p) end
	Players.PlayerAdded:Connect(function(p) hook(p); render() end)
	Players.PlayerRemoving:Connect(function() task.defer(render) end)
	render()
end

-------------------------------------------------------------------------------- 19 / 21: duels data
local duels = { live = {}, pads = {}, modes = {} }
local duelsListeners = {}
local function readDuels()
	local okJ, d = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("LF_LiveDuels") or "")
	if okJ and type(d) == "table" then duels = d end
	for _, f in duelsListeners do task.spawn(f) end
end
ReplicatedStorage:GetAttributeChangedSignal("LF_LiveDuels"):Connect(readDuels)

local function names(list)
	if type(list) ~= "table" or #list == 0 then return "—" end
	local s = table.concat(list, " + ")
	return string.upper(s)
end

-- (2026-10-21, RIVALS pass) one pooled Duels TV row: mode badge, headshot + names per side, clock, eye + spectators
local function duelRow(parent, i)
	local face, holder = plate(parent, S(0, (i - 1) * 0.2), S(1, 0.18), PANEL, LIP, 0.12)
	local badge = box(face, S(0, 0), S(0.12, 1), WHITE)
	local bg = grad(badge, GREEN_HI, GREEN_LO)
	local r = { holder = holder, bg = bg }
	r.mode = text(badge, "", S(0.08, 0.06), S(0.84, 0.58), INK, TITLE, CENTER)
	r.kind = text(badge, "", S(0.08, 0.64), S(0.84, 0.26), INK, BOLD, CENTER)
	r.headA = head(face, S(0.135, 0.15))
	r.nameA = text(face, "", S(0.2, 0.2), S(0.25, 0.6), CREAM, BOLD, nil, { TextTruncate = Enum.TextTruncate.AtEnd })
	r.vs = text(face, "VS", S(0.455, 0.22), S(0.06, 0.56), TAN, TITLE, CENTER)
	r.headB = head(face, S(0.52, 0.15))
	r.nameB = text(face, "", S(0.585, 0.2), S(0.2, 0.6), CREAM, BOLD, nil, { TextTruncate = Enum.TextTruncate.AtEnd })
	r.st = text(face, "", S(0.79, 0.08), S(0.19, 0.46), CREAM, TITLE, RIGHT)
	r.eye = icon(face, ICON.eye, S(0.79, 0.56), S(0.05, 0.32), TAN)
	r.sub = text(face, "", S(0.79, 0.56), S(0.19, 0.32), TAN, BOLD, RIGHT)
	r.hot = box(face, S(0, 0.9), S(1, 0.1), RED)
	return r
end

local function buildDuelsTV(part)
	local root = surface(part, "DuelsTV")
	header(root, "LIVE DUELS", "ALL LOBBIES", true)
	local rowsF = box(root, S(0.03, 0.22), S(0.94, 0.66), INK, { BackgroundTransparency = 1 })
	local empty = text(rowsF, "NO DUELS RIGHT NOW", S(0, 0.22), S(1, 0.22), CREAM, TITLE, CENTER)
	local empty2 = text(rowsF, "STEP ON A PAD IN THE DUELS HALL, OR PLAY ONLINE", S(0, 0.5), S(1, 0.12), TAN, BOLD, CENTER)
	local foot = footer(root, false)
	icon(foot, ICON.matches, S(0.03, 0.18), S(0.05, 0.64), TAN)
	text(foot, "IN QUEUE", S(0.09, 0.18), S(0.18, 0.64), TAN, TITLE)
	local qn = {}
	for i, m in { "1v1", "2v2", "3v3" } do
		local x = 0.34 + (i - 1) * 0.22
		text(foot, string.upper(m), S(x, 0.22), S(0.08, 0.56), GREEN_HI, TITLE)
		qn[m] = text(foot, "0", S(x + 0.085, 0.15), S(0.11, 0.7), CREAM, TITLE)
	end
	local maxRows = (okC and LF.DuelsTV.MaxRows) or 5
	local pool = {}
	for i = 1, maxRows do pool[i] = duelRow(rowsF, i) end
	local shown = {}
	local function render()
		local rows = {}
		for _, b in duels.pads or {} do
			if b.st == "Countdown" then
				table.insert(rows, { k = "pad:" .. tostring(b.m) .. ":" .. tostring(b.id), m = b.m, a = "PAD " .. string.format("%02d", b.id), b = "",
					st = "MATCH FOUND", sub = tostring(b.cd or ""), hot = true, ranked = b.r })
			end
		end
		for _, e in duels.live or {} do
			local nowT = workspace:GetServerTimeNow(); local age = math.max(0, math.floor(nowT - (e.t or nowT)))
			local st = e.sc and tostring(e.sc) or string.format("%d:%02d", age // 60, age % 60)
			table.insert(rows, { k = e.k, m = e.m, na = e.a, nb = e.b, a = names(e.a), b = names(e.b), st = st, sp = tonumber(e.sp),
				sub = SRC[e.s] or "LIVE", ranked = e.r })
		end
		empty.Visible = #rows == 0
		empty2.Visible = #rows == 0
		local now = {}
		for i, r in pool do
			local d = rows[i]
			r.holder.Visible = d ~= nil
			if d then
				local key = d.k or (tostring(d.a) .. "|" .. tostring(d.b))
				now[key] = true
				if not shown[key] then pop(r.holder) end
				r.mode.Text = string.upper(d.m or "?")
				r.kind.Text = d.ranked and "RANKED" or "CASUAL"
				r.bg.Color = d.ranked and ColorSequence.new(OLIVE, OLIVE_LO) or ColorSequence.new(GREEN_HI, GREEN_LO)
				local two = d.b ~= ""
				setHead(r.headA, d.na)
				setHead(r.headB, two and d.nb or nil)
				local ax = r.headA.ring.Visible and 0.2 or 0.145
				r.nameA.Position = S(ax, 0.2)
				r.nameA.Size = S(two and 0.45 - ax or 0.62, 0.6)
				r.nameA.Text = d.a
				r.vs.Visible = two
				r.nameB.Visible = two
				r.nameB.Text = d.b
				r.st.Text = d.st
				r.st.TextColor3 = d.hot and RED or CREAM
				r.eye.Visible = d.sp ~= nil
				r.sub.Position = d.sp and S(0.845, 0.56) or S(0.79, 0.56)
				r.sub.Size = d.sp and S(0.135, 0.32) or S(0.19, 0.32)
				r.sub.Text = d.sp and fmt(d.sp) or d.sub
				r.sub.TextColor3 = d.hot and CREAM or TAN
				r.hot.Visible = d.hot == true
			end
		end
		shown = now
		for _, m in { "1v1", "2v2", "3v3" } do
			local q = duels.modes and duels.modes[m]
			countTo(qn[m], (q and ((q.pads or 0) + (q.online or 0))) or 0)
		end
	end
	table.insert(duelsListeners, render)
	task.spawn(function() while root.Parent do task.wait(1); render() end end)   -- live clock
	render()
end

local function buildDuelsSign(part)
	local root = surface(part, "DuelsSign")
	local cells = {}
	for i, m in { "1v1", "2v2", "3v3" } do
		-- (2026-10-21, RIVALS pass) one lipped plate per mode instead of thin yellow dividers
		local c = plate(root, S((i - 1) / 3 + 0.012, 0.08), S(1 / 3 - 0.024, 0.84), PANEL, LIP, 0.08)
		text(c, string.upper(m), S(0.08, 0.1), S(0.34, 0.4), GREEN_HI, TITLE)
		local n = text(c, "0", S(0.08, 0.5), S(0.34, 0.42), CREAM, TITLE)
		local sub = text(c, "", S(0.46, 0.2), S(0.5, 0.6), TAN, BOLD, nil, { TextWrapped = false })
		cells[m] = { n = n, sub = sub }
	end
	local function render()
		for m, c in cells do
			local q = duels.modes and duels.modes[m] or { pads = 0, online = 0 }
			countTo(c.n, (q.pads or 0) + (q.online or 0))
			c.sub.Text = (q.pads or 0) .. " PADS\n" .. (q.online or 0) .. " ONLINE"
		end
	end
	table.insert(duelsListeners, render)
	render()
end

-------------------------------------------------------------------------------- 20: likes goal + rewarded ad
local function buildLikes(part)
	local root = surface(part, "Likes")
	header(root, "LIKE THE GAME", "COMMUNITY GOAL")
	local thumb = icon(root, ICON.thumbs, S(0.1, 0.34), S(0.12, 0.22), GREEN_HI)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	local big = text(root, "0", S(0.17, 0.22), S(0.4, 0.24), CREAM, TITLE)
	local goalT = text(root, "", S(0.57, 0.28), S(0.39, 0.13), TAN, BOLD, RIGHT)
	local face = plate(root, S(0.04, 0.5), S(0.92, 0.12), INK2, LIP, 0.2)
	local fill = box(face, S(0, 0), S(0, 1), WHITE)
	grad(fill, GREEN_HI, GREEN_LO)
	local pct = text(face, "0%", S(0.02, 0.1), S(0.96, 0.8), CREAM, TITLE, RIGHT)
	local reward = text(root, "", S(0.04, 0.68), S(0.92, 0.1), TAN, BOLD)
	local foot = footer(root, true)
	text(foot, "LIKE TACTICALS ON ITS GAME PAGE TO PUSH THE BAR", S(0.035, 0.18), S(0.93, 0.64), CREAM, BOLD)
	local last, wasDone
	local function render()
		local cur = tonumber(ReplicatedStorage:GetAttribute("LF_LikesCurrent")) or 0
		local goal = math.max(1, tonumber(ReplicatedStorage:GetAttribute("LF_LikesGoal")) or 1)
		local a = math.clamp(cur / goal, 0, 1)
		countTo(big, cur)
		goalT.Text = "/  " .. fmt(goal) .. "  LIKES"
		countTo(pct, math.floor(a * 100), "%")
		if last == nil then fill.Size = S(a, 1) else TweenService:Create(fill, COUNT, { Size = S(a, 1) }):Play() end
		if last and cur > last then pop(thumb, 1.3) end   -- (2026-10-21, RIVALS pass) thumbs-up bumps on a new like
		last = cur
		local done = a >= 1
		local rw = tostring(ReplicatedStorage:GetAttribute("LF_LikesReward") or "")
		reward.Text = done and "GOAL REACHED!  " .. rw or rw
		reward.TextColor3 = done and CREAM or TAN
		if done and wasDone == false then pop(reward) end
		wasDone = done
	end
	for _, at in { "LF_LikesCurrent", "LF_LikesGoal", "LF_LikesReward" } do ReplicatedStorage:GetAttributeChangedSignal(at):Connect(render) end
	render()
end

local function buildAd(part)
	local root = surface(part, "Ad")
	header(root, "SUPPLY DROP", "REWARD")
	icon(root, ICON.gadget, S(0.04, 0.25), S(0.1, 0.18), TAN)
	text(root, (okC and LF.AdBoard.RewardText) or "", S(0.16, 0.26), S(0.8, 0.16), CREAM, TITLE, nil, { TextWrapped = true })
	local status = text(root, "", S(0.04, 0.5), S(0.92, 0.12), TAN, BOLD)
	local foot = footer(root, false)
	local footT = text(foot, "", S(0.035, 0.18), S(0.93, 0.64), TAN, BODY)
	local function render()
		if ReplicatedStorage:GetAttribute("LF_AdReady") == true then
			-- client-side check (AdService:GetAdAvailabilityNowAsync is client only; Studio answers InternalError)
			local okA, av = pcall(function() return game:GetService("AdService"):GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo) end)
			local avail = okA and av and av.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			status.Text = avail and "WALK UP AND HOLD E TO WATCH" or "NO AD AVAILABLE RIGHT NOW"
			status.TextColor3 = avail and GREEN_HI or TAN
			footT.Text = "ONE REWARD PER AD  ·  ADS SHOW ONLY WHERE ROBLOX OFFERS THEM"
		else
			status.Text = "COMING SOON"
			status.TextColor3 = TAN
			footT.Text = "REWARDED ADS ARE NOT SET UP IN THIS PLACE YET"
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("LF_AdReady"):Connect(render)
	render()
end

local BUILD = { Training = buildTraining, DuelsTV = buildDuelsTV, DuelsSign = buildDuelsSign, Likes = buildLikes, Ad = buildAd }
local FLAG = { Training = "TrainingScreen", DuelsTV = "DuelsTV", DuelsSign = "DuelsSign", Likes = "LikesBoard", Ad = "AdBoard" }
local built = {}
local function onScreen(part)
	if built[part] or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then return end
	local kind = part:GetAttribute("Screen")
	local f = BUILD[kind]
	if not f or not (okC and LF.On(FLAG[kind])) then return end
	built[part] = true
	part.AncestryChanged:Connect(function() if not part:IsDescendantOf(workspace) then built[part] = nil end end)
	local okB, err = pcall(f, part)
	if not okB then warn("[LobbyScreens] " .. tostring(kind) .. ": " .. tostring(err)) end
end

function controller.Start()
	if not okC then return end
	readDuels()
	for _, p in CollectionService:GetTagged("LobbyScreen") do onScreen(p) end
	CollectionService:GetInstanceAddedSignal("LobbyScreen"):Connect(onScreen)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt:GetAttribute("LF_WatchAd") ~= true then return end
		local ev = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Lobby")
		ev = ev and ev:FindFirstChild("LF_WatchAd")
		if ev then ev:FireServer() end
	end)
end

return controller
