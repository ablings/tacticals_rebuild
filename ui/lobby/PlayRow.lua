-- UIKit/PlayRow (ModuleScript): the lobby's PLAY button + party (your avatar and a round invite "+"),
-- RIVALS play row (ported from rivals_practice/ui/hud) in tacticals' olive (pass 34). Its own ScreenGui on the
-- design canvas, converted to Scale (no Offset). It follows the lobby HUD: hidden whenever the lobby
-- ScreenGui is disabled (menus open) or the dock is hidden (Kit room).
--   PlayRow.Init({ lobbyGui, dock, onPlay, onInvite, tooltip })
--   PlayRow.SetState(text, kind)   kind: "play" (field green) | "busy" (gunmetal: searching / in queue) | "found" (bright field green)
-- (UI session 2026-10-17: now in the UI session's files) party: your party members' headshots sit right of your avatar
-- (RIVALS), the "+" moves along after them; Player attribute PartyMembers (JSON, leader first) from LobbyParty.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local C, F, new = Theme.color, Theme.font, Kit.new
local hex = Theme.hex

local PlayRow = {}
local gui, play, playLabel, playGrad, playStroke

-- top band pale, fast fall to the main colour, slightly deeper at the bottom (RIVALS play button shape)
local GRADS = {
	play = { "#E3F0D2", "#BCDC96", "#8DBF5A", "#6FA544", "#4C7A2E", "#1F3A14" }, -- (2026-10-20, Edward) field-green primary: matches the lobby's olive / lime and reads apart from Robux lime
	busy = { "#9A9E8C", "#787D69", "#525846", "#41463A", "#2C3027", "#151813" }, -- gunmetal while searching
	found = { "#F0F8E4", "#CFE8AE", "#A6D274", "#8DBF5A", "#6FA544", "#2C4A1C" }, -- match found / ready: a brighter field green (2026-10-21, AI-tells cleanup: was the comic yellow)
}
local function seq(kind)
	local g = GRADS[kind] or GRADS.play
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex(g[1])), ColorSequenceKeypoint.new(0.15, hex(g[2])), ColorSequenceKeypoint.new(0.35, hex(g[3])),
		ColorSequenceKeypoint.new(0.6, hex(g[4])), ColorSequenceKeypoint.new(1, hex(g[5])),
	}), hex(g[6])
end

local function headshot(img, uid)
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, uid or Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then img.Image = id end
	end)
end

local stateKind = "play" -- (2026-10-21, round 3) the halo pulse reads it: on for play / found, off while busy
function PlayRow.SetState(text, kind)
	if not play then return end
	stateKind = kind or "play"
	playLabel.Text = text
	local s, edge = seq(kind)
	playGrad.Color = s
	playStroke.Color = edge
end

