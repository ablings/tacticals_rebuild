-- UIKit/Tac: the TACTICALS deployment-board look (pass 34). Palette + small builders every screen can use:
--   Tac.brackets(gui, color?, len?, thickness?)  corner brackets instead of a full outline (returns the frames)
--   Tac.header(parent, title, sub?, accent?)       olive bar + stencil title (+ grey subline)
--   Tac.strip(parent, text, accent?)               the olive status strip from the PLAY cards
--   Tac.hoverBrackets(button, frames, base)        brackets light up bone-white on hover
local Tac = {}
Tac.C = {
	bone = Color3.fromRGB(236, 232, 218), field = Color3.fromRGB(150, 156, 140), olive = Color3.fromRGB(107, 122, 58),
	oliveHi = Color3.fromRGB(138, 156, 74), oliveDark = Color3.fromRGB(70, 80, 38), gun = Color3.fromRGB(26, 29, 26),
	gunDeep = Color3.fromRGB(12, 14, 11), line = Color3.fromRGB(64, 70, 58), violet = Color3.fromRGB(176, 120, 255),
	red = Color3.fromRGB(196, 52, 46), ink = Color3.fromRGB(10, 12, 9),
}
Tac.FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local TS = game:GetService("TweenService")
function Tac.brackets(p, color, len, th)
	color, len, th = color or Tac.C.line, len or 14, th or 2
	local list = {}
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local ax = Vector2.new(c[1], c[2])
		for _, sz in { UDim2.fromOffset(len, th), UDim2.fromOffset(th, len) } do
			local f = Instance.new("Frame"); f.Name = "_Bracket"; f.BackgroundColor3 = color; f.BorderSizePixel = 0; f.AnchorPoint = ax
			f.Position = UDim2.fromScale(c[1], c[2]); f.Size = sz; f.ZIndex = (p:IsA("GuiObject") and p.ZIndex or 1) + 5; f:SetAttribute("NoStyle", true)
			f:SetAttribute("Base", color); f.Parent = p; table.insert(list, f)
		end
	end
	return list
end
function Tac.hoverBrackets(b, frames)
	b.MouseEnter:Connect(function() for _, f in frames do TS:Create(f, TweenInfo.new(0.15), { BackgroundColor3 = Tac.C.bone }):Play() end end)
	b.MouseLeave:Connect(function() for _, f in frames do TS:Create(f, TweenInfo.new(0.15), { BackgroundColor3 = f:GetAttribute("Base") }):Play() end end)
end
function Tac.header(parent, title, sub, accent, size)
	local h = Instance.new("Frame"); h.Name = "TacHeader"; h.BackgroundTransparency = 1; h.Size = UDim2.new(1, 0, 0, size or 40); h.Parent = parent
	local bar = Instance.new("Frame"); bar.BackgroundColor3 = accent or Tac.C.olive; bar.BorderSizePixel = 0; bar.Size = UDim2.new(0, 6, 1, -8)
	bar.Position = UDim2.fromOffset(0, 4); bar.Parent = h
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.FontFace = Tac.FONT; t.TextColor3 = Tac.C.bone; t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title; t.TextScaled = true; t.Size = UDim2.new(0.6, 0, sub and 0.62 or 0.9, 0); t.Position = UDim2.new(0, 16, 0, 0); t.Parent = h
	if sub then
		local s = Instance.new("TextLabel"); s.BackgroundTransparency = 1; s.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
		s.TextColor3 = Tac.C.field; s.TextXAlignment = Enum.TextXAlignment.Left; s.Text = sub; s.TextScaled = true
		s.Size = UDim2.new(0.6, 0, 0.3, 0); s.Position = UDim2.new(0, 17, 0.66, 0); s.Parent = h
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