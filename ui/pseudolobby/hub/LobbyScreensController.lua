-- Controllers/LobbyScreensController (client, lobby place): the lobby feature screens (notes/features_done.md).
-- Each screen is a Part tagged "LobbyScreen" with attribute Screen = Training | DuelsTV | DuelsSign | Likes | Ad. The UI is a
-- SurfaceGui in PlayerGui adorned to that part (Front face), so the part can be re-parented into a TV kit model later
-- without touching this code. Every Position/Size is Scale (Edward's rule); canvas = 100 px per stud of the part face.
-- Data: Training = players' InTraining attribute; DuelsTV / DuelsSign = ReplicatedStorage attribute LF_LiveDuels
-- (LobbyFeaturesManager); Likes = LF_LikesCurrent / LF_LikesGoal / LF_LikesReward; Ad = LF_AdReady (+ Events.Lobby.LF_WatchAd).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local controller = {}

local player = Players.LocalPlayer
local okC, LF = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyFeaturesConfig", 10)) end)

-- palette (Tacticals loading screen)
local INK, INK2, PANEL = Color3.fromRGB(10, 12, 10), Color3.fromRGB(22, 25, 21), Color3.fromRGB(30, 34, 29)
local CREAM, SAGE, WARM = Color3.fromRGB(236, 232, 218), Color3.fromRGB(167, 173, 152), Color3.fromRGB(200, 196, 186)
local OLIVE, DOLIVE = Color3.fromRGB(255, 212, 0), Color3.fromRGB(255, 212, 0)
local RED = Color3.fromRGB(196, 64, 52)
local TITLE = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

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
local function fmt(n) n = math.floor(tonumber(n) or 0); local s = tostring(n); local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (r:gsub("^,", "")) end

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
		CanvasSize = Vector2.new(math.floor(part.Size.X * 100), math.floor(part.Size.Y * 100)), LightInfluence = 0, Brightness = 1.4,
		MaxDistance = 180, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true }, player:WaitForChild("PlayerGui"))
	local root = box(gui, S(0, 0), S(1, 1), INK)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(INK2, INK) }, root)
	part.AncestryChanged:Connect(function() if not part:IsDescendantOf(workspace) then gui:Destroy() end end)
	return root, gui
end
-- header bar: olive tab + title + right tag
local function header(root, title, tag, h)
	h = h or 0.17
	local bar = box(root, S(0, 0), S(1, h), INK)
	box(bar, S(0, 0), S(0.012, 1), OLIVE)
	text(bar, title, S(0.035, 0.12), S(0.6, 0.76), CREAM, TITLE)
	local t = tag and text(bar, tag, S(0.5, 0.25), S(0.42, 0.5), OLIVE, BOLD, Enum.TextXAlignment.Right)
	box(root, S(0, h), S(1, 0.012), DOLIVE)
	return bar, t
end
local function liveDot(parent, pos, size)
	local d = box(parent, pos, size, OLIVE, { SizeConstraint = Enum.SizeConstraint.RelativeYY })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
	TweenService:Create(d, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.7 }):Play()
	return d
end
local function clear(f) for _, c in f:GetChildren() do if not c:IsA("UIGridStyleLayout") then c:Destroy() end end end

