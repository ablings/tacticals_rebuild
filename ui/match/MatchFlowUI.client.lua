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
local OLIVE, OLIVE_HI = Color3.fromRGB(107, 122, 58), Color3.fromRGB(150, 172, 84)
local TEAM_A = { Color3.fromRGB(198, 206, 168), Color3.fromRGB(96, 108, 56) }  -- cream / olive (our team colours)
local TEAM_B = { Color3.fromRGB(232, 92, 72), Color3.fromRGB(140, 36, 28) }     -- red
local FX = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local STENCIL = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

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
	new("UIStroke", { Thickness = math.max(1.5, size / 22), Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
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
label(loading, "TACTICALS", STENCIL, 170, 360, 300, 1200, 200, WHITE)
new("Frame", { Position = UDim2.fromOffset(760, 500), Size = UDim2.fromOffset(400, 8), BackgroundColor3 = OLIVE, BorderSizePixel = 0, Parent = loading }, { corner(4) })
local bubble = new("Frame", { Position = UDim2.fromOffset(120, 950), Size = UDim2.fromOffset(640, 60), BackgroundColor3 = WHITE, Parent = loading }, { corner(10) })
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(40, 60), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bubble })
local tipL = new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = FB, TextSize = 26, TextColor3 = Color3.fromRGB(20, 20, 24), Size = UDim2.fromScale(1, 1), Parent = bubble })
tipL:SetAttribute("dTS", 26)
label(loading, "Loading", FB, 46, 1440, 920, 380, 56, WHITE, Enum.TextXAlignment.Right)
local loadN = label(loading, "0", FB, 40, 1440, 976, 380, 50, Color3.fromRGB(205, 205, 212), Enum.TextXAlignment.Right)

