-- UIKit/PlayScreen (ModuleScript): the lobby PLAY screen, full screen like Missions / Settings (one menu at a time).
-- RIVALS' play screen as a TACTICALS deployment board: no AI art, every card is a 3D scene.
--   * DEPLOY header with your operator level, CASUAL / RANKED tabs (ranked shows a 3D lock until Config.RankedLevel).
--   * Three mode cards (1V1 / 2V2 / 3V3): your avatar holding your one gun, squad mates beside you, the other team as
--     dark silhouettes opposite. Click = search online; while searching that card says SEARCHING m:ss and click cancels.
--   * TRAINING (your gun on the rack, ENTER) and LOBBY DUELS (TO PADS) below.
-- Design px at 1920x1080, converted to Scale (Kit.toScale).
--   PlayScreen.Init({ Config, getData, ask, onOpen, onClose, enterTraining, toPads, rankedOpen, level })
--   PlayScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local Tac = require(UIKit:WaitForChild("Tac"))
local C, new = Theme.color, Kit.new
local T = Tac.C
local player = Players.LocalPlayer

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local Screen = {}
local ctx = {}
local gui, root, body, blur, scrim
local isOpen = false
local chatWas
local tab = "Casual"
local strips = {} -- live status lines, updated every tick without rebuilding

-- (2026-10-18, live RIVALS party checks with Edward) the party: PartyMembers (JSON, leader first) + PartyLeader from LobbyParty
local function partyList()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PartyMembers") or "")
	return (ok and type(list) == "table") and list or {}
end
local function partyLeader(list) return player:GetAttribute("PartyLeader") or list[1] or player.UserId end
-- why this party can't take a queue of `teamSize` (RIVALS' "Whoops!" reasons), or nil
local function partyBlock(teamSize)
	local list = partyList()
	if #list <= 1 then return nil end
	if partyLeader(list) ~= player.UserId then return "Only the party leader can join a queue!" end
	if teamSize and #list > teamSize then return "This party is too big for this queue!" end
	for _, uid in list do
		local p = Players:GetPlayerByUserId(uid)
		if p and (p:GetAttribute("InDuel") == true or p:GetAttribute("DuelMatch") ~= nil) then
			return "A party member (@" .. p.Name .. ") is currently in a duel!"
		end
	end
	return nil
end
local function openParty()
	local mod = UIKit:FindFirstChild("PartyScreen")
	local ok, PS = pcall(require, mod)
	if ok and PS and PS.Open then Screen.Close(); PS.Open() end
end

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or T.bone, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3, Parent = parent })
end
local function clockText(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end
local function counts()
	local ok, t = pcall(function() return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("MM_Counts") or "{}") end)
	return (ok and type(t) == "table") and t or {}
end
local function search()
	local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
	if not (q and st) then return nil end
	return ctx.Config.QueueById(q), st, player:GetAttribute("MM_Since") or workspace:GetServerTimeNow()
end
local function onPad()
	-- PadUI hides the lobby HUD while you're on a pad; the Deploying attribute covers the rest
	return player:GetAttribute("QueueMode") ~= nil or player:GetAttribute("Deploying") == true
end

