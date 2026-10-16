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

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BONE, FIELD, OLIVE, OLIVE_HI = hex("#ECE8DA"), hex("#969C8C"), hex("#6B7A3A"), hex("#8A9C4A")
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local LB_NAME, LB_NUM = Font.new(BUILDER, Enum.FontWeight.Medium), Font.new(BUILDER, Enum.FontWeight.Bold)
local GUN, DEEP, LINE, RED = hex("#1A1D1A"), hex("#0C0E0B"), hex("#40463A"), hex("#D6403A")

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, Parent = parent })
end
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
	local settings = button("Settings", ICON_GEAR, "Change your controls & graphics")
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
		local left = placeBar(mainPill, W - 12, isOpen and { open, settings, codes } or { open })
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
	list.b.Activated:Connect(function() cb.openList() end)
	hud.b.Activated:Connect(function() if cb.showHud then cb.showHud() end end)
	leave.b.Activated:Connect(function() if cb.leave then cb.leave() end end)
	ctl.layout()
	return ctl
end

function LobbyHud.Start()
	local LobbyUI = shared.Get and shared.Get("LobbyUIController")
	local gui = new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui") })
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	---------------------------------------------------------------------------------------------- scissors pill
	local pill = new("Frame", { Name = "Scissors", Position = UDim2.fromOffset(840, 26), Size = UDim2.fromOffset(240, 58), BackgroundColor3 = DEEP, BackgroundTransparency = 0.08, Parent = root })
	brackets(pill, LINE, 12, 2)
	local iconHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-22, -12), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = pill })
	local count = label(pill, "...", OSWALD, 36, 62, 0, 120, 58, BONE, Enum.TextXAlignment.Center, 3)
	local plus = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(190, 9), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = OLIVE, ZIndex = 3, Parent = pill },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#A8BC62"), hex("#5B6E2C")) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 4, Parent = plus })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 4, Parent = plus })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() if LobbyUI and LobbyUI.OpenShop then LobbyUI.Close(); LobbyUI.OpenShop("Scissors") end end)

	---------------------------------------------------------------------------------------------- missions widget
	local missions = new("TextButton", { Name = "Missions", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(16, 360), Size = UDim2.fromOffset(372, 260),
		BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, Parent = root })
	brackets(missions, LINE, 14, 2)
	new("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = OLIVE, BorderSizePixel = 0, ZIndex = 3, Parent = missions })
	label(missions, "DAILY MISSIONS", OSWALD, 28, 18, 8, 240, 40, BONE, nil, 3)
	local reset = label(missions, "", OSWALD, 15, 200, 18, 160, 24, FIELD, Enum.TextXAlignment.Right, 3)
	local rows = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(372, 200), ZIndex = 3, Parent = missions })
	missions.Activated:Connect(function() if LobbyUI then LobbyUI.Open("Missions") end end)
	local toPads = new("TextButton", { Name = "ToPads", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(92, 634), Size = UDim2.fromOffset(220, 52), BackgroundColor3 = OLIVE, Parent = root },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#A8BC62"), hex("#5B6E2C")) }) })
	brackets(toPads, BONE, 10, 2, 4)
	label(toPads, "TO PADS  >", OSWALD, 28, 0, 0, 220, 52, BONE, Enum.TextXAlignment.Center, 3)
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

	Kit.toScale(root)

	-- the 3D scissors in the pill (the same view icon as the shop's balance pill)
	local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
	ViewIcons.Icon(iconHolder, "Scissors", { hoverTarget = pill, zoom = 1.15 })

	---------------------------------------------------------------------------------------------- data
	local data
	local function questDef(scope, id)
		for _, q in Config.Quests[scope].Pool do if q.Id == id then return q end end
	end
	local lastRows
	local function refresh()
		if not data then return end
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
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(372, 200), ZIndex = 3, Parent = rows })
		for i, e in entries do
			local y = (i - 1) * 64
			local done = e.prog >= e.def.Goal
			label(holder, e.def.Text, BOLD, 17, 18, y, 250, 24, e.claimed and FIELD or BONE, nil, 4).TextTruncate = Enum.TextTruncate.AtEnd
			label(holder, e.claimed and "DONE" or (e.prog .. " / " .. e.def.Goal), OSWALD, 18, 250, y, 70, 24, done and OLIVE_HI or FIELD, Enum.TextXAlignment.Right, 4)
			local track = new("Frame", { Position = UDim2.fromOffset(18, y + 30), Size = UDim2.fromOffset(302, 8), BackgroundColor3 = hex("#2A2E26"), BorderSizePixel = 0, ZIndex = 4, Parent = holder })
			new("Frame", { Size = UDim2.fromScale(e.prog / e.def.Goal, 1), BackgroundColor3 = done and OLIVE_HI or BONE, BorderSizePixel = 0, ZIndex = 5, Parent = track })
			label(holder, "+" .. e.def.Reward, OSWALD, 16, 324, y + 18, 44, 24, BONE, Enum.TextXAlignment.Center, 4)
			if done and not e.claimed then
				-- ready to claim: a red flag at the row start (claimed in Missions)
				new("Frame", { Position = UDim2.fromOffset(6, y + 4), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 5, Parent = holder })
			end
		end
		if #entries == 0 then label(holder, "Loading missions...", BODY, 16, 18, 0, 330, 24, FIELD, nil, 4) end
		Kit.toScale(holder, Vector2.new(372, 200))
		holder.Size = UDim2.fromScale(1, 1)
	end
	local function resetText()
		local left = 86400 - os.time() % 86400
		reset.Text = string.format("NEW IN %dH %dM", left // 3600, left % 3600 // 60)
	end

	-- list rows: everyone in the server, sorted by the shown stat
	local ViewIconsLB = require(UIKit:WaitForChild("ViewIcons"))
	local lbStat = "Level"
	local function modeIcon()
		for _, c in lbMode:GetChildren() do c:Destroy() end
		local icons = ReplicatedStorage:FindFirstChild("UIIcons")
		local lvl = icons and (icons:FindFirstChild("LevelUp") or icons:FindFirstChild("Badge"))
		if lbStat == "Level" and lvl then
			ViewIconsLB.Viewport(lbMode, lvl:Clone(), { view = CFrame.Angles(math.rad(8), math.rad(-20), 0), zoom = 1.1, still = true })
		else
			ViewIconsLB.Icon(lbMode, "Trophy", { still = true })
		end
	end
	local lastLB
	local function buildList(force)
		local ps = Players:GetPlayers()
		local key = lbStat
		for _, p in ps do key ..= p.UserId .. "/" .. tostring(p:GetAttribute(lbStat)) end
		if key == lastLB and not force then return end
		lastLB = key
		table.sort(ps, function(a, b)
			local va, vb = a:GetAttribute(lbStat) or 0, b:GetAttribute(lbStat) or 0
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
			row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.94 end)
			row.MouseLeave:Connect(function() row.BackgroundTransparency = baseT end)
			new("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(LB_W, 1), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = row })
			if p.MembershipType == Enum.MembershipType.Premium then
				Kit.label({ Text = utf8.char(0xE001), FontFace = LB_NUM, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(24, 40), Parent = row })
			end
			Kit.label({ Text = p.DisplayName, FontFace = LB_NAME, TextSize = 21, TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(44, 0), Size = UDim2.fromOffset(196, 40), Parent = row })
			Kit.label({ Text = tostring(p:GetAttribute(lbStat) or 0), FontFace = LB_NUM, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(60, 40), Parent = row })
			Kit.toScale(row, Vector2.new(LB_W, 40))
		end
	end
	local function lobbyData()
		local v = player:GetAttribute("Setting_LobbyData")
		if v == "Level" or v == "Wins" then lbStat = v; modeIcon(); buildList(true) end
	end
	player:GetAttributeChangedSignal("Setting_LobbyData"):Connect(lobbyData)
	modeIcon()
	lobbyData()
	lbMode.Activated:Connect(function()
		lbStat = lbStat == "Level" and "Wins" or "Level"
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
		if corner then corner.layout() end
		Kit.tween(lb, 0.12, { Position = on and lbHome or UDim2.fromScale(lbHome.X.Scale + 0.25, lbHome.Y.Scale) }, Enum.EasingStyle.Linear)
	end
	lbHide.Activated:Connect(function() setList(false) end)
	corner = buildCorner(gui, {
		openSettings = function() if LobbyUI then LobbyUI.Open("Settings") end end,
		openCodes = function() if LobbyUI then LobbyUI.Open("Codes") end end,
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

	---------------------------------------------------------------------------------------------- follow the lobby
	local function lobbyShown()
		local pg = player.PlayerGui
		local lobby = pg:FindFirstChild("LobbyUI")
		if not lobby or not lobby.Enabled then return false end
		local dock = lobby:FindFirstChild("Dock", true)
		if dock and not dock.Visible then return false end
		if player:GetAttribute("InTraining") or player:GetAttribute("Deploying") then return false end
		return true
	end
	-- Padded HUD: everything pulled in from the screen edges (TV safe area), always or while a controller is in use
	local lastPad = false
	UserInputService.LastInputTypeChanged:Connect(function(t) lastPad = t.Name:find("Gamepad") ~= nil end)
	local function padded()
		local v = player:GetAttribute("Setting_PaddedHUD") or "Using Controller"
		return v == "Always On" or (v == "Using Controller" and lastPad)
	end
	-- the rest of the lobby HUD (PLAY row, dock) hides with Hide HUD too; the dock's own state is put back after
	local dockSaved
	local cutShown = false
	local wasTraining = false
	local k = 0
	RunService.Heartbeat:Connect(function(dt)
		local on = lobbyShown()
		-- a cutscene (exfil heli etc.; ExfilFX sets InCutscene) hides everything, the corner and the fight HUD too
		local cut = player:GetAttribute("InCutscene") == true
		local hide = hudHidden() or cut
		root.Visible = on and not hide
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
		if hide then
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
		missions.Visible = not noMissions
		toPads.Visible = not noMissions
		local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
		seek.Visible = q ~= nil and st == "Searching"
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
