-- UIKit/PlayerCards (ModuleScript): RIVALS' "click a player" UI in TACTICALS' look (UI session 2026-10-17, overnight gap audit).
--   * PlayerCards.Menu(p, row): the player menu that slides out to the left of the player list (click a row). Header = headshot,
--     display name, @username; one row per action, each fading from the panel colour into its own colour, white on hover.
--     Lobby players: Invite / Add Friend / Challenge / View Profile / View Avatar / Block. In a duel: Spectate instead of
--     Invite / Challenge. Yourself: View Profile / View Avatar. Challenge + Spectate only show once the Tacticals session's
--     ReplicatedStorage.LobbySocial remote exists (contract in notes/lobby_social.md).
--   * PlayerCards.Profile(p, world): the profile card over a blurred lobby, laid out like live RIVALS (checked 2026-10-17):
--     headshot + gold trophy + wins + win rate on the left; name + device, @username, the blue level seal, then Most Played
--     Weapons (2026-10-21, RIVALS 1:1: ELO / Rank / Career tiles dropped from the card). Red X under it, plus Invite to
--     PARTY / Challenge 1v1 for anyone else (from the list or the world).
--   * PlayerCards.StartWorld(allowed): hovering a character shows "Double click to view profile" (touch: tap), a double
--     click / tap opens the card. allowed() says when the lobby is up (no menu, no duel, no training).
-- (2026-10-21, RIVALS 1:1) the menu and the profile card are now copies of RIVALS' own (notes/ui_rivals/rivals_live_notes.md,
-- "Profile, player menu, level badge, news"): colours / fonts from UIKit.Rivals.Theme (tok(): Theme.profile[name] overrides the
-- replica's measured values), icons / art from UIKit.Rivals.Assets, the level as UIKit.Kit.levelSeal. Behaviour unchanged.
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
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer
-- (2026-10-21, RIVALS 1:1) UIKit.Rivals: Theme (colours / fonts), Assets (icons, art)
local RIV = UIKit:WaitForChild("Rivals")
local RTheme = require(RIV:WaitForChild("Theme"))
local RAssets = require(RIV:WaitForChild("Assets"))
local RC, RF = RTheme.color, RTheme.font
local F_BOLD = Font.new(RF.medium.Family, Enum.FontWeight.Bold) -- Rubik Bold (the replica's FB)
local function tok(name, default)
	local t = RTheme.profile
	if t and t[name] ~= nil then return t[name] end
	return default
end
-- an asset by key from any table of UIKit.Rivals.Assets (hud.arrow, tasks.trophy_gold, ...), nil if absent
local function rasset(key)
	if not key then return nil end
	for _, t in RAssets do
		if type(t) == "table" and type(t[key]) == "string" and t[key] ~= "" then return t[key] end
	end
	return nil
end
-- the shared menu backdrop (Modules.Shared.UITheme: blur + scrim + vignette), nil in a place without it
local function sharedTheme()
	local ok, m = pcall(function()
		local sh = ReplicatedStorage:FindFirstChild("Modules")
		sh = sh and sh:FindFirstChild("Shared")
		local u = sh and sh:FindFirstChild("UITheme")
		return u and require(u)
	end)
	return ok and m or nil
end

-- (2026-10-21, AI-tells cleanup) Builder Sans is out: names / body in Rubik (F_NAME bold, F_SUB medium)
local RUBIK = "rbxassetid://12187365977"
local F_NAME = Font.new(RUBIK, Enum.FontWeight.Bold)
local F_SUB = Font.new(RUBIK, Enum.FontWeight.Medium)
local BONE, FIELD, DEEP = hex("#ECE8DA"), hex("#969C8C"), hex("#0C0E0B") -- (2026-10-21, RIVALS 1:1) the request popups still use these; Oswald / olive / gun-grey retired with the old card + menu

local PlayerCards = {}

-- (2026-10-20, Edward) Roblox badges with the name: Premium before, verified after (UIKit.Badges; Settings > Display Badges)
local function badgeName(p)
	local ok, B = pcall(function() return require(game:GetService("ReplicatedStorage").UIKit.Badges) end)
	return (ok and B) and B.Name(p) or p.DisplayName
end
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
	if p.backdrop then
		local UITheme = sharedTheme()
		if UITheme then UITheme.HideBackdrop("PlayerCard") end -- (2026-10-21, RIVALS 1:1) the shared backdrop lets go
	elseif blur then Kit.tween(blur, 0.2, { Size = 0 }) end
	Kit.tween(p.tint, 0.15, { BackgroundTransparency = 1 })
	Kit.close(p.card, function() p.root:Destroy(); p.tint:Destroy() end)
	for _, b in p.buttons do b.Visible = false end
end
PlayerCards.CloseProfile = closeProfile
function PlayerCards.ProfileOpen() return profile ~= nil end

-- (2026-10-21, RIVALS 1:1) "Most Played Weapons": the player's top 4 items by matches played (then kills). Sources, best first:
-- the Player attribute MostPlayed ("Id,Id,Id,Id", for when PublicStats publishes it), your own Data.WeaponStats (Registry
-- PlayerData replica), else RIVALS' starter four in our kit (Automatic Rifle / Pistol / Fists / Frag as placeholders).
local MOST_PLAYED_FALLBACK = { "AutoRifle", "Pistol", "Fists", "Frag" }
local function lobbyConfig()
	local ok, cfg = pcall(function() return require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig) end)
	return ok and cfg or nil
end
local function itemName(id)
	local cfg = lobbyConfig()
	local it = cfg and cfg.Items and cfg.Items[id]
	return (it and it.Name) or id
end
local function topFromStats(ws)
	if type(ws) ~= "table" then return nil end
	local cfg = lobbyConfig()
	local list = {}
	for id, r in ws do
		if type(r) == "table" and (tonumber(r.Matches) or 0) > 0 and (not cfg or not cfg.Items or cfg.Items[id]) then
			table.insert(list, { id = id, m = tonumber(r.Matches) or 0, k = tonumber(r.Kills) or 0 })
		end
	end
	if #list == 0 then return nil end
	table.sort(list, function(a, b) if a.m ~= b.m then return a.m > b.m end return a.k > b.k end)
	local out = {}
	for i = 1, math.min(4, #list) do out[i] = list[i].id end
	return out
end
local function mostPlayed(p, myData)
	local attr = p:GetAttribute("MostPlayed")
	if type(attr) == "string" and attr ~= "" then
		local out = {}
		for id in attr:gmatch("[^,%s]+") do if #out < 4 then table.insert(out, id) end end
		if #out > 0 then return out end
	end
	if p == player and myData then
		local top = topFromStats(myData.WeaponStats)
		if top then return top end
	end
	return MOST_PLAYED_FALLBACK
end
-- your own PlayerStore replica (the client Registry's PlayerData), fetched once in the background
local myData
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts", 30)
	local reg = ps and ps:FindFirstChild("Registry", true)
	local pd = reg and reg:WaitForChild("PlayerData", 30)
	if not pd then return end
	local ok, replica = pcall(function() return require(pd):GetMyReplica() end)
	if ok and replica then myData = replica.Data end
end)
-- the lobby's live 3D item icons (LobbyUIController/Icons): a ViewportFrame render of the item, else its name only
local IconsMod
local function icons()
	if IconsMod ~= nil then return IconsMod or nil end
	IconsMod = false
	pcall(function()
		local ps = player:FindFirstChild("PlayerScripts")
		local luc = ps and ps:FindFirstChild("LobbyUIController", true)
		local m = luc and luc:FindFirstChild("Icons")
		if m then IconsMod = require(m) end
	end)
	return IconsMod or nil
end

-- (2026-10-21, RIVALS 1:1) the profile card, a copy of RIVALS' (notes/ui_rivals/rivals_normal/profile_card.png, measured on
-- the 1920x1010 capture / 0.935 into design px; the replica's openProfile): a 498 x 292 dark card with a faded map picture at
-- the top. Left column: headshot, gold trophy, "N wins", "N% win rate". Right: name + device icon, @user, the centred blue
-- level seal (UIKit.Kit.levelSeal) with a grey "Level" under it, then "Most Played Weapons" with four tiles (render + name).
-- Red X centred under it (plus our Invite to PARTY / Challenge 1v1 for anyone else). Behind: the shared menu backdrop
-- (Modules.Shared.UITheme.ShowBackdrop) when the place has it, else our blur + scrim. Our ELO / Rank / Career numbers are
-- gone from the card (RIVALS shows none of them); the attributes are untouched.
local W, H, CX, CY = 498, 292, 711, 344
function PlayerCards.Profile(p: Player, world: boolean?)
	ensureGui()
	PlayerCards.CloseMenu()
	if profile then profile.root:Destroy(); profile.tint:Destroy(); profile = nil end
	local UITheme = sharedTheme()
	if not UITheme then blur = Lighting:FindFirstChild("PlayerCardBlur") or new("BlurEffect", { Name = "PlayerCardBlur", Size = 0, Parent = Lighting }) end
	-- the tint covers the whole screen (outside the 16:9 canvas too); a click on it closes
	local tint = new("TextButton", { Name = "ProfileTint", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = RC.scrim,
		BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	local root = new("Frame", { Name = "Profile", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), ZIndex = 2, Parent = canvas })
	local card = new("Frame", { Name = "Card", Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(W, H), BackgroundColor3 = tok("card", hex("#1E1F24")),
		ClipsDescendants = true, ZIndex = 2, Parent = root }, { Kit.corner(8) })
	-- the faded map picture behind the top of the card (RIVALS: the lobby's wall), dark from the middle down
	local mapImg = rasset("map_arena")
	if mapImg then
		new("ImageLabel", { BackgroundTransparency = 1, Image = mapImg, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.55, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = card })
	end
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = tok("card", hex("#1E1F24")), ZIndex = 2, Parent = card },
		{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(1, 0.05) }) }) })
	local matches, wins = p:GetAttribute("StatMatches") or 0, p:GetAttribute("Wins") or 0
	local rate = matches > 0 and math.floor(100 * wins / matches + 0.5) or 0
	-- left column: headshot, trophy, wins, win rate (RIVALS gold, chunky numbers with a dark-brown edge)
	local hs = new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 20), Size = UDim2.fromOffset(92, 92), ZIndex = 3, Parent = card })
	headshot(hs, p)
	local trophy = rasset("trophy_gold")
	new("ImageLabel", { BackgroundTransparency = 1, Image = trophy or rasset("trophy") or "", ImageColor3 = trophy and Color3.new(1, 1, 1) or RC.gold, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(47, 122), Size = UDim2.fromOffset(44, 44), ZIndex = 3, Parent = card })
	local function goldText(text, y, size, font)
		local l = label(card, text, font, size, 8, y, 122, size + 2, RC.gold, Enum.TextXAlignment.Center, 3)
		l.TextTruncate = Enum.TextTruncate.None
		new("UIStroke", { Color = tok("goldEdge", hex("#5A3A00")), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	end
	goldText(commas(wins), 172, 26, RF.chunky)
	goldText("wins", 197, 15, F_BOLD)
	goldText(rate .. "%", 216, 28, RF.chunky)
	goldText("win rate", 240, 15, F_BOLD)
	-- right: name + device icon, @username
	local nameRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(136, 18), Size = UDim2.fromOffset(350, 34), ZIndex = 3, Parent = card },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local nm = label(nameRow, badgeName(p), F_BOLD, 28, 0, 0, 0, 34, RC.text, nil, 3)
	nm.LayoutOrder, nm.AutomaticSize, nm.TextTruncate = 1, Enum.AutomaticSize.X, Enum.TextTruncate.None
	local okB, B = pcall(function() return require(UIKit:WaitForChild("Badges", 2)) end)
	local dev = (okB and B and B.DeviceIcon) and B.DeviceIcon(p) or nil
	if dev then new("ImageLabel", { LayoutOrder = 2, BackgroundTransparency = 1, Image = dev, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(24, 24), ZIndex = 3, Parent = nameRow }) end
	label(card, "@" .. p.Name, F_SUB, 16, 136, 49, 340, 18, tok("handle", hex("#8E8D94")), nil, 3)
	-- the level: RIVALS' blue starburst seal, centred over the right area, "Level" in grey under it
	-- (2026-10-22, live RIVALS profile at 16:9) a player on a win streak shows Level AND Streak side by side (the seal at ~51 % of
	-- the card, the flame with its number at ~73 %); no streak = the seal alone, centred over the right area as before
	local streakN = tonumber(p:GetAttribute("WinStreak")) or 0
	local levelX = streakN > 0 and 256 or 316
	local seal = Kit.levelSeal(card, p:GetAttribute("Level") or 1, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(levelX, 84), Size = UDim2.fromOffset(54, 54), ZIndex = 3 })
	seal.Name = "LevelSeal"
	label(card, "Level", F_BOLD, 20, levelX - 50, 136, 100, 24, tok("levelLabel", hex("#8E8D94")), Enum.TextXAlignment.Center, 3)
	if streakN > 0 and Kit.streak then
		Kit.streak(card, streakN, UDim2.fromOffset(366 - 29, 80), UDim2.fromOffset(58, 58), 3)
		label(card, "Streak", F_BOLD, 20, 316, 136, 100, 24, tok("levelLabel", hex("#8E8D94")), Enum.TextXAlignment.Center, 3)
	end
	-- Most Played Weapons: four tiles, a grey-to-dark fill, the render filling the tile and the name over its foot
	label(card, "Most Played Weapons", F_BOLD, 16, 146, 184, 340, 20, tok("mostPlayed", hex("#C9C9CF")), Enum.TextXAlignment.Center, 3)
	local tiles = {}
	for i = 1, 4 do
		local t = new("Frame", { Name = "Weapon" .. i, Position = UDim2.fromOffset(147 + (i - 1) * 91, 211), Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 3, Parent = card }, { Kit.corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(tok("tileTop", hex("#6E6E78")), tok("tileBottom", hex("#26262C"))) }) })
		local nameL = label(t, "", F_BOLD, 15, -8, 54, 88, 18, RC.text, Enum.TextXAlignment.Center, 5)
		nameL.TextTruncate = Enum.TextTruncate.None
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.2, Parent = nameL })
		tiles[i] = { frame = t, name = nameL }
	end
	-- buttons under the card: the X, and for anyone else INVITE / CHALLENGE beside it (live RIVALS: from the list too)
	local buttons = {}
	local by = CY + H + 16
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
		label(b, a[2], F_SUB, 15, 0, 5, 150, 18, RC.textDark, Enum.TextXAlignment.Center, 4).TextTransparency = 0.35
		local big = label(b, a[1], RF.chunky, 32, 0, 20, 150, 40, RC.text, Enum.TextXAlignment.Center, 4)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.5, Parent = big })
		b.Activated:Connect(a[4])
		table.insert(buttons, b)
	end
	close.Activated:Connect(closeProfile)
	tint.Activated:Connect(closeProfile)
	Kit.toScale(root)
	-- the tiles' renders go in after Kit.toScale (the ViewportFrames are Scale already); refilled once your own stats load
	local function fill(ids)
		local I = icons()
		for i, t in tiles do
			local id = ids[i]
			local old = t.frame:FindFirstChild("Render")
			if old then old:Destroy() end
			t.name.Text = id and itemName(id) or ""
			t.name:SetAttribute("dTS", #t.name.Text > 11 and 12 or 15) -- design px; long names a size down (RIVALS' "Assault Rifle")
			if id and I and I.Item and I.Viewport then
				-- (2026-10-22, main PC check vs profile_card.png) RIVALS' renders fill the tile and break out of its top edge;
				-- ours sat small inside it
				local holder = new("Frame", { Name = "Render", BackgroundTransparency = 1, Position = UDim2.fromScale(-0.14, -0.32), Size = UDim2.fromScale(1.28, 1.2), ZIndex = 4, Parent = t.frame })
				pcall(function()
					local model, view, zoom = I.Item(id)
					local ctl = I.Viewport(holder, model, { view = view, zoom = zoom })
					ctl.Frame.ZIndex = 4
				end)
			end
		end
		Kit.rescaleText()
	end
	local shown = mostPlayed(p, myData)
	fill(shown)
	profile = { root = root, tint = tint, card = card, buttons = buttons, player = p, backdrop = UITheme ~= nil }
	if p == player and not myData then
		local mine = profile
		task.delay(1.5, function()
			if profile == mine and myData then
				local top = mostPlayed(p, myData)
				if top ~= shown then fill(top) end
			end
		end)
	end
	if UITheme then
		UITheme.ShowBackdrop("PlayerCard", 1)
	else
		Kit.tween(blur, 0.25, { Size = Theme.blur })
		Kit.tween(tint, 0.25, { BackgroundTransparency = RTheme.alpha.scrim })
	end
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

-- (2026-10-21, RIVALS 1:1) RIVALS' row colours (the replica's ACTION_COLOR, from Edward's captures t0110 / t0130): green for the
-- friendly ones, orange for Challenge / Spectate, blue for View Profile / View Avatar, red for Block. Read from
-- UIKit.Rivals.Theme.playerMenu[name] when the Theme has it. Icons = the replica's white flat icons (UIKit.Rivals.Assets).
local ACTION_COLOR = {
	["Invite"] = "#3E9A1C", ["Add Friend"] = "#3E9A1C", ["Challenge"] = "#B7741B", ["Spectate"] = "#B7741B",
	["View Profile"] = "#1A5A93", ["View Avatar"] = "#1A5A93", ["Block"] = "#9A2626",
}
local ACTION_ICON = { ["Invite"] = "plus", ["Add Friend"] = "addfriend", ["Challenge"] = "inking", ["Spectate"] = "eye",
	["View Profile"] = "arrow", ["View Avatar"] = "arrow", ["Block"] = "hide" }
local ACTION_TEXT = { ["Invite"] = "Party Invite" } -- RIVALS' wording; the action keys stay ours
local function actionColor(a)
	local t = RTheme.playerMenu
	return (t and t[a]) or hex(ACTION_COLOR[a] or "#1A5A93")
end

-- (2026-10-21, RIVALS 1:1) the player menu, RIVALS' look (t0110 / t0130 / t0111; the replica's openPlayerMenu): a dark 303 px
-- card left of the list, headshot (bare head), display name + @username, then one row per action. A row fades from the card
-- colour into its own colour with a white icon on that end; the hovered row is solid white with black text and a black icon.
-- Same actions / behaviour as before (Invite, Add Friend, Challenge, View Profile, View Avatar, Block; Spectate paused).
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
	local PW, ROW, HEAD = 303, 55.6, 80
	local H = HEAD + #actions * ROW + 6
	local top = math.clamp(rowY, 10, 1080 - H - 10)
	local cardCol = tok("card", hex("#1E1F24"))
	local root = new("Frame", { Name = "PlayerMenu", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), ZIndex = 20, Parent = canvas })
	-- a click anywhere else closes it (the catcher covers the whole screen, under the panel)
	local catcher = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = gui })
	catcher.Activated:Connect(PlayerCards.CloseMenu)
	local panel = new("CanvasGroup", { Name = "Panel", Position = UDim2.fromOffset(rightX - 4 - PW, top), Size = UDim2.fromOffset(PW, H),
		BackgroundColor3 = cardCol, BackgroundTransparency = 0.05, ZIndex = 21, Parent = root }, { Kit.corner(8) })
	local hs = new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 8), Size = UDim2.fromOffset(64, 64), ZIndex = 22, Parent = panel }) -- live: a bare head, no circle
	headshot(hs, p)
	label(panel, badgeName(p), F_BOLD, 21, 105, 12, 190, 28, RC.text, nil, 22)
	label(panel, "@" .. p.Name, F_SUB, 14, 105, 42, 190, 18, tok("menuHandle", hex("#C9C9CF")), nil, 22)
	local checkImg, sentGrey = rasset("check"), tok("sent", hex("#8A8A8A"))
	for i, a in actions do
		local col = actionColor(a)
		local b = new("TextButton", { Name = a, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(3, HEAD + (i - 1) * ROW), Size = UDim2.fromOffset(PW - 6, 52),
			BackgroundColor3 = RC.white, ZIndex = 22, Parent = panel }, { Kit.corner(4) })
		local grad = new("UIGradient", { Color = ColorSequence.new(cardCol, col), Parent = b })
		local t = label(b, ACTION_TEXT[a] or a, F_BOLD, 17, 19, 0, 200, 52, RC.text, nil, 23)
		local img = rasset(ACTION_ICON[a])
		local ic = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = img or "", ImageColor3 = RC.white, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 26), Size = UDim2.fromOffset(40, 40), ZIndex = 23, Parent = b })
		local sent = false
		b.MouseEnter:Connect(function() grad.Enabled = false; t.TextColor3 = RC.textDark; if not sent then ic.ImageColor3 = RC.textDark end end)
		b.MouseLeave:Connect(function() grad.Enabled = true; t.TextColor3 = RC.text; ic.ImageColor3 = sent and sentGrey or RC.white end)
		-- (2026-10-21, RIVALS pass) Kit.bindButton (hover lift + press squash). One UIScale, named PopScale, so the stagger-in
		-- (Kit.popIn below) and the hover share it.
		new("UIScale", { Name = "PopScale", Parent = b })
		Kit.bindButton(b, { hover = 1.03 })
		b.Activated:Connect(function()
			if a == "View Profile" then PlayerCards.Profile(p, false); return end
			local opened = run(a, p)
			-- sent once: the icon turns into RIVALS' grey check (Invite / Challenge)
			if not sent and ((a == "Invite" and opened) or a == "Challenge") then
				sent = true
				if checkImg then ic.Image = checkImg end
				ic.ImageColor3 = sentGrey
			end
			if a == "Spectate" then t.Text = spectating == p and "Stop Spectating" or "Spectate" end
		end)
	end
	Kit.toScale(root)
	for _, c in panel:GetChildren() do if c:IsA("TextButton") then Kit.centreAnchor(c) end end
	-- (2026-10-21, RIVALS pass) the rows fill in one after another as the panel slides out (RIVALS t0110 -> t0111)
	for i, a in actions do
		local b = panel:FindFirstChild(a)
		if b then Kit.popIn(b, 0.04 + i * 0.04) end
	end
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
		BackgroundTransparency = 0.15, ZIndex = 30, Parent = reqHolder }, { Kit.corner(10) }) -- (2026-10-21, AI-tells cleanup) request panel: hairline border removed
	local hs = new("ImageLabel", { BackgroundColor3 = hex("#4C7A2E"), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(86, 86), ZIndex = 31, Parent = panel }, { Kit.corner(8) })
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
	-- (2026-10-21, RIVALS 1:1) RIVALS' pill (t0135): see-through dark grey, white Rubik Bold (was our bone-on-black)
	local hint = new("Frame", { Name = "ProfileHint", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(310, 38), BackgroundColor3 = tok("hint", hex("#3A3A40")), BackgroundTransparency = 0.35,
		Visible = false, ZIndex = 30, Parent = canvas }, { Kit.corner(19) })
	-- live RIVALS says "Double tap" on PC too
	local hl = label(hint, "Double tap to view profile", F_BOLD, 21, 0, 0, 310, 38, RC.text, Enum.TextXAlignment.Center, 31)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6, Parent = hl })
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
		-- (2026-10-21, grade2) the hint only shows over OTHER players: it sat on your own character at rest (the camera looks
		-- through you). Double-clicking yourself still opens your own card, it just isn't advertised.
		if p == player then p = nil end
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
