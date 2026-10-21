-- Client/Controllers/LobbyHudController (ModuleScript, auto-loaded): the lobby HUD around the PLAY row and the dock,
-- RIVALS' layout in TACTICALS' look.
--   * Top centre: the scissors pill (the 3D scissors, your count, + opens the scissors shop).
--   * Left: DAILY MISSIONS (the real daily quests with progress, claimable ones flagged) and TO PADS under it.
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

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BONE, FIELD, OLIVE, OLIVE_HI = hex("#ECE8DA"), hex("#969C8C"), hex("#FFD400"), hex("#FFD400")
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local LB_NAME, LB_NUM = Font.new(BUILDER, Enum.FontWeight.Medium), Font.new(BUILDER, Enum.FontWeight.Bold)
local GUN, DEEP, LINE, RED = hex("#1A1D1A"), hex("#0C0E0B"), hex("#40463A"), hex("#D6403A")

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, Parent = parent })
end
-- (Edward 2026-10-16: no "4 corners box" look) panels get RIVALS' soft rounded corners and a faint edge; the edge keeps
-- its colour only where colour means something (team A / B, ranked violet), otherwise it's a soft white line
local NEUTRAL_EDGE = { [Color3.fromRGB(64, 70, 58):ToHex()] = true, [Color3.fromRGB(255, 212, 0):ToHex()] = true,
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
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium), TextColor3 = BAR_ICON, Text = "", ZIndex = 31, Parent = bubble })
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
	local news = button("News", Kit.ICONS.news, "Read the latest news")
	local inbox = button("Inbox", Kit.ICONS.inbox, "View your recent notifications")
	-- unread notifications: a red count on the gear while the corner is shut, on the Inbox while it's open
	local function dot(parent)
		local d = new("Frame", { Name = "Unread", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.15), Size = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(230, 50, 50), Visible = false, ZIndex = 25, Parent = parent }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("TextLabel", { Name = "N", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "0", TextColor3 = Color3.new(1, 1, 1),
			FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold), ZIndex = 26, Parent = d })
		return d
	end
	local codes = button("Codes", ICON_CODES, "Redeem a code")
	local list = button("PlayerList", ICON_PLAYERS, "Open the player list")
	local hud = button("HUD", ICON_HUD, "Enable your HUD")
	local leave = button("Leave", ICON_LEAVE, "Leave the training room")

	local BODYI = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic)
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
	function ctl.setUnread(n) unreadN = n; ctl.unreadDots() end
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
	-- RIVALS' key pill, with our scissors: a small dark glass pill, the 3D scissors overlapping its left end, a rounded plus
	local PFONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	local pill = new("Frame", { Name = "Scissors", Position = UDim2.fromOffset(880, 40), Size = UDim2.fromOffset(168, 42), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local iconHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-46, -14), Size = UDim2.fromOffset(70, 70), ZIndex = 3, Parent = pill })
	local count = Kit.label({ Text = "...", FontFace = PFONT, TextSize = 31, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(130, 42), ZIndex = 3, Parent = pill })
	new("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = count })
	local plus = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(174, -1), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = pill }, -- (audit) 34 -> 44: a tappable size
		{ new("UICorner", { CornerRadius = UDim.new(0, 7) }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#7CC4FF"), hex("#1E63D6")) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 6), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = plus }, { new("UICorner", { CornerRadius = UDim.new(0, 2) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 18), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = plus }, { new("UICorner", { CornerRadius = UDim.new(0, 2) }) })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() if LobbyUI and LobbyUI.OpenShop then LobbyUI.Close(); LobbyUI.OpenShop("Scissors") end end)

	---------------------------------------------------------------------------------------------- missions widget
	-- RIVALS' Daily Tasks widget (ported from the replica): dark glass, a 3D clipboard + bold title, then per mission a 3D icon,
	-- the name, the count, a bright bar and the reward (3D scissors xN) or a green check when it's done
	local WFONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	local missions = new("TextButton", { Name = "Missions", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, 405), Size = UDim2.fromOffset(372, 255),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local clipHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(48, 48), ZIndex = 3, Parent = missions })
	local mt = Kit.label({ Text = "Daily Missions", FontFace = WFONT, TextSize = 34, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(58, 8), Size = UDim2.fromOffset(290, 42), ZIndex = 3, Parent = missions })
	new("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = mt })
	local reset = Kit.label({ Text = "", FontFace = WFONT, TextSize = 1, TextTransparency = 1, Size = UDim2.fromOffset(1, 1), Parent = missions }) -- (timer lives in Missions)
	local rows = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(372, 196), ZIndex = 3, Parent = missions })
	missions.Activated:Connect(function() if LobbyUI then LobbyUI.Open("Missions") end end)
	Kit.bindButton(missions, { hover = 1.02, press = 0.99 })
	-- To Pads: RIVALS' chunky "To Duels" button in our lobby colours
	local toPads = new("TextButton", { Name = "ToPads", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(95, 686), Size = UDim2.fromOffset(204, 50), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root },
		{ new("UICorner", { CornerRadius = UDim.new(0, 8) }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#7CC4FF"), hex("#1E63D6")) }),
			new("UIStroke", { Color = hex("#CFE6FF"), Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	local tp = Kit.label({ Text = "»  To Pads  «", FontFace = WFONT, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(204, 50), ZIndex = 3, Parent = toPads })
	new("UIStroke", { Color = hex("#10306E"), Thickness = 2, Transparency = 0.1, Parent = tp })
	Kit.bindButton(toPads, { hover = 1.06 })
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
	local seek = new("Frame", { Name = "Searching", Position = UDim2.fromOffset(790, 770), Size = UDim2.fromOffset(340, 58), BackgroundColor3 = DEEP,
		BackgroundTransparency = 0.15, Visible = false, Parent = root })
	brackets(seek, OLIVE, 12, 2)
	local seekMarks = {}
	for i = 1, 3 do
		table.insert(seekMarks, new("Frame", { Position = UDim2.fromOffset(18 + (i - 1) * 16, 24), Size = UDim2.fromOffset(10, 10), Rotation = 45, BackgroundColor3 = BONE,
			BorderSizePixel = 0, ZIndex = 3, Parent = seek }))
	end
	local seekMode = label(seek, "", OSWALD, 24, 76, 0, 200, 58, BONE, nil, 3)
	local seekX = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(284, 9), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = hex("#3A1E1C"), ZIndex = 3, Parent = seek })
	for _, r in { 45, -45 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 5), Rotation = r, BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 4, Parent = seekX })
	end
	Kit.bindButton(seekX, { hover = 1.1 })
	local Request = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby"):WaitForChild("Request")
	seekX.Activated:Connect(function() pcall(Request.InvokeServer, Request, "CancelMatch") end)

	---------------------------------------------------------------------------------------------- player list (RIVALS style)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	local LB_W, LB_H = 320, 536
	local lb = new("Frame", { Name = "PlayerList", Position = UDim2.fromOffset(1590, 96), Size = UDim2.fromOffset(LB_W, LB_H), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	local lbHide = new("TextButton", { Name = "Hide", Text = "×", TextColor3 = Color3.new(1, 1, 1), FontFace = LB_NAME, TextSize = 30, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(28, 30), Parent = lb })
	local lbMode = new("TextButton", { Name = "Mode", Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(272, 1), Size = UDim2.fromOffset(34, 32), Parent = lb })
	local lbList = new("ScrollingFrame", { Name = "Rows", Position = UDim2.fromOffset(0, 34), Size = UDim2.fromOffset(LB_W, LB_H - 34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = hex("#8E8D94"), ScrollBarImageTransparency = 0.3, CanvasSize = UDim2.new(), Parent = lb })


	---------------------------------------------------------------------------------------------- bottom nav (RIVALS' HUD bar)
	-- ported from the RIVALS replica (rivals_practice/ui/hud): a dark bar behind bold outlined labels, each item a big 3D icon
	-- on a dark disc, a red count badge, and on hover the item grows and lifts and a white speech bubble bobs above it.
	-- Replaces LobbyUI's old dock (its contents are hidden; the Dock frame stays as the "lobby is showing" signal).
	local Icons = require(script.Parent:WaitForChild("LobbyUIController"):WaitForChild("Icons"))
	local BAR = Color3.fromRGB(20, 18, 24)
	local NAV_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	local NAV = {
		{ Id = "Kit", Label = "Kit", Tip = "Your gun, gadget, melee & cosmetics", Build = function()
			local w = data and data.Loadout and data.Loadout.Weapon
			return Icons.Weapon(w or "Pistol") end, View = Icons.GunView, Zoom = 0.95 },
		{ Id = "Missions", Label = "Missions", Tip = "Complete missions to earn scissors", Build = Icons.Clipboard, View = CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), Zoom = 1.05 },
		{ Id = "Shop", Label = "Shop", Tip = "Unlock gear, bundles & scissors", Build = Icons.Crate, View = CFrame.Angles(math.rad(16), math.rad(28), 0), Zoom = 1.1 },
		{ Id = "Codes", Label = "Codes", Tip = "Redeem codes for free rewards", Build = Icons.DogTags, View = CFrame.Angles(math.rad(6), math.rad(-15), 0), Zoom = 1.05 },
		{ Id = "Settings", Label = "Settings", Tip = "Controls, graphics & hotkeys", Build = Icons.Gear, View = CFrame.Angles(math.rad(10), math.rad(25), 0), Zoom = 1.1 },
	}
	local STEP = 128
	local navW = #NAV * STEP + 36
	local navShade = new("Frame", { Name = "NavShade", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 1006), Size = UDim2.fromOffset(navW, 54),
		BackgroundColor3 = BAR, BackgroundTransparency = 0.25, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	local navButtons, navBadges, navIcons = {}, {}, {}
	for i, it in NAV do
		local cx = 960 + (i - (#NAV + 1) / 2) * STEP
		local b = new("TextButton", { Name = "Nav" .. it.Id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(cx, 1062), Size = UDim2.fromOffset(124, 116), Parent = root })
		new("Frame", { Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(62, 46), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(0, 0, 0)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 0.15) }) }) })
		local holder = new("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(62, 42), Size = UDim2.fromOffset(100, 100), ZIndex = 2, Parent = b })
		navIcons[it.Id] = { holder = holder, it = it }
		local lbl = Kit.label({ Text = it.Label, FontFace = NAV_FONT, TextSize = 28, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(62, 116), Size = UDim2.fromOffset(150, 32), ZIndex = 3, Parent = b })
		new("UIStroke", { Thickness = 2.5, Transparency = 0.1, Parent = lbl })
		local badge = new("Frame", { Name = "Badge", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(98, 12), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.fromRGB(235, 50, 50), ZIndex = 4, Parent = b }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.2 }) })
		local bl = Kit.label({ Text = "", FontFace = NAV_FONT, TextSize = 21, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = badge })
		navBadges[it.Id] = { f = badge, l = bl }
		-- speech bubble (white, pointer down), shown on hover
		local tip = new("Frame", { Name = "Bubble", Visible = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(62, -14), Size = UDim2.fromOffset(#it.Tip * 11 + 30, 40),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 10, Parent = b }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 9, Parent = tip })
		Kit.label({ Text = it.Tip, FontFace = NAV_FONT, TextSize = 21, TextColor3 = Color3.fromRGB(24, 24, 28), TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = tip })
		-- [PAD] (Edward 2026-10-20, RIVALS) the D-pad direction that opens it, beside the icon (shown with a controller)
		local padGlyph = new("ImageLabel", { Name = "PadGlyph", BackgroundTransparency = 1, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(104, 52), Size = UDim2.fromOffset(42, 42), ZIndex = 6, Parent = b })
		local sc = new("UIScale", { Parent = b })
		table.insert(navButtons, { b = b, s = sc, tip = tip, id = it.Id, pad = padGlyph })
		b.Activated:Connect(function() if LobbyUI then LobbyUI.Open(it.Id) end end)
	end

	Kit.toScale(root)

	-- [PAD] D-pad opens the nav screens from the hub (RIVALS: Weapons left, Tasks down, Shop right, Pass up). Only while the
	-- nav is on screen (it slides away for menus, duels and training) - in a round the D-pad equips weapons.
	do
		local DPAD = { Kit = Enum.KeyCode.DPadLeft, Missions = Enum.KeyCode.DPadDown, Shop = Enum.KeyCode.DPadRight, Codes = Enum.KeyCode.DPadUp }
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

	-- nav: 3D icons (after the conversion, so the viewports fill their holders), hover grow + lift + bobbing bubble
	for id, n in navIcons do
		n.vp = Icons.Viewport(n.holder, n.it.Build(), { view = n.it.View, zoom = n.it.Zoom * 1.12 })
	end
	Icons.Viewport(clipHolder, Icons.Clipboard(), { view = CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), zoom = 1.1 })
	local navResets = {}
	function resetNav() for _, f in navResets do f() end end
	for _, n in navButtons do
		local base = n.b.Position
		local function away() return root:GetAttribute("PushedAway") == true end -- a menu is open: no hover (RIVALS)
		local lift = UDim2.fromScale(base.X.Scale, base.Y.Scale - 14 / 1080)
		local tipBase = n.tip.Position
		local hovered, gen = false, 0
		local function bob(myGen)
			task.wait(2)
			local up = UDim2.new(tipBase.X.Scale, 0, tipBase.Y.Scale - 18 / 116, 0)
			while hovered and gen == myGen do
				Kit.tween(n.tip, 0.4, { Position = up }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.wait(0.4)
				if not hovered or gen ~= myGen then return end
				Kit.tween(n.tip, 0.6, { Position = tipBase }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.6)
			end
		end
		n.b.MouseEnter:Connect(function()
			if away() then return end
			hovered = true; gen += 1
			-- (Edward: the bubbles came up too early) the bubble waits until you've rested on the item a moment
			local myGen = gen
			task.delay(0.55, function()
				if hovered and gen == myGen and not away() then
					n.tip.Visible = true; n.tip.Position = tipBase
					task.spawn(bob, myGen)
				end
			end)
			if navIcons[n.id].vp then navIcons[n.id].vp.SetHover(true) end
			Kit.tween(n.s, 0.15, { Scale = 1.12 }, Enum.EasingStyle.Back)
			Kit.tween(n.b, 0.15, { Position = lift }, Enum.EasingStyle.Back)
		end)
		n.b.MouseLeave:Connect(function()
			hovered = false; gen += 1
			n.tip.Visible = false; n.tip.Position = tipBase
			if away() then Kit.tween(n.s, 0.15, { Scale = 1 }); return end
			if navIcons[n.id].vp then navIcons[n.id].vp.SetHover(false) end
			Kit.tween(n.s, 0.15, { Scale = 1 })
			Kit.tween(n.b, 0.15, { Position = base })
		end)
		table.insert(navResets, function()
			hovered = false; gen += 1
			n.tip.Visible = false; n.tip.Position = tipBase
			if navIcons[n.id].vp then navIcons[n.id].vp.SetHover(false) end
			n.s.Scale = 1
			n.b.Position = base
		end)
		n.b.Activated:Connect(function() task.defer(resetNav) end) -- a click opens something: the bubble goes with it
		n.b.MouseButton1Down:Connect(function() if not away() then Kit.tween(n.s, 0.06, { Scale = 1.02 }) end end)
		n.b.MouseButton1Up:Connect(function() if not away() then Kit.tween(n.s, 0.12, { Scale = 1.12 }, Enum.EasingStyle.Back) end end)
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
	ViewIcons.Icon(iconHolder, "Scissors", { hoverTarget = pill, zoom = 1.15 })

	---------------------------------------------------------------------------------------------- data
	local data
	local function questDef(scope, id)
		for _, q in Config.Quests[scope].Pool do if q.Id == id then return q end end
	end
	local lastRows
	local shownKitWeapon
	local function refresh()
		if not data then return end
		-- nav: Missions badge = missions ready to claim; the Kit icon follows your gun
		local ready = 0
		for _, scope in { "Daily", "Weekly" } do
			local q = data.Quests and data.Quests[scope]
			for _, e in (q and q.List) or {} do
				local def = questDef(scope, e.Id)
				if def and not e.Claimed and ((data.Stats and data.Stats[def.Stat]) or 0) - (e.Base or 0) >= def.Goal then ready += 1 end
			end
		end
		local mb = navBadges and navBadges.Missions
		if mb then mb.f.Visible = ready > 0; mb.l.Text = tostring(ready) end
		local w = data.Loadout and data.Loadout.Weapon
		if w and w ~= shownKitWeapon and navIcons and navIcons.Kit and navIcons.Kit.vp then
			shownKitWeapon = w
			navIcons.Kit.vp.SetModel(Icons.Weapon(w), Icons.GunView)
		end
		count.Text = commas(data.Credits or 0)
		local q = data.Quests and data.Quests.Daily
		local key = ""
		local entries = {}
		for i, e in (q and q.List) or {} do
			local def = questDef("Daily", e.Id)
			if def then
				local prog = math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (e.Base or 0), 0, def.Goal)
				table.insert(entries, { def = def, prog = prog, claimed = e.Claimed })
				key ..= def.Id .. prog .. tostring(e.Claimed)
			end
		end
		if key == lastRows then return end
		lastRows = key
		for _, c in rows:GetChildren() do c:Destroy() end
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(372, 196), ZIndex = 3, Parent = rows })
		local art = {}
		for i, e in entries do
			local y = (i - 1) * 64
			local done = e.prog >= e.def.Goal
			local ic = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, y + 2), Size = UDim2.fromOffset(42, 42), ZIndex = 4, Parent = holder })
			table.insert(art, { ic, e.def.Stat })
			local t = Kit.label({ Text = e.def.Text, FontFace = WFONT, TextSize = 24, TextColor3 = (e.claimed or done) and hex("#D9D6DA") or Color3.new(1, 1, 1),
				Position = UDim2.fromOffset(50, y), Size = UDim2.fromOffset(210, 30), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = holder })
			new("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = t })
			local back = new("Frame", { Position = UDim2.fromOffset(50, y + 34), Size = UDim2.fromOffset(262, 7), BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45, ClipsDescendants = true, ZIndex = 4, Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			new("Frame", { Size = UDim2.fromScale(math.clamp(e.prog / e.def.Goal, 0, 1), 1), BackgroundColor3 = done and hex("#FFD400") or hex("#ECE8DA"), ZIndex = 5, Parent = back },
				{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			if done or e.claimed then
				-- done: a big green check instead of the count and reward (RIVALS)
				local ck = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(318, y + 2), Size = UDim2.fromOffset(44, 44), ZIndex = 4, Parent = holder })
				table.insert(art, { ck, "_Check" })
			else
				local cnt = Kit.label({ RichText = true, Text = e.prog .. ' <font size="16">/ ' .. e.def.Goal .. '</font>', FontFace = WFONT, TextSize = 25, TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(196, y - 2), Size = UDim2.fromOffset(116, 32), ZIndex = 4, Parent = holder })
				new("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = cnt })
				local rw = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(318, y - 4), Size = UDim2.fromOffset(46, 34), ZIndex = 4, Parent = holder })
				table.insert(art, { rw, "_Scissors" })
				local rl = Kit.label({ Text = "×" .. e.def.Reward, FontFace = WFONT, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(312, y + 24), Size = UDim2.fromOffset(58, 20), ZIndex = 5, Parent = holder })
				new("UIStroke", { Thickness = 1.5, Transparency = 0.2, Parent = rl })
			end
		end
		if #entries == 0 then label(holder, "Loading missions...", BODY, 18, 18, 0, 330, 24, FIELD, nil, 4) end
		Kit.toScale(holder, Vector2.new(372, 196))
		holder.Size = UDim2.fromScale(1, 1)
		-- 3D art after the conversion: mission icons (same mapping as the Missions screen), scissors, check
		local VI = require(UIKit:WaitForChild("ViewIcons"))
		local STAT = { Wins = { "Trophy" }, MatchesPlayed = { "DogTags" }, Kills = { "Weapon", "AutoRifle" }, Headshots = { "Weapon", "Sniper" },
			CoverKills = { "Sandbags" }, MeleeKills = { "Melee", "Knife" }, GadgetsThrown = { "Grenade" } }
		for _, a2 in art do
			local h2, what = a2[1], a2[2]
			if what == "_Scissors" then
				VI.Icon(h2, "Scissors", { still = true })
			elseif what == "_Check" then
				local icons = ReplicatedStorage:FindFirstChild("UIIcons")
				local mesh = icons and icons:FindFirstChild("Check")
				if mesh then
					local m = mesh:Clone()
					for _, d in (m:IsA("BasePart") and { m } or m:GetDescendants()) do if d:IsA("BasePart") then d.Color = hex("#FFD400") end end
					VI.Viewport(h2, m, { zoom = 1.05, still = true })
				end
			else
				local spec = STAT[what] or { "Medal" }
				if spec[1] == "Weapon" then VI.Viewport(h2, VI.Weapon(spec[2]), { view = VI.GunView, zoom = 0.95, still = true })
				elseif spec[1] == "Melee" then VI.Viewport(h2, VI.Melee(spec[2]), { view = CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(38), 0, 0), zoom = 1, still = true })
				else VI.Icon(h2, spec[1], { still = true }) end
			end
		end
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
		for _, c in lbMode:GetChildren() do c:Destroy() end
		-- (2026-10-18, live RIVALS) the column icon is a white silhouette: flame = streak, burst = level, trophy shield = rank
		local id = (lbStat == "Rank" and Kit.ICONS.rank) or (lbStat == "Level" and Kit.ICONS.level) or (lbStat == "Streak" and Kit.ICONS.streak) or Kit.ICONS.trophy
		Kit.new("ImageLabel", { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = lbMode })
	end
	local lastLB
	local function buildList(force)
		local ps = Players:GetPlayers()
		local key = lbStat
		for _, p in ps do key ..= p.UserId .. "/" .. tostring(statValue(p)) .. tostring(p:GetAttribute("RankTier")) .. "/" .. tostring(p:GetAttribute("WinStreak")) .. "/" .. tostring(p:GetAttribute("Device")) .. tostring(p:GetAttribute("Setting_DisplayBadges")) end -- (device / badges change -> rebuild)
		if key == lastLB and not force then return end
		lastLB = key
		table.sort(ps, function(a, b)
			local va, vb = statValue(a), statValue(b)
			if va ~= vb then return va > vb end
			return a.DisplayName:lower() < b.DisplayName:lower()
		end)
		for _, c in lbList:GetChildren() do c:Destroy() end
		-- rows are 40 design px in a 502 px window, in Scale; CanvasSize Scale is relative to the list's parent (lb)
		local winH = LB_H - 34
		local canvasH = math.max(winH, #ps * 40)
		lbList.CanvasSize = UDim2.fromScale(0, canvasH / LB_H)
		for i, p in ps do
			local row = new("TextButton", { Name = p.Name, Text = "", AutoButtonColor = false, Position = UDim2.fromScale(0, (i - 1) * 40 / canvasH), Size = UDim2.fromScale(1, 40 / canvasH),
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = i % 2 == 0 and 0.97 or 1, Parent = lbList })
			local baseT = row.BackgroundTransparency
			-- click a row: RIVALS' player menu slides out to the left of the list (UIKit.PlayerCards)
			row.Activated:Connect(function() if PlayerCards then PlayerCards.Menu(p, row, 1590) end end)
			row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.94 end)
			row.MouseLeave:Connect(function() row.BackgroundTransparency = baseT end)
			new("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(LB_W, 1), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = row })
			-- (2026-10-20, Edward) Roblox badges: Premium before the name, verified after (UIKit.Badges; Settings > Display Badges)
			local okBd, Bd = pcall(function() return require(game:GetService("ReplicatedStorage").UIKit.Badges) end)
			if (okBd and Bd and Bd.Prefix(p) ~= "") or (not okBd and p.MembershipType == Enum.MembershipType.Premium) then
				Kit.label({ Text = utf8.char(0xE001), FontFace = LB_NUM, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(24, 40), Parent = row })
			end
			local streakN = tonumber(p:GetAttribute("WinStreak")) or 0
			-- (2026-10-20, RIVALS) the device icon right after the name (UIKit.Badges.DeviceIcon)
			local dv = (okBd and Bd and Bd.DeviceIcon) and Bd.DeviceIcon(p) or nil
			if dv then
				local nameText = p.DisplayName .. Bd.Suffix(p)
				local w = game:GetService("TextService"):GetTextSize(nameText, 21, Enum.Font.BuilderSansBold, Vector2.new(400, 40)).X
				Kit.new("ImageLabel", { Name = "Device", BackgroundTransparency = 1, Image = dv, ScaleType = Enum.ScaleType.Fit,
					Position = UDim2.fromOffset(math.min(44 + w + 6, 222), 11), Size = UDim2.fromOffset(18, 18), Parent = row })
			end
			Kit.label({ Text = p.DisplayName .. ((okBd and Bd) and Bd.Suffix(p) or ""), FontFace = LB_NAME, TextSize = 21, TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(44, 0), Size = UDim2.fromOffset(streakN > 0 and lbStat ~= "Streak" and 164 or 196, 40), Parent = row })
			-- the win streak next to the name (RIVALS): a flame with the number over it
			if streakN > 0 and lbStat ~= "Streak" then Kit.streak(row, streakN, UDim2.fromOffset(210, 4), UDim2.fromOffset(32, 32), 3) end
			if lbStat == "Rank" and RankArtLB then
				local r = RankArtLB.Of(p)
				if r.image then
					Kit.new("ImageLabel", { BackgroundTransparency = 1, Image = r.image, ScaleType = Enum.ScaleType.Fit,
						Position = UDim2.fromOffset(266, 3), Size = UDim2.fromOffset(34, 34), Parent = row })
				else
					Kit.label({ Text = "-", FontFace = LB_NUM, TextSize = 22, TextColor3 = Color3.fromRGB(150, 150, 156), TextXAlignment = Enum.TextXAlignment.Right,
						Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(60, 40), Parent = row })
				end
			else
				Kit.label({ Text = tostring(statValue(p)), FontFace = LB_NUM, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(60, 40), Parent = row })
			end
			Kit.toScale(row, Vector2.new(LB_W, 40))
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
		{ dx = 0, dy = -0.32, names = { "Scissors" } },
		{ dx = 0, dy = 0.3, fast = true, names = { "NavShade", "NavKit", "NavMissions", "NavShop", "NavCodes", "NavSettings", "Searching" } },
	}
	local homes = {}
	-- recorded a moment later: Kit.bindButton re-anchors buttons to their centre on the next frame, which moves their Position
	-- (recording first sent Missions / To Pads back to the wrong spot after a menu closed)
	task.delay(0.2, function()
		for _, g in GROUPS do
			for _, n in g.names do
				local o = root:FindFirstChild(n)
				if o then homes[o] = { home = o.Position, away = UDim2.fromScale(o.Position.X.Scale + g.dx, o.Position.Y.Scale + g.dy), t = g.fast and 0.08 or 0.18 } end
			end
		end
	end)
	local pushedAway = false
	local kitShown = false
	local function pushAside(away)
		root:SetAttribute("PushedAway", away)
		resetNav()
		for o, h in homes do
			if o.Name == "PlayerList" and not lbOn then continue end -- hidden by Tab: leave it off screen
			Kit.tween(o, away and h.t or 0.25, { Position = away and h.away or h.home }, away and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
				away and Enum.EasingDirection.In or Enum.EasingDirection.Out)
		end
	end
	local wasTraining = false
	local k = 0
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
		-- Hide Missions (Settings > Video > Interface)
		local noMissions = player:GetAttribute("Setting_HideSideTasks") == true
		missions.Visible = not noMissions and not kitShown
		toPads.Visible = not noMissions and not kitShown and not PseudoLobby.MatchPlace() -- (after-match lobby: the pads are barricaded)
		local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
		seek.Visible = q ~= nil and st == "Searching" and not kitShown
		if seek.Visible then
			local def = Config.QueueById and Config.QueueById(q)
			seekMode.Text = "SEARCHING  " .. (def and (string.upper(def.Mode) .. (def.Ranked and " RANKED" or "")) or "")
			seekMode.TextColor3 = (def and def.Ranked) and hex("#B078FF") or BONE
			k += dt
			local step = math.floor(k / 0.25) % 3
			for i, m in seekMarks do m.BackgroundTransparency = (i - 1) == step and 0 or 0.65 end
		end
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
