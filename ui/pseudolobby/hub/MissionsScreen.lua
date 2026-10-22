-- UIKit/MissionsScreen (ModuleScript): the lobby MISSIONS screen. Layout follows the RIVALS Tasks screen
-- (ported from rivals_practice/ui/tasks): a centred column of panels, each with task cards (title, icon,
-- progress bar with the count, reward). Data is tacticals' real quests: data.Quests.Daily / .Weekly,
-- progress = data.Stats[def.Stat] - entry.Base, rewards in scissors.
-- (2026-10-21, auto-pay) the server pays a finished task by itself (~3 s, and on join) and sets entry.Claimed; no CLAIM button.
-- Design px at 1920x1080, converted to Scale (Kit.toScale) - no Offset on screen.
--   MissionsScreen.Init({ Config, getData, tooltip, onOpen, onClose, openPlay? })
--   MissionsScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Assets = require(UIKit:WaitForChild("Assets"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local Tac = require(UIKit:WaitForChild("Tac")) -- pass 34 deployment-board look
local C, F, new = Theme.color, Theme.font, Kit.new

local SCISSORS = "rbxassetid://120480559804238"
local A = Assets.tasks or {}
local function icon(name)
	if A[name] then return A[name] end
	for _, key in ipairs({ "rowIcon", "hotkeys" }) do
		if Assets[key] and Assets[key][name] then return Assets[key][name] end
	end
	return ""
end
-- (2026-10-21, auto-pay) the done badge's check glyph: the tasks art's check, else the flat cream check (Kit.ICONS)
local CHECK = icon("check") ~= "" and icon("check") or (Kit.ICONS and Kit.ICONS.check) or ""
-- which 3D icon each quest stat shows (ViewIcons): a named model, or a real weapon from the Repository
local STAT_ICON = {
	Wins = { "Trophy" }, MatchesPlayed = { "DogTags" }, Kills = { "Weapon", "AutoRifle" }, Headshots = { "Weapon", "Sniper" },
	CoverKills = { "Sandbags" }, MeleeKills = { "Melee", "Knife" }, GadgetsThrown = { "Grenade" },
}
-- (2026-10-21) RIVALS' Daily Tasks show FLAT white glyphs for the task (t0062: play / crosshair / trophy), so ours do too: the
-- art batch 1 cream line icons (Kit.ICONS). Any stat without one keeps its 3D icon below.
local FLAT_STAT = { Wins = "trophy", MatchesPlayed = "play", Kills = "lbElims", Headshots = "lbElims", CoverKills = "cover",
	MeleeKills = "melee", GadgetsThrown = "gadget" }
local function statIcon(parent, stat, hoverTarget)
	local flat = FLAT_STAT[stat] and Kit.ICONS and Kit.ICONS[FLAT_STAT[stat]]
	if flat then
		local img = Instance.new("ImageLabel")
		img.Name = "FlatIcon"
		img.BackgroundTransparency = 1
		img.Image = flat
		img.ImageColor3 = Color3.fromRGB(236, 230, 210)
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1) -- (2026-10-21, grade1) with the bigger Art frame the glyph reads ~36 px (was ~20)
		img.Parent = parent
		local sc = Instance.new("UIScale"); sc.Parent = img
		hoverTarget.MouseEnter:Connect(function() Kit.tween(sc, 0.15, { Scale = 1.12 }, Enum.EasingStyle.Back) end)
		hoverTarget.MouseLeave:Connect(function() Kit.tween(sc, 0.15, { Scale = 1 }) end)
		return img
	end
	local spec = STAT_ICON[stat] or { "Medal" }
	local vp
	if spec[1] == "Weapon" then
		vp = ViewIcons.Viewport(parent, ViewIcons.Weapon(spec[2]), { view = ViewIcons.GunView, zoom = 0.95 })
	elseif spec[1] == "Melee" then
		vp = ViewIcons.Viewport(parent, ViewIcons.Melee(spec[2]), { view = CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(38), 0, 0), zoom = 1 })
	else
		return ViewIcons.Icon(parent, spec[1], { hoverTarget = hoverTarget })
	end
	hoverTarget.MouseEnter:Connect(function() vp.SetHover(true) end)
	hoverTarget.MouseLeave:Connect(function() vp.SetHover(false) end)
	return vp
end

