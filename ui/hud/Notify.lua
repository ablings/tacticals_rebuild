-- UIKit/Notify (ModuleScript, hub + match places): RIVALS' notification banner and Inbox (UI session 2026-10-18, from Edward's
-- live captures).
--   * Banner: a black pill slides down at the top centre: a green check on the left, a bold title ("Task Completed"), a grey
--     line under it ("You've earned x3 Scissors!"), the reward on the right with its count. One at a time, queued.
--   * Inbox: every banner this session also lands in the Inbox (newest first, "12m ago" chips on the left), opened from the
--     top-right inbox button. It clears when you leave the server, like RIVALS'.
--   * Top-right buttons (hub): Inbox / News / Settings as round icons with RIVALS' black tooltip bubbles on hover.
-- Server contract (Tacticals session): Events.Lobby.Notify:FireClient(player, { title = "Task Completed",
--   sub = "You've earned x3 Scissors!", icon = "check", reward = { kind = "Scissors" | "Item", id = itemId?, count = n? } })
-- (a plain string still goes to the old lobby toast). Notify.Push(t) shows one from the client.
-- Icons: white vector silhouettes (ui/art/icons, codex) once uploaded; until then the check and the buttons are drawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local UIKit = script.Parent
local Kit = require(UIKit:WaitForChild("Kit"))
local new = Kit.new
local player = Players.LocalPlayer

local Notify = {}
-- white silhouette icons (rbxassetid) as they get uploaded; nil = the drawn fallback
Notify.ICONS = { bell = "rbxassetid://93058069459479", check = "rbxassetid://134680054948193", elims = "rbxassetid://87495411854172", inbox = "rbxassetid://106780166776464", level = "rbxassetid://122349404580689", news = "rbxassetid://98784760577764", play = "rbxassetid://112398761342835", rank = "rbxassetid://127088807913977", scissors = "rbxassetid://124651407398623", settings = "rbxassetid://77423905055797", streak = "rbxassetid://89001729086571", trophy = "rbxassetid://112797256867777" } -- (Gunsy Funsy uploads of ui/art/icons, 2026-10-18)

local FX = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local GREEN = Color3.fromRGB(255, 212, 0) -- (2026-10-20 palette: the accent, no green)
local GREY = Color3.fromRGB(190, 190, 194)
local PILL = Color3.fromRGB(18, 19, 21)

for k, v in Kit.ICONS or {} do if Notify.ICONS[k] == nil then Notify.ICONS[k] = v end end
local inbox = {} -- { t, title, sub, reward }
local unread = 0
local onUnread -- set by the top-right buttons

local function txt(parent, text, font, size, x, y, w, h, color, align, z)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = font, TextSize = size, TextColor3 = color or Color3.new(1, 1, 1),
		TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3, Parent = parent })
	return l
end

-- an icon: the uploaded silhouette, or a drawn stand-in (the check is two rounded bars)
local function icon(parent, kind, x, y, s, color, z)
	local id = Notify.ICONS[kind]
	if id then
		return new("ImageLabel", { BackgroundTransparency = 1, Image = id, ImageColor3 = color or Color3.new(1, 1, 1), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s, s),
			ZIndex = z or 4, Parent = parent })
	end
	local h = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s, s), ZIndex = z or 4, Parent = parent })
	if kind == "check" then
		new("Frame", { BackgroundColor3 = color or GREEN, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * 0.3, s * 0.62),
			Size = UDim2.fromOffset(s * 0.44, s * 0.2), Rotation = 45, ZIndex = z or 4, Parent = h }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("Frame", { BackgroundColor3 = color or GREEN, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * 0.6, s * 0.47),
			Size = UDim2.fromOffset(s * 0.78, s * 0.2), Rotation = -48, ZIndex = z or 4, Parent = h }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	else
		local glyph = ({ inbox = "!", news = "N", settings = "*", scissors = "X", level = "L" })[kind] or "?"
		txt(h, glyph, FX, s * 0.7, 0, 0, s, s, color, nil, z or 4)
	end
	return h
end

