-- UIKit/PlayRow (ModuleScript): the lobby's PLAY button + party (your avatar and a round invite "+"),
-- RIVALS play row (ported from rivals_practice/ui/hud) in tacticals' olive (pass 34). Its own ScreenGui on the
-- design canvas, converted to Scale (no Offset). It follows the lobby HUD: hidden whenever the lobby
-- ScreenGui is disabled (menus open) or the dock is hidden (Kit room).
--   PlayRow.Init({ lobbyGui, dock, onPlay, onInvite, tooltip })
--   PlayRow.SetState(text, kind)   kind: "play" (amber) | "busy" (olive: searching / in queue) | "found" (green)
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
	play = { "#D6ECFF", "#9CCEFF", "#5AB2FF", "#3A8CF0", "#1E63D6", "#0E2F6E" }, -- blue primary (2026-10-20 palette)
	busy = { "#9A9E8C", "#787D69", "#525846", "#41463A", "#2C3027", "#151813" }, -- gunmetal while searching
	found = { "#FFF6BF", "#FFEC80", "#FFD400", "#F5C200", "#E0A800", "#7A5A00" }, -- match found: the comic-yellow accent
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

function PlayRow.SetState(text, kind)
	if not play then return end
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

	-- PLAY: chunky amber button, Oswald with a darker amber outline; grows from its centre on hover
	play = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(830, 846), Size = UDim2.fromOffset(260, 70),
		BackgroundColor3 = C.white, Parent = root }, { Kit.corner(2), Kit.stroke(hex("#CFE6FF"), 1.5, 0.3) })
	playGrad = new("UIGradient", { Rotation = 90, Parent = play })
	playLabel = Kit.label({ Text = "PLAY", FontFace = F.display, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(236, 54), Parent = play })
	new("UITextSizeConstraint", { MaxTextSize = 46, Parent = playLabel })
	playStroke = new("UIStroke", { Color = hex("#0E2F6E"), Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = playLabel })
	local Tac = require(UIKit:WaitForChild("Tac"))
	Tac.hoverBrackets(play, Tac.brackets(play, Tac.C.bone, 16, 3))
	Kit.bindButton(play, { hover = 1.08 })
	play.Activated:Connect(function() if ctx.onPlay then ctx.onPlay() end end)
	PlayRow.SetState("PLAY", "play")

	-- party: your avatar in an amber ring, then a round "+" to invite friends
	local av = new("ImageButton", { Name = "Avatar", AutoButtonColor = false, BackgroundColor3 = C.panelRaised, Position = UDim2.fromOffset(1114, 850),
		Size = UDim2.fromOffset(62, 62), Parent = root }, { Kit.corner(31), Kit.stroke(C.amber, 2.5, 0) })
	headshot(av)
	av:SetAttribute("Uid", Players.LocalPlayer.UserId)
	Kit.bindButton(av, { hover = 1.08 })
	av.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end) -- your avatar opens Your Party too
	local inv = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1186, 858), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.white, Parent = root },
		{ Kit.corner(23), Kit.stroke(C.olive, 1.5, 0.3), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#2B3142"), hex("#161A24")),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = C.text, Parent = inv }, { Kit.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = C.text, Parent = inv }, { Kit.corner(2) })
	Kit.bindButton(inv, { hover = 1.1 })
	inv.Activated:Connect(function() if ctx.onInvite then ctx.onInvite() end end)
	-- party members: up to four more heads after yours; the + slides right past them
	local mates = new("Frame", { Name = "PartyMates", BackgroundTransparency = 1, Position = UDim2.fromOffset(1184, 850), Size = UDim2.fromOffset(4 * 54, 62), Parent = root })
	local invHome -- read after Kit.bindButton has re-anchored the + (it moves it a frame later)
	if ctx.tooltip then
		ctx.tooltip(play, "Play", "Find a match online: 1v1, 2v2 or 3v3, casual or ranked.")
		ctx.tooltip(av, Players.LocalPlayer.DisplayName, "Your squad. Invite friends with the + to play together.")
		ctx.tooltip(inv, "Invite", "Invite a friend to your squad.")
	end
	Kit.toScale(root)
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
					Size = UDim2.fromScale(50 / (4 * 54), 50 / 62), Parent = mates }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Kit.stroke(C.olive, 2, 0) })
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