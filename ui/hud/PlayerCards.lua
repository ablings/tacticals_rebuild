-- UIKit/PlayerCards (ModuleScript): RIVALS' "click a player" UI in TACTICALS' look (UI session 2026-10-17, overnight gap audit).
--   * PlayerCards.Menu(p, row): the player menu that slides out to the left of the player list (click a row). Header = headshot,
--     display name, @username; one row per action, each fading from the panel colour into its own colour, white on hover.
--     Lobby players: Invite / Add Friend / Challenge / View Profile / View Avatar / Block. In a duel: Spectate instead of
--     Invite / Challenge. Yourself: View Profile / View Avatar. Challenge + Spectate only show once the Tacticals session's
--     ReplicatedStorage.LobbySocial remote exists (contract in notes/lobby_social.md).
--   * PlayerCards.Profile(p, world): the profile card over a blurred lobby, laid out like live RIVALS (checked 2026-10-17):
--     headshot + wins + win rate on the left, name, then Level / ELO / Rank badges, then a Career row (Matches, Kills,
--     Headshots, HS %) where RIVALS has Most Played Weapons. Red X under it, plus Invite to PARTY / Challenge 1v1 for
--     anyone else (from the list or the world).
--   * PlayerCards.StartWorld(allowed): hovering a character shows "Double click to view profile" (touch: tap), a double
--     click / tap opens the card. allowed() says when the lobby is up (no menu, no duel, no training).
-- Stats come from attributes the server publishes (PublicStats: Level, Wins, StatMatches, StatKills, StatHeadshots; RankedCore:
-- Rank*). Built in 1920x1080 design px on a 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local RankArt
pcall(function() RankArt = require(UIKit:WaitForChild("RankArt", 10)) end)
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local F_NAME = Font.new(BUILDER, Enum.FontWeight.Bold)
local F_SUB = Font.new(BUILDER, Enum.FontWeight.Medium)
local F_NUM = Font.new(BUILDER, Enum.FontWeight.ExtraBold)
local F_HEAD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BONE, FIELD, GUN, DEEP = hex("#ECE8DA"), hex("#969C8C"), hex("#1A1D1A"), hex("#0C0E0B")
local OLIVE_HI = hex("#9DB05A")

local PlayerCards = {}

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
end
local function headshot(img, p)
	task.spawn(function()
		local ok, id = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok and img.Parent then img.Image = id end
	end)
end
local function social() return ReplicatedStorage:FindFirstChild("LobbySocial") end
local function inDuel(p)
	return p:GetAttribute("InDuel") == true or p:GetAttribute("DuelMatch") ~= nil
end
local function commas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- one ScreenGui above the lobby HUD (5) and below full menus' popups
local gui, canvas
local function ensureGui()
	if gui and gui.Parent then return end
	gui = new("ScreenGui", { Name = "PlayerCards", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 12,
		Parent = player:WaitForChild("PlayerGui") })
	canvas = Kit.canvas(gui)
	canvas.ZIndex = 5 -- above the full-screen tint (1) and the menu's click catcher (4)
end

---------------------------------------------------------------------------------------------------- actions
-- the lobby's own toast (bottom centre); Roblox's notification only if the lobby controller isn't there
local function toast(text, kind)
	local LobbyUI = shared.Get and shared.Get("LobbyUIController")
	if LobbyUI and LobbyUI.Toast then LobbyUI.Toast(text, kind or "bad"); return end
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "TACTICALS", Text = text, Duration = 3 })
end
local spectating = nil
local function run(action, p)
	if action == "View Avatar" then
		pcall(GuiService.InspectPlayerFromUserId, GuiService, p.UserId) -- Roblox's own avatar inspect
	elseif action == "Add Friend" then
		pcall(StarterGui.SetCore, StarterGui, "PromptSendFriendRequest", p)
	elseif action == "Block" then
		pcall(StarterGui.SetCore, StarterGui, "PromptBlockPlayer", p)
	elseif action == "Invite" and ReplicatedStorage:FindFirstChild("LobbyParty") then
		ReplicatedStorage.LobbyParty:FireServer("Invite", p)
		return true
	elseif action == "Invite" then
		local SocialService = game:GetService("SocialService")
		local okCan, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		local ok = okCan and can and pcall(function()
			local opts = Instance.new("ExperienceInviteOptions")
			opts.InviteUser = p.UserId -- the invite sheet opens on this player
			SocialService:PromptGameInvite(player, opts)
		end)
		if not ok then toast("Invites aren't available here (they work in the published game)") end
		return ok
	elseif action == "Challenge" then
		local r = social()
		if r then r:FireServer("Challenge", p) end
	elseif action == "Spectate" then
		local r = social()
		if r then
			spectating = spectating ~= p and p or nil
			r:FireServer("Spectate", spectating)
		end
	end
