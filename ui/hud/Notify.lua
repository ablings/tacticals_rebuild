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

-- (2026-10-21, AI-tells cleanup) Builder Sans -> Oswald Bold (titles, counts) / Rubik SemiBold (sub lines, chips, tips);
-- the check / done colour is field green #8DBF5A (was the #FFD400 yellow), the reward icon cream #ECE6D2
local BLUR = 24 -- the menus' blur (rivals Theme.blur)
pcall(function() -- FindFirstChild: the match place's UIKit may have no Rivals folder (WaitForChild would hang the module)
	local r = script.Parent:FindFirstChild("Rivals")
	local t = r and r:FindFirstChild("Theme")
	if t then BLUR = require(t).blur or BLUR end
end)
local FX = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local FB = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold)
local GREEN = Color3.fromRGB(141, 191, 90) -- field green: done
local GREY = Color3.fromRGB(190, 190, 194)
local PILL = Color3.fromRGB(18, 19, 21)

for k, v in Kit.ICONS or {} do if Notify.ICONS[k] == nil then Notify.ICONS[k] = v end end
-- (rd5, grader B) the people glyph for friend notices (the play triangle read wrong); from the Rivals art if it's there
pcall(function()
	local r = script.Parent:FindFirstChild("Rivals")
	local a = r and r:FindFirstChild("Assets") and require(r.Assets)
	if a and a.play and a.play.people and not Notify.ICONS.people then Notify.ICONS.people = a.play.people end
end)
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
		icon(box, "level", 15, 0, 40, Color3.fromRGB(90, 170, 255), 4)
	else
		icon(box, r.kind == "Scissors" and "scissors" or "check", 15, 0, 40, Color3.fromRGB(236, 230, 210), 4) -- cream (was yellow); (rd6, grader B: 40, so the count sits under it, not on it)
	end
	if r.count then
		local function commas(v) local t = tostring(math.floor(tonumber(v) or 0)) local out = t:reverse():gsub("(%d%d%d)", "%1,"):reverse() return (out:gsub("^,", "")) end
		local c = txt(box, (r.kind == "Level" and tostring(r.count) or ("×" .. commas(r.count))), FX, 24, -10, 40, 90, 28, nil, nil, 5) -- (a level shows its number)
		new("UIStroke", { Thickness = 2, Transparency = 0.2, Parent = c })
	end
end

-- (live-like data rd3, grader B) each kind of notification gets its own icon (every row was the same green check)
local function kindIcon(n)
	if n.icon then return n.icon end
	local t = string.lower((n.title or "") .. " " .. (n.sub or ""))
	for _, pair in { { "rank", "rank" }, { "contract", "elims" }, { "weekly", "trophy" }, { "login", "bell" }, { "daily", "bell" },
		{ "level", "level" }, { "friend", "people" }, { "shop", "scissors" }, { "streak", "streak" } } do
		if string.find(t, pair[1], 1, true) and Notify.ICONS[pair[2]] then return pair[2] end
	end
	return "check"
end

