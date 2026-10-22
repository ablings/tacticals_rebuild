-- UIKit/RankedScreen (ModuleScript): the lobby RANKED screen, full screen like Play / Shop / Codes (UI session 2026-10-17).
-- RIVALS' ranked page, Tacticals' rules (notes/ranked_design.md): one shared rank for 1v1 / 2v2 / 3v3, Bronze-Diamond then
-- Elite / Commander / Warlord (top 200), 10 placements, a daily ELO shield.
--   top:     your emblem + rank name ("Gold 2", "Warlord #12", "Placements 3/10") · Ranks button (the ladder) · red X
--   ELO bar: this tier's floor and emblem · "Your ELO" · the next tier and its floor; the fill = progress through the tier
--   banner:  placements progress, or "Daily ELO Shield Active" (white pill, RIVALS)
--   cards:   Ranked 1v1 / 2v2 / 3v3: click to queue (FindMatch with the ranked queue), click again while searching to cancel
--   bottom:  Warlord strip (the cutoff + the top 3) · Leaderboard button (top 200)
-- Reads the server's player attributes (Rank*) and ReplicatedStorage RankedTop_<key> / RankedCutoff_<key>
-- (notes/ranked_server.md §4). Emblem art: ui/art/ranks/v2 (EMBLEM ids below, once uploaded); a drawn badge until then.
--   RankedScreen.Init({ Config, ask, onOpen, onClose, toast })   RankedScreen.Open() / Close() / IsOpen()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local C, new = Theme.color, Kit.new
local RankedCore
pcall(function() RankedCore = require(ReplicatedStorage.Modules.Shared:WaitForChild("RankedCore", 10)) end)

local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GREY = Theme.hex("#CFCDD3")

-- emblem art (Gunsy Funsy uploads of ui/art/ranks/v2/rank_<name>.png); "" = not uploaded yet -> drawn badge
-- (uploaded 2026-10-17 under Gunsy Funsy; decal ids 138889723915036 ... resolved to these image ids)
local EMBLEM = require(UIKit:WaitForChild("RankArt")).EMBLEM
local RANK_COLOR = {
	Bronze = Theme.hex("#C07A45"), Silver = Theme.hex("#C3C9D3"), Gold = Theme.hex("#F2C14E"), Platinum = Theme.hex("#3FD0D4"),
	Diamond = Theme.hex("#3C8CFF"), Elite = Theme.hex("#3FD1C4"), Commander = Theme.hex("#ECE8DA"), Warlord = Theme.hex("#D9AE3F"),
}
local RANKS = { "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Elite", "Commander", "Warlord" }
local MODES = { "1v1", "2v2", "3v3" }

local Screen = {}
local ctx = {}
local gui, root, blur, scrim
local isOpen = false
local ui = {} -- built pieces

local player = Players.LocalPlayer
local function A(name) return player:GetAttribute(name) end
local function stroke(l, t) new("UIStroke", { Thickness = t or 2, Transparency = 0.3, Parent = l }) return l end
local function label(parent, text, font, size, x, y, w, h, color, align)
	local l = Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Parent = parent })
	l:SetAttribute("dTS", size)
	return l
end

-- an emblem in a holder (all Scale: it can be redrawn at any time). Placements: a grey "?" badge.
local function emblem(holder, rank)
	for _, c in holder:GetChildren() do if c.Name == "Emblem" then c:Destroy() end end
	local e = new("Frame", { Name = "Emblem", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
	local id = rank and EMBLEM[rank] or ""
	if id ~= "" then
		new("ImageLabel", { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = e })
		return
	end
	local col = rank and RANK_COLOR[rank] or Theme.hex("#5A5862")
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78),
		Rotation = 45, BackgroundColor3 = WHITE, Parent = e }, {
		new("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(WHITE, 0.35), col:Lerp(BLACK, 0.35)) }),
		new("UIStroke", { Color = col:Lerp(BLACK, 0.55), Thickness = 3 }),
	})
	local t = new("TextLabel", { BackgroundTransparency = 1, Rotation = -45, Text = rank and rank:sub(1, 1) or "?", FontFace = FB, TextScaled = true,
		TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55), Parent = badge })
	new("UIStroke", { Thickness = 2, Transparency = 0.4, Parent = t })
