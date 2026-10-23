-- Client/Controllers/LobbyHudController (ModuleScript, auto-loaded): the lobby HUD around the PLAY row and the dock,
-- RIVALS' layout in TACTICALS' look.
--   * Top centre: the scissors pill (the 3D scissors, your count, + opens the scissors shop).
--   * Left: DAILY MISSIONS (the real daily quests with progress, claimable ones flagged) and DUEL PADS under it.
--   * Right: the player list, RIVALS's fake Roblox-style one: black panel, x to hide, a 3D icon that switches Level / Wins,
--     40 px rows (name left, number right). Tab slides it out and back. Replaces the Roblox list.
-- Follows the lobby: hidden while a menu is open (LobbyUI disabled), in the Kit room (dock hidden), on a pad and in Training.
-- Built in 1920x1080 design px on a 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyHud = {}
local buildCorner
local resetNav = function() end

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local PseudoLobby = require(UIKit:WaitForChild("PseudoLobby")) -- the after-match lobby in the match places (no-op in the hub)
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer

-- (2026-10-21, RIVALS 1:1) the hub (scissors pill, missions widget, Duel Pads, nav dock, join bubble) is a 1:1 port of the
-- replica's HudController (rivals_practice/ui/hud): every colour / font of those pieces comes from UIKit.Rivals.Theme. Values
-- the Rivals Theme has no token for yet are read from Theme.hud[name] when it exists, else the replica's measured value, so a
-- re-theme is one file (add a `hud` table to UIKit.Rivals.Theme). Layout / tweens stay on our UIKit.Kit (same converter).
local RUI = UIKit:WaitForChild("Rivals")
local RTheme = require(RUI:WaitForChild("Theme"))
local RKit = require(RUI:WaitForChild("Kit"))
local RAssets = require(RUI:WaitForChild("Assets"))
local RC = RTheme.color
local R_FAMILY = RTheme.font.medium.Family -- Rubik
local R_BOLD = Font.new(R_FAMILY, Enum.FontWeight.Bold) -- the replica HUD's FB
local function rtok(name, default)
	local t = RTheme.hud
	if t and t[name] ~= nil then return t[name] end
	return default
end
local RH = RTheme.hex
local R_HUD = {
	pillBg = rtok("pillBg", RC.textDark), pillAlpha = rtok("pillAlpha", 0.45),
	plusGrad = rtok("plusGrad", { RH("#9CFF6A"), RH("#3FD21E") }),
	widgetBg = rtok("widgetBg", RC.textDark), widgetAlpha = rtok("widgetAlpha", 0.5),
	taskDone = rtok("taskDone", RH("#D9D6DA")), barBack = rtok("barBack", RC.textDark), barFill = rtok("barFill", RC.blue),
	duelsGrad = rtok("duelsGrad", { RH("#7FD8FF"), RH("#0A6CF2") }), duelsEdge = rtok("duelsEdge", RH("#9BE7FF")),
	navShade = rtok("navShade", RH("#141218")), navShadeAlpha = rtok("navShadeAlpha", 0.25), disc = rtok("disc", RC.textDark),
}

-- (2026-10-21, Edward's font decision: Gotham / Montserrat read as AI-made) headings Oswald Bold, body Rubik (Theme.font)
local OSWALD = Theme.font.display
local BODY = Theme.font.medium
local BOLD = Theme.font.bold
-- (2026-10-21, AI-tells cleanup) the old yellow accent is cream now; the player list drops Builder Sans: names Rubik, numbers Oswald
local BONE, FIELD, OLIVE, OLIVE_HI = hex("#ECE8DA"), hex("#969C8C"), Theme.color.cream, Theme.color.cream
local LB_NAME, LB_NUM = BODY, OSWALD
local GUN, DEEP, LINE, RED = hex("#1A1D1A"), hex("#0C0E0B"), hex("#40463A"), hex("#D6403A")

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, Parent = parent })
end
-- (Edward 2026-10-16: no "4 corners box" look) panels get RIVALS' soft rounded corners.
-- (2026-10-21, AI-tells cleanup) no thin edge stroke any more: the panel's own dark fill separates it
local function brackets(p, color, len, th, z)
	if not p:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, math.clamp(math.floor(len * 0.6), 6, 14)); c.Parent = p
	end
	local old = p:FindFirstChild("_Edge")
	if old then old:Destroy() end
end
local function commas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- the top-right corner, built the way RIVALS builds it (read from its client code, 2026-10-16): its own bars in the
-- Roblox top-bar row, styled like Roblox's top bar (dark pills 18,18,21 @ 0.08, white icons, a speech bubble on hover).
--   * Main bar: closed it shows one gear ("See more"); clicked, the pill widens (Quint 0.25) to show Settings and Codes
--     and the gear turns into an X ("See less").
--   * Context bar, left of it: the player list button, only while the list is closed.
--   * Region and fps / ping lines left of the bars.
-- Icons are Roblox's own client textures (rbxasset://), not uploads. Pinned to the real screen corner (Scale + aspect
-- lock), built in a 560x80 design box.
local ICON_GEAR = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png"
local ICON_X = "rbxasset://textures/ui/InspectMenu/x.png"
local ICON_PLAYERS = "rbxasset://textures/ui/Settings/MenuBarIcons/PlayersTabIcon.png"
local ICON_CODES = "rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png"
local ICON_HUD = "rbxasset://textures/ui/Settings/MenuBarIcons/CaptureTab.png"
local ICON_LEAVE = "rbxasset://textures/ui/Settings/Help/LeaveIcon.png"
local BAR_BG, BAR_T, BAR_ICON = Color3.fromRGB(18, 18, 21), 0.08, Color3.fromRGB(247, 247, 248)
buildCorner = function(gui, cb)
	local TweenService = game:GetService("TweenService")
	local W, H = 560, 80
	local CY, B, GAP = 33, 44, 8 -- row centre, button / pill height, gap between bars
	local frame = new("Frame", { Name = "HudCorner", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1, H / 1080),
		BackgroundTransparency = 1, ZIndex = 20, Parent = gui }, { new("UIAspectRatioConstraint", { AspectRatio = W / H, DominantAxis = Enum.DominantAxis.Height }) })
	local function sx(x) return x / W end
	local function sy(y) return y / H end
	local function pill(name)
		return new("Frame", { Name = name, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(sx(W - 12), sy(CY)), Size = UDim2.fromScale(sx(B), sy(B)),
			BackgroundColor3 = BAR_BG, BackgroundTransparency = BAR_T, ZIndex = 20, Parent = frame }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	local mainPill, ctxPill = pill("MainBar"), pill("ContextBar")
	-- the hover bubble (one, moved under whichever button is hovered)
	local bubble = new("Frame", { Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(sx(190), sy(30)), BackgroundColor3 = BAR_BG,
		BackgroundTransparency = BAR_T, Visible = false, ZIndex = 30, Parent = frame }, { new("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(10 / 190, 10 / 30), Rotation = 45, BackgroundColor3 = BAR_BG,
		BackgroundTransparency = BAR_T, BorderSizePixel = 0, ZIndex = 30, Parent = bubble })
	local bubbleText = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.15), Size = UDim2.fromScale(0.88, 0.7), TextScaled = true,
		FontFace = BODY, TextColor3 = BAR_ICON, Text = "", ZIndex = 31, Parent = bubble }) -- (2026-10-21, AI-tells cleanup) Rubik, was Builder Sans
	local function button(name, icon, tip)
		local b = new("ImageButton", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(sx(B), sy(B)), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1, AutoButtonColor = false, Image = "", ZIndex = 22, Visible = false, Parent = frame }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local img = new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1, Image = icon, ImageColor3 = BAR_ICON, ZIndex = 23, Parent = b })
		local entry = { b = b, img = img, tip = tip }
		b.MouseEnter:Connect(function()
			b.BackgroundTransparency = 0.9 -- the soft hover circle
			bubbleText.Text = entry.tip
			-- keep the bubble on screen: it never sticks out past the right edge
			local x = math.min(b.Position.X.Scale, sx(W - 4 - 95))
			bubble.Position = UDim2.fromScale(x, sy(CY + B / 2 + 10))
			bubble.Visible = entry.tip ~= ""
		end)
		b.MouseLeave:Connect(function() b.BackgroundTransparency = 1; bubble.Visible = false end)
		return entry
	end
	local open = button("Open", ICON_GEAR, "See more")
	local settings = button("Settings", ICON_GEAR, "Change your crosshair & hotkeys")
	-- (2026-10-18, Edward: "keep the corner gear and add your changes to it") RIVALS' corner: News + Inbox beside Settings
	local news = button("News", Kit.glyph("news", Kit.ICONS.news), "Read the latest news")
	local inbox = button("Inbox", Kit.glyph("inbox", Kit.ICONS.inbox), "View your recent notifications")
	-- unread notifications: a red count on the gear while the corner is shut, on the Inbox while it's open
	local function dot(parent)
		local d = new("Frame", { Name = "Unread", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.15), Size = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(230, 50, 50), Visible = false, ZIndex = 25, Parent = parent }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("TextLabel", { Name = "N", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "0", TextColor3 = Color3.new(1, 1, 1),
			FontFace = OSWALD, ZIndex = 26, Parent = d }) -- (2026-10-21, AI-tells cleanup) Oswald count, was Builder Sans
		return d
	end
	local codes = button("Codes", ICON_CODES, "Redeem a code")
	local list = button("PlayerList", ICON_PLAYERS, "Open the player list")
	local hud = button("HUD", ICON_HUD, "Enable your HUD")
	local leave = button("Leave", ICON_LEAVE, "Leave the training room")
	-- (2026-10-21, RIVALS pass) the corner's Settings / News / Inbox react like every other button (grow on hover, squash on press)
	for _, e in { settings, news, inbox } do Kit.bindButton(e.b, { hover = 1.1 }) end

	local BODYI = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium, Enum.FontStyle.Italic) -- (2026-10-21) Rubik, was Gotham
	local function line(y)
		return new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(sx(W - 70), sy(y)), Size = UDim2.fromScale(sx(260), sy(16)), BackgroundTransparency = 1,
			Text = "", TextScaled = true, TextColor3 = hex("#D9D9D9"), TextTransparency = 0.15, FontFace = BODYI, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21, Parent = frame })
	end
	local region, stats = line(17), line(35)
	task.spawn(function()
		local NAMES = { US = "United States", GB = "United Kingdom", CA = "Canada", AU = "Australia", DE = "Germany", FR = "France", NL = "Netherlands", BR = "Brazil", JP = "Japan", SG = "Singapore", IN = "India", MX = "Mexico" }
		local LS = game:GetService("LocalizationService")
		local ok, code = pcall(LS.GetCountryRegionForPlayerAsync, LS, player)
		region.Text = ok and (NAMES[code] or code) or ""
	end)
	local frames, t0 = 0, os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local dt = os.clock() - t0
		if dt >= 0.5 then
			stats.Text = math.floor(frames / dt + 0.5) .. "fps  " .. math.floor(player:GetNetworkPing() * 1000 + 0.5) .. "ms"
			frames, t0 = 0, os.clock()
		end
	end)

	local isOpen = false
	local ctl = { frame = frame }
	local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	-- lay a bar out from its right edge: buttons right to left; returns the bar's left edge
	local function placeBar(p, right, items)
		local n = #items
		p.Visible = true
		TweenService:Create(p, TI, { Position = UDim2.fromScale(sx(right), sy(CY)), Size = UDim2.fromScale(sx(n * B), sy(B)) }):Play()
		for i, e in items do
			e.b.Position = UDim2.fromScale(sx(right - (i - 0.5) * B), sy(CY))
			e.b.Visible = true
		end
		return right - n * B
	end
	function ctl.layout()
		if not isOpen then settings.b.Visible = false; codes.b.Visible = false end
		codes.b.Visible = false
		local left = placeBar(mainPill, W - 12, isOpen and { open, settings, news, inbox } or { open })
		if not isOpen then news.b.Visible = false; inbox.b.Visible = false; settings.b.Visible = false end
		if ctl.unreadDots then ctl.unreadDots() end
		local ctxItems = {}
		if not cb.listShown() then table.insert(ctxItems, list) else list.b.Visible = false end
		if cb.hudHidden and cb.hudHidden() then table.insert(ctxItems, hud) else hud.b.Visible = false end
		if cb.canLeave and cb.canLeave() then table.insert(ctxItems, leave) else leave.b.Visible = false end
		if #ctxItems > 0 then
			left = placeBar(ctxPill, left - GAP, ctxItems)
		else
			ctxPill.Visible = false
		end
		for _, l in { region, stats } do
			TweenService:Create(l, TI, { Position = UDim2.fromScale(sx(left - 10), l.Position.Y.Scale) }):Play()
		end
		-- the open button turns into an X ("See less") with a little pop, like RIVALS
		local want = isOpen and ICON_X or ICON_GEAR
		if open.img.Image ~= want then
			open.img.Image = want
			open.img.Size = UDim2.fromScale(0, 0)
			TweenService:Create(open.img, TI, { Size = UDim2.fromScale(isOpen and 0.4 or 0.5, isOpen and 0.4 or 0.5) }):Play()
		end
		open.tip = isOpen and "See less" or "See more"
		bubble.Visible = false
	end
	open.b.Activated:Connect(function() isOpen = not isOpen; ctl.layout() end)
	settings.b.Activated:Connect(function() isOpen = false; ctl.layout(); cb.openSettings() end)
	codes.b.Activated:Connect(function() isOpen = false; ctl.layout(); if cb.openCodes then cb.openCodes() end end)
	news.b.Activated:Connect(function() isOpen = false; ctl.layout(); if cb.openNews then cb.openNews() end end)
	inbox.b.Activated:Connect(function() isOpen = false; ctl.layout(); if cb.openInbox then cb.openInbox() end end)
	local gearDot, inboxDot = dot(open.b), dot(inbox.b)
	local unreadN = 0
	function ctl.unreadDots()
		for _, d in { gearDot, inboxDot } do d.N.Text = unreadN > 9 and "9+" or tostring(unreadN) end
		gearDot.Visible = unreadN > 0 and not isOpen
		inboxDot.Visible = unreadN > 0 and isOpen
	end
	function ctl.setUnread(n)
		local up = n > unreadN
		unreadN = n; ctl.unreadDots()
		-- (2026-10-21, RIVALS pass) a new notification: the red count punches
		if up then for _, d in { gearDot, inboxDot } do if d.Visible then Kit.pop(d, 1.3) end end end
	end
	list.b.Activated:Connect(function() cb.openList() end)
	hud.b.Activated:Connect(function() if cb.showHud then cb.showHud() end end)
	leave.b.Activated:Connect(function() if cb.leave then cb.leave() end end)
	ctl.layout()
	return ctl
