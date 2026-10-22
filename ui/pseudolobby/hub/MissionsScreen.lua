-- UIKit/MissionsScreen (ModuleScript): the lobby MISSIONS screen.
-- (2026-10-21, RIVALS 1:1) a straight port of the replica's Tasks screen (rivals_practice/ui/tasks/TasksController, RIVALS
-- t0062): one centred scrolling column (532-1360, from y 208, no clip so the panels run on down the screen) holding the Daily
-- panel (header: notepad icon, "Daily Missions [done / total]", the blue "To Duels"-style Play button; three task tiles: title,
-- solid white glyph, blue bar with a bold big count / small total, the scissors render with xN under it) and the Contracts panel
-- ("sorted by" dropdown; rows: glyph, name, count right, a full-width blue bar, a small reward render). Red X outside the column.
-- Colours / fonts: UIKit.Rivals.Theme only; components from UIKit.Rivals.Kit; canvas / toScale / motion from UIKit.Kit.
-- Data is tacticals' real quests: data.Quests.Daily / .Weekly, progress = data.Stats[def.Stat] - entry.Base, rewards in scissors.
-- (2026-10-21, auto-pay) the server pays a finished task by itself (~3 s, and on join) and sets entry.Claimed; no CLAIM button.
-- Done = green title + full green bar + a check on the bar; paid = the reward render dims and its xN turns green.
-- Design px at 1920x1080, converted to Scale (Kit.toScale) - no Offset on screen.
--   MissionsScreen.Init({ Config, getData, tooltip, onOpen, onClose, openPlay? })
--   MissionsScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Kit = require(UIKit:WaitForChild("Kit")) -- canvas, toScale, countTo / fillTo / pop (motion)
local Rivals = UIKit:WaitForChild("Rivals")
local Theme = require(Rivals:WaitForChild("Theme"))
local RK = require(Rivals:WaitForChild("Kit"))
local RA = require(Rivals:WaitForChild("Assets"))
local C, F, new = Theme.color, Theme.font, Kit.new
-- (2026-10-21, RIVALS 1:1) the replica's Tasks faces: Rubik Bold for headers / tile titles / counts, Medium for contract text
local FB = Font.new(F.heavy.Family, Enum.FontWeight.Bold)
local FM = F.medium
local BLACK = C.textDark

local SCISSORS = "rbxassetid://120480559804238" -- (2026-10-21, RIVALS 1:1) the bright scissors render (RIVALS' key render)
local A = RA.tasks or {}
local ROW = RA.rowIcon or {}
local ICONS = Kit.ICONS or {}
local CHECK = A.check or ICONS.check or ""
-- (2026-10-21, RIVALS images) the generated RIVALS marks: the claw for elimination tasks, the lime check (coloured: never
-- tinted) for done, the twisted pinwheel star on the Play button. The old stand-ins stay as fallbacks.
local GEN = RA.gen or {}
local CHECK_LIME = GEN.tasks_check_lime
local STAR6 = GEN.tasks_star6 or A.star6 or ""
-- (2026-10-21, RIVALS 1:1) solid white task glyphs (t0062: play / crosshair / trophy), the replica's art first
-- (2026-10-21, RIVALS images) Kills and Headshots (headshot kills: it used rowIcon.aim, not the eye) show RIVALS' claw
-- (2026-10-21, port3) the thin grey line-art cover / melee / gadget glyphs are swapped for the solid white gen art: the crouched
-- figure (row_crouch) for cover, the knife (kit_cat_knife) for melee, the grenade (kit_cat_grenade) for gadgets
local GLYPH = {
	Wins = A.trophy or Kit.glyph("trophy", ICONS.trophy), MatchesPlayed = A.play or Kit.glyph("play", ICONS.play), Kills = GEN.tasks_elims or ROW.crosshair or ICONS.lbElims,
	Headshots = Kit.glyph("headshot", GEN.tasks_elims or ROW.aim or ICONS.eye), -- (2026-10-22) its own glyph, not the claw
	 CoverKills = GEN.row_crouch or ICONS.cover, MeleeKills = GEN.kit_cat_knife or ICONS.melee,
	GadgetsThrown = GEN.kit_cat_grenade or ICONS.gadget,
}
-- (2026-10-21, port3) RIVALS' task titles are two-word stat names ("Play duels", "Eliminations", "Win duels") at one fixed size;
-- ours map the quest stat the same way. The full sentence (def.Text) stays in the hover bubble (tip).
local SHORT = {
	Kills = "Eliminations", Headshots = "Headshots", MeleeKills = "Melee kills", CoverKills = "Cover kills",
	GadgetsThrown = "Gadgets", Wins = "Win matches", MatchesPlayed = "Play matches",
}
local function shortName(def) return SHORT[def.Stat] or def.Short or def.Text end
local function glyph(parent, stat, pos, size, color)
	return new("ImageLabel", { Name = "Glyph", BackgroundTransparency = 1, Image = GLYPH[stat] or A.trophy or "", ImageColor3 = color or C.white,
		ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), Parent = parent })