---------------------------------------------------------------------------------------------------- shared: team boxes + timer
local function teamBox(parent, x, cols, right)
	local b = new("Frame", { Position = UDim2.fromOffset(x, 34), Size = UDim2.fromOffset(290, 84), BackgroundColor3 = WHITE, Parent = parent },
		{ corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }) })
	local slots = {}
	for i = 1, 3 do
		local hx = right and (90 + (i - 1) * 64) or (14 + (i - 1) * 64)
		local h = new("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(hx, 14), Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 3, Parent = b }, { corner(28) })
		local lv = new("Frame", { Position = UDim2.fromOffset(hx - 8, 50), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = Color3.fromRGB(20, 18, 24), Visible = false, ZIndex = 4, Parent = b }, { corner(7) })
		local ll = label(lv, "", FX, 17, 0, 0, 30, 26, WHITE, nil, 5)
		slots[i] = { h = h, lv = lv, ll = ll }
	end
	return slots
end
local function timerBox(parent)
	local t = new("Frame", { Position = UDim2.fromOffset(888, 34), Size = UDim2.fromOffset(144, 76), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, Parent = parent }, { corner(8) })
	return label(t, "10.0", FX, 42, 0, 0, 144, 76, WHITE)
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
				s.ll.Text = ready and "✓" or (p.bot and "BOT" or tostring(lv or "-"))
				s.lv.BackgroundColor3 = ready and Color3.fromRGB(70, 180, 60) or Color3.fromRGB(20, 18, 24)
				s.h.ImageTransparency = p.gone and 0.6 or 0
				if p.bot then s.h.Image = ""
				elseif heads[p.UserId] then s.h.Image = heads[p.UserId]
				else task.spawn(function()
					local ok, im = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
					if ok then heads[p.UserId] = im; s.h.Image = im end
				end) end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------- 2. Map vote
local vote = new("Frame", { Name = "MapVote", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
local voteBoxes = { teamBox(vote, 588, TEAM_A, false), teamBox(vote, 1042, TEAM_B, true) }
local voteTimer = timerBox(vote)
label(vote, "VOTE FOR A MAP", STENCIL, 40, 660, 136, 600, 50, WHITE)
local mapHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(250, 210), Size = UDim2.fromOffset(1420, 760), Parent = vote })
local mapTiles = {}

local refreshVotes
local function buildMaps(list)
	for _, c in mapHolder:GetChildren() do c:Destroy() end
	mapTiles = {}
	local all = table.clone(list)
	table.insert(all, { id = "Random", name = "Random", random = true })
	local n = #all
	local tw = math.min(560, (1420 - (n - 1) * 30) / n)
	local th = math.floor(tw * 0.62)
	local x0 = (1420 - (n * tw + (n - 1) * 30)) / 2
	for i, m in all do
		local t = new("TextButton", { Name = m.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x0 + (i - 1) * (tw + 30), 40), Size = UDim2.fromOffset(tw, th),
			BackgroundColor3 = Color3.fromRGB(28, 30, 26), ClipsDescendants = true, Parent = mapHolder }, { corner(10) })
		local edgeCol = m.random and Color3.fromRGB(90, 90, 96) or OLIVE_HI
		local edge = new("UIStroke", { Color = edgeCol, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = t })
		if m.random then
			label(t, "?", FX, 160, 0, th * 0.1, tw, th * 0.6, Color3.fromRGB(200, 200, 206))
		elseif m.image and m.image ~= "" then
			new("ImageLabel", { BackgroundTransparency = 1, Image = m.image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = t })
		end
		-- striped name bar
		local barH = th * 0.2
		local bar = new("Frame", { Position = UDim2.fromOffset(0, th - barH), Size = UDim2.fromOffset(tw, barH), BackgroundColor3 = BLACK, BackgroundTransparency = 0.25,
			ClipsDescendants = true, ZIndex = 2, Parent = t })
		for s = 0, math.floor(tw / 20) do
			new("Frame", { Rotation = 30, Position = UDim2.fromOffset(s * 20, -8), Size = UDim2.fromOffset(7, barH * 1.6), BackgroundColor3 = edgeCol, BackgroundTransparency = 0.6,
				BorderSizePixel = 0, ZIndex = 2, Parent = bar })
		end
		label(bar, m.name, FX, 44, 0, 0, tw, barH, WHITE, nil, 3)
		-- voters (headshots along the top)
		local voters = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(tw - 24, 56), ZIndex = 4, Parent = t },
			{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
		local count = label(t, "", FX, 34, tw - 110, 12, 96, 44, WHITE, Enum.TextXAlignment.Right, 4)
		local sc = new("UIScale", { Parent = t })
		t.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.03 }):Play() end)
		t.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
		t.Activated:Connect(function()
			send("Vote", m.id)
			player:SetAttribute("_MyVote", m.id) -- instant feedback before the server echoes MapVotes
			refreshVotes()
		end)
		mapTiles[m.id] = { t = t, edge = edge, col = edgeCol, voters = voters, count = count, tw = tw }
	end
end

refreshVotes = function()
	local ok, votes = pcall(function() return HttpService:JSONDecode(st(STATE.Votes) or "{}") end)
	votes = ok and votes or {}
	local mine = player:GetAttribute("_MyVote")
	for id, tile in mapTiles do
		local ids = table.clone(votes[id] or {})
		if mine and mine ~= id then local k = table.find(ids, player.UserId); if k then table.remove(ids, k) end end
		local hasMe = table.find(ids, player.UserId) ~= nil
		if mine == id and not hasMe then table.insert(ids, player.UserId); hasMe = true end
		for _, c in tile.voters:GetChildren() do if c:IsA("ImageLabel") then c:Destroy() end end
		for k, uid in ids do
			if k > 6 then break end
			local img = new("ImageLabel", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tile.voters },
				{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
					new("UIStroke", { Color = uid == player.UserId and WHITE or BLACK, Thickness = 2 }) })
			if heads[uid] then img.Image = heads[uid] else task.spawn(function()
				local ok2, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if ok2 then heads[uid] = im; img.Image = im end
			end) end
		end
		tile.count.Text = #ids > 0 and tostring(#ids) or ""
		tile.edge.Color = hasMe and WHITE or tile.col
		tile.edge.Thickness = hasMe and 6 or 4
	end
