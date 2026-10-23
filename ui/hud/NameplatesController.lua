-- Client/Controllers/NameplatesController (ModuleScript, auto-loaded): RIVALS' lobby nameplates in our look.
-- Over every player in the lobby: a stat badge (Level or Wins: Settings > Video > Interface > Lobby Data), the display
-- name big and bold, @username small under it (only when it differs from the display name), and a VIP chip for VIPs. Sized in studs (shrinks with distance), not
-- AlwaysOnTop (walls hide it: Roblox's own names were turned off because they showed through walls).
-- Not shown in Training, during a cutscene, or when you hide the HUD. (UI session 2026-10-16)
-- (2026-10-21, RIVALS 1:1) one row like RIVALS (notes/rivals_rec/t0000, t0135): [blue level seal] Name [device icon], the name
-- white Rubik Bold with a dark outline (UIKit.Rivals.Theme). The win-streak flame takes the seal's place on a streak. The seal is
-- UIKit.Kit.levelSeal (was our tiered shield). Sized like the replica's plate (10 x 1.6 studs, row 62 %), the name label sized to
-- its text so the seal and device icon hug it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Nameplates = {}
local player = Players.LocalPlayer
-- (2026-10-21, RIVALS 1:1) fonts / colours from UIKit.Rivals.Theme: the name in Rubik Bold (RIVALS' plate), @username in Rubik
-- Medium (was Oswald Bold / Rubik Medium literals)
local RTheme
pcall(function() RTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Rivals", 10):WaitForChild("Theme", 10)) end)
local RUBIK = (RTheme and RTheme.font.medium.Family) or "rbxassetid://12187365977"
local BOLD = Font.new(RUBIK, Enum.FontWeight.Bold)
local MED = (RTheme and RTheme.font.medium) or Font.new(RUBIK, Enum.FontWeight.Medium)
local WHITE = (RTheme and RTheme.color.text) or Color3.new(1, 1, 1)
local DIM = (RTheme and RTheme.color.textDim) or Color3.fromRGB(205, 205, 212)
local PANEL = (RTheme and RTheme.color.panel) or Color3.fromRGB(20, 18, 24)
local W_STUDS, H_STUDS, ROW = 10, 1.6, 0.62 -- plate size in studs, the name row's share of the height (the replica's plate)

local plates = {} -- [Player] = { gui, badgeText, nameText, vip }

local RankArt
pcall(function() RankArt = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("RankArt", 10)) end)
local function statOf(p)
	local mode = player:GetAttribute("Setting_LobbyData")
	if mode == "Rank" and RankArt then return "Rank", RankArt.Of(p) end
	local which = mode == "Wins" and "Wins" or "Level"
	return which, p:GetAttribute(which) or 0
end

local function build(p, character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end
	local old = plates[p]
	if old and old.gui then old.gui:Destroy() end
	local g = Instance.new("BillboardGui")
	g.Name = "Nameplate_" .. p.UserId
	g.Enabled = false -- (2026-10-20) starts hidden: the 0.25 s update decides (a respawn mid-duel flashed a blank plate)
	g.Adornee = head
	-- (2026-10-21, grade1) your own plate is ~55% size: over your own back it filled the middle of the hub screen
	local mine = p == player
	-- (2026-10-21, RIVALS 1:1) 10 x 1.6 studs like the replica (was 9 x 2: the name read a size too big next to RIVALS')
	g.Size = mine and UDim2.fromScale(W_STUDS * 0.55, H_STUDS * 0.55) or UDim2.fromScale(W_STUDS, H_STUDS) -- studs
	g.StudsOffset = Vector3.new(0, mine and 1.5 or 2.2, 0)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.ResetOnSpawn = false
	g.Parent = player:WaitForChild("PlayerGui")
	-- row: [badge] Name [VIP]
	-- (2026-10-21, grade1) one name like RIVALS: the @username line only when it differs from the display name
	-- ("whitteguy / @whitteguy" said it twice); without it the name row sits low, on the head
	local showHandle = p.DisplayName:lower() ~= p.Name:lower()
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = showHandle and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.3)
	row.Size = UDim2.fromScale(1, ROW)
	row.Parent = g
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	-- (2026-10-22, spacing grade vs RIVALS) no shared padding: each gap is its own spacer, sized to RIVALS' visible (ink) gaps in
	-- cap heights - seal 0.65, name -> Premium 0.6, Premium -> device 0.95 (the even 8/8/8 frame gaps read uneven)
	list.Padding = UDim.new(0, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local badge = Instance.new("Frame")
	badge.LayoutOrder = 10
	badge.Size = UDim2.fromScale(0.2, 1) -- (2026-10-21, RIVALS 1:1) square, the row's height (aspect constraint below)
	badge.BackgroundColor3 = PANEL
	badge.BackgroundTransparency = 1
	badge.Parent = row
	local ba = Instance.new("UIAspectRatioConstraint"); ba.AspectRatio = 1; ba.DominantAxis = Enum.DominantAxis.Height; ba.Parent = badge
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.25, 0); bc.Parent = badge
	local bt = Instance.new("TextLabel")
	bt.BackgroundTransparency = 1
	bt.Size = UDim2.fromScale(1, 1)
	bt.FontFace = BOLD
	bt.TextScaled = true
	bt.TextColor3 = WHITE
	bt.Text = "" -- (2026-10-20) never Roblox's default "Label" before the first update fills it
	bt.Parent = badge
	local bp = Instance.new("UIPadding"); bp.PaddingTop = UDim.new(0.12, 0); bp.PaddingBottom = UDim.new(0.12, 0); bp.Parent = bt
	-- Lobby Data = Rank: the ranked emblem, a little bigger than the badge
	local bi = Instance.new("ImageLabel")
	bi.Name = "RankEmblem"
	bi.BackgroundTransparency = 1
	bi.AnchorPoint = Vector2.new(0.5, 0.5)
	bi.Position = UDim2.fromScale(0.5, 0.5)
	bi.Size = UDim2.fromScale(1.35, 1.35)
	bi.ScaleType = Enum.ScaleType.Fit
	bi.Visible = false
	bi.Parent = badge
	bt.ZIndex = bi.ZIndex + 1 -- the number sits over the rank emblem
	-- (2026-10-21, RIVALS 1:1) the level: RIVALS' blue starburst seal with the white number (UIKit.Kit.levelSeal)
	local KitM = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
	local seal = KitM.levelSeal(badge, p:GetAttribute("Level") or 1, { ZIndex = bt.ZIndex + 1, Visible = false })
	local name = Instance.new("TextLabel")
	name.LayoutOrder = 20
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.62, 1) -- (TextScaled and AutomaticSize don't mix: fitName() sets the width from the text)
	name.FontFace = BOLD
	name.TextScaled = true
	name.TextColor3 = WHITE
	name.Text = p.DisplayName
	name.Name = "DisplayName" -- (2026-10-20) badges are added by the update loop (UIKit.Badges)
	name.Parent = row
	-- (2026-10-21, RIVALS 1:1) RIVALS' dark outline round the white name
	-- (2026-10-22, names study) a thin 1 px edge at 0.5: UIStroke is in pixels, so the old 2 px muddied a far / own (55 %) plate
	local ns = Instance.new("UIStroke"); ns.Color = Color3.new(0, 0, 0); ns.Thickness = 1; ns.Transparency = 0.5; ns.Parent = name
	-- the verified / Premium glyph in its own label (no stroke, cap height) instead of inside the stroked name text
	local glyph = Instance.new("TextLabel")
	glyph.Name = "BadgeGlyph"
	glyph.LayoutOrder = 30
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(0.093, 1.28) -- (2026-10-22) ink ~1.2 cap like RIVALS' P (was 0.62, half size)
	glyph.FontFace = BOLD
	glyph.TextScaled = true
	glyph.TextColor3 = WHITE
	glyph.Text = ""
	glyph.Visible = false
	glyph.Parent = row
	local ga = Instance.new("UIAspectRatioConstraint"); ga.AspectRatio = 1; ga.DominantAxis = Enum.DominantAxis.Height; ga.Parent = glyph -- (a square box: a narrower one draws nothing, TextScaled gives up on the glyph)
	local vip = Instance.new("TextLabel")
	vip.LayoutOrder = 40
	vip.Size = UDim2.fromScale(0.15, 0.7)
	vip.BackgroundColor3 = Color3.fromRGB(236, 230, 210) -- (2026-10-21, AI-tells cleanup) tag yellow -> cream #ECE6D2
	vip.FontFace = BOLD
	vip.TextScaled = true
	vip.TextColor3 = Color3.fromRGB(30, 24, 8)
	vip.Text = "VIP"
	vip.Visible = p:GetAttribute("VIP") == true
	vip.Parent = row
	local vc = Instance.new("UICorner"); vc.CornerRadius = UDim.new(0.3, 0); vc.Parent = vip
	local user = Instance.new("TextLabel")
	user.BackgroundTransparency = 1
	user.Position = UDim2.fromScale(0, 0.62)
	user.Size = UDim2.fromScale(1, 0.3)
	user.FontFace = MED
	user.TextScaled = true
	user.TextColor3 = DIM
	user.Text = "@" .. p.Name
	user.Visible = showHandle
	user.Parent = g
	local us = Instance.new("UIStroke"); us.Thickness = 1; us.Transparency = 0.65; us.Parent = user -- (2026-10-22) barely-there edge on the grey @handle
	-- the old server VIP tag sits in the same spot: ours carries the VIP chip now
	local oldVip = head:FindFirstChild("VipTag")
	if oldVip and oldVip:IsA("BillboardGui") then oldVip.Enabled = false end
	head.ChildAdded:Connect(function(c) if c.Name == "VipTag" and c:IsA("BillboardGui") then c.Enabled = false end end)
	-- (2026-10-18) the win streak: RIVALS' flame with the number over it, right of the name
	local streak = Instance.new("Frame")
	streak.Name = "StreakHolder"
	streak.LayoutOrder = 0 -- (2026-10-20, Edward) the flame takes the badge's place, left of the name
	streak.BackgroundTransparency = 1
	streak.Size = UDim2.fromScale(0.26, 1.3) -- (2026-10-22, RIVALS) the flame is ~1.3x the line height
	streak.Visible = false
	streak.Parent = row
	local sa = Instance.new("UIAspectRatioConstraint"); sa.AspectRatio = 1; sa.DominantAxis = Enum.DominantAxis.Height; sa.Parent = streak
	local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
	local flame = Kit.streak(streak, 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
	-- (2026-10-22, names study) a readable number: bigger, white with a thin dark edge (the orange edge sank into the flame)
	do
		local n = flame:FindFirstChild("N")
		if n then
			n.Size = UDim2.fromScale(0.8, 0.56); n.Position = UDim2.fromScale(0.5, 0.66)
			local st = n:FindFirstChildOfClass("UIStroke"); if st then st.Color = Color3.fromRGB(60, 20, 8); st.Thickness = 1.2; st.Transparency = 0.1 end
		end
	end
	-- (2026-10-20, RIVALS) the device icon after the name (UIKit.Badges.DeviceIcon; hidden until the art is uploaded)
	local dev = Instance.new("ImageLabel")
	dev.Name = "Device"
	dev.LayoutOrder = 50
	dev.BackgroundTransparency = 1
	dev.ScaleType = Enum.ScaleType.Fit
	dev.Size = UDim2.fromScale(0.2, 1.28) -- (2026-10-22, spacing grade) ~1.3 cap like RIVALS' monitor (0.62 read half size)
	dev.ImageColor3 = WHITE
	dev.Visible = false
	dev.Parent = row
	local da = Instance.new("UIAspectRatioConstraint"); da.AspectRatio = 1; da.DominantAxis = Enum.DominantAxis.Height; da.Parent = dev
	-- the spacers (share of the plate width; the row is ~247 px at a 1268 px screen): each shows only while the piece after it does
	local function gap(order, share, after, before)
		local f = Instance.new("Frame")
		f.Name = "Gap" .. order
		f.LayoutOrder = order
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(share, 1)
		f.Parent = row
		local function sync() f.Visible = after.Visible and (before == nil or before.Visible) end
		after:GetPropertyChangedSignal("Visible"):Connect(sync)
		sync()
	end
	gap(15, 0.02, name) -- seal / flame -> name
	gap(25, 0.012, glyph) -- name -> Premium glyph
	gap(35, 0.024, vip) -- -> VIP tag
	gap(45, 0.036, dev) -- -> device
	plates[p] = { gui = g, badge = badge, badgeText = bt, badgeImage = bi, seal = seal, vip = vip, streak = streak, streakN = flame:FindFirstChild("N"), name = name, device = dev, glyph = glyph }
end

-- (2026-10-21, RIVALS 1:1) the name label is as wide as its text (measured once per text), so the seal and the device icon sit
-- right against the name like RIVALS' plate. Width share = row height (studs) x text aspect / plate width, capped.
local function fitName(e)
	local text = e.name.Text
	if e.fitted == text then return end
	e.fitted = text
	task.spawn(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text, params.Font, params.Size, params.Width = text, BOLD, 100, 100000
		local ok, b = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if not ok or not b or b.Y <= 0 or not e.name.Parent or e.fitted ~= text then return end
		local share = (H_STUDS * ROW) * (b.X / b.Y) / W_STUDS
		-- (2026-10-22, Edward: each icon sits a precise distance from the name) the label is exactly the text's width, so the
		-- seal / badge / device gaps all equal the row's padding (no extra 4 % after the name)
		e.name.Size = UDim2.fromScale(math.clamp(share * 0.96, 0.08, 0.66), 1) -- (a hair under: TextScaled then fills the width exactly)
	end)
end

local function hook(p)
	p.CharacterAdded:Connect(function(c) task.spawn(build, p, c) end)
	if p.Character then task.spawn(build, p, p.Character) end
end

function Nameplates.Start()
	-- match places: lobby plates only in the after-match lobby (never over your opponent in a duel)
	local PseudoLobby = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("PseudoLobby"))
	PseudoLobby.WaitMap()
	Nameplates.Active = PseudoLobby.Active
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(p)
		local e = plates[p]
		if e and e.gui then e.gui:Destroy() end
		plates[p] = nil
	end)
	for _, p in Players:GetPlayers() do hook(p) end
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if t < 0.25 then return end
		t = 0
		local hideAll = player:GetAttribute("InTraining") == true or player:GetAttribute("InDuel") == true or player:GetAttribute("DuelSpectate") ~= nil or player:GetAttribute("InCutscene") == true
			or player:GetAttribute("Setting_HideHUD") == true
		for p, e in plates do
			if e.gui and e.gui.Parent then
				-- too close to the camera it would fill the screen (it's sized in studs): hide it inside ~9 studs
				local head = e.gui.Adornee
				local near = head and (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 9
				-- only plates of people in the same place as you: same duel (or both in the lobby)
				local sameSpace = (p:GetAttribute("DuelMatch") or false) == (player:GetAttribute("DuelMatch") or false)
				e.gui.Enabled = Nameplates.Active() and not hideAll and not near and sameSpace and p:GetAttribute("InTraining") ~= true
					and not (p == player and player:GetAttribute("InKit") == true) -- (2026-10-21) own plate hidden in the Kit
				-- (2026-10-20, Edward, RIVALS) ONE icon left of the name, picked by your leaderboard mode (Lobby Data):
				--   Level / Streak (/ Wins): their win-streak flame if they have one, else their level (Wins: their wins)
				--   Rank: their rank emblem if they're ranked, else their level
				-- (2026-10-23, Edward) the icon follows the leaderboard YOU are on (LeaderboardStat, set by the lobby HUD's list; Lobby Data
				-- otherwise), for every plate in your lobby: Level = their level; Streak = their flame if they have a streak, else their level;
				-- Rank = their rank emblem if ranked, else their level; anything else (Wins) = their level
				local mode = player:GetAttribute("LeaderboardStat") or player:GetAttribute("Setting_LobbyData") or "Level"
				if mode == "Wins" then mode = "Level" end
				local sn = tonumber(p:GetAttribute("WinStreak")) or 0
				local flame = sn > 0 and mode == "Streak"
				e.streak.Visible = flame
				e.badge.Visible = not flame
				if e.streakN then e.streakN.Text = tostring(sn) end
				if not flame then
					local r = (mode == "Rank" and RankArt) and RankArt.Of(p) or nil
					e.seal.Visible = false
					if r and r.image then
						e.badgeImage.Visible, e.badgeImage.Image = true, r.image
						e.badgeText.Text = ""
						e.badge.BackgroundTransparency = 1
					elseif mode ~= "Wins" then
						-- (2026-10-21, RIVALS 1:1) RIVALS' blue seal with the white number (was our tiered shield, Kit.levelTier)
						e.badgeImage.Visible = false
						e.badge.BackgroundTransparency = 1
						e.badgeText.Text = ""
						e.seal.Visible = true
						local K = require(game:GetService("ReplicatedStorage").UIKit.Kit)
						K.setLevel(e.seal, tonumber(p:GetAttribute("Level")) or 1)
					else
						e.badgeImage.Visible = false
						e.badge.BackgroundTransparency = 0.25
						e.badgeText.Text = tostring(p:GetAttribute("Wins") or 0)
						local st = e.badgeText:FindFirstChildOfClass("UIStroke")
						if st then st.Transparency = 1 end
					end
				end
				e.vip.Visible = p:GetAttribute("VIP") == true
				-- (2026-10-20, Edward) Roblox badges with the name (UIKit.Badges: verified while Display Badges is on, else Premium)
				if e.name then
					local okB, B = pcall(function() return require(game:GetService("ReplicatedStorage").UIKit.Badges) end)
					-- (2026-10-22) the name alone; the badge glyph Badges.Name appends goes into its own label
					local full = (okB and B) and B.Name(p) or p.DisplayName
					local suffix = full:sub(#p.DisplayName + 1):gsub("^%s+", "")
					e.name.Text = p.DisplayName
					if e.glyph then e.glyph.Text = suffix; e.glyph.Visible = suffix ~= "" end
					local dv = (okB and B and B.DeviceIcon) and B.DeviceIcon(p) or nil
					if e.device then e.device.Visible = dv ~= nil; e.device.Image = dv or "" end
					fitName(e)
				end
			end
		end
	end)
end

return Nameplates