end

---------------------------------------------------------------------------------------------------- profile card
local profile
local blur
local function closeProfile()
	if not profile then return end
	local p = profile
	profile = nil
	if blur then Kit.tween(blur, 0.2, { Size = 0 }) end
	Kit.tween(p.tint, 0.15, { BackgroundTransparency = 1 })
	Kit.close(p.card, function() p.root:Destroy(); p.tint:Destroy() end)
	for _, b in p.buttons do b.Visible = false end
end
PlayerCards.CloseProfile = closeProfile
function PlayerCards.ProfileOpen() return profile ~= nil end

local function statTile(parent, x, y, value, name, accent)
	local t = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(176, 84), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Parent = parent },
		{ Kit.corner(8), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.88, Thickness = 1.5 }) })
	local v = label(t, value, F_NUM, 34, 0, 8, 176, 42, accent or BONE, Enum.TextXAlignment.Center, 4)
	v.TextTruncate = Enum.TextTruncate.None
	label(t, name, F_SUB, 17, 0, 52, 176, 22, FIELD, Enum.TextXAlignment.Center, 4)
	return t
end

function PlayerCards.Profile(p: Player, world: boolean?)
	ensureGui()
	PlayerCards.CloseMenu()
	if profile then profile.root:Destroy(); profile.tint:Destroy(); profile = nil end
	blur = Lighting:FindFirstChild("PlayerCardBlur") or new("BlurEffect", { Name = "PlayerCardBlur", Size = 0, Parent = Lighting })
	-- the tint covers the whole screen (outside the 16:9 canvas too); a click on it closes
	local tint = new("TextButton", { Name = "ProfileTint", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.scrim,
		BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	local root = new("Frame", { Name = "Profile", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), ZIndex = 2, Parent = canvas })
	-- live RIVALS layout (2026-10-17 check): left column = headshot, wins, win rate; right = name, then three badges
	-- (RIVALS: Level / Streak / Rank; ours: Level / ELO / Rank), then a row of four tiles (RIVALS: Most Played Weapons;
	-- ours: career numbers until per-weapon stats exist)
	local W, H = 640, 352
	local card = new("Frame", { Name = "Card", Position = UDim2.fromOffset((1920 - W) / 2, 320), Size = UDim2.fromOffset(W, H), BackgroundColor3 = GUN,
		ClipsDescendants = true, ZIndex = 2, Parent = root }, { Kit.corner(12), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.82, Thickness = 2 }) })
	-- olive wash fading down from the top, faint diagonal stripes (the Tacticals panel look)
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("#4A5A22"), ZIndex = 2, Parent = card },
		{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.55, 0.92), NumberSequenceKeypoint.new(1, 1) }) }) })
	for i = 0, 14 do
		new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.965, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 35,
			Position = UDim2.fromOffset(-60 + i * 56, 60), Size = UDim2.fromOffset(14, 320), ZIndex = 2, Parent = card })
	end
	local matches, wins = p:GetAttribute("StatMatches") or 0, p:GetAttribute("Wins") or 0
	local kills, heads = p:GetAttribute("StatKills") or 0, p:GetAttribute("StatHeadshots") or 0
	local rate = matches > 0 and string.format("%.1f%%", 100 * wins / matches) or "-"
	local hsr = kills > 0 and string.format("%.0f%%", 100 * heads / kills) or "-"
	local gold = hex("#E9C46A")
	-- left column
	local hs = new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 14), Size = UDim2.fromOffset(120, 120), ZIndex = 3, Parent = card })
	headshot(hs, p)
	local function goldNum(text, y, size)
		local l = label(card, text, F_NUM, size, 10, y, 144, size + 6, gold, Enum.TextXAlignment.Center, 3)
		l.TextTruncate = Enum.TextTruncate.None
		new("UIStroke", { Color = hex("#4A3400"), Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	end
	goldNum(commas(wins), 152, 38)
	label(card, "wins", F_SUB, 17, 10, 194, 144, 20, gold, Enum.TextXAlignment.Center, 3)
	goldNum(rate, 222, 34)
	label(card, "win rate", F_SUB, 17, 10, 260, 144, 20, gold, Enum.TextXAlignment.Center, 3)
	-- right: name + @username
	local nm = label(card, p.DisplayName, F_NAME, 36, 172, 14, 440, 44, BONE, nil, 3)
	nm.TextScaled = false
	label(card, "@" .. p.Name, F_SUB, 19, 172, 54, 440, 22, FIELD, nil, 3)
	-- three badges: Level, ELO, Rank
	local r = RankArt and RankArt.Of(p) or { placed = false, name = "Unranked", elo = 0 }
	local placedN, needN = p:GetAttribute("RankPlaced") or 0, p:GetAttribute("RankPlacements") or 0
	local cols = { 248, 392, 536 } -- centres
	local lvl = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cols[1], 88), Size = UDim2.fromOffset(64, 56), BackgroundColor3 = hex("#5B6E2C"), ZIndex = 3, Parent = card },
		{ Kit.corner(12), new("UIStroke", { Color = OLIVE_HI, Thickness = 2 }) })
	local ln = label(lvl, tostring(p:GetAttribute("Level") or 1), F_NUM, 30, 0, 0, 64, 56, BONE, Enum.TextXAlignment.Center, 4)
	ln.TextTruncate = Enum.TextTruncate.None
	label(card, "Level", F_SUB, 21, cols[1] - 70, 148, 140, 26, FIELD, Enum.TextXAlignment.Center, 3)
	local elo = label(card, r.placed and commas(r.elo) or (needN > 0 and string.format("%d/%d", placedN, needN) or "-"), F_NUM, 34, cols[2] - 70, 92, 140, 50, BONE, Enum.TextXAlignment.Center, 3)
	elo.TextTruncate = Enum.TextTruncate.None
	label(card, r.placed and "ELO" or "Placements", F_SUB, 21, cols[2] - 70, 148, 140, 26, FIELD, Enum.TextXAlignment.Center, 3)
	-- unranked (placements to play): a faded, greyed Bronze emblem
	local fallback = RankArt and RankArt.EMBLEM.Bronze or ""
	new("ImageLabel", { BackgroundTransparency = 1, Image = r.image or fallback, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cols[3], 82),
		Size = UDim2.fromOffset(90, 66), ImageTransparency = r.image and 0 or 0.7, ImageColor3 = r.image and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150), ZIndex = 3, Parent = card })
	label(card, r.placed and r.name or "Unranked", F_SUB, 21, cols[3] - 80, 148, 160, 26, FIELD, Enum.TextXAlignment.Center, 3)
	-- career row
	label(card, "Career", F_NAME, 19, 172, 186, 440, 22, hex("#C9C9C0"), Enum.TextXAlignment.Center, 3)
	local tiles = { { commas(matches), "Matches" }, { commas(kills), "Kills" }, { commas(heads), "Headshots" }, { hsr, "HS %" } }
	for i, t in tiles do
		local x = 172 + (i - 1) * 112
		local f = new("Frame", { Position = UDim2.fromOffset(x, 216), Size = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Parent = card },
			{ Kit.corner(8), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.8, Thickness = 1.5 }) })
		local v = label(f, t[1], F_NUM, 30, 0, 16, 100, 40, BONE, Enum.TextXAlignment.Center, 4)
		v.TextTruncate = Enum.TextTruncate.None
		label(f, t[2], F_SUB, 16, 0, 62, 100, 22, FIELD, Enum.TextXAlignment.Center, 4)
	end
	-- buttons under the card: the X, and for anyone else INVITE / CHALLENGE beside it (live RIVALS: from the list too)
	local buttons = {}
	local by = 320 + H + 18
	local close = Kit.closeButton(UDim2.fromOffset(150, 66))
	close.ZIndex = 3
	close.Parent = root
	table.insert(buttons, close)
	local acts = {}
	if p ~= player then
		table.insert(acts, { "PARTY", "Invite to", "key", function() run("Invite", p) end })
		if social() and not inDuel(p) then table.insert(acts, { "1V1", "Challenge", "red", function() run("Challenge", p); closeProfile() end }) end
	end
	local total = 150 + #acts * 168
	local x0 = (1920 - total) / 2
	close.Position = UDim2.fromOffset(x0, by)
	for i, a in acts do
		local b = Kit.button(a[3], UDim2.fromOffset(150, 66), nil, { Position = UDim2.fromOffset(x0 + i * 168, by), ZIndex = 3, Parent = root })
		local cc = b:FindFirstChildOfClass("UICorner"); if cc then cc.CornerRadius = UDim.new(0, 8) end
		label(b, a[2], F_SUB, 15, 0, 5, 150, 18, Color3.new(0, 0, 0), Enum.TextXAlignment.Center, 4).TextTransparency = 0.35
		local big = label(b, a[1], F_HEAD, 32, 0, 20, 150, 40, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, 4)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.5, Parent = big })
		b.Activated:Connect(a[4])
		table.insert(buttons, b)
	end
	close.Activated:Connect(closeProfile)
	tint.Activated:Connect(closeProfile)
	Kit.toScale(root)
	profile = { root = root, tint = tint, card = card, buttons = buttons, player = p }
	Kit.tween(blur, 0.25, { Size = Theme.blur })
	Kit.tween(tint, 0.25, { BackgroundTransparency = Theme.alpha.scrim })
	Kit.open(card)
