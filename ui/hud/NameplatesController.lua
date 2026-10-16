-- Client/Controllers/NameplatesController (ModuleScript, auto-loaded): RIVALS' lobby nameplates in our look.
-- Over every player in the lobby: a stat badge (Level or Wins: Settings > Video > Interface > Lobby Data), the display
-- name big and bold, @username small under it, and a VIP chip for VIPs. Sized in studs (shrinks with distance), not
-- AlwaysOnTop (walls hide it: Roblox's own names were turned off because they showed through walls).
-- Not shown in Training, during a cutscene, or when you hide the HUD. (UI session 2026-10-16)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Nameplates = {}
local player = Players.LocalPlayer
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local MED = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local plates = {} -- [Player] = { gui, badgeText, nameText, vip }

local function statOf(p)
	local which = player:GetAttribute("Setting_LobbyData") == "Wins" and "Wins" or "Level"
	return which, p:GetAttribute(which) or 0
end

local function build(p, character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end
	local old = plates[p]
	if old and old.gui then old.gui:Destroy() end
	local g = Instance.new("BillboardGui")
	g.Name = "Nameplate_" .. p.UserId
	g.Adornee = head
	g.Size = UDim2.fromScale(9, 2) -- studs
	g.StudsOffset = Vector3.new(0, 2.1, 0)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.ResetOnSpawn = false
	g.Parent = player:WaitForChild("PlayerGui")
	-- row: [badge] Name [VIP]
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
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
	bt.Parent = badge
	local bp = Instance.new("UIPadding"); bp.PaddingTop = UDim.new(0.12, 0); bp.PaddingBottom = UDim.new(0.12, 0); bp.Parent = bt
	local name = Instance.new("TextLabel")
	name.LayoutOrder = 2
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.62, 1) -- (TextScaled and AutomaticSize don't mix: a fixed share of the row)
	name.FontFace = BOLD
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = p.DisplayName
	name.Parent = row
	local ns = Instance.new("UIStroke"); ns.Thickness = 2; ns.Transparency = 0.25; ns.Parent = name
	local vip = Instance.new("TextLabel")
	vip.LayoutOrder = 3
	vip.Size = UDim2.fromScale(0.15, 0.7)
	vip.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
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
	user.Parent = g
	local us = Instance.new("UIStroke"); us.Thickness = 1.5; us.Transparency = 0.4; us.Parent = user
	-- the old server VIP tag sits in the same spot: ours carries the VIP chip now
	local oldVip = head:FindFirstChild("VipTag")
	if oldVip and oldVip:IsA("BillboardGui") then oldVip.Enabled = false end
	head.ChildAdded:Connect(function(c) if c.Name == "VipTag" and c:IsA("BillboardGui") then c.Enabled = false end end)
	plates[p] = { gui = g, badgeText = bt, vip = vip }
end

local function hook(p)
	p.CharacterAdded:Connect(function(c) task.spawn(build, p, c) end)
	if p.Character then task.spawn(build, p, p.Character) end
end

function Nameplates.Start()
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
		local hideAll = player:GetAttribute("InTraining") == true or player:GetAttribute("InCutscene") == true
			or player:GetAttribute("Setting_HideHUD") == true
		for p, e in plates do
			if e.gui and e.gui.Parent then
				e.gui.Enabled = not hideAll and p:GetAttribute("InTraining") ~= true
				local which, v = statOf(p)
				e.badgeText.Text = tostring(v)
				e.vip.Visible = p:GetAttribute("VIP") == true
			end
		end
	end)
end

return Nameplates
