-- PadUI (StarterPlayerScripts, LocalScript): the duel pads' screen UI, RIVALS' flow in TACTICALS' look.
-- Data: QueueManager's snapshot (Events.Lobby.QueueState) - nothing here is made up.
--   * On a pad: the lobby HUD steps aside and a box at the bottom shows your bay: "SQUAD UP" strip with INVITE, then
--     team A's slots | VS | team B's slots (headshots + level for players, three pulsing marks for open slots).
--     When the bay fills the VS becomes the countdown; at zero the deploy screen takes over.
--   * Deploy screen: full screen, gunmetal with the olive bracket frame, "DEPLOYING", the mode, a tip, marching marks.
--     It goes when you leave the server (teleport) or the bay resets (Studio: no teleports).
--   * Off a pad: one small JOIN box per bay that has someone on it (right side, stacked). No players on pads = no boxes.
-- Built in 1920x1080 design px on a 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer
local Lobby = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")
local Request, QueueState = Lobby:WaitForChild("Request"), Lobby:WaitForChild("QueueState")

-- (2026-10-21, RIVALS pass) the game's font decision (Edward): Oswald Bold for headings / big words / numbers, Rubik for
-- small and body text (was Montserrat Heavy / Gotham SSm)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold)
local BONE, FIELD, OLIVE, OLIVE_HI = hex("#ECE8DA"), hex("#969C8C"), hex("#6B7A3A"), hex("#8A9C4A") -- (2026-10-20, Edward) the lobby olive back (the palette pass had made it yellow)
local GUN, GUN2, DEEP, LINE = hex("#1A1D1A"), hex("#262A22"), hex("#0C0E0B"), hex("#40463A")
local TEAM = { A = hex("#ECE8DA"), B = hex("#9DB05A") } -- the pads' floor colours: team A cream, team B olive
local VIOLET = hex("#B078FF")

local gui = new("ScreenGui", { Name = "PadUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 8,
	Parent = player:WaitForChild("PlayerGui") })
local canvas = Kit.canvas(gui)

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, Parent = parent })
end
-- corner brackets (our signature instead of RIVALS' round outlines)
-- (Edward 2026-10-16: no "4 corners box" look) panels get RIVALS' soft rounded corners and a faint edge; the edge keeps
-- its colour only where colour means something (team A / B, ranked violet), otherwise it's a soft white line
local NEUTRAL_EDGE = { [Color3.fromRGB(64, 70, 58):ToHex()] = true, [Color3.fromRGB(107, 122, 58):ToHex()] = true,
	[Color3.fromRGB(236, 232, 218):ToHex()] = true }
local function brackets(p, color, len, th, z)
	if not p:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, math.clamp(math.floor(len * 0.6), 6, 14)); c.Parent = p
	end
	local st = p:FindFirstChild("_Edge") or Instance.new("UIStroke")
	st.Name = "_Edge"
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local neutral = NEUTRAL_EDGE[color:ToHex()] == true
	st.Color = neutral and Color3.new(1, 1, 1) or color
	st.Transparency = neutral and 0.85 or 0.25
	st.Thickness = neutral and 1.5 or math.max(2, math.floor(th * 0.75))
	st.Parent = p
	return st
end
local thumbs = {}
local function headshot(uid, img)
	if thumbs[uid] then img.Image = thumbs[uid] return end
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then thumbs[uid] = id; if img.Parent then img.Image = id end end
	end)
end

local snap = { bays = {}, players = {} }
local function bayOf(mode, id)
	for _, b in snap.bays do if b.mode == mode and b.id == id then return b end end
end
local function mine()
	local me = snap.players[tostring(player.UserId)]
	return me, me and bayOf(me.mode, me.bay)
end
local function modeName(mode)
	for _, m in Config.Modes do if m.Id == mode then return m.Name end end
	return string.upper(tostring(mode))
end

-- the lobby HUD steps aside while you're on a pad or deploying (RIVALS); our own UI shows instead
local HIDE = { "LobbyUI", "PlayRowUI" }
-- (2026-10-21, RIVALS pass) PadBoards no longer builds its old side panel (PadQueueUI), so the guard that hid it is gone;
-- this script's on-pad box and JOIN boxes are the only pad screen UI.
local hidden = {}
local function hideLobby(on)
	local pg = player.PlayerGui
	for _, n in HIDE do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then
			if on and g.Enabled then hidden[g] = true; g.Enabled = false
			elseif not on and hidden[g] then g.Enabled = true; hidden[g] = nil end
		end
	end