function PlayRow.Init(ctx)
	if gui then return end
	gui = new("ScreenGui", { Name = "PlayRowUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	-- PLAY: chunky field-green button, Oswald with a darker green text outline; grows from its centre on hover
	-- (2026-10-21, AI-tells cleanup) no thin pale border on the button; the gradient fill carries it
	-- (lobby revamp, graders: PLAY was barely bigger than the dock icons) 340 x 84 design px: the biggest thing on the hub,
	-- about 30 % taller on a phone (over the 44 pt tap minimum on a 390 pt tall screen)
	-- (2026-10-21, round 3: match RIVALS t0000 / t0254.9, PLAY is THE call to action) a field-green halo behind PLAY swells out
	-- and fades every couple of seconds (faster when a match is found), on top of the shine sweep below. A sibling drawn
	-- behind the button (ZIndex 1 < 2), centred on it, so the button's own hover UIScale is untouched.
	local halo = new("Frame", { Name = "PlayHalo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 880), Size = UDim2.fromOffset(340, 84),
		BackgroundColor3 = hex("#8DBF5A"), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = root }, { Kit.corner(6) })
	play = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(790, 838), Size = UDim2.fromOffset(340, 84),
		BackgroundColor3 = C.white, ZIndex = 2, Parent = root }, { Kit.corner(2) })
	playGrad = new("UIGradient", { Rotation = 90, Parent = play })
	playLabel = Kit.label({ Text = "PLAY", FontFace = F.display, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(310, 66), Parent = play })
	new("UITextSizeConstraint", { MaxTextSize = 58, Parent = playLabel })
	playStroke = new("UIStroke", { Color = hex("#1F3A14"), Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = playLabel })
	local Tac = require(UIKit:WaitForChild("Tac"))
	Tac.hoverBrackets(play, Tac.brackets(play, Tac.C.bone, 16, 3))
	Kit.bindButton(play, { hover = 1.08 })
	play.Activated:Connect(function() if ctx.onPlay then ctx.onPlay() end end)
	PlayRow.SetState("PLAY", "play")

	-- party: your avatar on a round plate, then a round "+" to invite friends
	-- (2026-10-21, AI-tells cleanup) the thin yellow / cream ring around the avatar and the green hairlines on the + and the
	-- party heads are gone; each sits on a solid dark disc that sets it off the floor
	local av = new("ImageButton", { Name = "Avatar", AutoButtonColor = false, BackgroundColor3 = C.panelRaised, Position = UDim2.fromOffset(1150, 849),
		Size = UDim2.fromOffset(62, 62), Parent = root }, { Kit.corner(31) })
	headshot(av)
	av:SetAttribute("Uid", Players.LocalPlayer.UserId)
	Kit.bindButton(av, { hover = 1.08 })
	av.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end) -- your avatar opens Your Party too
	local inv = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1222, 857), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.white, Parent = root },
		{ Kit.corner(23), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#2B3142"), hex("#161A24")),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = C.text, Parent = inv }, { Kit.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = C.text, Parent = inv }, { Kit.corner(2) })
	Kit.bindButton(inv, { hover = 1.1 })
	inv.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end)
	-- party members: up to four more heads after yours; the + slides right past them
	local mates = new("Frame", { Name = "PartyMates", BackgroundTransparency = 1, Position = UDim2.fromOffset(1220, 849), Size = UDim2.fromOffset(4 * 54, 62), Parent = root })
	local invHome -- read after Kit.bindButton has re-anchored the + (it moves it a frame later)
	if ctx.tooltip then
		ctx.tooltip(play, "Play", "Find a match online: 1v1, 2v2 or 3v3, casual or ranked.")
		ctx.tooltip(av, Players.LocalPlayer.DisplayName, "Your squad. Invite friends with the + to play together.")
		ctx.tooltip(inv, "Invite", "Invite a friend to your squad.")
	end
	Kit.toScale(root)
	-- (2026-10-20, Edward: make the lobby "feel alive" like RIVALS) a light sweeps across PLAY every few seconds (its own clipped
	-- layer, so the hover brackets outside the button aren't cut off)
	do
		local clip = new("Frame", { Name = "ShineClip", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = play },
			{ Kit.corner(2) })
		local bar = new("Frame", { Name = "Shine", BackgroundColor3 = C.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 20,
			Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.fromScale(0.16, 2.2), ZIndex = 3, Parent = clip }, {
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }) })
		task.spawn(function()
			while bar.Parent do
				task.wait(4.5)
				if play.Visible and gui.Enabled then
					bar.Position = UDim2.fromScale(-0.3, 0.5)
					Kit.tween(bar, 0.7, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				end
			end
		end)
	end
	do
		local hs = new("UIScale", { Name = "PulseScale", Parent = halo })
		task.spawn(function()
			while halo.Parent do
				local found = stateKind == "found"
				if stateKind ~= "busy" and play.Visible and gui.Enabled then
					hs.Scale = 1
					halo.BackgroundTransparency = found and 0.25 or 0.45
					Kit.tween(hs, found and 0.6 or 0.9, { Scale = found and 1.3 or 1.22 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					Kit.tween(halo, found and 0.6 or 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
				task.wait(found and 0.9 or 2.2)
			end
		end)
	end
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
				local head = new("ImageButton", { AutoButtonColor = false, BackgroundColor3 = C.panelRaised, Position = UDim2.fromScale(n * 54 / (4 * 54), 0.06),
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