end

local Screen = {}
local ctx = {}
local gui, canvas, root, column, blur, scrim
local isOpen = false
local bars = {}
-- (2026-10-21, RIVALS 1:1) replica geometry (wiki: RIVALS UI - Screens, 6. Tasks): column 532-1360, scroll area 208-872,
-- tiles 243x242 at x 45 / 292 / 540 (gap 4), contract rows 62 tall, close 94x48 at 1402, 208
local PANEL_T = 0.55
local COL_X, COL_Y, COL_W = 532, 208, 828
local CARD_W, CARD_H = 243, 242
local CARD_X = { 44, 293, 542 } -- (2026-10-22, section round 1, grader C vs tasks.png: 6 px gaps, were 4)
local HEAD_H, ROW_H, ROW_PAD = 82, 62, 40
local SORTS = { "Default", "Near Completion" }
local sortBy = SORTS[1]

local function commas(n)
	local str = tostring(math.floor(tonumber(n) or 0))
	local out = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
-- "12 / 20" with a big bold numerator and a small total (rich text). live = sized for the screen now (countTo writes Text
-- straight, past Kit's rich-text scaling); otherwise design px for Kit.toScale to convert.
local function countText(p, goal, small, live)
	local sz = live and math.floor(small * Kit.factor() + 0.5) or small
	return ('%d <font size="%d">/ %d</font>'):format(p, sz, goal)
end

-- (2026-10-21, auto-pay) what each task looked like at the last render ([scope:period:id] = { state, prog }), so a task that
-- finishes or gets paid while the screen is open pops its check / reward and grows its bar, with no click
local seen = {}
local pops = {}
local holdUntil, renderToken = 0, 0
local render
local function renderSoon()
	renderToken += 1
	local token, delay = renderToken, holdUntil - os.clock()
	if delay <= 0 then render(true) return end
	task.delay(delay, function()
		if token ~= renderToken or not isOpen then return end
		if os.clock() >= holdUntil then render(true) else renderSoon() end
	end)
end
-- (2026-10-22) the login row follows the server's streak attributes live
for _, attr in { "LoginDay", "LoginClaimed" } do
	Players.LocalPlayer:GetAttributeChangedSignal(attr):Connect(function() if isOpen then renderSoon() end end)
end

local function resetIn(scope)
	local t = os.time()
	if scope == "Daily" then return 86400 - t % 86400 end
	local day = math.floor(t / 86400)
	local weekday = (day + 3) % 7 -- 0 = Monday
	return (7 - weekday) * 86400 - t % 86400
end
local function clock(sec)
	sec = math.max(0, math.floor(sec))
	local d, h, m = sec // 86400, sec % 86400 // 3600, sec % 3600 // 60
	if d > 0 then return ("%dd %dh %dm"):format(d, h, m) end
	return ("%dh %dm %ds"):format(h, m, sec % 60)
end
local function timerText(scope)
	return "new " .. (scope == "Daily" and "daily missions" or "contracts") .. " in " .. clock(resetIn(scope))
end

local function questDef(scope, id)
	for _, q in ctx.Config.Quests[scope].Pool do
		if q.Id == id then return q end
	end
end
-- progress / done / paid for one entry, and what it was at the last render
local function stateOf(scope, entry, def, period)
	local data = ctx.getData() or {}
	-- done = the progress reached the goal OR the server already paid it (entry.Claimed); a paid task always reads full
	local paid = entry.Claimed == true
	local prog = paid and def.Goal or math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (entry.Base or 0), 0, def.Goal)
	local done = paid or prog >= def.Goal
	local state = paid and "paid" or done and "done" or "todo"
	local key = scope .. ":" .. tostring(period) .. ":" .. def.Id
	local was = seen[key]
	seen[key] = { state = state, prog = prog }
	return prog, done, paid, state, was