end

---------------------------------------------------------------------------------------------------- 3. Loadout
local lo = new("Frame", { Name = "Loadout", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
local loBoxes = { teamBox(lo, 588, TEAM_A, false), teamBox(lo, 1042, TEAM_B, true) }
local loTimer = timerBox(lo)
label(lo, "CHOOSE YOUR LOADOUT", STENCIL, 40, 560, 136, 800, 50, WHITE)
local mapChip = label(lo, "", FB, 24, 560, 184, 800, 30, Color3.fromRGB(205, 205, 212))
local slotCards, picker = {}, nil
local openSlot

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
end
local function itemName(id) return (id or "?"):gsub("(%l)(%u)", "%1 %2") end

for i, s in SLOTS do
	local x = 300 + (i - 1) * 450
	local card = new("TextButton", { Name = s.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 250), Size = UDim2.fromOffset(420, 340),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.45, Parent = lo }, { corner(12) })
	local edge = new("UIStroke", { Color = WHITE, Transparency = 1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	label(card, s.label, STENCIL, 30, 20, 12, 380, 40, Color3.fromRGB(205, 205, 212), Enum.TextXAlignment.Left)
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 50), Size = UDim2.fromOffset(380, 210), ZIndex = 3, Parent = card })
	local name = label(card, "", FX, 40, 0, 270, 420, 50, WHITE)
	local sc = new("UIScale", { Parent = card })
	card.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.03 }):Play(); edge.Transparency = 0.5 end)
	card.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play(); edge.Transparency = openSlot == s.id and 0.1 or 1 end)
	slotCards[s.id] = { card = card, art = art, name = name, edge = edge, shown = nil }
end
picker = new("Frame", { Name = "Picker", BackgroundTransparency = 1, Position = UDim2.fromOffset(300, 620), Size = UDim2.fromOffset(1320, 160), Visible = false, Parent = lo })
local ready = new("TextButton", { Name = "Ready", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(810, 900), Size = UDim2.fromOffset(300, 80),
	BackgroundColor3 = WHITE, Parent = lo }, { corner(10), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(196, 214, 120), Color3.fromRGB(92, 110, 44)) }) })
local readyL = label(ready, "READY", FX, 44, 0, 0, 300, 80, WHITE)
ready.Activated:Connect(function()
	send("Ready")
	player:SetAttribute("_Ready", true)
	readyL.Text = "READY ✓"
end)

local function owned()
	local ok, list = pcall(function() return HttpService:JSONDecode(player:GetAttribute(STATE.Owned) or "[]") end)
	return ok and list or {}
end
local ITEM_SLOT -- id -> slot, from the shared config if the match place has it
pcall(function()
	local cfg = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
	ITEM_SLOT = {}
	for id, it in cfg.Items do ITEM_SLOT[id] = it.Slot end
end)
local function openPicker(slot)
	for _, c in picker:GetChildren() do c:Destroy() end
	openSlot = slot
	for id, sc in slotCards do sc.edge.Transparency = id == slot and 0.1 or 1 end
	local list = {}
	for _, id in owned() do
		if not ITEM_SLOT or ITEM_SLOT[id] == slot then table.insert(list, id) end
	end
	local cur = player:GetAttribute(STATE.Kit[slot])
	if cur and not table.find(list, cur) then table.insert(list, 1, cur) end
	for i, id in list do
		local b = new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((i - 1) * 176, 0), Size = UDim2.fromOffset(164, 150),
			BackgroundColor3 = id == cur and Color3.fromRGB(120, 120, 126) or BLACK, BackgroundTransparency = 0.45, Parent = picker }, { corner(10) })
		if id == cur then new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b }) end
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(152, 100), ZIndex = 3, Parent = b })
		label(b, itemName(id), FB, 20, 0, 108, 164, 34, WHITE)
		b.Activated:Connect(function()
			send("Pick", slot, id)
			player:SetAttribute(STATE.Kit[slot] .. "_Pending", id)
		end)
		task.defer(viewport, art, id)
	end
	picker.Visible = #list > 0
