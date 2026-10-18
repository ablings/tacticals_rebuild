-- UIKit/PartyScreen (ModuleScript): RIVALS' "Your Party" in TACTICALS' look (UI session 2026-10-17; ref: the replica's
-- PartyController, built from live RIVALS). Opened by the round "+" next to your avatar by PLAY.
--   * Left: "YOUR PARTY", your card and four slots. Party members fill the slots (leader first, a crown on the leader);
--     the leader gets a kick X on each member; "Leave Party" under the column while you're in one.
--   * Right: a search box, All / Friends / Lobby tabs and the red X; a 3-wide grid of people: everyone in this server,
--     plus your online friends who are elsewhere (Friends tab). Each card: headshot, name, @username and buttons:
--     in this lobby "1v1" (LobbySocial Challenge) and "Invite" (LobbyParty Invite); elsewhere "Invite" (Roblox's invite).
--     A sent button turns grey with a tick until the request runs out.
-- Party state comes from the Tacticals session's server (ReplicatedStorage.LobbyParty): Player attributes PartyId,
-- PartyLeader (UserId), PartyMembers (JSON array, leader first). Without LobbyParty the screen still opens: the slots stay
-- empty and Invite uses Roblox's invite sheet.
-- Built in 1920x1080 design px on a 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local F_NAME = Font.new(BUILDER, Enum.FontWeight.Bold)
local F_SUB = Font.new(BUILDER, Enum.FontWeight.Medium)
local F_HEAD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BONE, FIELD, GUN, DEEP = hex("#ECE8DA"), hex("#969C8C"), hex("#1A1D1A"), hex("#0C0E0B")
local OLIVE, OLIVE_HI, GOLD = hex("#5B6E2C"), hex("#9DB05A"), hex("#E9C46A")

local PartyScreen = {}
local MAX = 5

local function party() return ReplicatedStorage:FindFirstChild("LobbyParty") end
local function social() return ReplicatedStorage:FindFirstChild("LobbySocial") end
local function members(p)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, (p or player):GetAttribute("PartyMembers") or "")
	return (ok and type(list) == "table") and list or {}
end
function PartyScreen.Members() return members(player) end
function PartyScreen.IsLeader()
	local list = members(player)
	return #list == 0 or player:GetAttribute("PartyLeader") == player.UserId
end
local function toast(text, kind)
	local LobbyUI = shared.Get and shared.Get("LobbyUIController")
	if LobbyUI and LobbyUI.Toast then LobbyUI.Toast(text, kind or "bad"); return end
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "TACTICALS", Text = text, Duration = 3 })
end
PartyScreen.Toast = toast
local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
end
local thumbs = {}
local function headshot(img, uid)
	if not uid or uid <= 0 then return end
	if thumbs[uid] then img.Image = thumbs[uid]; return end
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then thumbs[uid] = id; if img.Parent then img.Image = id end end
	end)
end
local function busy(p)
	return p:GetAttribute("InDuel") == true or p:GetAttribute("DuelMatch") ~= nil or p:GetAttribute("MM_Queue") ~= nil
		or p:GetAttribute("InTraining") == true or p:GetAttribute("Deploying") == true
end

---------------------------------------------------------------------------------------------------- screen
local gui, canvas, root, col, grid, search, tabBtns, blur, scrim
local current = "All"
local sent = {} -- "uid|kind" -> os.clock() of the send (a sent button stays a tick for 15 s)
local isOpen = false
local friendsOnline = {} -- { uid, name, user } for friends elsewhere (refreshed on open)

local function tick(parent, color)
	for _, bar in { { 0.4, 0.58, 0.26, 45 }, { 0.57, 0.48, 0.48, -50 } } do
		new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(bar[1], bar[2]),
			Size = UDim2.fromScale(bar[3], 0.12), Rotation = bar[4], ZIndex = 6, Parent = parent }, { Kit.corner(2) })
	end
