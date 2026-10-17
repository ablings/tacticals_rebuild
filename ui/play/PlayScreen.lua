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
	-- status strip along the bottom
	local strip = new("Frame", { Position = UDim2.fromOffset(0, MH - 44), Size = UDim2.fromOffset(MW, 44), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ZIndex = 3, Parent = card })
	local left = Kit.label({ Text = "", FontFace = HEAVY, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(MW - 28, 44), ZIndex = 4, Parent = strip })
	local right = Kit.label({ Text = "", FontFace = SEMI, TextSize = 16, TextColor3 = Color3.fromRGB(205, 205, 212), TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(MW - 214, 0), Size = UDim2.fromOffset(200, 44), ZIndex = 4, Parent = strip })
	table.insert(strips, { q = q, left = left, right = right, strip = strip, card = card, ranked = ranked, mode = mode, accent = accent })
	Kit.bindButton(card, { hover = 1.03, press = 0.985 })
	card.Activated:Connect(function()
		local myQ, st = search()
		if myQ and q and myQ.Id == q.Id and st == "Searching" then ctx.ask("CancelMatch"); return end
		if myQ or onPad() or not q then return end
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
		big(rt, "Unlocked at\nLevel " .. Config.RankedLevel, 40, 20, 392, RW - 40, 100, Color3.fromRGB(225, 225, 230))
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
	Kit.label({ Text = "Practice room: cover, vaults, live targets.\nSwap your gun at the crates.", FontFace = SEMI, TextSize = 21, TextColor3 = Color3.fromRGB(215, 215, 220),
		Position = UDim2.fromOffset(32, 104), Size = UDim2.fromOffset(330, 60), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4, Parent = tb })
	local tStatus = big(tb, "Enter  >", 30, 30, MH - 66, 330, 40, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
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
	big(db, "To Pads  >", 28, 0, MH - 64, MW, 40)
	Kit.bindButton(db, { hover = 1.03, press = 0.985 })
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
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
			s.training.Text = (myQ or pad) and "Unavailable while queued" or "Enter  >"
		else
			local n = s.q and cnt[s.q.Id] or 0
			local mine = myQ and s.q and myQ.Id == s.q.Id
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
				s.strip.BackgroundColor3 = Color3.fromRGB(70, 180, 60)
				s.strip.BackgroundTransparency = 0.1
			elseif myQ or pad then
				s.left.Text = myQ and ("Searching " .. myQ.Mode) or "On a lobby pad"
				s.right.Text = ""
				s.strip.BackgroundColor3 = Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = 0.35
			else
				s.left.Text = "Play  >"
				local extra = ""
				if s.ranked then
					local player = game:GetService("Players").LocalPlayer
					extra = "  ·  " .. (function()
				local placed, need = player:GetAttribute("RankPlaced") or 0, player:GetAttribute("RankPlacements") or 0
				if need > 0 and placed < need then return "Placements " .. placed .. "/" .. need end
				return (player:GetAttribute("RankName") or "Bronze 1") .. "  " .. tostring(player:GetAttribute("RankElo") or 100) .. " ELO"
			end)()
				end
				s.right.Text = n .. " searching" .. extra
				s.strip.BackgroundColor3 = s.ranked and T.violet or Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = s.ranked and 0.25 or 0.35
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
end
function Screen.Open() setOpen(true) end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end
function Screen.Refresh() if isOpen then header(); tick() end end

return Screen