-- the reward on the right of a pill: its picture (an item render id, or the scissors icon) and "xN" under it
local function rewardBox(parent, r, x, y)
	if type(r) ~= "table" then return end
	local box = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(70, 70), ZIndex = 4, Parent = parent })
	-- the reward picture: a given image, a rank emblem (RankArt), an item's shop icon, or the silhouette icon for its kind
	local img = r.image
	if not img and r.kind == "Rank" and r.rank then
		local ok, RankArt = pcall(require, UIKit:FindFirstChild("RankArt"))
		if ok and RankArt and RankArt.EMBLEM then img = RankArt.EMBLEM[tostring(r.rank):match("^(%a+)") or r.rank] end
	end
	if not img and r.kind == "Item" and r.id then
		local okC, cfg = pcall(function() return require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig) end)
		local item = okC and cfg and cfg.Items and cfg.Items[r.id]
		img = item and (item.Icon or item.Image)
	end
	if img then
		new("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(70, 70), ZIndex = 4, Parent = box })
	elseif r.kind == "Level" then
		icon(box, "level", 8, 0, 54, Color3.fromRGB(90, 170, 255), 4)
	else
		icon(box, r.kind == "Scissors" and "scissors" or "check", 8, 0, 54, Color3.fromRGB(255, 205, 60), 4)
	end
	if r.count then
		local c = txt(box, (r.kind == "Level" and "" or "×") .. tostring(r.count), FX, 28, 0, 42, 70, 30, nil, nil, 5) -- (a level shows its number)
		new("UIStroke", { Thickness = 2, Transparency = 0.2, Parent = c })
	end
end

-- one pill (banner or inbox row), design px
local function pill(parent, n, x, y, w, h)
	local p = new("Frame", { Name = "Pill", BackgroundColor3 = PILL, BackgroundTransparency = 0.05, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		ZIndex = 3, Parent = parent }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	icon(p, n.icon or "check", 26, (h - 56) / 2, 56, GREEN, 4)
	local t = txt(p, n.title or "", FX, math.floor(h * 0.42), 96, h * 0.06, w - 200, h * 0.52, nil, nil, 4)
	t.TextScaled = false
	txt(p, n.sub or "", FB, math.floor(h * 0.24), 96, h * 0.56, w - 200, h * 0.32, GREY, nil, 4)
	rewardBox(p, n.reward, w - 96, (h - 70) / 2)
	return p
end

---------------------------------------------------------------------------------------------------- banner
local bannerGui, bannerRoot
local queue, showing = {}, false
local function ensureBanner()
	if bannerGui and bannerGui.Parent then return end
	bannerGui = new("ScreenGui", { Name = "NotifyBanner", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui") })
	local canvas = Kit.canvas(bannerGui)
	bannerRoot = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
end
local function nextBanner()
	if showing or #queue == 0 then return end
	showing = true
	local n = table.remove(queue, 1)
	ensureBanner()
	local holder = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Parent = bannerRoot })
	local p = pill(holder, n, 545, 64, 830, 92)
	Kit.toScale(holder)
	holder.Size = UDim2.fromScale(1, 1)
	-- slide down from above the screen with a little overshoot, hold, then slide back up and fade
	local home = p.Position
	p.Position = home - UDim2.fromScale(0, 0.14)
	local sc = new("UIScale", { Scale = 0.9, Parent = p })
	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = home }):Play()
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if Kit.sfx then pcall(Kit.sfx, "reward") end
	task.delay(3.4, function()
		TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = home - UDim2.fromScale(0, 0.14) }):Play()
		task.delay(0.32, function()
			holder:Destroy()
			showing = false
			nextBanner()
		end)
	end)
end

function Notify.Push(n)
	if type(n) ~= "table" then return end
	if player:GetAttribute("Setting_DeliveryMode") == "Disabled" then return end
	table.insert(inbox, 1, { t = os.time(), title = n.title, sub = n.sub, icon = n.icon, reward = n.reward })
	while #inbox > 50 do table.remove(inbox) end
	unread += 1
	if onUnread then onUnread(unread) end
	table.insert(queue, n)
	nextBanner()
end

---------------------------------------------------------------------------------------------------- inbox
local inboxGui, inboxRoot, blur
local function ago(t)
	local d = os.time() - t
	if d < 60 then return "now" end
	if d < 3600 then return d // 60 .. "m ago" end
	return d // 3600 .. "h ago"