end
-- a small gradient button that becomes a grey tick once sent
local function actionButton(card, x, y, text, kind, uid, colors, onPress)
	local b = new("TextButton", { Name = kind, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(88, 34),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = card }, { Kit.corner(6) })
	local g = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]), Parent = b })
	local l = label(b, text, F_NAME, 18, 0, 0, 88, 34, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, 5)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.5, Parent = l })
	local tickHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), Visible = false, ZIndex = 5, Parent = b })
	tick(tickHolder, Color3.new(1, 1, 1))
	local key = uid .. "|" .. kind
	local function showSent(left)
		g.Color = ColorSequence.new(hex("#A9AC9F"), hex("#6C7064"))
		l.Visible, tickHolder.Visible = false, true
		task.delay(left, function()
			if not b.Parent then return end
			g.Color = ColorSequence.new(colors[1], colors[2])
			l.Visible, tickHolder.Visible = true, false
		end)
	end
	if sent[key] and os.clock() - sent[key] < 15 then showSent(15 - (os.clock() - sent[key])) end
	b.Activated:Connect(function()
		if sent[key] and os.clock() - sent[key] < 15 then return end
		if onPress() ~= false then sent[key] = os.clock(); showSent(15) end
	end)
	return b
end

local function invite(uid, inServer)
	local r = party()
	local target = Players:GetPlayerByUserId(uid)
	if r and target then
		r:FireServer("Invite", target)
		return true
	end
	-- not in this server (or no party server yet): Roblox's own invite sheet, aimed at them
	local SocialService = game:GetService("SocialService")
	local okCan, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	local ok = okCan and can and pcall(function()
		local opts = Instance.new("ExperienceInviteOptions")
		opts.InviteUser = uid
		SocialService:PromptGameInvite(player, opts)
	end)
	if not ok then toast("Invites aren't available here (they work in the published game)") end
	return ok
end

