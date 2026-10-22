-- UIKit/PlayRow (ModuleScript): the lobby's PLAY button + party (your avatar and a round invite "+").
-- (2026-10-21, RIVALS 1:1) a 1:1 port of the replica's Play row (rivals_practice/ui/hud/HudController.client.lua, "Play row"):
-- sizes, positions, gradient, font and hover are the replica's; every colour / font comes from UIKit.Rivals.Theme (values it has
-- no token for yet are read from Theme.playRow[name] when present, else the replica's measured value), so a re-theme is one file.
-- Its own ScreenGui on the design canvas, converted to Scale (no Offset). It follows the lobby HUD: hidden whenever the lobby
-- ScreenGui is disabled (menus open) or the dock is hidden (Kit room).
--   PlayRow.Init({ lobbyGui, dock, onPlay, onInvite, tooltip })
--   PlayRow.SetState(text, kind)   kind: "play" (lime) | "busy" (grey: searching / in queue) | "found" (bright lime)
-- (UI session 2026-10-17: now in the UI session's files) party: your party members' headshots sit right of your avatar
-- (RIVALS), the "+" moves along after them; Player attribute PartyMembers (JSON, leader first) from LobbyParty.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = script.Parent
local Kit = require(UIKit:WaitForChild("Kit")) -- our Kit: canvas, Scale conversion, sfx, tooltips, crown
local new = Kit.new
local RUI = ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Rivals")
local RTheme = require(RUI:WaitForChild("Theme"))
local RKit = require(RUI:WaitForChild("Kit"))
local RC, RH = RTheme.color, RTheme.hex

local function rtok(name, default)
	local t = RTheme.playRow
	if t and t[name] ~= nil then return t[name] end
	return default
end
-- the replica's Play gradient (measured on ref_65: pale lime top band, fast fall to bright lime, slightly greener at the bottom);
-- 5 stops at 0 / 0.15 / 0.35 / 0.6 / 1, then the button edge and the label outline colours
local GRADS = {
	play = rtok("play", { "#F6FFBE", "#E9FEB7", "#BCFC4E", "#94FB24", "#79EC31", edge = "#D8FF8A", text = "#5FB51E" }),
	-- (no live capture of a searching Play: Theme grey, same band shape)
	busy = rtok("busy", { "#E4E4E4", "#D2D2D2", "#B5B5B5", "#999999", "#7A7A7A", edge = "#D8D8D8", text = "#5A5A5A" }),
	-- match found: the same lime, lifted
	found = rtok("found", { "#FCFFE0", "#F4FFCF", "#D6FF6E", "#B4FC4A", "#94F23A", edge = "#EFFFC0", text = "#5FB51E" }),
}
local PLAY_FONT = RTheme.font.display -- Rubik ExtraBold (the replica's FX)
local PLAY_SIZE = 35 -- cap 20 px -> size 35

local PlayRow = {}
local gui, play, playLabel, playGrad, playStroke, labelStroke, labelCap

local function seq(kind)
	local g = GRADS[kind] or GRADS.play
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, RH(g[1])), ColorSequenceKeypoint.new(0.15, RH(g[2])), ColorSequenceKeypoint.new(0.35, RH(g[3])),
		ColorSequenceKeypoint.new(0.6, RH(g[4])), ColorSequenceKeypoint.new(1, RH(g[5])),
	}), RH(g.edge), RH(g.text)
end

-- RIVALS writes its button words in title case ("Play", "To Duels"): callers pass "PLAY", "SEARCHING 0:12", "IN QUEUE · DUEL"
local function titleCase(s)
	return (string.lower(s):gsub("(%a)([%w']*)", function(a, b) return string.upper(a) .. b end))
end

local function headshot(img, uid)
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid or Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then img.Image = id end
	end)
end

