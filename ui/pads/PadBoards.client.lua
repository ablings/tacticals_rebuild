-- PadBoards (pass 39, lobby): the duel pads' live boards. Data = QueueManager's snapshot (Events.Lobby.QueueState).
-- (2026-10-21, RIVALS pass) RIVALS' pad wall: one card per plate (team A | VS | team B) with a big "n/m" count and the
-- players' headshots, mode + pad on top, one status line under it. Built in Scale inside the billboard (no fixed px canvas),
-- built once per pad and then only updated: the count pops (Kit.pop) when it changes, a joiner's headshot pops in.
-- The old side panel (PadQueueUI: JOIN near a pad / your queue) is gone: PadUI replaced it and only hid it, while it
-- was still rebuilt here 4 times a second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Lobby = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")
local Request, QueueState = Lobby:WaitForChild("Request"), Lobby:WaitForChild("QueueState")
local Kit = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Kit")) -- (2026-10-21, RIVALS pass) shared pop / popIn

local BONE, FIELD, OLIVE, GUN, GUN2 = Color3.fromRGB(236, 232, 218), Color3.fromRGB(150, 156, 140), Color3.fromRGB(107, 122, 58), Color3.fromRGB(20, 23, 20), Color3.fromRGB(34, 38, 32)
local VIOLET = Color3.fromRGB(150, 116, 52) -- (2026-10-21, AI-tells cleanup) ranked: muted dark gold (was violet 176,120,255)
-- [PolishDuels] team colours match the floor: team A cream, team B olive
local TEAM_A, TEAM_B = Color3.fromRGB(236, 232, 218), Color3.fromRGB(157, 176, 90) -- (2026-10-20, Edward) olive back
-- (2026-10-21, RIVALS pass) the game's font decision (Edward): Oswald Bold for big words / numbers (was Montserrat Heavy)
local OSWALD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local SHADOW = Color3.fromRGB(8, 9, 7) -- the cards' offset shadow block
local BOARD_W, BOARD_H = 11, 6 -- billboard size in studs (R = W / H converts X-scale thickness to Y-scale)

local snap = { bays = {}, players = {} }
local function bayOf(mode, id)
	for _, b in snap.bays do if b.mode == mode and b.id == id then return b end end
end
local function statusText(b)
	if not b then return "OPEN", FIELD end
	-- [UI] (UI session 2026-10-16) maps are per mode, and arenas can all be busy (lobby duels)
	if b.noMap then return type(b.noMap) == "string" and string.upper(b.noMap) or ("NO MAPS YET FOR " .. string.upper(b.mode)), FIELD end
	if b.duelWait then return tostring(b.duelWait), BONE end
	if b.state == "Countdown" then return "MATCH FOUND  ·  DEPLOYING IN " .. tostring(b.countdown or ""), BONE end
	if b.state == "Deploying" then return "DEPLOYING...", BONE end
	if b.count == 0 then return "OPEN  ·  STEP ON A PLATE", FIELD end
	return "WAITING FOR " .. (b.total - b.count) .. " MORE", FIELD
end

local function new(class, props, parent)
	local o = Instance.new(class); for k, v in props do o[k] = v end; if parent then o.Parent = parent end; return o
end
local thumbs = {}
-- headshot into img for uid; a late answer for a player who already left that slot is dropped
local function headshot(uid, img)
	img:SetAttribute("Uid", uid)
	if thumbs[uid] then img.Image = thumbs[uid] return end
	img.Image = ""
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then thumbs[uid] = id; if img.Parent and img:GetAttribute("Uid") == uid then img.Image = id end end
	end)
end
-- (2026-10-21, RIVALS pass) Scale text: TextScaled inside a Scale box (was TextSize in a fixed 440x240 canvas)
local function label(text, color, parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextScaled = true, TextColor3 = color or BONE, FontFace = OSWALD,
		TextXAlignment = Enum.TextXAlignment.Center }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end
-- corner brackets in Scale (the board's existing frame; len / th are fractions of the board width)
local function brackets(p, color, len, th)
	local R = BOARD_W / BOARD_H
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		for _, sz in { UDim2.fromScale(len, th * R), UDim2.fromScale(th, len * R) } do
			new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = sz, ZIndex = 6 }, p)
		end
	end
end

-- // boards over the pads ------------------------------------------------------------------------------
-- pads[model] = { gui, key, title, pad, status, cards = { A = { count, col, slots = { { box, img, plus, uid } } }, B = ... } }
local pads = {}
-- (2026-10-21, RIVALS pass) one plate card: solid fill on a thick dark offset block (no rounded corner + hairline stroke,
-- no left accent bar), a big "n/m" count in the team colour, a row of headshot slots, a team-colour strip along the bottom
local function plateCard(parent, team, size, x)
	local col = team == "A" and TEAM_A or TEAM_B
	local W, H, Y = 0.38, 0.54, 0.22
	new("Frame", { BackgroundColor3 = SHADOW, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.fromScale(x + 0.012, Y + 0.035), Size = UDim2.fromScale(W, H), ZIndex = 2 }, parent)
	local card = new("Frame", { BackgroundColor3 = GUN2, BorderSizePixel = 0, Position = UDim2.fromScale(x, Y), Size = UDim2.fromScale(W, H), ZIndex = 3 }, parent)
	new("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.93), Size = UDim2.fromScale(1, 0.07), ZIndex = 4 }, card)
	local count = label("0/" .. size, col, card, { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.42), ZIndex = 4 })
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.05, 0.47), Size = UDim2.fromScale(0.9, 0.42), ZIndex = 4 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local slots = {}
	for i = 1, size do
		local box = new("Frame", { BackgroundColor3 = GUN, BorderSizePixel = 0, LayoutOrder = i, Size = UDim2.fromScale((1 - 0.04 * (size - 1)) / size, 1), ZIndex = 4 }, row)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, box)
		local plus = label("+", Color3.fromRGB(84, 90, 76), box, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
		local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 5 }, box)
		slots[i] = { box = box, img = img, plus = plus, uid = nil }
	end
	return { count = count, col = col, slots = slots }