-- one pill (banner or inbox row), design px
local function pill(parent, n, x, y, w, h)
	local p = new("CanvasGroup", { Name = "Pill", BackgroundColor3 = PILL, -- (e17, grader C: a CanvasGroup, so its pop fades too)
		 BackgroundTransparency = 0.05, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		ZIndex = 3, Parent = parent }, { new("UICorner", { CornerRadius = UDim.new(0, 12) }) }) -- (menus e9, grader B: 12 px corners, was a capsule)
	-- (menus e23, grader B) the icon sits in a 56 px darker tile, like RIVALS' task rows
	new("Frame", { Name = "IconTile", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, Position = UDim2.fromOffset(18, (h - 56) / 2), Size = UDim2.fromOffset(56, 56),
		ZIndex = 4, Parent = p }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local kind = kindIcon(n)
	icon(p, kind, 26, (h - 40) / 2, 40, kind == "check" and GREEN or Color3.new(1, 1, 1), 5)
	local t = txt(p, n.title or "", FX, math.floor(h * 0.42), 84, h * 0.06, w - 200, h * 0.52, nil, Enum.TextXAlignment.Left, 4) -- (e9, grader B: left-aligned at +96 beside the icon)
	t.TextScaled = false
	txt(p, n.sub or "", FB, math.floor(h * 0.24), 84, h * 0.56, w - 200, h * 0.32, GREY, Enum.TextXAlignment.Left, 4)
	rewardBox(p, n.reward, w - 96, math.max((h - 70) / 2, 30)) -- (rd3, grader A: under the age chip, which keeps the title line)
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
	p.GroupTransparency = 1 -- (e18, grader C: the banner fades in 0.2 s and out 0.3 s as it slides)
	TweenService:Create(p, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = home }):Play()
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- (rd3, grader C) a burst of notifications plays the sound once and moves along faster (10 in a row took 37 s)
	local burst = #queue > 0
	if Kit.sfx and not Notify._burst then pcall(Kit.sfx, "reward") end
	Notify._burst = burst
	task.spawn(function()
		-- (rd5, grader C) hold 1.4 s; only a lone banner (nothing queued by then) stays the full 3.4 s
		task.wait(1.4)
		if #queue == 0 then task.wait(2) end
		TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = home - UDim2.fromScale(0, 0.14), GroupTransparency = 1 }):Play()
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
	-- (2026-10-21, RIVALS pass) named: CloseInbox fades it. (menus e2, grader C) a button: a click outside the panel closes it,
	-- and it fades in instead of popping
	local dim = new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), Parent = inboxGui })
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	dim.Activated:Connect(function() Notify.CloseInbox() end)
	local canvas = Kit.canvas(inboxGui)
	inboxRoot = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local head = new("Frame", { Name = "Head", BackgroundColor3 = PILL, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(540, 120), Size = UDim2.fromOffset(828, 132),
		ZIndex = 2, Active = true, Parent = inboxRoot }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	icon(head, "inbox", 20, 10, 56, Color3.new(1, 1, 1), 3)
	txt(head, "Inbox", FX, 46, 84, 6, 400, 60, nil, Enum.TextXAlignment.Left, 3)
	txt(head, "All of your recent notifications end up here.\nYour inbox clears when you leave the server!", FB, 22, 24, 62, 780, 60, GREY, Enum.TextXAlignment.Left, 3)
	-- (menus e4, grader A) the inbox column starts at y 120 like its sibling News (was 208), rows span the full column and the
	-- age chip sits inside the row's top-right
	local x = Kit.closeButton(UDim2.fromOffset(84, 50))
	x.Position = UDim2.fromOffset(1394, 120)
	x.Parent = inboxRoot
	x.Activated:Connect(function() Notify.CloseInbox() end)
	local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(540, 264), Size = UDim2.fromOffset(846, 776), -- (rd5, grader C: 18 wider, the bar clears the rows)
		
		ScrollBarThickness = 10, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Active = true, Parent = inboxRoot }) -- (e4: one scrollbar style)
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(828, math.max(776, #inbox * 108)), Parent = list })
	if #inbox == 0 then
		txt(content, "Nothing yet", FX, 34, 0, 40, 828, 44, nil, nil, 3)
		txt(content, "Completed tasks, unlocks and rewards show up here.", FB, 22, 0, 86, 828, 30, GREY, nil, 3)
	end
	for i, n in inbox do
		local y = (i - 1) * 108
		local row = pill(content, n, 0, y, 828, 102)
		-- (menus e15, graders A + C) the age chip belongs to its row (it pops with it) and sits 24 in from the row's right end
		local chip = new("Frame", { BackgroundColor3 = PILL, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(828 - 24 - 90, 10), Size = UDim2.fromOffset(90, 28), ZIndex = 5, -- (e23: a small 28 chip; rd3, grader A: pinned on the title line, the reward sits under it)
			
			Parent = row }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		txt(chip, ago(n.t), FB, 16, 0, 0, 90, 28, GREY, Enum.TextXAlignment.Right, 6) -- (e16, grader A: the text ends 24 in from the row's end)
		-- (2026-10-21, RIVALS pass) the first rows pop in one after another (0.03 s apart) instead of all at once
		if Kit.popIn and i <= 10 then
			row.AnchorPoint = Vector2.new(0.5, 0.5); row.Position = UDim2.fromOffset(414, y + 51)
			pcall(Kit.popIn, row, 0.08 + i * 0.03)
		end
	end
	Kit.toScale(inboxRoot)
	-- the list's canvas: as tall as the rows (Scale is relative to the list's parent)
	-- (rd3, grader C) a fixed canvas from the row count, measured on the menu root (the open pop scales the list): with 10
	-- rows the old Scale maths stretched them 1.41x and the last rows couldn't be scrolled to
	-- (rd5, grader C) measured on the canvas, which the open / close pop doesn't scale, and through a local reference:
	-- CloseInbox clears inboxRoot before the close animation, and the old hook threw "attempt to index nil" on every close
	local H = math.max(776, #inbox * 108)
	local myCanvas = canvas
	local function fit()
		if not (myCanvas and myCanvas.Parent) then return end
		local unit = myCanvas.AbsoluteSize.Y / 1080
		if unit <= 0 then return end
		list.CanvasSize = UDim2.new(0, 0, 0, H * unit)
		content.Size = UDim2.fromScale(828 / 846, 1)
	end
	fit()
	myCanvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- (menus e4-e5, graders A + C) no idle scrollbar while the rows fit
	if #inbox * 108 <= 776 then
		list.ScrollBarImageTransparency = 1
		list.ScrollBarThickness = 0
		list.ScrollingEnabled = false
	end
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = BLUR }):Play() -- (e10-e18, grader C: the shared menu blur)
	if Kit.open then pcall(Kit.open, inboxRoot) end
end
function Notify.OpenInbox()
	unread = 0
	if onUnread then onUnread(0) end
	buildInbox()
end
function Notify.CloseInbox()
	if blur then TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play() end
	-- (2026-10-21, RIVALS pass) close with Kit.close (shrink + close sound) and fade the dim, then destroy; InboxOpen() is
	-- false at once, and a reopen during the 0.12 s builds a fresh one (this one is destroyed by its own callback)
	local g, r = inboxGui, inboxRoot
	inboxGui, inboxRoot = nil, nil
	if not g then return end
	local dim = g:FindFirstChild("Dim")
	if dim then TweenService:Create(dim, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play() end
	if Kit.close and r and r.Parent then
		local ok = pcall(Kit.close, r, function() g:Destroy() end)
		if ok then return end
	end
	g:Destroy()
end
function Notify.InboxOpen() return inboxGui ~= nil and inboxGui.Parent ~= nil end

---------------------------------------------------------------------------------------------------- news
-- "Read the latest news": the update notes, newest first (edit NEWS when a port goes out)
Notify.NEWS = {
	{ title = "After-match lobby", sub = "Walk around after a match: To Hub, Play Again or Rematch (best of three).", icon = "play" },
	{ title = "Weapon stats + Duel History", sub = "Kit > Statistics for each weapon, and your last 20 duels.", icon = "elims" },
	{ title = "Switch Weapons", sub = "Press M between rounds to change your loadout.", icon = "settings" },
}
-- (2026-10-23, menus e2, graders A + B + C vs RIVALS news_panel.png) News is RIVALS' article, not a stack of inbox pills: one
-- 832-wide column at y 119 that scrolls, a hero picture across its top, "UPDATE N" right-aligned under it, then each item as a
-- heading with its bullet line. Same gui variables as the inbox, so CloseInbox / the dim close it.
Notify.NEWS_UPDATE = Notify.NEWS_UPDATE or 36
function Notify.OpenNews()
	if inboxGui and inboxGui.Parent then inboxGui:Destroy() end
	inboxGui = new("ScreenGui", { Name = "InboxUI", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 26, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui") })
	local dim = new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), Parent = inboxGui })
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	dim.Activated:Connect(function() Notify.CloseInbox() end)
	local canvas = Kit.canvas(inboxGui)
	inboxRoot = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- (menus e5, graders A + B + C vs news_panel.png) the article runs to the screen bottom and scrolls: a ScrollingFrame with an
	-- automatic canvas and a list layout of fixed-size blocks (the pattern the Ranks rules use; e2's hand-sized canvas hid the
	-- children). Hero 16:9 (468 tall), headings 42 with even 48 gaps, the body regular 26 with the bullet hanging in its own column.
	local W, TOP, H = 832, 119, 961
	-- (menus e7, graders A + B + C) the plate is its own frame and the scroller is 22 wider, so the 9 px bar runs in the gap
	-- right of the panel instead of over the hero
	new("Frame", { Name = "Plate", BackgroundColor3 = PILL, BackgroundTransparency = 0.15, BorderSizePixel = 0, Position = UDim2.fromOffset(544, TOP),
		Size = UDim2.fromOffset(W, H), ZIndex = 2, Parent = inboxRoot }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local col = new("ScrollingFrame", { Name = "Article", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(544, TOP),
		Size = UDim2.fromOffset(W + 22, H), ScrollBarThickness = 10, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Active = true, ZIndex = 2, Parent = inboxRoot },
		{ new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	local FR = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium) -- (e6: this family has no Regular; it fell back to Source Sans)
	local order = 0
	local function block(h)
		order += 1
		-- (menus e9, grader C) CanvasGroups, so each block can fade in after the hero
		return new("CanvasGroup", { BackgroundTransparency = 1, GroupTransparency = 1, LayoutOrder = order, Size = UDim2.fromOffset(W - 12, h), ZIndex = 3, Parent = col })
	end
	local heroImg = ""
	pcall(function()
		local A = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Rivals"):WaitForChild("Assets"))
		heroImg = (A.gen and (A.gen.shop_bg_operator or A.gen.play_card_1v1)) or ""
	end)
	order += 1
	new("ImageLabel", { Name = "Hero", BackgroundColor3 = Color3.new(0, 0, 0), Image = heroImg, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromOffset(W, 468), ZIndex = 3,
		LayoutOrder = order, Parent = col }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	txt(block(130), "UPDATE " .. tostring(Notify.NEWS_UPDATE), FX, 44, 0, 8, W - 16, 56, nil, Enum.TextXAlignment.Right, 3)
	for _, n in Notify.NEWS do
		local bodyH = math.max(1, math.ceil(#(n.sub or "") / 60)) * 32 -- (e6-e7) about 60 characters a line at 26 px in 722
		local b = block(52 + 6 + bodyH + 16) -- (e14, grader A vs news_panel: ~60 from the last bullet to the next heading)
		-- (menus e20, grader B) a 40 px icon before each section head
		if n.icon and Notify.ICONS[n.icon] then local s = n.icon == "play" and 52 or 44 icon(b, n.icon, 34 - (s - 44) / 2, 4 - (s - 44) / 2, s, nil, 4) end -- (e22: the play glyph's art is smaller, drawn larger to match)
		txt(b, n.title, FX, 42, (n.icon and Notify.ICONS[n.icon]) and 86 or 36, 0, W - 110, 52, nil, Enum.TextXAlignment.Left, 3)
		txt(b, "•", FR, 26, 44, 58, 24, 34, GREY, Enum.TextXAlignment.Left, 3)
		local body = txt(b, n.sub or "", FR, 26, 70, 58, W - 110, bodyH, Color3.fromRGB(228, 228, 230), Enum.TextXAlignment.Left, 3) -- (e7, grader B: 90% white)
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
	end
	-- (menus e16, grader A vs news_panel) RIVALS' news close is a small 67x36 at (1402,119)
	local x = Kit.closeButton(UDim2.fromOffset(67, 36))
	x.Position = UDim2.fromOffset(1402, TOP)
	x.Parent = inboxRoot
	x.Activated:Connect(function() Notify.CloseInbox() end)
	Kit.toScale(inboxRoot)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = BLUR }):Play() -- (e10-e18, grader C: the shared menu blur)
	if Kit.open then pcall(Kit.open, inboxRoot) end
	if col.Name == "Article" then
		-- (menus e9, grader C) the hero fades in over 0.15 s, then the blocks follow 0.05 s apart
		local hero = col:FindFirstChild("Hero")
		if hero then
			hero.ImageTransparency = 1
			hero.BackgroundTransparency = 1
			TweenService:Create(hero, TweenInfo.new(0.15), { ImageTransparency = 0, BackgroundTransparency = 0 }):Play()
		end
		local i = 0
		for _, b in col:GetChildren() do
			if b:IsA("CanvasGroup") then
				i += 1
				task.delay(0.15 + (b.LayoutOrder - 1) * 0.05, function() TweenService:Create(b, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play() end)
			end
		end
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
		local badge = new("Frame", { Name = "Badge", BackgroundColor3 = Color3.fromRGB(230, 50, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(46, 8), Size = UDim2.fromOffset(24, 24),
			Visible = false, ZIndex = 4, Parent = btn }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		txt(badge, "0", FX, 16, 0, 0, 24, 24, nil, nil, 5) -- (2026-10-21, RIVALS pass) badge centre-anchored (same spot) so its pop grows from the middle
		if Kit.bindButton then Kit.bindButton(btn, { hover = 1.1 }) end -- (2026-10-21, RIVALS pass) hover grow / press squash + sounds
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
	onUnread = function(n)
		local changed = n ~= unreadN
		unreadN = n
		refresh()
		-- (2026-10-21, RIVALS pass) the badge that shows the count punches when it changes
		if changed and n > 0 and Kit.pop then
			for _, m in made do if m.badge.Visible then pcall(Kit.pop, m.badge, 1.35) end end
		end
	end
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