end
local function buildInbox()
	if inboxGui and inboxGui.Parent then inboxGui:Destroy() end
	inboxGui = new("ScreenGui", { Name = "InboxUI", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 26, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui") })
	new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = inboxGui })
	local canvas = Kit.canvas(inboxGui)
	inboxRoot = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local head = new("Frame", { Name = "Head", BackgroundColor3 = PILL, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(540, 208), Size = UDim2.fromOffset(828, 132),
		ZIndex = 2, Parent = inboxRoot }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	icon(head, "inbox", 20, 10, 56, Color3.new(1, 1, 1), 3)
	txt(head, "Inbox", FX, 46, 84, 6, 400, 60, nil, Enum.TextXAlignment.Left, 3)
	txt(head, "All of your recent notifications end up here.\nYour inbox clears when you leave the server!", FB, 22, 0, 62, 828, 60, GREY, nil, 3)
	local x = Kit.closeButton(UDim2.fromOffset(84, 50))
	x.Position = UDim2.fromOffset(1406, 207)
	x.Parent = inboxRoot
	x.Activated:Connect(function() Notify.CloseInbox() end)
	local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(420, 360), Size = UDim2.fromOffset(940, 680),
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = inboxRoot })
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(940, math.max(680, #inbox * 108)), Parent = list })
	if #inbox == 0 then
		txt(content, "Nothing yet", FX, 34, 0, 40, 940, 44, nil, nil, 3)
		txt(content, "Completed tasks, unlocks and rewards show up here.", FB, 22, 0, 86, 940, 30, GREY, nil, 3)
	end
	for i, n in inbox do
		local y = (i - 1) * 108
		local chip = new("Frame", { BackgroundColor3 = PILL, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(4, y + 28), Size = UDim2.fromOffset(118, 46), ZIndex = 3,
			Parent = content }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		txt(chip, ago(n.t), FB, 18, 0, 0, 118, 46, GREY, nil, 4)
		pill(content, n, 142, y, 785, 102)
	end
	Kit.toScale(inboxRoot)
	-- the list's canvas: as tall as the rows (Scale is relative to the list's parent)
	list.CanvasSize = UDim2.fromScale(0, math.max(680, #inbox * 108) / 1080)
	content.Size = UDim2.fromScale(1, math.max(680, #inbox * 108) / 680)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = 18 }):Play()
	if Kit.open then pcall(Kit.open, inboxRoot) end
end
function Notify.OpenInbox()
	unread = 0
	if onUnread then onUnread(0) end
	buildInbox()
end
function Notify.CloseInbox()
	if blur then TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play() end
	if inboxGui then inboxGui:Destroy(); inboxGui = nil end
end
function Notify.InboxOpen() return inboxGui ~= nil and inboxGui.Parent ~= nil end

---------------------------------------------------------------------------------------------------- news
-- "Read the latest news": the update notes, newest first (edit NEWS when a port goes out)
Notify.NEWS = {
	{ title = "After-match lobby", sub = "Walk around after a match: To Hub, Play Again or Rematch (best of three)." },
	{ title = "Weapon stats + Duel History", sub = "Kit > Statistics for each weapon, and your last 20 duels." },
	{ title = "Switch Weapons", sub = "Press M between rounds to change your loadout." },
}
function Notify.OpenNews()
	local saved = inbox
	inbox = {}
	for i, n in Notify.NEWS do inbox[i] = { t = os.time(), title = n.title, sub = n.sub, icon = "news" } end
	buildInbox()
	inbox = saved
	-- the header says News instead of Inbox
	local head = inboxRoot and inboxRoot:FindFirstChild("Head")
	if head then
		for _, l in head:GetDescendants() do
			if l:IsA("TextLabel") and l.Text == "Inbox" then l.Text = "News" end
			if l:IsA("TextLabel") and l.Text:find("notifications end up here", 1, true) then l.Text = "What's new in Tacticals." end
		end
	end
	-- the time chips make no sense for news: hide them
	local list = inboxRoot and inboxRoot:FindFirstChild("List")
	for _, f in list and list:GetDescendants() or {} do
		if f:IsA("TextLabel") and f.Text == "now" and f.Parent then f.Parent.Visible = false end
	end
end

---------------------------------------------------------------------------------------------------- top-right buttons (hub)
-- RIVALS' corner (Edward, 2026-10-18): only the gear shows ("See more"). Clicking it slides the other buttons out to its
-- left (Inbox, News) and its own tooltip becomes "Change your crosshair & hotkeys"; clicking it again then opens Settings.
-- A small x at the end of the row folds it back. buttons = { { kind, tip, onClick }, ... }: the first is the gear.
function Notify.MountTopRight(buttons)
	local gui = new("ScreenGui", { Name = "TopRightButtons", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 8, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui") })
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local GEAR_X = 1640 -- (left of the region / fps readout already in the corner)
	local made, order = {}, {}
	local expanded = false
	local function bubbleFor(btn, text)
		local tipW = math.max(140, #text * 12 + 40)
		local bubble = new("Frame", { Name = "Tip", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(52, 66), Size = UDim2.fromOffset(tipW, 40), Visible = false, ZIndex = 5, Parent = btn },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(tipW - 26, 0),
			Size = UDim2.fromOffset(14, 14), ZIndex = 5, Parent = bubble })
		local l = txt(bubble, text, FB, 22, 0, 0, tipW, 40, nil, nil, 6)
		return bubble, l
	end
	for i, b in buttons do
		local x = GEAR_X - (i - 1) * 62
		local btn = new("TextButton", { Name = b[1], Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(28, 29, 31), BackgroundTransparency = 0.15,
			Position = UDim2.fromOffset(x, 16), Size = UDim2.fromOffset(52, 52), Visible = i == 1, ZIndex = 2, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		btn:AddTag("Nonapplicable")
		icon(btn, b[1], 10, 10, 32, Color3.new(1, 1, 1), 3)
		local bubble, tipL = bubbleFor(btn, i == 1 and "See more" or b[2])
		if i == 1 then
			-- the gear's tooltip is wider than "See more" needs: size it for the long text, the short one sits right-aligned
			local w = math.max(140, #b[2] * 12 + 40)
			bubble.Size = UDim2.fromOffset(w, 40)
			tipL.Size = UDim2.fromOffset(w, 40)
			bubble:FindFirstChildOfClass("Frame").Position = UDim2.fromOffset(w - 26, 0)
		end
		local badge = new("Frame", { Name = "Badge", BackgroundColor3 = Color3.fromRGB(230, 50, 50), Position = UDim2.fromOffset(34, -4), Size = UDim2.fromOffset(24, 24),
			Visible = false, ZIndex = 4, Parent = btn }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		txt(badge, "0", FX, 16, 0, 0, 24, 24, nil, nil, 5)
		btn.MouseEnter:Connect(function() bubble.Visible = true end)
		btn.MouseLeave:Connect(function() bubble.Visible = false end)
		btn.SelectionGained:Connect(function() bubble.Visible = true end)
		btn.SelectionLost:Connect(function() bubble.Visible = false end)
		made[b[1]] = { btn = btn, badge = badge, bubble = bubble, tip = tipL, def = b }
		table.insert(order, b[1])
	end
	-- the x that folds the row back, left of the last button
	local fold = new("TextButton", { Name = "Fold", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(GEAR_X - #buttons * 62 + 18, 30),
		Size = UDim2.fromOffset(28, 28), Visible = false, ZIndex = 2, Parent = root })
	fold:AddTag("Nonapplicable")
	txt(fold, "×", FX, 30, 0, -4, 28, 32, Color3.fromRGB(220, 220, 224), nil, 3)
	Kit.toScale(root)
	local unreadN = unread
	local function refresh()
		for i, k in order do
			local m = made[k]
			if i > 1 then m.btn.Visible = expanded end
		end
		fold.Visible = expanded
		local gear = made[order[1]]
		gear.tip.Text = expanded and gear.def[2] or "See more"
		-- unread: on the inbox button when it's out, on the gear while folded
		local ib = made.inbox
		if ib then
			ib.badge.Visible = expanded and unreadN > 0
			ib.badge:FindFirstChildOfClass("TextLabel").Text = unreadN > 9 and "9+" or tostring(unreadN)
		end
		gear.badge.Visible = not expanded and unreadN > 0
		gear.badge:FindFirstChildOfClass("TextLabel").Text = unreadN > 9 and "9+" or tostring(unreadN)
	end
	local function setExpanded(on)
		expanded = on
		refresh()
		if on then
			-- the buttons slide out from behind the gear
			local gx = made[order[1]].btn.Position
			for i = 2, #order do
				local b2 = made[order[i]].btn
				local home = b2:GetAttribute("Home") or b2.Position
				b2:SetAttribute("Home", home)
				b2.Position = gx
				TweenService:Create(b2, TweenInfo.new(0.18 + i * 0.04, Enum.EasingStyle.Quart), { Position = home }):Play()
			end
		end
	end
	for i, k in order do
		local m = made[k]
		m.btn.Activated:Connect(function()
			m.bubble.Visible = false
			if i == 1 and not expanded then setExpanded(true) return end
			if m.def[3] then m.def[3]() end
		end)
	end
	fold.Activated:Connect(function() setExpanded(false) end)
	onUnread = function(n) unreadN = n; refresh() end
	refresh()
	return gui
end

-- the unread count for a badge somewhere else (the lobby's corner gear): fn(n) now and on every change
function Notify.OnUnread(fn) onUnread = fn; fn(unread) end

---------------------------------------------------------------------------------------------------- server hook
local hooked = false
function Notify.Hook()
	if hooked then return end
	hooked = true
	task.spawn(function()
		local ev = ReplicatedStorage:WaitForChild("Events", 30)
		local lobby = ev and ev:WaitForChild("Lobby", 30)
		local n = lobby and lobby:WaitForChild("Notify", 30)
		if n then n.OnClientEvent:Connect(function(a) if type(a) == "table" then Notify.Push(a) end end) end
	end)
end

return Notify
