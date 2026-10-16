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

local function plate(parent, x, y, w, h, accent)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.gunDeep, BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = parent })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(38, 42, 34), Color3.fromRGB(10, 12, 9)), Parent = f })
	local br = Tac.brackets(f, accent or T.line, 20, 3)
	return f, br
end

local function modeCard(i, mode, ranked, x)
	local q = ctx.Config.QueueFor(mode.Id, ranked)
	local accent = ranked and T.violet or T.olive
	local W, H = 424, 486
	local card, br = plate(body, x, 0, W, H, ranked and T.violet or T.line)
	-- the scene, with a floor glow under the squads
	local stage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(W, 300), ZIndex = 2, Parent = card })
	-- a soft pool of the accent colour on the floor under the squads
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 270), Size = UDim2.fromOffset(W, 120), BackgroundColor3 = accent,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 1, Parent = card }, {
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	label(card, string.format("OP-%02d", i), OSWALD, 16, 16, 10, 80, 20, T.field)
	if ranked then label(card, "RANKED", OSWALD, 16, W - 116, 10, 100, 20, T.violet, Enum.TextXAlignment.Right) end
	-- name, line, pips
	local title = label(card, mode.Name, OSWALD, 72, 18, 300, 260, 80, T.bone)
	new("UIStroke", { Color = T.ink, Thickness = 2, Parent = title })
	label(card, mode.Desc or "", BODY, 17, 20, 380, W - 40, 24, T.field)
	for t = 1, mode.TeamSize do
		new("Frame", { Position = UDim2.fromOffset(W - 26 - (mode.TeamSize * 2 + 1) * 18 + (t - 1) * 18, 330), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.bone,
			BorderSizePixel = 0, ZIndex = 3, Parent = card })
		new("Frame", { Position = UDim2.fromOffset(W - 26 - mode.TeamSize * 18 + (t - 1) * 18, 330), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = ranked and T.violet or T.line,
			BorderSizePixel = 0, ZIndex = 3, Parent = card })
	end
	-- status strip
	local strip = new("Frame", { Position = UDim2.fromOffset(0, H - 52), Size = UDim2.fromOffset(W, 52), BackgroundColor3 = accent, BackgroundTransparency = 0.1,
		BorderSizePixel = 0, ZIndex = 3, Parent = card })
	local left = label(strip, "", OSWALD, 24, 18, 0, W - 36, 52, T.bone, nil, 4)
	local right = label(strip, "", OSWALD, 17, W - 218, 0, 200, 52, T.bone, Enum.TextXAlignment.Right, 4)
	table.insert(strips, { q = q, left = left, right = right, strip = strip, card = card, ranked = ranked, mode = mode, accent = accent })
	Tac.hoverBrackets(card, br)
	Kit.bindButton(card, { hover = 1.02, press = 0.985 })
	card.Activated:Connect(function()
		local myQ, st = search()
		if myQ and q and myQ.Id == q.Id and st == "Searching" then ctx.ask("CancelMatch"); return end
		if myQ or onPad() or not q then return end
		local r = ctx.ask("FindMatch", q.Id)
		if r and r.ok then Screen.Close(); return end
		-- say why on the card itself (the lobby toasts sit under this menu)
		local msg = r and r.msg or "No answer from the server"
		if msg == "Unknown action" then msg = "Online matchmaking is offline here" end
		local entry
		for _, e in strips do if e.card == card then entry = e end end
		if entry then entry.flash = { text = string.upper(msg), untilT = os.clock() + 5 } end
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
	-- tabs
	-- in the header row, clear of the Roblox chat window (top left swallows clicks)
	local tabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(470, -162), Size = UDim2.fromOffset(420, 50), Parent = body })
	for k, name in { "Casual", "Ranked" } do
		local on = tab == name
		local locked = name == "Ranked" and not open
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((k - 1) * 214, 0), Size = UDim2.fromOffset(200, 50),
			BackgroundColor3 = on and (name == "Ranked" and T.violet or T.olive) or T.gunDeep, BackgroundTransparency = on and 0.05 or 0.25, Parent = tabs })
		Tac.hoverBrackets(b, Tac.brackets(b, on and T.bone or T.line, 12, 2))
		label(b, string.upper(name), OSWALD, 26, locked and 54 or 0, 0, locked and 140 or 200, 50, locked and T.field or T.bone, locked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, 3)
		if locked then
			local lk = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(40, 40), ZIndex = 3, Parent = b })
			local icons = ReplicatedStorage:FindFirstChild("UIIcons")
			local mesh = icons and icons:FindFirstChild("Lock")
			if mesh then ViewIcons.Viewport(lk, mesh:Clone(), { view = CFrame.Angles(math.rad(8), math.rad(-20), 0), zoom = 1.1, still = true }) end
			label(b, "LV " .. Config.RankedLevel, OSWALD, 16, 136, 0, 56, 50, T.violet, Enum.TextXAlignment.Right, 3)
		end
		Kit.bindButton(b, { hover = 1.04 })
		b.Activated:Connect(function()
			if locked then
				local lv = ctx.level and ctx.level() or 0
				if ctx.toast then ctx.toast(`Ranked unlocks at level {Config.RankedLevel} (you are {lv})`, "bad") end
				return
			end
			if tab ~= name then tab = name; render() end
		end)
	end
	-- mode cards
	for i, mode in Config.Modes do
		local stage, n = modeCard(i, mode, ranked, (i - 1) * 444)
		table.insert(stages, { stage, n })
	end
	-- row 2: training + lobby duels
	local tb, tbr = plate(body, 0, 506, 868, 150, T.line)
	label(tb, "TRAINING", OSWALD, 52, 26, 14, 400, 64, T.bone)
	label(tb, "Practice room: cover, vaults, live targets. Swap your kit at the bins.", BODY, 17, 28, 78, 520, 24, T.field)
	local tStatus = label(tb, "ENTER  >", OSWALD, 22, 28, 108, 400, 30, T.oliveHi)
	local gunHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(580, 0), Size = UDim2.fromOffset(280, 150), ZIndex = 2, Parent = tb })
	Tac.hoverBrackets(tb, tbr)
	Kit.bindButton(tb, { hover = 1.01, press = 0.99 })
	tb.Activated:Connect(function()
		if search() or onPad() then return end
		Screen.Close()
		if ctx.enterTraining then ctx.enterTraining() end
	end)
	table.insert(strips, { training = tStatus })
	local db, dbr = plate(body, 888, 506, 424, 150, T.line)
	label(db, "LOBBY DUELS", OSWALD, 40, 24, 14, 400, 52, T.bone)
	label(db, "Fight people in this server on the pads.", BODY, 17, 26, 66, 400, 24, T.field)
	label(db, "TO PADS  >", OSWALD, 22, 26, 108, 300, 30, T.oliveHi)
	Tac.hoverBrackets(db, dbr)
	Kit.bindButton(db, { hover = 1.02, press = 0.98 })
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
	Kit.toScale(root)
	-- 3D after the conversion (viewports fill their holders)
	for _, s in stages do squadScene(s[1], s[2], ranked) end
	local weapon = (ctx.getData() and ctx.getData().Loadout and ctx.getData().Loadout.Weapon) or Config.DefaultLoadout.Weapon
	local gvp = ViewIcons.Viewport(gunHold, ViewIcons.Weapon(weapon), { view = ViewIcons.GunView, zoom = 0.8 })
	tb.MouseEnter:Connect(function() gvp.SetHover(true) end)
	tb.MouseLeave:Connect(function() gvp.SetHover(false) end)