-------------------------------------------------------------------------------- 4: who is in Training
local function buildTraining(part)
	local root = surface(part, "Training")
	header(root, "TRAINING RANGE", "LIVE")
	liveDot(root, S(0.955, 0.06), S(0.05, 0.05))
	local count = text(root, "", S(0.035, 0.21), S(0.93, 0.1), SAGE, BOLD)
	local list = box(root, S(0.035, 0.34), S(0.93, 0.52), INK, { BackgroundTransparency = 1 })
	local foot = box(root, S(0, 0.885), S(1, 0.115), DOLIVE)
	text(foot, "BOARD THE HELI AT EXFIL  >", S(0.035, 0.15), S(0.93, 0.7), CREAM, TITLE)
	local max = (okC and LF.TrainingScreen.MaxNames) or 8
	local function render()
		clear(list)
		local inside = {}
		for _, p in Players:GetPlayers() do if p:GetAttribute("InTraining") == true then table.insert(inside, p) end end
		table.sort(inside, function(a, b) return a.DisplayName < b.DisplayName end)
		count.Text = #inside == 0 and "RANGE OPEN  ·  NOBODY INSIDE RIGHT NOW" or (#inside .. (#inside == 1 and " OPERATOR" or " OPERATORS") .. " TRAINING NOW")
		for i = 1, math.min(#inside, max) do
			local p = inside[i]
			local col, row = (i - 1) % 2, (i - 1) // 2
			local card = box(list, S(col * 0.51, row * 0.25), S(0.49, 0.22), PANEL)
			box(card, S(0, 0), S(0.012, 1), p == player and CREAM or OLIVE)
			local img = new("ImageLabel", { BackgroundColor3 = INK2, BorderSizePixel = 0, Position = S(0.03, 0.08), Size = S(0.84, 0.84), SizeConstraint = Enum.SizeConstraint.RelativeYY }, card)
			headshot(p.UserId, img)
			text(card, string.upper(p == player and (p.DisplayName .. " (YOU)") or p.DisplayName), S(0.22, 0.18), S(0.75, 0.64), CREAM, BOLD, nil, { TextTruncate = Enum.TextTruncate.AtEnd })
		end
		if #inside > max then text(list, "+" .. (#inside - max) .. " MORE", S(0, 0.98), S(1, 0.1), SAGE, BOLD, Enum.TextXAlignment.Right) end
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

local function buildDuelsTV(part)
	local root = surface(part, "DuelsTV")
	header(root, "LIVE DUELS", "ALL LOBBIES")
	liveDot(root, S(0.955, 0.06), S(0.05, 0.05))
	local rowsF = box(root, S(0.03, 0.21), S(0.94, 0.66), INK, { BackgroundTransparency = 1 })
	local foot = box(root, S(0, 0.885), S(1, 0.115), PANEL)
	local footT = text(foot, "", S(0.03, 0.15), S(0.94, 0.7), SAGE, BOLD)
	local maxRows = (okC and LF.DuelsTV.MaxRows) or 5
	local function render()
		clear(rowsF)
		local rows = {}
		for _, b in duels.pads or {} do
			if b.st == "Countdown" then table.insert(rows, { m = b.m, a = "PAD " .. string.format("%02d", b.id), b = "", st = "MATCH FOUND · " .. tostring(b.cd or ""), hot = true }) end
		end
		for _, e in duels.live or {} do
			local nowT = workspace:GetServerTimeNow(); local age = math.max(0, math.floor(nowT - (e.t or nowT)))
			local st = e.sc and ("LIVE · " .. e.sc) or string.format("LIVE · %d:%02d", age // 60, age % 60)
			table.insert(rows, { m = e.m, a = names(e.a), b = names(e.b), st = st, ranked = e.r })
		end
		if #rows == 0 then
			text(rowsF, "NO DUELS RIGHT NOW", S(0, 0.22), S(1, 0.22), CREAM, TITLE, Enum.TextXAlignment.Center)
			text(rowsF, "STEP ON A PAD IN THE DUELS HALL, OR PLAY ONLINE", S(0, 0.5), S(1, 0.12), SAGE, BOLD, Enum.TextXAlignment.Center)
		end
		for i = 1, math.min(#rows, maxRows) do
			local r = rows[i]
			local y = (i - 1) * 0.2
			local row = box(rowsF, S(0, y), S(1, 0.18), PANEL)
			local badge = box(row, S(0, 0), S(0.13, 1), r.ranked and DOLIVE or OLIVE)
			text(badge, string.upper(r.m or "?"), S(0.08, 0.15), S(0.84, 0.7), INK, TITLE, Enum.TextXAlignment.Center)
			if r.b ~= "" then
				text(row, r.a, S(0.16, 0.18), S(0.3, 0.64), CREAM, BOLD, Enum.TextXAlignment.Right, { TextTruncate = Enum.TextTruncate.AtEnd })
				text(row, "VS", S(0.47, 0.22), S(0.06, 0.56), OLIVE, TITLE, Enum.TextXAlignment.Center)
				text(row, r.b, S(0.54, 0.18), S(0.24, 0.64), CREAM, BOLD, nil, { TextTruncate = Enum.TextTruncate.AtEnd })
			else
				text(row, r.a, S(0.16, 0.18), S(0.5, 0.64), CREAM, BOLD)
			end
			text(row, r.st, S(0.79, 0.24), S(0.19, 0.52), r.hot and CREAM or SAGE, BOLD, Enum.TextXAlignment.Right)
			if r.hot then box(row, S(0, 0.92), S(1, 0.08), RED) end
		end
		local parts = {}
		for _, m in { "1v1", "2v2", "3v3" } do
			local q = duels.modes and duels.modes[m]
			table.insert(parts, string.upper(m) .. " " .. ((q and (q.pads + q.online)) or 0))
		end
		footT.Text = "IN QUEUE   " .. table.concat(parts, "   ·   ")
	end
	table.insert(duelsListeners, render)
	task.spawn(function() while root.Parent do task.wait(1); render() end end)   -- live clock
	render()
end

local function buildDuelsSign(part)
	local root = surface(part, "DuelsSign")
	local cells = {}
	for i, m in { "1v1", "2v2", "3v3" } do
		local c = box(root, S((i - 1) / 3, 0), S(1 / 3, 1), INK, { BackgroundTransparency = 1 })
		if i > 1 then box(c, S(0, 0.15), S(0.006, 0.7), DOLIVE) end
		text(c, string.upper(m), S(0.08, 0.12), S(0.34, 0.44), OLIVE, TITLE)
		local n = text(c, "0", S(0.08, 0.5), S(0.34, 0.4), CREAM, TITLE)
		local sub = text(c, "", S(0.44, 0.2), S(0.52, 0.6), SAGE, BOLD, nil, { TextWrapped = false })
		cells[m] = { n = n, sub = sub }
	end
	local function render()
		for m, c in cells do
			local q = duels.modes and duels.modes[m] or { pads = 0, online = 0 }
			c.n.Text = tostring((q.pads or 0) + (q.online or 0))
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
	local big = text(root, "", S(0.04, 0.24), S(0.92, 0.2), CREAM, TITLE)
	local barBg = box(root, S(0.04, 0.5), S(0.92, 0.1), PANEL)
	local fill = box(barBg, S(0, 0), S(0, 1), OLIVE)
	local pct = text(barBg, "", S(0.02, 0.1), S(0.96, 0.8), CREAM, BOLD, Enum.TextXAlignment.Right)
	local reward = text(root, "", S(0.04, 0.66), S(0.92, 0.1), SAGE, BOLD)
	local foot = box(root, S(0, 0.885), S(1, 0.115), DOLIVE)
	text(foot, "LIKE TACTICALS ON ITS GAME PAGE TO PUSH THE BAR", S(0.035, 0.18), S(0.93, 0.64), CREAM, BOLD)
	local function render()
		local cur = tonumber(ReplicatedStorage:GetAttribute("LF_LikesCurrent")) or 0
		local goal = math.max(1, tonumber(ReplicatedStorage:GetAttribute("LF_LikesGoal")) or 1)
		local a = math.clamp(cur / goal, 0, 1)
		big.Text = fmt(cur) .. "  /  " .. fmt(goal) .. "  LIKES"
		fill.Size = S(a, 1)
		pct.Text = math.floor(a * 100) .. "%"
		reward.Text = a >= 1 and "GOAL REACHED!  " .. tostring(ReplicatedStorage:GetAttribute("LF_LikesReward") or "") or tostring(ReplicatedStorage:GetAttribute("LF_LikesReward") or "")
	end
	for _, at in { "LF_LikesCurrent", "LF_LikesGoal", "LF_LikesReward" } do ReplicatedStorage:GetAttributeChangedSignal(at):Connect(render) end
	render()
end

local function buildAd(part)
	local root = surface(part, "Ad")
	header(root, "SUPPLY DROP", "REWARD")
	text(root, (okC and LF.AdBoard.RewardText) or "", S(0.04, 0.26), S(0.92, 0.16), CREAM, TITLE, nil, { TextWrapped = true })
	local status = text(root, "", S(0.04, 0.5), S(0.92, 0.12), SAGE, BOLD)
	local foot = box(root, S(0, 0.885), S(1, 0.115), PANEL)
	local footT = text(foot, "", S(0.035, 0.18), S(0.93, 0.64), SAGE, BOLD)
	local function render()
		if ReplicatedStorage:GetAttribute("LF_AdReady") == true then
			-- client-side check (AdService:GetAdAvailabilityNowAsync is client only; Studio answers InternalError)
			local okA, av = pcall(function() return game:GetService("AdService"):GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo) end)
			local avail = okA and av and av.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			status.Text = avail and "WALK UP AND HOLD E TO WATCH" or "NO AD AVAILABLE RIGHT NOW"
			footT.Text = "ONE REWARD PER AD  ·  ADS SHOW ONLY WHERE ROBLOX OFFERS THEM"
		else
			status.Text = "COMING SOON"
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