end

local function ladderKey()
	if RankedCore and not RankedCore.Config.PerModeLadders then return RankedCore.Config.SharedKey end
	return A("RankMode") or "1v1"
end
local function leaderboard()
	local key = ladderKey()
	local ok, top = pcall(function() return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("RankedTop_" .. key) or "[]") end)
	return ok and top or {}, ReplicatedStorage:GetAttribute("RankedCutoff_" .. key)
end

-- queue state (the matchmaking attributes the PLAY screen uses too)
local function queueFor(mode) return ctx.Config and ctx.Config.QueueFor and ctx.Config.QueueFor(mode, true) end
local function searching() return A("MM_Queue"), A("MM_Status") end

---------------------------------------------------------------------------------------------------- render (live)
local function render()
	if not root then return end
	local placed, need = A("RankPlaced") or 0, A("RankPlacements") or 0
	local inPlacements = need > 0 and placed < need
	local rank = A("RankWarlord") and "Warlord" or A("RankTier")
	local elo = A("RankElo") or (RankedCore and RankedCore.Config.StartElo) or 100
	emblem(ui.topEmblem, not inPlacements and rank or nil)
	ui.rankName.Text = inPlacements and "Placements" or (A("RankName") or "Bronze 1")
	ui.rankSub.Text = inPlacements and string.format("%d / %d placement matches played: your rank shows after the last one", placed, need)
		or ("Peak " .. tostring(A("RankPeak") or elo) .. " ELO")
	-- the ELO bar
	local floor, nextFloor = A("RankFloor") or 100, A("RankNextFloor")
	ui.eloNum.Text = inPlacements and "?" or tostring(elo)
	ui.leftName.Text = inPlacements and "" or (A("RankName") or "")
	ui.leftFloor.Text = inPlacements and "" or tostring(floor)
	emblem(ui.leftEmblem, not inPlacements and rank or nil)
	if nextFloor and not inPlacements then
		local nextName = A("RankNextName") or ""
		ui.rightName.Text, ui.rightFloor.Text = nextName, tostring(nextFloor)
		emblem(ui.rightEmblem, nextName:match("^(%a+)"))
		ui.fill.Size = UDim2.fromScale(math.clamp((elo - floor) / math.max(nextFloor - floor, 1), 0, 1), 1)
	else
		ui.rightName.Text, ui.rightFloor.Text = inPlacements and "" or "Top 200", ""
		emblem(ui.rightEmblem, nil)
		ui.rightEmblem:FindFirstChild("Emblem"):Destroy()
		ui.fill.Size = UDim2.fromScale(inPlacements and placed / math.max(need, 1) or 1, 1)
	end
	-- banner
	if inPlacements then
		ui.banner.Visible, ui.bannerText.Text = true, string.format("Placement match %d of %d: wins and losses count double", placed + 1, need)
	elseif A("RankShield") then
		ui.banner.Visible, ui.bannerText.Text = true, "Daily ELO Shield Active: you won't lose any ELO from your next loss!"
	else
		ui.banner.Visible = false
	end
	-- queue cards
	local q, st = searching()
	for mode, c in ui.cards do
		local mq = queueFor(mode)
		local mine = q and mq and q == mq.Id and st == "Searching"
		-- (2026-10-21, RIVALS pass) the status lives in the green PLAY bar: idle = PLAY on field green, searching / busy = a dark bar
		local idle = not q
		c.status.Text = mine and "SEARCHING...  TAP TO CANCEL" or (q and "IN ANOTHER QUEUE" or "PLAY")
		c.green.Enabled = idle
		c.bar.BackgroundColor3 = idle and WHITE or BLACK
		c.bar.BackgroundTransparency = idle and 0 or (mine and 0.1 or 0.35)
		c.shadow.Visible = idle
		c.edge.Transparency = mine and 0.05 or 1
	end
	-- Warlord strip
	local top, cutoff = leaderboard()
	local bits = {}
	for i = 1, math.min(3, #top) do table.insert(bits, string.format("#%d %s (%d)", i, top[i].name or "?", top[i].elo or 0)) end
	ui.warlordText.Text = (#bits > 0 and table.concat(bits, "     ") or "No Warlords yet: be the first")
	ui.warlordCut.Text = cutoff and ("Warlord from " .. cutoff .. " ELO") or "Warlord: 2200+ ELO and the top 200"
end

---------------------------------------------------------------------------------------------------- popups
local function popup(name, w, h, title)
	local shade = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 20, Parent = root })
	local p = new("Frame", { Name = "Panel", Position = UDim2.fromOffset((1920 - w) / 2, (1080 - h) / 2), Size = UDim2.fromOffset(w, h), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.08, ZIndex = 21, Parent = shade }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	stroke(label(p, title, FB, 56, 0, 18, w, 64), 2.5).ZIndex = 22
	local x = Kit.closeButton(UDim2.fromOffset(96, 50))
	x.Position = UDim2.fromOffset(w - 116, 22)
	x.ZIndex = 23
	x.Parent = p
	local function hide() shade.Visible = false end
	x.Activated:Connect(hide)
	shade.Activated:Connect(hide)
	return shade, p
end

local function buildLadder()
	local shade, p = popup("Ladder", 1300, 760, "Ranks")
	local names = RANKS
	for i, r in names do
		local x = 40 + (i - 1) * 152
		local col = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 110), Size = UDim2.fromOffset(140, 260), ZIndex = 22, Parent = p })
		local hold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(120, 120), ZIndex = 23, Parent = col })
		emblem(hold, r)
		local floorText = r == "Warlord" and "Top 200" or tostring(((i - 1) * 3 + 1) * 100) .. "+"
		label(col, floorText, FB, 30, 0, 128, 140, 36, WHITE).ZIndex = 23
		local bar = new("Frame", { Position = UDim2.fromOffset(20, 172), Size = UDim2.fromOffset(100, 70), BackgroundColor3 = RANK_COLOR[r], ZIndex = 22, Parent = col },
			{ new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		label(bar, r, FS, 20, 0, 18, 100, 30, BLACK).ZIndex = 23
	end
	local rules = {
		"One rank for 1v1, 2v2 and 3v3. Every rank has 3 tiers, 100 ELO each. You never drop below Bronze 1.",
		"Play 10 placement matches to show your rank: wins and losses count double while you place.",
		"Beat higher ranks for more ELO; losing to lower ranks costs more. Gains shrink and losses grow as you climb.",
		"Daily ELO Shield: your first loss each day costs nothing (below Elite). Leaving a match: the loss plus 25 ELO.",
		"Elite and up: after 7 days without ranked you lose 25 ELO a day (never below Elite 1).",
		"Past Commander 3 (2200 ELO) the top 200 players are Warlord.",
	}
	for i, t in rules do
		label(p, "•  " .. t, FM, 26, 60, 400 + (i - 1) * 54, 1180, 44, GREY, Enum.TextXAlignment.Left).ZIndex = 22
	end
	return shade
end

local function buildBoard()
	local shade, p = popup("Leaderboard", 900, 820, "Warlord · Top 200")
	local listHold = new("ScrollingFrame", { Name = "List", Position = UDim2.fromOffset(40, 110), Size = UDim2.fromOffset(820, 680), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = p },
		{ new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	ui.boardList = listHold
	return shade
end

local function fillBoard()
	local holder = ui.boardList
	for _, c in holder:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local top = leaderboard()
	if #top == 0 then
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = "Nobody has reached 2200 ELO yet.", FontFace = FM, TextScaled = true, TextColor3 = GREY,
			Size = UDim2.new(1, 0, 0.07, 0), ZIndex = 23, Parent = holder })
		return
	end
	for i, e in top do
		local mine = e.userId == player.UserId
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0.07, 0), BackgroundColor3 = mine and C.white or BLACK, BackgroundTransparency = mine and 0.75 or 0.5,
			ZIndex = 22, Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.2, 0) }) })
		local function cell(text, x, w, align, font)
			new("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = font or FS, TextScaled = true, TextColor3 = WHITE, TextXAlignment = align,
				Position = UDim2.fromScale(x, 0.18), Size = UDim2.fromScale(w, 0.64), ZIndex = 23, Parent = row })
		end
		cell("#" .. i, 0.03, 0.12, Enum.TextXAlignment.Left, FB)
		cell(tostring(e.name or "?"), 0.17, 0.55, Enum.TextXAlignment.Left)
		cell(tostring(e.elo or 0) .. " ELO", 0.72, 0.25, Enum.TextXAlignment.Right, FB)
	end