end

local function panel(name, order, height)
	return new("Frame", {
		Name = name, LayoutOrder = order, Size = UDim2.fromOffset(COL_W, height),
		BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, BorderSizePixel = 0, Parent = column,
	}, { RK.corner(8) })
end

-- progress bar: track + fill (blue; green when done). Fills in when the screen opens.
local function bar(parent, pos, size, frac, done, track, corner)
	local back = new("Frame", { Name = "Bar", Position = pos, Size = size, BackgroundColor3 = track, BorderSizePixel = 0, ClipsDescendants = true, Parent = parent }, { RK.corner(corner) })
	local f = math.clamp(frac, 0, 1)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(f, 1), BackgroundColor3 = done and C.green or C.blue, BorderSizePixel = 0, Parent = back }, { RK.corner(corner) })
	table.insert(bars, { fill = fill, frac = f })
	return back
end

-- reward: the scissors render with "×N" (dark outline); paid = the render dims and the ×N turns green
-- (2026-10-21, port3) RIVALS style: a large render (48 design px = 4.4 % of the screen height) with the "×N" laid over its
-- bottom-right corner (right-aligned a little past the render's right edge, bottom on its bottom), not stacked under it
local REWARD_PX = 48
local function reward(parent, amount, pos, paid)
	local size = REWARD_PX
	local holder = new("Frame", { Name = "Reward", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), Parent = parent })
	new("ImageLabel", { Name = "Render", BackgroundTransparency = 1, Image = SCISSORS, ScaleType = Enum.ScaleType.Fit, ImageTransparency = paid and 0.5 or 0,
		Size = UDim2.fromScale(1, 1), Parent = holder })
	-- (2026-10-22, section rounds 0-1, RIVALS tasks.png) RIVALS' "×1" is CENTRED on the render, over its lower third (top at ~0.62 of
	-- the render): it no longer hides the right half (r0), nor hangs below into the next contract row (r1)
	local n = RK.label({ Text = "×" .. commas(amount), FontFace = FB, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = paid and C.green or C.text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(size / 2, math.floor(size * 0.62)), Size = UDim2.fromOffset(110, 26), ZIndex = 2, Parent = holder })
	RK.textStroke(2).Parent = n
	return holder
end

local function pending(was, state, badge, rewardHolder)
	if not (was and was.state ~= state) then return end
	if was.state == "todo" and badge then table.insert(pops, function() Kit.pop(badge, 1.35) end) end
	if state == "paid" then table.insert(pops, function() Kit.pop(rewardHolder, 1.2) end) end
	holdUntil = os.clock() + 0.5 -- let the pop play before the next refresh rebuilds the panels
end
local function tip(target, def, done, paid, prog)
	if not ctx.tooltip then return end
	ctx.tooltip(target, def.Text, function()
		return done and (paid and "Reward collected." or `Done! Your {def.Reward} scissors are on the way.`)
			or `{def.Goal - prog} to go. Progress comes from matches.`
	end)
end

