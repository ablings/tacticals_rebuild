-- PadBoards (pass 39, lobby): the duel pads' live boards + the side panel. Data = QueueManager's snapshot
-- (Events.Lobby.QueueState). Our own TACTICALS look (RIVALS was only the reference for "icons on the board, a side
-- panel while you queue").
--   * Board over every pad: mode + pad number, team A (red) and team B (blue) slots with the players' headshots,
--     status (OPEN / WAITING FOR N MORE / DEPLOYING IN 3 / DEPLOYING...). Ranked pads in violet.
--   * Side panel (right): near a pad and not queued -> JOIN <MODE> (puts you on that pad). On a pad -> your queue:
--     both teams with headshots, status, LEAVE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Lobby = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")
local Request, QueueState = Lobby:WaitForChild("Request"), Lobby:WaitForChild("QueueState")

local BONE, FIELD, OLIVE, GUN, GUN2 = Color3.fromRGB(236, 232, 218), Color3.fromRGB(150, 156, 140), Color3.fromRGB(107, 122, 58), Color3.fromRGB(20, 23, 20), Color3.fromRGB(34, 38, 32)
local RED, BLUE, VIOLET = Color3.fromRGB(214, 52, 52), Color3.fromRGB(60, 140, 240), Color3.fromRGB(176, 120, 255)
-- [PolishDuels] team colours match the floor: team A cream, team B olive
local TEAM_A, TEAM_B = Color3.fromRGB(236, 232, 218), Color3.fromRGB(157, 176, 90)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local NEAR = 20 -- studs from a pad's post that shows the JOIN button

local snap = { bays = {}, players = {} }
local thumbs = {}
local function headshot(uid, img)
	if thumbs[uid] then img.Image = thumbs[uid] return end
	img.Image = ""
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then thumbs[uid] = id; if img.Parent then img.Image = id end end
	end)
end
local function new(class, props, parent)
	local o = Instance.new(class); for k, v in props do o[k] = v end; if parent then o.Parent = parent end; return o
end
local function brackets(p, color, len, th)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		for _, sz in { UDim2.new(0, len, 0, th), UDim2.new(0, th, 0, len) } do
			new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = sz, ZIndex = 6 }, p)
		end
	end
end
local function label(text, size, color, font, parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or BONE, FontFace = font or OSWALD,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, size + 4) }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end
local function bayOf(mode, id)
	for _, b in snap.bays do if b.mode == mode and b.id == id then return b end end
end
local function statusText(b)
	if not b then return "OPEN", FIELD end
	if b.state == "Countdown" then return "MATCH FOUND  ·  DEPLOYING IN " .. tostring(b.countdown or ""), BONE end
	if b.state == "Deploying" then return "DEPLOYING...", BONE end
	if b.count == 0 then return "OPEN  ·  STEP ON A PLATE", FIELD end
	return "WAITING FOR " .. (b.total - b.count) .. " MORE", FIELD
end