local function personCard(parent, x, y, w, pp, opts)
	local c = new("Frame", { Name = tostring(pp.uid), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 108), BackgroundColor3 = DEEP, BackgroundTransparency = 0.25,
		ZIndex = 3, Parent = parent }, { Kit.corner(10), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.88, Thickness = 1.5 }) })
	local hs = new("ImageLabel", { BackgroundColor3 = GUN, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(64, 64), ZIndex = 4, Parent = c }, { Kit.corner(8) })
	headshot(hs, pp.uid)
	label(c, pp.name, F_NAME, 22, 86, 10, w - 96, 28, BONE, nil, 4)
	label(c, "@" .. pp.user .. (pp.where and ("  ·  " .. pp.where) or ""), F_SUB, 15, 86, 38, w - 96, 20, FIELD, nil, 4)
	if opts.crown then
		-- (2026-10-18, live RIVALS) the leader: a gold crown on the headshot's corner (drawn: BuilderSans has no crown glyph)
		Kit.crown(hs, UDim2.fromScale(0.86, 0.1), UDim2.fromScale(0.62, 0.48), 6)
	end
	if opts.leave then
		-- your own card while you're in a party: a red Leave on it (RIVALS)
		local lb = new("TextButton", { Name = "Leave", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(w - 112, 64), Size = UDim2.fromOffset(100, 36),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = c }, { Kit.corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#E8463A"), hex("#9C1E16")) }) })
		label(lb, "Leave", F_NAME, 20, 0, 0, 100, 36, BONE, Enum.TextXAlignment.Center, 6)
		Kit.bindButton(lb, { hover = 1.06 })
		lb.Activated:Connect(function() local r = party(); if r then r:FireServer("Leave") end end)
	end
	if opts.kick then
		local k = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(w - 40, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = hex("#8E2A24"),
			ZIndex = 5, Parent = c }, { Kit.corner(8) })
		label(k, "×", F_NAME, 24, 0, -2, 30, 30, BONE, Enum.TextXAlignment.Center, 6)
		k.Activated:Connect(function() local r = party(); local t = Players:GetPlayerByUserId(pp.uid); if r and t then r:FireServer("Kick", t) end end)
	end
	if opts.buttons then
		local bx = w - 12
		if opts.invite then
			bx -= 88
			actionButton(c, bx, 66, "Invite", "Invite", pp.uid, { hex("#B6D86A"), hex("#5B6E2C") }, function() return invite(pp.uid, pp.inServer) end)
		end
		if opts.duel and social() then
			bx -= 96
			actionButton(c, bx, 66, "1v1", "Duel", pp.uid, { hex("#F0B550"), hex("#B06A12") }, function()
				local t = Players:GetPlayerByUserId(pp.uid)
				if t then social():FireServer("Challenge", t) return true end
				return false
			end)
		end
	end
	return c
end

local function renderParty()
	for _, ch in col:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	local list = members(player)
	if #list == 0 then list = { player.UserId } end
	local leader = player:GetAttribute("PartyLeader") or player.UserId
	local amLeader = leader == player.UserId
	for i = 1, MAX do
		local uid = list[i]
		if uid then
			local p = Players:GetPlayerByUserId(uid)
			local card = personCard(col, 0, (i - 1) * 118, 340, { uid = uid, name = p and p.DisplayName or "...", user = p and p.Name or "...", where = not p and "elsewhere" or nil },
				{ crown = #list > 1 and uid == leader, kick = amLeader and uid ~= player.UserId and party() ~= nil, leave = #list > 1 and uid == player.UserId })
			if not p then
				-- a member in another server (a party survives the teleport): look their name up
				task.spawn(function()
					local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, uid)
					if ok and card.Parent then
						for _, l in card:GetDescendants() do
							if l:IsA("TextLabel") and l.Text == "..." then l.Text = name end
							if l:IsA("TextLabel") and l.Text:sub(1, 4) == "@..." then l.Text = "@" .. name .. "  ·  elsewhere" end
						end
					end
				end)
			end
		else
			-- an empty slot: a dashed-feel dim card with "+ Invite"; clicking it jumps to the Friends tab
			local slot = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, (i - 1) * 118), Size = UDim2.fromOffset(340, 108),
				BackgroundColor3 = DEEP, BackgroundTransparency = 0.6, ZIndex = 3, Parent = col }, { Kit.corner(10), new("UIStroke", { Color = OLIVE_HI, Transparency = 0.7, Thickness = 1.5 }) })
			label(slot, "+  Invite", F_NAME, 22, 0, 0, 340, 108, FIELD, Enum.TextXAlignment.Center, 4)
			slot.Activated:Connect(function() PartyScreen.SetTab("Friends") end)
		end
	end
	local leave = col.Parent:FindFirstChild("LeaveParty")
	if leave then leave.Visible = false end -- (Leave is on your own card now, RIVALS)
	Kit.toScale(col)
end

local function people()
	local out, seen = {}, {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			seen[p.UserId] = true
			table.insert(out, { uid = p.UserId, name = p.DisplayName, user = p.Name, inServer = true, lobby = not busy(p),
				friend = (function() local ok, f = pcall(player.IsFriendsWith, player, p.UserId) return ok and f end)(),
				where = busy(p) and "busy" or nil })
		end
	end
	for _, f in friendsOnline do
		if not seen[f.uid] then table.insert(out, { uid = f.uid, name = f.name, user = f.user, inServer = false, lobby = false, friend = true, where = "online" }) end
	end
	return out
end

local function renderGrid()
	for _, ch in grid:GetChildren() do ch:Destroy() end
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 10), Parent = grid })
	local q = search.Text:lower()
	local inParty = {}
	for _, uid in members(player) do inParty[uid] = true end
	local k = 0
	for _, pp in people() do
		local show = current == "All" and pp.inServer or (current == "Lobby" and pp.inServer and pp.lobby) or (current == "Friends" and pp.friend)
		if show and (q == "" or pp.name:lower():find(q, 1, true) or pp.user:lower():find(q, 1, true)) then
			personCard(holder, (k % 3) * 300, (k // 3) * 118, 290, pp, {
				buttons = not inParty[pp.uid], invite = not inParty[pp.uid] and (not pp.inServer or pp.lobby), duel = pp.inServer and pp.lobby })
			k += 1
		end
	end
	if k == 0 then
		label(holder, current == "Friends" and "No friends online right now" or "Nobody else here yet", F_SUB, 24, 0, 30, 900, 30, FIELD, Enum.TextXAlignment.Center, 3)
		k = 1
	end
	holder.Size = UDim2.fromOffset(900, math.max(10, math.ceil(k / 3) * 118))
	Kit.toScale(grid)
