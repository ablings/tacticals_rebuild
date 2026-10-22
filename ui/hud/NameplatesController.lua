-- Client/Controllers/NameplatesController (ModuleScript, auto-loaded): RIVALS' lobby nameplates in our look.
-- Over every player in the lobby: a stat badge (Level or Wins: Settings > Video > Interface > Lobby Data), the display
-- name big and bold, @username small under it (only when it differs from the display name), and a VIP chip for VIPs. Sized in studs (shrinks with distance), not
-- AlwaysOnTop (walls hide it: Roblox's own names were turned off because they showed through walls).
-- Not shown in Training, during a cutscene, or when you hide the HUD. (UI session 2026-10-16)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Nameplates = {}
local player = Players.LocalPlayer
-- (2026-10-21, AI-tells cleanup) Builder Sans is out: the name / numbers in Oswald Bold, @username in Rubik Medium
local BOLD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local MED = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)

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
	g.Size = mine and UDim2.fromScale(9 * 0.55, 2 * 0.55) or UDim2.fromScale(9, 2) -- studs
	g.StudsOffset = Vector3.new(0, mine and 1.6 or 2.1, 0)
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
	row.Size = UDim2.fromScale(1, 0.62)
	row.Parent = g
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.015, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local badge = Instance.new("Frame")
	badge.LayoutOrder = 1
	badge.Size = UDim2.fromScale(0.13, 0.82)
	badge.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
	badge.BackgroundTransparency = 0.25
	badge.Parent = row
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.25, 0); bc.Parent = badge
	local bt = Instance.new("TextLabel")
	bt.BackgroundTransparency = 1
	bt.Size = UDim2.fromScale(1, 1)
	bt.FontFace = BOLD
	bt.TextScaled = true
	bt.TextColor3 = Color3.new(1, 1, 1)
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
	bt.ZIndex = bi.ZIndex + 1 -- the number sits over the level shield / emblem
	local name = Instance.new("TextLabel")
	name.LayoutOrder = 2
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.62, 1) -- (TextScaled and AutomaticSize don't mix: a fixed share of the row)
	name.FontFace = BOLD
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = p.DisplayName
	name.Name = "DisplayName" -- (2026-10-20) badges are added by the update loop (UIKit.Badges)
	name.Parent = row
	local ns = Instance.new("UIStroke"); ns.Thickness = 2; ns.Transparency = 0.25; ns.Parent = name
	local vip = Instance.new("TextLabel")
	vip.LayoutOrder = 3
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
	user.TextColor3 = Color3.fromRGB(205, 205, 212)
	user.Text = "@" .. p.Name
	user.Visible = showHandle
	user.Parent = g
	local us = Instance.new("UIStroke"); us.Thickness = 1.5; us.Transparency = 0.4; us.Parent = user
	-- the old server VIP tag sits in the same spot: ours carries the VIP chip now
	local oldVip = head:FindFirstChild("VipTag")
	if oldVip and oldVip:IsA("BillboardGui") then oldVip.Enabled = false end
	head.ChildAdded:Connect(function(c) if c.Name == "VipTag" and c:IsA("BillboardGui") then c.Enabled = false end end)
	-- (2026-10-18) the win streak: RIVALS' flame with the number over it, right of the name
	local streak = Instance.new("Frame")
	streak.Name = "StreakHolder"
	streak.LayoutOrder = 0 -- (2026-10-20, Edward) the flame takes the badge's place, left of the name
	streak.BackgroundTransparency = 1
	streak.Size = UDim2.fromScale(0.13, 0.95)
	streak.Visible = false
	streak.Parent = row
	local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
	local flame = Kit.streak(streak, 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
	-- (2026-10-20, RIVALS) the device icon after the name (UIKit.Badges.DeviceIcon; hidden until the art is uploaded)
	local dev = Instance.new("ImageLabel")
	dev.Name = "Device"
	dev.LayoutOrder = 5
	dev.BackgroundTransparency = 1
	dev.ScaleType = Enum.ScaleType.Fit
	dev.Size = UDim2.fromScale(0.09, 0.7)
	dev.Visible = false
	dev.Parent = row
	plates[p] = { gui = g, badge = badge, badgeText = bt, badgeImage = bi, vip = vip, streak = streak, streakN = flame:FindFirstChild("N"), name = name, device = dev }
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
				local mode = player:GetAttribute("Setting_LobbyData") or "Level"
				local sn = tonumber(p:GetAttribute("WinStreak")) or 0
				local flame = sn > 0 and mode ~= "Rank"
				e.streak.Visible = flame
				e.badge.Visible = not flame
				if e.streakN then e.streakN.Text = tostring(sn) end
				if not flame then
					local r = (mode == "Rank" and RankArt) and RankArt.Of(p) or nil
					if r and r.image then
						e.badgeImage.Visible, e.badgeImage.Image = true, r.image
						e.badgeText.Text = ""
						e.badge.BackgroundTransparency = 1
					elseif mode ~= "Wins" then
						-- (2026-10-20) our tiered level shield (Kit.levelTier) with the number over it in the tier's edge colour
						local K = require(game:GetService("ReplicatedStorage").UIKit.Kit)
						local lv = tonumber(p:GetAttribute("Level")) or 1
						local img, edge = K.levelTier(lv)
						e.badgeImage.Visible, e.badgeImage.Image = true, img
						e.badge.BackgroundTransparency = 1
						e.badgeText.Text = tostring(lv)
						local st = e.badgeText:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
						st.Color, st.Thickness, st.Transparency = edge, 2, 0
						st.Parent = e.badgeText
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
					e.name.Text = (okB and B) and B.Name(p) or p.DisplayName
					local dv = (okB and B and B.DeviceIcon) and B.DeviceIcon(p) or nil
					if e.device then e.device.Visible = dv ~= nil; e.device.Image = dv or "" end
				end
			end
		end
	end)
end

return Nameplates