end
for id, sc in slotCards do sc.card.Activated:Connect(function() if openSlot == id then picker.Visible = false; openSlot = nil else openPicker(id) end end) end

local function refreshLoadout()
	for _, s in SLOTS do
		local sc = slotCards[s.id]
		local cur = player:GetAttribute(STATE.Kit[s.id] .. "_Pending") or player:GetAttribute(STATE.Kit[s.id])
		if cur ~= sc.shown then
			sc.shown = cur
			sc.name.Text = cur and itemName(cur) or "—"
			viewport(sc.art, cur)
			if openSlot == s.id then openPicker(s.id) end
		end
	end
end

---------------------------------------------------------------------------------------------------- convert + phases
toScale(canvas, Vector2.new(W, H))
-- children of converted frames keep Scale; holders built later are converted against their own design size
local function convertLater(holder, size) toScale(holder, size); rescale() end
rescale()

local phase
local function setPhase(p)
	if p == phase then return end
	phase = p
	local on = p == "Loading" or p == "MapVote" or p == "Loadout"
	gui.Enabled = on
	loading.Visible = p == "Loading"
	vote.Visible = p == "MapVote"
	lo.Visible = p == "Loadout"
	if p == "Loading" then tipL.Text = TIPS[math.random(#TIPS)] end
	if p == "MapVote" then
		player:SetAttribute("_MyVote", nil)
		local ok, list = pcall(function() return HttpService:JSONDecode(st(STATE.Maps) or "[]") end)
		buildMaps(ok and list or {})
		convertLater(mapHolder, Vector2.new(1420, 760))
		fillTeams(voteBoxes); refreshVotes()
	end
	if p == "Loadout" then
		player:SetAttribute("_Ready", nil); readyL.Text = "READY"
		local chosen = st(STATE.Chosen)
		mapChip.Text = chosen and ("Map: " .. chosen) or ""
		fillTeams(loBoxes)
		for _, s in SLOTS do slotCards[s.id].shown = false; player:SetAttribute(STATE.Kit[s.id] .. "_Pending", nil) end
		picker.Visible = false; openSlot = nil
		refreshLoadout()
	end
end
-- map vote ends: the winner flashes (RIVALS) before the next phase shows
local lastChosen, lastVotes
local function onChosen()
	local tile = mapTiles[st(STATE.Chosen) or ""]
	if tile and phase == "MapVote" then
		task.spawn(function()
			for _ = 1, 3 do tile.edge.Color = WHITE; tile.edge.Thickness = 8; task.wait(0.15); tile.edge.Color = tile.col; task.wait(0.15) end
			tile.edge.Color = WHITE
		end)
	end
end
for _, s in SLOTS do
	player:GetAttributeChangedSignal(STATE.Kit[s.id]):Connect(function()
		player:SetAttribute(STATE.Kit[s.id] .. "_Pending", nil)
		if phase == "Loadout" then refreshLoadout() end
	end)
end

local loadStart = os.clock()
local teamTick
RunService.RenderStepped:Connect(function()
	setPhase(st(STATE.Phase))
	local left = math.max(0, (st(STATE.EndsAt) or 0) - workspace:GetServerTimeNow())
	if phase == "MapVote" then
		voteTimer.Text = string.format("%.1f", left)
		local v, c = st(STATE.Votes), st(STATE.Chosen)
		if v ~= lastVotes then lastVotes = v; refreshVotes() end
		if c ~= lastChosen then lastChosen = c; if c then onChosen() end end
	end
	if phase == "Loadout" then
		loTimer.Text = string.format("%.1f", left); refreshLoadout()
		teamTick = (teamTick or 0) + 1
		if teamTick % 15 == 0 then fillTeams(loBoxes) end -- ready ticks
	end
	if phase == "Loading" then loadN.Text = tostring(math.min(99, math.floor((os.clock() - loadStart) * 25))) end
end)

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