-- a team row: coloured tag + N slots (headshot or empty "+")
local function teamRow(parent, team, size, occupants, slotPx, y, nameTags)
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, slotPx), ZIndex = 3 }, parent)
	new("Frame", { BackgroundColor3 = team == "A" and TEAM_A or TEAM_B, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0), ZIndex = 3 }, row)
	label(team == "A" and "TEAM A" or "TEAM B", math.floor(slotPx * 0.28), team == "A" and TEAM_A or TEAM_B, OSWALD, row,
		{ Position = UDim2.new(0, 12, 0.5, -slotPx * 0.17), Size = UDim2.new(0, slotPx * 1.4, 0, slotPx * 0.34), ZIndex = 3 })
	for i = 1, size do
		local occ
		for _, o in occupants do if o.t == team and o.i == i then occ = o end end
		local x = slotPx * 1.55 + (i - 1) * (slotPx + 8)
		local slot = new("Frame", { BackgroundColor3 = GUN2, BorderSizePixel = 0, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(0, slotPx, 0, slotPx), ZIndex = 3 }, row)
		new("UIStroke", { Color = occ and (team == "A" and TEAM_A or TEAM_B) or Color3.fromRGB(64, 70, 58), Thickness = 2 }, slot)
		if occ then
			local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, slot)
			headshot(occ.u, img)
			if nameTags then
				local p = Players:GetPlayerByUserId(occ.u)
				label(p and (p == player and "YOU" or p.DisplayName) or "", 12, p == player and BONE or FIELD, BODY, slot,
					{ Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(1, 20, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
			end
		else
			label("+", math.floor(slotPx * 0.5), Color3.fromRGB(84, 90, 76), OSWALD, slot, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		end
	end
	return row
end

-- // boards over the pads ------------------------------------------------------------------------------
local pads = {} -- [model] = board gui
local function drawBoard(model)
	local holo = model:FindFirstChild("Holo"); if not holo then return end
	local old = holo:FindFirstChild("Display"); if old and old:IsA("BillboardGui") then old.Enabled = false end
	local gui = pads[model]
	if not gui then
		gui = new("BillboardGui", { Name = "PadBoard", Size = UDim2.new(11, 0, 6, 0), StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0), LightInfluence = 0,
			MaxDistance = 110, AlwaysOnTop = false, ResetOnSpawn = false, Adornee = holo }, player.PlayerGui)
		pads[model] = gui
	end
	gui:ClearAllChildren()
	local mode, id, size = model:GetAttribute("Mode"), model:GetAttribute("BayId"), model:GetAttribute("TeamSize") or 1
	local b = bayOf(mode, id)
	local ranked = b and b.ranked
	-- fixed 440 x 240 canvas scaled as one piece to whatever size the billboard is at this distance
	local CW, CH = 440, 240
	local panel = new("Frame", { BackgroundColor3 = GUN, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromOffset(CW, CH) }, gui)
	local sc = new("UIScale", {}, panel)
	local function fit() local a = gui.AbsoluteSize; if a.X > 0 then sc.Scale = a.X / CW end end
	fit(); gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	brackets(panel, ranked and VIOLET or OLIVE, 26, 4)
	new("UIPadding", { PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0), PaddingTop = UDim.new(0.07, 0) }, panel)
	label(string.upper(mode or "?") .. (ranked and "  RANKED" or "  DUEL"), 36, ranked and VIOLET or BONE, OSWALD, panel, { Size = UDim2.new(0.7, 0, 0, 40) })
	label("PAD " .. tostring(id or ""), 22, FIELD, OSWALD, panel, { Position = UDim2.new(0.7, 0, 0, 10), Size = UDim2.new(0.3, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right })
	local occ = b and b.occupants or {}
	local px = size >= 3 and 50 or 56
	teamRow(panel, "A", size, occ, px, 54, false)
	teamRow(panel, "B", size, occ, px, 54 + px + 10, false)
	local st, col = statusText(b)
	label(st, 20, col, OSWALD, panel, { Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
end

-- // side panel ------------------------------------------------------------------------------------------
local side = new("ScreenGui", { Name = "PadQueueUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7 }, player:WaitForChild("PlayerGui"))
local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(320, 330) }, side)
new("UIScale", { Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 900, 0.65, 1.15) }, holder)
local busy = false
local function ask(action, ...)
	if busy then return end
	busy = true
	local ok, r = pcall(Request.InvokeServer, Request, action, ...)
	busy = false
	return ok and r
end
local lastKey
local function drawSide(nearPad)
	local me = snap.players[tostring(player.UserId)]
	local key = me and ("Q" .. me.mode .. me.bay) or (nearPad and ("N" .. nearPad:GetAttribute("Mode") .. tostring(nearPad:GetAttribute("BayId"))) or "")
	local b = me and bayOf(me.mode, me.bay) or (nearPad and bayOf(nearPad:GetAttribute("Mode"), nearPad:GetAttribute("BayId")))
	key ..= b and (b.state .. b.count .. tostring(b.countdown) .. #b.occupants) or ""
	if key == lastKey then return end
	lastKey = key
	holder:ClearAllChildren()
	new("UIScale", { Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 900, 0.65, 1.15) }, holder)
	if player:GetAttribute("InTraining") then return end
	if me then
		-- queued: both teams, status, LEAVE
		local size = b and (b.total / 2) or 1
		local px0 = size >= 3 and 50 or 56
		local panel = new("Frame", { BackgroundColor3 = GUN, BackgroundTransparency = 0.08, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 62 + 2 * px0 + 26 + 54 + 26 + 66) }, holder)
		brackets(panel, (b and b.ranked) and VIOLET or OLIVE, 18, 3)
		new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 14) }, panel)
		label("QUEUED", 14, OLIVE, OSWALD, panel)
		label(string.upper(me.mode) .. ((b and b.ranked) and "  RANKED" or "  DUEL") .. "  ·  PAD " .. me.bay, 26, (b and b.ranked) and VIOLET or BONE, OSWALD, panel, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30) })
		local occ = b and b.occupants or {}
		local px = size >= 3 and 50 or 56
		teamRow(panel, "A", size, occ, px, 62, true)
		teamRow(panel, "B", size, occ, px, 62 + px + 26, true)
		local st, col = statusText(b)
		label(st, 16, col, OSWALD, panel, { Position = UDim2.new(0, 0, 0, 62 + 2 * px + 54), Size = UDim2.new(1, 0, 0, 20) })
		local leave = new("TextButton", { Text = "LEAVE QUEUE", FontFace = OSWALD, TextSize = 18, TextColor3 = BONE, AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(46, 50, 42), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 40) }, panel)
		brackets(leave, OLIVE, 10, 2)
		leave.MouseEnter:Connect(function() TweenService:Create(leave, TweenInfo.new(0.12), { BackgroundColor3 = RED }):Play() end)
		leave.MouseLeave:Connect(function() TweenService:Create(leave, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(46, 50, 42) }):Play() end)
		leave.Activated:Connect(function() ask("LeaveQueue") end)
		if b and b.state ~= "Open" then leave.Visible = false end
	elseif nearPad and b and b.state == "Open" and b.count < b.total and not player:GetAttribute("MM_Queue") then
		-- near a pad: the JOIN button
		local mode, id = nearPad:GetAttribute("Mode"), nearPad:GetAttribute("BayId")
		local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = OLIVE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 92) }, holder)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(157, 176, 90), Color3.fromRGB(80, 96, 40)) }, btn)
		brackets(btn, BONE, 16, 3)
		label("JOIN " .. string.upper(mode) .. (b.ranked and " RANKED" or " DUEL") .. "  >", 30, BONE, OSWALD, btn, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 34) })
		label(`PAD {id}  ·  {b.count} / {b.total} PLAYERS  ·  or step onto a plate`, 13, Color3.fromRGB(226, 230, 200), BODY, btn, { Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 16) })
		btn.Activated:Connect(function() ask("JoinPad", mode, id) end)
	end
end

-- // loop --------------------------------------------------------------------------------------------------
local function allPads()
	local list = {}
	local duels = workspace:FindFirstChild("LobbyMap") and workspace.LobbyMap:FindFirstChild("Duels")
	for _, m in (duels and duels:GetChildren() or {}) do if m:IsA("Model") and m:GetAttribute("BayId") then table.insert(list, m) end end
	return list
end
local function redrawBoards() for _, m in allPads() do drawBoard(m) end end
QueueState.OnClientEvent:Connect(function(s) if type(s) == "table" then snap = s; redrawBoards(); lastKey = nil end end)
task.spawn(function()
	local r = ask("GetQueue")
	if r and r.snapshot then snap = r.snapshot end
	redrawBoards()
end)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt; if acc < 0.25 then return end; acc = 0
	local c = player.Character; local root = c and c:FindFirstChild("HumanoidRootPart")
	local near, best
	if root then
		for _, m in allPads() do
			local holo = m:FindFirstChild("Holo")
			local d = holo and (holo.Position - root.Position).Magnitude
			if d and d < NEAR and (not best or d < best) then near, best = m, d end
		end
	end
	drawSide(near)
end)
