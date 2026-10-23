-- UIKit/Tac: the TACTICALS deployment-board look (pass 34). Palette + small builders every screen can use:
--   Tac.brackets(gui, color?, len?, thickness?)  corner brackets instead of a full outline (returns the frames)
--   Tac.header(parent, title, sub?, accent?)       olive bar + stencil title (+ grey subline)
--   Tac.strip(parent, text, accent?)               the olive status strip from the PLAY cards
--   Tac.hoverBrackets(button, frames, base)        brackets light up bone-white on hover
local Tac = {}
Tac.C = {
	-- (2026-10-21, Edward Q1 / Q2) olive / oliveHi = field green (done / ready; was the comic yellow), the yellow lives on only
	-- as `gold` for #1 / rank-1 highlights, and the Ranked "violet" is now a muted dark gold (name kept for old callers)
	bone = Color3.fromRGB(236, 232, 218), field = Color3.fromRGB(150, 156, 140), olive = Color3.fromRGB(141, 191, 90),
	oliveHi = Color3.fromRGB(141, 191, 90), oliveDark = Color3.fromRGB(70, 80, 38), gun = Color3.fromRGB(26, 29, 26),
	gunDeep = Color3.fromRGB(12, 14, 11), line = Color3.fromRGB(64, 70, 58), violet = Color3.fromRGB(150, 116, 52),
	gold = Color3.fromRGB(255, 212, 0), cream = Color3.fromRGB(236, 230, 210),
	red = Color3.fromRGB(196, 52, 46), ink = Color3.fromRGB(10, 12, 9),
}
Tac.FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local TS = game:GetService("TweenService")
-- (2026-10-21, Edward Q3 + the "AI-generated UI" tells) Tac.brackets no longer draws anything: no corner brackets, and no
-- rounded corner + faint hairline edge (that combo is exactly what reads as AI-made). It returns {} so callers keep working,
-- and Tac.hoverBrackets gives RIVALS' hover instead: the card lifts (grows a little) and a soft thick glow fades in.
function Tac.brackets(p, color, len, th)
	return {}
end
function Tac.hoverBrackets(b, frames)
	if not (b and b:IsA("GuiObject")) then return end
	local sc = b:FindFirstChildOfClass("UIScale")
	local owned = false
	if not sc then sc = Instance.new("UIScale"); sc.Name = "LiftScale"; sc.Parent = b; owned = true end
	local glow = Instance.new("UIStroke")
	glow.Name = "_HoverGlow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Color = Tac.C.cream
	glow.Thickness = 4
	glow.Transparency = 1
	glow:SetAttribute("NoStyle", true)
	glow.Parent = b
	b.MouseEnter:Connect(function()
		TS:Create(glow, TweenInfo.new(0.15), { Transparency = 0.45 }):Play()
		if owned then TS:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.03 }):Play() end
	end)
	b.MouseLeave:Connect(function()
		TS:Create(glow, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		if owned then TS:Create(sc, TweenInfo.new(0.15), { Scale = 1 }):Play() end
	end)
end
function Tac.header(parent, title, sub, accent, size)
	local h = Instance.new("Frame"); h.Name = "TacHeader"; h.BackgroundTransparency = 1; h.Size = UDim2.new(1, 0, 0, size or 40); h.Parent = parent
	-- (2026-10-21) no left accent bar (an "AI UI" tell); the title starts at the edge
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.FontFace = Tac.FONT; t.TextColor3 = Tac.C.bone; t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title; t.TextScaled = true; t.Size = UDim2.new(0.6, 0, sub and 0.62 or 0.9, 0); t.Position = UDim2.new(0, 0, 0, 0); t.Parent = h
	if sub then
		local s = Instance.new("TextLabel"); s.BackgroundTransparency = 1; s.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium) -- Rubik (no Gotham)
		s.TextColor3 = Tac.C.field; s.TextXAlignment = Enum.TextXAlignment.Left; s.Text = sub; s.TextScaled = true
		s.Size = UDim2.new(0.6, 0, 0.3, 0); s.Position = UDim2.new(0, 1, 0.66, 0); s.Parent = h
	end
	return h
end
function Tac.strip(parent, text, accent)
	local s = Instance.new("Frame"); s.Name = "TacStrip"; s.BackgroundColor3 = accent or Tac.C.olive; s.BackgroundTransparency = 0.15; s.BorderSizePixel = 0
	s.Size = UDim2.new(1, 0, 0, 22); s.AnchorPoint = Vector2.new(0, 1); s.Position = UDim2.fromScale(0, 1); s.Parent = parent
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.FontFace = Tac.FONT; l.TextColor3 = Tac.C.bone; l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left; l.Text = text or ""; l.Size = UDim2.new(1, -16, 1, 0); l.Position = UDim2.fromOffset(8, 0); l.Parent = s
	return s, l
end
return Tac