---------------------------------------------------------------------------------------------------- 3D scenes
-- a stripped, anchored copy of your character; tint = nil keeps your look, else a flat mannequin of that colour
local function rig(tint)
	local char = player.Character
	if not char then return nil end
	local was = char.Archivable
	char.Archivable = true
	local m = char:Clone()
	char.Archivable = was
	if not m then return nil end
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt") or d:IsA("ForceField") or d:IsA("Tool") or d:IsA("Highlight") then
			d:Destroy()
		elseif tint and (d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal") or d:IsA("SurfaceAppearance")) then
			d:Destroy()
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false; d.CastShadow = false
			if d.Name == "HumanoidRootPart" then d.Transparency = 1 end
			if tint then
				d.Color = tint; d.Material = Enum.Material.SmoothPlastic
				if d:IsA("MeshPart") then d.TextureID = "" end
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return m
end
-- your one gun in the right hand, barrel forward (low ready)
local function arm(m, weaponId)
	local hand = m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm")
	if not hand or not weaponId then return end
	local gun = ViewIcons.Weapon(weaponId)
	if not gun or #gun:GetChildren() == 0 then return end
	local _, size = gun:GetBoundingBox()
	-- the longest axis is the barrel: turn it to the rig's forward (-Z)
	local turn = CFrame.identity
	if size.X >= size.Y and size.X >= size.Z then turn = CFrame.Angles(0, math.rad(90), 0)
	elseif size.Y >= size.X and size.Y >= size.Z then turn = CFrame.Angles(math.rad(90), 0, 0) end
	local base = CFrame.new(hand.Position) * (m:GetPivot().Rotation)
	gun:PivotTo(base * CFrame.new(0, -0.15, -math.max(size.X, size.Y, size.Z) * 0.32) * turn)
	gun.Parent = m
end

-- the scene for a mode card: you (+ mates) on the left facing right, the other team on the right facing left
local function squadScene(parent, teamSize, ranked)
	local scene = Instance.new("Model")
	scene.Name = "Squad"
	local weapon = (ctx.getData() and ctx.getData().Loadout and ctx.getData().Loadout.Weapon) or ctx.Config.DefaultLoadout.Weapon
	local enemyTint = ranked and Color3.fromRGB(58, 38, 88) or Color3.fromRGB(34, 38, 32)
	local mateTint = Color3.fromRGB(120, 126, 108)
	local gap = 3.4
	-- the viewport camera looks from +Z towards -Z (screen right = -X), rigs face -Z by default:
	-- your team at +X (screen left) turned towards the other team and the camera, theirs mirrored
	for side = 0, 1 do
		for i = 1, teamSize do
			local tint
			if side == 1 then tint = enemyTint elseif i > 1 then tint = mateTint end
			local m = rig(tint)
			if not m then break end
			local x = (side == 0 and 1 or -1) * (2.6 + (i - 1) * gap)
			local z = -(i - 1) * 2.2 -- mates stand a step back
			local yaw = side == 0 and math.rad(125) or math.rad(-125)
			m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0))
			if side == 0 and i == 1 then arm(m, weapon) end
			m.Parent = scene
		end
	end
	if #scene:GetChildren() == 0 then scene:Destroy(); return nil end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(math.rad(-6), 0, 0), zoom = ({ 1.1, 1.4, 1.45 })[teamSize] or 1.6, still = true })
	return vp
end

---------------------------------------------------------------------------------------------------- building
local tickNow -- set below (status refresh)

-- (Edward 2026-10-16: no "4 corners box" look) RIVALS-style cards: rounded dark glass with a faint edge that lights on hover
local function edge(f, accent, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = f })
	local st = new("UIStroke", { Color = accent or Color3.new(1, 1, 1), Transparency = accent and 0.35 or 0.85, Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	local base = st.Transparency
	f.MouseEnter:Connect(function() Kit.tween(st, 0.12, { Transparency = 0.2, Color = accent or Color3.new(1, 1, 1) }) end)
	f.MouseLeave:Connect(function() Kit.tween(st, 0.12, { Transparency = base }) end)
	return st
end
local function plate(parent, x, y, w, h, accent)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.gunDeep, BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = parent })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(38, 42, 34), Color3.fromRGB(10, 12, 9)), Parent = f })
	return f, edge(f, accent)
end

-- (UI session 2026-10-16, remade on RIVALS' play screen, ref_04): a tight grid of big mode tiles (the mode name huge
-- and centred over its 3D squad scene), a tall Ranked tile on the right (locked: padlock + "Unlocked at Level N"; open:
-- click to switch the modes to ranked), Training and Lobby Duels under the modes, the red X top right. No header.
local HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local SEMI = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local function big(parent, text, size, x, y, w, h, color, align, z)
	local l = Kit.label({ Text = text, FontFace = HEAVY, TextSize = size, TextColor3 = color or Color3.new(1, 1, 1), TextXAlignment = align or Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 4, Parent = parent })
	new("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = math.max(2, math.floor(size / 28)), Transparency = 0.15, Parent = l })
	return l
end
local function tile(x, y, w, h, top, bottom)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top or Color3.fromRGB(58, 64, 54), bottom or Color3.fromRGB(14, 16, 13)), Parent = f })
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	local st = new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	f.MouseEnter:Connect(function() Kit.tween(st, 0.1, { Transparency = 0.15 }) end)
	f.MouseLeave:Connect(function() Kit.tween(st, 0.1, { Transparency = 1 }) end)
	return f
