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
local TextService = game:GetService("TextService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Assets = {} -- the Rivals art ids (banner shields); empty if the module isn't there
pcall(function() Assets = require(UIKit:WaitForChild("Rivals"):WaitForChild("Assets", 5)) end)
local C, new = Theme.color, Kit.new
local RankedCore
pcall(function() RankedCore = require(ReplicatedStorage.Modules.Shared:WaitForChild("RankedCore", 10)) end)

-- (2026-10-21, AI-tells cleanup) was Builder Sans everywhere: headings / numbers in Oswald Bold, labels and body in Rubik
local FB = Theme.font.display -- Oswald Bold
local FS = Theme.font.bold -- Rubik SemiBold
local FM = Theme.font.medium -- Rubik Medium
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
	ui.rankName.Text = inPlacements and (placed .. "/" .. need) or (A("RankName") or "Bronze 1")
	ui.rankUnit.Text = inPlacements and "Placed" or ""
	-- the unit sits right after the count, measured from the live label (e15, grader C: GothamBold drifted from our font)
	task.defer(function()
		local st = ui.rankName.Parent
		if not (inPlacements and st and st.AbsoluteSize.X > 0) then return end
		local right = ui.rankName.AbsolutePosition.X - st.AbsolutePosition.X + ui.rankName.TextBounds.X
		ui.rankUnit.Position = UDim2.fromScale((right + 10 * st.AbsoluteSize.X / 330) / st.AbsoluteSize.X, ui.rankUnit.Position.Y.Scale)
	end)
	-- banner shields hug the words (e15)
	task.defer(function()
		local b = ui.banner
		if not (b.Visible and b.AbsoluteSize.X > 0) then return end
		local half = ui.bannerText.TextBounds.X / 2 / b.AbsoluteSize.X
		local pad = 34 / 1412
		ui.bannerShields[1].Position = UDim2.fromScale(0.5 - half - pad, 0.5)
		ui.bannerShields[2].Position = UDim2.fromScale(0.5 + half + pad, 0.5)
	end)
	ui.rankSub.Text = inPlacements and string.format("%d / %d placement matches played: your rank shows after the last one", placed, need)
		or ("Peak " .. tostring(A("RankPeak") or elo) .. " ELO")
	-- the ELO bar
	local floor, nextFloor = A("RankFloor") or 100, A("RankNextFloor")
	ui.eloNum.Text = inPlacements and "?" or ui.eloNum.Text
	if inPlacements then ui.eloShown = nil; ui.eloNum:SetAttribute("_CountToken", (ui.eloNum:GetAttribute("_CountToken") or 0) + 1) end -- (2026-10-21, round 3) stops a running count-up
	ui.leftName.Text = inPlacements and "Placements played" or (A("RankName") or "")
	ui.leftFloor.Text = inPlacements and tostring(placed) or tostring(floor)
	emblem(ui.leftEmblem, not inPlacements and rank or nil)
	if nextFloor and not inPlacements then
		local nextName = A("RankNextName") or ""
		ui.rightName.Text, ui.rightFloor.Text = nextName, tostring(nextFloor)
		emblem(ui.rightEmblem, nextName:match("^(%a+)"))
		Kit.fillTo(ui.fill, math.clamp((elo - floor) / math.max(nextFloor - floor, 1), 0, 1), 0.6) -- (2026-10-21, round 3) the bar fills, was set
	else
		ui.rightName.Text, ui.rightFloor.Text = inPlacements and "Rank reveal" or "Top 200", inPlacements and tostring(need) or ""
		emblem(ui.rightEmblem, nil)
		if not inPlacements then ui.rightEmblem:FindFirstChild("Emblem"):Destroy() end -- (e7, grader B: placements show the "?" badge at both ends)
		Kit.fillTo(ui.fill, inPlacements and placed / math.max(need, 1) or 1, 0.6)
	end
	-- (2026-10-21, round 3: match RIVALS' counters) the ELO number counts from what was shown (from the tier floor on open)
	if not inPlacements then
		Kit.countTo(ui.eloNum, ui.eloShown or floor, elo, 0.6, function(n) return tostring(math.floor(n + 0.5)) end)
		ui.eloShown = elo
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
		c.shadow.Visible = false
		c.bar.Visible = not idle -- (menus e2, RIVALS: no PLAY bar at rest; the bar only carries a queue state)
		c.edge.Transparency = mine and 0.05 or 1
		emblem(c.badge, not inPlacements and rank or nil)
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
		BackgroundTransparency = 0.08, ZIndex = 21, Active = true, Parent = shade }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) }) -- (menus e2, grader C: Active, so a click inside the panel no longer reaches the shade and closes it)
	stroke(label(p, title, FB, 56, 0, 18, w, 64), 2.5).ZIndex = 22
	local x = Kit.closeButton(UDim2.fromOffset(108, 62)) -- (menus e4, grader A: RIVALS' modal close is 108x62, inset 10)
	x.Position = UDim2.fromOffset(w - 118, 10)
	x.ZIndex = 23
	x.Parent = p
	-- (2026-10-21, round 3: match RIVALS t0285.4-t0286, the card pops in) the popups open / close with Kit.open / Kit.close
	-- (was Visible on / off); the shade goes once the panel's close has finished, unless it was reopened meanwhile
	-- (menus e4, grader C) the shade fades in / out with the panel instead of appearing in one frame
	local function hide()
		Kit.tween(shade, 0.12, { BackgroundTransparency = 1 })
		Kit.close(p, function() if not p.Visible then shade.Visible = false end end)
	end
	local function show()
		shade.BackgroundTransparency = 1
		shade.Visible = true
		Kit.tween(shade, 0.2, { BackgroundTransparency = 0.35 })
		Kit.open(p)
	end
	x.Activated:Connect(hide)
	shade.Activated:Connect(hide)
	return shade, p, show
end

local function buildLadder()
	-- (menus e4-e5, grader A) RIVALS' Ranks modal: 882x629 at (519,225)
	local shade, p, show = popup("Ladder", 882, 629, "Ranked")
	-- (menus e10, graders A + B vs 05) the whole body under the title scrolls (heading, podium, rules), with a slim bar at the
	-- modal's right edge, like RIVALS; a list layout of fixed-size blocks (the pattern that survives Kit.toScale)
	-- (e11, grader A: the body is 858 wide, so its bar sits 24 in from the modal's edge)
	local body = new("ScrollingFrame", { Name = "Body", Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(858, 547), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22, Parent = p }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingBottom = UDim.new(0, 24) }), -- (e10, grader C: the last rule scrolls clear of the fade)
	})
	-- (menus e6, grader A vs 05) RIVALS titles the modal "Ranked" and heads the podium "Ranks" on the left
	-- (menus e4-e10, graders A + B vs RIVALS 05_rank_ladder.jpg) a stepped podium: each rank is a pillar rising left to right
	-- (98 wide, gap 4, 90 -> 272 tall: the Bronze-to-Warlord climb ~185 like RIVALS), its colour darkening downward, an 88 px
	-- emblem overlapping its top, the ELO floor (italic 34) under the emblem and the rank name (italic 17, one size for all) at
	-- its foot. (grader C) The columns rise from the podium's floor one after another when the modal opens.
	-- (e11, graders A + C) the "Ranks" heading sits inside the podium's top-left (the short pillars leave room), so the Top 200
	-- emblem is level with it like RIVALS; 20 px of headroom keeps the hover lift from being clipped
	local PH = 370
	local podium = new("Frame", { Name = "Podium", BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2, Size = UDim2.fromOffset(828, PH),
		ZIndex = 22, Parent = body })
	label(podium, "Ranks", FB, 40, 4, 4, 300, 50, WHITE, Enum.TextXAlignment.Left).ZIndex = 22
	local italic = function(f) return Font.new(f.Family, f.Weight, Enum.FontStyle.Italic) end
	local cols = {}
	for i, r in RANKS do
		local x = (i - 1) * 101 -- (e15, grader A: 15 clear of the scroll bar)
		local h = 90 + (i - 1) * 26
		local c = RANK_COLOR[r]
		local col = new("Frame", { Name = r, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, PH - h - 68), Size = UDim2.fromOffset(98, h + 68),
			ZIndex = 22, Parent = podium })
		new("Frame", { Name = "Pillar", Position = UDim2.fromOffset(0, 68), Size = UDim2.fromOffset(98, h), BackgroundColor3 = WHITE, BorderSizePixel = 0,
			ZIndex = 22, Parent = col }, {
			new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c, c:Lerp(BLACK, 0.65)) }),
		})
		-- (e6: the art has padding, so 108 shows an 88 px emblem; e7: a centred anchor, so the hover lift grows in place)
		local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(49, 46), Size = UDim2.fromOffset(108, 108),
			ZIndex = 24, Parent = col })
		emblem(hold, r)
		-- (menus e7, grader C) each column answers hover: its emblem lifts a little
		local lift = new("UIScale", { Parent = hold })
		col.MouseEnter:Connect(function() Kit.tween(lift, 0.12, { Scale = 1.1 }) end)
		col.MouseLeave:Connect(function() Kit.tween(lift, 0.12, { Scale = 1 }) end)
		local floorText = r == "Warlord" and "Top 200" or tostring(((i - 1) * 3 + 1) * 100) .. "+"
		stroke(label(col, floorText, italic(FB), 34, -8, 90, 114, 38, WHITE), 2).ZIndex = 25
		local n = label(col, r, italic(FS), 17, 0, h + 68 - 28, 98, 24, WHITE)
		n.TextTransparency = 0.15
		n.ZIndex = 25
		table.insert(cols, col)
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
		local l = label(body, "•  " .. t, FM, 26, 0, 0, 800, 64, GREY, Enum.TextXAlignment.Left)
		l.LayoutOrder = 2 + i
		l.ZIndex = 23
		l.TextWrapped = true
		l.TextYAlignment = Enum.TextYAlignment.Top
	end
	-- (menus e9, grader C) the body fades out at the bottom edge instead of being cut
	new("Frame", { Name = "Fade", Position = UDim2.fromOffset(30, 629 - 12 - 24), Size = UDim2.fromOffset(812, 24), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 24,
		Parent = p }, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local function rise()
		body.CanvasPosition = Vector2.zero
		for i, col in cols do
			local home = col:GetAttribute("_Home") or col.Position
			col:SetAttribute("_Home", home)
			col.Position = UDim2.new(home.X.Scale, home.X.Offset, 1, 0)
			task.delay(0.05 + (i - 1) * 0.04, function() Kit.tween(col, 0.3, { Position = home }) end)
		end
	end
	return function() show(); rise() end -- (2026-10-21, round 3) opens with a pop
end

local function buildBoard()
	-- (menus e4, grader A) the Leaderboard shares the Ranks modal's frame (882 wide), with a column-header row over the list
	local _, p, show = popup("Leaderboard", 882, 629, "Warlord · Top 200")
	local head = new("Frame", { Name = "Head", Position = UDim2.fromOffset(40, 85), Size = UDim2.fromOffset(792, 48), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
		ZIndex = 22, Parent = p }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	-- (e15, grader B) the column heads are quiet: 20 px at 60% white
	for _, h in { label(head, "Rank", FB, 20, 20, 0, 120, 48, WHITE, Enum.TextXAlignment.Left), label(head, "Player", FB, 20, 150, 0, 400, 48, WHITE, Enum.TextXAlignment.Left),
		label(head, "ELO", FB, 20, 600, 0, 172, 48, WHITE, Enum.TextXAlignment.Right) } do
		h.ZIndex = 23
		h.TextTransparency = 0.4
	end
	local listHold = new("ScrollingFrame", { Name = "List", Position = UDim2.fromOffset(40, 145), Size = UDim2.fromOffset(802, 464), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 10, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = p }, -- (e4: one scrollbar style, 10 px white)
		{ new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	ui.boardList = listHold
	return show
end

local function fillBoard()
	local holder = ui.boardList
	for _, c in holder:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local top = leaderboard()
	if #top == 0 then
		-- (menus e4, grader A) the empty state sits in the middle of the list, and an idle list shows no scrollbar;
		-- (menus e12, grader B) with the Warlord crest above it
		holder.ScrollBarImageTransparency = 1
		new("Frame", { Name = "Spacer", BackgroundTransparency = 1, LayoutOrder = 0, Size = UDim2.new(1, 0, 0.3, 0), Parent = holder })
		local crest = new("Frame", { Name = "Crest", BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0.24, 0), Parent = holder }) -- (e13, grader B: a ~96 px crest)
		local cHold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 1), Parent = crest },
			{ new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		emblem(cHold, "Warlord")
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = "Nobody has reached 2200 ELO yet.", FontFace = FM, TextScaled = true, TextColor3 = GREY,
			LayoutOrder = 2, Size = UDim2.new(1, 0, 0.07, 0), ZIndex = 23, Parent = holder })
		-- (menus e14, grader B) a quieter hint under it
		local hint = new("TextLabel", { BackgroundTransparency = 1, Text = "Reach 2200 ELO, then climb into the top 200.", FontFace = FM, TextScaled = true,
			TextColor3 = WHITE, TextTransparency = 0.4, LayoutOrder = 3, Size = UDim2.new(1, 0, 0.058, 0), ZIndex = 23, Parent = holder }) -- (e15: 22 px)
		return
	end
	holder.ScrollBarImageTransparency = #top > 9 and 0.4 or 1
	for i, e in top do
		local mine = e.userId == player.UserId
		-- (menus e15, grader C) CanvasGroup rows, so they fade as they pop
		local row = new("CanvasGroup", { LayoutOrder = i, GroupTransparency = 1, Size = UDim2.new(1, -10, 0.07, 0), BackgroundColor3 = mine and C.white or BLACK, BackgroundTransparency = mine and 0.75 or 0.5,
			ZIndex = 22, Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.2, 0) }) })
		if Kit.popIn and i <= 12 then pcall(Kit.popIn, row, 0.04 + i * 0.02) end -- (menus e10, grader C: the rows stagger in)
		task.delay(i <= 12 and (0.04 + i * 0.02) or 0, function() Kit.tween(row, 0.2, { GroupTransparency = 0 }) end)
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
	-- (menus e5, grader A vs RIVALS 02_ranked_screen) not one 150-tall plate: three 66-tall blocks at y 125 like RIVALS'
	-- Glory / rules strip / Season row, so the mode cards below get their height back. Everything spans 254-1666 (the cards).
	local L, WIDE = 254, 1412
	local top = new("Frame", { Name = "Top", BackgroundTransparency = 1, Position = UDim2.fromOffset(L, 125), Size = UDim2.fromOffset(WIDE, 66), Parent = root })
	local status = new("Frame", { Name = "Status", Size = UDim2.fromOffset(330, 66), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Parent = top },
		{ new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	ui.topEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(56, 56), Parent = status })
	ui.rankName = stroke(label(status, "Bronze 1", FB, 38, 74, 0, 250, 66, WHITE, Enum.TextXAlignment.Left), 2)
	-- (menus e14, grader B vs RIVALS 02 "138 Glory") in placements the block reads a big count with a small unit beside it
	ui.rankUnit = label(status, "", FS, 22, 74, 6, 160, 66, GREY, Enum.TextXAlignment.Left)
	local strip = new("Frame", { Name = "Rules", Position = UDim2.fromOffset(342, 0), Size = UDim2.fromOffset(820, 66), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35,
		Parent = top }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	ui.rankSub = label(strip, "", FM, 26, 20, 12, 720, 42, WHITE) -- (e7, grader B: 26 full white)
	ui.rankSub.TextScaled = true -- (e12) long placement text shrinks to clear the "i" square
	new("UITextSizeConstraint", { MaxTextSize = 26, Parent = ui.rankSub })
	-- (menus e12, grader B vs RIVALS 02: an "i" square at the strip's right end) opens the ranks and rules
	local info = new("TextButton", { Name = "Info", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(820 - 20 - 40, 13), Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = WHITE, Parent = strip }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	label(info, "i", FB, 32, 0, 0, 40, 40, BLACK)
	ui.infoBtn = info
	local ranksBtn = new("TextButton", { Name = "Ranks", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1174, 0), Size = UDim2.fromOffset(238, 66),
		BackgroundColor3 = WHITE, Parent = top }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	label(ranksBtn, "Ranks", FB, 36, 0, 0, 238, 66, BLACK)
	local close = Kit.closeButton(UDim2.fromOffset(112, 66))
	close.Position = UDim2.fromOffset(L + WIDE + 24, 125)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)

	-- ELO bar
	local bar = new("Frame", { Name = "EloBar", Position = UDim2.fromOffset(L, 203), Size = UDim2.fromOffset(WIDE, 96), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	ui.leftEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 6), Size = UDim2.fromOffset(84, 84), Parent = bar }) -- (menus e7, grader B: 84 px end badges; e13, grader A: inset 28)
	ui.leftFloor = label(bar, "", FB, 30, 138, 8, 300, 36, WHITE, Enum.TextXAlignment.Left)
	ui.leftName = label(bar, "", FS, 26, 138, 40, 300, 32, GREY, Enum.TextXAlignment.Left)
	label(bar, "Your ELO", FS, 22, 556, 4, 300, 28, GREY)
	ui.eloNum = stroke(label(bar, "100", FB, 58, 556, 20, 300, 60, WHITE), 2)
	ui.rightEmblem = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(1300, 6), Size = UDim2.fromOffset(84, 84), Parent = bar })
	ui.rightFloor = label(bar, "", FB, 30, 974, 8, 300, 36, WHITE, Enum.TextXAlignment.Right)
	ui.rightName = label(bar, "", FS, 26, 974, 40, 300, 32, GREY, Enum.TextXAlignment.Right)
	local track = new("Frame", { Position = UDim2.fromOffset(138, 76), Size = UDim2.fromOffset(1136, 10), BackgroundColor3 = Theme.hex("#2A2830"), Parent = bar },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	ui.fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Color = ColorSequence.new(Theme.hex("#8DBF5A"), Theme.hex("#FFFFFF")) }) }) -- (2026-10-21, AI-tells cleanup) progress = field green, was yellow

	-- banner (white pill, RIVALS)
	ui.banner = new("Frame", { Name = "Banner", Position = UDim2.fromOffset(L, 311), Size = UDim2.fromOffset(WIDE, 63), BackgroundColor3 = WHITE, Visible = false, Parent = root },
		{ new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	ui.bannerText = label(ui.banner, "", FB, 30, 0, 0, WIDE, 63, BLACK)
	-- (menus e15, grader B vs RIVALS 02) a 40 px shield either side of the banner's words; render() places them by the text width
	local shieldImg = (Assets.play and Assets.play.shield_badge) or ""
	ui.bannerShields = {}
	for i = 1, 2 do
		ui.bannerShields[i] = new("ImageLabel", { Name = "Shield", BackgroundTransparency = 1, Image = shieldImg, ImageColor3 = BLACK, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(WIDE / 2, 31), Size = UDim2.fromOffset(40, 40), ZIndex = 2, Parent = ui.banner })
	end
	-- (menus e7, grader B vs RIVALS 02) the banner points down at each mode card: a small white notch under each card's centre
	for i = 1, 3 do
		new("Frame", { Name = "Notch", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(233 + (i - 1) * 473, 63), Size = UDim2.fromOffset(20, 20), Rotation = 45,
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 0, Parent = ui.banner })
	end

	-- mode cards
	ui.cards = {}
	for i, mode in MODES do
		local card = new("TextButton", { Name = "Ranked" .. mode, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(L + (i - 1) * 473, 392),
			Size = UDim2.fromOffset(466, 564), BackgroundColor3 = WHITE, Parent = root }, { -- (menus e2, graders A + B vs RIVALS 02_ranked_screen: tall cards, the whole card is the button)
			new("UICorner", { CornerRadius = UDim.new(0, 14) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.hex("#3B4524"), Theme.hex("#14170F")) }),
		})
		local edge = new("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		-- (2026-10-21, round 3: match RIVALS t0291, mode tiles = the mode name over a scene) a live 3D squad behind the words
		-- (PlayScreen's squad: you + mates vs dark-gold silhouettes, hops on hover); built on every open (render-time character)
		local stage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(466, 544), ZIndex = 2,
			ClipsDescendants = true, Parent = card })
		-- (menus e6, graders A + B vs RIVALS 02: each tile carries a ranked badge at its foot, bottom-left, inset 22) your rank's
		-- emblem; render() fills it
		local badge = new("Frame", { Name = "Badge", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 564 - 22 - 63), Size = UDim2.fromOffset(63, 63), ZIndex = 4, Parent = card })
		stroke(label(card, "Ranked", FB, 80, 0, 168, 466, 90, WHITE), 3).ZIndex = 4 -- (e2: centred on the taller card, RIVALS' size)
		stroke(label(card, mode, FB, 104, 0, 254, 466, 116, WHITE), 3).ZIndex = 4
		-- (2026-10-21, RIVALS pass) a real PLAY bar (PlayScreen's field-green strip, inset as a button): solid fill on an offset
		-- block, no outline; the queue status is written in it (render)
		local shadow = new("Frame", { Name = "PlayShadow", Position = UDim2.fromOffset(17, 486), Size = UDim2.fromOffset(432, 62), BackgroundColor3 = C.fieldDark,
			BorderSizePixel = 0, ZIndex = 4, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		local bar = new("Frame", { Name = "PlayBar", Position = UDim2.fromOffset(17, 480), Size = UDim2.fromOffset(432, 62), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, ZIndex = 5, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		local green = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)), Parent = bar })
		local status = label(bar, "PLAY", Theme.font.chunky, 30, 0, 0, 432, 62, WHITE)
		new("UIStroke", { Color = Color3.fromRGB(28, 44, 16), Thickness = 2, Transparency = 0.3, Parent = status }) -- text outline, not a border
		Kit.bindButton(card, { hover = 1.05, press = 0.97 }) -- (menus e6, grader C: RIVALS' tiles lift further on hover)
		card.Activated:Connect(function()
			local q, st = searching()
			local mq = queueFor(mode)
			if not mq then if ctx.toast then ctx.toast("Ranked " .. mode .. " isn't available yet", "bad") end return end
			if q == mq.Id and st == "Searching" then if ctx.ask then ctx.ask("CancelMatch") end return end
			if q then return end
			local r = ctx.ask and ctx.ask("FindMatch", mq.Id)
			if not (r and r.ok) and ctx.toast then ctx.toast((r and r.msg) or "Couldn't join the ranked queue", "bad") end
		end)
		ui.cards[mode] = { badge = badge, card = card, status = status, edge = edge, bar = bar, green = green, shadow = shadow, stage = stage, i = i }
	end

	-- Warlord strip + leaderboard button
	local wstrip = new("Frame", { Name = "Warlord", Position = UDim2.fromOffset(L, 968), -- (e5: below the 564-tall cards)
		 Size = UDim2.fromOffset(WIDE, 84), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	local wHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(72, 72), Parent = wstrip })
	emblem(wHold, "Warlord")
	ui.warlordCut = label(wstrip, "", FB, 28, 100, 6, 900, 36, WHITE, Enum.TextXAlignment.Left)
	ui.warlordText = label(wstrip, "", FS, 24, 100, 42, 1000, 34, GREY, Enum.TextXAlignment.Left)
	local boardBtn = new("TextButton", { Name = "Leaderboard", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(WIDE - 280, 12), Size = UDim2.fromOffset(260, 60),
		BackgroundColor3 = WHITE, Parent = wstrip }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	label(boardBtn, "Leaderboard", FB, 30, 0, 0, 260, 60, BLACK)

	-- popups (built hidden, converted with the rest)
	local ladder = buildLadder()
	local board = buildBoard()
	Kit.bindButton(ranksBtn, { hover = 1.04, press = 0.97 })
	ranksBtn.Activated:Connect(function() ladder() end)
	Kit.bindButton(ui.infoBtn, { hover = 1.08, press = 0.94 })
	ui.infoBtn.Activated:Connect(function() ladder() end) -- (2026-10-21, round 3) the popups pop in (Kit.open)
	Kit.bindButton(boardBtn, { hover = 1.04, press = 0.97 })
	boardBtn.Activated:Connect(function() fillBoard(); board() end)

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
	Kit.tween(blur, on and 0.25 or 0.12, { Size = on and Theme.blur or 0 }) -- (lobby r29, grader C: on close the dim goes with the panel, 0.12 s)
	Kit.tween(scrim, on and 0.25 or 0.12, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		ui.fill.Size = UDim2.fromScale(0, 1) -- (2026-10-21, round 3) the ELO bar fills up as the screen opens
		ui.eloShown = nil
		render()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
		-- (2026-10-21, round 3: match RIVALS) the mode cards pop in one after another and get their live squads
		local okP, PlayScreen = pcall(require, UIKit:FindFirstChild("PlayScreen"))
		for mode, c in ui.cards do
			Kit.popIn(c.card, 0.06 + c.i * 0.05)
			for _, ch in c.stage:GetChildren() do ch:Destroy() end
			if okP and PlayScreen and PlayScreen.SquadScene then
				pcall(PlayScreen.SquadScene, c.stage, tonumber(mode:match("^(%d)")) or 1, true, c.card)
			end
		end
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