end

-- status lines only (every half second while open)
local function tick()
	local cnt = counts()
	local myQ, st, since = search()
	local pad = onPad()
	for _, s in strips do
		if s.training then
			s.training.Text = (myQ or pad) and "UNAVAILABLE WHILE QUEUED" or "ENTER  >"
		else
			local n = s.q and cnt[s.q.Id] or 0
			local mine = myQ and s.q and myQ.Id == s.q.Id
			if s.flash and os.clock() < s.flash.untilT then
				s.left.Text = s.flash.text
				s.right.Text = ""
				s.strip.BackgroundColor3 = T.red
			elseif mine and st == "Searching" then
				s.left.Text = "SEARCHING  " .. clockText(workspace:GetServerTimeNow() - since)
				s.right.Text = "CLICK TO CANCEL"
				s.strip.BackgroundColor3 = T.gun
			elseif mine then
				s.left.Text = "MATCH FOUND"
				s.right.Text = ""
				s.strip.BackgroundColor3 = T.oliveHi
			elseif myQ or pad then
				s.left.Text = myQ and ("SEARCHING " .. string.upper(myQ.Mode)) or "ON A LOBBY PAD"
				s.right.Text = ""
				s.strip.BackgroundColor3 = T.line
			else
				s.left.Text = "DEPLOY  >"
				local extra = ""
				if s.ranked then
					local d = ctx.getData()
					local r = d and d.Ranked and d.Ranked[s.mode.Id]
					extra = "  ·  SR " .. tostring((r and r.Rating) or ctx.Config.StartingRating or 0)
				end
				s.right.Text = n .. " SEARCHING" .. extra
				s.strip.BackgroundColor3 = s.accent
			end
		end
	end
end

tickNow = function() if isOpen then tick() end end

local levelText, xpFill
local function header()
	local lv, into, need = 0, 0, 1
	local d = ctx.getData()
	if d then lv, into, need = ctx.Config.AccountLevel(d.XP or 0) end
	levelText.Text = "OPERATOR  LV " .. lv
	xpFill.Size = UDim2.fromScale(math.clamp(into / math.max(need, 1), 0.02, 1), 1)
end

local function build()
	gui = new("ScreenGui", { Name = "PlayUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local X0 = 294
	new("Frame", { Name = "TacBar", BackgroundColor3 = T.olive, BorderSizePixel = 0, Position = UDim2.fromOffset(X0 - 4, 96), Size = UDim2.fromOffset(10, 64), Parent = root })
	Kit.label({ Text = "DEPLOY", FontFace = OSWALD, TextSize = 70, Position = UDim2.fromOffset(X0 + 20, 86), Size = UDim2.fromOffset(400, 84), Parent = root })
	Kit.label({ Text = "Online matches  ·  one gun, one life", FontFace = BODY, TextSize = 20, TextColor3 = T.field, Position = UDim2.fromOffset(X0 + 22, 176),
		Size = UDim2.fromOffset(600, 30), Parent = root })
	-- operator level tag
	local tag = new("Frame", { Position = UDim2.fromOffset(1194, 108), Size = UDim2.fromOffset(300, 44), BackgroundColor3 = T.gunDeep, BackgroundTransparency = 0.15, Parent = root })
	Tac.brackets(tag, T.line, 10, 2)
	levelText = label(tag, "OPERATOR  LV 0", OSWALD, 20, 14, 0, 150, 44, T.bone)
	local xb = new("Frame", { Position = UDim2.fromOffset(168, 19), Size = UDim2.fromOffset(116, 6), BackgroundColor3 = T.line, BorderSizePixel = 0, Parent = tag })
	xpFill = new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = T.oliveHi, BorderSizePixel = 0, Parent = xb })
	local close = Kit.closeButton(UDim2.fromOffset(94, 48))
	close.Position = UDim2.fromOffset(1512, 106)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(X0, 268), Size = UDim2.fromOffset(1332, 660), Parent = root })
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
