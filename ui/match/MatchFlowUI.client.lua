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
local OLIVE, OLIVE_HI = Color3.fromRGB(255, 212, 0), Color3.fromRGB(255, 212, 0)
local TEAM_A = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(30, 95, 210) }  -- cream / olive (our team colours)
local TEAM_B = { Color3.fromRGB(255, 140, 60), Color3.fromRGB(214, 70, 28) }     -- red
-- (2026-10-20, Edward picked style D "Comic Ink" with RIVALS' see-through panels) Bangers headings, heavy black ink outlines,
-- hard black drop shadows, small tilts, comic yellow for "selected"; panels stay dark and see-through
local FX = Font.new("rbxasset://fonts/families/Bangers.json")
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local STENCIL = FX
local INK_YELLOW = Color3.fromRGB(255, 212, 0)
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
	new("UIStroke", { Thickness = math.max(2, size / 13), Transparency = 0, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end
-- ink: a thick black outline and a hard black drop shadow behind (a sibling, so it is converted to Scale with the rest)
local function ink(target, off, thick)
	if (thick or 4) > 0 then
		new("UIStroke", { Color = BLACK, Thickness = thick or 4, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = target })
	end
	local r = target:FindFirstChildOfClass("UICorner")
	local sh = new("Frame", { Name = target.Name .. "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0,
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
	local b = new("Frame", { Position = UDim2.fromOffset(x, 34), Size = UDim2.fromOffset(290, 84), BackgroundColor3 = WHITE, BackgroundTransparency = 0.15,
		Rotation = right and 1 or -1, ZIndex = 2, Parent = parent }, { corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }) })
	ink(b, 7, 4)
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
	local t = new("Frame", { Position = UDim2.fromOffset(888, 34), Size = UDim2.fromOffset(144, 76), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, ZIndex = 2, Parent = parent }, { corner(6) })
	ink(t, 7, 4)
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
			BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, ClipsDescendants = true, Rotation = (i % 2 == 0) and 1.5 or -1.5, ZIndex = 2, Parent = mapHolder }, { corner(6) })
		ink(t, 12, 0).BackgroundTransparency = 0.2
		local edgeCol = BLACK
		local edge = new("UIStroke", { Color = edgeCol, Thickness = 6, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = t })
		if m.random then
			label(t, "?", FX, 160, 0, th * 0.1, tw, th * 0.6, Color3.fromRGB(200, 200, 206))
		elseif m.image and m.image ~= "" then
			new("ImageLabel", { BackgroundTransparency = 1, Image = m.image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = t })
		else
			-- (2026-10-20) no picture uploaded yet (Practice Range): an aerial render of the map itself. Lobby duels keep the
			-- map's look in ReplicatedStorage.DuelMaps[id].Visual; the match place has it in Workspace[id].
			local reg = ReplicatedStorage:FindFirstChild("DuelMaps") and ReplicatedStorage.DuelMaps:FindFirstChild(m.id)
			local src = (reg and reg:FindFirstChild("Visual")) or workspace:FindFirstChild(m.id)
			if src then
				local vpf = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(150, 190, 225), Size = UDim2.fromScale(1, 1),
					Ambient = Color3.fromRGB(120, 124, 132), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.35), Parent = t })
				local world = Instance.new("WorldModel")
				for _, d in src:GetDescendants() do
					if d:IsA("BasePart") and d.Transparency < 0.95 then
						local c = d:Clone()
						for _, k in c:GetChildren() do if not (k:IsA("DataModelMesh") or k:IsA("Decal") or k:IsA("Texture") or k:IsA("SurfaceAppearance")) then k:Destroy() end end
						c.Anchored = true
						c.Parent = world
					end
				end
				world.Parent = vpf
				local cf, size = world:GetBoundingBox()
				local cam = Instance.new("Camera")
				cam.FieldOfView = 40
				local span = math.max(size.X, size.Z)
				cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-0.45 * span, 0.62 * span, 0.62 * span), cf.Position)
				cam.Parent = vpf
				vpf.CurrentCamera = cam
			end
		end
		-- striped name bar
		local barH = th * 0.2
		-- the name on a yellow comic caption strip
		local bar = new("Frame", { Position = UDim2.fromOffset(0, th - barH), Size = UDim2.fromOffset(tw, barH), BackgroundColor3 = m.random and WHITE or INK_YELLOW,
			BorderSizePixel = 0, ZIndex = 2, Parent = t }, { new("UIStroke", { Color = BLACK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local nl = label(bar, string.upper(m.name), FX, 50, 0, 0, tw, barH, BLACK, nil, 3)
		for _, k in nl:GetChildren() do if k:IsA("UIStroke") then k.Color = WHITE; k.Thickness = 2 end end
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
local mapBar = new("Frame", { Name = "MapBar", Position = UDim2.fromOffset(660, 120), Size = UDim2.fromOffset(600, 50), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = lo },
	{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
local mapBarL = label(mapBar, "Map", FX, 32, 0, 0, 600, 50, WHITE)

-- your picks: three slots in a row (each shows its pick in 3D; the open one framed)
local SLOT_W, SLOT_GAP = 86, 12
local slotRowX = 960 - (#SLOTS * SLOT_W + (#SLOTS - 1) * SLOT_GAP) / 2
local chips = {}
for i, s2 in SLOTS do
	local chip = new("TextButton", { Name = "Slot" .. s2.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(slotRowX + (i - 1) * (SLOT_W + SLOT_GAP), 186),
		Size = UDim2.fromOffset(SLOT_W, SLOT_W), BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, ZIndex = 2, Parent = lo }, { corner(6) })
	ink(chip, 6, 4)
	local edge = new("UIStroke", { Color = INK_YELLOW, Thickness = 5, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-8, -12), Size = UDim2.fromOffset(SLOT_W + 16, SLOT_W + 8), ZIndex = 3, Parent = chip })
	local q = label(chip, string.upper(s2.label), STENCIL, 18, 0, 0, SLOT_W, SLOT_W, Color3.fromRGB(110, 112, 108))
	chips[s2.id] = { chip = chip, edge = edge, art = art, q = q, index = i }
end

-- slot tabs
local TAB_W, TAB_GAP = 200, 10
local tabX = 960 - (#SLOTS * TAB_W + (#SLOTS - 1) * TAB_GAP) / 2
local tabs = {}
for i, s2 in SLOTS do
	local t = new("TextButton", { Name = "Tab" .. s2.id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(tabX + (i - 1) * (TAB_W + TAB_GAP), 300),
		Size = UDim2.fromOffset(TAB_W, 48), BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, Rotation = -2, ZIndex = 2, Parent = lo }, { corner(4) })
	ink(t, 6, 4)
	local tl = label(t, string.upper(s2.label), FX, 34, 0, 0, TAB_W, 48, WHITE)
	tabs[i] = { b = t, l = tl }
end

-- the grid: 5 per row in a scroll area
local OPT, OPT_GAP, PER_ROW = 122, 36, 5
local GRID_W, GRID_H = 5 * OPT + 4 * OPT_GAP + 40, 560
local optArea = new("ScrollingFrame", { Name = "Options", Position = UDim2.fromOffset(960 - GRID_W / 2, 368), Size = UDim2.fromOffset(GRID_W, GRID_H), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = GREY, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), Parent = lo })
local list = optArea
local ready = new("TextButton", { Name = "Ready", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1500, 900), Size = UDim2.fromOffset(300, 80),
	BackgroundColor3 = INK_YELLOW, Visible = false, Rotation = -3, ZIndex = 2, Parent = lo }, { corner(6) })
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
		if c.shown ~= id then c.shown = id; viewport(c.art, id) end
		c.edge.Transparency = (step == c.index and optArea.Visible) and 0 or 1
	end
	for i, t in tabs do
		local on = i == step and optArea.Visible
		t.b.BackgroundColor3 = on and INK_YELLOW or BLACK
		t.b.BackgroundTransparency = on and 0 or PANEL_T
		t.l.TextColor3 = on and BLACK or WHITE
		local ts = t.l:FindFirstChildOfClass("UIStroke"); if ts then ts.Color = on and WHITE or BLACK end
		t.l.Text = string.upper(SLOTS[i].label) .. ((picks[SLOTS[i].id] and not on) and "  ·  SET" or "")
	end
	ready.Visible = not switching and picks.Weapon ~= nil and picks.Melee ~= nil and picks.Gadget ~= nil
end
local switching = false -- (2026-10-18, RIVALS "Switch Weapons [M]") the picker opened between rounds
local function allPicked()
	optArea.Visible = false
	refreshChips()
	if switching then task.delay(0.35, function() switching = false end) end -- the last pick closes it (RIVALS)
end
local function optionTile(parent, x, y, id, text, onPick, kind)
	-- kind: "random" | "locked" | rarity name
	local cols = kind == "random" and { Color3.fromRGB(20, 20, 24), Color3.fromRGB(6, 6, 8) } or (RARITY[kind] or RARITY.Standard)
	local t = new("TextButton", { Name = text, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(OPT, OPT), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.2, Rotation = ((x // OPT) % 2 == 0) and -1.5 or 1.5, ZIndex = 2, Parent = parent },
		{ corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(cols[1], cols[2]) }) })
	ink(t, 7, 4)
	local scale = new("UIScale", { Parent = t })
	if kind == "random" then
		label(t, "⇄", FB, 64, 0, 6, OPT, 80, Color3.fromRGB(200, 200, 206))
	else
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-14, -34), Size = UDim2.fromOffset(OPT + 28, OPT + 8), ZIndex = 3, Parent = t })
		task.defer(viewport, art, id)
	end
	local n = label(t, string.upper(text), FX, #text > 11 and 26 or 32, -10, OPT - 40, OPT + 20, 36, WHITE)
	n.ZIndex = 4
	if kind == "locked" then
		t.BackgroundTransparency = 0.5
		new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = t }, { corner(8) })
		local lock = label(t, "🔒", FX, 40, 0, 30, OPT, 50, WHITE)
		lock.ZIndex = 6
		return t
	end
	t.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play() end)
	t.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	t.SelectionGained:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play() end)
	t.SelectionLost:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
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
	for k, e in entries do
		local row = (k - 1) // PER_ROW
		local col = (k - 1) % PER_ROW
		local x = 20 + col * (OPT + OPT_GAP)
		local y = 36 + row * rowH
		if e.kind == "random" then
			optionTile(content, x, y, nil, "Random", function() if #mine > 0 then pick(mine[math.random(#mine)]) end end, "random")
		else
			local tile = optionTile(content, x, y, e.id, nameOf(e.id), function() pick(e.id) end, e.kind)
			if picks[slot] == e.id then
				for _, k in tile:GetChildren() do if k:IsA("UIStroke") then k.Color = INK_YELLOW; k.Thickness = 6 end end
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

local phase
local function setPhase(p)
	if p == phase then return end
	phase = p
	local on = p == "Loading" or p == "MapVote" or p == "Loadout" or p == "Switch"
	gui.Enabled = on
	loading.Visible = p == "Loading"
	vote.Visible = p == "MapVote"
	lo.Visible = p == "Loadout" or p == "Switch"
	loTimer.Parent.Visible = p ~= "Switch" -- (between rounds the match HUD's timer counts down)
	-- Switch Weapons (RIVALS): the picker over the blurred match instead of the dark backdrop, no team boxes
	local sw = p == "Switch"
	-- RIVALS: the map vote / gun pick sit over the world, see-through (the loading screen stays solid)
	back.BackgroundTransparency = sw and 0.55 or (p == "Loading" and 0 or 0.3)
	for _, bx in loBoxes do local f = type(bx) == "table" and (bx.frame or (bx[1] and bx[1].h and bx[1].h.Parent)) or bx; if typeof(f) == "Instance" then f.Visible = not sw end end
	local Lighting = game:GetService("Lighting")
	local blur = Lighting:FindFirstChild("SwitchWeaponsBlur") or new("BlurEffect", { Name = "SwitchWeaponsBlur", Size = 0, Parent = Lighting })
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = sw and 16 or 0 }):Play()
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
		task.spawn(function()
			for _ = 1, 3 do tile.edge.Color = WHITE; tile.edge.Thickness = 8; task.wait(0.15); tile.edge.Color = tile.col; task.wait(0.15) end
			tile.edge.Color = WHITE
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
RunService.RenderStepped:Connect(function()
	-- (Edward 2026-10-20) Switch Weapons stays up when the next round goes live: only the match moving on closes it
	-- (or the player: Done / X / M / B)
	if switching then
		local ms = st("MatchState")
		if ms ~= "RoundEnd" and ms ~= "Countdown" and ms ~= "Live" then switching = false end
	end
	if player:GetAttribute("SwitchingWeapons") ~= (switching or nil) then player:SetAttribute("SwitchingWeapons", switching or nil) end
	setPhase(switching and "Switch" or st(STATE.Phase))
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

-- (2026-10-18) DuelHUD's Switch Weapons button / M key: PlayerScripts.SwitchWeapons:Invoke("Open" | "Close" | "Toggle") -> open?
do
	local sw = Instance.new("BindableFunction")
	sw.Name = "SwitchWeapons"
	sw.OnInvoke = function(cmd)
		local ms = st("MatchState")
		local allowed = (ms == "RoundEnd" or ms == "Countdown") and st(STATE.Phase) ~= "Loadout"
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