function PlayRow.SetState(text, kind)
	if not play then return end
	playLabel.Text = titleCase(text)
	-- the label is TextScaled (long states like "Searching 0:12" must fit 222 px); its cap follows the canvas like a TextSize would
	labelCap.MaxTextSize = math.max(1, math.floor(PLAY_SIZE * Kit.factor() + 0.5))
	local s, edge, textEdge = seq(kind)
	playGrad.Color = s
	playStroke.Color = edge
	labelStroke.Color = textEdge
end

function PlayRow.Init(ctx)
	if gui then return end
	gui = new("ScreenGui", { Name = "PlayRowUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	-- (2026-10-21, RIVALS 1:1) PLAY: the replica's 222 x 62 button at (849, 859), corner 4, the measured lime gradient and a thin
	-- pale-lime edge (#D8FF8A 1.5 @ 0.2); "Play" in Rubik ExtraBold 35 with a thin green outline (#5FB51E 1.5 @ 0.2), not black.
	-- The 340 x 84 field-green button, the Oswald caps, the halo pulse, the shine sweep and the hover corner brackets are gone.
	play = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(849, 859), Size = UDim2.fromOffset(222, 62),
		BackgroundColor3 = RC.white, ZIndex = 2, Parent = root }, { RKit.corner(4) })
	playGrad = new("UIGradient", { Rotation = 90, Parent = play })
	playStroke = RKit.stroke(RC.white, 1.5, 0.2)
	playStroke.Parent = play
	playLabel = RKit.label({ Text = "Play", FontFace = PLAY_FONT, TextSize = PLAY_SIZE, TextScaled = true, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(206, 40), ZIndex = 3, Parent = play })
	labelCap = new("UITextSizeConstraint", { MaxTextSize = PLAY_SIZE, Parent = playLabel })
	labelStroke = new("UIStroke", { Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = playLabel })
	-- hover: the replica grows Play 1.08 from its centre (Kit.bindButton); live RIVALS also brightens it, so a white sheen at
	-- 0.85 fades in under the label. Press 0.93 like every replica button. The "Hovered" attribute tells LobbyHud to hide its
	-- "Join the queue" bubble while PLAY is hovered.
	local playScale = new("UIScale", { Name = "HoverScale", Parent = play })
	local sheen = new("Frame", { Name = "_HoverGlow", BackgroundColor3 = RC.white, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 2, Parent = play }, { RKit.corner(4) })
	local playHover = false
	local function playEnter()
		if playHover then return end
		playHover = true
		play:SetAttribute("Hovered", true)
		Kit.tween(playScale, 0.1, { Scale = 1.08 })
		Kit.tween(sheen, 0.1, { BackgroundTransparency = 0.85 })
		Kit.sfx("hover")
	end
	local function playLeave()
		playHover = false
		play:SetAttribute("Hovered", false)
		Kit.tween(playScale, 0.1, { Scale = 1 })
		Kit.tween(sheen, 0.1, { BackgroundTransparency = 1 })
	end
	play.MouseEnter:Connect(playEnter)
	play.MouseLeave:Connect(playLeave)
	play.SelectionGained:Connect(playEnter)
	play.SelectionLost:Connect(playLeave)
	play.MouseButton1Down:Connect(function() Kit.tween(playScale, 0.06, { Scale = 0.93 }) end)
	play.MouseButton1Up:Connect(function() Kit.tween(playScale, 0.1, { Scale = playHover and 1.08 or 1 }, Enum.EasingStyle.Back) end)
	task.defer(Kit.centreAnchor, play) -- grow from the centre (after toScale below has placed it)
	play.Activated:Connect(function() Kit.sfx("click"); if ctx.onPlay then ctx.onPlay() end end)

	-- (2026-10-21, RIVALS 1:1) party: the replica's 62 px round headshot at (1102, 859) on #2B2B33, then the 46 px "+" at
	-- (1172, 876): a dark disc fading from 0.6 to 0.1 (#5A5A62 -> #1E1E24) with a light grey cross (#B9B9C0)
	local AV_BG = rtok("avatarBg", RH("#2B2B33"))
	local av = new("ImageButton", { Name = "Avatar", AutoButtonColor = false, BackgroundColor3 = AV_BG, Position = UDim2.fromOffset(1102, 859),
		Size = UDim2.fromOffset(62, 62), Parent = root }, { RKit.corner(31) })
	headshot(av)
	av:SetAttribute("Uid", Players.LocalPlayer.UserId)
	Kit.bindButton(av, { hover = 1.08 })
	av.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end) -- your avatar opens Your Party too
	local inv = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1172, 876), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = RC.white, Parent = root },
		{ RKit.corner(23), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rtok("inviteTop", RH("#5A5A62")), rtok("inviteBottom", RH("#1E1E24"))),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }) }) })
	local CROSS = rtok("inviteCross", RH("#B9B9C0"))
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = CROSS, Parent = inv }, { RKit.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = CROSS, Parent = inv }, { RKit.corner(2) })
	Kit.bindButton(inv, { hover = 1.1 })
	inv.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end)
	-- party members: up to four more heads (50 px, 54 apart) after yours; the + slides right past them
	local mates = new("Frame", { Name = "PartyMates", BackgroundTransparency = 1, Position = UDim2.fromOffset(1172, 859), Size = UDim2.fromOffset(4 * 54, 62), Parent = root })
	local invHome -- read after Kit.bindButton has re-anchored the + (it moves it a frame later)
	if ctx.tooltip then
		-- no tooltip on PLAY (LobbyHud's "Join the queue" bubble is its only bubble)
		ctx.tooltip(av, Players.LocalPlayer.DisplayName, "Your squad. Invite friends with the + to play together.")
		ctx.tooltip(inv, "Invite", "Invite a friend to your squad.")
	end
	Kit.toScale(root)
	PlayRow.SetState("PLAY", "play")
	local function refreshParty()
		invHome = invHome or inv.Position
		for _, c in mates:GetChildren() do c:Destroy() end
		local ok, list = pcall(HttpService.JSONDecode, HttpService, Players.LocalPlayer:GetAttribute("PartyMembers") or "")
		list = (ok and type(list) == "table") and list or {}
		-- (2026-10-18, live RIVALS) the party leader's head always comes first, crowned, even when you were the one invited
		local me = Players.LocalPlayer.UserId
		local leader = (#list > 1) and (Players.LocalPlayer:GetAttribute("PartyLeader") or list[1]) or me
		if av:GetAttribute("Uid") ~= leader then av:SetAttribute("Uid", leader); av.Image = ""; headshot(av, leader) end
		local crown = av:FindFirstChild("Crown")
		if #list > 1 and not crown then Kit.crown(av, UDim2.fromScale(0.82, 0.08), UDim2.fromScale(0.6, 0.46), 6)
		elseif #list <= 1 and crown then crown:Destroy() end
		local n = 0
		for _, uid in list do
			if uid ~= leader and n < 4 then
				local head = new("ImageButton", { AutoButtonColor = false, BackgroundColor3 = AV_BG, Position = UDim2.fromScale(n * 54 / (4 * 54), 0.06),
					Size = UDim2.fromScale(50 / (4 * 54), 50 / 62), Parent = mates }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
				task.spawn(function()
					local okT, id = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
					if okT then head.Image = id end
				end)
				head.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end)
				n += 1
			end
		end
		-- the + follows the last head (design px / 1920 across)
		inv.Position = UDim2.new(invHome.X.Scale + n * 54 / 1920, 0, invHome.Y.Scale, 0)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("PartyMembers"):Connect(refreshParty)
	task.delay(0.2, refreshParty)

	-- follow the lobby HUD
	local function sync()
		local on = (not ctx.lobbyGui or ctx.lobbyGui.Enabled) and (not ctx.dock or ctx.dock.Visible)
		gui.Enabled = on
	end
	if ctx.lobbyGui then ctx.lobbyGui:GetPropertyChangedSignal("Enabled"):Connect(sync) end
	if ctx.dock then ctx.dock:GetPropertyChangedSignal("Visible"):Connect(sync) end
	sync()
end

return PlayRow