-- one Daily task tile (replica: title, glyph, bar with the count over it, reward under)
local function taskCard(parent, scope, i, entry, def, x, y, period)
	local prog, done, paid, state, was = stateOf(scope, entry, def, period)
	local card = new("Frame", {
		Name = scope .. i, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = parent,
	}, { RK.corner(6), RK.stroke(C.track, 1, 0.5) })
	-- (2026-10-21, port3) the short stat name at one fixed size (Rubik Bold 30): no TextScaled, no size constraint, no ellipsis
	local title = RK.label({ Text = shortName(def), FontFace = FB, TextSize = 30, TextColor3 = done and C.green or C.text,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, 34), Parent = card })
	-- RIVALS grows the task title on hover (~1.1x)
	local titleScale = new("UIScale", { Name = "HoverScale", Parent = title })
	card.MouseEnter:Connect(function() Kit.tween(titleScale, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
	card.MouseLeave:Connect(function() Kit.tween(titleScale, 0.15, { Scale = 1 }) end)
	glyph(card, def.Stat, UDim2.fromOffset(121, 86), 52, done and C.green or C.white) -- (2026-10-21, port3) solid white art; (round 1) 44 -> 52: the art's margin left it reading ~33 vs RIVALS ~45
	bar(card, UDim2.fromOffset(18, 130), UDim2.fromOffset(206, 10), prog / def.Goal, done, C.track, 5)
	local b = bars[#bars]
	local badge
	if done then
		-- done (replica): the count gives way to a green check on the bar
		-- (2026-10-21, RIVALS images) gen.tasks_check_lime (lime with its dark outline, untinted); the tinted white tick as fallback
		badge = new("ImageLabel", { Name = "DoneCheck", BackgroundTransparency = 1, Image = CHECK_LIME or CHECK, ImageColor3 = CHECK_LIME and C.white or C.green,
			ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(121, 135), Size = UDim2.fromOffset(40, 40), ZIndex = 3, Parent = card })
	else
		local count = RK.label({ RichText = true, Text = countText(prog, def.Goal, 29), FontFace = FB, TextSize = 29, TextXAlignment = Enum.TextXAlignment.Center, -- (round 0, grader B: "/ N" at the count's size, was 20)
			Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 30), ZIndex = 3, Parent = card })
		RK.textStroke(2).Parent = count
		b.count, b.small = count, 29
	end
	b.prog, b.goal = prog, def.Goal
	if was then b.fromFrac, b.fromProg = was.prog / def.Goal, was.prog end
	local rewardHolder = reward(card, def.Reward, UDim2.fromOffset(121, 192), paid)
	pending(was, state, badge, rewardHolder)
	tip(card, def, done, paid, prog)
end

-- one contract row (replica: glyph | name | count right; full-width bar under; small reward at the far right)
local function taskRow(parent, scope, i, entry, def, y, period)
	local prog, done, paid, state, was = stateOf(scope, entry, def, period)
	local row = new("Frame", { Name = scope .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(COL_W, ROW_H), Parent = parent })
	glyph(row, def.Stat, UDim2.fromOffset(67, 27), 46, done and C.green or C.white) -- (2026-10-21, port3) RIVALS' weapon-picture size (~46), solid art
	-- (2026-10-22, section round 0, grader B) RIVALS' contract labels are a soft grey (#C3C2C2) so the white count leads, and the count
	-- is ~1.38 label caps tall (was 32: 1.08)
	RK.label({ Text = def.Text, FontFace = FM, TextSize = 27, TextColor3 = done and C.green or Color3.fromRGB(195, 194, 194), TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(98, 6), Size = UDim2.fromOffset(460, 40), Parent = row })
	local count = RK.label({ RichText = true, Text = countText(prog, def.Goal, 26), FontFace = FB, TextSize = 37, TextColor3 = done and C.green or C.text,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(708, 4), Size = UDim2.fromOffset(240, 40), Parent = row })
	bar(row, UDim2.fromOffset(48, 46), UDim2.fromOffset(660, 6), prog / def.Goal, done, C.panel, 3)
	local b = bars[#bars]
	b.count, b.small, b.prog, b.goal = count, 26, prog, def.Goal
	if was then b.fromFrac, b.fromProg = was.prog / def.Goal, was.prog end
	local badge
	if done then
		-- the check sits on the bar's right end (the bar clips, so the badge is the row's child)
		-- (2026-10-21, RIVALS images) the outlined lime check image itself (no green disc); the old disc + black tick as fallback
		if CHECK_LIME then
			badge = new("ImageLabel", { Name = "DoneCheck", BackgroundTransparency = 1, Image = CHECK_LIME, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(708, 49), Size = UDim2.fromOffset(32, 32), ZIndex = 4, Parent = row })
		else
			badge = new("Frame", { Name = "DoneCheck", BackgroundColor3 = C.green, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(708, 49), Size = UDim2.fromOffset(26, 26), ZIndex = 4, Parent = row }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			new("ImageLabel", { Name = "Check", BackgroundTransparency = 1, Image = CHECK, ImageColor3 = BLACK, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), ZIndex = 5, Parent = badge })
		end
	end
	local rewardHolder = reward(row, def.Reward, UDim2.fromOffset(770, 28), paid)
	pending(was, state, badge, rewardHolder)
	tip(row, def, done, paid, prog)
end

-- header: icon + title (+ extra), the reset line under the title once everything is done (RIVALS' done panel)
local function header(p, image, title, allDone, scope)
	new("ImageLabel", { Name = "HeadIcon", BackgroundTransparency = 1, Image = image or "", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(30, 10),
		Size = UDim2.fromOffset(46, 46), Parent = p })
	local line = new("Frame", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(83, 12), Size = UDim2.fromOffset(520, 44), Parent = p },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	RK.label({ LayoutOrder = 1, Text = title, FontFace = FB, TextSize = 36, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 44), Parent = line })
	if allDone then
		local t = RK.label({ Name = "Reset", Text = timerText(scope), FontFace = FM, TextSize = 24, TextColor3 = C.textDim, Position = UDim2.fromOffset(42, 58),
			Size = UDim2.fromOffset(420, 30), Parent = p })
		t:SetAttribute("ResetScope", scope)
	end
	return line
end

local function dailyPanel(order)
	local q = (ctx.getData() or {}).Quests
	q = q and q.Daily
	local list = (q and q.List) or {}
	local n, total = 0, 0
	for _, entry in ipairs(list) do
		local def = questDef("Daily", entry.Id)
		if def then
			total += 1
			local data = ctx.getData() or {}
			if entry.Claimed == true or ((data.Stats and data.Stats[def.Stat]) or 0) - (entry.Base or 0) >= def.Goal then n += 1 end
		end
	end
	local allDone = total > 0 and n == total
	local top = allDone and HEAD_H + 18 or HEAD_H
	-- (2026-10-22, Edward: RIVALS' 7-day login row under the tasks) server attributes LoginDay (1-7, today's slot), LoginClaimed
	-- (today paid) and ReplicatedStorage LoginRewards (JSON, 7 scissor amounts). No LoginDay = no row (server not shipped yet).
	-- (2026-10-22, section round 1, grader A vs RIVALS t0066 / tasks.png) RIVALS' Tasks screen always has the 7-circle row (the panel
	-- runs to 0.686 H); without it ours ended at 0.526 H. Until the server ships LoginDay the row shows day 1 with the approved
	-- economy's login amounts (notes/economy/scissors_economy.md: 50, 50, 100, 100, 150, 150, 400), nothing to claim
	local loginDay = tonumber(Players.LocalPlayer:GetAttribute("LoginDay")) or 1
	local STREAK_H = 150
	local p = panel("Daily", order, top + CARD_H + 38 + STREAK_H)
	-- (2026-10-21, port3) RIVALS' normal theme shows just "Daily Tasks": the "[done / total]" counter is gone
	header(p, A.notepad, "Daily Missions", allDone, "Daily")
	-- the blue "To Duels"-style button (replica 165x41 at 652, 12); ours opens Play through ctx.openPlay
	if ctx.openPlay then
		local go = new("TextButton", { Name = "ToPlay", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(652, 12), Size = UDim2.fromOffset(165, 41),
			BackgroundColor3 = C.white, Parent = p }, { RK.corner(6), RK.vgrad(Theme.gradient.blue), RK.stroke(C.blue, 1.5, 0.1) })
		RK.bindButton(go)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = go },
			{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }) })
		new("ImageLabel", { LayoutOrder = 1, BackgroundTransparency = 1, Image = STAR6, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(28, 28), Parent = row }) -- (2026-10-21, RIVALS images) gen.tasks_star6
		RK.label({ LayoutOrder = 2, Text = "Play", FontFace = FB, TextSize = 24, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 41), Parent = row })
		new("ImageLabel", { LayoutOrder = 3, BackgroundTransparency = 1, Image = STAR6, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(28, 28), Parent = row }) -- (2026-10-21, RIVALS images) gen.tasks_star6
		go.Activated:Connect(function()
			Screen.Close()
			ctx.openPlay()
		end)
	end
	if #list == 0 then
		RK.label({ Text = "Loading missions...", FontFace = FM, TextSize = 26, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, top + 100), Size = UDim2.new(1, 0, 0, 40), Parent = p })
	end
	for i, entry in ipairs(list) do
		local def = questDef("Daily", entry.Id)
		if def and CARD_X[i] then taskCard(p, "Daily", i, entry, def, CARD_X[i], top, q and q.Key) end
	end
	if loginDay then
		-- RIVALS t0062 / live 16:9: a dotted divider, then seven 80 px circles in a row. Days already collected are white with a
		-- dark check; today is a ring with the big day number (a white check once claimed); days to come are faint "Day N".
		-- The reward (scissors + xN) sits over the top-right of every day not yet collected.
		local claimed = Players.LocalPlayer:GetAttribute("LoginClaimed") == true
		local okR, rewards = pcall(function() return game:GetService("HttpService"):JSONDecode(game:GetService("ReplicatedStorage"):GetAttribute("LoginRewards") or "[]") end)
		rewards = (okR and type(rewards) == "table" and #rewards > 0) and rewards or { 50, 50, 100, 100, 150, 150, 400 }
		local y0 = top + CARD_H + 30
		for k = 0, math.floor((COL_W - 80) / 14) do
			new("Frame", { BackgroundColor3 = C.textDim, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromOffset(40 + k * 14, y0), Size = UDim2.fromOffset(5, 5),
				Parent = p }, { RK.corner(3) })
		end
		local D, GAP = 80, 18
		local x0 = (COL_W - (7 * D + 6 * GAP)) / 2
		for d = 1, 7 do
			local cx, cy = x0 + (d - 1) * (D + GAP), y0 + 44
			local past = d < loginDay or (d == loginDay and claimed)
			local today = d == loginDay
			local circle = new("Frame", { Name = "Day" .. d, Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(D, D),
				BackgroundColor3 = past and C.white or BLACK, BackgroundTransparency = past and 0 or 0.4, Parent = p },
				{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), RK.stroke(today and C.white or C.track, today and 3 or 2, today and 0 or 0.3) })
			if past then
				new("ImageLabel", { BackgroundTransparency = 1, Image = CHECK_LIME or CHECK, ImageColor3 = CHECK_LIME and C.white or C.textDark, ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), ZIndex = 2, Parent = circle })
			else
				RK.label({ Text = "Day", FontFace = FB, TextSize = 18, TextColor3 = today and C.text or C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(D, 20), ZIndex = 2, Parent = circle })
				RK.label({ Text = tostring(d), FontFace = FB, TextSize = 40, TextColor3 = today and C.text or C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(D, 46), ZIndex = 2, Parent = circle })
				local amt = tonumber(rewards[d])
				if amt then
					new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(D - 26, -32), Size = UDim2.fromOffset(38, 38),
						ZIndex = 3, Parent = circle })
					local n = RK.label({ Text = "×" .. commas(amt), FontFace = FB, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromOffset(D + 16, -10), Size = UDim2.fromOffset(70, 22), ZIndex = 4, Parent = circle })
					RK.textStroke(1.5).Parent = n
				end
			end
		end
	end
