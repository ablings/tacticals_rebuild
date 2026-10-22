-- UIKit/MissionsScreen (ModuleScript): the lobby MISSIONS screen. Layout follows the RIVALS Tasks screen
-- (ported from rivals_practice/ui/tasks): a centred column of panels, each with task cards (title, icon,
-- progress bar with the count, reward). Data is tacticals' real quests: data.Quests.Daily / .Weekly,
-- progress = data.Stats[def.Stat] - entry.Base, rewards in scissors, claimed with "ClaimQuest".
-- Design px at 1920x1080, converted to Scale (Kit.toScale) - no Offset on screen.
--   MissionsScreen.Init({ Config, getData, ask, tooltip, onOpen, onClose })
--   MissionsScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService") -- (2026-10-21, RIVALS pass) the looping CLAIM sheen

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
		img.Size = UDim2.fromScale(1, 0.8)
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
local CARD_H = 266 -- (lobby revamp) was 300; (2026-10-21, round 3) 258 -> 266: room for the count under the bar + a bigger reward
-- (2026-10-21, round 3: match RIVALS) the cards leave the navy-slate C.panelRaised for our dark plate / field-green family
local CARD_BG = C.plate or Color3.fromRGB(24, 26, 21) -- charcoal-green plate
local CARD_READY = Color3.fromRGB(34, 52, 24) -- a claimable card is lit dark field green
local FIELD, FIELD_DARK = C.field or Color3.fromRGB(141, 191, 90), C.fieldDark or Color3.fromRGB(76, 122, 46)

local PANEL_T = 0.5
local COL_X, COL_W = 532, 828
local CARD_X = { 45, 292, 540 }
-- (2026-10-21, RIVALS pass) a claim's check / reward pop must finish before data refreshes rebuild the cards
local holdUntil, renderToken = 0, 0
local render -- forward: the claim handler re-renders through renderSoon
local function renderSoon()
	renderToken += 1 -- the latest call wins (a hold shortened after the server answers reschedules)
	local token, delay = renderToken, holdUntil - os.clock()
	if delay <= 0 then render() return end
	task.delay(delay, function()
		if token ~= renderToken or not isOpen then return end
		if os.clock() >= holdUntil then render() else renderSoon() end
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
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = PANEL_T, Parent = column,
	}) -- (2026-10-21, AI-tells cleanup) no thin olive border, no left TacBar: the dark fill separates the panel
end