end

-- marks that pulse one after another in an open slot (RIVALS' three dots, here square marks)
local marks = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock() % 1.2
	for _, m in marks do
		if m.f.Parent then
			local u = (t - (m.i - 1) * 0.12) / 0.35
			local bump = (u > 0 and u < 1) and math.sin(u * math.pi) or 0
			m.s.Scale = 0.55 + 0.75 * bump
			m.f.BackgroundTransparency = 0.45 - 0.45 * bump
		end
	end
end)
local function slot(parent, x, y, sz, team, occ, z)
	local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = DEEP, BackgroundTransparency = 0.15, ZIndex = z, Parent = parent })
	brackets(f, occ and TEAM[team] or LINE, math.floor(sz * 0.22), 3, z + 2)
	if occ then
		local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = f })
		headshot(occ.u, img)
		local p = Players:GetPlayerByUserId(occ.u)
		local lv = p and p:GetAttribute("Level")
		if lv then
			-- level on a small chevron plate in the corner
			local plate = new("Frame", { Position = UDim2.fromOffset(-6, sz - 22), Size = UDim2.fromOffset(40, 24), BackgroundColor3 = OLIVE, ZIndex = z + 3, Parent = f })
			label(plate, tostring(lv), OSWALD, 18, 0, 0, 40, 24, BONE, Enum.TextXAlignment.Center, z + 4)
		end
		if p == player then
			label(f, "YOU", OSWALD, 15, 0, sz + 2, sz, 18, BONE, Enum.TextXAlignment.Center, z + 1)
		elseif p then
			label(f, p.DisplayName, BODY, 13, -10, sz + 2, sz + 20, 18, FIELD, Enum.TextXAlignment.Center, z + 1)
		end
	else
		local m = sz * 0.13
		for i = 1, 3 do
			local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(sz / 2 + (i - 2) * sz * 0.24, sz / 2), Size = UDim2.fromOffset(m, m),
				BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = z + 1, Parent = f })
			table.insert(marks, { f = d, s = new("UIScale", { Parent = d }), i = i })
		end
	end
	return f
end

-------------------------------------------------------------------------------------------------------------------
-- 1. on-pad box (bottom centre)
-------------------------------------------------------------------------------------------------------------------
local padBox = new("Frame", { Name = "PadBox", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = canvas })
local countLabel -- the VS / countdown label of the current box
local function buildPadBox(b, me)
	for _, c in padBox:GetChildren() do c:Destroy() end
	table.clear(marks)
	local size = math.max(1, math.floor(b.total / 2))
	local SZ = size == 1 and 128 or (size == 2 and 112 or 96)
	local GAP = 12
	local teamW = size * SZ + (size - 1) * GAP
	local W = teamW * 2 + 190 + 60
	local H = SZ + 92
	local x0 = (1920 - W) / 2
	local y0 = 1080 - 40 - H
	local accent = b.ranked and VIOLET or OLIVE
	-- strip above the box: SQUAD UP  ·  invite
	local strip = new("Frame", { Position = UDim2.fromOffset(x0, y0 - 54), Size = UDim2.fromOffset(W, 46), BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, ZIndex = 2, Parent = padBox })
	new("Frame", { Size = UDim2.fromOffset(6, 46), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 3, Parent = strip })
	label(strip, "SQUAD UP", OSWALD, 24, 22, 0, 200, 46, BONE, nil, 3)
	label(strip, "Bring a friend onto your team", BODY, 15, 140, 0, 400, 46, FIELD, nil, 3)
	local inv = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(W - 150, 6), Size = UDim2.fromOffset(140, 34), BackgroundColor3 = accent, ZIndex = 3, Parent = strip })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(b.ranked and hex("#C9A0FF") or hex("#A9D27A"), b.ranked and hex("#7A4CC0") or hex("#4C7A2E")), Parent = inv })
	label(inv, "INVITE", OSWALD, 22, 0, 0, 140, 34, BONE, Enum.TextXAlignment.Center, 4)
	Kit.bindButton(inv, { hover = 1.06 })
	inv.Activated:Connect(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then pcall(SocialService.PromptGameInvite, SocialService, player) end
	end)
	-- the box
	local box = new("Frame", { Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(W, H), BackgroundColor3 = GUN, BackgroundTransparency = 0.12, ZIndex = 2, Parent = padBox })
	brackets(box, accent, 26, 4, 6)
	label(box, modeName(b.mode) .. (b.ranked and "  RANKED" or "  DUEL"), OSWALD, 22, 26, 10, 300, 28, b.ranked and VIOLET or BONE, nil, 3)
	label(box, "PAD " .. string.format("%02d", b.id), OSWALD, 18, W - 226, 12, 200, 26, FIELD, Enum.TextXAlignment.Right, 3)
	local yS = 46
	local occ = b.occupants or {}
	local function teamSlots(team, xStart)
		for i = 1, size do
			local o
			for _, q in occ do if q.t == team and q.i == i then o = q end end
			slot(box, xStart + (i - 1) * (SZ + GAP), yS, SZ, team, o, 3)
		end
		-- team tag under the slots
		new("Frame", { Position = UDim2.fromOffset(xStart, yS + SZ + 24), Size = UDim2.fromOffset(teamW, 4), BackgroundColor3 = TEAM[team], BorderSizePixel = 0, ZIndex = 3, Parent = box })
	end
	teamSlots("A", 30)
	teamSlots("B", W - 30 - teamW)
	countLabel = label(box, "VS", OSWALD, 64, 30 + teamW, yS + SZ / 2 - 40, 190, 80, BONE, Enum.TextXAlignment.Center, 3)
	local sub = label(box, "", OSWALD, 16, 30 + teamW, yS + SZ / 2 + 30, 190, 22, FIELD, Enum.TextXAlignment.Center, 3)
	sub.Name = "Sub"
	label(box, "Step off the plate to leave", BODY, 13, 0, H - 22, W, 18, FIELD, Enum.TextXAlignment.Center, 3)
	Kit.toScale(padBox)
	return sub