end

---------------------------------------------------------------------------------------------------- player menu
local menu
function PlayerCards.CloseMenu()
	if not menu then return end
	local m = menu
	menu = nil
	m.catcher.Visible = false
	Kit.tween(m.panel, 0.14, { Position = UDim2.fromScale(m.home.X.Scale + 0.1, m.home.Y.Scale) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Kit.tween(m.group, 0.14, { GroupTransparency = 1 })
	task.delay(0.15, function() m.root:Destroy(); m.catcher:Destroy() end)
end
function PlayerCards.MenuOpen() return menu ~= nil end

-- RIVALS' colours, pulled toward the Tacticals palette (olive for the friendly ones)
local ACTION_COLOR = {
	["Invite"] = hex("#4F6B23"), ["Add Friend"] = hex("#4F6B23"), ["Challenge"] = hex("#9A6A1E"), ["Spectate"] = hex("#9A6A1E"),
	["View Profile"] = hex("#2F5170"), ["View Avatar"] = hex("#2F5170"), ["Block"] = hex("#8E2A24"),
}
local ACTION_GLYPH = { ["Invite"] = "+", ["Add Friend"] = "+", ["Challenge"] = "»", ["Spectate"] = "◎", ["View Profile"] = "→", ["View Avatar"] = "→", ["Block"] = "×" }

function PlayerCards.Menu(p: Player, row: GuiObject, listLeft: number?)
	ensureGui()
	PlayerCards.CloseMenu()
	local actions
	if p == player then
		actions = { "View Profile", "View Avatar" }
	elseif inDuel(p) then
		actions = { "Add Friend", "View Profile", "View Avatar", "Block" }
		-- Spectate: paused by Edward (2026-10-17), the row stays out even once LobbySocial exists
	else
		actions = { "Invite", "Add Friend", "View Profile", "View Avatar", "Block" }
		if social() then table.insert(actions, 3, "Challenge") end
	end
	-- top level with the row (design px on the canvas)
	local cs, ca = canvas.AbsoluteSize, canvas.AbsolutePosition
	local f = 1080 / math.max(cs.Y, 1)
	local rowY = (row.AbsolutePosition.Y - ca.Y) * f
	local rightX = listLeft or ((row.AbsolutePosition.X - ca.X) * f)
	local ROW, HEAD = 56, 84
	local H = HEAD + #actions * ROW + 6
	local top = math.clamp(rowY, 10, 1080 - H - 10)
	local root = new("Frame", { Name = "PlayerMenu", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), ZIndex = 20, Parent = canvas })
	-- a click anywhere else closes it (the catcher covers the whole screen, under the panel)
	local catcher = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = gui })
	catcher.Activated:Connect(PlayerCards.CloseMenu)
	local panel = new("CanvasGroup", { Name = "Panel", Position = UDim2.fromOffset(rightX - 8 - 310, top), Size = UDim2.fromOffset(310, H),
		BackgroundColor3 = GUN, BackgroundTransparency = 0.04, ZIndex = 21, Parent = root }, { Kit.corner(10), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1.5 }) })
	local hs = new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 2), Size = UDim2.fromOffset(78, 78), ZIndex = 22, Parent = panel }) -- live: a bare head, no circle
	headshot(hs, p)
	label(panel, p.DisplayName, F_NAME, 23, 92, 14, 206, 30, BONE, nil, 22)
	label(panel, "@" .. p.Name, F_SUB, 16, 92, 44, 206, 20, FIELD, nil, 22)
	for i, a in actions do
		local col = ACTION_COLOR[a]
		local b = new("TextButton", { Name = a, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(4, HEAD + (i - 1) * ROW), Size = UDim2.fromOffset(302, ROW - 4),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = panel }, { Kit.corner(6) })
		local grad = new("UIGradient", { Color = ColorSequence.new(GUN, col), Parent = b })
		local t = label(b, a, F_NAME, 19, 18, 0, 200, ROW - 4, BONE, nil, 23)
		local g = label(b, ACTION_GLYPH[a], F_NUM, 30, 240, 0, 48, ROW - 4, BONE, Enum.TextXAlignment.Center, 23)
		local sent = false
		b.MouseEnter:Connect(function() grad.Enabled = false; t.TextColor3 = DEEP; g.TextColor3 = DEEP end)
		b.MouseLeave:Connect(function() grad.Enabled = true; t.TextColor3 = BONE; g.TextColor3 = sent and FIELD or BONE end)
		local pop = new("UIScale", { Parent = b })
		b.Activated:Connect(function()
			pop.Scale = 1
			Kit.tween(pop, 0.07, { Scale = 1.06 })
			task.delay(0.07, function() Kit.tween(pop, 0.16, { Scale = 1 }, Enum.EasingStyle.Back) end)
			if a == "View Profile" then PlayerCards.Profile(p, false); return end
			local opened = run(a, p)
			-- sent once: the glyph turns into a grey tick (Invite / Challenge), RIVALS-style
			if not sent and ((a == "Invite" and opened) or a == "Challenge") then
				sent = true
				g.Text = ""
				-- a grey tick drawn from two bars (BuilderSans has no check mark glyph)
				for _, bar in { { 0.36, 0.6, 0.32, 45 }, { 0.58, 0.48, 0.62, -50 } } do
					new("Frame", { BorderSizePixel = 0, BackgroundColor3 = FIELD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(bar[1], bar[2]),
						Size = UDim2.fromScale(bar[3], 0.1), Rotation = bar[4], ZIndex = 24, Parent = g }, { Kit.corner(2) })
				end
			end
			if a == "Spectate" then t.Text = spectating == p and "Stop Spectating" or "Spectate" end
		end)
	end
	Kit.toScale(root)
	for _, c in panel:GetChildren() do if c:IsA("TextButton") then Kit.centreAnchor(c) end end
	-- slides out from under the list (from the right)
	local home = panel.Position
	panel.Position = UDim2.fromScale(home.X.Scale + 0.1, home.Y.Scale)
	panel.GroupTransparency = 1
	Kit.tween(panel, 0.18, { Position = home }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Kit.tween(panel, 0.14, { GroupTransparency = 0 })
	menu = { root = root, panel = panel, group = panel, catcher = catcher, home = home, player = p }
end

-- a player leaving closes whatever is open about them
Players.PlayerRemoving:Connect(function(p)
	if menu and menu.player == p then PlayerCards.CloseMenu() end
	if profile and profile.player == p then closeProfile() end
end)

---------------------------------------------------------------------------------------------------- challenge requests
-- RIVALS' request popup on the right under the player list: headshot with a draining timer bar, the name,
-- "challenges you to a duel!", red X (decline) and an olive tick (accept). Up to 4 stack, oldest on top.
-- Driven by ReplicatedStorage.LobbySocial (Tacticals session): server -> ("Request", from, expiresAt) / ("Closed", other, reason)
-- / ("Sent", target, ok, reason); client -> ("Respond", from, accept). Dormant until the remote exists.
local requests = {} -- from Player -> { panel, done }
local reqHolder
local REQ_W, REQ_H, REQ_GAP = 320, 132, 10
local function restack()
	local i = 0
	for _, r in requests do
		if not r.closing then
			i += 1
			Kit.tween(r.panel, 0.2, { Position = UDim2.fromScale(r.panel.Position.X.Scale, (i - 1) * (REQ_H + REQ_GAP) / 600 + r.panel.AnchorPoint.Y * r.panel.Size.Y.Scale) }, Enum.EasingStyle.Quint)
		end
	end
end
-- requests are keyed by sender + kind ("duel" = LobbySocial challenge, "party" = LobbyParty invite)
local function remoteFor(kind) return ReplicatedStorage:FindFirstChild(kind == "party" and "LobbyParty" or "LobbySocial") end
local function closeRequest(from, respond, kind)
	kind = kind or "duel"
	local key = from.UserId .. kind
	local r = requests[key]
	if not r or r.closing then return end
	r.closing = true
	local remote = remoteFor(kind)
	if respond ~= nil and remote then remote:FireServer("Respond", from, respond) end
	Kit.close(r.panel, function() r.panel:Destroy(); if requests[key] == r then requests[key] = nil end; restack() end)
end
local function tickMark(parent, color)
	for _, bar in { { 0.4, 0.58, 0.26, 45 }, { 0.57, 0.48, 0.48, -50 } } do
		new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(bar[1], bar[2]),
			Size = UDim2.fromScale(bar[3], 0.12), Rotation = bar[4], ZIndex = 33, Parent = parent }, { Kit.corner(2) })
	end