end

local MW, MH, GAP = 322, 272, 8
local STRIP = 58 -- (lobby revamp) the bottom action bar of every tile
local function modeCard(i, mode, ranked, x)
	local q = ctx.Config.QueueFor(mode.Id, ranked)
	local accent = ranked and T.violet or Color3.fromRGB(236, 232, 218)
	local card = ranked and tile(x, 0, MW, MH, Color3.fromRGB(78, 52, 112), Color3.fromRGB(20, 12, 34)) or tile(x, 0, MW, MH)
	local stage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(MW, 210), ZIndex = 2, Parent = card })
	-- the mode name, huge and centred (RIVALS)
	big(card, mode.Id, 96, 0, 70, MW, 110, Color3.new(1, 1, 1), nil, 4)
	if ranked then
		local chip = new("TextLabel", { Text = "RANKED", FontFace = HEAVY, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = T.violet,
			Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(94, 26), ZIndex = 5, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	end
	-- status strip along the bottom. (lobby revamp, graders: "Play >" in 22 px read as a small link, not the button) idle = a
	-- full-width field-green PLAY bar, so the whole card reads as one big button; the queue count is a pill top right
	local strip = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(MW, STRIP), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ZIndex = 3, Parent = card })
	local green = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)), Enabled = false, Parent = strip })
	local left = Kit.label({ Text = "", FontFace = HEAVY, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(MW - 28, STRIP), ZIndex = 4, Parent = strip })
	new("UIStroke", { Color = Color3.fromRGB(28, 44, 16), Thickness = 2, Transparency = 0.3, Parent = left })
	local right = Kit.label({ Text = "", FontFace = SEMI, TextSize = 20, TextColor3 = Color3.fromRGB(225, 225, 228), TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(MW - 214, 0), Size = UDim2.fromOffset(200, STRIP), ZIndex = 4, Parent = strip })
	local pill = new("TextLabel", { Text = "", FontFace = HEAVY, TextSize = 19, TextColor3 = Color3.fromRGB(225, 225, 228), BackgroundColor3 = Color3.fromRGB(10, 12, 9),
		BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(MW - 12, 12), Size = UDim2.fromOffset(150, 30), ZIndex = 5, Parent = card },
		{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	table.insert(strips, { q = q, left = left, right = right, strip = strip, green = green, pill = pill, card = card, ranked = ranked, mode = mode, accent = accent })
	Kit.bindButton(card, { hover = 1.03, press = 0.985 })
	card.Activated:Connect(function()
		local myQ, st = search()
		if myQ and q and myQ.Id == q.Id and st == "Searching" then ctx.ask("CancelMatch"); return end
		if myQ or onPad() or not q then return end
		local why = partyBlock(mode.TeamSize)
		if why then Kit.whoops(why) return end
		local r = ctx.ask("FindMatch", q.Id)
		if r and r.ok then Screen.Close(); return end
		-- say why on the tile itself (the lobby toasts sit under this menu)
		local msg = r and r.msg or "No answer from the server"
		if msg == "Unknown action" then msg = "Online matchmaking is offline here" end
		local entry
		for _, e in strips do if e.card == card then entry = e end end
		if entry then entry.flash = { text = msg, untilT = os.clock() + 5 } end
		tickNow()
	end)
	return stage, mode.TeamSize
end

local function render()
	strips = {}
	for _, ch in body:GetChildren() do ch:Destroy() end
	local Config = ctx.Config
	local open = ctx.rankedOpen and ctx.rankedOpen()
	if not open then tab = "Casual" end
	local ranked = tab == "Ranked"
	local stages = {}
	for i, mode in Config.Modes do
		local stage, n = modeCard(i, mode, ranked, (i - 1) * (MW + GAP))
		table.insert(stages, { stage, n })
	end
	-- Ranked: the tall tile on the right
	local RX = 3 * (MW + GAP)
	local RW, RH = 1404 - RX, MH * 2 + GAP
	local rt = tile(RX, 0, RW, RH, open and Color3.fromRGB(96, 62, 140) or Color3.fromRGB(40, 36, 48), open and Color3.fromRGB(24, 14, 40) or Color3.fromRGB(10, 9, 13))
	big(rt, "Ranked", 72, 0, 36, RW, 84)
	local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(RW / 2, 150), Size = UDim2.fromOffset(230, 230), ZIndex = 3, Parent = rt })
	local rankedSub
	if not open then
		big(rt, "UNLOCKS AT LEVEL " .. Config.RankedLevel, 30, 20, 392, RW - 40, 40, Color3.fromRGB(225, 225, 230))
		-- (lobby revamp, graders: a bare lock gives no sense of distance) how far you are: LV n / 50 on a bar
		local lv = math.max(1, (ctx.level and ctx.level()) or 1)
		local need = math.max(1, Config.RankedLevel)
		local track = new("Frame", { Position = UDim2.fromOffset(30, 446), Size = UDim2.fromOffset(RW - 60, 18), BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 4, Parent = rt }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("Frame", { Size = UDim2.fromScale(math.clamp(lv / need, 0.04, 1), 1), BackgroundColor3 = Color3.fromRGB(232, 212, 168), BorderSizePixel = 0, ZIndex = 5, Parent = track },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		big(rt, "LV " .. lv .. " / " .. need, 24, 20, 470, RW - 40, 30, Color3.fromRGB(232, 212, 168))
	else
		rankedSub = big(rt, ranked and "Ranked queues: ON" or "Ranked queues: OFF", 34, 20, 392, RW - 40, 44, ranked and T.violet:Lerp(Color3.new(1, 1, 1), 0.4) or Color3.new(1, 1, 1))
		Kit.label({ Text = ranked and "Click to go back to casual" or "Click to play rated duels", FontFace = SEMI, TextSize = 20, TextColor3 = Color3.fromRGB(205, 205, 212),
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 440), Size = UDim2.fromOffset(RW - 40, 28), ZIndex = 4, Parent = rt })
	end
	Kit.bindButton(rt, { hover = 1.02, press = 0.985 })
	rt.Activated:Connect(function()
		if not open then
			local lv = ctx.level and ctx.level() or 0
			if ctx.toast then ctx.toast(`Ranked unlocks at level {Config.RankedLevel} (you are {lv})`, "bad") end
			return
		end
		-- (2026-10-17) ranked has its own page now (UIKit.RankedScreen); the old in-place switch stays as the fallback
		if ctx.openRanked then ctx.openRanked() return end
		tab = ranked and "Casual" or "Ranked"
		render()
	end)
	-- row 2: Training (wide) + Lobby Duels
	local Y2 = MH + GAP
	local TW = 2 * MW + GAP
	local tb = tile(0, Y2, TW, MH)
	big(tb, "Training", 64, 28, 26, 420, 76, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	Kit.label({ Text = "Practice room: cover, vaults, live targets.\nTry any weapon, gadget or melee for free.", FontFace = SEMI, TextSize = 21, TextColor3 = Color3.fromRGB(215, 215, 220),
		Position = UDim2.fromOffset(32, 104), Size = UDim2.fromOffset(330, 60), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4, Parent = tb })
	-- (lobby revamp) the same green bottom bar as the mode tiles
	local tBar = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(TW, STRIP), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = tb },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)) }) })
	local tStatus = big(tBar, "ENTER", 30, 0, 0, TW, STRIP, Color3.new(1, 1, 1))
	local gunHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(330, 20), Size = UDim2.fromOffset(320, 232), ZIndex = 2, Parent = tb })
	Kit.bindButton(tb, { hover = 1.02, press = 0.985 })
	tb.Activated:Connect(function()
		if search() or onPad() then return end
		Screen.Close()
		if ctx.enterTraining then ctx.enterTraining() end
	end)
	table.insert(strips, { training = tStatus })
	local db = tile(TW + GAP, Y2, MW, MH)
	big(db, "Lobby\nDuels", 52, 0, 40, MW, 130)
	Kit.label({ Text = "Fight people in this server", FontFace = SEMI, TextSize = 19, TextColor3 = Color3.fromRGB(215, 215, 220), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 172), Size = UDim2.fromOffset(MW, 26), ZIndex = 4, Parent = db })
	-- secondary action: a dark bar (PLAY-green is for the queues)
	local dBar = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(MW, STRIP), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ZIndex = 3, Parent = db })
	big(dBar, "TO PADS", 28, 0, 0, MW, STRIP)
	Kit.bindButton(db, { hover = 1.03, press = 0.985 })
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
	-- the party column, bottom left (RIVALS): the leader at the bottom with the crown, the others stacked above, a + on top;
	-- any of them opens Your Party
	local old = root:FindFirstChild("PartyColumn")
	if old then old:Destroy() end
	local colF = new("Frame", { Name = "PartyColumn", BackgroundTransparency = 1, Position = UDim2.fromOffset(84, 560), Size = UDim2.fromOffset(110, 500), Parent = root })
	local list = partyList()
	if #list == 0 then list = { player.UserId } end
	local leader = partyLeader(list)
	local order = { leader }
	for _, uid in list do if uid ~= leader then table.insert(order, uid) end end
	local y = 500
	for i, uid in order do
		local d = i == 1 and 100 or 80
		y -= d + 8
		local h = new("ImageButton", { Name = "Head" .. i, AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(26, 28, 24), BackgroundTransparency = 0.2,
			Position = UDim2.fromOffset((110 - d) / 2, y), Size = UDim2.fromOffset(d, d), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		h:AddTag("Nonapplicable")
		task.spawn(function()
			local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok then h.Image = im end
		end)
		if i == 1 and #list > 1 then Kit.crown(h, UDim2.fromScale(0.78, 0.12), UDim2.fromScale(0.55, 0.42), 6) end
		Kit.bindButton(h, { hover = 1.06 })
		h.Activated:Connect(openParty)
	end
	if #list < 5 then
		y -= 72
		local plus = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(26, 28, 24), BackgroundTransparency = 0.3,
			Position = UDim2.fromOffset(19, y), Size = UDim2.fromOffset(72, 72), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		plus:AddTag("Nonapplicable")
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 8), BackgroundColor3 = Color3.fromRGB(200, 200, 205), BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 30), BackgroundColor3 = Color3.fromRGB(200, 200, 205), BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		Kit.bindButton(plus, { hover = 1.08 })
		plus.Activated:Connect(openParty)
	end
	Kit.toScale(root)
	-- 3D after the conversion (viewports fill their holders)
	for _, sc in stages do squadScene(sc[1], sc[2], ranked) end
	local weapon = (ctx.getData() and ctx.getData().Loadout and ctx.getData().Loadout.Weapon) or Config.DefaultLoadout.Weapon
	local gvp = ViewIcons.Viewport(gunHold, ViewIcons.Weapon(weapon), { view = ViewIcons.GunView, zoom = 0.9 })
	tb.MouseEnter:Connect(function() gvp.SetHover(true) end)
	tb.MouseLeave:Connect(function() gvp.SetHover(false) end)
	local icons = ReplicatedStorage:FindFirstChild("UIIcons")
	if not open then
		local mesh = icons and icons:FindFirstChild("Lock")
		if mesh then ViewIcons.Viewport(art, mesh:Clone(), { view = CFrame.Angles(math.rad(8), math.rad(-20), 0), zoom = 1.05 }) end
	else
		ViewIcons.Icon(art, "Trophy", { hoverTarget = rt })
	end