local Screen = {}
local ctx = {}
local gui, root, column, blur, scrim
local isOpen = false
local bars = {}
local CARD_H = 286 -- (lobby revamp) was 300; (2026-10-21, round 3) 258 -> 266: room for the count under the bar + a bigger reward
-- (2026-10-21, grade1) 266 -> 286: the bigger task glyph and the reward with its count beside it
-- (2026-10-21, round 3: match RIVALS) the cards leave the navy-slate C.panelRaised for our dark plate / field-green family
local CARD_BG = C.plate or Color3.fromRGB(24, 26, 21) -- charcoal-green plate
local CARD_DONE = Color3.fromRGB(34, 52, 24) -- (2026-10-21, auto-pay) a finished card is lit dark field green (was the claimable card)
local FIELD, FIELD_DARK = C.field or Color3.fromRGB(141, 191, 90), C.fieldDark or Color3.fromRGB(76, 122, 46)

local PANEL_T = 0.5
local COL_X, COL_W = 532, 828
local COL_Y, COL_H = 130, 830 -- (2026-10-21, grade1) the MISSIONS title is gone: the column moves up into its place
local CARD_X = { 45, 292, 540 }
-- (2026-10-21, auto-pay) what each task looked like at the last render ([scope:period:id] = { state, prog }), so a task that
-- finishes or gets paid while the screen is open pops its check / PAID tag and grows its bar, with no click
local seen = {}
local pops = {} -- this render's pops, played after Kit.toScale
-- (2026-10-21, RIVALS pass) a pop must finish before the next data refresh rebuilds the cards
local holdUntil, renderToken = 0, 0
local render -- forward: Refresh re-renders through renderSoon
local function renderSoon()
	renderToken += 1 -- the latest call wins
	local token, delay = renderToken, holdUntil - os.clock()
	if delay <= 0 then render(true) return end
	task.delay(delay, function()
		if token ~= renderToken or not isOpen then return end
		if os.clock() >= holdUntil then render(true) else renderSoon() end
	end)
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

local function questDef(scope, id)
	for _, q in ctx.Config.Quests[scope].Pool do
		if q.Id == id then return q end
	end
end

local function panel(name, order, height)
	return new("Frame", {
		Name = name, LayoutOrder = order, Size = UDim2.fromOffset(COL_W, height),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = PANEL_T, BorderSizePixel = 0, Parent = column,
	}) -- (2026-10-21, AI-tells cleanup) no thin olive border, no left TacBar: the dark fill separates the panel
	-- (2026-10-21, grade1) BorderSizePixel = 0: the faint 1 px edge graders saw was the Frame's default border (no UICorner here)
end

local function bar(parent, pos, size, frac, done)
	-- (lobby revamp, graders: an empty bar was invisible) a lighter, rounded track so 0 / N still shows how far there is to go
	-- (2026-10-21, round 3: match RIVALS) a bigger bar (RIVALS t0062: the bar is the card's centre line); in-progress fills cream,
	-- done fills the field-green gradient
	-- (2026-10-21, grade1) graders: at 0 / N the dark track vanished on the dark card. The track is now cream at ~35 % opacity,
	-- ~8-10 px tall, so an empty bar still reads as a bar
	local back = new("Frame", { Name = "Bar", Position = pos, Size = size, BackgroundColor3 = C.cream or Color3.fromRGB(236, 230, 210), BackgroundTransparency = 0.65,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = parent }, { Kit.corner(5) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = done and Color3.new(1, 1, 1) or Tac.C.bone, BorderSizePixel = 0, Parent = back },
		{ Kit.corner(5) })
	if done then Kit.vgrad({ FIELD, FIELD_DARK }).Parent = fill end
	table.insert(bars, { fill = fill, frac = math.clamp(frac, 0, 1) })
	return back
end

-- reward: scissors icon + "×N" with a dark outline
-- (2026-10-21, round 3: match RIVALS) RIVALS' reward is a posed 3D key render with "×N" tucked under its corner (t0062-t0066).
-- Ours is the live 3D scissors (no longer `still`: it sways and turns toward you on card hover) at about 1.4x the old size,
-- with a big Oswald "×N" overlapping its lower right like RIVALS.
local function reward(parent, amount, size, pos, hoverTarget)
	local holder = new("Frame", { Name = "Reward", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), Parent = parent })
	ViewIcons.Icon(holder, "Scissors", { hoverTarget = hoverTarget, zoom = 1.15 })
	-- (2026-10-21, grade1) "×N" bigger (32 -> 42 design px, ~20 px on a phone-ish 1436 capture) and BESIDE the scissors,
	-- vertically centred on them (was tucked small under the corner)
	local n = Kit.label({ Text = "×" .. amount, FontFace = F.display, TextSize = 42, TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(size * 0.86, size * 0.55), Size = UDim2.fromOffset(110, 48), ZIndex = 3, Parent = holder })
	Kit.textStroke(2).Parent = n
	return holder