end

-------------------------------------------------------------------------------------------------------------------
-- 2. deploy screen
-------------------------------------------------------------------------------------------------------------------
local TIPS = {
	"Cover wins duels: peek, shoot, get back down.",
	"Headshots end fights. Aim for the visor.",
	"Smoke a lane before you cross it.",
	"Your gadget recharges between rounds.",
	"Reload behind cover, never in the open.",
}
local deployBg = new("Frame", { Name = "Deploy", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = gui },
	{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#20251B"), hex("#080907")) }) })
-- (its own canvas above the backdrop: with Sibling ZIndex a child of the main canvas would sit under it)
local deployCanvas = Kit.canvas(gui)
deployCanvas.Name = "DeployCanvas"
deployCanvas.ZIndex = 51
local deploy = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = deployCanvas, Visible = false, ZIndex = 51 })
local dTitle, dMode, dTip, dMarks, dCount
-- (UI session 2026-10-16) RIVALS' teleport screen: the TACTICALS wordmark in the middle, the mode under it, a tip in a white
-- speech bubble bottom left, "Loading" + a counter bottom right. The match place's MatchFlowUI opens on the same look.
do
	-- (2026-10-20, Edward: "should utilize our logo") the real TACTICALS logo instead of the plain wordmark (UIKit.Logo)
	local Logo = require(UIKit:WaitForChild("Logo"))
	dTitle = Logo.Build(deploy, { Position = UDim2.fromOffset(960, 360), Size = UDim2.fromOffset(980, 331), ZIndex = 53 })
	dMode = label(deploy, "", OSWALD, 40, 360, 560, 1200, 52, OLIVE_HI, Enum.TextXAlignment.Center, 53)
	Logo.Breathe(dTitle)
	local bubble = new("Frame", { Position = UDim2.fromOffset(120, 950), Size = UDim2.fromOffset(640, 60), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 53, Parent = deploy },
		{ new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(40, 60), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 53, Parent = bubble })
	dTip = label(bubble, "", BODY, 24, 0, 0, 640, 60, Color3.fromRGB(20, 20, 24), Enum.TextXAlignment.Center, 54)
	label(deploy, "Loading", OSWALD, 46, 1440, 920, 380, 56, BONE, Enum.TextXAlignment.Right, 53)
	dCount = label(deploy, "0", OSWALD, 40, 1440, 976, 380, 50, FIELD, Enum.TextXAlignment.Right, 53)
	dMarks = {}
	Kit.toScale(deploy)
