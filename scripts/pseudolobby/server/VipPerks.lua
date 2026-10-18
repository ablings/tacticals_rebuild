-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- VipPerks (pass 37): players with the VIP pass (player attribute VIP, set by LobbyManager) get a "VIP" tag over
-- their head. The chat tag is client-side (StarterPlayerScripts.VipChatTag). Bone + olive, no gold (theme rule).
local Players = game:GetService("Players")
local function tag(player, character)
	if not player:GetAttribute("VIP") then return end
	local head = character:WaitForChild("Head", 10); if not head or head:FindFirstChild("VipTag") then return end
	local g = Instance.new("BillboardGui"); g.Name = "VipTag"; g.Size = UDim2.fromOffset(64, 22); g.StudsOffset = Vector3.new(0, 2.4, 0)
	g.MaxDistance = 60; g.LightInfluence = 0; g.Parent = head
	local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundColor3 = Color3.fromRGB(26, 29, 26); l.BackgroundTransparency = 0.15
	l.Text = "VIP"; l.TextColor3 = Color3.fromRGB(236, 232, 218); l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); l.Parent = g
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(107, 122, 58); st.Thickness = 2; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = l
end
local function hook(p)
	p.CharacterAdded:Connect(function(c) tag(p, c) end)
	p:GetAttributeChangedSignal("VIP"):Connect(function() if p.Character then tag(p, p.Character) end end)
	if p.Character then task.spawn(tag, p, p.Character) end
end
Players.PlayerAdded:Connect(hook); for _, p in Players:GetPlayers() do hook(p) end