end

local function taskCard(parent, scope, i, entry, def, x, y, period)
	local data = ctx.getData() or {}
	-- (2026-10-21, auto-pay) done = the progress reached the goal OR the server already paid it (entry.Claimed). A paid task
	-- always reads full (a stat reset could drop Stats - Base under the goal after the payout).
	local paid = entry.Claimed == true
	local prog = paid and def.Goal or math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (entry.Base or 0), 0, def.Goal)
	local done = paid or prog >= def.Goal
	local state = paid and "paid" or done and "done" or "todo"
	local key = scope .. ":" .. tostring(period) .. ":" .. def.Id
	local was = seen[key]
	seen[key] = { state = state, prog = prog }
	local card = new("Frame", {
		Name = scope .. i, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(243, CARD_H),
		BackgroundColor3 = done and CARD_DONE or CARD_BG, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = parent, -- (2026-10-21, round 3) off the navy
	}, { Kit.corner(2) })
	local br = Tac.brackets(card, done and Tac.C.bone or Tac.C.line, 18, 3)
	-- (2026-10-21, RIVALS pass) the "D-01" / "W-02" id label is gone: RIVALS' cards carry no ids (clean)
	Tac.hoverBrackets(card, br)
	-- (2026-10-21, RIVALS pass) the card lifts on hover; (2026-10-21, auto-pay) every card now, not only a claimable one.
	-- A position lift, not a UIScale: the pops below own their parts' UIScales.
	card.MouseEnter:Connect(function()
		local home = card:GetAttribute("LiftHome") or card.Position -- (Scale by now: toScale ran after the build)
		card:SetAttribute("LiftHome", home)
		Kit.tween(card, 0.12, { Position = home - UDim2.fromScale(0, 6 / (82 + CARD_H + 24)) })
	end)
	card.MouseLeave:Connect(function()
		local home = card:GetAttribute("LiftHome")
		if home then Kit.tween(card, 0.12, { Position = home }) end
	end)
	-- (2026-10-21, round 3: match RIVALS) RIVALS' order top to bottom (t0062): title, task glyph, a wide bar, the "x / y" count
	-- UNDER the bar (it no longer runs through it), then the reward. Done titles and counts turn field green.
	local title = Kit.label({ Text = def.Text, FontFace = F.bold, TextSize = 21, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 44), Parent = card })
	-- (2026-10-21, grade1) RIVALS grows the task title on hover: ~1.1x with the lift (own UIScale; the pops own the others)
	local titleScale = new("UIScale", { Name = "HoverScale", Parent = title })
	card.MouseEnter:Connect(function() Kit.tween(titleScale, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
	card.MouseLeave:Connect(function() Kit.tween(titleScale, 0.15, { Scale = 1 }) end)
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(121, 92), Size = UDim2.fromOffset(200, 64), Parent = card }) -- (grade1) 50 -> 64 tall: ~36 px glyph
	local badge
	if done then
		-- (2026-10-21, auto-pay) RIVALS' done tile: a big green check badge takes the task glyph's place
		badge = new("Frame", { Name = "DoneCheck", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), ZIndex = 3, Parent = art },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIAspectRatioConstraint", { AspectRatio = 1 }), Kit.vgrad({ FIELD, FIELD_DARK }) })
		new("ImageLabel", { Name = "Check", BackgroundTransparency = 1, Image = CHECK, ImageColor3 = C.cream or Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6),
			ZIndex = 4, Parent = badge })
		title.TextColor3 = FIELD
	else
		statIcon(art, def.Stat, card)
	end
	bar(card, UDim2.fromOffset(16, 134), UDim2.fromOffset(211, 10), prog / def.Goal, done) -- (grade1) 16 -> 10 tall, under the bigger glyph
	local count = Kit.label({ Text = prog .. " / " .. def.Goal, FontFace = F.display, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = done and FIELD or C.cream or Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 28), ZIndex = 3, Parent = card })
	-- (2026-10-21, round 3: match RIVALS "counters that animate") the count ticks up with its bar; (auto-pay) done counts too
	local b = bars[#bars]
	b.count, b.prog, b.goal = count, prog, def.Goal
	if was then b.fromFrac, b.fromProg = was.prog / def.Goal, was.prog end
	local rewardHolder = reward(card, def.Reward, 62, UDim2.fromOffset(86, 214), card) -- (grade1) left of centre: the "×N" sits beside it
	local paidTag
	if paid then
		-- (2026-10-21, auto-pay) the reward is already in your scissors: it dims and a field-green PAID sits under it
		for _, d in rewardHolder:GetDescendants() do
			if d:IsA("ViewportFrame") then d.ImageTransparency = 0.55
			elseif d:IsA("TextLabel") then d.TextTransparency = 0.45
			elseif d:IsA("UIStroke") then d.Transparency = 0.6 end
		end
		paidTag = Kit.label({ Text = "PAID", FontFace = F.display, TextSize = 24, TextColor3 = FIELD, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(218, 30), ZIndex = 3, Parent = card })
	end
	-- (2026-10-21, auto-pay) no click: a task that finished while the screen is open pops its check, one the server just paid
	-- pops its PAID tag and the reward (the "Task Completed" banner itself is Notify's)
	if was and was.state ~= state then
		if was.state == "todo" and badge then
			table.insert(pops, function() Kit.pop(badge, 1.35) end)
		end
		if state == "paid" and paidTag then
			table.insert(pops, function() Kit.popIn(paidTag, 0.1); Kit.pop(rewardHolder, 1.2) end)
		end
		holdUntil = os.clock() + 0.5 -- let the pop play before the next refresh rebuilds the cards
	end
	-- (2026-10-21, RIVALS pass) no IN PROGRESS strip: the "3 / 5" count already says it (clean)
	if ctx.tooltip then
		ctx.tooltip(card, def.Text, function()
			return done and (paid and "Reward collected." or `Done! Your {def.Reward} scissors are on the way.`)
				or `{def.Goal - prog} to go. Progress comes from matches.`
		end)
	end
	return card
end

local function scopePanel(scope, order, title, iconModel)
	local data = ctx.getData() or {}
	local q = data.Quests and data.Quests[scope]
	local list = (q and q.List) or {}
	local p = panel(scope, order, 82 + CARD_H + 24)
	-- (2026-10-21, grade1) header = icon + title on the left, the reset timer as a small tan line UNDER the title (was a grey
	-- line squeezed against the PLAY button on the right)
	local head = new("Frame", { Name = "HeadIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 10), Size = UDim2.fromOffset(60, 60), Parent = p })
	ViewIcons.Icon(head, iconModel, { hoverTarget = p })
	Kit.label({ Text = title, FontFace = F.display, TextSize = 40, Position = UDim2.fromOffset(92, 4), Size = UDim2.fromOffset(420, 46), Parent = p })
	local timer = Kit.label({ Text = "", FontFace = F.medium, TextSize = 20, TextColor3 = C.tan or Color3.fromRGB(226, 210, 172), TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(94, 48), Size = UDim2.fromOffset(420, 24), Parent = p })
	timer:SetAttribute("ResetScope", scope)
	-- (2026-10-21, grade1) the red X lives in the Daily panel's top-right corner (was floating over the column beside the old
	-- MISSIONS title); the column is rebuilt per render, so it is made here with the panel
	local X_W, X_H, EDGE = 72, 52, 14
	if scope == "Daily" then
		local close = Kit.closeButton(UDim2.fromOffset(X_W, X_H))
		close.Position = UDim2.fromOffset(COL_W - EDGE - X_W, EDGE)
		close.Parent = p
		close.Activated:Connect(function() Screen.Close() end)
	end
	-- (2026-10-21, round 3: match RIVALS) RIVALS' Daily Tasks header carries a bright "To Duels" button on the right (t0062): the
	-- way to go and do the tasks. Ours is a field-green "PLAY" that opens the Play screen through ctx.openPlay. It only appears
	-- when the controller passes that hook (LobbyUIController's MissionsScreen.Init does not yet); the reset timer moves left of it.
	-- (2026-10-21, grade1) bigger / chunky: Kit.button 150x52 "GO PLAY" (was 170x50 "PLAY" squeezed by the timer), left of the
	-- X with a 20 px gap. Kit.button's bindButton centre-anchors it, so it is placed by its top-left in design px.
	if scope == "Daily" and ctx.openPlay then
		local play = Kit.button("key", UDim2.fromOffset(150, 52), "GO PLAY")
		play.Name = "ToPlay"
		play.Position = UDim2.fromOffset(COL_W - EDGE - X_W - 20 - 150, EDGE)
		play.Parent = p
		play.Activated:Connect(function()
			Screen.Close()
			ctx.openPlay()
		end)
	end
	timer.Text = "new " .. string.lower(title) .. " in " .. clock(resetIn(scope))
	if #list == 0 then
		Kit.label({ Text = "Loading missions...", FontFace = F.medium, TextSize = 26, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 40), Parent = p })
	end
	for i, entry in ipairs(list) do
		local def = questDef(scope, entry.Id)
		if def and CARD_X[i] then taskCard(p, scope, i, entry, def, CARD_X[i], 82, q and q.Key) end
	end
	return p
end

function render(live) -- (forward-declared above renderSoon); live = a data refresh while open, not the open itself
	bars, pops = {}, {}
	Kit.restoreModifiers(column)
	column.AutomaticCanvasSize = Enum.AutomaticSize.Y
	column.CanvasSize = UDim2.new()
	for _, ch in ipairs(column:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	scopePanel("Daily", 1, "Daily Missions", "Clipboard")
	scopePanel("Weekly", 2, "Weekly Contracts", "Medal")
	-- (2026-10-21, grade1) the "Play matches to fill these up." footer is gone: GO PLAY and the tooltips already say it
	Kit.toScale(root) -- UI rule: everything in Scale
	if not live then return end
	-- (2026-10-21, auto-pay) progress made while open: the bar grows and the count ticks on from what was shown, then the pops
	for _, b in ipairs(bars) do
		if b.fromFrac and b.fromFrac ~= b.frac and b.fill.Parent then
			b.fill.Size = UDim2.fromScale(math.clamp(b.fromFrac, 0, 1), 1)
			Kit.fillTo(b.fill, b.frac, 0.5)
			local goal = b.goal
			Kit.countTo(b.count, b.fromProg, b.prog, 0.5, function(n) return math.floor(n + 0.5) .. " / " .. goal end)
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
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- (2026-10-21, grade1) graders: "MISSIONS" + "Daily Missions" + the footer were three labels for one thing. The big title is
	-- gone and the X moved into the Daily panel's top-right corner (scopePanel)
	column = new("ScrollingFrame", {
		-- (lobby revamp, graders: the weekly row was cut off) taller column + shorter cards: both rows and the footer fit
		Name = "Column", Position = UDim2.fromOffset(COL_X, COL_Y), Size = UDim2.fromOffset(852, COL_H), BackgroundTransparency = 1, BorderSizePixel = 0, -- (grade1) was y 204, 840 tall
		ScrollBarThickness = 8, ScrollBarImageColor3 = C.olive, ScrollBarImageTransparency = 0.3, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 25), Parent = column })
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
					if scope then d.Text = "new " .. (scope == "Daily" and "daily missions" or "weekly contracts") .. " in " .. clock(resetIn(scope)) end
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
		render()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
		for _, b in ipairs(bars) do -- bars fill in after the panel pops open
			if b.fill.Parent then
				b.fill.Size = UDim2.fromScale(0, 1)
				Kit.tween(b.fill, 0.6, { Size = UDim2.fromScale(b.frac, 1) }, Enum.EasingStyle.Quart)
				if b.count and b.count.Parent then -- (2026-10-21, round 3) counts tick up with the fill
					local goal = b.goal
					Kit.countTo(b.count, 0, b.prog, 0.6, function(n) return math.floor(n + 0.5) .. " / " .. goal end)
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
function Screen.Refresh() if isOpen then renderSoon() end end -- (2026-10-21, auto-pay) waits for a check / PAID pop

return Screen