end

-- status lines only (every half second while open)
local function tick()
	local cnt = counts()
	local myQ, st, since = search()
	local pad = onPad()
	for _, s in strips do
		if s.training then
			s.training.Text = (myQ or pad) and "UNAVAILABLE WHILE QUEUED" or "ENTER"
		else
			local n = s.q and cnt[s.q.Id] or 0
			local mine = myQ and s.q and myQ.Id == s.q.Id
			s.green.Enabled = false
			s.left.TextXAlignment = Enum.TextXAlignment.Left
			s.pill.Visible = false
			if s.flash and os.clock() < s.flash.untilT then
				s.left.Text = s.flash.text
				s.right.Text = ""
				s.strip.BackgroundColor3 = T.red
				s.strip.BackgroundTransparency = 0.1
			elseif mine and st == "Searching" then
				s.left.Text = "Searching  " .. clockText(workspace:GetServerTimeNow() - since)
				s.right.Text = "Click to cancel"
				s.strip.BackgroundColor3 = Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = 0.1
			elseif mine then
				s.left.Text = "Match found!"
				s.right.Text = ""
				s.strip.BackgroundColor3 = Color3.fromRGB(141, 191, 90)
				s.strip.BackgroundTransparency = 0.1
			elseif myQ or pad then
				s.left.Text = myQ and ("Searching " .. myQ.Mode) or "On a lobby pad"
				s.right.Text = ""
				s.strip.BackgroundColor3 = Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = 0.35
			else
				s.left.Text = "PLAY"
				s.left.TextXAlignment = Enum.TextXAlignment.Center
				s.green.Enabled = not s.ranked
				s.pill.Visible = true
				s.pill.Text = n .. " SEARCHING"
				s.pill.TextColor3 = n > 0 and Color3.fromRGB(170, 220, 120) or Color3.fromRGB(225, 225, 228)
				local extra = ""
				if s.ranked then
					local player = game:GetService("Players").LocalPlayer
					extra = "  ·  " .. (function()
				local placed, need = player:GetAttribute("RankPlaced") or 0, player:GetAttribute("RankPlacements") or 0
				if need > 0 and placed < need then return "Placements " .. placed .. "/" .. need end
				return (player:GetAttribute("RankName") or "Bronze 1") .. "  " .. tostring(player:GetAttribute("RankElo") or 100) .. " ELO"
			end)()
				end
				s.right.Text = s.ranked and (extra:gsub("^  ·  ", "")) or ""
				if s.ranked then s.left.TextXAlignment = Enum.TextXAlignment.Left end
				s.strip.BackgroundColor3 = s.ranked and T.violet or Color3.new(1, 1, 1)
				s.strip.BackgroundTransparency = s.ranked and 0.25 or 0
			end
		end
	end