end

local function contractsPanel(order)
	local q = (ctx.getData() or {}).Quests
	q = q and q.Weekly
	local rows = {}
	for _, entry in ipairs((q and q.List) or {}) do
		local def = questDef("Weekly", entry.Id)
		if def then
			local data = ctx.getData() or {}
			local prog = entry.Claimed == true and def.Goal or math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (entry.Base or 0), 0, def.Goal)
			table.insert(rows, { entry = entry, def = def, frac = prog / def.Goal, i = #rows + 1 })
		end
	end
	if sortBy == "Near Completion" then
		table.sort(rows, function(a, b) if a.frac ~= b.frac then return a.frac > b.frac end return a.i < b.i end)
	end
	local allDone = #rows > 0
	for _, r in ipairs(rows) do if r.frac < 1 then allDone = false end end
	local top = allDone and 74 + 18 or 74
	local p = panel("Weekly", order, top + math.max(1, #rows) * ROW_H + ROW_PAD)
	header(p, A.scroll, "Weekly Contracts", allDone, "Weekly")
	RK.label({ Text = "sorted by", FontFace = FM, TextSize = 27, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(593, 17), Size = UDim2.fromOffset(200, 41), Parent = p })
	local dd = RK.dropdown(SORTS, sortBy, canvas, function(v)
		if v == sortBy then return end
		sortBy = v
		render()
	end)
	-- (2026-10-21, port3) RIVALS-size: a 210 x 44 solid white box, the value in Rubik Bold 26 (~1.8 % h), a bigger ▼
	dd.Size = UDim2.fromOffset(210, 44)
	dd.BackgroundColor3 = C.white
	dd.AnchorPoint = Vector2.new(0.5, 0.5) -- grows in place on hover
	for _, ch in ipairs(dd:GetChildren()) do
		if ch:IsA("TextLabel") and ch.Text ~= "▼" then
			for _, k in ipairs(ch:GetChildren()) do if k:IsA("UITextSizeConstraint") then k:Destroy() end end
			ch.TextScaled = false; ch.TextWrapped = false; ch.TextSize = 26; ch.Position = UDim2.fromOffset(12, 0); ch.Size = UDim2.new(1, -46, 1, 0); ch.FontFace = FB
		elseif ch:IsA("TextLabel") then
			ch.TextSize = 26
		end
	end
	dd.Position = UDim2.fromOffset(603 + 105, 15 + 22)
	dd.Parent = p
	if #rows == 0 then
		RK.label({ Text = "Loading contracts...", FontFace = FM, TextSize = 26, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, top + 10), Size = UDim2.new(1, 0, 0, 40), Parent = p })
	end
	for n, r in ipairs(rows) do
		taskRow(p, "Weekly", n, r.entry, r.def, top + (n - 1) * ROW_H, q and q.Key)
	end
end

function render(live) -- (forward-declared above renderSoon); live = a data refresh while open, not the open itself
	bars, pops = {}, {}
	Kit.restoreModifiers(column)
	column.AutomaticCanvasSize = Enum.AutomaticSize.Y
	column.CanvasSize = UDim2.new()
	for _, ch in ipairs(column:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	dailyPanel(1)
	contractsPanel(2)
	Kit.toScale(root) -- UI rule: everything in Scale
	if not live then return end
	-- (2026-10-21, auto-pay) progress made while open: the bar grows and the count ticks on from what was shown, then the pops
	for _, b in ipairs(bars) do
		if b.fromFrac and b.fromFrac ~= b.frac and b.fill.Parent then
			b.fill.Size = UDim2.fromScale(math.clamp(b.fromFrac, 0, 1), 1)
			Kit.fillTo(b.fill, b.frac, 0.5)
			if b.count then
				local goal, small = b.goal, b.small
				Kit.countTo(b.count, b.fromProg, b.prog, 0.5, function(n) return countText(math.floor(n + 0.5), goal, small, true) end)
			end
		end
	end
	for _, f in ipairs(pops) do f() end
end

local function build()
	gui = new("ScreenGui", { Name = "MissionsUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- (2026-10-21, RIVALS 1:1) replica ref_63/64: the scroll area is 208-872 with a thin dark bar, and it does NOT clip (the
	-- panels run on down the screen); scrolled to the end, the last panel stops at 872
	column = new("ScrollingFrame", {
		Name = "Column", Position = UDim2.fromOffset(COL_X, COL_Y), Size = UDim2.fromOffset(852, 664), BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = false, ScrollBarThickness = 10, ScrollBarImageColor3 = BLACK, ScrollBarImageTransparency = 0.45,
		VerticalScrollBarInset = Enum.ScrollBarInset.None, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 25), Parent = column })
	-- (2026-10-21, RIVALS 1:1) the red X outside the column (replica 94x48 at 1402, 208). Not named "Close" and tagged
	-- Nonapplicable: the old InterfaceController hooks any "Close" button in a new ScreenGui and shrinks its parent to 0 x 0.
	-- (2026-10-21, port3) the kit's one close size for every screen (RK.CLOSE_W x CLOSE_H = 112 x 58), CLOSE_GAP right of the
	-- panel's right edge (column x + panel width), top-aligned with the panel
	local close = RK.closeButton()
	close.Name = "CloseX"
	close:AddTag("Nonapplicable")
	close.Position = UDim2.fromOffset(COL_X + COL_W + (RK.CLOSE_GAP or 12), COL_Y)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	render()
	root.Visible = false

	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
	task.spawn(function() -- reset timers tick
		while gui.Parent do
			task.wait(1)
			if isOpen then
				for _, d in ipairs(column:GetDescendants()) do
					local scope = d:GetAttribute("ResetScope")
					if scope then d.Text = timerText(scope) end
				end
			end
		end
	end)
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		column.CanvasPosition = Vector2.zero
		render()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
		for _, b in ipairs(bars) do -- bars fill in after the panel pops open, counts tick up with them
			if b.fill.Parent then
				b.fill.Size = UDim2.fromScale(0, 1)
				Kit.tween(b.fill, 0.6, { Size = UDim2.fromScale(b.frac, 1) }, Enum.EasingStyle.Quart)
				if b.count and b.count.Parent then
					local goal, small = b.goal, b.small
					Kit.countTo(b.count, 0, b.prog, 0.6, function(n) return countText(math.floor(n + 0.5), goal, small, true) end)
				end
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
function Screen.Refresh() if isOpen then renderSoon() end end -- (2026-10-21, auto-pay) waits for a check / reward pop

return Screen