end

local function styleTabs()
	for name, t in tabBtns do
		local on = name == current
		t.b.BackgroundColor3 = on and BONE or DEEP
		t.b.BackgroundTransparency = on and 0 or 0.35
		t.l.TextColor3 = on and DEEP or BONE
		t.b:SetAttribute("NavTabOn", on)
	end
end
function PartyScreen.SetTab(name)
	current = name
	if not gui then return end
	styleTabs()
	renderGrid()
end

local function build()
	gui = new("ScreenGui", { Name = "PartyUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 11, Enabled = false,
		Parent = player:WaitForChild("PlayerGui") })
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.scrim, BackgroundTransparency = 1, Parent = gui })
	canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Parent = canvas })
	-- left
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = OLIVE, Position = UDim2.fromOffset(296, 150), Size = UDim2.fromOffset(10, 56), Parent = root })
	label(root, "YOUR PARTY", F_HEAD, 52, 318, 142, 400, 70, BONE)
	col = new("Frame", { Name = "Members", BackgroundTransparency = 1, Position = UDim2.fromOffset(300, 230), Size = UDim2.fromOffset(340, 5 * 118), Parent = root })
	local leave = new("TextButton", { Name = "LeaveParty", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(300, 830), Size = UDim2.fromOffset(340, 56),
		BackgroundColor3 = hex("#8E2A24"), Visible = false, Parent = root }, { Kit.corner(10) })
	label(leave, "Leave Party", F_NAME, 24, 0, 0, 340, 56, BONE, Enum.TextXAlignment.Center, 3)
	Kit.bindButton(leave, { hover = 1.04 })
	leave.Activated:Connect(function() local r = party(); if r then r:FireServer("Leave") end end)
	-- right
	search = new("TextBox", { Name = "Search", Text = "", PlaceholderText = "Search players", PlaceholderColor3 = FIELD, FontFace = F_NAME, TextSize = 24, TextColor3 = BONE,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Position = UDim2.fromOffset(700, 156), Size = UDim2.fromOffset(420, 54), BackgroundColor3 = DEEP,
		BackgroundTransparency = 0.25, Parent = root }, { Kit.corner(10), new("UIPadding", { PaddingLeft = UDim.new(0, 16) }) })
	tabBtns = {}
	for i, t in { { "All", 96 }, { "Friends", 128 }, { "Lobby", 116 } } do
		local x = 1134 + (i == 1 and 0 or (i == 2 and 106 or 244))
		local b = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 156), Size = UDim2.fromOffset(t[2], 54), BackgroundColor3 = BONE,
			Parent = root }, { Kit.corner(10) })
		local l = label(b, t[1], F_NAME, 24, 0, 0, t[2], 54, DEEP, Enum.TextXAlignment.Center, 3)
		tabBtns[t[1]] = { b = b, l = l }
		b.Activated:Connect(function() PartyScreen.SetTab(t[1]) end)
		b:SetAttribute("NavTab", i) -- [PAD] LB / RB
		b:GetAttributeChangedSignal("NavPressed"):Connect(function() PartyScreen.SetTab(t[1]) end)
	end
	local close = Kit.closeButton(UDim2.fromOffset(80, 54))
	close.Position = UDim2.fromOffset(1520, 156)
	close.Parent = root
	close.Activated:Connect(function() PartyScreen.Close() end)
	grid = new("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(700, 230), Size = UDim2.fromOffset(912, 760), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = FIELD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root })
	Kit.toScale(root)
	search:GetPropertyChangedSignal("Text"):Connect(function() if isOpen then renderGrid() end end)
	-- party changes redraw while open
	for _, a in { "PartyMembers", "PartyLeader" } do
		player:GetAttributeChangedSignal(a):Connect(function() if isOpen then renderParty(); renderGrid() end end)
	end
	Players.PlayerAdded:Connect(function() if isOpen then renderGrid() end end)
	Players.PlayerRemoving:Connect(function() if isOpen then task.defer(renderGrid) end end)
end

function PartyScreen.IsOpen() return isOpen end
function PartyScreen.Open(tab)
	if not gui then build() end
	if tab then current = tab end
	isOpen = true
	gui.Enabled = true
	styleTabs()
	renderParty()
	renderGrid()
	Kit.tween(blur, 0.25, { Size = Theme.blur })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = Theme.alpha.scrim })
	Kit.open(root)
	-- online friends elsewhere (Friends tab): fetched each open, the grid redraws when they arrive
	task.spawn(function()
		local ok, list = pcall(player.GetFriendsOnline, player, 50)
		if not ok or type(list) ~= "table" then return end
		local out = {}
		for _, f in list do
			if f.VisitorId and f.IsOnline then table.insert(out, { uid = f.VisitorId, name = f.DisplayName or f.UserName, user = f.UserName }) end
		end
		friendsOnline = out
		if isOpen then renderGrid() end
	end)
	if PartyScreen.OnOpen then PartyScreen.OnOpen(true) end