local function bar(parent, pos, size, frac, done)
	-- (lobby revamp, graders: an empty bar was invisible) a lighter, rounded track so 0 / N still shows how far there is to go
	-- (2026-10-21, round 3: match RIVALS) a bigger bar (RIVALS t0062: the bar is the card's centre line); in-progress fills cream,
	-- done fills the field-green gradient
	local back = new("Frame", { Name = "Bar", Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(52, 56, 47), ClipsDescendants = true, Parent = parent },
		{ Kit.corner(6) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = done and Color3.new(1, 1, 1) or Tac.C.bone, BorderSizePixel = 0, Parent = back },
		{ Kit.corner(6) })
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
	local n = Kit.label({ Text = "×" .. amount, FontFace = F.display, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(size * 0.78, size + 4), Size = UDim2.fromOffset(80, 36), ZIndex = 3, Parent = holder })
	Kit.textStroke(2).Parent = n
	return holder
end

local function taskCard(parent, scope, i, entry, def, x, y)
	local data = ctx.getData() or {}
	local prog = math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (entry.Base or 0), 0, def.Goal)
	local done = prog >= def.Goal
	local ready = done and not entry.Claimed
	local card = new("Frame", {
		Name = scope .. i, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(243, CARD_H),
		BackgroundColor3 = ready and CARD_READY or CARD_BG, BackgroundTransparency = ready and 0.1 or 0.25, Parent = parent, -- (2026-10-21, round 3) off the navy
	}, { Kit.corner(2) })
	local br = Tac.brackets(card, ready and Tac.C.bone or Tac.C.line, 18, 3)
	-- (2026-10-21, RIVALS pass) the "D-01" / "W-02" id label is gone: RIVALS' cards carry no ids (clean)
	if ready then new("Frame", { Name = "ReadyStripe", BackgroundColor3 = FIELD, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Parent = card }) end
	if not entry.Claimed then Tac.hoverBrackets(card, br) end
	-- (2026-10-21, round 3: match RIVALS) RIVALS' order top to bottom (t0062): title, task glyph, a wide bar, the "x / y" count
	-- UNDER the bar (it no longer runs through it), then the reward. Done counts turn field green with a check in front.
	local title = Kit.label({ Text = def.Text, FontFace = F.bold, TextSize = 21, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 44), Parent = card })
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(121, 82), Size = UDim2.fromOffset(200, 50), Parent = card })
	statIcon(art, def.Stat, card)
	bar(card, UDim2.fromOffset(16, 114), UDim2.fromOffset(211, 16), prog / def.Goal, done)
	local count = Kit.label({ Text = prog .. " / " .. def.Goal, FontFace = F.display, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = done and FIELD or C.cream or Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 28), ZIndex = 3, Parent = card })
	if done then
		title.TextColor3 = FIELD
		count.Text = "✓  " .. def.Goal .. " / " .. def.Goal -- (the check rides in the text, so long counts can't collide with it)
	else
		-- (2026-10-21, round 3: match RIVALS "counters that animate") the count ticks up with its bar when the screen opens
		bars[#bars].count, bars[#bars].prog, bars[#bars].goal = count, prog, def.Goal
	end
	local rewardHolder = reward(card, def.Reward, 62, UDim2.fromOffset(106, 188), card)
	-- claim strip along the bottom
	local strip = UDim2.fromOffset(218, 38)
	if entry.Claimed then
		-- (2026-10-21, round 3) the claimed state reads as finished, not just dim: a field-green "✓ CLAIMED" on a dark plate
		Kit.label({ Text = "✓  CLAIMED", FontFace = F.display, TextSize = 24, TextColor3 = FIELD, TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.35, BackgroundColor3 = Color3.new(0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = strip, Parent = card })
		card.BackgroundTransparency = 0.6
	elseif ready then
		local b = Kit.button("key", strip, "CLAIM")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -8)
		b.Parent = card
		-- (2026-10-21, RIVALS pass) ready cards pull the eye: the card breathes (from its centre), a sheen sweeps CLAIM on a
		-- loop, and the card lifts on hover. A position lift, not a UIScale: one UIScale per object (the breathe owns it).
		Kit.centreAnchor(card)
		Kit.breathe(card, 0.03, 1.6)
		local sheen = new("Frame", { Name = "ClaimSheen", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = b },
			{ Kit.corner(3), new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) }) })
		TweenService:Create(sheen:FindFirstChildOfClass("UIGradient"), TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.1),
			{ Offset = Vector2.new(1, 0) }):Play()
		card.MouseEnter:Connect(function()
			local home = card:GetAttribute("LiftHome") or card.Position -- (Scale by now: toScale ran after the build)
			card:SetAttribute("LiftHome", home)
			Kit.tween(card, 0.12, { Position = home - UDim2.fromScale(0, 6 / (82 + CARD_H + 24)) })
		end)
		card.MouseLeave:Connect(function()
			local home = card:GetAttribute("LiftHome")
			if home then Kit.tween(card, 0.12, { Position = home }) end
		end)
		-- (2026-10-21, RIVALS pass) the claim is a moment: squash, busy dots while the server answers, then a check pops
		-- over the art, the reward punches, the reward sound plays, and only then the cards re-render
		local claiming = false
		b.Activated:Connect(function()
			if claiming then return end
			claiming = true
			holdUntil = os.clock() + 15 -- no rebuild while we wait on the server
			local sc = b:FindFirstChildOfClass("UIScale") -- bindButton's own scale (Kit.button binds it)
			if sc then Kit.tween(sc, 0.08, { Scale = 0.88 }) end
			local stopBusy = Kit.busy(b)
			local r = ctx.ask("ClaimQuest", scope, i)
			stopBusy()
			if sc and sc.Parent then Kit.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back) end
			if r and r.ok and card.Parent then
				local check = new("ImageLabel", { Name = "ClaimCheck", BackgroundTransparency = 1, Image = icon("check"), ImageColor3 = C.cream or Color3.new(1, 1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 82 / CARD_H), Size = UDim2.fromScale(0.42, 0.42 * 243 / CARD_H), ZIndex = 6, Parent = card },
					{ new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
				Kit.popIn(check)
				task.delay(0.12, function() if rewardHolder.Parent then Kit.pop(rewardHolder, 1.3) end end)
				Kit.sfx("reward")
				holdUntil = os.clock() + 0.65
			else
				holdUntil = 0
				claiming = false
			end
			if isOpen then renderSoon() end
		end)
	end
	-- (2026-10-21, RIVALS pass) no IN PROGRESS strip: the "3 / 5" count already says it (clean)
	if ctx.tooltip then
		ctx.tooltip(card, def.Text, function()
			return done and (entry.Claimed and "Reward collected." or `Done! Claim your {def.Reward} scissors.`)
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
	local head = new("Frame", { Name = "HeadIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 6), Size = UDim2.fromOffset(56, 56), Parent = p })
	ViewIcons.Icon(head, iconModel, { hoverTarget = p })
	Kit.label({ Text = title, FontFace = F.display, TextSize = 40, Position = UDim2.fromOffset(84, 8), Size = UDim2.fromOffset(400, 52), Parent = p })
	local timer = Kit.label({ Text = "", FontFace = F.medium, TextSize = 24, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(COL_W - 30, 14), Size = UDim2.fromOffset(380, 40), Parent = p })
	timer:SetAttribute("ResetScope", scope)
	-- (2026-10-21, round 3: match RIVALS) RIVALS' Daily Tasks header carries a bright "To Duels" button on the right (t0062): the
	-- way to go and do the tasks. Ours is a field-green "PLAY" that opens the Play screen through ctx.openPlay. It only appears
	-- when the controller passes that hook (LobbyUIController's MissionsScreen.Init does not yet); the reset timer moves left of it.
	if scope == "Daily" and ctx.openPlay then
		local play = Kit.button("key", UDim2.fromOffset(170, 50), "PLAY")
		play.Name = "ToPlay"
		play.AnchorPoint = Vector2.new(1, 0)
		play.Position = UDim2.fromOffset(COL_W - 24, 12)
		play.Parent = p
		play.Activated:Connect(function()
			Screen.Close()
			ctx.openPlay()
		end)
		timer.Position = UDim2.fromOffset(COL_W - 24 - 170 - 18, 14)
	end
	timer.Text = "new " .. string.lower(title) .. " in " .. clock(resetIn(scope))
	if #list == 0 then
		Kit.label({ Text = "Loading missions...", FontFace = F.medium, TextSize = 26, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 40), Parent = p })
	end
	for i, entry in ipairs(list) do
		local def = questDef(scope, entry.Id)
		if def and CARD_X[i] then taskCard(p, scope, i, entry, def, CARD_X[i], 82) end
	end
	return p
end

function render() -- (forward-declared above renderSoon)
	bars = {}
	Kit.restoreModifiers(column)
	column.AutomaticCanvasSize = Enum.AutomaticSize.Y
	column.CanvasSize = UDim2.new()
	for _, ch in ipairs(column:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	scopePanel("Daily", 1, "Daily Missions", "Clipboard")
	scopePanel("Weekly", 2, "Weekly Contracts", "Medal")
	local foot = new("Frame", { Name = "Foot", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(COL_W, 40), Parent = column })
	Kit.label({ Text = "Play matches to fill these up." --[[ (2026-10-21, RIVALS pass) shorter footer ]], FontFace = F.medium, TextSize = 22,
		TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = foot })
	Kit.toScale(root) -- UI rule: everything in Scale
end

local function build()
	gui = new("ScreenGui", { Name = "MissionsUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- (2026-10-21, AI-tells cleanup) the left TacBar beside the MISSIONS title is gone
	Kit.label({ Text = "MISSIONS", FontFace = F.display, TextSize = 64, Position = UDim2.fromOffset(COL_X + 20, 118), Size = UDim2.fromOffset(500, 76), Parent = root })
	local close = Kit.closeButton(UDim2.fromOffset(94, 48))
	close.Position = UDim2.fromOffset(1312, 136) -- (lobby revamp Phase B: square X at the column edge)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	column = new("ScrollingFrame", {
		-- (lobby revamp, graders: the weekly row was cut off) taller column + shorter cards: both rows and the footer fit
		Name = "Column", Position = UDim2.fromOffset(COL_X, 204), Size = UDim2.fromOffset(852, 840), BackgroundTransparency = 1, BorderSizePixel = 0,
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
function Screen.Refresh() if isOpen then renderSoon() end end -- (2026-10-21, RIVALS pass) waits for a claim's pop

return Screen