end

local NotifyRef -- UIKit.Notify once loaded (the corner's Inbox / News)
function LobbyHud.Start()
	-- (2026-10-18) RIVALS' notification banner + Inbox, and the top-right Inbox / News / Settings buttons with tooltips
	task.spawn(function()
		local okN, Notify = pcall(require, UIKit:WaitForChild("Notify", 10))
		if not okN or not Notify then return end
		Notify.Hook()
		-- Inbox / News live in the corner gear (buildCorner); it shows the unread count
		NotifyRef = Notify
	end)
	PseudoLobby.Guard() -- match places: the lobby GUIs stay off during a (rematch) game
	PseudoLobby.WaitMap() -- match places: built once the after-match lobby map is out (UIKit.PseudoLobby hides it during a match)
	local LobbyUI = shared.Get and shared.Get("LobbyUIController")
	local gui = new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui") })
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	---------------------------------------------------------------------------------------------- scissors pill
	-- (2026-10-21, RIVALS 1:1) the replica's key pill, with our 3D scissors in the key's place: a 122 x 38 black pill at 0.45
	-- (design 893, 42), corner 8, the count in Rubik Bold 30 white, the 56 px render overlapping its left end (862, 30) and a
	-- 32 px lime + (1015, 45). One transparent "Scissors" frame (862-1047 x 30-86) holds them, so the push-aside / Kit-room code
	-- that looks the pill up by name still finds it.
	local pill = new("Frame", { Name = "Scissors", Position = UDim2.fromOffset(862, 30), Size = UDim2.fromOffset(185, 56), BackgroundTransparency = 1, Parent = root })
	new("Frame", { Name = "Plate", Position = UDim2.fromOffset(31, 12), Size = UDim2.fromOffset(122, 38), BackgroundColor3 = R_HUD.pillBg,
		BackgroundTransparency = R_HUD.pillAlpha, ZIndex = 1, Parent = pill }, { RKit.corner(8) })
	local iconHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(56, 56), ZIndex = 3, Parent = pill })
	local count = RKit.label({ Text = "...", FontFace = R_BOLD, TextSize = 30, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(51, 12), Size = UDim2.fromOffset(90, 38), ZIndex = 3, Parent = pill })
	local plus = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(153, 15), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = RC.white, ZIndex = 3, Parent = pill },
		{ RKit.corner(5), RKit.vgrad(R_HUD.plusGrad) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 6), BackgroundColor3 = RC.white, BorderSizePixel = 0, ZIndex = 4, Parent = plus }, { RKit.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 18), BackgroundColor3 = RC.white, BorderSizePixel = 0, ZIndex = 4, Parent = plus }, { RKit.corner(2) })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() if LobbyUI and LobbyUI.OpenShop then LobbyUI.Close(); LobbyUI.OpenShop("Scissors") end end)

	---------------------------------------------------------------------------------------------- missions widget
	-- (2026-10-21, RIVALS 1:1) the replica's Daily Tasks widget: a 350 x 255 black box at 0.5 (design 10, 405), corner 6; the
	-- 38 px clipboard (our 3D one) at (10, 10) and "Daily Missions" in Rubik Bold 34 at (55, 8). Rows from y 64, 67 apart (built
	-- in refresh). The grade1-3 fading wash, Oswald and the hover grow are gone (the replica's widget has none of them).
	-- (2026-10-21, port3) RIVALS' t0000 widget: a lighter see-through black backing that fades out to the right (UIGradient
	-- 0 -> 0.45 -> 1 on top of widgetAlpha 0.35), 430 wide so the fade runs past the rewards; the title is Rubik Bold 26
	-- (~2.2 % h) beside a 32 px clipboard
	local WFONT = R_BOLD
	local MW, MH = 430, 255
	local missions = new("TextButton", { Name = "Missions", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, 405), Size = UDim2.fromOffset(MW, MH),
		BackgroundColor3 = R_HUD.widgetBg, BackgroundTransparency = rtok("widgetFadeAlpha", 0.35), Parent = root }, { RKit.corner(6),
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.45), NumberSequenceKeypoint.new(1, 1) }) }) })
	local clipHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40), ZIndex = 3, Parent = missions }) -- (round 1: 32 -> 40, RIVALS' calendar ~40)
	RKit.label({ Text = "Daily Missions", FontFace = WFONT, TextSize = 29, TextColor3 = RC.text, Position = UDim2.fromOffset(52, 9), Size = UDim2.fromOffset(300, 38), ZIndex = 3, Parent = missions }) -- (round 1, grader B: ~1.12x the task labels, was 26)
	local reset = Kit.label({ Text = "", FontFace = WFONT, TextSize = 1, TextTransparency = 1, Size = UDim2.fromOffset(1, 1), Parent = missions }) -- (timer lives in Missions)
	local ROWS_H = MH - 58 -- rows frame starts at y 58, so a replica row y (64 + (i - 1) * 67) is 6 + (i - 1) * 67 inside it
	local rows = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(MW, ROWS_H), ZIndex = 3, Parent = missions })
	missions.Activated:Connect(function() if LobbyUI then LobbyUI.Open("Missions") end end)
	-- (2026-10-21, RIVALS 1:1) Duel Pads = the replica's "To Duels": 197 x 48 at (91, 688), corner 6, the blue gradient
	-- #7FD8FF -> #0A6CF2 with a light cyan edge, white Rubik Bold 28 between two six-point stars (Rivals Assets.tasks.star6).
	-- Title case like RIVALS ("To Duels"); the earlier field-green fill and caps are gone.
	local toPads = new("TextButton", { Name = "ToPads", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(91, 688), Size = UDim2.fromOffset(197, 48), BackgroundColor3 = RC.white,
		Parent = root }, { RKit.corner(6), RKit.vgrad(R_HUD.duelsGrad), RKit.stroke(R_HUD.duelsEdge, 1.5, 0.1) })
	local tpRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = toPads },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- (2026-10-21, RIVALS images) gen.tasks_star6: RIVALS' twisted pinwheel star on both sides (the PIL star6 as fallback)
	local STAR = (RAssets.gen and RAssets.gen.tasks_star6) or (RAssets.tasks and RAssets.tasks.star6) or ""
	new("ImageLabel", { LayoutOrder = 1, BackgroundTransparency = 1, Image = STAR, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(30, 30), ZIndex = 3, Parent = tpRow })
	RKit.label({ LayoutOrder = 2, Text = "Duel Pads", FontFace = WFONT, TextSize = 28, TextColor3 = RC.text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 48), ZIndex = 3, Parent = tpRow })
	new("ImageLabel", { LayoutOrder = 3, BackgroundTransparency = 1, Image = STAR, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(30, 30), ZIndex = 3, Parent = tpRow })
	Kit.bindButton(toPads, { hover = 1.1 }) -- (2026-10-22, RIVALS: primary buttons grow ~1.1, like PLAY)
	function LobbyHud.ToPads()
		-- straight to the duel hall, in front of the first pad (not on it)
		local duels = workspace:FindFirstChild("LobbyMap") and workspace.LobbyMap:FindFirstChild("Duels")
		local pad = duels and (duels:FindFirstChild("Pad_1v1_A") or duels:FindFirstChildWhichIsA("Model"))
		local holo = pad and (pad:FindFirstChild("Holo") or pad:FindFirstChildWhichIsA("BasePart", true))
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if holo and hrp then
			-- stand on the hall side of the pad (towards the Duels centre), facing it, camera behind you
			local padPos = pad:GetBoundingBox().Position
			-- the hall centre = the middle of all its pads (Duels is a Folder)
			local sum, n = Vector3.zero, 0
			for _, m in duels:GetChildren() do
				if m:IsA("Model") then sum += m:GetBoundingBox().Position; n += 1 end
			end
			local hallPos = n > 0 and sum / n or padPos + Vector3.new(0, 0, 20)
			local away = Vector3.new(hallPos.X - padPos.X, 0, hallPos.Z - padPos.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
			local _, padSize = pad:GetBoundingBox()
			local spot = padPos + away * (math.max(padSize.X, padSize.Z) / 2 + 7)
			local hit = workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -50, 0))
			local ground = (hit and hit.Position or spot) + Vector3.new(0, 3, 0)
			hrp.CFrame = CFrame.lookAt(ground, Vector3.new(padPos.X, ground.Y, padPos.Z))
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(ground + away * 12 + Vector3.new(0, 5, 0), Vector3.new(padPos.X, ground.Y, padPos.Z))
		end
	end
	toPads.Activated:Connect(function() LobbyHud.ToPads() end)

	---------------------------------------------------------------------------------------------- searching (online)
	-- (2026-10-21, RIVALS 1:1) the replica's searching pill (rivals_practice/ui/play/PlayController "matchmaking"), the same one
	-- PlayScreen shows while Play is open: a 540 x 80 black pill at 0.25, corner 8, at the top centre (replica 692, 119: under
	-- the scissors pill), the six-point sparkle (44 px), "Searching for players..." (Rubik Medium 21) over the mode (Rubik Bold
	-- 27), the clock (Rubik Bold 30, right-aligned to x 430) and the red X (Rivals Kit.closeButton 76 x 52) that cancels. Live
	-- RIVALS hides PLAY while it shows (the Heartbeat below). The bracketed olive box over PLAY and its blinking marks are gone.
	local seek = new("Frame", { Name = "Searching", Position = UDim2.fromOffset(692, 119), Size = UDim2.fromOffset(540, 80), BackgroundColor3 = RC.textDark,
		BackgroundTransparency = 0.1, Visible = false, ZIndex = 10, Parent = root }, { RKit.corner(8) }) -- (m7, grader B vs t0018: 0.25 let the lobby signs show through)
	new("ImageLabel", { BackgroundTransparency = 1, Image = RAssets.tasks and RAssets.tasks.star6 or "", Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(44, 44), ZIndex = 11, Parent = seek })
	local seekStatus = RKit.label({ Name = "Status", Text = "Searching for players.", FontFace = RTheme.font.medium, TextSize = 21, TextColor3 = RC.text,
		Position = UDim2.fromOffset(74, 10), Size = UDim2.fromOffset(300, 28), ZIndex = 11, Parent = seek })
	local seekMode = RKit.label({ Name = "Mode", Text = "", FontFace = R_BOLD, TextSize = 27, TextColor3 = RC.text, Position = UDim2.fromOffset(74, 38), Size = UDim2.fromOffset(320, 32),
		ZIndex = 11, Parent = seek })
	local seekClock = RKit.label({ Name = "Clock", Text = "0:00", FontFace = R_BOLD, TextSize = 30, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(100, 80), ZIndex = 11, Parent = seek })
	local seekX = RKit.closeButton(UDim2.fromOffset(76, 52))
	seekX.Position = UDim2.fromOffset(448, 14)
	seekX.ZIndex = 11
	seekX.Parent = seek
	local Request = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby"):WaitForChild("Request")
	seekX.Activated:Connect(function() pcall(Request.InvokeServer, Request, "CancelMatch") end)

	---------------------------------------------------------------------------------------------- player list (RIVALS style)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	-- (2026-10-21, grade1) the panel is as tall as its rows (34 px header + 40 px a row + 4), up to LB_H = 40% of the screen,
	-- then it scrolls; it was always 536 tall, a big dark box holding one row. buildList sets the height.
	local LB_W, LB_H = 320, 432
	local lbH = 78
	-- (2026-10-21, RIVALS 1:1) RIVALS' corner list (t0166 / t0193 / t0247 / t0270): a compact translucent black panel under the
	-- gear, colours / fonts from UIKit.Rivals.Theme (names Rubik Medium, the number Rubik SemiBold, all white).
	local LBF_NAME, LBF_NUM = RTheme.font.medium, RTheme.font.heavy
	local lb = new("Frame", { Name = "PlayerList", Position = UDim2.fromOffset(1590, 96), Size = UDim2.fromOffset(LB_W, lbH), BackgroundColor3 = RC.textDark,
		BackgroundTransparency = rtok("listAlpha", 0.3), Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	-- the x and the column icon sit in a 34 px header strip, so they keep their size while the panel's height changes
	local lbHead = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.fromOffset(LB_W, 34), Parent = lb })
	local lbHide = new("TextButton", { Name = "Hide", Text = "×", TextColor3 = RC.text, FontFace = LBF_NAME, TextSize = 30, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(28, 30), Parent = lbHead })
	local lbMode = new("TextButton", { Name = "Mode", Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(280, 4), Size = UDim2.fromOffset(26, 26), Parent = lbHead })
	-- (2026-10-21, RIVALS 1:1) the column icon is one ImageLabel whose Image changes (was destroyed + rebuilt per switch)
	local lbModeIcon = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = "", ImageColor3 = RC.text, ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1), Parent = lbMode })
	local lbList = new("ScrollingFrame", { Name = "Rows", Position = UDim2.fromOffset(0, 34), Size = UDim2.fromOffset(LB_W, lbH - 34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = RC.track, ScrollBarImageTransparency = 0.3, CanvasSize = UDim2.new(), Parent = lb })


	---------------------------------------------------------------------------------------------- bottom nav (RIVALS' HUD bar)
	-- ported from the RIVALS replica (rivals_practice/ui/hud): a dark bar behind bold outlined labels, each item a big 3D icon
	-- on a dark disc, a red count badge, and on hover the item grows and lifts and a white speech bubble bobs above it.
	-- Replaces LobbyUI's old dock (its contents are hidden; the Dock frame stays as the "lobby is showing" signal).
	local Icons = require(script.Parent:WaitForChild("LobbyUIController"):WaitForChild("Icons"))
	local NAV_FONT = R_BOLD -- (2026-10-21, RIVALS 1:1) labels, badge counts and bubbles in Rubik Bold (the replica's FB), was Oswald
	-- (2026-10-21, RIVALS 1:1) bubble texts are RIVALS-style sentences again (replica: "View your weapons, career, emotes, & more",
	-- "Change crosshair & hotkeys"), worded for our screens
	local NAV = {
		{ Id = "Kit", Label = "Kit", Tip = "View your weapons, skins, & more", Build = function()
			local w = data and data.Loadout and data.Loadout.Weapon
			return Icons.Weapon(w or "Pistol") end, View = Icons.GunView, Zoom = 0.95, Tint = rtok("navKitTint", RC.gold), TintK = 0.3 }, -- (2026-10-21, port3) gold like RIVALS' Weapons render, was olive (read grey)
		{ Id = "Missions", Label = "Missions", Tip = "Complete missions to earn scissors", Build = Icons.Clipboard, View = CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), Zoom = 1.05 },
		{ Id = "Shop", Label = "Shop", Tip = "Unlock gear, skins, & more", Build = Icons.Crate, View = CFrame.Angles(math.rad(16), math.rad(28), 0), Zoom = 1.1 },
		{ Id = "Codes", Label = "Codes", Tip = "Redeem a code", Build = Icons.DogTags, View = CFrame.Angles(math.rad(6), math.rad(-15), 0), Zoom = 1.05, Tint = hex("#ECE6D2"), Stub = hex("#C8442E") },
		{ Id = "Settings", Label = "Settings", Tip = "Change crosshair & hotkeys", Build = Icons.Gear, View = CFrame.Angles(math.rad(10), math.rad(25), 0), Zoom = 1.1, Tint = hex("#D9A160") },
	}
	-- (2026-10-21, RIVALS 1:1) the replica's spacing: items 121 design px apart, 118 x 112 buttons bottom-anchored at y 1060, and
	-- its dark trapezoid bar (Rivals Assets.hud.navbar, #141218 at 0.25) behind the labels, 54 tall at y 1003, cut to our 5 items
	-- (replica: 784 wide for 6, so 784 - 121 = 663 for 5)
	local STEP = 121
	local shadeW = 784 - (6 - #NAV) * STEP
	new("ImageLabel", { Name = "NavShade", Position = UDim2.fromOffset(960 - shadeW / 2, 1003), Size = UDim2.fromOffset(shadeW, 54), BackgroundTransparency = 1,
		Image = RAssets.hud and RAssets.hud.navbar or "", ImageColor3 = R_HUD.navShade, ImageTransparency = R_HUD.navShadeAlpha, Parent = root })
	local navButtons, navBadges, navIcons = {}, {}, {}
	for i, it in NAV do
		local cx = 960 + (i - (#NAV + 1) / 2) * STEP
		local b = new("TextButton", { Name = "Nav" .. it.Id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(cx, 1060), Size = UDim2.fromOffset(118, 112), Parent = root })
		-- (2026-10-21, RIVALS 1:1) the replica's disc: 92 px at (59, 44), black with ONE fading UIGradient (0.55 top -> 0.3 -> 0.15
		-- bottom). The grade2/3 flat black 0.4 disc and the cream hover glow layer are gone.
		-- (2026-10-22, section rounds 0-1, graders A + B vs hub_full / t0060) RIVALS' dock icons stand ~0.068 H (73 px; ours 92) with
		-- 0.03 H clear under Play, labels ~13.5 px cap (Bold 21, was 25): disc 92 -> 80, icon box 104 -> 84
		new("Frame", { Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(59, 46), Size = UDim2.fromOffset(90, 90), BackgroundColor3 = RC.white, Parent = b }, -- (round 2, grader A: RIVALS' disc is 0.083 H = 90; 80 was a regression)
			{ RKit.corner(45), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(R_HUD.disc),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 0.15) }) }) })
		-- our 3D model sits where the replica's 92 px icon image sits (centre 59, 40)
		-- (2026-10-21, port3) icons ~9.5 % h: a 104 px box centred at (59, 38), so they overflow the disc like RIVALS' renders
		local holder = new("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(59, 46), Size = UDim2.fromOffset(84, 84), ZIndex = 2, Parent = b })
		local iconScale = new("UIScale", { Name = "HoverScale", Parent = holder })
		navIcons[it.Id] = { holder = holder, it = it, scale = iconScale }
		-- (2026-10-21, port3) label: Rubik Bold 25 with a thin 1.5 px stroke, bottom at y 104 (bar y 1052), so it sits up on the dark
		-- strip and overlaps the icon's bottom (icon box ends at 90) like RIVALS
		local lbl = RKit.label({ Text = it.Label, FontFace = NAV_FONT, TextSize = 21, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(59, 104), Size = UDim2.fromOffset(140, 30), ZIndex = 3, Parent = b })
		RKit.textStroke(1.5).Parent = lbl
		-- badge: 30 px Theme badge red at (92, 10), white ring 1.5 @ 0.2, Rubik Bold 21
		local badge = new("Frame", { Name = "Badge", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(92, 10), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = RC.badge, ZIndex = 4, Parent = b }, { RKit.corner(15), RKit.stroke(RC.white, 1.5, 0.2) })
		local bl = RKit.label({ Text = "", FontFace = NAV_FONT, TextSize = 21, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = badge })
		navBadges[it.Id] = { f = badge, l = bl, order = i }
		if it.Id == "Shop" then
			-- (2026-10-22, RIVALS) a red "1" on Shop while the daily free reward waits (server attribute DailyFreeAt <= now)
			task.spawn(function()
				while badge.Parent do
					local at = player:GetAttribute("DailyFreeAt")
					local ready = type(at) == "number" and at <= workspace:GetServerTimeNow()
					if ready ~= badge.Visible then badge.Visible = ready; bl.Text = "1"; if ready then Kit.pop(badge, 1.4) end end
					task.wait(1)
				end
			end)
		end
		-- bubble: the replica's white self-sizing pill (40 tall, corner 6) 14 px over the button, pointer = a Scale square locked
		-- to 40 % of the bubble height (NoConvert), text Rubik Bold 22 black padded with spaces
		local tip = new("Frame", { Name = "Bubble", Visible = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(59, -14), Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = RC.white, ZIndex = 10, Parent = b }, { RKit.corner(6) })
		tip:SetAttribute("KeepAuto", true)
		local ptr = new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0.4),
			BackgroundColor3 = RC.white, BorderSizePixel = 0, ZIndex = 9, Parent = tip }, { new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) })
		ptr:SetAttribute("NoConvert", true)
		RKit.label({ Text = "   " .. it.Tip .. "   ", FontFace = NAV_FONT, TextSize = 22, TextColor3 = RC.textDark, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), ZIndex = 11, Parent = tip })
		-- [PAD] (Edward 2026-10-20, RIVALS) the D-pad direction that opens it, beside the icon (shown with a controller)
		local padGlyph = new("ImageLabel", { Name = "PadGlyph", BackgroundTransparency = 1, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(100, 50), Size = UDim2.fromOffset(42, 42), ZIndex = 6, Parent = b })
		local sc = new("UIScale", { Parent = b })
		table.insert(navButtons, { b = b, s = sc, tip = tip, id = it.Id, pad = padGlyph, lbl = lbl })
		b.Activated:Connect(function() if LobbyUI then LobbyUI.Open(it.Id) end end)
	end
	-- (2026-10-21, RIVALS 1:1) RIVALS' resting "Join the queue to start playing!" over PLAY for new players (until they have queued
	-- or played once): the same plain white pill as the nav bubbles (Rubik Bold 22 black, corner 6, 40 tall, pointer down), its
	-- pointer 14 px over PLAY's top (replica PLAY top = 859). The cream pill / Oswald are gone.
	local joinTip = new("Frame", { Name = "JoinTip", Visible = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(960, 845), Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = RC.white, ZIndex = 5, Parent = root }, { RKit.corner(6) })
	joinTip:SetAttribute("KeepAuto", true)
	local joinPtr = new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = RC.white, BorderSizePixel = 0, ZIndex = 4, Parent = joinTip }, { new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) })
	joinPtr:SetAttribute("NoConvert", true)
	RKit.label({ Text = "   Join the queue to start playing!   ", FontFace = NAV_FONT, TextSize = 22, TextColor3 = RC.textDark, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40), ZIndex = 7, Parent = joinTip })

	Kit.toScale(root)
	do -- the join pill's bob: 4 px up and back over 1.2 s, only while shown
		local home = joinTip.Position
		task.spawn(function()
			while joinTip.Parent do
				if joinTip.Visible then
					Kit.tween(joinTip, 0.6, { Position = home - UDim2.fromScale(0, 4 / 1080) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.6)
					Kit.tween(joinTip, 0.6, { Position = home }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
				task.wait(0.6)
			end
		end)
	end

	-- [PAD] D-pad opens the nav screens from the hub (RIVALS: Weapons left, Tasks down, Shop right, Pass up). Only while the
	-- nav is on screen (it slides away for menus, duels and training) - in a round the D-pad equips weapons.
	do
		local DPAD = { Kit = Enum.KeyCode.DPadLeft, Missions = Enum.KeyCode.DPadDown, Shop = Enum.KeyCode.DPadRight } -- (Codes lost D-pad up: it is Dash, 2026-10-21)
		local padMode = false
		local function showGlyphs()
			for _, nb in navButtons do
				local code = DPAD[nb.id]
				local img = ""
				if code then pcall(function() img = UserInputService:GetImageForKeyCode(code) end) end
				nb.pad.Image = img
				nb.pad.Visible = padMode and img ~= ""
			end
		end
		local function onType(t)
			if t == Enum.UserInputType.MouseMovement then return end
			local pad = t.Name:find("Gamepad") ~= nil
			if not pad and not (t == Enum.UserInputType.Keyboard or t.Name:find("Mouse") or t == Enum.UserInputType.Touch) then return end
			if pad ~= padMode then padMode = pad; showGlyphs() end
		end
		UserInputService.LastInputTypeChanged:Connect(onType)
		onType(UserInputService:GetLastInputType())
		player:GetAttributeChangedSignal("_ForcePad"):Connect(function()
			if game:GetService("RunService"):IsStudio() then padMode = player:GetAttribute("_ForcePad") == true; showGlyphs() end
		end)
		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			for id, code in DPAD do
				if input.KeyCode == code then
					local nb
					for _, x in navButtons do if x.id == id then nb = x end end
					local b = nb and nb.b
					local vp = workspace.CurrentCamera.ViewportSize
					local onScreen = b and b.Visible and b.AbsolutePosition.Y < vp.Y and b.AbsolutePosition.Y + b.AbsoluteSize.Y > 0
					if onScreen and player:GetAttribute("InTraining") ~= true and LobbyUI then LobbyUI.Open(id) end
				end
			end
		end)
	end

	-- nav: 3D icons (after the conversion, so the viewports fill their holders), hover grow + lift + bobbing bubble.
	-- (2026-10-21, user: "whatever RIVALS is doing") back to the glossy 3D renders RIVALS uses on its nav, not flat icons
	-- (2026-10-21, grade1) brighter lighting than Icons' default (ambient ~+30%, white key light from the camera side; the
	-- default light came from behind the model) so dark models like the Kit pistol read on their disc
	-- (2026-10-21, grade2) the icons read grey-on-grey: each model is pulled ~45 % toward one saturated base colour (Kit olive /
	-- steel, Codes tan cream, Settings orange tan; Missions' clipboard and Shop's crate already had colour) and ambient goes to 220
	-- (2026-10-21, grade3) per-item strength (it.TintK, default 0.45): Kit drops to 25 % (45 % washed the pistol out). With
	-- it.Stub, the dark parts (luminance < 0.3: the tags' chain stub) take that colour and the rest go 60 % to the tint, so
	-- Codes reads as cream tags with a red stub.
	local function tintModel(m, c, it)
		if not c then return m end
		local stub = it and it.Stub
		local k = stub and 0.6 or (it and it.TintK) or 0.45
		local parts = m:IsA("BasePart") and { m } or {}
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
		for _, d in parts do
			if d.Material ~= Enum.Material.Neon then
				local col = d.Color
				local lum = 0.299 * col.R + 0.587 * col.G + 0.114 * col.B
				d.Color = (stub and lum < 0.3) and stub or col:Lerp(c, k)
			end
		end
		return m
	end
	-- (2026-10-21, port3) glossy + saturated like RIVALS' renders: every part's saturation x1.4 (+0.1) and value x1.15 (+0.06),
	-- SmoothPlastic so the key light leaves a sheen (the Kit pistol and the Shop crate read grey / olive before)
	local function glossModel(m)
		local parts = m:IsA("BasePart") and { m } or {}
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
		for _, d in parts do
			if d.Material ~= Enum.Material.Neon then
				local h, s, v = d.Color:ToHSV()
				d.Color = Color3.fromHSV(h, math.min(1, s * 1.4 + 0.1), math.min(1, v * 1.15 + 0.06))
				d.Material = Enum.Material.SmoothPlastic
			end
		end
		return m
	end
	-- (2026-10-21, port3) rim highlight: a white silhouette of the same model in a second ViewportFrame just behind and 6 % bigger,
	-- following the icon's sway every frame (and its model when Kit swaps guns), so each icon gets a soft light edge
	local function addRim(n)
		local main = n.vp.Frame
		main.ZIndex = 3
		local rim = new("ViewportFrame", { Name = "Rim", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.06, 1.06), Ambient = RC.white, LightColor = RC.white, ImageTransparency = rtok("iconRimAlpha", 0.45), ZIndex = 2, Parent = n.holder })
		local cam = new("Camera", { Parent = rim })
		rim.CurrentCamera = cam
		local world = new("WorldModel", { Parent = rim })
		local src, copy
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not rim.Parent or not main.Parent then conn:Disconnect() return end
			local w = main:FindFirstChildOfClass("WorldModel")
			local now = w and w:FindFirstChildOfClass("Model")
			if now ~= src then
				src = now
				if copy then copy:Destroy(); copy = nil end
				if not now then return end
				copy = now:Clone()
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") then
						d.Color = RC.white; d.Material = Enum.Material.SmoothPlastic
						if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
					elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then
						d:Destroy()
					end
				end
				copy.Parent = world
			end
			if copy and src then
				copy:PivotTo(src:GetPivot())
				if main.CurrentCamera then cam.FieldOfView = main.CurrentCamera.FieldOfView; cam.CFrame = main.CurrentCamera.CFrame end
			end
		end)
	end
	for id, n in navIcons do
		-- (2026-10-21, RIVALS 1:1) lit like the replica's bright Codex renders: neutral white key light from the camera side, ambient
		-- ~200 (the cream rim light on Kit is gone); zoom 1.12 fills the replica's 92 px icon box
		n.vp = Icons.Viewport(n.holder, glossModel(tintModel(n.it.Build(), n.it.Tint, n.it)), { view = n.it.View, zoom = n.it.Zoom * 1.12 })
		-- (2026-10-21, port3) brighter: ambient 200 -> 228, the white key light from the camera side
		n.vp.Frame.Ambient = rtok("iconAmbient", Color3.fromRGB(228, 228, 232))
		n.vp.Frame.LightColor = rtok("iconLight", RC.white)
		n.vp.Frame.LightDirection = Vector3.new(0.45, -0.7, 0.55)
		addRim(n)
		n.holderBase = n.holder.Position
	end
	Icons.Viewport(clipHolder, Icons.Clipboard(), { view = CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), zoom = 1.1 })
	-- (round 1, grader C) full brightness like RIVALS' calendar (the shared viewport light is dim on the see-through widget)
	for _, v in clipHolder:GetDescendants() do if v:IsA("ViewportFrame") then v.Ambient, v.LightColor = Color3.fromRGB(225, 225, 230), Color3.new(1, 1, 1) end end
	local navResets = {}
	function resetNav() for _, f in navResets do f() end end
	-- (2026-10-21, grade3) PLAY no longer yields while a dock item is hovered: the grade2 shrink to 0.94 + half fade read as
	-- "PLAY is disabled". Like RIVALS, the bubble simply draws over PLAY (this ScreenGui's DisplayOrder 7 > PlayRowUI's 6).
	-- dockHover is still kept: the "Join a match!" pill hides while a dock item is hovered.
	local dockHover = {} -- [nav id] = true while hovered
	local function setDockHover(id, on)
		dockHover[id] = on or nil
	end
	for _, n in navButtons do
		local base = n.b.Position
		local function away() return root:GetAttribute("PushedAway") == true end -- a menu is open: no hover (RIVALS)
		-- (2026-10-21, RIVALS 1:1) the replica's nav hover: the WHOLE item grows to 1.12 (Back, 0.15 s) and lifts 14 design px, the
		-- bubble shows at once (live: "nav bubbles appear immediately"), sits still 2 s, then repeats a slow 18 px hop (0.4 s up
		-- Quad Out, 0.6 s down Quad In) until unhovered. Press: 1.02, release: back to 1.12 (Back). The grade1-3 icon-only grow,
		-- 6 px lift, glow layer, 0.12 s bubble delay and 5 px bob are gone.
		-- (2026-10-22, live RIVALS feel study) a small 6 px lift (14 made the hovered Shop crate cover PLAY); labels rest light grey
		local lift = UDim2.fromScale(base.X.Scale, base.Y.Scale - 6 / 1080)
		local LBL_REST, LBL_ON = Color3.fromRGB(205, 205, 210), Color3.new(1, 1, 1)
		if n.lbl then n.lbl.TextColor3 = LBL_REST end
		-- (2026-10-22, 4:3) the dock is shifted onto the bottom edge by applyPins (attribute PinDy, Scale): hover / reset add it
		local function pinned(u) return UDim2.new(u.X.Scale, u.X.Offset, u.Y.Scale + (n.b:GetAttribute("PinDy") or 0), u.Y.Offset) end
		local tipBase = n.tip.Position
		local icon = navIcons[n.id]
		local hovered, gen = false, 0
		local function bob(myGen)
			task.wait(2)
			local up = UDim2.new(tipBase.X.Scale, 0, tipBase.Y.Scale - 18 / 112, 0)
			while hovered and gen == myGen do
				Kit.tween(n.tip, 0.4, { Position = up }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.wait(0.4)
				if not hovered or gen ~= myGen then return end
				Kit.tween(n.tip, 0.6, { Position = tipBase }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.6)
			end
		end
		-- the hovered item draws above its neighbours (ZIndex 2); a controller's selection drives the same enter / leave
		local function enter()
			if away() or hovered then return end
			hovered = true; gen += 1
			n.b.ZIndex = 2
			setDockHover(n.id, true)
			n.tip.Visible = true; n.tip.Position = tipBase
			task.spawn(bob, gen)
			if icon.vp then icon.vp.SetHover(true) end
			Kit.tween(n.s, 0.15, { Scale = 1.12 }, Enum.EasingStyle.Back)
			Kit.tween(n.b, 0.15, { Position = pinned(lift) }, Enum.EasingStyle.Back)
			if n.lbl then n.lbl.TextColor3 = LBL_ON end
		end
		local function leave()
			hovered = false; gen += 1
			n.b.ZIndex = 1
			setDockHover(n.id, false)
			n.tip.Visible = false; n.tip.Position = tipBase
			if away() then return end
			if icon.vp then icon.vp.SetHover(false) end
			Kit.tween(n.s, 0.15, { Scale = 1 })
			Kit.tween(n.b, 0.15, { Position = pinned(base) })
			if n.lbl then n.lbl.TextColor3 = LBL_REST end
		end
		n.b.MouseEnter:Connect(enter)
		n.b.MouseLeave:Connect(leave)
		n.b.SelectionGained:Connect(enter)
		n.b.SelectionLost:Connect(leave)
		table.insert(navResets, function()
			hovered = false; gen += 1
			n.b.ZIndex = 1
			setDockHover(n.id, false)
			n.tip.Visible = false; n.tip.Position = tipBase
			if icon.vp then icon.vp.SetHover(false) end
			n.s.Scale = 1
			icon.scale.Scale = 1
			n.b.Position = pinned(base)
		end)
		n.b.Activated:Connect(function() task.defer(resetNav) end) -- a click opens something: the bubble goes with it
		n.b.MouseButton1Down:Connect(function() if not away() then Kit.tween(n.s, 0.06, { Scale = 1.02 }) end end)
		n.b.MouseButton1Up:Connect(function() if not away() then Kit.tween(n.s, 0.12, { Scale = hovered and 1.12 or 1 }, Enum.EasingStyle.Back) end end)
	end
	-- hide the old dock's contents (the Dock frame keeps its Visible state for the Kit room / PlayRow)
	task.spawn(function()
		local lobby = player.PlayerGui:WaitForChild("LobbyUI", 30)
		local dock = lobby and lobby:FindFirstChild("Dock", true)
		if dock then
			for _, c in dock:GetChildren() do if c:IsA("GuiObject") then c.Visible = false end end
			dock.ChildAdded:Connect(function(c) if c:IsA("GuiObject") then c.Visible = false end end)
		end
		local shade = lobby and lobby:FindFirstChild("DockShade", true)
		if shade then shade.Visible = false end
	end)

	-- the 3D scissors in the pill (the same view icon as the shop's balance pill)
	local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
	-- (round 4, grader B: RIVALS' counter key is a solid glyph, ours a hairline 3D outline) the filled red scissors
	new("ImageLabel", { BackgroundTransparency = 1, Image = Kit.ICONS.scissorsReward or "", ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.1, 1.1), ZIndex = 3, Parent = iconHolder }) -- (round 8: = the Shop counter's ~30 px glyph)

	---------------------------------------------------------------------------------------------- data
	local data
	local function questDef(scope, id)
		for _, q in Config.Quests[scope].Pool do if q.Id == id then return q end end
	end
	local lastRows
	local shownKitWeapon
	-- (2026-10-21, RIVALS pass) what the widgets showed last: the scissors count and each mission's bar / done state, so changes animate
	local hudFx = { credits = nil, frac = {}, done = {}, paid = {} } -- (2026-10-21, auto-pay) + each mission's paid (Claimed) flag
	local function refresh()
		if not data then return end
		-- nav: the Kit icon follows your gun.
		-- (2026-10-21, grade1) Missions badge = daily missions not finished yet (RIVALS' Tasks count). It used to count claimable
		-- ones, and with auto-pay nothing is ever left to claim, so it sat at 0 and the dock had no badges at all
		local unfinished = 0
		local dq = data.Quests and data.Quests.Daily
		for _, e in (dq and dq.List) or {} do
			local def = questDef("Daily", e.Id)
			if def and not e.Claimed and ((data.Stats and data.Stats[def.Stat]) or 0) - (e.Base or 0) < def.Goal then unfinished += 1 end
		end
		local mb = navBadges and navBadges.Missions
		if mb then
		-- (2026-10-20, RIVALS' "Claim your FREE reward now!") a red callout bobs above Missions while a reward waits
		local navM = mb.f.Parent
		local call = navM and navM:FindFirstChild("Callout")
		if navM and not call then
			call = new("Frame", { Name = "Callout", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, -0.14), Size = UDim2.fromScale(2.0, 0.3),
				BackgroundColor3 = RC.badge, Visible = false, ZIndex = 9, Parent = navM }, { new("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.07, 0.38),
				SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = RC.badge, BorderSizePixel = 0, ZIndex = 8, Parent = call })
			local t = new("TextLabel", { BackgroundTransparency = 1, Text = "Claim your reward!", FontFace = NAV_FONT, -- (2026-10-21, RIVALS 1:1) the replica's ShopTip: Theme badge red, Rubik Bold
				TextScaled = true, TextColor3 = RC.text, Position = UDim2.fromScale(0.06, 0.14), Size = UDim2.fromScale(0.88, 0.72), ZIndex = 10, Parent = call })
			new("UITextSizeConstraint", { MaxTextSize = 22, Parent = t })
			local home = call.Position
			task.spawn(function()
				local bub = navM:FindFirstChild("Bubble")
				while call.Parent do
					call.Visible = call:GetAttribute("Want") == true and not (bub and bub.Visible) -- (the hover bubble takes its place)
					if call.Visible then
						Kit.tween(call, 0.6, { Position = home - UDim2.fromScale(0, 0.06) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						task.wait(0.6)
						Kit.tween(call, 0.6, { Position = home }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					end
					task.wait(0.6)
				end
			end)
		end
		-- (2026-10-21, auto-pay) tasks pay out by themselves now, so there is nothing to claim: the callout stays hidden
		if call then call:SetAttribute("Want", false); call.Visible = false end
		-- (2026-10-21, grade1) first show: pops in 0.8 -> 1 (staggered by dock slot); after that the count punches whenever it
		-- changes (a mission finished, a new day). (2026-10-21, RIVALS 1:1) the idle bob is gone: RIVALS' badges sit still.
		local was = mb.l.Text
		local wasShown = mb.f.Visible
		mb.f.Visible = unfinished > 0; mb.l.Text = tostring(unfinished)
		if mb.f.Visible and not wasShown then
			local ps = mb.f:FindFirstChildOfClass("UIScale") or new("UIScale", { Name = "PopScale", Parent = mb.f })
			ps.Scale = 0 -- held back until its turn in the stagger
			task.delay(0.15 + mb.order * 0.07, function() Kit.pop(mb.f, 0.8) end)
		elseif mb.f.Visible and was ~= mb.l.Text then
			Kit.pop(mb.f, 1.4)
		end
	end
		local w = data.Loadout and data.Loadout.Weapon
		if w and w ~= shownKitWeapon and navIcons and navIcons.Kit and navIcons.Kit.vp then
			shownKitWeapon = w
			navIcons.Kit.vp.SetModel(glossModel(tintModel(Icons.Weapon(w), navIcons.Kit.it.Tint, navIcons.Kit.it)), Icons.GunView) -- (2026-10-21, port3) keeps its gold tint + gloss; the rim follows the new model
		end
		-- (2026-10-21, RIVALS pass) the scissors count counts up from what was shown, and the pill pops when it rises
		local credits = data.Credits or 0
		if hudFx.credits == nil then
			count.Text = commas(credits)
		elseif credits ~= hudFx.credits then
			Kit.countTo(count, hudFx.credits, credits, 0.6, commas)
			if credits > hudFx.credits then Kit.pop(pill, 1.1) end -- (2026-10-21, grade2) the whole plate punches 1.1x
		end
		hudFx.credits = credits
		local q = data.Quests and data.Quests.Daily
		local key = ""
		local entries = {}
		for i, e in (q and q.List) or {} do
			local def = questDef("Daily", e.Id)
			if def then
				-- (2026-10-21, auto-pay) the server pays a finished mission by itself and sets Claimed: a paid mission reads full
				local claimed = e.Claimed == true
				local prog = claimed and def.Goal or math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (e.Base or 0), 0, def.Goal)
				table.insert(entries, { def = def, prog = prog, claimed = claimed, order = i })
			end
		end
		-- (2026-10-21, grade3) the same order as the Missions screen: MissionsScreen.scopePanel walks data.Quests.Daily.List with
		-- ipairs (the saved list order, no sort), so the hub uses the list index too (the grade2 pool-index sort disagreed with it)
		table.sort(entries, function(a, b) return a.order < b.order end)
		for _, en in entries do key ..= en.def.Id .. en.prog .. tostring(en.claimed) end
		if key == lastRows then return end
		lastRows = key
		for _, c in rows:GetChildren() do c:Destroy() end
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(MW, ROWS_H), ZIndex = 3, Parent = rows })
		local art = {}
		local fills = {} -- (2026-10-21, RIVALS pass) bars built at their old fraction, tweened to the new one after toScale
		local checkPops = {} -- (2026-10-21, auto-pay) checks of missions that just finished / just got paid: popped after toScale
		local firstBuild = next(hudFx.frac) == nil
		-- (2026-10-21, grade1) the same flat cream glyphs as the Missions screen (MissionsScreen FLAT_STAT), not tiny dark 3D models
		local FLAT_STAT = { Wins = "trophy", MatchesPlayed = "play", Kills = "lbElims", Headshots = "lbElims", CoverKills = "cover",
			MeleeKills = "melee", GadgetsThrown = "gadget" }
		-- (2026-10-21, port3) RIVALS' rows read "Play duels" / "Eliminations" / "Win duels": short stat names at ONE fixed size
		-- (Rubik Bold 24), the same map as MissionsScreen SHORT; no measuring, no shrinking, no ellipsis
		local SHORT = { Kills = "Eliminations", Headshots = "Headshots", MeleeKills = "Melee kills", CoverKills = "Cover kills",
			GadgetsThrown = "Gadgets", Wins = "Win matches", MatchesPlayed = "Play matches" }
		-- (2026-10-21, RIVALS 1:1) the replica's task rows (HudController Daily Tasks), 67 design px apart from widget y 64 (rows
		-- frame y 58, so 6 + (i - 1) * 67 here): a 32 px white glyph (ours) at (8, +6), the name in Rubik Bold 28 with a 1.5 text
		-- stroke at (47, 0), a 262 x 6 black-0.5 track at (45, +34) with a Theme blue fill (Theme green when done), the count
		-- "n / goal" (Rubik Bold 27, the "/ goal" at 17) right-aligned to x 307, and the reward the RIVALS way: the bright 3D
		-- scissors (34 px) at (312, 0) with "×N" (Rubik Bold 20) stacked under it. Done: a 40 px green check in place of the count
		-- and reward (ref_65). The cream glyphs / cream track / Oswald / separate reward column are gone.
		local CHECK = RAssets.tasks and RAssets.tasks.check or ""
		-- (2026-10-21, RIVALS images) RIVALS' claw for the elimination tasks (Kills, Headshots), the lime check (untinted) for done
		local GEN = RAssets.gen or {}
		-- (2026-10-21, port3) + the solid white gen art for cover (row_crouch), melee (kit_cat_knife) and gadgets (kit_cat_grenade)
		local GEN_GLYPH = { Kills = GEN.tasks_elims, Headshots = Kit.glyph("headshot", GEN.tasks_elims), CoverKills = GEN.row_crouch, MeleeKills = GEN.kit_cat_knife,
			GadgetsThrown = GEN.kit_cat_grenade, Wins = RAssets.tasks and RAssets.tasks.trophy, MatchesPlayed = RAssets.tasks and RAssets.tasks.play }
		local CHECK_LIME = GEN.tasks_check_lime
		-- (2026-10-21, port3) row layout, 67 apart: 30 px solid glyph at (14, +4), the short name (Rubik Bold 24, 1.5 stroke) at
		-- (52, 0), a 250 x 6 bar under the name (light track RC.track @ 0.35 so the blue reads on the see-through backing), the count
		-- right-aligned to x 318, and the reward RIVALS-style: a 46 px (4.3 % h) 3D scissors at (326, -6) with "×N" laid over its
		-- bottom-right corner. Done: the 40 px lime check where the reward sits.
		for i, e in entries do
			local y = 6 + (i - 1) * 67
			local done = e.claimed or e.prog >= e.def.Goal
			new("ImageLabel", { Name = "StatIcon", BackgroundTransparency = 1, Image = GEN_GLYPH[e.def.Stat] or Kit.ICONS[FLAT_STAT[e.def.Stat] or "trophy"], ImageColor3 = RC.white,
				ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(14, y + 4), Size = UDim2.fromOffset(30, 30), ZIndex = 4, Parent = holder })
			-- (round 1, grader B vs t0000: RIVALS' task labels are a soft grey #C4C5C9 so the white counts lead)
			local t = RKit.label({ Text = SHORT[e.def.Stat] or e.def.Short or e.def.Text, FontFace = WFONT, TextSize = 24, TextColor3 = done and R_HUD.taskDone or Color3.fromRGB(196, 197, 201),
				Position = UDim2.fromOffset(52, y), Size = UDim2.fromOffset(200, 32), ZIndex = 4, Parent = holder })
			RKit.textStroke(1.5).Parent = t
			-- (2026-10-22, section round 0, grader A: RIVALS' bar ~0.008 H = 8 px, was 6)
			local back = new("Frame", { Position = UDim2.fromOffset(52, y + 32), Size = UDim2.fromOffset(250, 8), BackgroundColor3 = rtok("barTrack", RC.track),
				BackgroundTransparency = 0.35, ClipsDescendants = true, ZIndex = 4, Parent = holder }, { RKit.corner(4) })
			local frac = math.clamp(e.prog / e.def.Goal, 0, 1)
			local wasFrac = hudFx.frac[e.def.Id] or frac
			local fill = new("Frame", { Size = UDim2.fromScale(wasFrac, 1), BackgroundColor3 = done and RC.green or R_HUD.barFill, ZIndex = 5, Parent = back }, { RKit.corner(3) })
			local fx = wasFrac ~= frac and { fill, frac, up = frac > wasFrac } or nil
			if fx then table.insert(fills, fx) end
			hudFx.frac[e.def.Id] = frac
			-- (2026-10-21, auto-pay) no CLAIM pill: the check pops when a mission finishes (or the server's payout flips Claimed) on screen
			local newlyDone = done and not firstBuild and hudFx.done[e.def.Id] == false
			local newlyPaid = e.claimed and not firstBuild and hudFx.paid[e.def.Id] == false
			hudFx.done[e.def.Id] = done
			hudFx.paid[e.def.Id] = e.claimed
			if done then
				local ck = new("ImageLabel", { Name = "Check", BackgroundTransparency = 1, Image = CHECK_LIME or CHECK, ImageColor3 = CHECK_LIME and RC.white or RC.green,
					ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(326, y),
					Size = UDim2.fromOffset(40, 40), ZIndex = 4, Parent = holder })
				if newlyDone or newlyPaid then table.insert(checkPops, ck) end
			else
				local cnt = RKit.label({ RichText = true, Text = e.prog .. ' <font size="17">/ ' .. e.def.Goal .. '</font>', FontFace = WFONT, TextSize = 26, TextColor3 = RC.text,
					TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(318, y - 2), Size = UDim2.fromOffset(110, 34), ZIndex = 4, Parent = holder })
				RKit.textStroke(1.5).Parent = cnt
				if fx and fx.up then fx.count = cnt end -- (2026-10-21, round 3) progress made: the count punches as its bar fills
				local rw = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(324, y - 14), Size = UDim2.fromOffset(56, 56), ZIndex = 4, Parent = holder }) -- (round 7, grader B: the glyph read smaller than its xN)
				table.insert(art, { rw, "_Scissors" })
				-- (2026-10-22, section round 0, grader B) "×N" UNDER the render (overlapping only its bottom ~6 px) at the label's size (24, was
				-- 21 laid over the render's bottom-right, hiding half the scissors)
				-- (round 1, RIVALS tasks.png / hub widget) centred on the render over its lower third, like RIVALS' "×1"
				-- (round 5, grader B) on the icon's bottom-right corner only, the handle rings stay clear
				local rl = RKit.label({ Text = "×" .. commas(e.def.Reward), FontFace = WFONT, TextSize = 24, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(324 + 28, y - 14 + 38), Size = UDim2.fromOffset(100, 26),
					ZIndex = 6, Parent = holder })
				RKit.textStroke(1.5).Parent = rl
			end
		end
		if #entries == 0 then RKit.label({ Text = "Loading missions...", FontFace = RTheme.font.medium, TextSize = 20, TextColor3 = RC.textDim, Position = UDim2.fromOffset(18, 6),
			Size = UDim2.fromOffset(320, 26), ZIndex = 4, Parent = holder }) end
		Kit.toScale(holder, Vector2.new(MW, ROWS_H))
		holder.Size = UDim2.fromScale(1, 1)
		for _, f in fills do
			Kit.fillTo(f[1], f[2], 0.5)
			if f.count then Kit.pop(f.count, 1.25) end
		end
		-- 3D art after the conversion: the reward scissors and the done check
		local VI = require(UIKit:WaitForChild("ViewIcons"))
		for _, a2 in art do
			local h2, what = a2[1], a2[2]
			if what == "_Scissors" then
				-- (2026-10-22, section round 1, grader C) the bright scissors render Missions uses (RIVALS' key render); the 3D model drew ~40 %
				-- dimmer on the see-through widget
				new("ImageLabel", { BackgroundTransparency = 1, Image = Kit.ICONS.scissorsReward or "rbxassetid://120480559804238", ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1),
					ZIndex = 5, Parent = h2 })
			elseif what == "_Check" then
				local icons = ReplicatedStorage:FindFirstChild("UIIcons")
				local mesh = icons and icons:FindFirstChild("Check")
				if mesh then
					local m = mesh:Clone()
					for _, d in (m:IsA("BasePart") and { m } or m:GetDescendants()) do if d:IsA("BasePart") then d.Color = Theme.color.field end end -- (2026-10-21, AI-tells cleanup) done check = field green, was yellow
					VI.Viewport(h2, m, { zoom = 1.05, still = true })
				end
			end
		end
		for _, ck in checkPops do Kit.pop(ck, 1.4) end -- (after the check's viewport is in: the pop's UIScale scales it)
	end
	local function resetText()
		local left = 86400 - os.time() % 86400
		reset.Text = string.format("NEW IN %dH %dM", left // 3600, left % 3600 // 60)
	end

	-- list rows: everyone in the server, sorted by the shown stat
	local ViewIconsLB = require(UIKit:WaitForChild("ViewIcons"))
	local lbStat = "Level"
	local PlayerCards
	pcall(function() PlayerCards = require(UIKit:WaitForChild("PlayerCards", 10)) end)
	local RankArtLB
	pcall(function() RankArtLB = require(UIKit:WaitForChild("RankArt", 10)) end)
	local function statValue(p) -- the number the list sorts by
		if lbStat == "Rank" and RankArtLB then
			local r = RankArtLB.Of(p)
			return r.placed and r.elo or -1
		end
		if lbStat == "Streak" then return p:GetAttribute("WinStreak") or 0 end
		return p:GetAttribute(lbStat) or 0
	end
	local function modeIcon()
		-- (2026-10-18, live RIVALS) the column icon is a white silhouette: flame = streak, burst = level, trophy shield = rank
		-- (2026-10-21, RIVALS 1:1) set in place on the one ImageLabel (no destroy / recreate)
		-- (2026-10-22, section round 0, grader C: RIVALS' list header is a white stat glyph; the seal shrank to a blue dot at 22 px)
		-- (2026-10-23) the nameplates follow the board you're on (NameplatesController reads LeaderboardStat)
		player:SetAttribute("LeaderboardStat", lbStat)
		lbModeIcon.Image = (lbStat == "Rank" and Kit.glyph("rank", Kit.ICONS.rank)) or (lbStat == "Level" and Kit.glyph("level", Kit.ICONS.level))
			or (lbStat == "Streak" and Kit.glyph("flame", Kit.ICONS.streak)) or Kit.glyph("trophy", Kit.ICONS.trophy)
	end
	local lastLB
	-- (2026-10-21, RIVALS 1:1) rows are kept by UserId and stay steady: each row's pieces (badge, name, device icon, streak flame,
	-- number / rank emblem) are built ONCE when the player first shows and are then updated in place (Text / Image / Visible /
	-- Position), never destroyed and rebuilt. A re-sort slides rows to their new slot, newcomers pop in, leavers shrink away.
	-- All rows look the same (RIVALS: no zebra, no tint); your own row carries your badge left of the name: Premium if you
	-- have it, else your level badge with your level. Rows hover-lift (UIScale 1.02) with a faint white wash.
	local lbRows = {} -- [UserId] = { row, scale, key, p, parts }
	local okBd, Bd = pcall(function() return require(UIKit:WaitForChild("Badges", 2)) end)
	if not okBd then Bd = nil end
	local TextServiceLB = game:GetService("TextService")
	local function buildRow(row)
		local parts = {}
		new("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(LB_W, 1), BackgroundColor3 = RC.white,
			BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = row })
		-- (2026-10-20, Edward) Roblox badges: Premium before the name, verified after (UIKit.Badges; Settings > Display Badges)
		parts.prem = Kit.label({ Name = "Premium", Text = utf8.char(0xE001), FontFace = LBF_NUM, TextSize = 20, TextColor3 = RC.text, Visible = false,
			Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(24, 40), Parent = row })
		parts.lv = Kit.new("ImageLabel", { Name = "LevelBadge", BackgroundTransparency = 1, Image = RAssets.hud.levelbadge, ScaleType = Enum.ScaleType.Fit, Visible = false,
			Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(26, 26), Parent = row })
		parts.lvN = Kit.label({ Name = "N", Text = "", FontFace = R_BOLD, TextSize = 13, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(-3, 1), Size = UDim2.fromOffset(32, 26), Parent = parts.lv })
		if Kit.levelNumber then Kit.levelNumber(parts.lvN) end -- (2026-10-22, Edward: level numbers like RIVALS) chunky white, deep-blue edge
		parts.name = Kit.label({ Name = "PlayerName", Text = "", FontFace = LBF_NAME, TextSize = 21, TextColor3 = RC.text, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(44, 0), Size = UDim2.fromOffset(196, 40), Parent = row })
		-- (2026-10-20, RIVALS) the device icon right after the name (UIKit.Badges.DeviceIcon)
		parts.device = Kit.new("ImageLabel", { Name = "Device", BackgroundTransparency = 1, Image = "", ImageColor3 = RC.text, ScaleType = Enum.ScaleType.Fit, Visible = false,
			Position = UDim2.fromOffset(222, 2), Size = UDim2.fromOffset(36, 36), Parent = row }) -- (2026-10-22, spacing grade) the device art is a square with ~22 % clear margin round the monitor, so a 36 px square draws ~1.45 cap of ink like RIVALS
		-- the win streak next to the name (RIVALS): a flame with the number over it
		parts.streak = Kit.streak(row, 0, UDim2.fromOffset(210, 4), UDim2.fromOffset(32, 32), 3)
		parts.streak.Visible = false
		parts.rank = Kit.new("ImageLabel", { Name = "RankEmblem", BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, Visible = false,
			Position = UDim2.fromOffset(266, 3), Size = UDim2.fromOffset(34, 34), Parent = row })
		parts.value = Kit.label({ Name = "Value", Text = "", FontFace = LBF_NUM, TextSize = 24, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(230, 0), Size = UDim2.fromOffset(70, 40), Parent = row })
		Kit.toScale(row, Vector2.new(LB_W, 40))
		return parts
	end
	local function updateRow(e, p)
		local parts = e.parts
		local mine = p == player
		local premium = (Bd and Bd.Prefix(p) ~= "") or (not Bd and p.MembershipType == Enum.MembershipType.Premium)
		parts.prem.Visible = premium
		-- (2026-10-23, Edward: "it shouldn't show your streak icon on the leaderboard ... the level icon shouldn't be on your leaderboard
		-- either, only your roblox badge on the left and device on the right") those icons live on the nameplates now
		parts.lv.Visible = false
		parts.lvN.Text = tostring(tonumber(p:GetAttribute("Level")) or 1)
		local streakN = tonumber(p:GetAttribute("WinStreak")) or 0
		local showStreak = false
		local nameText = p.DisplayName .. (Bd and Bd.Suffix(p) or "")
		parts.name.Text = nameText
		local nameW = showStreak and 164 or 196
		parts.name.Size = UDim2.fromScale(nameW / LB_W, 1)
		local dv = (Bd and Bd.DeviceIcon) and Bd.DeviceIcon(p) or nil
		parts.device.Visible = dv ~= nil
		if dv then
			parts.device.Image = dv
			-- (2026-10-21, AI-tells cleanup) names draw in Rubik; Enum.Font has no Rubik, so measure with Arial (close widths, no yield)
			local w = TextServiceLB:GetTextSize(nameText, 21, Enum.Font.Arial, Vector2.new(400, 40)).X
			-- (2026-10-22, names study) Arial runs narrower than the Rubik we draw in, so the icon sat ON the name: use the label's
			-- real TextBounds (screen px -> design px) once it has laid out, with an 8 px gap like RIVALS
			local nb = parts.name.TextBounds.X
			local rowW = parts.name.Parent and parts.name.Parent.AbsoluteSize.X or 0
			if nb > 0 and rowW > 0 then w = nb * LB_W / rowW end
			-- (2026-10-22, spacing grade) ~1 cap of ink gap like RIVALS' PC icon: 13.5 px to the ink, minus the art's ~4 px clear margin
			parts.device.Position = UDim2.fromScale(math.min(44 + math.min(w, nameW) + 9.5, 206) / LB_W, 2 / 40)
		end
		parts.streak.Visible = showStreak
		local sn = parts.streak:FindFirstChild("N")
		if sn then sn.Text = tostring(streakN) end
		local r = (lbStat == "Rank" and RankArtLB) and RankArtLB.Of(p) or nil
		parts.rank.Visible = r ~= nil and r.image ~= nil
		parts.rank.Image = (r and r.image) or ""
		parts.value.Visible = not parts.rank.Visible
		parts.value.Text = r and "-" or tostring(statValue(p))
		parts.value.TextColor3 = r and RC.textDim or RC.text
	end
	local function buildList(force)
		local ps = Players:GetPlayers()
		local key = lbStat
		for _, p in ps do key ..= p.UserId .. "/" .. tostring(statValue(p)) .. tostring(p:GetAttribute("RankTier")) .. "/" .. tostring(p:GetAttribute("WinStreak")) .. "/" .. tostring(p:GetAttribute("Device")) .. tostring(p:GetAttribute("Setting_DisplayBadges")) .. "/" .. tostring(p:GetAttribute("Level")) end -- (device / badges / level change -> update)
		if key == lastLB and not force then return end
		lastLB = key
		table.sort(ps, function(a, b)
			local va, vb = statValue(a), statValue(b)
			if va ~= vb then return va > vb end
			return a.DisplayName:lower() < b.DisplayName:lower()
		end)
		-- rows are 40 design px, in Scale; CanvasSize Scale is relative to the list's parent (lb)
		lbH = math.min(LB_H, 34 + #ps * 40 + 4)
		lb.Size = UDim2.fromScale(LB_W / 1920, lbH / 1080) -- (set, not tweened: the header / rows are Scale of this height)
		lbHead.Size = UDim2.fromScale(1, 34 / lbH)
		lbList.Position = UDim2.fromScale(0, 34 / lbH)
		lbList.Size = UDim2.fromScale(1, (lbH - 34) / lbH)
		local winH = lbH - 34
		local canvasH = math.max(winH, #ps * 40)
		lbList.CanvasSize = UDim2.fromScale(0, canvasH / lbH)
		local present = {}
		for i, p in ps do
			present[p.UserId] = true
			local slot = UDim2.fromScale(0.5, (i - 1) * 40 / canvasH)
			local e = lbRows[p.UserId]
			if e and e.row.Parent == nil then e = nil end
			if not e then
				local row = new("TextButton", { Name = p.Name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = slot, Size = UDim2.fromScale(1, 40 / canvasH),
					BackgroundColor3 = RC.white, BackgroundTransparency = 1, Parent = lbList })
				e = { row = row, p = p }
				lbRows[p.UserId] = e
				e.parts = buildRow(row)
				Kit.popIn(row, (i - 1) * 0.03) -- makes the row's PopScale, reused for the hover lift
				e.scale = row:FindFirstChild("PopScale")
				-- click a row: RIVALS' player menu slides out to the left of the list (UIKit.PlayerCards)
				row.Activated:Connect(function() if PlayerCards then PlayerCards.Menu(e.p, row, 1590) end end)
				row.MouseEnter:Connect(function()
					row.BackgroundTransparency = 0.94
					if e.scale then Kit.tween(e.scale, 0.1, { Scale = 1.02 }) end
				end)
				row.MouseLeave:Connect(function()
					row.BackgroundTransparency = 1
					if e.scale then Kit.tween(e.scale, 0.1, { Scale = 1 }) end
				end)
			else
				e.p = p
				if e.row.Position ~= slot then Kit.tween(e.row, 0.25, { Position = slot }, Enum.EasingStyle.Quad) end
				e.row.Size = UDim2.fromScale(1, 40 / canvasH)
			end
			local rowKey = lbStat .. "/" .. tostring(statValue(p)) .. "/" .. tostring(p:GetAttribute("RankTier")) .. "/" .. tostring(p:GetAttribute("WinStreak")) .. "/"
				.. tostring(p:GetAttribute("Device")) .. "/" .. tostring(p:GetAttribute("Setting_DisplayBadges")) .. "/" .. tostring(p:GetAttribute("Level")) .. "/" .. p.DisplayName
			if rowKey ~= e.key or force then
				e.key = rowKey
				updateRow(e, p)
			end
		end
		for uid, e in lbRows do
			if not present[uid] then
				lbRows[uid] = nil
				local row = e.row
				if e.scale then Kit.tween(e.scale, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
				task.delay(0.16, function() row:Destroy() end)
			end
		end
	end
	local function lobbyData()
		local v = player:GetAttribute("Setting_LobbyData")
		if v == "Level" or v == "Wins" or v == "Rank" or v == "Streak" then lbStat = v; modeIcon(); buildList(true) end
	end
	player:GetAttributeChangedSignal("Setting_LobbyData"):Connect(lobbyData)
	modeIcon()
	lobbyData()
	lbMode.Activated:Connect(function()
		-- Streak -> Level -> Rank -> Wins (RIVALS' three columns, plus our wins)
		lbStat = lbStat == "Streak" and "Level" or (lbStat == "Level" and (RankArtLB and "Rank" or "Wins")) or (lbStat == "Rank" and "Wins") or "Streak"
		modeIcon()
		buildList(true)
	end)
	-- Tab / x: the list slides off to the right and back, constant speed so spamming Tab reverses mid-way
	local corner, hudHidden
	local hudFlip = false -- Hide HUD flipped by its hotkey / the corner button (declared before the corner uses it)
	local lbHome = lb.Position
	local lbOn = true
	local function setList(on)
		if on == lbOn then return end
		lbOn = on
		if not on and PlayerCards then PlayerCards.CloseMenu() end
		if corner then corner.layout() end
		Kit.tween(lb, 0.12, { Position = on and lbHome or UDim2.fromScale(lbHome.X.Scale + 0.25, lbHome.Y.Scale) }, Enum.EasingStyle.Linear)
	end
	lbHide.Activated:Connect(function() setList(false) end)
	Kit.bindButton(lbHide, { hover = 1.15 }) -- (2026-10-21, RIVALS pass) the x reacts too
	corner = buildCorner(gui, {
		openSettings = function() if LobbyUI then LobbyUI.Open("Settings") end end,
		openCodes = function() if LobbyUI then LobbyUI.Open("Codes") end end,
		openNews = function() if NotifyRef then NotifyRef.OpenNews() end end,
		openInbox = function() if NotifyRef then NotifyRef.OpenInbox() end end,
		openList = function() setList(true) end,
		listShown = function() return lbOn end,
		hudHidden = function() return hudHidden and hudHidden() end,
		showHud = function() hudFlip = not hudFlip; corner.layout() end,
		-- in Training: leave through ExfilFX (its LeaveTraining hook), like RIVALS' "Leave Shooting Range"
		canLeave = function()
			local fade = player.PlayerGui:FindFirstChild("ExfilFade")
			return player:GetAttribute("InTraining") == true and fade ~= nil and fade:FindFirstChild("LeaveTraining") ~= nil
		end,
		leave = function()
			local fade = player.PlayerGui:FindFirstChild("ExfilFade")
			local ev = fade and fade:FindFirstChild("LeaveTraining")
			if ev then ev:Fire() end
		end,
	})
	-- the corner's unread count follows UIKit.Notify (loaded in a task at the top of Start)
	task.spawn(function()
		local t0 = os.clock()
		while not NotifyRef and os.clock() - t0 < 30 do task.wait(0.2) end
		if NotifyRef and corner.setUnread then NotifyRef.OnUnread(corner.setUnread) end
	end)
	local function bound(action, fallback)
		local name = player:GetAttribute("Bind_" .. action)
		local ok, kc = pcall(function() return name and Enum.KeyCode[name] end)
		return (ok and kc) or fallback
	end
	-- Hide HUD (Settings > Video > Interface, or its hotkey): the setting, flipped by the hotkey / the corner button
	hudHidden = function() return (player:GetAttribute("Setting_HideHUD") == true) ~= hudFlip end
	UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == bound("OpenScoreboard", Enum.KeyCode.Tab) then setList(not lbOn) end
		local hk = bound("HideHUD", nil)
		if hk and i.KeyCode == hk then hudFlip = not hudFlip; corner.layout() end
	end)
	player:GetAttributeChangedSignal("Setting_HideHUD"):Connect(function() hudFlip = false; corner.layout() end)

	-- [TOUCH] mobile: the Scoreboard button toggles the player list like Tab
	task.spawn(function()
		local ok, IA = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if ok and IA then IA.Bind("Scoreboard", function(state) if state == Enum.UserInputState.Begin then setList(not lbOn) end end) end
	end)

	---------------------------------------------------------------------------------------------- follow the lobby
	local function lobbyShown()
		local pg = player.PlayerGui
		local lobby = pg:FindFirstChild("LobbyUI")
		if not lobby or not lobby.Enabled then return false end
		local dock = lobby:FindFirstChild("Dock", true)
		if dock and not dock.Visible then return false end
		if player:GetAttribute("InTraining") or player:GetAttribute("Deploying") then return false end
		-- in-lobby duels: playing or spectating one hides the lobby HUD (DuelHUD takes over)
		if player:GetAttribute("InDuel") or player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate") then return false end
		return true
	end
	-- the world: hover a character for "Double click to view profile", double click opens their card (RIVALS)
	if PlayerCards then
		PlayerCards.StartWorld(function()
			local lobbyGui = player.PlayerGui:FindFirstChild("LobbyUI")
			return lobbyShown() and not hudHidden() and lobbyGui ~= nil and lobbyGui.Enabled
		end)
	end
	-- Padded HUD: everything pulled in from the screen edges (TV safe area), always or while a controller is in use
	local lastPad = false
	UserInputService.LastInputTypeChanged:Connect(function(t)
		if t == Enum.UserInputType.MouseMovement then return end -- (2026-10-20) mouse MOVEMENT never flips back to keyboard + mouse: a resting mouse / locked cursor sends it, and hid every controller icon
		lastPad = t.Name:find("Gamepad") ~= nil
	end)
	local function padded()
		local v = player:GetAttribute("Setting_PaddedHUD") or "Using Controller"
		return v == "Always On" or (v == "Using Controller" and lastPad)
	end
	-- the rest of the lobby HUD (PLAY row, dock) hides with Hide HUD too; the dock's own state is put back after
	local dockSaved
	local cutShown = false
	-- push-aside groups (RIVALS replica): left group left, right group right, top up, bottom down
	local GROUPS = {
		{ dx = -0.32, dy = 0, names = { "Missions", "ToPads" } },
		{ dx = 0.3, dy = 0, names = { "PlayerList" } },
		{ dx = 0, dy = -0.32, names = { "Scissors", "Searching" } }, -- (2026-10-21, RIVALS 1:1) the searching pill is top centre now
		{ dx = 0, dy = 0.3, fast = true, names = { "NavShade", "NavKit", "NavMissions", "NavShop", "NavCodes", "NavSettings" } },
	}
	local homes = {}
	-- (2026-10-22, Edward: "4:3 tablets ... if rivals does it") on a screen taller than 16:9 the design canvas sits in a band; RIVALS
	-- keeps the currency / player list on the top edge and the dock on the bottom edge. Those pieces move by the band height
	-- (Scale of the canvas): PIN_DY(o) = -band for the top ones, +band for the bottom ones, 0 for the rest (missions panel etc.).
	local PIN_TOP = { Scissors = true, Searching = true, PlayerList = true }
	local PIN_BOTTOM = { NavShade = true, NavKit = true, NavMissions = true, NavShop = true, NavCodes = true, NavSettings = true, JoinTip = true }
	local function pinDy(o)
		local band = Kit.canvasBand and Kit.canvasBand(canvas) or 0
		if band <= 0 then return 0 end
		-- pad mode shrinks root to 0.92 of the canvas height: the band is measured on the canvas, root's scale follows
		local rs = root.Size.Y.Scale > 0 and root.Size.Y.Scale or 1
		if PIN_TOP[o.Name] then return -band / rs end
		if PIN_BOTTOM[o.Name] then return band / rs end
		return 0
	end
	local function plus(u, dy) return UDim2.new(u.X.Scale, u.X.Offset, u.Y.Scale + dy, u.Y.Offset) end
	-- recorded a moment later: Kit.bindButton re-anchors buttons to their centre on the next frame, which moves their Position
	-- (recording first sent Missions / To Pads back to the wrong spot after a menu closed)
	task.delay(0.2, function()
		for _, g in GROUPS do
			for _, n in g.names do
				local o = root:FindFirstChild(n)
				if o then homes[o] = { home = o.Position, away = UDim2.fromScale(o.Position.X.Scale + g.dx, o.Position.Y.Scale + g.dy), t = g.fast and 0.08 or 0.18 } end
			end
		end
		-- the join tip is no push group but sits on the bottom edge too
		local jt = root:FindFirstChild("JoinTip")
		if jt then homes[jt] = homes[jt] or { home = jt.Position, away = jt.Position, t = 0.08, still = true } end
		-- 4:3: put the pinned pieces on their edge now, and again whenever the screen shape changes
		local function applyPins()
			for o, h in homes do
				if o.Parent and (PIN_TOP[o.Name] or PIN_BOTTOM[o.Name]) then
					o:SetAttribute("PinDy", pinDy(o))
					o.Position = plus((root:GetAttribute("PushedAway") and not h.still) and h.away or h.home, pinDy(o))
				end
			end
		end
		applyPins()
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyPins)
	end)
	local pushedAway = false
	local kitShown = false
	local function pushAside(away)
		root:SetAttribute("PushedAway", away)
		resetNav()
		for o, h in homes do
			if o.Name == "PlayerList" and not lbOn then continue end -- hidden by Tab: leave it off screen
			if h.still then continue end
			Kit.tween(o, away and h.t or 0.25, { Position = plus(away and h.away or h.home, pinDy(o)) }, away and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
				away and Enum.EasingDirection.In or Enum.EasingDirection.Out)
		end
	end
	local wasTraining = false
	-- new player = never queued this session and account level < 5 (no data loaded yet: the first 60 s after join)
	local joinT0, queuedOnce = os.clock(), false
	local function wantJoin()
		if player:GetAttribute("MM_Queue") ~= nil then queuedOnce = true end
		if queuedOnce then return false end
		-- (2026-10-21, user) RIVALS shows the bubble to low-level accounts only, until about level 5
		if data and data.XP ~= nil and Config.AccountLevel then
			return (Config.AccountLevel(data.XP)) < 5
		end
		return os.clock() - joinT0 < 60
	end
	RunService.Heartbeat:Connect(function(dt)
		local on = lobbyShown()
		-- a cutscene (exfil heli etc.; ExfilFX sets InCutscene) hides everything, the corner and the fight HUD too
		local cut = player:GetAttribute("InCutscene") == true
		local hide = hudHidden() or cut
		-- RIVALS: a menu opening pushes the HUD out to the sides (and back when it closes); anything else hides it at once
		local lobbyGui = player.PlayerGui:FindFirstChild("LobbyUI")
		local menuAway = lobbyGui ~= nil and not lobbyGui.Enabled and not player:GetAttribute("InTraining") and not player:GetAttribute("Deploying")
			or (PlayerCards ~= nil and PlayerCards.ProfileOpen()) -- the profile card pushes the HUD aside like a menu
			or (player.PlayerGui:FindFirstChild("PartyUI") ~= nil and player.PlayerGui.PartyUI.Enabled) -- and Your Party
			or player.PlayerGui:FindFirstChild("InboxUI") ~= nil -- and the Inbox / News
		-- Kit room (LobbyUI on, its dock hidden by the Armory): RIVALS keeps the currency pill up there, nothing else
		local kitDock = lobbyGui and lobbyGui:FindFirstChild("Dock", true)
		local kitRoom = lobbyGui ~= nil and lobbyGui.Enabled and kitDock ~= nil and not kitDock.Visible
			and not player:GetAttribute("InTraining") and not player:GetAttribute("Deploying")
		root.Visible = (on or menuAway or kitRoom) and not hide
		if kitRoom ~= kitShown then
			kitShown = kitRoom
			resetNav()
			for _, c in root:GetChildren() do
				if c:IsA("GuiObject") and c.Name ~= "Scissors" then
					if kitRoom then c:SetAttribute("KitHid", c.Visible); c.Visible = false
					elseif c:GetAttribute("KitHid") ~= nil then c.Visible = c:GetAttribute("KitHid"); c:SetAttribute("KitHid", nil) end
				end
			end
		end
		if menuAway ~= pushedAway then
			pushedAway = menuAway
			pushAside(menuAway)
		end
		-- (2026-10-21, RIVALS) the Kit picker's skin-name pill takes the top centre while it previews: the currency steps aside
		local sc = root:FindFirstChild("Scissors")
		if sc then sc.Visible = not (kitRoom and player:GetAttribute("KitPreview") == true) end
		local training = player:GetAttribute("InTraining") == true
		if corner then corner.frame.Visible = not cut and (on or hide or training) end
		if training ~= wasTraining then wasTraining = training; corner.layout() end
		if cut ~= cutShown then
			cutShown = cut
			for _, name in { "Hotbar", "Vitals" } do
				local g = player.PlayerGui:FindFirstChild(name)
				if g then g.Enabled = not cut end
			end
		end
		local pad = padded()
		root.Size = pad and UDim2.fromScale(0.94, 0.92) or UDim2.fromScale(1, 1)
		root.Position = pad and UDim2.fromScale(0.03, 0.04) or UDim2.fromScale(0, 0)
		local lobby = player.PlayerGui:FindFirstChild("LobbyUI")
		local dock = lobby and lobby:FindFirstChild("Dock", true)
		local row = player.PlayerGui:FindFirstChild("PlayRowUI")
		-- in a duel (playing or watching) the PLAY row and the dock go too, like Hide HUD (the hotbar stays)
		local inDuel = player:GetAttribute("InDuel") == true or player:GetAttribute("DuelMatch") ~= nil or player:GetAttribute("DuelSpectate") ~= nil
		local partyUp = player.PlayerGui:FindFirstChild("PartyUI") ~= nil and player.PlayerGui.PartyUI.Enabled
		local cardUp = (PlayerCards ~= nil and PlayerCards.ProfileOpen()) or partyUp or player.PlayerGui:FindFirstChild("InboxUI") ~= nil -- the profile card / Your Party: PLAY row + dock go too (RIVALS)
		if hide or inDuel or cardUp then
			if dock and dockSaved == nil then dockSaved = dock.Visible end
			if dock then dock.Visible = false end
			if row then row.Enabled = false end
		elseif dockSaved ~= nil then
			if dock then dock.Visible = dockSaved end
			if row and lobby then row.Enabled = lobby.Enabled end
			dockSaved = nil
		end
		-- (2026-10-21, grade2) the "Join a match!" pill over PLAY: new players only, while PLAY is up and no dock bubble shows
		-- (2026-10-21, grade3) ... and while PLAY itself is hovered (PlayRow sets Play's "Hovered" attribute)
		local rowPlay = row and row:FindFirstChild("Play", true)
		joinTip.Visible = wantJoin() and row ~= nil and row.Enabled and not kitShown and not pushedAway and next(dockHover) == nil
			and not (rowPlay ~= nil and rowPlay:GetAttribute("Hovered") == true)
		-- Hide Missions (Settings > Video > Interface)
		local noMissions = player:GetAttribute("Setting_HideSideTasks") == true
		missions.Visible = not noMissions and not kitShown
		toPads.Visible = not noMissions and not kitShown and not PseudoLobby.MatchPlace() -- (after-match lobby: the pads are barricaded)
		local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
		-- (2026-10-21, RIVALS 1:1) the pill's texts the way PlayScreen fills its copy: status dots cycle once a second, "Match
		-- found!" in Theme green (X hidden) once found, the mode as "[Ranked ]<Mode>", the clock from MM_Since
		seek.Visible = q ~= nil and st ~= nil and not kitShown
		if seek.Visible then
			local def = Config.QueueById and Config.QueueById(q)
			local e = workspace:GetServerTimeNow() - (player:GetAttribute("MM_Since") or workspace:GetServerTimeNow())
			local searching = st == "Searching"
			seekStatus.Text = searching and ("Searching for players" .. string.rep(".", 1 + math.floor(e) % 3)) or "Match found!"
			seekStatus.TextColor3 = searching and RC.text or RC.green
			seekMode.Text = def and ((def.Ranked and "Ranked " or "") .. tostring(def.Mode or def.Id or "")) or ""
			local sec = math.max(0, math.floor(e))
			seekClock.Text = string.format("%d:%02d", sec // 60, sec % 60)
			seekX.Visible = searching
		end
		-- live RIVALS: PLAY hides while the searching pill is up (put back as soon as it goes)
		if rowPlay and rowPlay.Visible == seek.Visible then rowPlay.Visible = not seek.Visible end
	end)

	task.spawn(function()
		local PlayerData = require(script.Parent.Parent:WaitForChild("Registry"):WaitForChild("PlayerData"))
		local replica = PlayerData:GetMyReplica()
		data = replica.Data
		replica:ListenToRaw(function() refresh() end)
		refresh()
	end)
	task.spawn(function()
		while true do
			resetText()
			refresh()
			buildList()
			task.wait(1)
		end
	end)
end

return LobbyHud