end
function PartyScreen.Close()
	if not isOpen then return end
	isOpen = false
	Kit.tween(blur, 0.2, { Size = 0 })
	Kit.tween(scrim, 0.2, { BackgroundTransparency = 1 })
	Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
	if PartyScreen.OnOpen then PartyScreen.OnOpen(false) end
end

---------------------------------------------------------------------------------------------------- server events
-- invites to you show in PlayerCards' request stack ("invited you to their party!"); the rest are toasts
local CLOSED = { declined = "declined your party invite", expired = "didn't answer your party invite", busy = "is busy right now",
	full = "'s party is full", cancelled = "cancelled the party invite" }
local function hook(r)
	if not r:IsA("RemoteEvent") then return end
	r.OnClientEvent:Connect(function(kind, who, a, b)
		if kind == "Kicked" then toast("You were removed from the party") return end
		if typeof(who) ~= "Instance" or not who:IsA("Player") then return end
		local PlayerCards = require(UIKit:WaitForChild("PlayerCards"))
		if kind == "Request" then
			PlayerCards.ShowRequest(who, tonumber(a), "party")
		elseif kind == "Closed" then
			PlayerCards.CloseRequest(who, "party")
			if CLOSED[a] then toast(who.DisplayName .. (a == "full" and "" or " ") .. CLOSED[a]) end
			if a == "accepted" then toast(who.DisplayName .. " joined the party", "good") end
		elseif kind == "Sent" then
			if a then toast("Party invite sent to " .. who.DisplayName, "good") else toast(tostring(b or "Couldn't send the invite")) end
		end
	end)
end
task.spawn(function()
	local r = ReplicatedStorage:FindFirstChild("LobbyParty")
	if r then hook(r) return end
	local conn
	conn = ReplicatedStorage.ChildAdded:Connect(function(c) if c.Name == "LobbyParty" then conn:Disconnect(); hook(c) end end)
end)

return PartyScreen