end
local deploying = false
local function showDeploy(on, mode, title)
	if on then dMode.Text = (title or "DEPLOYING") .. "  ·  " .. modeName(mode) end -- the wordmark stays (RIVALS)
	if on == deploying then return end
	deploying = on
	deployBg.Visible, deploy.Visible = on, on
	if on then
		dTip.Text = TIPS[math.random(#TIPS)]
		-- the counter climbs while we wait (RIVALS), and the same screen is handed to Roblox so it stays up through the teleport
		task.spawn(function()
			local t0 = os.clock()
			while deploying do
				dCount.Text = tostring(math.min(99, math.floor((os.clock() - t0) * 14)))
				task.wait(0.05)
			end
		end)
		pcall(function()
			local tg = gui:Clone()
			for _, c in tg:GetChildren() do
				if c.Name ~= "Deploy" and c.Name ~= "DeployCanvas" then c:Destroy() end
			end
			for _, d in tg:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
			game:GetService("TeleportService"):SetTeleportGui(tg)
		end)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- 3. JOIN boxes (bays with someone on them, while you're free)
-------------------------------------------------------------------------------------------------------------------
local joinHolder = new("Frame", { Name = "JoinBoxes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
local function busyAsk(action, ...)
	local ok, r = pcall(Request.InvokeServer, Request, action, ...)
	return ok and r
end
-- (UI session 2026-10-16) maps are per mode: a pad whose mode has no map yet carries NoMap = true (on the pad model, or on the
-- snapshot bay) and never counts down. Its UI says so instead of offering a countdown / JOIN.
local function noMap(b)
	if b.noMap or b.NoMap then return true end
	local duels = workspace:FindFirstChild("LobbyMap") and workspace.LobbyMap:FindFirstChild("Duels")
	for _, m in (duels and duels:GetChildren() or {}) do
		if m:GetAttribute("BayId") == b.id and (m:GetAttribute("Mode") == b.mode or m:GetAttribute("QueueName") == b.mode) then
			return m:GetAttribute("NoMap") == true
		end
	end
	return false
end
local function buildJoin(list)
	for _, c in joinHolder:GetChildren() do c:Destroy() end
	local y = 470
	for _, b in list do
		local size = math.max(1, math.floor(b.total / 2))
		local SZ = size == 1 and 44 or (size == 2 and 34 or 28)
		local teamW = size * SZ + (size - 1) * 4
		local W = math.max(236, teamW * 2 + 90)
		local f = new("Frame", { Position = UDim2.fromOffset(1900 - W, y), Size = UDim2.fromOffset(W, 118), BackgroundColor3 = GUN, BackgroundTransparency = 0.12, ZIndex = 2, Parent = joinHolder })
		brackets(f, b.ranked and VIOLET or OLIVE, 14, 3, 6)
		label(f, modeName(b.mode) .. "  ·  PAD " .. string.format("%02d", b.id), OSWALD, 15, 10, 4, W - 20, 18, FIELD, nil, 3)
		local occ = b.occupants or {}
		local xA, xB = (W / 2) - 36 - teamW, (W / 2) + 36
		for team, xs in { A = xA, B = xB } do
			for i = 1, size do
				local o
				for _, q in occ do if q.t == team and q.i == i then o = q end end
				local s = new("Frame", { Position = UDim2.fromOffset(xs + (i - 1) * (SZ + 4), 26), Size = UDim2.fromOffset(SZ, SZ), BackgroundColor3 = DEEP, ZIndex = 3, Parent = f })
				brackets(s, o and TEAM[team] or LINE, 8, 2, 5)
				if o then
					local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = s })
					headshot(o.u, img)
				end
			end
		end
		label(f, "VS", OSWALD, 26, W / 2 - 30, 26 + SZ / 2 - 16, 60, 32, BONE, Enum.TextXAlignment.Center, 3)
		if noMap(b) then
			label(f, "NO MAPS YET", OSWALD, 20, 0, 82, W, 28, FIELD, Enum.TextXAlignment.Center, 3)
			y += 128
			continue
		end
		local join = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((W - 140) / 2, 78), Size = UDim2.fromOffset(140, 32), BackgroundColor3 = OLIVE, ZIndex = 3, Parent = f })
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#A9D27A"), hex("#4C7A2E")), Parent = join })
		label(join, "JOIN  >", OSWALD, 20, 0, 0, 140, 32, BONE, Enum.TextXAlignment.Center, 4)
		Kit.bindButton(join, { hover = 1.06 })
		join.Activated:Connect(function() busyAsk("JoinPad", b.mode, b.id) end)
		y += 128
	end
	Kit.toScale(joinHolder)
end

-------------------------------------------------------------------------------------------------------------------
-- state -> screens
-------------------------------------------------------------------------------------------------------------------
local lastBoxKey, lastJoinKey
local function menusOpen()
	local lobby = player.PlayerGui:FindFirstChild("LobbyUI")
	return (lobby and not lobby.Enabled and not hidden[lobby]) or player:GetAttribute("InTraining") == true
		or player:GetAttribute("InCutscene") == true
end
local function refresh()
	local me, b = mine()
	local dep = player:GetAttribute("Deploying") == true or (b and b.state == "Deploying")
	-- an online match (PLAY) that was found: the same screen while the server teleports you
	local mm = player:GetAttribute("MM_Status")
	local online = not dep and (mm == "Found" or mm == "Teleporting")
	local oq = online and Config.QueueById and Config.QueueById(player:GetAttribute("MM_Queue"))
	dep = dep or online
	showDeploy(dep and true or false, (me and me.mode) or (oq and oq.Mode), online and mm == "Found" and "MATCH FOUND" or "DEPLOYING")
	-- on a pad
	if me and b and not dep then
		local key = b.mode .. b.id .. b.state .. b.count .. tostring(b.ranked)
		for _, o in b.occupants or {} do key ..= o.u .. o.t .. o.i end
		local sub
		local rebuilt = false
		if key ~= lastBoxKey then lastBoxKey = key; sub = buildPadBox(b, me); rebuilt = true end
		sub = sub or padBox:FindFirstChild("Sub", true)
		local before = countLabel.Text
		if noMap(b) then
			countLabel.Text = "VS"
			if sub then sub.Text = "NO " .. modeName(b.mode) .. " MAPS YET" end
		elseif b.duelWait then
			-- every arena is busy: the bay waits instead of counting down
			countLabel.Text = "VS"
			if sub then sub.Text = tostring(b.duelWait) end
		elseif b.state == "Countdown" then
			countLabel.Text = tostring(b.countdown or "")
			if sub then sub.Text = "DEPLOYING IN" end
		else
			countLabel.Text = "VS"
			if sub then sub.Text = (b.total - b.count) .. " MORE TO START" end
		end
		-- (2026-10-21, RIVALS pass) the VS / countdown number pops each time it changes (Kit.pop; refresh also runs every 0.3 s)
		if not rebuilt and countLabel.Text ~= before then Kit.pop(countLabel) end
		padBox.Visible = true
	else
		padBox.Visible = false
		lastBoxKey = nil
	end
	hideLobby((me and b) or dep)
	-- join boxes: real players on a bay you're not in, only while you're free in the lobby
	local list = {}
	if not me and not dep and not menusOpen() then
		for _, bb in snap.bays do
			if bb.count > 0 and bb.count < bb.total and bb.state == "Open" then table.insert(list, bb) end
		end
		table.sort(list, function(x, y) return x.mode == y.mode and x.id < y.id or x.mode < y.mode end)
		while #list > 3 do table.remove(list) end
	end
	local jk = ""
	for _, bb in list do
		jk ..= bb.mode .. bb.id .. bb.count
		for _, o in bb.occupants or {} do jk ..= o.u end
	end
	if jk ~= lastJoinKey then lastJoinKey = jk; buildJoin(list) end
end

QueueState.OnClientEvent:Connect(function(s) if type(s) == "table" then snap = s; refresh() end end)
-- Studio only: PadUITestHook:Invoke(snapshot) shows the UI for a made-up queue (a second player can't be faked otherwise)
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "PadUITestHook"
	hook.OnInvoke = function(s) snap = s; refresh(); return true end
	hook.Parent = player:WaitForChild("PlayerScripts")
end
player:GetAttributeChangedSignal("Deploying"):Connect(refresh)
player:GetAttributeChangedSignal("MM_Status"):Connect(refresh)
player:GetAttributeChangedSignal("InTraining"):Connect(refresh)
player:GetAttributeChangedSignal("InCutscene"):Connect(refresh)
task.spawn(function()
	local r = busyAsk("GetQueue")
	if r and r.snapshot then snap = r.snapshot end
	refresh()
end)
-- menus opening / closing changes whether the join boxes may show
task.spawn(function()
	while true do
		task.wait(0.3)
		refresh()
	end
end)