end
local function showRequest(from: Player, expiresAt: number?, kind: string?)
	kind = kind or "duel"
	local key = from.UserId .. kind
	ensureGui()
	if requests[key] then closeRequest(from, nil, kind) end
	local n = 0
	for _, r in requests do if not r.closing then n += 1 end end
	if n >= 4 then return end
	if not reqHolder then
		reqHolder = new("Frame", { Name = "Requests", BackgroundTransparency = 1, Position = UDim2.fromOffset(1590, 646), Size = UDim2.fromOffset(REQ_W, 600), ZIndex = 30, Parent = canvas })
		Kit.toScale(reqHolder)
	end
	local panel = new("Frame", { Name = from.Name, Position = UDim2.fromOffset(0, n * (REQ_H + REQ_GAP)), Size = UDim2.fromOffset(REQ_W, REQ_H), BackgroundColor3 = DEEP,
		BackgroundTransparency = 0.15, ZIndex = 30, Parent = reqHolder }, { Kit.corner(10), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1.5 }) })
	local hs = new("ImageLabel", { BackgroundColor3 = hex("#4F6B23"), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(86, 86), ZIndex = 31, Parent = panel }, { Kit.corner(8) })
	headshot(hs, from)
	local barBack = new("Frame", { Position = UDim2.fromOffset(12, 108), Size = UDim2.fromOffset(82, 8), BackgroundColor3 = hex("#3A3F36"), ClipsDescendants = true, ZIndex = 31, Parent = panel }, { Kit.corner(4) })
	local bar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BONE, ZIndex = 32, Parent = barBack }, { Kit.corner(4) })
	label(panel, from.DisplayName, F_NAME, 25, 108, 8, 204, 30, BONE, nil, 31)
	label(panel, kind == "party" and "invited you to their party!" or "challenges you to a duel!", F_SUB, 18, 108, 38, 204, 22, FIELD, nil, 31)
	local no = Kit.closeButton(UDim2.fromOffset(96, 48))
	no.Position = UDim2.fromOffset(108, 72); no.ZIndex = 31; no.Parent = panel
	local yes = Kit.button("key", UDim2.fromOffset(96, 48), nil, { Position = UDim2.fromOffset(212, 72), ZIndex = 31, Parent = panel })
	local cc = yes:FindFirstChildOfClass("UICorner"); if cc then cc.CornerRadius = UDim.new(0, 8) end
	local tickHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 32, Parent = yes })
	tickMark(tickHolder, Color3.new(1, 1, 1))
	Kit.toScale(panel)
	requests[key] = { panel = panel }
	Kit.open(panel)
	restack()
	local left = math.max(1, (expiresAt and expiresAt - workspace:GetServerTimeNow()) or 10)
	Kit.tween(bar, left, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
	no.Activated:Connect(function() closeRequest(from, false, kind) end)
	yes.Activated:Connect(function() closeRequest(from, true, kind) end)
	task.delay(left, function() closeRequest(from, nil, kind) end) -- the server expires it too ("Closed")
end
PlayerCards.ShowRequest = showRequest -- Studio tests: PlayerCards.ShowRequest(somePlayer, workspace:GetServerTimeNow() + 10, "party")
PlayerCards.CloseRequest = function(from, kind) closeRequest(from, nil, kind) end

local CLOSED_TEXT = { declined = "declined your challenge", expired = "didn't answer your challenge", busy = "is busy right now", cancelled = "cancelled the challenge" }
local function hookSocial(r)
	if not r:IsA("RemoteEvent") then return end
	r.OnClientEvent:Connect(function(kind, who, a, b)
		if typeof(who) ~= "Instance" or not who:IsA("Player") then return end
		if kind == "Request" then
			showRequest(who, tonumber(a))
		elseif kind == "Closed" then
			closeRequest(who, nil, "duel")
			if CLOSED_TEXT[a] then toast(who.DisplayName .. " " .. CLOSED_TEXT[a]) end
		elseif kind == "Sent" then
			if a then toast("Challenge sent to " .. who.DisplayName, "good") else toast(tostring(b or "Couldn't send the challenge")) end
		end
	end)
end
task.spawn(function()
	local r = ReplicatedStorage:FindFirstChild("LobbySocial")
	if r then hookSocial(r); return end
	local conn
	conn = ReplicatedStorage.ChildAdded:Connect(function(c)
		if c.Name == "LobbySocial" then conn:Disconnect(); hookSocial(c) end
	end)
end)
Players.PlayerRemoving:Connect(function(p) closeRequest(p, nil, "duel"); closeRequest(p, nil, "party") end)

---------------------------------------------------------------------------------------------------- world: hover + double click
function PlayerCards.StartWorld(allowed: () -> boolean)
	ensureGui()
	local mouse = player:GetMouse()
	local hint = new("Frame", { Name = "ProfileHint", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(310, 38), BackgroundColor3 = DEEP, BackgroundTransparency = 0.25,
		Visible = false, ZIndex = 30, Parent = canvas }, { Kit.corner(21), new("UIStroke", { Color = BONE, Thickness = 1.5, Transparency = 0.35 }) })
	-- live RIVALS says "Double tap" on PC too
	label(hint, "Double tap to view profile", F_NAME, 21, 0, 0, 310, 38, BONE, Enum.TextXAlignment.Center, 31)
	Kit.toScale(hint, Vector2.new(310, 38))
	hint.Size = UDim2.fromScale(310 / 1920, 38 / 1080)
	-- a ray from the pointer (Mouse.Target skips your own character; RIVALS opens your own card too)
	local function playerUnder()
		local cam = workspace.CurrentCamera
		local at = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(at.X, at.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300)
		local t = hit and hit.Instance
		while t and t ~= workspace do
			local p = Players:GetPlayerFromCharacter(t)
			if p then return p end
			t = t.Parent
		end
		return nil
	end
	local function ok() return not profile and not menu and allowed() end
	RunService.RenderStepped:Connect(function()
		-- touch has no hover: the hint only follows a mouse
		local p = (not UserInputService.TouchEnabled or UserInputService.MouseEnabled) and ok() and playerUnder() or nil
		hint.Visible = p ~= nil
		if p then
			-- GetMouseLocation counts the top bar; AbsolutePosition on an IgnoreGuiInset gui doesn't (its origin sits at -inset)
			local at = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			local ca, cs = canvas.AbsolutePosition, canvas.AbsoluteSize
			hint.Position = UDim2.fromScale((at.X - ca.X) / cs.X, (at.Y - 14 - ca.Y) / cs.Y)
		end
	end)
	local lastClick, lastWho = 0, nil
	mouse.Button1Down:Connect(function()
		local p = ok() and playerUnder() or nil
		if not p then return end
		if p == lastWho and os.clock() - lastClick < 0.4 then
			lastWho = nil
			PlayerCards.Profile(p, true)
		else
			lastWho, lastClick = p, os.clock()
		end
	end)
end

return PlayerCards