end

---------------------------------------------------------------------------------------------------- build
local function build()
	gui = new("ScreenGui", { Name = "RankedUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	-- top: emblem + rank name, Ranks button, X
	local top = new("Frame", { Name = "Top", Position = UDim2.fromOffset(220, 70), Size = UDim2.fromOffset(1480, 150), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	ui.topEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(130, 130), Parent = top })
	ui.rankName = stroke(label(top, "Bronze 1", FB, 64, 170, 22, 800, 74, WHITE, Enum.TextXAlignment.Left), 2.5)
	ui.rankSub = label(top, "", FM, 26, 172, 96, 900, 36, GREY, Enum.TextXAlignment.Left)
	local ranksBtn = new("TextButton", { Name = "Ranks", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1210, 44), Size = UDim2.fromOffset(240, 64),
		BackgroundColor3 = WHITE, Parent = top }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	label(ranksBtn, "Ranks", FB, 36, 0, 0, 240, 64, BLACK)
	local close = Kit.closeButton(UDim2.fromOffset(112, 58))
	close.Position = UDim2.fromOffset(1730, 116)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)

	-- ELO bar
	local bar = new("Frame", { Name = "EloBar", Position = UDim2.fromOffset(220, 236), Size = UDim2.fromOffset(1480, 110), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	ui.leftEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(76, 76), Parent = bar })
	ui.leftFloor = label(bar, "", FB, 30, 104, 12, 300, 36, WHITE, Enum.TextXAlignment.Left)
	ui.leftName = label(bar, "", FS, 26, 104, 46, 300, 32, GREY, Enum.TextXAlignment.Left)
	label(bar, "Your ELO", FS, 22, 590, 8, 300, 28, GREY)
	ui.eloNum = stroke(label(bar, "100", FB, 50, 590, 30, 300, 54, WHITE), 2)
	ui.rightEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(1388, 12), Size = UDim2.fromOffset(76, 76), Parent = bar })
	ui.rightFloor = label(bar, "", FB, 30, 1076, 12, 300, 36, WHITE, Enum.TextXAlignment.Right)
	ui.rightName = label(bar, "", FS, 26, 1076, 46, 300, 32, GREY, Enum.TextXAlignment.Right)
	local track = new("Frame", { Position = UDim2.fromOffset(104, 88), Size = UDim2.fromOffset(1272, 10), BackgroundColor3 = Theme.hex("#2A2830"), Parent = bar },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	ui.fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Color = ColorSequence.new(Theme.hex("#FFE14D"), Theme.hex("#FFFFFF")) }) })

	-- banner (white pill, RIVALS)
	ui.banner = new("Frame", { Name = "Banner", Position = UDim2.fromOffset(220, 362), Size = UDim2.fromOffset(1480, 54), BackgroundColor3 = WHITE, Visible = false, Parent = root },
		{ new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	ui.bannerText = label(ui.banner, "", FB, 28, 0, 0, 1480, 54, BLACK)

	-- mode cards
	ui.cards = {}
	for i, mode in MODES do
		local card = new("TextButton", { Name = "Ranked" .. mode, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(220 + (i - 1) * 500, 432),
			Size = UDim2.fromOffset(480, 380), BackgroundColor3 = WHITE, Parent = root }, {
			new("UICorner", { CornerRadius = UDim.new(0, 14) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.hex("#3B4524"), Theme.hex("#14170F")) }),
		})
		local edge = new("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		stroke(label(card, "Ranked", FB, 72, 0, 90, 480, 84, WHITE), 3)
		stroke(label(card, mode, FB, 96, 0, 170, 480, 108, WHITE), 3)
		-- (2026-10-21, RIVALS pass) a real PLAY bar (PlayScreen's field-green strip, inset as a button): solid fill on an offset
		-- block, no outline; the queue status is written in it (render)
		local shadow = new("Frame", { Name = "PlayShadow", Position = UDim2.fromOffset(24, 302), Size = UDim2.fromOffset(432, 62), BackgroundColor3 = C.fieldDark,
			BorderSizePixel = 0, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		local bar = new("Frame", { Name = "PlayBar", Position = UDim2.fromOffset(24, 296), Size = UDim2.fromOffset(432, 62), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		local green = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)), Parent = bar })
		local status = label(bar, "PLAY", Theme.font.chunky, 30, 0, 0, 432, 62, WHITE)
		new("UIStroke", { Color = Color3.fromRGB(28, 44, 16), Thickness = 2, Transparency = 0.3, Parent = status }) -- text outline, not a border
		Kit.bindButton(card, { hover = 1.02, press = 0.985 })
		card.Activated:Connect(function()
			local q, st = searching()
			local mq = queueFor(mode)
			if not mq then if ctx.toast then ctx.toast("Ranked " .. mode .. " isn't available yet", "bad") end return end
			if q == mq.Id and st == "Searching" then if ctx.ask then ctx.ask("CancelMatch") end return end
			if q then return end
			local r = ctx.ask and ctx.ask("FindMatch", mq.Id)
			if not (r and r.ok) and ctx.toast then ctx.toast((r and r.msg) or "Couldn't join the ranked queue", "bad") end
		end)
		ui.cards[mode] = { card = card, status = status, edge = edge, bar = bar, green = green, shadow = shadow }
	end

	-- Warlord strip + leaderboard button
	local strip = new("Frame", { Name = "Warlord", Position = UDim2.fromOffset(220, 830), Size = UDim2.fromOffset(1480, 100), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	local wHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(84, 84), Parent = strip })
	emblem(wHold, "Warlord")
	ui.warlordCut = label(strip, "", FB, 28, 112, 12, 900, 36, WHITE, Enum.TextXAlignment.Left)
	ui.warlordText = label(strip, "", FS, 24, 112, 52, 1000, 34, GREY, Enum.TextXAlignment.Left)
	local boardBtn = new("TextButton", { Name = "Leaderboard", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1200, 20), Size = UDim2.fromOffset(260, 60),
		BackgroundColor3 = WHITE, Parent = strip }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	label(boardBtn, "Leaderboard", FB, 30, 0, 0, 260, 60, BLACK)

	-- popups (built hidden, converted with the rest)
	local ladder = buildLadder()
	local board = buildBoard()
	Kit.bindButton(ranksBtn, { hover = 1.04, press = 0.97 })
	ranksBtn.Activated:Connect(function() ladder.Visible = true end)
	Kit.bindButton(boardBtn, { hover = 1.04, press = 0.97 })
	boardBtn.Activated:Connect(function() fillBoard(); board.Visible = true end)

	Kit.toScale(root)
	root.Visible = false
	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
	-- live: any rank / queue change while open
	for _, a in { "RankElo", "RankName", "RankTier", "RankFloor", "RankNextFloor", "RankShield", "RankPlaced", "RankWarlord", "MM_Queue", "MM_Status" } do
		player:GetAttributeChangedSignal(a):Connect(function() if isOpen then render() end end)
	end
	ReplicatedStorage.AttributeChanged:Connect(function(a) if isOpen and a:match("^RankedTop_") then render() end end)
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		render()
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
function Screen.Refresh() if isOpen then render() end end

return Screen