end
local function buildBoard(gui, mode, id, size, ranked)
	gui:ClearAllChildren()
	local panel = new("Frame", { BackgroundColor3 = GUN, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, gui)
	brackets(panel, ranked and VIOLET or OLIVE, 0.06, 0.009)
	local st = { gui = gui }
	st.title = label(string.upper(mode or "?") .. (ranked and "  RANKED" or "  DUEL"), ranked and VIOLET or BONE, panel,
		{ Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.62, 0.13), TextXAlignment = Enum.TextXAlignment.Left })
	st.pad = label("PAD " .. tostring(id or ""), FIELD, panel, { Position = UDim2.fromScale(0.67, 0.07), Size = UDim2.fromScale(0.28, 0.09), TextXAlignment = Enum.TextXAlignment.Right })
	st.cards = { A = plateCard(panel, "A", size, 0.05), B = plateCard(panel, "B", size, 0.57) }
	label("VS", FIELD, panel, { Position = UDim2.fromScale(0.43, 0.38), Size = UDim2.fromScale(0.14, 0.16) })
	st.status = label("", FIELD, panel, { Position = UDim2.fromScale(0.05, 0.84), Size = UDim2.fromScale(0.9, 0.1) })
	return st
end
local function drawBoard(model)
	local holo = model:FindFirstChild("Holo"); if not holo then return end
	local old = holo:FindFirstChild("Display"); if old and old:IsA("BillboardGui") then old.Enabled = false end
	local mode, id, size = model:GetAttribute("Mode"), model:GetAttribute("BayId"), model:GetAttribute("TeamSize") or 1
	local b = bayOf(mode, id)
	local ranked = b and b.ranked
	-- (2026-10-21, RIVALS pass) rebuild only when the layout changes (mode / pad / team size / ranked), else update in place
	-- (was ClearAllChildren + a new AbsoluteSize connection on every snapshot)
	local key = tostring(mode) .. "|" .. tostring(id) .. "|" .. tostring(size) .. "|" .. tostring(ranked)
	local st = pads[model]
	local fresh = false
	if not st or st.key ~= key or not st.gui.Parent then
		local gui = (st and st.gui.Parent) and st.gui or new("BillboardGui", { Name = "PadBoard", Size = UDim2.new(BOARD_W, 0, BOARD_H, 0), StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
			LightInfluence = 0, MaxDistance = 110, AlwaysOnTop = false, ResetOnSpawn = false, Adornee = holo }, player.PlayerGui)
		st = buildBoard(gui, mode, id, size, ranked)
		st.key = key
		pads[model] = st
		fresh = true
	end
	local occ = b and b.occupants or {}
	for team, card in st.cards do
		local n = 0
		for i, s in card.slots do
			local uid
			for _, o in occ do if o.t == team and o.i == i then uid = o.u end end
			if uid then n += 1 end
			if uid ~= s.uid then
				s.uid = uid
				s.plus.Visible = uid == nil
				s.img.Visible = uid ~= nil
				s.box.BackgroundColor3 = uid and card.col or GUN
				if uid then
					headshot(uid, s.img)
					if not fresh then Kit.popIn(s.img) end -- a joiner pops into the slot
				else
					s.img.Image = ""
					s.img:SetAttribute("Uid", nil)
				end
			end
		end
		local text = n .. "/" .. #card.slots
		if card.count.Text ~= text then
			card.count.Text = text
			if not fresh then Kit.pop(card.count) end -- (2026-10-21, RIVALS pass) the count pops when it changes
		end
	end
	local txt, col = statusText(b)
	if st.status.Text ~= txt then
		st.status.Text = txt
		if not fresh and b and b.state == "Countdown" then Kit.pop(st.status, 1.12) end -- each countdown tick
	end
	st.status.TextColor3 = col
end

-- // loop --------------------------------------------------------------------------------------------------
local function ask(action, ...)
	local ok, r = pcall(Request.InvokeServer, Request, action, ...)
	return ok and r
end
local function allPads()
	local list = {}
	local duels = workspace:FindFirstChild("LobbyMap") and workspace.LobbyMap:FindFirstChild("Duels")
	for _, m in (duels and duels:GetChildren() or {}) do if m:IsA("Model") and m:GetAttribute("BayId") then table.insert(list, m) end end
	return list
end
local function redrawBoards() for _, m in allPads() do drawBoard(m) end end
QueueState.OnClientEvent:Connect(function(s) if type(s) == "table" then snap = s; redrawBoards() end end)
task.spawn(function()
	local r = ask("GetQueue")
	if r and r.snapshot then snap = r.snapshot end
	redrawBoards()
end)