end

tickNow = function() if isOpen then tick() end end

local function header() end -- (no header row since the RIVALS remake)

local function build()
	gui = new("ScreenGui", { Name = "PlayUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local close = Kit.closeButton(UDim2.fromOffset(112, 58))
	close.Position = UDim2.fromOffset(1704, 140)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(258, 140), Size = UDim2.fromOffset(1404, 560), Parent = root })
	root.Visible = false
	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
	task.spawn(function()
		while gui.Parent do
			if isOpen then tick() end
			task.wait(0.5)
		end
	end)
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	-- the chat window steps aside while the menu is open (it covers the top left and eats clicks)
	pcall(function()
		local cw = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
		if not cw then return end
		if on then chatWas = cw.Enabled; cw.Enabled = false elseif chatWas ~= nil then cw.Enabled = chatWas; chatWas = nil end
	end)
	if on then
		gui.Enabled = true
		header()
		render()
		tick()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
	else
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

function Screen.Init(context)
	ctx = context or {}
	if not gui then build() end
	for _, a in { "PartyMembers", "PartyLeader" } do
		player:GetAttributeChangedSignal(a):Connect(function() if isOpen then render() end end)
	end
end
function Screen.Open() setOpen(true) end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end
function Screen.Refresh() if isOpen then header(); tick() end end

return Screen
